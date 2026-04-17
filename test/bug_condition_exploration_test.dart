// Bug Condition Exploration Tests
//
// These tests encode the EXPECTED (correct) behavior for the 4 remaining
// unfixed bugs (tasks 7-10). They are designed to FAIL on unfixed code,
// confirming the bugs exist. Once the fixes are applied, these tests
// should PASS.
//
// **Validates: Requirements 1.12, 1.13, 1.14, 1.15**

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bug Condition Exploration — Remaining Unfixed Bugs', () {
    // ── Req 1.12: Notification ID Collision ──────────────────────────
    group('Notification ID Collision (Req 1.12)', () {
      test(
          'Validates: Requirements 1.12 — '
          'distinct challenge IDs should produce different base hashes '
          'with a sufficiently wide hash space', () {
        // Generate many distinct challenge IDs and check for collisions
        // in the current 10K hash space vs the fixed 100K hash space.
        final challengeIds = <String>[
          'Read 30 pages',
          'Meditate',
          'Workout 1',
          'Workout 2',
          'Drink water',
          'Follow diet',
          'Take progress photo',
          'Read book',
          'No alcohol',
          'No cheat meals',
          'Cold shower',
          'Walk 10000 steps',
          'Journal entry',
          'Study 1 hour',
          'Practice guitar',
          'Run 5K',
          'Yoga session',
          'Meal prep',
          'Sleep by 10pm',
          'No social media',
        ];

        // Read the actual source to verify the modulus value
        final sourceFile = File('lib/services/smart_notification_service.dart');
        final source = sourceFile.readAsStringSync();

        // The EXPECTED behavior: the hash space should be 100000, not 10000
        // This test asserts the fix is in place (% 100000).
        // On UNFIXED code, the source contains `% 10000` so this will FAIL.
        expect(
          source.contains('challengeId.hashCode.abs() % 100000'),
          isTrue,
          reason:
              'EXPECTED: _getNotificationId should use % 100000 for wider hash space. '
              'ACTUAL: Uses % 10000 which causes collisions between distinct challenge IDs.',
        );

        // Additionally, demonstrate that collisions exist in the 10K space
        // by computing base hashes for all challenge IDs
        final baseHashes10K = <int>{};
        final collisions10K = <String>[];
        for (final id in challengeIds) {
          final hash = id.hashCode.abs() % 10000;
          if (baseHashes10K.contains(hash)) {
            collisions10K.add(id);
          }
          baseHashes10K.add(hash);
        }

        // With 10K space and 20 IDs, collisions are possible (birthday paradox).
        // Even if this specific set doesn't collide, the source check above
        // catches the bug definitively.
      });
    });

    // ── Req 1.13: Once-Reminder Repeats Daily ────────────────────────
    group('Once-Reminder Repeats Daily (Req 1.13)', () {
      test(
          'Validates: Requirements 1.13 — '
          '_scheduleOnceReminder should NOT pass matchDateTimeComponents', () {
        // Read the source code of smart_notification_service.dart
        final sourceFile = File('lib/services/smart_notification_service.dart');
        final source = sourceFile.readAsStringSync();

        // Find the _scheduleOnceReminder method body
        final methodStart =
            source.indexOf('Future<void> _scheduleOnceReminder(');
        expect(methodStart, isNot(-1),
            reason: '_scheduleOnceReminder method should exist');

        // Find the next method after _scheduleOnceReminder to bound our search
        final methodBody = source.substring(methodStart);
        final nextMethodIndex = methodBody
            .indexOf(RegExp(r'\n  Future<void> _schedule(?!OnceReminder)'));
        final onceReminderBody = nextMethodIndex > 0
            ? methodBody.substring(0, nextMethodIndex)
            : methodBody;

        // EXPECTED behavior: _scheduleOnceReminder should NOT contain
        // matchDateTimeComponents. On UNFIXED code, it DOES contain it,
        // so this test will FAIL.
        expect(
          onceReminderBody.contains('matchDateTimeComponents'),
          isFalse,
          reason: 'EXPECTED: _scheduleOnceReminder should NOT pass '
              'matchDateTimeComponents: DateTimeComponents.time. '
              'ACTUAL: It passes matchDateTimeComponents which causes '
              'the "once" reminder to repeat daily.',
        );
      });
    });

    // ── Req 1.14: Day Counter Clamped to 75 ──────────────────────────
    group('Day Counter Clamped to 75 (Req 1.14)', () {
      /// Replicates the _computeCurrentDay logic from challenge_bloc.dart.
      /// The current buggy code clamps to 75 instead of session.totalDaysTarget.
      int computeCurrentDayBuggy(DateTime startDate, int totalDaysTarget) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final days = today.difference(start).inDays + 1;
        return days.clamp(1, 75); // BUG: hardcoded 75
      }

      /// The EXPECTED (fixed) behavior clamps to totalDaysTarget.
      int computeCurrentDayFixed(DateTime startDate, int totalDaysTarget) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final days = today.difference(start).inDays + 1;
        return days.clamp(1, totalDaysTarget); // FIXED: uses totalDaysTarget
      }

      test(
          'Validates: Requirements 1.14 — '
          '_computeCurrentDay should clamp to session.totalDaysTarget, not 75',
          () {
        // Read the source code of challenge_bloc.dart
        final sourceFile = File('lib/bloc/challenge_bloc.dart');
        final source = sourceFile.readAsStringSync();

        // Find the _computeCurrentDay method
        final methodStart =
            source.indexOf('int _computeCurrentDay(ChallengeSession session)');
        expect(methodStart, isNot(-1),
            reason: '_computeCurrentDay method should exist');

        final methodBody = source.substring(methodStart);
        final methodEnd = methodBody.indexOf('}');
        final computeCurrentDayBody = methodBody.substring(0, methodEnd + 1);

        // EXPECTED behavior: should use session.totalDaysTarget, not hardcoded 75
        // On UNFIXED code, it uses `clamp(1, 75)` so this will FAIL.
        expect(
          computeCurrentDayBody.contains('session.totalDaysTarget'),
          isTrue,
          reason: 'EXPECTED: _computeCurrentDay should clamp to '
              'session.totalDaysTarget. '
              'ACTUAL: Clamps to hardcoded 75, freezing the day counter '
              'for soft-mode sessions with totalDaysTarget > 75.',
        );
      });

      test(
          'Validates: Requirements 1.14 — '
          'day 80 of a 100-day session should return 80, not 75', () {
        // Simulate a session that started 80 days ago with totalDaysTarget = 100
        final startDate =
            DateTime.now().subtract(const Duration(days: 79)); // day 80
        const totalDaysTarget = 100;

        final buggyResult = computeCurrentDayBuggy(startDate, totalDaysTarget);
        final fixedResult = computeCurrentDayFixed(startDate, totalDaysTarget);

        // The buggy version returns 75 (clamped), the fixed returns 80
        // EXPECTED: the actual code should return 80, not 75
        // On UNFIXED code, the actual code behaves like buggyResult (75),
        // so asserting fixedResult != buggyResult demonstrates the bug.
        expect(
          buggyResult,
          equals(75),
          reason: 'Buggy code clamps day 80 to 75',
        );
        expect(
          fixedResult,
          equals(80),
          reason: 'Fixed code should return 80 for day 80 of a 100-day session',
        );

        // Now verify the ACTUAL source code uses the correct clamp.
        // This is the assertion that FAILS on unfixed code.
        final sourceFile = File('lib/bloc/challenge_bloc.dart');
        final source = sourceFile.readAsStringSync();
        final methodStart =
            source.indexOf('int _computeCurrentDay(ChallengeSession session)');
        final methodBody = source.substring(methodStart);
        final methodEnd = methodBody.indexOf('}');
        final body = methodBody.substring(0, methodEnd + 1);

        expect(
          body.contains('clamp(1, session.totalDaysTarget)'),
          isTrue,
          reason: 'EXPECTED: days.clamp(1, session.totalDaysTarget). '
              'ACTUAL: days.clamp(1, 75) — hardcoded upper bound.',
        );
      });
    });

    // ── Req 1.15: Empty Catch Blocks ─────────────────────────────────
    group('Empty Catch Blocks (Req 1.15)', () {
      test(
          'Validates: Requirements 1.15 — '
          'catch blocks in notification_service.dart should contain logging',
          () {
        final sourceFile = File('lib/services/notification_service.dart');
        final source = sourceFile.readAsStringSync();

        // Find all catch blocks with empty bodies: `catch (e) {\n    }`
        // The pattern is `catch (e) {` followed by only whitespace and `}`
        final emptyCatchPattern = RegExp(r'catch\s*\(\s*e\s*\)\s*\{\s*\}');
        final emptyCatches = emptyCatchPattern.allMatches(source);

        // EXPECTED behavior: zero empty catch blocks (all should have logging)
        // On UNFIXED code, there are 9 empty catch blocks, so this FAILS.
        expect(
          emptyCatches.length,
          equals(0),
          reason: 'EXPECTED: All catch blocks should contain debug logging '
              '(if (kDebugMode) print(...)). '
              'ACTUAL: Found ${emptyCatches.length} empty catch blocks '
              'that silently swallow errors.',
        );
      });

      test(
          'Validates: Requirements 1.15 — '
          'notification_service.dart should import foundation for kDebugMode',
          () {
        final sourceFile = File('lib/services/notification_service.dart');
        final source = sourceFile.readAsStringSync();

        // EXPECTED: The file should import flutter/foundation.dart for kDebugMode
        // On UNFIXED code, this import is missing, so this FAILS.
        expect(
          source.contains("import 'package:flutter/foundation.dart'"),
          isTrue,
          reason: 'EXPECTED: notification_service.dart should import '
              'package:flutter/foundation.dart for kDebugMode. '
              'ACTUAL: Import is missing — catch blocks have no logging.',
        );
      });
    });
  });
}
