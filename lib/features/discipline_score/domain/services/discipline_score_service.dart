import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import '../models/discipline_score_model.dart';

/// Pure calculation service — no Flutter, no Firestore, no BLoC.
///
/// ── Warning & Penalty System ──────────────────────────────────────
///
/// Each consecutive missed day adds 1 warning (max 3).
/// A completed day resets the warning counter to 0.
/// When warnings reach 3:
///   • The current streak is broken (reset to 0)
///   • A flat -15 pt penalty is applied to the score
///   • The streak-break counter increments
///   • Warnings reset to 0 and counting restarts
///
/// ── Score Formula (0–100) ─────────────────────────────────────────
///
///   40 pts  Task completion rate
///   30 pts  Current streak (30 days = full, linear below)
///   20 pts  Weekly consistency (last 7 days)
///  -10 pts  Missed-day ratio penalty (proportional)
///  -15 pts  Per streak break caused by 3 consecutive misses
class DisciplineScoreService {
  const DisciplineScoreService();

  DisciplineScoreModel calculate({
    required ChallengeSession session,
    required List<DailyProgress> progress,
  }) {
    if (progress.isEmpty) return DisciplineScoreModel.empty;

    final today = _dateOnly(DateTime.now());
    final startDate = _dateOnly(session.startDate);

    final progressMap = <DateTime, DailyProgress>{
      for (final p in progress) _dateOnly(p.date): p,
    };

    final daysElapsed = today.difference(startDate).inDays + 1;
    final trackedDays = daysElapsed.clamp(1, session.totalDaysTarget);

    // ── Task counts ──────────────────────────────────────────────
    int totalCompleted = 0;
    int totalAvailable = 0;
    int completedDays = 0;
    int missedDays = 0;

    final taskCount =
        session.challenges.where((c) => c.taskType != 'regular').length;

    for (int i = 0; i < trackedDays; i++) {
      final date = startDate.add(Duration(days: i));
      final p = progressMap[date];
      totalAvailable += taskCount;

      if (p == null) {
        missedDays++;
      } else {
        final done =
            p.challengeCompletions.values.where((v) => v == true).length;
        totalCompleted += done;
        if (p.isCompleted) {
          completedDays++;
        } else {
          missedDays++;
        }
      }
    }

    // ── Warning & streak-break scan ──────────────────────────────
    // Walk through every day chronologically, tracking consecutive misses.
    // Every 3rd consecutive miss = streak break + penalty.
    int streakBreaks = 0;
    int consecutiveMisses = 0; // resets on completion
    int currentWarnings = 0; // live warning count (last window)

    for (int i = 0; i < trackedDays; i++) {
      final date = startDate.add(Duration(days: i));
      final p = progressMap[date];
      final dayCompleted = p != null && p.isCompleted;

      if (dayCompleted) {
        consecutiveMisses = 0;
      } else {
        consecutiveMisses++;
        if (consecutiveMisses >= DisciplineScoreModel.maxWarnings) {
          streakBreaks++;
          consecutiveMisses = 0; // reset after penalty applied
        }
      }
    }

    // currentWarnings = how many consecutive misses are active RIGHT NOW
    // (i.e. at the end of the tracked window, before a break triggers)
    currentWarnings = consecutiveMisses;

    // ── Streaks ──────────────────────────────────────────────────
    final currentStreak = _computeCurrentStreak(
      startDate: startDate,
      trackedDays: trackedDays,
      progressMap: progressMap,
    );

    final longestStreak = _computeLongestStreak(
      startDate: startDate,
      trackedDays: trackedDays,
      progressMap: progressMap,
    );

    // ── Consistency ──────────────────────────────────────────────
    final weeklyConsistency = _computeConsistency(
      startDate: startDate,
      trackedDays: trackedDays,
      progressMap: progressMap,
      windowDays: 7,
    );

    final monthlyConsistency = _computeConsistency(
      startDate: startDate,
      trackedDays: trackedDays,
      progressMap: progressMap,
      windowDays: 30,
    );

    // ── Score ────────────────────────────────────────────────────
    final streakBreakPenalty =
        streakBreaks * DisciplineScoreModel.penaltyPerBreak;

    final score = _computeScore(
      completionRate: totalAvailable == 0 ? 0 : totalCompleted / totalAvailable,
      currentStreak: currentStreak,
      weeklyConsistency: weeklyConsistency,
      missedDays: missedDays,
      trackedDays: trackedDays,
      streakBreakPenalty: streakBreakPenalty,
    );

    return DisciplineScoreModel(
      disciplineScore: score,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      weeklyConsistency: weeklyConsistency,
      monthlyConsistency: monthlyConsistency,
      totalTasksCompleted: totalCompleted,
      totalTasksAvailable: totalAvailable,
      missedDays: missedDays,
      completedDays: completedDays,
      totalDaysTracked: trackedDays,
      currentWarnings: currentWarnings,
      streakBreaks: streakBreaks,
      streakBreakPenalty: streakBreakPenalty,
    );
  }

  // ── Private helpers ──────────────────────────────────────────────

  int _computeCurrentStreak({
    required DateTime startDate,
    required int trackedDays,
    required Map<DateTime, DailyProgress> progressMap,
  }) {
    int streak = 0;
    for (int i = trackedDays - 1; i >= 0; i--) {
      final date = startDate.add(Duration(days: i));
      final p = progressMap[date];
      if (p != null && p.isCompleted) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _computeLongestStreak({
    required DateTime startDate,
    required int trackedDays,
    required Map<DateTime, DailyProgress> progressMap,
  }) {
    int longest = 0;
    int current = 0;
    for (int i = 0; i < trackedDays; i++) {
      final date = startDate.add(Duration(days: i));
      final p = progressMap[date];
      if (p != null && p.isCompleted) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  double _computeConsistency({
    required DateTime startDate,
    required int trackedDays,
    required Map<DateTime, DailyProgress> progressMap,
    required int windowDays,
  }) {
    final window = trackedDays < windowDays ? trackedDays : windowDays;
    if (window == 0) return 0;
    int completed = 0;
    for (int i = trackedDays - window; i < trackedDays; i++) {
      final date = startDate.add(Duration(days: i));
      final p = progressMap[date];
      if (p != null && p.isCompleted) completed++;
    }
    return (completed / window) * 100;
  }

  /// Score formula:
  ///   40 pts  completion rate
  ///   30 pts  streak bonus
  ///   20 pts  weekly consistency
  ///  -10 pts  missed-day ratio penalty
  ///  -15 pts  per streak break (3 consecutive misses)
  double _computeScore({
    required double completionRate,
    required int currentStreak,
    required double weeklyConsistency,
    required int missedDays,
    required int trackedDays,
    required double streakBreakPenalty,
  }) {
    final completionPts = completionRate * 40;
    final streakPts = (currentStreak / 30).clamp(0.0, 1.0) * 30;
    final consistencyPts = (weeklyConsistency / 100) * 20;
    final missedRatio = trackedDays == 0 ? 0.0 : missedDays / trackedDays;
    final missedPenalty = missedRatio * 10;

    final raw = completionPts +
        streakPts +
        consistencyPts -
        missedPenalty -
        streakBreakPenalty;
    return raw.clamp(0.0, 100.0);
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
