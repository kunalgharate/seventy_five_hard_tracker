import 'package:equatable/equatable.dart';
import '../models/regular_task.dart';
import '../models/regular_task_completion.dart';

abstract class RegularTaskState extends Equatable {
  const RegularTaskState();

  @override
  List<Object?> get props => [];
}

class RegularTaskInitial extends RegularTaskState {}

class RegularTaskLoading extends RegularTaskState {}

class RegularTaskLoaded extends RegularTaskState {
  final List<RegularTask> tasks;
  final Map<String, bool> todayCompletions;
  final List<RegularTaskCompletion> recentCompletions;

  const RegularTaskLoaded({
    required this.tasks,
    required this.todayCompletions,
    required this.recentCompletions,
  });

  @override
  List<Object?> get props => [tasks, todayCompletions, recentCompletions];

  RegularTaskLoaded copyWith({
    List<RegularTask>? tasks,
    Map<String, bool>? todayCompletions,
    List<RegularTaskCompletion>? recentCompletions,
  }) {
    return RegularTaskLoaded(
      tasks: tasks ?? this.tasks,
      todayCompletions: todayCompletions ?? this.todayCompletions,
      recentCompletions: recentCompletions ?? this.recentCompletions,
    );
  }
}

class RegularTaskError extends RegularTaskState {
  final String message;

  const RegularTaskError(this.message);

  @override
  List<Object> get props => [message];
}
