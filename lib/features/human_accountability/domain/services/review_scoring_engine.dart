/// Pure functions for computing the impact of partner reviews on user progress.
///
/// All methods are stateless and deterministic — suitable for property-based testing.
class ReviewScoringEngine {
  const ReviewScoringEngine();

  /// Computes the 75 Hard streak after a review outcome.
  ///
  /// - approved → keep the streak (the day's completion flow already
  ///   increments it)
  /// - rejected or expired → reset to 1 (Day 1)
  /// - pending (anything else) → keep the streak untouched
  int compute75HardStreak(int currentStreak, String outcome) {
    // Reuse the reset rule: only rejected/expiry are terminal failures.
    if (triggers75HardReset(outcome)) return 1;
    return currentStreak; // pending keeps the streak; approved handled by daily completion flow
  }

  /// Whether a Regular task day counts as complete based on outcome.
  ///
  /// Only 'approved' counts as complete.
  bool isRegularDayComplete(String outcome) {
    return outcome == 'approved';
  }

  /// Completion percentage for a Regular task.
  ///
  /// Formula: (partner-approved days / total days) × 100
  /// Returns 0.0 if no outcomes recorded.
  double computeCompletionPercentage(List<String> dailyOutcomes) {
    if (dailyOutcomes.isEmpty) return 0.0;
    final approved = dailyOutcomes.where((o) => o == 'approved').length;
    return (approved / dailyOutcomes.length) * 100;
  }

  /// Regular task streak: consecutive partner-approved days from the most recent.
  ///
  /// Iterates from the latest day backward, counting 'approved' until
  /// a non-approved outcome is hit.
  int computeRegularStreak(List<String> dailyOutcomes) {
    int streak = 0;
    for (final outcome in dailyOutcomes.reversed) {
      if (outcome == 'approved') {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Whether an outcome triggers a 75 Hard streak reset.
  bool triggers75HardReset(String outcome) {
    return outcome == 'rejected' || outcome == 'expired';
  }

  /// Whether an outcome is terminal (can't be changed).
  bool isTerminalOutcome(String outcome) {
    return outcome == 'approved' ||
        outcome == 'rejected' ||
        outcome == 'expired';
  }
}
