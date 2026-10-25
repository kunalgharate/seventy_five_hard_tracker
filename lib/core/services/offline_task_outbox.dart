import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity_service.dart';

import '../../features/human_accountability/data/datasource/accountability_service.dart';

typedef OfflineTaskPartnershipResolver = Future<String?> Function(
  String uid,
  String name,
);

typedef OfflineTaskCreator = Future<bool> Function(
  Map<String, dynamic> task,
  String partnershipId,
);

class OfflineTaskFlushResult {
  const OfflineTaskFlushResult({
    required this.created,
    required this.succeeded,
  });

  final int created;
  final bool succeeded;
}

/// Offline outbox for Squad task creation.
///
/// Squads tasks are Firestore-doc based, so creating one while Firebase is
/// not ready (e.g. the app cold-started offline) fails outright. Instead of
/// showing a generic failure, the sheet stores the creation payload here and
/// a "Saved offline" message is shown; the payload is replayed to
/// [AccountabilityService.createAccountabilityTask] on the next
/// connectivity-restore / app-start while signed in.
class OfflineTaskOutbox {
  OfflineTaskOutbox({
    Future<bool> Function()? hasInternet,
    bool Function()? isReady,
    String? Function()? currentUid,
    OfflineTaskPartnershipResolver? resolvePartnership,
    OfflineTaskCreator? createTask,
  })  : _hasInternet = hasInternet ?? ConnectivityService().hasInternet,
        _isReady = isReady ?? (() => AccountabilityService().isReady),
        _currentUid = currentUid ?? (() => AccountabilityService().currentUid),
        _resolvePartnership = resolvePartnership ??
            ((uid, name) =>
                AccountabilityService().ensurePartnership(uid, name)),
        _createTask = createTask ?? _createWithAccountabilityService;

  static final OfflineTaskOutbox instance = OfflineTaskOutbox();

  static const _kQueueKey = 'offline_task_outbox_v1';
  static int _nextItemId = 0;

  final Future<bool> Function() _hasInternet;
  final bool Function() _isReady;
  final String? Function() _currentUid;
  final OfflineTaskPartnershipResolver _resolvePartnership;
  final OfflineTaskCreator _createTask;
  Future<void> _queueLock = Future<void>.value();
  Future<OfflineTaskFlushResult>? _flushInFlight;

  static Future<bool> _createWithAccountabilityService(
    Map<String, dynamic> item,
    String partnershipId,
  ) async {
    final task = await AccountabilityService().createAccountabilityTask(
      accountableUid: (item['accountableUid'] as String?) ?? '',
      accountableName: (item['accountableName'] as String?) ?? '',
      partnershipId: partnershipId,
      title: (item['title'] as String?) ?? '',
      description: item['description'] as String?,
      challengeId: item['challengeId'] as String?,
      partnerUid: item['partnerUid'] as String?,
      taskType: item['taskType'] as String?,
    );
    return task != null;
  }

  Future<T> _withQueueLock<T>(Future<T> Function() action) {
    final previous = _queueLock;
    final release = Completer<void>();
    _queueLock = release.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        release.complete();
      }
    }();
  }

  List<Map<String, dynamic>> _readQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_kQueueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineTaskOutbox] queue read failed: $e');
      return [];
    }
  }

  Future<void> _writeQueue(
      SharedPreferences prefs, List<Map<String, dynamic>> queue) async {
    if (queue.isEmpty) {
      await prefs.remove(_kQueueKey);
    } else {
      await prefs.setString(_kQueueKey, jsonEncode(queue));
    }
  }

  /// Queues a task-creation payload to be replayed when connectivity
  /// (and a signed-in session) is available again.
  Future<void> enqueue(Map<String, dynamic> payload) async {
    await _withQueueLock(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final queue = _readQueue(prefs);
        final outboxId =
            '${DateTime.now().microsecondsSinceEpoch}_${_nextItemId++}';
        queue.add({
          ...payload,
          '_outboxId': outboxId,
          'queuedAt': DateTime.now().toIso8601String(),
        });
        await _writeQueue(prefs, queue);
      } catch (e) {
        if (kDebugMode) debugPrint('[OfflineTaskOutbox] enqueue failed: $e');
        rethrow;
      }
    });
  }

  /// Replays queued task creations without holding the queue lock while
  /// waiting on network operations. This lets new tasks be enqueued while a
  /// replay is in progress.
  ///
  /// Returns the number of tasks created.
  Future<int> flush() async => (await flushWithResult()).created;

  /// Flushes the queue and reports whether every pending operation completed.
  ///
  /// Items that fail remain queued and make [succeeded] false, allowing the
  /// connectivity coordinator to retain its retry-pending state.
  Future<OfflineTaskFlushResult> flushWithResult() {
    final activeFlush = _flushInFlight;
    if (activeFlush != null) return activeFlush;
    late final Future<OfflineTaskFlushResult> flush;
    flush = _flushQueuedTasks().whenComplete(() {
      if (identical(_flushInFlight, flush)) _flushInFlight = null;
    });
    _flushInFlight = flush;
    return flush;
  }

  Future<OfflineTaskFlushResult> _flushQueuedTasks() async {
    if (!await _hasInternet()) {
      return const OfflineTaskFlushResult(created: 0, succeeded: false);
    }
    final queue = await _withQueueLock(() async {
      final prefs = await SharedPreferences.getInstance();
      final queuedItems = _readQueue(prefs);
      var changed = false;
      for (final item in queuedItems) {
        if (item['_outboxId'] is! String) {
          item['_outboxId'] =
              '${DateTime.now().microsecondsSinceEpoch}_${_nextItemId++}';
          changed = true;
        }
      }
      if (changed) await _writeQueue(prefs, queuedItems);
      return queuedItems;
    });
    if (queue.isEmpty) {
      return const OfflineTaskFlushResult(created: 0, succeeded: true);
    }
    if (!_isReady()) {
      return const OfflineTaskFlushResult(created: 0, succeeded: false);
    }

    var created = 0;
    var succeeded = true;

    for (final item in queue) {
      final uid = _currentUid();
      if (uid == null || !_isReady()) {
        succeeded = false;
        continue;
      }
      final creator = (item['senderUid'] as String?) ?? '';
      // Never invoke the resolver or creator without proving that the
      // queued sender is still the signed-in account.
      if (creator.isEmpty || creator != uid) {
        if (kDebugMode) {
          debugPrint(
              '[OfflineTaskOutbox] dropping invalid or stale task "$creator"');
        }
        await _removeQueuedItem(item);
        continue;
      }

      try {
        var partnershipId = (item['partnershipId'] as String?) ?? '';
        final accountableUid = (item['accountableUid'] as String?) ?? '';
        final partnerUid = (item['partnerUid'] as String?) ?? '';
        final targetUid = partnerUid.isNotEmpty && partnerUid != creator
            ? partnerUid
            : accountableUid;
        final targetName = (item['accountableName'] as String?) ?? '';
        if (partnershipId.isEmpty &&
            targetUid.isNotEmpty &&
            targetUid != creator) {
          if (!_isReady() || _currentUid() != creator) {
            succeeded = false;
            continue;
          }
          partnershipId =
              await _resolvePartnership(targetUid, targetName) ?? '';
          if (!_isReady() || _currentUid() != creator) {
            succeeded = false;
            continue;
          }
          if (partnershipId.isEmpty) {
            succeeded = false;
            continue;
          }
        }
        if (!_isReady() || _currentUid() != creator) {
          succeeded = false;
          continue;
        }
        if (await _createTask(item, partnershipId)) {
          created++;
          await _removeQueuedItem(item);
        } else {
          succeeded = false;
        }
      } catch (e) {
        succeeded = false;
        if (kDebugMode) {
          debugPrint('[OfflineTaskOutbox] replay failed, keeping item: $e');
        }
      }
    }

    final hasPendingItems = await _withQueueLock(() async {
      final prefs = await SharedPreferences.getInstance();
      return _readQueue(prefs).isNotEmpty;
    });
    if (hasPendingItems) succeeded = false;

    return OfflineTaskFlushResult(created: created, succeeded: succeeded);
  }

  Future<void> _removeQueuedItem(Map<String, dynamic> item) =>
      _withQueueLock(() async {
        final prefs = await SharedPreferences.getInstance();
        final queue = _readQueue(prefs);
        final id = item['_outboxId'];
        queue.removeWhere((queued) => queued['_outboxId'] == id);
        await _writeQueue(prefs, queue);
      });
}
