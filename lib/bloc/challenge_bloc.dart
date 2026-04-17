import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/challenge.dart';
import '../models/challenge_session.dart';
import '../models/daily_progress.dart';
import '../repositories/database_repository.dart';
import '../services/smart_notification_service.dart';
import '../services/analytics_service.dart';
import 'challenge_event.dart';
import 'challenge_state.dart';

class ChallengeBloc extends Bloc<ChallengeEvent, ChallengeState> {
  final DatabaseRepository _repository;
  final SmartNotificationService _smartNotifications;
  final AnalyticsService _analytics = AnalyticsService();
  Timer? _midnightTimer;

  /// Guard to prevent re-entrant missed-day checks.
  bool _isCheckingMissedDays = false;
  bool _hasCheckedMissedDays = false;

  DatabaseRepository get repository => _repository;

  ChallengeBloc({
    required DatabaseRepository repository,
    required SmartNotificationService smartNotifications,
  })  : _repository = repository,
        _smartNotifications = smartNotifications,
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
    on<AddTaskPhoto>(_onAddTaskPhoto);
    on<AddChallengeToSession>(_onAddChallengeToSession);

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

    _midnightTimer?.cancel();
    _midnightTimer = Timer(timeUntilMidnight, () {
      _performMidnightCheck();
      _startMidnightTimer();
    });
  }

  void _performMidnightCheck() {
    final activeSession = _repository.getActiveSession();
    if (activeSession != null) {
      _checkForMissedDays(activeSession);
    }
  }

  // ── Event handlers ──────────────────────────────────────────────

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

      // Keep currentDay in sync with reality
      if (activeSession != null) {
        final computedDay = _computeCurrentDay(activeSession);
        if (computedDay != activeSession.currentDay) {
          final updated = activeSession.copyWith(currentDay: computedDay);
          await _repository.updateSession(updated);
          emit(ChallengeLoaded(
            activeSession: updated,
            allSessions: allSessions,
            currentProgress: currentProgress,
            hasActiveSession: true,
          ));
          return;
        }
      }

      emit(ChallengeLoaded(
        activeSession: activeSession,
        allSessions: allSessions,
        currentProgress: currentProgress,
        hasActiveSession: activeSession != null,
      ));

      // Check for missed days only on first load (app open)
      if (activeSession != null &&
          activeSession.isActive &&
          !_hasCheckedMissedDays) {
        _hasCheckedMissedDays = true;
        await _checkForMissedDays(activeSession);
      }
    } catch (e) {
      emit(ChallengeError('Failed to load challenge data: $e'));
    }
  }

  Future<void> _onStartNewSession(
    StartNewSession event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      await _smartNotifications.cancelAllRemindersForDate(DateTime.now());

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

      await _smartNotifications.scheduleSmartReminders(
        DateTime.now(),
        event.challenges,
        null,
      );

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

      final allCompleted = activeSession.challenges
          .where((c) => c.taskType != 'regular')
          .every((c) => updatedCompletions[c.id] == true);

      final updatedProgress = dailyProgress.copyWith(
        challengeCompletions: updatedCompletions,
        isCompleted: allCompleted,
      );

      await _repository.saveDailyProgress(updatedProgress);

      if (event.isCompleted) {
        await _smartNotifications
            .cancelCompletedTaskReminders(event.challengeId);

        final challenge = activeSession.challenges
            .firstWhere((c) => c.id == event.challengeId);
        await _analytics.logTaskComplete(
          challenge.title,
          _computeCurrentDay(activeSession),
        );
      }

      await _smartNotifications.scheduleSmartReminders(
        event.date,
        activeSession.challenges,
        updatedProgress,
      );

      final pendingChallenges =
          _getPendingChallenges(activeSession.challenges, updatedProgress);

      if (pendingChallenges.isNotEmpty) {
        await _smartNotifications.scheduleNightSummary(
          event.date,
          pendingChallenges,
        );
      } else {
        // All tasks done — cancel night summaries
        await _smartNotifications.cancelNightSummaries();
      }

      add(LoadChallengeData());
    } catch (e, stack) {
      await _analytics.logError(e, stack);
      emit(ChallengeError('Failed to update daily progress: $e'));
    }
  }

  List<Challenge> _getPendingChallenges(
    List<Challenge> challenges,
    DailyProgress progress,
  ) {
    return challenges.where((challenge) {
      final isCompleted = progress.challengeCompletions[challenge.id] ?? false;
      return !isCompleted;
    }).toList();
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

  Future<void> _onAddTaskPhoto(
    AddTaskPhoto event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      var dailyProgress = _repository.getDailyProgress(event.date);
      if (dailyProgress != null) {
        final updatedPhotos = Map<String, String>.from(
          dailyProgress.taskPhotos ?? {},
        );
        updatedPhotos[event.challengeId] = event.photoPath;
        final updatedProgress =
            dailyProgress.copyWith(taskPhotos: updatedPhotos);
        await _repository.saveDailyProgress(updatedProgress);
        add(LoadChallengeData());
      }
    } catch (e, stack) {
      await _analytics.logError(e, stack);
      emit(ChallengeError('Failed to add task photo: $e'));
    }
  }

  Future<void> _onResetChallenge(
    ResetChallenge event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = _repository.getActiveSession();
      if (activeSession == null) return;

      await _smartNotifications.cancelAllRemindersForDate(DateTime.now());

      if (activeSession.mode == ResetMode.hard) {
        await _smartNotifications.showFailureNotification(
          activeSession.currentDay,
          event.failedChallenges,
        );

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

        emit(ChallengeReset(
          reason: event.reason,
          failedChallenges: event.failedChallenges,
          daysFailed: activeSession.currentDay,
        ));

        await Future.delayed(const Duration(seconds: 2));
        add(LoadChallengeData());
      } else {
        add(LoadChallengeData());
      }
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

      await _smartNotifications.cancelAllRemindersForDate(DateTime.now());
      await _smartNotifications.showCompletionNotification();

      final completedSession = activeSession.copyWith(
        isActive: false,
        isCompleted: true,
        endDate: DateTime.now(),
        currentDay: 75,
      );

      await _repository.updateSession(completedSession);
      await _analytics.logSessionComplete(75);

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
      final activeSession = _repository.getActiveSession();
      if (activeSession == null) return;

      final updatedChallenges = activeSession.challenges.map((challenge) {
        return challenge.id == event.challenge.id ? event.challenge : challenge;
      }).toList();

      final updatedSession =
          activeSession.copyWith(challenges: updatedChallenges);
      await _repository.saveSession(updatedSession);

      if (event.challenge.isReminderEnabled &&
          event.challenge.reminderTime != null) {
        await _smartNotifications.scheduleSmartReminders(
          DateTime.now(),
          [event.challenge],
          null,
        );
      } else {
        await _smartNotifications
            .cancelCompletedTaskReminders(event.challenge.id);
      }

      final currentProgress =
          _repository.getProgressForSession(activeSession.startDate);
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

  Future<void> _onAddChallengeToSession(
    AddChallengeToSession event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = _repository.getActiveSession();
      if (activeSession == null) return;

      final updatedChallenges = [...activeSession.challenges, event.challenge];
      final updatedSession =
          activeSession.copyWith(challenges: updatedChallenges);
      await _repository.saveSession(updatedSession);

      final currentProgress =
          _repository.getProgressForSession(activeSession.startDate);
      final allSessions = _repository.getAllSessions();
      emit(ChallengeLoaded(
        activeSession: updatedSession,
        currentProgress: currentProgress,
        allSessions: allSessions,
        hasActiveSession: true,
      ));
    } catch (e) {
      emit(ChallengeError('Failed to add task: $e'));
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
        await _smartNotifications.scheduleSmartReminders(
          DateTime.now(),
          [updatedChallenge],
          null,
        );
        await _analytics.logReminderSet(
          updatedChallenge.title,
          event.reminderTime!,
        );
      } else {
        await _smartNotifications
            .cancelCompletedTaskReminders(event.challengeId);
      }

      add(LoadChallengeData());
    } catch (e, stack) {
      await _analytics.logError(e, stack);
      emit(ChallengeError('Failed to update reminder: $e'));
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────

  int _computeCurrentDay(ChallengeSession session) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
        session.startDate.year, session.startDate.month, session.startDate.day);
    final days = today.difference(start).inDays + 1;
    return days.clamp(1, session.totalDaysTarget);
  }

  /// Checks for missed days. Uses [_isCheckingMissedDays] guard to prevent
  /// the reset → load → check → reset infinite loop.
  Future<void> _checkForMissedDays(ChallengeSession session) async {
    if (_isCheckingMissedDays) return;
    _isCheckingMissedDays = true;

    try {
      // Soft mode doesn't reset — only hard mode checks
      if (session.mode != ResetMode.hard) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDate = DateTime(session.startDate.year,
          session.startDate.month, session.startDate.day);

      final daysSinceStart = today.difference(startDate).inDays;

      // Don't check on the first day — nothing to miss yet
      if (daysSinceStart <= 0) return;

      // Check each day from start until yesterday (not including today)
      for (int i = 0; i < daysSinceStart; i++) {
        final checkDate = startDate.add(Duration(days: i));
        final progress = _repository.getDailyProgress(checkDate);

        // If no progress entry exists for this day, it means the day was missed entirely
        if (progress == null) {
          final hardChallenges =
              session.challenges.where((c) => c.type == TaskType.hard).toList();
          if (hardChallenges.isNotEmpty) {
            add(ResetChallenge(
              reason: 'Missed day ${i + 1}',
              failedChallenges: hardChallenges.map((c) => c.title).toList(),
            ));
            return;
          }
          continue;
        }

        // Only check hard tasks for reset
        final hardChallenges =
            session.challenges.where((c) => c.type == TaskType.hard).toList();

        final missedHardTasks = hardChallenges
            .where((c) => progress.challengeCompletions[c.id] != true)
            .map((c) => c.title)
            .toList();

        if (missedHardTasks.isNotEmpty) {
          add(ResetChallenge(
            reason: 'Missed day ${i + 1}',
            failedChallenges: missedHardTasks,
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
          add(CompleteChallenge());
        }
      }
    } finally {
      _isCheckingMissedDays = false;
    }
  }
}
