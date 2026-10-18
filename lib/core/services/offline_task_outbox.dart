import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/human_accountability/data/datasource/accountability_service.dart';

/// Offline outbox for Squad task creation.
///
/// Squads tasks are Firestore-doc based, so creating one while Firebase is
/// not ready (e.g. the app cold-started offline) fails outright. Instead of
/// showing a generic failure, the sheet stores the creation payload here and
/// a "Saved offline" message is shown; the payload is replayed to
/// [AccountabilityService.createAccountabilityTask] on the next
/// connectivity-restore / app-start while signed in.
class OfflineTaskOutbox {
  OfflineTaskOutbox._();
  static final OfflineTaskOutbox instance = OfflineTaskOutbox._();

  static const _kQueueKey = 'offline_task_outbox_v1';

  final AccountabilityService _svc = AccountabilityService();

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = _readQueue(prefs);
      queue.add({
        ...payload,
        'queuedAt': DateTime.now().toIso8601String(),
      });
      await _writeQueue(prefs, queue);
    } catch (e) {
      if (kDebugMode) debugPrint('[OfflineTaskOutbox] enqueue failed: $e');
    }
  }

  /// Replays queued task creations. An item is consumed only when its
  /// creation succeeds or when the stored creator no longer matches the
  /// signed-in account (stale payload from a previous user — never replayed
  /// into the wrong account's squad).
  ///
  /// Returns the number of tasks created.
  Future<int> flush() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _readQueue(prefs);
    if (queue.isEmpty) return 0;
    if (!_svc.isReady) return 0;

    final uid = _svc.currentUid;
    if (uid == null) return 0;

    final remaining = <Map<String, dynamic>>[];
    var created = 0;

    for (final item in queue) {
      final creator = (item['senderUid'] as String?) ?? '';
      // Creator recorded (signed in when queued) but a different account is
      // active now — the task was never meant for them; drop it.
      if (creator.isNotEmpty && creator != uid) {
        if (kDebugMode) {
          debugPrint('[OfflineTaskOutbox] dropping stale task "$creator"');
        }
        continue;
      }

      try {
        final task = await _svc.createAccountabilityTask(
          accountableUid: (item['accountableUid'] as String?) ?? '',
          accountableName: (item['accountableName'] as String?) ?? '',
          partnershipId: (item['partnershipId'] as String?) ?? '',
          title: (item['title'] as String?) ?? '',
          description: (item['description'] as String?),
          challengeId: (item['challengeId'] as String?),
          partnerUid: (item['partnerUid'] as String?),
          taskType: (item['taskType'] as String?),
        );
        if (task != null) {
          created++;
        } else {
          remaining.add(item);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[OfflineTaskOutbox] replay failed, keeping item: $e');
        }
        remaining.add(item);
      }
    }

    await _writeQueue(prefs, remaining);
    return created;
  }
}
