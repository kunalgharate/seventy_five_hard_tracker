import 'package:equatable/equatable.dart';

/// Immutable snapshot of a user's discipline metrics at a point in time.
class DisciplineScoreModel extends Equatable {
  /// Overall discipline score 0–100.
  final double disciplineScore;

  /// Number of consecutive fully-completed days ending today.
  final int currentStreak;

  /// Longest consecutive streak ever recorded in the session.
  final int longestStreak;

  /// Percentage of days completed in the last 7 days (0–100).
  final double weeklyConsistency;

  /// Percentage of days completed in the last 30 days (0–100).
  final double monthlyConsistency;

  /// Total tasks completed across all tracked days.
  final int totalTasksCompleted;

  /// Total tasks that were available across all tracked days.
  final int totalTasksAvailable;

  /// Number of days where at least one task was missed.
  final int missedDays;

  /// Number of days that were fully completed.
  final int completedDays;

  /// Total days tracked so far.
  final int totalDaysTracked;

  /// Current consecutive missed days (0–3).
  /// Resets to 0 when a day is completed.
  /// At 3 the streak ends and a penalty is applied.
  final int currentWarnings;

  /// How many times the streak has been broken by 3 consecutive misses.
  final int streakBreaks;

  /// Total points deducted from streak breaks (15 pts per break).
  final double streakBreakPenalty;

  const DisciplineScoreModel({
    required this.disciplineScore,
    required this.currentStreak,
    required this.longestStreak,
    required this.weeklyConsistency,
    required this.monthlyConsistency,
    required this.totalTasksCompleted,
    required this.totalTasksAvailable,
    required this.missedDays,
    required this.completedDays,
    required this.totalDaysTracked,
    required this.currentWarnings,
    required this.streakBreaks,
    required this.streakBreakPenalty,
  });

  static const empty = DisciplineScoreModel(
    disciplineScore: 0,
    currentStreak: 0,
    longestStreak: 0,
    weeklyConsistency: 0,
    monthlyConsistency: 0,
    totalTasksCompleted: 0,
    totalTasksAvailable: 0,
    missedDays: 0,
    completedDays: 0,
    totalDaysTracked: 0,
    currentWarnings: 0,
    streakBreaks: 0,
    streakBreakPenalty: 0,
  );

  /// Max warnings before streak break.
  static const int maxWarnings = 3;

  /// Points deducted per streak break.
  static const double penaltyPerBreak = 15.0;

  /// Overall task completion rate (0–1).
  double get completionRate =>
      totalTasksAvailable == 0 ? 0 : totalTasksCompleted / totalTasksAvailable;

  /// Whether the user is currently in warning territory.
  bool get hasActiveWarnings => currentWarnings > 0;

  /// Whether the next miss will trigger a streak break + penalty.
  bool get onFinalWarning => currentWarnings == maxWarnings - 1;

  /// Warning label shown in UI.
  String get warningLabel {
    if (currentWarnings == 0) return '';
    return '⚠️ Warning $currentWarnings/$maxWarnings';
  }

  /// Letter grade derived from the discipline score.
  String get grade {
    if (disciplineScore >= 90) return 'S';
    if (disciplineScore >= 80) return 'A';
    if (disciplineScore >= 70) return 'B';
    if (disciplineScore >= 60) return 'C';
    if (disciplineScore >= 50) return 'D';
    return 'F';
  }

  /// Human-readable label for the score tier.
  String get tier {
    if (disciplineScore >= 90) return 'Elite';
    if (disciplineScore >= 75) return 'Strong';
    if (disciplineScore >= 60) return 'Building';
    if (disciplineScore >= 40) return 'Developing';
    return 'Starting Out';
  }

  @override
  List<Object?> get props => [
        disciplineScore,
        currentStreak,
        longestStreak,
        weeklyConsistency,
        monthlyConsistency,
        totalTasksCompleted,
        totalTasksAvailable,
        missedDays,
        completedDays,
        totalDaysTracked,
        currentWarnings,
        streakBreaks,
        streakBreakPenalty,
      ];
}
