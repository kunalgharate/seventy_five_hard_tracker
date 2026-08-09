import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/domain/services/review_scoring_engine.dart';

void main() {
  const engine = ReviewScoringEngine();
  final rng = Random(42); // fixed seed for reproducibility

  group('ReviewScoringEngine — Property-Based Tests', () {
    // Property 13: Streak increment on approval (75 Hard)
    test('Property: approved always increments streak by exactly 1', () {
      for (int i = 0; i < 200; i++) {
        final currentStreak = rng.nextInt(500) + 1; // 1–500
        final result = engine.compute75HardStreak(currentStreak, 'approved');
        expect(result, equals(currentStreak + 1),
            reason:
                'approved should always increment: $currentStreak → ${currentStreak + 1}');
      }
    });

    // Property 12: Rejected resets to 1
    test('Property: rejected always resets streak to 1', () {
      for (int i = 0; i < 200; i++) {
        final currentStreak = rng.nextInt(500) + 1;
        final result = engine.compute75HardStreak(currentStreak, 'rejected');
        expect(result, equals(1),
            reason:
                'rejected should always reset to 1, got $result for streak $currentStreak');
      }
    });

    // Property 12: Expired treated identically to rejected
    test('Property: expired treated identically to rejected', () {
      for (int i = 0; i < 200; i++) {
        final currentStreak = rng.nextInt(500) + 1;
        final rejected = engine.compute75HardStreak(currentStreak, 'rejected');
        final expired = engine.compute75HardStreak(currentStreak, 'expired');
        expect(expired, equals(rejected),
            reason: 'expired must equal rejected for streak=$currentStreak');
      }
    });

    // Property 14: Completion percentage formula
    test('Property: percentage = approved/total × 100', () {
      for (int i = 0; i < 100; i++) {
        final length = rng.nextInt(50) + 1;
        final outcomes = List.generate(length, (_) {
          final r = rng.nextInt(3);
          return r == 0 ? 'approved' : (r == 1 ? 'rejected' : 'expired');
        });

        final approvedCount = outcomes.where((o) => o == 'approved').length;
        final expected = (approvedCount / outcomes.length) * 100;
        final result = engine.computeCompletionPercentage(outcomes);

        expect(result, closeTo(expected, 0.001),
            reason: 'percentage should be $expected but got $result');
      }
    });

    // Edge: empty outcomes = 0%
    test('Property: empty outcomes returns 0%', () {
      expect(engine.computeCompletionPercentage([]), equals(0.0));
    });

    // Property 15: Regular streak = consecutive approved from end
    test('Property: streak counts consecutive approved from most recent', () {
      for (int i = 0; i < 100; i++) {
        final length = rng.nextInt(30) + 1;
        final outcomes = List.generate(length, (_) {
          return rng.nextBool() ? 'approved' : 'rejected';
        });

        // Manually compute expected
        int expected = 0;
        for (final o in outcomes.reversed) {
          if (o == 'approved') {
            expected++;
          } else {
            break;
          }
        }

        final result = engine.computeRegularStreak(outcomes);
        expect(result, equals(expected),
            reason: 'streak should be $expected for $outcomes');
      }
    });

    // Property: all approved = streak equals length
    test('Property: all approved outcomes gives streak = length', () {
      for (int i = 1; i <= 100; i++) {
        final outcomes = List.filled(i, 'approved');
        expect(engine.computeRegularStreak(outcomes), equals(i));
      }
    });

    // Property: isRegularDayComplete only true for approved
    test('Property: only approved returns true for isRegularDayComplete', () {
      expect(engine.isRegularDayComplete('approved'), isTrue);
      expect(engine.isRegularDayComplete('rejected'), isFalse);
      expect(engine.isRegularDayComplete('expired'), isFalse);
      expect(engine.isRegularDayComplete('pending'), isFalse);
    });

    // Property: triggers75HardReset for rejected and expired only
    test('Property: triggers reset only for rejected/expired', () {
      expect(engine.triggers75HardReset('rejected'), isTrue);
      expect(engine.triggers75HardReset('expired'), isTrue);
      expect(engine.triggers75HardReset('approved'), isFalse);
      expect(engine.triggers75HardReset('pending'), isFalse);
    });

    // Property: terminal outcomes are immutable
    test('Property: approved/rejected/expired are terminal', () {
      expect(engine.isTerminalOutcome('approved'), isTrue);
      expect(engine.isTerminalOutcome('rejected'), isTrue);
      expect(engine.isTerminalOutcome('expired'), isTrue);
      expect(engine.isTerminalOutcome('pending'), isFalse);
      expect(engine.isTerminalOutcome('pendingReview'), isFalse);
    });
  });
}
