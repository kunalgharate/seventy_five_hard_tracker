import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seventy_five_hard_tracker/core/services/offline_task_outbox.dart';
import 'package:seventy_five_hard_tracker/core/services/connectivity_reconnect_state.dart';
import 'package:seventy_five_hard_tracker/core/utils/notification_badge.dart';
import 'package:seventy_five_hard_tracker/core/utils/online_refresh.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_message.dart';

void main() {
  group('BUG-01: unread notification badge state', () {
    test('counts every delivered unread notification, without a recent cap',
        () {
      final notifications = List.generate(
        80,
        (index) => {
          'id': '$index',
          'delivered': true,
          'isRead': false,
          'suppressedByPrefs': false,
        },
      );

      expect(unreadDeliveredNotifications(notifications), hasLength(80));
    });

    test(
        'read, undelivered, and preference-suppressed notifications do not count',
        () {
      expect(
        unreadDeliveredNotifications([
          {'delivered': true, 'isRead': true},
          {'delivered': false, 'isRead': false},
          {
            'delivered': true,
            'isRead': false,
            'suppressedByPrefs': true,
          },
        ]),
        isEmpty,
      );
    });
  });

  group('BUG-02: challenge reset reason', () {
    test('manual restart records the expected reason and end state', () {
      final endedAt = DateTime(2026, 10, 18, 9);
      final ended = endSessionForManualRestart(
        _session(),
        endedAt: endedAt,
      );

      expect(ended.isActive, isFalse);
      expect(ended.endDate, endedAt);
      expect(ended.failureReason, 'Manually restarted');
    });

    test('missing legacy reset reasons are identified without guessing', () {
      expect(challengeResetReasonLabel(null), 'Reason not recorded');
      expect(challengeResetReasonLabel('  '), 'Reason not recorded');
      expect(challengeResetReasonLabel('  missed task  '), 'missed task');
    });
  });

  group('BUG-03: offline task outbox', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('keeps a task queued while offline, then replays it when online',
        () async {
      var online = false;
      var created = false;
      String? resolvedUid;
      String? resolvedName;
      String? createdPartnership;
      Map<String, dynamic>? createdTask;
      final outbox = OfflineTaskOutbox(
        hasInternet: () async => online,
        isReady: () => true,
        currentUid: () => 'owner-1',
        resolvePartnership: (uid, name) async {
          resolvedUid = uid;
          resolvedName = name;
          return 'partnership-1';
        },
        createTask: (task, partnershipId) async {
          created = true;
          createdTask = task;
          createdPartnership = partnershipId;
          return true;
        },
      );
      final task = {
        'senderUid': 'owner-1',
        'accountableUid': 'partner-1',
        'accountableName': 'Partner',
        'partnershipId': '',
        'title': 'Drink water',
        'taskType': 'hard',
      };

      await outbox.enqueue(task);
      expect(await outbox.flush(), 0);
      expect(created, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getString('offline_task_outbox_v1'), contains('Drink water'));

      online = true;
      expect(await outbox.flush(), 1);
      expect(created, isTrue);
      expect(resolvedUid, 'partner-1');
      expect(resolvedName, 'Partner');
      expect(createdPartnership, 'partnership-1');
      expect(createdTask?['title'], 'Drink water');
      expect(prefs.getString('offline_task_outbox_v1'), isNull);
    });

    test('does not replay a task under a different signed-in account',
        () async {
      var createAttempts = 0;
      final outbox = OfflineTaskOutbox(
        hasInternet: () async => true,
        isReady: () => true,
        currentUid: () => 'account-2',
        createTask: (_, __) async {
          createAttempts++;
          return true;
        },
      );
      await outbox.enqueue({
        'senderUid': 'account-1',
        'accountableUid': 'partner-1',
        'accountableName': 'Partner',
        'partnershipId': 'partnership-1',
        'title': 'Do not cross accounts',
      });

      expect(await outbox.flush(), 0);
      expect(createAttempts, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('offline_task_outbox_v1'), isNull);
    });

    test('retains a task when creation fails so a later flush can retry',
        () async {
      var createAttempts = 0;
      final outbox = OfflineTaskOutbox(
        hasInternet: () async => true,
        isReady: () => true,
        currentUid: () => 'owner-1',
        createTask: (_, __) async => ++createAttempts > 1,
      );
      await outbox.enqueue({
        'senderUid': 'owner-1',
        'accountableUid': 'partner-1',
        'accountableName': 'Partner',
        'partnershipId': 'partnership-1',
        'title': 'Retry me',
      });

      expect(await outbox.flush(), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('offline_task_outbox_v1'), contains('Retry me'));

      expect(await outbox.flush(), 1);
      expect(createAttempts, 2);
      expect(prefs.getString('offline_task_outbox_v1'), isNull);
    });

    test('reports incomplete replay so reconnect work remains pending',
        () async {
      final outbox = OfflineTaskOutbox(
        hasInternet: () async => true,
        isReady: () => true,
        currentUid: () => 'owner-1',
        createTask: (_, __) async => false,
      );
      await outbox.enqueue({
        'senderUid': 'owner-1',
        'accountableUid': 'partner-1',
        'accountableName': 'Partner',
        'partnershipId': 'partnership-1',
        'title': 'Still pending',
      });

      final result = await outbox.flushWithResult();

      expect(result.created, 0);
      expect(result.succeeded, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getString('offline_task_outbox_v1'), contains('Still pending'));
    });

    test('enqueue is not blocked behind an in-flight network replay', () async {
      final resolverStarted = Completer<void>();
      final finishResolver = Completer<String?>();
      final outbox = OfflineTaskOutbox(
        hasInternet: () async => true,
        isReady: () => true,
        currentUid: () => 'owner-1',
        resolvePartnership: (_, __) {
          resolverStarted.complete();
          return finishResolver.future;
        },
        createTask: (_, __) async => true,
      );
      await outbox.enqueue({
        'senderUid': 'owner-1',
        'accountableUid': 'partner-1',
        'accountableName': 'Partner',
        'partnershipId': '',
        'title': 'First task',
      });

      final flush = outbox.flushWithResult();
      await resolverStarted.future;
      await outbox.enqueue({
        'senderUid': 'owner-1',
        'accountableUid': 'partner-2',
        'accountableName': 'Another partner',
        'partnershipId': 'partnership-2',
        'title': 'Enqueued during replay',
      });
      finishResolver.complete('partnership-1');

      final result = await flush;
      expect(result.succeeded, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('offline_task_outbox_v1'),
        contains('Enqueued during replay'),
      );
    });
  });

  group('BUG-04: message edit validation', () {
    test('trims whitespace before saving an edited message', () {
      expect(normalizeMessageText('  Updated note  '), 'Updated note');
    });

    test('rejects a blank message edit', () {
      expect(() => normalizeMessageText('  \n  '), throwsArgumentError);
    });
  });

  group('BUG-06: reconnect-triggered synchronization', () {
    test('runs after the initial online event and after coming back online',
        () {
      final state = ConnectivityReconnectState();

      expect(state.observe(true), isTrue);
      state.complete(succeeded: true);
      expect(state.observe(true), isFalse);

      expect(state.observe(false), isFalse);
      expect(state.observe(true), isTrue);
    });

    test('keeps synchronization pending after a failed attempt', () {
      final state = ConnectivityReconnectState();
      state.observe(true);

      state.complete(succeeded: false);

      expect(state.workPending, isTrue);
      expect(state.observe(true), isTrue);
    });
  });

  group('BUG-05: Squad refresh', () {
    test('invokes reload when online', () async {
      var reloads = 0;

      final didRefresh = await refreshWhenOnline(
        hasInternet: () async => true,
        refresh: () async => reloads++,
      );

      expect(didRefresh, isTrue);
      expect(reloads, 1);
    });

    test('does not discard cached content by reloading while offline',
        () async {
      var reloads = 0;

      final didRefresh = await refreshWhenOnline(
        hasInternet: () async => false,
        refresh: () async => reloads++,
      );

      expect(didRefresh, isFalse);
      expect(reloads, 0);
    });
  });
}

ChallengeSession _session() => ChallengeSession(
      id: 'session-1',
      challenges: const [],
      startDate: DateTime(2026, 10, 1),
      isActive: true,
      isCompleted: false,
      currentDay: 18,
    );
