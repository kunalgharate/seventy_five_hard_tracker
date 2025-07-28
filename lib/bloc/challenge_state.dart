import 'package:equatable/equatable.dart';
import '../models/challenge_session.dart';
import '../models/daily_progress.dart';

abstract class ChallengeState extends Equatable {
  const ChallengeState();

  @override
  List<Object?> get props => [];
}

class ChallengeInitial extends ChallengeState {}

class ChallengeLoading extends ChallengeState {}

class ChallengeLoaded extends ChallengeState {
  final ChallengeSession? activeSession;
  final List<ChallengeSession> allSessions;
  final List<DailyProgress> currentProgress;
  final bool hasActiveSession;

  const ChallengeLoaded({
    this.activeSession,
    required this.allSessions,
    required this.currentProgress,
    required this.hasActiveSession,
  });

  @override
  List<Object?> get props => [
    activeSession,
    allSessions,
    currentProgress,
    hasActiveSession,
  ];

  ChallengeLoaded copyWith({
    ChallengeSession? activeSession,
    List<ChallengeSession>? allSessions,
    List<DailyProgress>? currentProgress,
    bool? hasActiveSession,
  }) {
    return ChallengeLoaded(
      activeSession: activeSession ?? this.activeSession,
      allSessions: allSessions ?? this.allSessions,
      currentProgress: currentProgress ?? this.currentProgress,
      hasActiveSession: hasActiveSession ?? this.hasActiveSession,
    );
  }
}

class ChallengeError extends ChallengeState {
  final String message;

  const ChallengeError(this.message);

  @override
  List<Object> get props => [message];
}

class ChallengeCompleted extends ChallengeState {
  final ChallengeSession completedSession;

  const ChallengeCompleted(this.completedSession);

  @override
  List<Object> get props => [completedSession];
}

class ChallengeReset extends ChallengeState {
  final String reason;
  final List<String> failedChallenges;
  final int daysFailed;

  const ChallengeReset({
    required this.reason,
    required this.failedChallenges,
    required this.daysFailed,
  });

  @override
  List<Object> get props => [reason, failedChallenges, daysFailed];
}
