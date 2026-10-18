import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/challenges/presentation/bloc/challenge_event.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/presentation/bloc/accountability_bloc.dart';

void main() {
  test('review outcome routes to the task creator, not the assignee', () {
    final task = AccountabilityTask(
      id: 'task-1',
      assignedByUid: 'creator-uid',
      assignedByName: 'Creator',
      accountableUid: 'assignee-uid',
      accountableName: 'Assignee',
      partnershipId: 'partnership-1',
      challengeId: 'challenge-1',
      title: 'Complete the task',
      status: AccountabilityTaskStatus.pendingReview,
      assignedAt: DateTime(2026, 10, 18),
      taskType: 'hard',
    );

    final outcome = createStreakReviewOutcome(
      task: task,
      newStreakDay: 0,
      outcome: 'rejected',
    );

    expect(outcome.taskOwnerUid, 'creator-uid');
    expect(outcome.taskOwnerUid, isNot('assignee-uid'));
    expect(outcome.taskId, task.id);
    expect(outcome.challengeId, task.challengeId);
    expect(outcome.reviewedAt, task.reviewedAt);
    expect(outcome.taskAssignedAt, task.assignedAt);
  });

  test('owner task stream creates a rejected round for the assignedBy owner',
      () {
    final reviewedAt = DateTime(2026, 10, 18, 11);
    final task = AccountabilityTask(
      id: 'task-stream',
      assignedByUid: 'owner-uid',
      assignedByName: 'Owner',
      accountableUid: 'reviewer-uid',
      accountableName: 'Reviewer',
      partnershipId: 'partnership-1',
      challengeId: 'challenge-1',
      title: 'Complete the task',
      status: AccountabilityTaskStatus.rejected,
      assignedAt: DateTime(2026, 10, 17),
      taskType: 'hard',
      reviewDecision: 'rejected',
      reviewedAt: reviewedAt,
    );

    final outcome = reviewOutcomeForOwnerTask(task, currentUid: 'owner-uid');
    expect(outcome, isNotNull);
    expect(outcome!.taskOwnerUid, 'owner-uid');
    expect(outcome.taskId, task.id);
    expect(outcome.challengeId, task.challengeId);
    expect(outcome.taskType, 'hard');
    expect(outcome.reviewedAt, reviewedAt);
    expect(outcome.taskAssignedAt, task.assignedAt);
    expect(reviewOutcomeForOwnerTask(task, currentUid: 'reviewer-uid'), isNull);
  });

  test('review round key distinguishes later rejections and filters stale ones',
      () {
    final firstAt = DateTime(2026, 10, 18, 11);
    final secondAt = firstAt.add(const Duration(days: 1));
    final first = ReviewOutcomeObserved(
      taskId: 'task-1',
      challengeId: 'challenge-1',
      taskOwnerUid: 'owner-uid',
      outcome: 'rejected',
      taskType: 'hard',
      taskAssignedAt: firstAt,
      reviewedAt: firstAt,
    );
    final second = ReviewOutcomeObserved(
      taskId: 'task-1',
      challengeId: 'challenge-1',
      taskOwnerUid: 'owner-uid',
      outcome: 'rejected',
      taskType: 'hard',
      taskAssignedAt: secondAt,
      reviewedAt: secondAt,
    );
    final activeSession = ChallengeSession(
      id: 'active',
      challenges: const [],
      startDate: firstAt,
      isActive: true,
      isCompleted: false,
      currentDay: 1,
      ownerUid: 'owner-uid',
    );
    final laterSession = activeSession.copyWith(startDate: secondAt);
    final oldTaskReviewedNow = ReviewOutcomeObserved(
      taskId: 'old-task',
      challengeId: 'challenge-1',
      taskOwnerUid: 'owner-uid',
      outcome: 'rejected',
      taskType: 'hard',
      taskAssignedAt: firstAt.subtract(const Duration(days: 2)),
      reviewedAt: secondAt,
    );

    expect(first.dedupeKey, isNot(second.dedupeKey));
    expect(first.isForCurrentSession(activeSession), isTrue);
    expect(first.isForCurrentSession(laterSession), isFalse);
    expect(oldTaskReviewedNow.isForCurrentSession(laterSession), isFalse);
    expect(first.isForCurrentSession(activeSession.copyWith(ownerUid: 'other')),
        isFalse);
  });
}
