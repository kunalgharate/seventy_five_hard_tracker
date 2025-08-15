import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/challenge_session.dart';
import '../models/daily_progress.dart';
import '../repositories/database_repository.dart';
import '../services/notification_service.dart';
import 'challenge_event.dart';
import 'challenge_state.dart';

class ChallengeBloc extends Bloc<ChallengeEvent, ChallengeState> {
  final DatabaseRepository _repository;
  final NotificationService _notificationService;

  // Getter for repository access
  DatabaseRepository get repository => _repository;

  ChallengeBloc({
    required DatabaseRepository repository,
    required NotificationService notificationService,
  })  : _repository = repository,
        _notificationService = notificationService,
        super(ChallengeInitial()) {
    on<LoadChallengeData>(_onLoadChallengeData);
    on<StartNewSession>(_onStartNewSession);
    on<UpdateDailyProgress>(_onUpdateDailyProgress);
    on<AddJournalNote>(_onAddJournalNote);
    on<UpdateChallenge>(_onUpdateChallenge);
    on<ResetChallenge>(_onResetChallenge);
    on<CompleteChallenge>(_onCompleteChallenge);
    on<UpdateChallengeReminder>(_onUpdateChallengeReminder);
  }

  Future<void> _onLoadChallengeData(
    LoadChallengeData event,
    Emitter<ChallengeState> emit,
  ) async {
    emit(ChallengeLoading());
    
    try {
      final activeSession = _repository.getActiveSession();
      final allSessions = _repository.getAllSessions();
      final currentProgress = activeSession != null
          ? _repository.getProgressForSession(activeSession.startDate)
          : <DailyProgress>[];

      emit(ChallengeLoaded(
        activeSession: activeSession,
        allSessions: allSessions,
        currentProgress: currentProgress,
        hasActiveSession: activeSession != null,
      ));
    } catch (e) {
      emit(ChallengeError('Failed to load challenge data: $e'));
    }
  }

  Future<void> _onStartNewSession(
    StartNewSession event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      // End any active session
      final activeSession = _repository.getActiveSession();
      if (activeSession != null) {
        final endedSession = activeSession.copyWith(
          isActive: false,
          endDate: DateTime.now(),
        );
        await _repository.updateSession(endedSession);
      }

      // Clear all existing daily progress data to prevent stale completion status
      await _repository.clearAllDailyProgress();

      // Create new session
      final newSession = ChallengeSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        challenges: event.challenges,
        startDate: DateTime.now(),
        isActive: true,
        isCompleted: false,
        currentDay: 1,
      );

      await _repository.saveSession(newSession);

      // Schedule notifications
      print('🔔 DEBUG: Starting notification scheduling in _onStartNewSession');
      await _notificationService.scheduleDailyMotivation();
      for (final challenge in event.challenges) {
        print('🔔 DEBUG: Checking challenge: ${challenge.title}');
        print('🔔 DEBUG: isReminderEnabled: ${challenge.isReminderEnabled}');
        print('🔔 DEBUG: reminderTime: ${challenge.reminderTime}');
        if (challenge.isReminderEnabled && challenge.reminderTime != null) {
          print('🔔 DEBUG: Scheduling reminder for: ${challenge.title}');
          await _notificationService.scheduleTaskReminder(
            challenge,
            challenge.reminderTime!,
          );
        } else {
          print('🔔 DEBUG: Skipping reminder for: ${challenge.title}');
        }
      }
      print('🔔 DEBUG: Completed notification scheduling in _onStartNewSession');

      // Reload data
      add(LoadChallengeData());
    } catch (e) {
      emit(ChallengeError('Failed to start new session: $e'));
    }
  }

  Future<void> _onUpdateDailyProgress(
    UpdateDailyProgress event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = _repository.getActiveSession();
      if (activeSession == null) return;

      // Get existing progress or create new
      var dailyProgress = _repository.getDailyProgress(event.date);
      if (dailyProgress == null) {
        final challengeCompletions = <String, bool>{};
        for (final challenge in activeSession.challenges) {
          challengeCompletions[challenge.id] = false;
        }
        dailyProgress = DailyProgress(
          date: event.date,
          challengeCompletions: challengeCompletions,
          isCompleted: false,
        );
      }

      // Update specific challenge completion
      final updatedCompletions = Map<String, bool>.from(dailyProgress.challengeCompletions);
      updatedCompletions[event.challengeId] = event.isCompleted;

      // Check if all challenges are completed
      final allCompleted = updatedCompletions.values.every((completed) => completed);
      
      // Debug logging
      print('🔧 DEBUG: Updating daily progress for ${event.date}');
      print('🔧 DEBUG: Challenge ${event.challengeId} set to ${event.isCompleted}');
      print('🔧 DEBUG: All completions: $updatedCompletions');
      print('🔧 DEBUG: All completed: $allCompleted');

      final updatedProgress = dailyProgress.copyWith(
        challengeCompletions: updatedCompletions,
        isCompleted: allCompleted,
      );

      await _repository.saveDailyProgress(updatedProgress);

      // Check for missed days and auto-reset
      await _checkForMissedDays(activeSession);

      // Reload data
      add(LoadChallengeData());
    } catch (e) {
      emit(ChallengeError('Failed to update daily progress: $e'));
    }
  }

  Future<void> _onAddJournalNote(
    AddJournalNote event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      var dailyProgress = _repository.getDailyProgress(event.date);
      if (dailyProgress != null) {
        final updatedProgress = dailyProgress.copyWith(journalNote: event.note);
        await _repository.saveDailyProgress(updatedProgress);
        add(LoadChallengeData());
      }
    } catch (e) {
      emit(ChallengeError('Failed to add journal note: $e'));
    }
  }

  Future<void> _onResetChallenge(
    ResetChallenge event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = _repository.getActiveSession();
      if (activeSession == null) return;

      // Update session as failed
      final failedSession = activeSession.copyWith(
        isActive: false,
        endDate: DateTime.now(),
        failureReason: event.reason,
        failedChallenges: event.failedChallenges,
      );

      await _repository.updateSession(failedSession);

      // Show failure notification
      await _notificationService.showFailureNotification(
        activeSession.currentDay,
        event.failedChallenges,
      );

      emit(ChallengeReset(
        reason: event.reason,
        failedChallenges: event.failedChallenges,
        daysFailed: activeSession.currentDay,
      ));

      // Reload data after a short delay
      await Future.delayed(const Duration(seconds: 2));
      add(LoadChallengeData());
    } catch (e) {
      emit(ChallengeError('Failed to reset challenge: $e'));
    }
  }

  Future<void> _onCompleteChallenge(
    CompleteChallenge event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = _repository.getActiveSession();
      if (activeSession == null) return;

      final completedSession = activeSession.copyWith(
        isActive: false,
        isCompleted: true,
        endDate: DateTime.now(),
        currentDay: 75,
      );

      await _repository.updateSession(completedSession);
      await _notificationService.showCompletionNotification();

      emit(ChallengeCompleted(completedSession));

      // Reload data after showing completion
      await Future.delayed(const Duration(seconds: 3));
      add(LoadChallengeData());
    } catch (e) {
      emit(ChallengeError('Failed to complete challenge: $e'));
    }
  }

  Future<void> _onUpdateChallenge(
    UpdateChallenge event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      print('🔔 BLOC DEBUG: _onUpdateChallenge called');
      print('🔔 BLOC DEBUG: event.challenge.id = ${event.challenge.id}');
      print('🔔 BLOC DEBUG: event.challenge.title = ${event.challenge.title}');
      print('🔔 BLOC DEBUG: event.challenge.isReminderEnabled = ${event.challenge.isReminderEnabled}');
      print('🔔 BLOC DEBUG: event.challenge.reminderTime = ${event.challenge.reminderTime}');
      
      final activeSession = _repository.getActiveSession();
      if (activeSession == null) {
        print('🔔 BLOC DEBUG: No active session found - returning');
        return;
      }

      print('🔔 BLOC DEBUG: Active session found, updating challenges...');
      
      // Update challenge in session
      final updatedChallenges = activeSession.challenges.map((challenge) {
        if (challenge.id == event.challenge.id) {
          print('🔔 BLOC DEBUG: Found matching challenge, updating...');
          return event.challenge;
        }
        return challenge;
      }).toList();

      print('🔔 BLOC DEBUG: Saving updated session...');
      final updatedSession = activeSession.copyWith(challenges: updatedChallenges);
      await _repository.saveSession(updatedSession);

      print('🔔 BLOC DEBUG: Session saved, scheduling notification...');
      
      // Schedule notification if reminder is enabled
      if (event.challenge.isReminderEnabled && event.challenge.reminderTime != null) {
        print('🔔 BLOC DEBUG: Scheduling notification for ${event.challenge.title}');
        await _notificationService.scheduleTaskReminder(
          event.challenge,
          event.challenge.reminderTime!,
        );
      } else {
        print('🔔 BLOC DEBUG: Cancelling notification for ${event.challenge.title}');
        await _notificationService.cancelTaskReminder(event.challenge.id);
      }

      print('🔔 BLOC DEBUG: Emitting updated state...');
      // Emit updated state
      final currentProgress = _repository.getProgressForSession(activeSession.startDate);
      final allSessions = _repository.getAllSessions();
      emit(ChallengeLoaded(
        activeSession: updatedSession,
        currentProgress: currentProgress,
        allSessions: allSessions,
        hasActiveSession: true,
      ));
    } catch (e) {
      emit(ChallengeError('Failed to update challenge: $e'));
    }
  }

  Future<void> _onUpdateChallengeReminder(
    UpdateChallengeReminder event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = _repository.getActiveSession();
      if (activeSession == null) return;

      // Update challenge in session
      final updatedChallenges = activeSession.challenges.map((challenge) {
        if (challenge.id == event.challengeId) {
          return challenge.copyWith(
            reminderTime: event.reminderTime,
            isReminderEnabled: event.isEnabled,
          );
        }
        return challenge;
      }).toList();

      final updatedSession = activeSession.copyWith(challenges: updatedChallenges);
      await _repository.updateSession(updatedSession);

      // Update notification
      final updatedChallenge = updatedChallenges.firstWhere(
        (c) => c.id == event.challengeId,
      );

      print('🔔 DEBUG: Updating reminder for challenge: ${updatedChallenge.title}');
      print('🔔 DEBUG: event.isEnabled: ${event.isEnabled}');
      print('🔔 DEBUG: event.reminderTime: ${event.reminderTime}');
      print('🔔 DEBUG: updatedChallenge.isReminderEnabled: ${updatedChallenge.isReminderEnabled}');
      print('🔔 DEBUG: updatedChallenge.reminderTime: ${updatedChallenge.reminderTime}');

      if (event.isEnabled && event.reminderTime != null) {
        print('🔔 DEBUG: Scheduling new reminder');
        await _notificationService.scheduleTaskReminder(
          updatedChallenge,
          event.reminderTime!,
        );
      } else {
        print('🔔 DEBUG: Cancelling reminder');
        await _notificationService.cancelTaskReminder(event.challengeId);
      }

      add(LoadChallengeData());
    } catch (e) {
      emit(ChallengeError('Failed to update reminder: $e'));
    }
  }

  Future<void> _checkForMissedDays(ChallengeSession session) async {
    final now = DateTime.now();
    final daysSinceStart = now.difference(session.startDate).inDays;
    
    // Check if we've missed any days
    for (int i = 0; i < daysSinceStart; i++) {
      final checkDate = session.startDate.add(Duration(days: i));
      final progress = _repository.getDailyProgress(checkDate);
      
      if (progress == null || !progress.isCompleted) {
        // Found a missed day - reset the challenge
        final failedChallenges = session.challenges
            .where((challenge) => progress?.challengeCompletions[challenge.id] != true)
            .map((challenge) => challenge.title)
            .toList();
        
        add(ResetChallenge(
          reason: 'Missed day ${i + 1}',
          failedChallenges: failedChallenges,
        ));
        return;
      }
    }

    // Check if challenge is completed (75 days)
    if (daysSinceStart >= 75) {
      final allDaysCompleted = List.generate(75, (index) {
        final date = session.startDate.add(Duration(days: index));
        final progress = _repository.getDailyProgress(date);
        return progress?.isCompleted ?? false;
      }).every((completed) => completed);

      if (allDaysCompleted) {
        add(CompleteChallenge());
      }
    }
  }
}
