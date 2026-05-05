import 'package:equatable/equatable.dart';
import '../models/regular_task.dart';

abstract class RegularTaskEvent extends Equatable {
  const RegularTaskEvent();

  @override
  List<Object?> get props => [];
}

class LoadRegularTasks extends RegularTaskEvent {}

class AddRegularTask extends RegularTaskEvent {
  final RegularTask task;

  const AddRegularTask(this.task);

  @override
  List<Object> get props => [task];
}

class UpdateRegularTask extends RegularTaskEvent {
  final RegularTask task;

  const UpdateRegularTask(this.task);

  @override
  List<Object> get props => [task];
}

class DeleteRegularTask extends RegularTaskEvent {
  final String taskId;

  const DeleteRegularTask(this.taskId);

  @override
  List<Object> get props => [taskId];
}

class ToggleRegularTaskCompletion extends RegularTaskEvent {
  final String taskId;
  final DateTime date;
  final bool isCompleted;

  const ToggleRegularTaskCompletion({
    required this.taskId,
    required this.date,
    required this.isCompleted,
  });

  @override
  List<Object> get props => [taskId, date, isCompleted];
}

class UpdateRegularTaskReminder extends RegularTaskEvent {
  final RegularTask task;

  const UpdateRegularTaskReminder(this.task);

  @override
  List<Object> get props => [task];
}
