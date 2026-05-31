import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task_completion.dart';

/// Statistics for a regular task's completion history.
class RegularTaskStats {
  final int completed;
  final int missed;
  final int currentStreak;
  final int bestStreak;
  final int total;

  const RegularTaskStats({
    required this.completed,
    required this.missed,
    required this.currentStreak,
    required this.bestStreak,
    required this.total,
  });
}

/// Calculates streak and statistics for a regular task from its completion history.
///
/// For a given [taskId] and list of [completions], this function:
/// - Sorts completions by date ascending
/// - Counts completed and missed entries
/// - Computes currentStreak (longest suffix of consecutive true values)
/// - Computes bestStreak (longest consecutive run of true values)
///
/// Invariants:
/// - completed + missed == total == completions.length
/// - bestStreak >= currentStreak
RegularTaskStats calculateRegularTaskStats(
  String taskId,
  List<RegularTaskCompletion> completions,
) {
  final sorted = [...completions]..sort((a, b) => a.date.compareTo(b.date));

  int completed = 0;
  int missed = 0;
  int currentStreak = 0;
  int bestStreak = 0;
  int tempStreak = 0;

  for (final completion in sorted) {
    final done = completion.taskCompletions[taskId] ?? false;
    if (done) {
      completed++;
      tempStreak++;
      if (tempStreak > bestStreak) bestStreak = tempStreak;
    } else {
      missed++;
      tempStreak = 0;
    }
  }
  currentStreak = tempStreak;

  return RegularTaskStats(
    completed: completed,
    missed: missed,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    total: sorted.length,
  );
}
