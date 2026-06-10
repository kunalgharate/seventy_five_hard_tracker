import 'package:equatable/equatable.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';

abstract class DisciplineScoreEvent extends Equatable {
  const DisciplineScoreEvent();

  @override
  List<Object?> get props => [];
}

/// Recalculate the discipline score from fresh session + progress data.
class CalculateDisciplineScore extends DisciplineScoreEvent {
  final ChallengeSession? session;
  final List<DailyProgress> progress;

  const CalculateDisciplineScore({
    required this.session,
    required this.progress,
  });

  @override
  List<Object?> get props => [session, progress];
}

/// Reset to empty (e.g. when session ends or user logs out).
class ResetDisciplineScore extends DisciplineScoreEvent {}
