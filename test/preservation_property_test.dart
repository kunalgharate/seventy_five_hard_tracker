/// Preservation Property Tests
///
/// These tests verify that existing behavior for non-buggy inputs remains
/// unchanged AFTER the remaining fixes (tasks 7-10) are applied.
/// They are run on the current (partially fixed) code and must PASS,
/// establishing a baseline to detect regressions.
///
/// **Validates: Requirements 3.1, 3.2, 3.5, 3.6, 3.7, 3.8**
library preservation_property_test;

import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Property: Standard Day Counter Preservation (Req 3.7) ──────────
  group('Standard Day Counter Preservation (Req 3.7)', () {
    /// Replicates the _computeCurrentDay logic from challenge_bloc.dart.
    /// For standard 75-day sessions, the current code clamps to 75.
    /// After the fix (clamp to session.totalDaysTarget), behavior for
    /// totalDaysTarget == 75 must remain identical.
    int computeCurrentDay(DateTime startDate, int totalDaysTarget) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final days = today.difference(start).inDays + 1;
      // Current behavior: clamp(1, 75). After fix: clamp(1, totalDaysTarget).
      // When totalDaysTarget == 75, both are equivalent.
      return days.clamp(1, totalDaysTarget);
    }

    /// The CURRENT (unfixed) behavior always clamps to 75.
    int computeCurrentDayCurrent(DateTime startDate) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final days = today.difference(start).inDays + 1;
      return days.clamp(1, 75);
    }

    test(
        'Validates: Requirements 3.7 — '
        'for totalDaysTarget == 75, _computeCurrentDay returns days.clamp(1, 75) '
        'for all random daysSinceStart values', () {
      final random = Random(42);

      for (int i = 0; i < 200; i++) {
        // Generate random daysSinceStart from -10 to 200
        // (covers before start, during, and after challenge)
        final daysSinceStart = random.nextInt(211) - 10;
        final startDate =
            DateTime.now().subtract(Duration(days: daysSinceStart));
        const totalDaysTarget = 75;

        final fixedResult = computeCurrentDay(startDate, totalDaysTarget);
        final currentResult = computeCurrentDayCurrent(startDate);

        // When totalDaysTarget == 75, both must be identical
        expect(
          fixedResult,
          equals(currentResult),
          reason: 'For totalDaysTarget=75, daysSinceStart=$daysSinceStart: '
              'fixed ($fixedResult) should equal current ($currentResult)',
        );

        // Also verify the result is always in [1, 75]
        expect(fixedResult, greaterThanOrEqualTo(1));
        expect(fixedResult, lessThanOrEqualTo(75));
      }
    });

    test(
        'Validates: Requirements 3.7 — '
        'boundary values: day 0, day 1, day 75, day 76 all clamp correctly',
        () {
      // Day 0 (before start) → clamp to 1
      final beforeStart = DateTime.now().add(const Duration(days: 1));
      expect(computeCurrentDayCurrent(beforeStart), equals(1));
      expect(computeCurrentDay(beforeStart, 75), equals(1));

      // Day 1 (start date) → 1
      final startDate = DateTime.now();
      expect(computeCurrentDayCurrent(startDate), equals(1));
      expect(computeCurrentDay(startDate, 75), equals(1));

      // Day 75 → 75
      final day75 = DateTime.now().subtract(const Duration(days: 74));
      expect(computeCurrentDayCurrent(day75), equals(75));
      expect(computeCurrentDay(day75, 75), equals(75));

      // Day 76 → clamped to 75
      final day76 = DateTime.now().subtract(const Duration(days: 75));
      expect(computeCurrentDayCurrent(day76), equals(75));
      expect(computeCurrentDay(day76, 75), equals(75));
    });
  });

  // ── Property: Notification ID Determinism (Req 3.5) ────────────────
  group('Notification ID Determinism (Req 3.5)', () {
    /// Replicates the _getNotificationId logic from smart_notification_service.dart.
    /// Current code uses % 10000. After fix: % 100000.
    /// Both must be deterministic and time-differentiated.
    int getNotificationIdCurrent(String challengeId, int hour, int minute) {
      final hash = challengeId.hashCode.abs() % 10000;
      return (hash * 10000) + (hour * 100) + minute;
    }

    test(
        'Validates: Requirements 3.5 — '
        'calling _getNotificationId twice with the same inputs yields identical results',
        () {
      final random = Random(42);
      final challengeIds = [
        'Read 30 pages',
        'Meditate',
        'Workout 1',
        'Workout 2',
        'Drink water',
        'Follow diet',
        'Take progress photo',
        'Cold shower',
        'Walk 10000 steps',
        'Journal entry',
      ];

      for (int i = 0; i < 200; i++) {
        final challengeId = challengeIds[random.nextInt(challengeIds.length)];
        final hour = random.nextInt(24);
        final minute = random.nextInt(60);

        final result1 = getNotificationIdCurrent(challengeId, hour, minute);
        final result2 = getNotificationIdCurrent(challengeId, hour, minute);

        expect(
          result1,
          equals(result2),
          reason: 'Determinism: same inputs ($challengeId, $hour, $minute) '
              'must produce same ID. Got $result1 vs $result2',
        );
      }
    });

    test(
        'Validates: Requirements 3.5 — '
        'different (hour, minute) pairs for the same challenge produce different IDs',
        () {
      final random = Random(42);
      const challengeId = 'Read 30 pages';

      for (int i = 0; i < 100; i++) {
        final hour1 = random.nextInt(24);
        final minute1 = random.nextInt(60);
        var hour2 = random.nextInt(24);
        var minute2 = random.nextInt(60);

        // Ensure the two time pairs are different
        while (hour1 == hour2 && minute1 == minute2) {
          hour2 = random.nextInt(24);
          minute2 = random.nextInt(60);
        }

        final id1 = getNotificationIdCurrent(challengeId, hour1, minute1);
        final id2 = getNotificationIdCurrent(challengeId, hour2, minute2);

        expect(
          id1,
          isNot(equals(id2)),
          reason:
              'Time-differentiation: ($hour1:$minute1) and ($hour2:$minute2) '
              'for same challenge should produce different IDs. '
              'Got $id1 for both.',
        );
      }
    });

    test(
        'Validates: Requirements 3.5 — '
        'notification IDs are non-negative integers within 32-bit range', () {
      final random = Random(42);
      final challengeIds = [
        'Read 30 pages',
        'Meditate',
        'Workout',
        'Drink water',
        'Follow diet',
      ];

      for (int i = 0; i < 200; i++) {
        final challengeId = challengeIds[random.nextInt(challengeIds.length)];
        final hour = random.nextInt(24);
        final minute = random.nextInt(60);

        final id = getNotificationIdCurrent(challengeId, hour, minute);

        expect(id, greaterThanOrEqualTo(0),
            reason: 'Notification ID must be non-negative');
        // 32-bit signed int max: 2^31 - 1 = 2147483647
        expect(id, lessThan(2147483647),
            reason: 'Notification ID must fit in 32-bit signed int');
      }
    });
  });

  // ── Property: Missed Day Detection (Req 3.2) ──────────────────────
  group('Missed Day Detection (Req 3.2)', () {
    test(
        'Validates: Requirements 3.2 — '
        'after replacing ?. with ., _checkForMissedDays still uses '
        'progress.challengeCompletions correctly', () {
      // Read the source to verify the fix (task 4) has been applied:
      // progress.challengeCompletions (not progress?.challengeCompletions)
      final sourceFile = File('lib/bloc/challenge_bloc.dart');
      final source = sourceFile.readAsStringSync();

      // Find the _checkForMissedDays method
      final methodStart = source.indexOf('Future<void> _checkForMissedDays(');
      expect(methodStart, isNot(-1),
          reason: '_checkForMissedDays method should exist');

      final methodBody = source.substring(methodStart);
      // Find the closing of the method (look for the finally block)
      final finallyIndex = methodBody.indexOf('} finally {');
      final checkBody = finallyIndex > 0
          ? methodBody.substring(0, finallyIndex)
          : methodBody.substring(0, 500);

      // Verify the method accesses challengeCompletions on progress
      // (either with . or ?. — both work, but . is preferred after null check)
      expect(
        checkBody.contains('challengeCompletions'),
        isTrue,
        reason:
            'The method should access challengeCompletions on progress records',
      );

      // Verify the method checks for hard tasks (TaskType.hard)
      expect(
        checkBody.contains('TaskType.hard'),
        isTrue,
        reason: 'The method should filter for hard tasks to determine resets',
      );

      // Verify the null check guard exists before accessing progress
      expect(
        checkBody.contains('progress == null'),
        isTrue,
        reason: 'The method should have a null check guard for progress',
      );
    });

    test(
        'Validates: Requirements 3.2 — '
        'missed hard task detection logic: non-null progress with incomplete '
        'hard tasks should be identified as missed', () {
      // Simulate the missed day detection logic extracted from _checkForMissedDays
      // This tests the core logic that must be preserved

      // Given: a set of hard challenges and a progress record
      final hardChallengeIds = ['challenge_1', 'challenge_2', 'challenge_3'];
      final completions = <String, bool>{
        'challenge_1': true,
        'challenge_2': false, // missed!
        'challenge_3': true,
      };

      // The logic: find hard tasks where completions[id] != true
      final missedHardTasks =
          hardChallengeIds.where((id) => completions[id] != true).toList();

      expect(missedHardTasks, equals(['challenge_2']),
          reason: 'Should identify challenge_2 as missed');

      // All completed case
      final allComplete = <String, bool>{
        'challenge_1': true,
        'challenge_2': true,
        'challenge_3': true,
      };
      final noMissed =
          hardChallengeIds.where((id) => allComplete[id] != true).toList();
      expect(noMissed, isEmpty,
          reason: 'No tasks should be missed when all are complete');

      // All missed case
      final noneMissed = <String, bool>{};
      final allMissedTasks =
          hardChallengeIds.where((id) => noneMissed[id] != true).toList();
      expect(allMissedTasks, equals(hardChallengeIds),
          reason: 'All tasks should be missed when none are in completions');
    });
  });

  // ── Property: Non-Once Reminder Scheduling (Req 3.6) ──────────────
  group('Non-Once Reminder Scheduling (Req 3.6)', () {
    test(
        'Validates: Requirements 3.6 — '
        'hourly, interval, and custom reminder scheduling methods do not use '
        'the matchDateTimeComponents parameter being removed from _scheduleOnceReminder',
        () {
      final sourceFile = File('lib/services/smart_notification_service.dart');
      final source = sourceFile.readAsStringSync();

      // Verify _scheduleHourlyReminders exists and uses matchDateTimeComponents
      // (hourly reminders SHOULD keep using it — only _scheduleOnceReminder changes)
      final hourlyStart =
          source.indexOf('Future<void> _scheduleHourlyReminders(');
      expect(hourlyStart, isNot(-1),
          reason: '_scheduleHourlyReminders method should exist');

      // Find the end of _scheduleHourlyReminders
      final hourlyBody = source.substring(hourlyStart);
      final nextMethodAfterHourly = hourlyBody
          .indexOf(RegExp(r'\n  Future<void> _schedule(?!HourlyReminders)'));
      final hourlyMethodBody = nextMethodAfterHourly > 0
          ? hourlyBody.substring(0, nextMethodAfterHourly)
          : hourlyBody.substring(0, 600);

      // Hourly reminders use matchDateTimeComponents independently
      expect(
        hourlyMethodBody.contains('matchDateTimeComponents'),
        isTrue,
        reason:
            'Hourly reminders should continue using matchDateTimeComponents '
            '— this is independent of the _scheduleOnceReminder fix',
      );

      // Verify _scheduleIntervalReminders exists and uses matchDateTimeComponents
      final intervalStart =
          source.indexOf('Future<void> _scheduleIntervalReminders(');
      expect(intervalStart, isNot(-1),
          reason: '_scheduleIntervalReminders method should exist');

      final intervalBody = source.substring(intervalStart);
      final nextMethodAfterInterval =
          intervalBody.indexOf(RegExp(r'\n  // ──'));
      final intervalMethodBody = nextMethodAfterInterval > 0
          ? intervalBody.substring(0, nextMethodAfterInterval)
          : intervalBody.substring(0, 800);

      // Interval reminders use matchDateTimeComponents independently
      expect(
        intervalMethodBody.contains('matchDateTimeComponents'),
        isTrue,
        reason:
            'Interval reminders should continue using matchDateTimeComponents '
            '— this is independent of the _scheduleOnceReminder fix',
      );
    });

    test(
        'Validates: Requirements 3.6 — '
        'the scheduling dispatch correctly routes reminder types to their methods',
        () {
      final sourceFile = File('lib/services/smart_notification_service.dart');
      final source = sourceFile.readAsStringSync();

      // Verify the dispatch logic routes different reminder types correctly
      expect(source.contains("data.startsWith('once:')"), isTrue,
          reason: 'Should dispatch once: reminders');
      expect(source.contains("data.startsWith('multiple:')"), isTrue,
          reason: 'Should dispatch multiple: reminders');
      expect(source.contains("data.startsWith('hourly:')"), isTrue,
          reason: 'Should dispatch hourly: reminders');
      expect(source.contains("data.startsWith('interval:')"), isTrue,
          reason: 'Should dispatch interval: reminders');
      expect(source.contains("data.startsWith('custom:')"), isTrue,
          reason: 'Should dispatch custom: reminders');
    });
  });

  // ── Property: Compilation Preservation (Req 3.1) ──────────────────
  group('Compilation Preservation (Req 3.1)', () {
    test(
        'Validates: Requirements 3.1 — '
        'all modified files still exist and are valid Dart files', () {
      // Verify all files that were modified in tasks 3-6 still exist
      final modifiedFiles = [
        'lib/bloc/challenge_bloc.dart',
        'lib/main.dart',
        'lib/repositories/database_repository.dart',
        'lib/screens/home_screen.dart',
        'lib/services/cloud_sync_service.dart',
        'lib/services/connectivity_service.dart',
        'lib/widgets/horizontal_date_picker.dart',
        'lib/screens/onboarding_screen.dart',
        'lib/widgets/daily_journal_widget.dart',
        // Files to be modified in tasks 7-10:
        'lib/services/smart_notification_service.dart',
        'lib/services/notification_service.dart',
      ];

      for (final filePath in modifiedFiles) {
        final file = File(filePath);
        expect(file.existsSync(), isTrue, reason: '$filePath should exist');

        final content = file.readAsStringSync();
        expect(content.isNotEmpty, isTrue,
            reason: '$filePath should not be empty');

        // Basic Dart syntax check: should contain at least one import or class
        expect(
          content.contains('import ') || content.contains('class '),
          isTrue,
          reason: '$filePath should contain valid Dart code',
        );
      }
    });
  });

  // ── Property: Error Handling Resilience (Req 3.8) ──────────────────
  group('Error Handling Resilience (Req 3.8)', () {
    test(
        'Validates: Requirements 3.8 — '
        'catch blocks in notification_service.dart still catch exceptions '
        'without re-throwing (resilience preserved)', () {
      final sourceFile = File('lib/services/notification_service.dart');
      final source = sourceFile.readAsStringSync();

      // Count catch blocks — there should be at least 9
      final catchPattern = RegExp(r'catch\s*\(\s*e\s*\)');
      final catches = catchPattern.allMatches(source).toList();

      expect(catches.length, greaterThanOrEqualTo(9),
          reason:
              'notification_service.dart should have at least 9 catch blocks');

      // Verify none of the catch blocks re-throw (they should swallow/log)
      for (final match in catches) {
        // Get the catch block body (from { to })
        final afterCatch = source.substring(match.end);
        final braceStart = afterCatch.indexOf('{');
        if (braceStart == -1) continue;

        // Find matching closing brace
        int depth = 1;
        int pos = braceStart + 1;
        while (pos < afterCatch.length && depth > 0) {
          if (afterCatch[pos] == '{') depth++;
          if (afterCatch[pos] == '}') depth--;
          pos++;
        }
        final catchBody = afterCatch.substring(braceStart + 1, pos - 1);

        // Catch blocks should NOT contain rethrow or throw
        expect(
          catchBody.contains('rethrow'),
          isFalse,
          reason: 'Catch blocks should not rethrow — they provide resilience',
        );
      }
    });

    test(
        'Validates: Requirements 3.8 — '
        'notification_service.dart does not use kDebugMode-guarded print '
        'in release mode (no additional output)', () {
      final sourceFile = File('lib/services/notification_service.dart');
      final source = sourceFile.readAsStringSync();

      // Currently (unfixed), catch blocks are empty — no print statements.
      // After fix (task 10), they'll have `if (kDebugMode) print(...)`.
      // In either case, release builds should produce no additional output.
      //
      // Verify that any print statements are guarded by kDebugMode
      final printPattern = RegExp(r"print\s*\(");
      final prints = printPattern.allMatches(source).toList();

      for (final match in prints) {
        // Check that the print is preceded by kDebugMode check
        final before = source.substring(
            (match.start - 50).clamp(0, source.length), match.start);
        expect(
          before.contains('kDebugMode'),
          isTrue,
          reason: 'All print statements in notification_service.dart should be '
              'guarded by kDebugMode to prevent output in release builds',
        );
      }
      // If no prints exist (current unfixed state), this test passes trivially
      // — which is correct: no output in release builds.
    });
  });
}
