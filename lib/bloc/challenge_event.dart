import 'package:equatable/equatable.dart';
import '../models/challenge.dart';

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

class AddJournalNote extends ChallengeEvent {
  final DateTime date;
  final String note;

  const AddJournalNote({
    required this.date,
    required this.note,
  });

  @override
  List<Object> get props => [date, note];
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
