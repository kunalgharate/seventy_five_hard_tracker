// AI Companion Event
abstract class AICompanionEvent {}

class LoadAIMessage extends AICompanionEvent {
  final int completedTasks;
  final int totalTasks;
  final int streak;

  LoadAIMessage({
    required this.completedTasks,
    required this.totalTasks,
    required this.streak,
  });
}
