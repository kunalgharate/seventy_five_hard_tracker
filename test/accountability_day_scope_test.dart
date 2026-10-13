import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';

/// Regression tests for the daily-reset complaint: yesterday's approved
/// task rendered as approved today on Home, Squad and Reviews. Approval
/// is now scoped to the calendar day it happened (`isDoneToday`); a new
/// day renders the task as needing fresh proof + approval.
AccountabilityTask task({
  AccountabilityTaskStatus status = AccountabilityTaskStatus.approved,
  ProofStatus proofStatus = ProofStatus.notRequired,
  DateTime? proofReviewedAt,
  DateTime? reviewedAt,
  DateTime? completedAt,
}) {
  return AccountabilityTask(
    id: 't1',
    assignedByUid: 'owner',
    assignedByName: 'Owner',
    accountableUid: 'reviewer',
    accountableName: 'Reviewer',
    partnershipId: 'p1',
    title: 'Daily task',
    status: status,
    assignedAt: DateTime(2026, 1, 1),
    proofStatus: proofStatus,
    proofReviewedAt: proofReviewedAt,
    reviewedAt: reviewedAt,
    completedAt: completedAt,
  );
}

void main() {
  group('AccountabilityTask.isSameDay', () {
    test('same calendar day, different times', () {
      expect(
        AccountabilityTask.isSameDay(
          DateTime(2026, 10, 13, 8),
          DateTime(2026, 10, 13, 22),
        ),
        true,
      );
    });

    test('midnight boundary is a different day', () {
      expect(
        AccountabilityTask.isSameDay(
          DateTime(2026, 10, 12, 23, 59),
          DateTime(2026, 10, 13, 0, 1),
        ),
        false,
      );
    });
  });

  group('isApprovedToday', () {
    test('approved just now counts', () {
      expect(task(proofReviewedAt: DateTime.now()).isApprovedToday, true);
    });

    test('approved yesterday does not count', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(task(proofReviewedAt: yesterday).isApprovedToday, false);
    });

    test('falls back to reviewedAt', () {
      expect(task(reviewedAt: DateTime.now()).isApprovedToday, true);
      expect(
        task(reviewedAt: DateTime.now().subtract(const Duration(days: 2)))
            .isApprovedToday,
        false,
      );
    });

    test('non-approved status is never approved-today', () {
      expect(
        task(
          status: AccountabilityTaskStatus.pendingReview,
          proofReviewedAt: DateTime.now(),
        ).isApprovedToday,
        false,
      );
    });
  });

  group('isDoneToday', () {
    test('approved today counts as done', () {
      expect(task(proofReviewedAt: DateTime.now()).isDoneToday, true);
    });

    test('approved yesterday needs new proof', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(task(proofReviewedAt: yesterday).isDoneToday, false);
    });

    test('completed yesterday needs new proof', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        task(
          status: AccountabilityTaskStatus.completed,
          completedAt: yesterday,
        ).isDoneToday,
        false,
      );
    });

    test('completed today counts as done', () {
      expect(
        task(
          status: AccountabilityTaskStatus.completed,
          completedAt: DateTime.now(),
        ).isDoneToday,
        true,
      );
    });

    test('proof-approved yesterday needs new proof', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        task(
          status: AccountabilityTaskStatus.pendingReview,
          proofStatus: ProofStatus.approved,
          proofReviewedAt: yesterday,
        ).isDoneToday,
        false,
      );
    });

    test('pending task is not done', () {
      expect(
        task(status: AccountabilityTaskStatus.pending).isDoneToday,
        false,
      );
    });
  });
}
