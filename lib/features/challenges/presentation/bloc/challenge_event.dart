import 'package:equatable/equatable.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/journal_entry.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';

abstract class ChallengeEvent extends Equatable {
  const ChallengeEvent();

  @override
  List<Object?> get props => [];
}

class LoadChallengeData extends ChallengeEvent {}

class StartNewSession extends ChallengeEvent {
  final List<Challenge> challenges;

  const StartNewSession(this.challenges);

  @override
  List<Object> get props => [challenges];
}

class UpdateDailyProgress extends ChallengeEvent {
  final DateTime date;
  final String challengeId;
  final bool isCompleted;

  const UpdateDailyProgress({
    required this.date,
    required this.challengeId,
    required this.isCompleted,
  });

  @override
  List<Object> get props => [date, challengeId, isCompleted];
}

/// Append a journal entry to the day (a day holds many entries).
class AddJournalEntry extends ChallengeEvent {
  final DateTime date;
  final JournalEntry entry;

  const AddJournalEntry({
    required this.date,
    required this.entry,
  });

  @override
  List<Object> get props => [date, entry];
}

/// Update one journal entry of the day (matched by entry id).
class UpdateJournalEntry extends ChallengeEvent {
  final DateTime date;
  final JournalEntry entry;

  const UpdateJournalEntry({
    required this.date,
    required this.entry,
  });

  @override
  List<Object> get props => [date, entry];
}

/// Delete one journal entry of the day (matched by entry id).
class DeleteJournalEntry extends ChallengeEvent {
  final DateTime date;
  final String entryId;

  const DeleteJournalEntry({
    required this.date,
    required this.entryId,
  });

  @override
  List<Object> get props => [date, entryId];
}

class AddTaskNote extends ChallengeEvent {
  final DateTime date;
  final String challengeId;
  final String note;

  const AddTaskNote({
    required this.date,
    required this.challengeId,
    required this.note,
  });

  @override
  List<Object> get props => [date, challengeId, note];
}

class UpdateChallenge extends ChallengeEvent {
  final Challenge challenge;

  const UpdateChallenge(this.challenge);

  @override
  List<Object> get props => [challenge];
}

class ResetChallenge extends ChallengeEvent {
  final String reason;
  final List<String> failedChallenges;

  const ResetChallenge({
    required this.reason,
    required this.failedChallenges,
  });

  @override
  List<Object> get props => [reason, failedChallenges];
}

class CompleteChallenge extends ChallengeEvent {}

class UpdateChallengeReminder extends ChallengeEvent {
  final String challengeId;
  final String? reminderTime;
  final bool isEnabled;

  const UpdateChallengeReminder({
    required this.challengeId,
    this.reminderTime,
    required this.isEnabled,
  });

  @override
  List<Object?> get props => [challengeId, reminderTime, isEnabled];
}

class AddChallengeToSession extends ChallengeEvent {
  final Challenge challenge;

  const AddChallengeToSession(this.challenge);

  @override
  List<Object> get props => [challenge];
}

class AddTaskPhoto extends ChallengeEvent {
  final DateTime date;
  final String challengeId;
  final String photoPath;

  const AddTaskPhoto({
    required this.date,
    required this.challengeId,
    required this.photoPath,
  });

  @override
  List<Object> get props => [date, challengeId, photoPath];
}

class RestartFromHistory extends ChallengeEvent {
  final String sessionId;

  const RestartFromHistory(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}

class RemoveChallengeFromSession extends ChallengeEvent {
  final String challengeId;

  const RemoveChallengeFromSession(this.challengeId);

  @override
  List<Object> get props => [challengeId];
}

class EndActiveSession extends ChallengeEvent {
  const EndActiveSession();

  @override
  List<Object> get props => const [];
}

/// A partner-review outcome for one of this user's tasks, forwarded from
/// AccountabilityBloc by main.dart's BlocListener. The task ID is required
/// for exactly-once handling; owner/challenge IDs let the receiver verify
/// session ownership and avoid mutating the reviewer's local session.
class ReviewOutcomeObserved extends ChallengeEvent {
  final String? taskId;
  final String? challengeId;
  final String? taskOwnerUid;
  final String outcome; // 'approved' | 'rejected'
  final String taskType; // 'hard' | 'regular'; unknown values are ignored
  final int? newStreakDay;
  final DateTime? reviewedAt;
  final DateTime? taskAssignedAt;

  const ReviewOutcomeObserved({
    this.taskId,
    this.challengeId,
    this.taskOwnerUid,
    required this.outcome,
    required this.taskType,
    this.newStreakDay,
    this.reviewedAt,
    this.taskAssignedAt,
  });

  String get reviewRoundId =>
      reviewedAt?.toUtc().microsecondsSinceEpoch.toString() ?? '';

  String get dedupeKey => '${taskId ?? ''}:$outcome:$reviewRoundId';

  bool isForCurrentSession(ChallengeSession session) =>
      taskOwnerUid != null &&
      taskOwnerUid == session.ownerUid &&
      reviewedAt != null &&
      !reviewedAt!.isBefore(session.startDate) &&
      taskAssignedAt != null &&
      !taskAssignedAt!.isBefore(session.startDate);

  @override
  List<Object?> get props =>
      [
        taskId,
        challengeId,
        taskOwnerUid,
        outcome,
        taskType,
        newStreakDay,
        reviewedAt,
        taskAssignedAt,
      ];
}

/// Builds the owner-side event from a persisted task stream update. The task
/// stream may replay old snapshots; the ChallengeBloc checks reviewedAt
/// against the active session start before applying the event.
ReviewOutcomeObserved? reviewOutcomeForOwnerTask(
  AccountabilityTask task, {
  required String? currentUid,
}) {
  final reviewedAt = task.reviewedAt ?? task.proofReviewedAt;
  if (currentUid == null ||
      task.assignedByUid != currentUid ||
      (task.reviewDecision != 'rejected' &&
          task.status != AccountabilityTaskStatus.rejected) ||
      reviewedAt == null ||
      (task.taskType != 'hard' &&
          task.taskType != 'soft' &&
          task.taskType != 'regular')) {
    return null;
  }
  return ReviewOutcomeObserved(
    taskId: task.id,
    challengeId: task.challengeId,
    taskOwnerUid: task.assignedByUid,
    outcome: 'rejected',
    taskType: task.taskType,
    reviewedAt: reviewedAt,
    taskAssignedAt: task.assignedAt,
  );
}
