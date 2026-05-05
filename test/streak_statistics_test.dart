/// Property Test: Streak and statistics invariants
///
/// For any RegularTask with a completion history of length N, the
/// calculateRegularTaskStats function SHALL produce results where:
/// (a) completed + missed == total == N,
/// (b) bestStreak >= currentStreak,
/// (c) currentStreak equals the length of the longest suffix of
///     consecutive true values, and
/// (d) bestStreak equals the length of the longest consecutive run
///     of true values.
///
/// **Validates: Requirements 6.1, 6.2, 6.3, 6.4**
library streak_statistics_test;

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/models/regular_task_completion.dart';
import 'package:seventy_five_hard_tracker/utils/regular_task_stats.dart';

/// Generates a random list of booleans representing a completion history.
List<bool> _randomBoolSequence(Random rng, {int maxLength = 50}) {
  final length = rng.nextInt(maxLength + 1); // 0..maxLength inclusive
  return List.generate(length, (_) => rng.nextBool());
}

/// Builds a list of RegularTaskCompletion objects from a boolean sequence.
/// Each entry represents one day, starting from a base date.
List<RegularTaskCompletion> _buildCompletions(
  String taskId,
  List<bool> sequence,
) {
  final baseDate = DateTime(2024, 1, 1);
  return List.generate(sequence.length, (i) {
    return RegularTaskCompletion(
      date: baseDate.add(Duration(days: i)),
      taskCompletions: {taskId: sequence[i]},
    );
  });
}

/// Reference implementation: compute the longest suffix of consecutive true values.
int _expectedCurrentStreak(List<bool> sequence) {
  int streak = 0;
  for (int i = sequence.length - 1; i >= 0; i--) {
    if (sequence[i]) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

/// Reference implementation: compute the longest consecutive run of true values.
int _expectedBestStreak(List<bool> sequence) {
  int best = 0;
  int current = 0;
  for (final value in sequence) {
    if (value) {
      current++;
      if (current > best) best = current;
    } else {
      current = 0;
    }
  }
  return best;
}

void main() {
  group('Property 6: Streak and statistics invariants', () {
    test(
      'Validates: Requirements 6.1, 6.2, 6.3, 6.4 — '
      'completed + missed == total == N for random completion histories',
      () {
        final rng = Random(42);
        const taskId = 'test-task';

        for (int i = 0; i < 200; i++) {
          final sequence = _randomBoolSequence(rng);
          final completions = _buildCompletions(taskId, sequence);
          final stats = calculateRegularTaskStats(taskId, completions);

          expect(stats.completed + stats.missed, equals(stats.total),
              reason: 'completed + missed != total at iteration $i, '
                  'sequence=$sequence');
          expect(stats.total, equals(sequence.length),
              reason: 'total != N at iteration $i, '
                  'expected=${sequence.length}, got=${stats.total}');
        }
      },
    );

    test(
      'Validates: Requirements 6.1, 6.2, 6.3, 6.4 — '
      'bestStreak >= currentStreak for random completion histories',
      () {
        final rng = Random(99);
        const taskId = 'test-task';

        for (int i = 0; i < 200; i++) {
          final sequence = _randomBoolSequence(rng);
          final completions = _buildCompletions(taskId, sequence);
          final stats = calculateRegularTaskStats(taskId, completions);

          expect(stats.bestStreak, greaterThanOrEqualTo(stats.currentStreak),
              reason: 'bestStreak < currentStreak at iteration $i, '
                  'best=${stats.bestStreak}, current=${stats.currentStreak}, '
                  'sequence=$sequence');
        }
      },
    );

    test(
      'Validates: Requirements 6.1, 6.2, 6.3, 6.4 — '
      'currentStreak equals the longest suffix of consecutive true values',
      () {
        final rng = Random(7);
        const taskId = 'test-task';

        for (int i = 0; i < 200; i++) {
          final sequence = _randomBoolSequence(rng);
          final completions = _buildCompletions(taskId, sequence);
          final stats = calculateRegularTaskStats(taskId, completions);
          final expected = _expectedCurrentStreak(sequence);

          expect(stats.currentStreak, equals(expected),
              reason: 'currentStreak mismatch at iteration $i, '
                  'expected=$expected, got=${stats.currentStreak}, '
                  'sequence=$sequence');
        }
      },
    );

    test(
      'Validates: Requirements 6.1, 6.2, 6.3, 6.4 — '
      'bestStreak equals the longest consecutive run of true values',
      () {
        final rng = Random(13);
        const taskId = 'test-task';

        for (int i = 0; i < 200; i++) {
          final sequence = _randomBoolSequence(rng);
          final completions = _buildCompletions(taskId, sequence);
          final stats = calculateRegularTaskStats(taskId, completions);
          final expected = _expectedBestStreak(sequence);

          expect(stats.bestStreak, equals(expected),
              reason: 'bestStreak mismatch at iteration $i, '
                  'expected=$expected, got=${stats.bestStreak}, '
                  'sequence=$sequence');
        }
      },
    );

    test(
      'Validates: Requirements 6.1, 6.2, 6.3, 6.4 — '
      'completed count equals number of true values in sequence',
      () {
        final rng = Random(21);
        const taskId = 'test-task';

        for (int i = 0; i < 200; i++) {
          final sequence = _randomBoolSequence(rng);
          final completions = _buildCompletions(taskId, sequence);
          final stats = calculateRegularTaskStats(taskId, completions);
          final expectedCompleted = sequence.where((v) => v).length;
          final expectedMissed = sequence.where((v) => !v).length;

          expect(stats.completed, equals(expectedCompleted),
              reason: 'completed count mismatch at iteration $i, '
                  'expected=$expectedCompleted, got=${stats.completed}');
          expect(stats.missed, equals(expectedMissed),
              reason: 'missed count mismatch at iteration $i, '
                  'expected=$expectedMissed, got=${stats.missed}');
        }
      },
    );

    test(
      'Validates: Requirements 6.1, 6.2, 6.3, 6.4 — '
      'empty completion history produces all-zero stats',
      () {
        const taskId = 'test-task';
        final stats = calculateRegularTaskStats(taskId, []);

        expect(stats.completed, equals(0));
        expect(stats.missed, equals(0));
        expect(stats.currentStreak, equals(0));
        expect(stats.bestStreak, equals(0));
        expect(stats.total, equals(0));
      },
    );

    test(
      'Validates: Requirements 6.1, 6.2, 6.3, 6.4 — '
      'all-true sequence: currentStreak == bestStreak == N',
      () {
        final rng = Random(55);
        const taskId = 'test-task';

        for (int i = 0; i < 50; i++) {
          final length = rng.nextInt(30) + 1;
          final sequence = List.filled(length, true);
          final completions = _buildCompletions(taskId, sequence);
          final stats = calculateRegularTaskStats(taskId, completions);

          expect(stats.currentStreak, equals(length),
              reason: 'all-true: currentStreak != N at iteration $i');
          expect(stats.bestStreak, equals(length),
              reason: 'all-true: bestStreak != N at iteration $i');
          expect(stats.completed, equals(length));
          expect(stats.missed, equals(0));
        }
      },
    );

    test(
      'Validates: Requirements 6.1, 6.2, 6.3, 6.4 — '
      'all-false sequence: currentStreak == bestStreak == 0',
      () {
        final rng = Random(77);
        const taskId = 'test-task';

        for (int i = 0; i < 50; i++) {
          final length = rng.nextInt(30) + 1;
          final sequence = List.filled(length, false);
          final completions = _buildCompletions(taskId, sequence);
          final stats = calculateRegularTaskStats(taskId, completions);

          expect(stats.currentStreak, equals(0),
              reason: 'all-false: currentStreak != 0 at iteration $i');
          expect(stats.bestStreak, equals(0),
              reason: 'all-false: bestStreak != 0 at iteration $i');
          expect(stats.completed, equals(0));
          expect(stats.missed, equals(length));
        }
      },
    );

    test(
      'Validates: Requirements 6.1, 6.2, 6.3, 6.4 — '
      'shuffled completions produce same result (sort invariance)',
      () {
        final rng = Random(33);
        const taskId = 'test-task';

        for (int i = 0; i < 100; i++) {
          final sequence = _randomBoolSequence(rng, maxLength: 30);
          if (sequence.isEmpty) continue;

          final completions = _buildCompletions(taskId, sequence);
          final statsOrdered = calculateRegularTaskStats(taskId, completions);

          // Shuffle the completions list
          final shuffled = [...completions]..shuffle(rng);
          final statsShuffled = calculateRegularTaskStats(taskId, shuffled);

          expect(statsShuffled.completed, equals(statsOrdered.completed),
              reason: 'completed differs after shuffle at iteration $i');
          expect(statsShuffled.missed, equals(statsOrdered.missed),
              reason: 'missed differs after shuffle at iteration $i');
          expect(
              statsShuffled.currentStreak, equals(statsOrdered.currentStreak),
              reason: 'currentStreak differs after shuffle at iteration $i');
          expect(statsShuffled.bestStreak, equals(statsOrdered.bestStreak),
              reason: 'bestStreak differs after shuffle at iteration $i');
          expect(statsShuffled.total, equals(statsOrdered.total),
              reason: 'total differs after shuffle at iteration $i');
        }
      },
    );

    test(
      'Validates: Requirements 6.1, 6.2, 6.3, 6.4 — '
      'taskId not present in completions counts all as missed',
      () {
        final rng = Random(88);
        const taskId = 'nonexistent-task';

        for (int i = 0; i < 50; i++) {
          final length = rng.nextInt(20) + 1;
          final baseDate = DateTime(2024, 1, 1);
          final completions = List.generate(length, (j) {
            return RegularTaskCompletion(
              date: baseDate.add(Duration(days: j)),
              taskCompletions: {'other-task': rng.nextBool()},
            );
          });

          final stats = calculateRegularTaskStats(taskId, completions);

          expect(stats.completed, equals(0),
              reason:
                  'nonexistent taskId should have 0 completed at iteration $i');
          expect(stats.missed, equals(length),
              reason:
                  'nonexistent taskId should have all missed at iteration $i');
          expect(stats.currentStreak, equals(0));
          expect(stats.bestStreak, equals(0));
          expect(stats.total, equals(length));
        }
      },
    );
  });
}
