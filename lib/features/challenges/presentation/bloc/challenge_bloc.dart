import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge_session.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';
import 'package:seventy_five_hard_tracker/core/services/analytics_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'challenge_event.dart';
import 'challenge_state.dart';

/// Creates a new [ChallengeSession] from a historical session, preserving
/// the challenge configuration while resetting progress-related fields.
ChallengeSession createRestartedSession(ChallengeSession historicalSession) {
  return ChallengeSession(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    challenges: historicalSession.challenges,
    startDate: DateTime.now(),
    isActive: true,
    isCompleted: false,
    currentDay: 1,
    resetMode: historicalSession.resetMode,
    totalDaysTarget: historicalSession.totalDaysTarget,
  );
}

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
    on<RestartFromHistory>(_onRestartFromHistory);
    on<RemoveChallengeFromSession>(_onRemoveChallengeFromSession);
    on<EndActiveSession>(_onEndActiveSession);
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

  void _performMidnightCheck() async {
    final activeSession = await _repository.getActiveSession();
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
      final activeSession = await _repository.getActiveSession();
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

      // Publish challenge names to Firestore so partners see task names
      if (activeSession != null && activeSession.isActive) {
        unawaited(() async {
          try {
            final names = activeSession.challenges
                .where((c) => c.taskType != 'regular')
                .map((c) => c.title)
                .toList();
            await AccountabilityService().publishChallengeMeta(
              challengeNames: names,
              currentDay: activeSession.currentDay,
            );
          } catch (_) {}
        }());
      }

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

      final activeSession = await _repository.getActiveSession();
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
      unawaited(_analytics.logSessionStart(event.challenges.length));
      unawaited(_analytics.logChallengeSelection(
        event.challenges.map((c) => c.title).toList(),
      ));

      await _smartNotifications.scheduleSmartReminders(
        DateTime.now(),
        event.challenges,
        null,
      );

      // Emit immediately so the UI shows the new session without a loading gap.
      final allSessions = _repository.getAllSessions();
      final currentProgress =
          _repository.getProgressForSession(newSession.startDate);
      emit(ChallengeLoaded(
        activeSession: newSession,
        allSessions: allSessions,
        currentProgress: currentProgress,
        hasActiveSession: true,
      ));

      // Still dispatch a background reload for Firestore sync and missed-day check.
      add(LoadChallengeData());
    } catch (e, stack) {
      unawaited(_analytics.logError(e, stack));
      emit(ChallengeError('Failed to start new session: $e'));
    }
  }

  Future<void> _onRestartFromHistory(
    RestartFromHistory event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      await _smartNotifications.cancelAllRemindersForDate(DateTime.now());

      // Look up historical session by ID
      final allSessions = _repository.getAllSessions();
      final historicalSession = allSessions
          .where((session) => session.id == event.sessionId)
          .firstOrNull;

      if (historicalSession == null) {
        emit(const ChallengeError('Failed to restart: session not found'));
        return;
      }

      // Deactivate any active session
      final activeSession = await _repository.getActiveSession();
      if (activeSession != null) {
        final endedSession = activeSession.copyWith(
          isActive: false,
          endDate: DateTime.now(),
        );
        await _repository.updateSession(endedSession);
      }

      await _repository.clearAllDailyProgress();

      final newSession = createRestartedSession(historicalSession);
      await _repository.saveSession(newSession);

      // Emit immediately so the UI shows the new session without a loading gap.
      final updatedSessions = _repository.getAllSessions();
      final currentProgress =
          _repository.getProgressForSession(newSession.startDate);
      emit(ChallengeLoaded(
        activeSession: newSession,
        allSessions: updatedSessions,
        currentProgress: currentProgress,
        hasActiveSession: true,
      ));

      // Analytics — non-critical, fire-and-forget
      unawaited(_analytics.logSessionStart(newSession.challenges.length));
      unawaited(_analytics.logChallengeSelection(
        newSession.challenges.map((c) => c.title).toList(),
      ));

      // Notifications — non-critical
      try {
        await _smartNotifications.scheduleSmartReminders(
          DateTime.now(),
          newSession.challenges,
          null,
        );
      } catch (_) {
        // Notification failures should not block the restart
      }

      // Background reload for Firestore sync and missed-day check.
      add(LoadChallengeData());
    } catch (e, stack) {
      unawaited(_analytics.logError(e, stack));
      emit(ChallengeError('Failed to restart challenge: $e'));
    }
  }

  Future<void> _onUpdateDailyProgress(
    UpdateDailyProgress event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      // ── Partner permission check ──
      // If this challenge has an accountability partner assigned,
      // only that partner can toggle completion.
      final svc = AccountabilityService();
      final assignedMap = await svc.fetchAssignedChallengeMap();
      final accountableForMap = await svc.fetchAccountableForMap();
      final partnerUid = assignedMap[event.challengeId];
      final iAmPartner = accountableForMap.containsKey(event.challengeId);

      if (partnerUid != null && partnerUid.isNotEmpty) {
        // Task has an assigned partner — only they can toggle
        if (svc.currentUid != partnerUid) {
          emit(const ChallengeError(
              'Only your accountability partner can mark this task as complete.'));
          return;
        }
      } else if (iAmPartner) {
        // I am the accountable partner — allowed, continue
      }

      final activeSession = await _repository.getActiveSession();
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

      // Emit updated state IMMEDIATELY so the UI responds instantly.
      final currentProgress =
          _repository.getProgressForSession(activeSession.startDate);
      final allSessions = _repository.getAllSessions();
      emit(ChallengeLoaded(
        activeSession: activeSession,
        currentProgress: currentProgress,
        allSessions: allSessions,
        hasActiveSession: true,
      ));

      // Publish progress to Firestore so accountability partners can see it.
      // Fire-and-forget — never block the UI.
      unawaited(() async {
        try {
          final nonRegular = activeSession.challenges
              .where((c) => c.taskType != 'regular')
              .toList();
          final completedCount = nonRegular
              .where((c) => updatedProgress.challengeCompletions[c.id] == true)
              .length;
          final dateKey =
              '${event.date.year}-${event.date.month.toString().padLeft(2, '0')}-${event.date.day.toString().padLeft(2, '0')}';
          await AccountabilityService().publishDailyProgress(
            dateKey: dateKey,
            completedTasks: completedCount,
            totalTasks: nonRegular.length,
            dayCompleted: updatedProgress.isCompleted,
            currentDay: _computeCurrentDay(activeSession),
            taskDetails: nonRegular
                .map((c) => {
                      'name': c.title,
                      'completed':
                          updatedProgress.challengeCompletions[c.id] == true,
                      'type': c.taskType,
                    })
                .toList(),
          );
        } catch (_) {}
      }());

      // Notification and analytics calls are non-critical — run after emit
      // so the toggle always feels instant.
      try {
        if (event.isCompleted) {
          await _smartNotifications
              .cancelCompletedTaskReminders(event.challengeId);

          final challenge = activeSession.challenges
              .where((c) => c.id == event.challengeId)
              .firstOrNull;
          if (challenge != null) {
            unawaited(_analytics.logTaskComplete(
              challenge.title,
              _computeCurrentDay(activeSession),
            ));
          }
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
          await _smartNotifications.cancelNightSummaries();
        }
      } catch (notifError, notifStack) {
        // Log but don't fail the toggle — data is already saved
        unawaited(_analytics.logError(notifError, notifStack));
      }
    } catch (e, stack) {
      unawaited(_analytics.logError(e, stack));
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
      final activeSession = await _repository.getActiveSession();
      var dailyProgress = _repository.getDailyProgress(event.date);
      if (dailyProgress == null && activeSession != null) {
        // Create a fresh DailyProgress entry if none exists yet
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
      if (dailyProgress != null) {
        final updatedProgress = dailyProgress.copyWith(journalNote: event.note);
        await _repository.saveDailyProgress(updatedProgress);
        add(LoadChallengeData());
      }
    } catch (e, stack) {
      unawaited(_analytics.logError(e, stack));
      emit(ChallengeError('Failed to add journal note: $e'));
    }
  }

  Future<void> _onAddTaskNote(
    AddTaskNote event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = await _repository.getActiveSession();
      var dailyProgress = _repository.getDailyProgress(event.date);
      if (dailyProgress == null && activeSession != null) {
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
      unawaited(_analytics.logError(e, stack));
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
      unawaited(_analytics.logError(e, stack));
      emit(ChallengeError('Failed to add task photo: $e'));
    }
  }

  Future<void> _onResetChallenge(
    ResetChallenge event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = await _repository.getActiveSession();
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
        unawaited(_analytics.logSessionReset(
          activeSession.currentDay,
          event.reason,
        ));

        // Cancel accountability tasks for challenges that failed
        final svc = AccountabilityService();
        final failedChallengeIds = activeSession.challenges
            .where((c) => event.failedChallenges.contains(c.title))
            .map((c) => c.id)
            .toList();
        for (final challengeId in failedChallengeIds) {
          final task = await svc.fetchTaskByChallengeId(challengeId);
          if (task != null) {
            await svc.cancelAccountabilityTask(task.id);
          }
        }

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
      unawaited(_analytics.logError(e, stack));
      emit(ChallengeError('Failed to reset challenge: $e'));
    }
  }

  Future<void> _onCompleteChallenge(
    CompleteChallenge event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = await _repository.getActiveSession();
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
      unawaited(_analytics.logSessionComplete(75));

      emit(ChallengeCompleted(completedSession));

      await Future.delayed(const Duration(seconds: 3));
      add(LoadChallengeData());
    } catch (e, stack) {
      unawaited(_analytics.logError(e, stack));
      emit(ChallengeError('Failed to complete challenge: $e'));
    }
  }

  Future<void> _onUpdateChallenge(
    UpdateChallenge event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = await _repository.getActiveSession();
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
      debugPrint('🟢 [BLoC] _onAddChallengeToSession called');
      debugPrint('🟢 [BLoC] challenge.id: ${event.challenge.id}');
      debugPrint('🟢 [BLoC] challenge.title: ${event.challenge.title}');
      debugPrint('🟢 [BLoC] challenge.taskType: ${event.challenge.taskType}');
      debugPrint(
          '🟢 [BLoC] challenge.showInRegularTab: ${event.challenge.showInRegularTab}');

      // Debug: log all sessions in the database
      final allSessionsDebug = _repository.getAllSessions();
      debugPrint('🟢 [BLoC] Total sessions in DB: ${allSessionsDebug.length}');
      for (final s in allSessionsDebug) {
        debugPrint(
            '🟢 [BLoC]   Session ${s.id}: isActive=${s.isActive}, isCompleted=${s.isCompleted}, mode=${s.resetMode}, challenges=${s.challenges.length}');
      }

      final activeSession = await _repository.getActiveSession();
      if (activeSession == null) {
        debugPrint(
            '🔴 [BLoC] No active session found after checking ${allSessionsDebug.length} sessions');
        return;
      }
      debugPrint('🟢 [BLoC] Active session found: ${activeSession.id}');
      debugPrint(
          '🟢 [BLoC] Current challenges count: ${activeSession.challenges.length}');

      final updatedChallenges = [...activeSession.challenges, event.challenge];
      final updatedSession =
          activeSession.copyWith(challenges: updatedChallenges);
      await _repository.saveSession(updatedSession);
      debugPrint(
          '🟢 [BLoC] Session saved with ${updatedChallenges.length} challenges');

      // Initialize the new challenge in today's DailyProgress so it shows immediately
      final today = DateTime.now();
      var todayProgress = _repository.getDailyProgress(today);
      debugPrint('🟢 [BLoC] Today progress exists: ${todayProgress != null}');

      if (todayProgress != null) {
        final updatedCompletions =
            Map<String, bool>.from(todayProgress.challengeCompletions);
        updatedCompletions[event.challenge.id] = false;
        todayProgress = todayProgress.copyWith(
          challengeCompletions: updatedCompletions,
        );
      } else {
        final challengeCompletions = <String, bool>{};
        for (final challenge in updatedChallenges) {
          challengeCompletions[challenge.id] = false;
        }
        todayProgress = DailyProgress(
          date: today,
          challengeCompletions: challengeCompletions,
          isCompleted: false,
        );
      }
      await _repository.saveDailyProgress(todayProgress);
      debugPrint(
          '🟢 [BLoC] DailyProgress saved with completions: ${todayProgress.challengeCompletions.keys.toList()}');

      final currentProgress =
          _repository.getProgressForSession(activeSession.startDate);
      final allSessions = _repository.getAllSessions();
      debugPrint(
          '🟢 [BLoC] Emitting ChallengeLoaded with ${updatedSession.challenges.length} challenges');

      // Log regular tasks specifically
      final regularTasks = updatedSession.challenges
          .where((c) => c.taskType == 'regular')
          .toList();
      debugPrint('🟢 [BLoC] Regular tasks in session: ${regularTasks.length}');
      for (final rt in regularTasks) {
        debugPrint(
            '🟢 [BLoC]   - ${rt.title} (showInRegularTab: ${rt.showInRegularTab})');
      }

      emit(ChallengeLoaded(
        activeSession: updatedSession,
        currentProgress: currentProgress,
        allSessions: allSessions,
        hasActiveSession: true,
      ));
      debugPrint('🟢 [BLoC] ChallengeLoaded emitted successfully');

      // Schedule reminders if the new task has them enabled
      try {
        if (event.challenge.isReminderEnabled &&
            event.challenge.reminderTime != null) {
          await _smartNotifications.scheduleSmartReminders(
            DateTime.now(),
            [event.challenge],
            null,
          );
        }
      } catch (e) {
        debugPrint('🔴 [BLoC] Reminder scheduling failed (non-critical): $e');
      }
    } catch (e, stack) {
      debugPrint('🔴 [BLoC] Error adding task: $e');
      debugPrint('🔴 [BLoC] Stack: $stack');
      emit(ChallengeError('Failed to add task: $e'));
    }
  }

  Future<void> _onUpdateChallengeReminder(
    UpdateChallengeReminder event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = await _repository.getActiveSession();
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

      final updatedChallenge =
          updatedChallenges.where((c) => c.id == event.challengeId).firstOrNull;

      if (updatedChallenge == null) {
        add(LoadChallengeData());
        return;
      }

      if (event.isEnabled && event.reminderTime != null) {
        await _smartNotifications.scheduleSmartReminders(
          DateTime.now(),
          [updatedChallenge],
          null,
        );
        unawaited(_analytics.logReminderSet(
          updatedChallenge.title,
          event.reminderTime!,
        ));
      } else {
        await _smartNotifications
            .cancelCompletedTaskReminders(event.challengeId);
      }

      add(LoadChallengeData());
    } catch (e, stack) {
      unawaited(_analytics.logError(e, stack));
      emit(ChallengeError('Failed to update reminder: $e'));
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────

  Future<void> _onRemoveChallengeFromSession(
    RemoveChallengeFromSession event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = await _repository.getActiveSession();
      if (activeSession == null) return;

      final updatedChallenges = activeSession.challenges
          .where((c) => c.id != event.challengeId)
          .toList();

      if (updatedChallenges.isEmpty) {
        emit(const ChallengeError('Cannot remove the last challenge.'));
        return;
      }

      final updatedSession =
          activeSession.copyWith(challenges: updatedChallenges);
      await _repository.saveSession(updatedSession);

      // Cancel any pending reminders for the removed challenge
      await _smartNotifications.cancelCompletedTaskReminders(event.challengeId);

      // Recalculate daily progress completion flags for all existing progress
      // entries, since removing a challenge changes which tasks are required.
      final allProgress =
          _repository.getProgressForSession(activeSession.startDate);
      for (final progress in allProgress) {
        // Remove the deleted challenge from completions map
        final updatedCompletions =
            Map<String, bool>.from(progress.challengeCompletions)
              ..remove(event.challengeId);

        // Recalculate isCompleted based on remaining non-regular challenges
        final allCompleted = updatedChallenges
            .where((c) => c.taskType != 'regular')
            .every((c) => updatedCompletions[c.id] == true);

        final updatedProgress = progress.copyWith(
          challengeCompletions: updatedCompletions,
          isCompleted: allCompleted,
        );
        await _repository.saveDailyProgress(updatedProgress);
      }

      add(LoadChallengeData());
    } catch (e) {
      emit(ChallengeError('Failed to remove challenge: $e'));
    }
  }

  Future<void> _onEndActiveSession(
    EndActiveSession event,
    Emitter<ChallengeState> emit,
  ) async {
    try {
      final activeSession = await _repository.getActiveSession();
      if (activeSession == null) return;

      // Cancel only this session's reminders — regular-task reminders and any
      // other pending challenge reminders must keep working.
      for (final challenge in activeSession.challenges) {
        if (challenge.isReminderEnabled) {
          await _smartNotifications.cancelCompletedTaskReminders(challenge.id);
        }
      }
      await _smartNotifications.cancelNightSummaries();

      final endedSession = activeSession.copyWith(
        isActive: false,
        endDate: DateTime.now(),
      );
      await _repository.updateSession(endedSession);
      add(LoadChallengeData());
    } catch (e) {
      emit(ChallengeError('Failed to end the challenge: $e'));
    }
  }

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
