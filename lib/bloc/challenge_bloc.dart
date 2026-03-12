import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/challenge_session.dart';
import '../models/daily_progress.dart';
import '../repositories/database_repository.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';
import 'challenge_event.dart';
import 'challenge_state.dart';

class ChallengeBloc extends Bloc<ChallengeEvent, ChallengeState> {
  final DatabaseRepository _repository;
  final NotificationService _notificationService;
  final AnalyticsService _analytics = AnalyticsService();
  Timer? _midnightTimer;

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
    on<AddTaskNote>(_onAddTaskNote);
    on<UpdateChallenge>(_onUpdateChallenge);
    on<ResetChallenge>(_onResetChallenge);
    on<CompleteChallenge>(_onCompleteChallenge);
    on<UpdateChallengeReminder>(_onUpdateChallengeReminder);
    
    _startMidnightTimer();
  }

  @override
  Future<void> close() {
    _midnightTimer?.cancel();
    return super.close();
  }

  void _startMidnightTimer() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);
    
    print('🕛 DEBUG: Starting midnight timer - ${timeUntilMidnight.inMinutes} minutes until midnight');
    
    _midnightTimer = Timer(timeUntilMidnight, () {
      print('🕛 DEBUG: Midnight reached - checking for missed days');
      _performMidnightCheck();
      _startMidnightTimer(); // Restart timer for next day
    });
  }

  void _performMidnightCheck() {
    final activeSession = _repository.getActiveSession();
    if (activeSession != null) {
      print('🕛 DEBUG: Active session found - checking for missed days');
      _checkForMissedDays(activeSession);
    }
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
      await _notificationService.cancelAllNotifications();

      final activeSession = _repository.getActiveSession();
      if (activeSession != null) {
        final endedSession = activeSession.copyWith(
          isActive: false,
          endDate: DateTime.now(),
        );
        await _repository.updateSession(endedSession);
      }

      await _repository.clearAllDailyProgress();

      final newSession = ChallengeSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        challenges: event.challenges,
        startDate: DateTime.now(),
        isActive: true,
        isCompleted: false,
        currentDay: 1,
      );

      await _repository.saveSession(newSession);
      await _analytics.logSessionStart(event.challenges.length);
      await _analytics.logChallengeSelection(
        event.challenges.map((c) => c.title).toList(),
      );

      await _notificationService.scheduleDailyMotivation();
      for (final challenge in event.challenges) {
        if (challenge.isReminderEnabled && challenge.reminderTime != null) {
          await _notificationService.scheduleTaskReminder(
            challenge,
            challenge.reminderTime!,
          );
        }
      }

      add(LoadChallengeData());
    } catch (e, stack) {
      await _analytics.logError(e, stack);
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

      final updatedCompletions =
          Map<String, bool>.from(dailyProgress.challengeCompletions);
      updatedCompletions[event.challengeId] = event.isCompleted;

      final allCompleted =
          updatedCompletions.values.every((completed) => completed);

      final updatedProgress = dailyProgress.copyWith(
        challengeCompletions: updatedCompletions,
        isCompleted: allCompleted,
      );

      await _repository.saveDailyProgress(updatedProgress);

      if (event.isCompleted) {
        final challenge = activeSession.challenges
            .firstWhere((c) => c.id == event.challengeId);
        await _analytics.logTaskComplete(
          challenge.title,
          activeSession.currentDay,
        );
      }

      await _checkForMissedDays(activeSession);
      add(LoadChallengeData());
    } catch (e, stack) {
      await _analytics.logError(e, stack);
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
    } catch (e, stack) {
      await _analytics.logError(e, stack);
      emit(ChallengeError('Failed to add journal note: $e'));
    }
  }

  Future<void> _onAddTaskNote(
    AddTaskNote event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      var dailyProgress = _repository.getDailyProgress(event.date);
      if (dailyProgress != null) {
        final updatedNotes = Map<String, String>.from(
          dailyProgress.taskNotes ?? {},
        );
        updatedNotes[event.challengeId] = event.note;
        final updatedProgress = dailyProgress.copyWith(taskNotes: updatedNotes);
        await _repository.saveDailyProgress(updatedProgress);
        add(LoadChallengeData());
      }
    } catch (e, stack) {
      await _analytics.logError(e, stack);
      emit(ChallengeError('Failed to add task note: $e'));
    }
  }

  Future<void> _onResetChallenge(
    ResetChallenge event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = _repository.getActiveSession();
      if (activeSession == null) return;

      await _notificationService.cancelAllNotifications();

      final failedSession = activeSession.copyWith(
        isActive: false,
        endDate: DateTime.now(),
        failureReason: event.reason,
        failedChallenges: event.failedChallenges,
      );

      await _repository.updateSession(failedSession);
      await _analytics.logSessionReset(
        activeSession.currentDay,
        event.reason,
      );

      await _notificationService.showFailureNotification(
        activeSession.currentDay,
        event.failedChallenges,
      );

      emit(ChallengeReset(
        reason: event.reason,
        failedChallenges: event.failedChallenges,
        daysFailed: activeSession.currentDay,
      ));

      await Future.delayed(const Duration(seconds: 2));
      add(LoadChallengeData());
    } catch (e, stack) {
      await _analytics.logError(e, stack);
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

      await _notificationService.cancelAllNotifications();

      final completedSession = activeSession.copyWith(
        isActive: false,
        isCompleted: true,
        endDate: DateTime.now(),
        currentDay: 75,
      );

      await _repository.updateSession(completedSession);
      await _analytics.logSessionComplete(75);
      await _notificationService.showCompletionNotification();

      emit(ChallengeCompleted(completedSession));

      await Future.delayed(const Duration(seconds: 3));
      add(LoadChallengeData());
    } catch (e, stack) {
      await _analytics.logError(e, stack);
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

      final updatedChallenges = activeSession.challenges.map((challenge) {
        if (challenge.id == event.challengeId) {
          return challenge.copyWith(
            reminderTime: event.reminderTime,
            isReminderEnabled: event.isEnabled,
          );
        }
        return challenge;
      }).toList();

      final updatedSession =
          activeSession.copyWith(challenges: updatedChallenges);
      await _repository.updateSession(updatedSession);

      final updatedChallenge = updatedChallenges.firstWhere(
        (c) => c.id == event.challengeId,
      );

      if (event.isEnabled && event.reminderTime != null) {
        await _notificationService.scheduleTaskReminder(
          updatedChallenge,
          event.reminderTime!,
        );
        await _analytics.logReminderSet(
          updatedChallenge.title,
          event.reminderTime!,
        );
      } else {
        await _notificationService.cancelTaskReminder(event.challengeId);
      }

      add(LoadChallengeData());
    } catch (e, stack) {
      await _analytics.logError(e, stack);
      emit(ChallengeError('Failed to update reminder: $e'));
    }
  }

  Future<void> _checkForMissedDays(ChallengeSession session) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(session.startDate.year, session.startDate.month, session.startDate.day);
    
    final daysSinceStart = today.difference(startDate).inDays;
    
    print('🕛 DEBUG: Checking missed days - Days since start: $daysSinceStart');
    
    // Check each day from start until yesterday (not including today)
    for (int i = 0; i < daysSinceStart; i++) {
      final checkDate = startDate.add(Duration(days: i));
      final progress = _repository.getDailyProgress(checkDate);
      
      print('🕛 DEBUG: Checking day ${i + 1} (${checkDate.toString().split(' ')[0]}) - Completed: ${progress?.isCompleted ?? false}');
      
      if (progress == null || !progress.isCompleted) {
        // Found a missed day - reset the challenge
        final failedChallenges = session.challenges
            .where((challenge) => progress?.challengeCompletions[challenge.id] != true)
            .map((challenge) => challenge.title)
            .toList();
        
        print('🕛 DEBUG: Found missed day ${i + 1} - Resetting challenge');
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
        final date = startDate.add(Duration(days: index));
        final progress = _repository.getDailyProgress(date);
        return progress?.isCompleted ?? false;
      }).every((completed) => completed);

      if (allDaysCompleted) {
        print('🕛 DEBUG: All 75 days completed - Completing challenge');
        add(CompleteChallenge());
      }
    }
  }
}
