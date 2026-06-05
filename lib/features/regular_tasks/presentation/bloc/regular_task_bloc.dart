import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seventy_five_hard_tracker/features/regular_tasks/data/models/regular_task_completion.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';
import 'package:seventy_five_hard_tracker/services/smart_notification_service.dart';
import 'regular_task_event.dart';
import 'regular_task_state.dart';

class RegularTaskBloc extends Bloc<RegularTaskEvent, RegularTaskState> {
  final RegularTaskRepository _repository;
  final SmartNotificationService _notifications;

  RegularTaskBloc({
    required RegularTaskRepository repository,
    required SmartNotificationService notifications,
  })  : _repository = repository,
        _notifications = notifications,
        super(RegularTaskInitial()) {
    on<LoadRegularTasks>(_onLoadRegularTasks);
    on<AddRegularTask>(_onAddRegularTask);
    on<UpdateRegularTask>(_onUpdateRegularTask);
    on<DeleteRegularTask>(_onDeleteRegularTask);
    on<ToggleRegularTaskCompletion>(_onToggleCompletion);
    on<UpdateRegularTaskReminder>(_onUpdateReminder);
  }

  Future<void> _onLoadRegularTasks(
    LoadRegularTasks event,
    Emitter<RegularTaskState> emit,
  ) async {
    emit(RegularTaskLoading());
    try {
      await _repository.init();
      final tasks = _repository.getActiveTasks();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayCompletion = _repository.getCompletion(today);
      final todayCompletions = todayCompletion?.taskCompletions ?? {};

      final thirtyDaysAgo = today.subtract(const Duration(days: 30));
      final recentCompletions =
          _repository.getCompletionsInRange(thirtyDaysAgo, today);

      emit(RegularTaskLoaded(
        tasks: tasks,
        todayCompletions: Map<String, bool>.from(todayCompletions),
        recentCompletions: recentCompletions,
      ));
    } catch (e) {
      emit(RegularTaskError('Failed to load regular tasks: $e'));
    }
  }

  Future<void> _onAddRegularTask(
    AddRegularTask event,
    Emitter<RegularTaskState> emit,
  ) async {
    try {
      await _repository.saveTask(event.task);
      add(LoadRegularTasks());
    } catch (e) {
      emit(RegularTaskError('Failed to add regular task: $e'));
    }
  }

  Future<void> _onUpdateRegularTask(
    UpdateRegularTask event,
    Emitter<RegularTaskState> emit,
  ) async {
    try {
      await _repository.saveTask(event.task);
      add(LoadRegularTasks());
    } catch (e) {
      emit(RegularTaskError('Failed to update regular task: $e'));
    }
  }

  Future<void> _onDeleteRegularTask(
    DeleteRegularTask event,
    Emitter<RegularTaskState> emit,
  ) async {
    try {
      await _repository.archiveTask(event.taskId);
      add(LoadRegularTasks());
    } catch (e) {
      emit(RegularTaskError('Failed to delete regular task: $e'));
    }
  }

  Future<void> _onToggleCompletion(
    ToggleRegularTaskCompletion event,
    Emitter<RegularTaskState> emit,
  ) async {
    try {
      final date = DateTime(event.date.year, event.date.month, event.date.day);
      var completion = _repository.getCompletion(date);

      final updatedCompletions =
          Map<String, bool>.from(completion?.taskCompletions ?? {});
      updatedCompletions[event.taskId] = event.isCompleted;

      completion = RegularTaskCompletion(
        date: date,
        taskCompletions: updatedCompletions,
      );
      await _repository.saveCompletion(completion);

      // Emit updated state IMMEDIATELY so the UI responds instantly.
      final tasks = _repository.getActiveTasks();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayCompletion = _repository.getCompletion(today);
      final todayCompletions = todayCompletion?.taskCompletions ?? {};

      final thirtyDaysAgo = today.subtract(const Duration(days: 30));
      final recentCompletions =
          _repository.getCompletionsInRange(thirtyDaysAgo, today);

      emit(RegularTaskLoaded(
        tasks: tasks,
        todayCompletions: Map<String, bool>.from(todayCompletions),
        recentCompletions: recentCompletions,
      ));

      // Cancel reminder after emit — non-critical
      if (event.isCompleted) {
        try {
          await _notifications.cancelCompletedTaskReminders(event.taskId);
        } catch (_) {
          // Notification failure should not affect the toggle
        }
      }
    } catch (e) {
      emit(RegularTaskError('Failed to toggle task completion: $e'));
    }
  }

  Future<void> _onUpdateReminder(
    UpdateRegularTaskReminder event,
    Emitter<RegularTaskState> emit,
  ) async {
    try {
      await _repository.saveTask(event.task);

      if (event.task.isReminderEnabled && event.task.reminderTime != null) {
        await _notifications.scheduleSmartReminders(
          DateTime.now(),
          [event.task.toChallenge()],
          null,
        );
      } else {
        await _notifications.cancelCompletedTaskReminders(event.task.id);
      }

      add(LoadRegularTasks());
    } catch (e) {
      emit(RegularTaskError('Failed to update reminder: $e'));
    }
  }
}
