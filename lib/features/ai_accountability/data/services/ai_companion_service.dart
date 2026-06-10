import '../models/ai_message_model.dart';

class AICompanionService {
  AIMessage generateMessage({
    required int completedTasks,
    required int totalTasks,
    required int streak,
  }) {
    // Streak milestones
    if (streak == 75) {
      return AIMessage(
        title: '🏆 Challenge Complete',
        message:
            'You completed the full 75 Hard challenge. Incredible discipline and consistency!',
        createdAt: DateTime.now(),
      );
    }

    if (streak == 50) {
      return AIMessage(
        title: '🔥 50 Day Streak',
        message:
            'You have reached a 50 day streak. Keep pushing towards the finish line.',
        createdAt: DateTime.now(),
      );
    }

    if (streak == 30) {
      return AIMessage(
        title: '🎯 30 Day Milestone',
        message:
            'Amazing consistency. You have maintained your streak for 30 days.',
        createdAt: DateTime.now(),
      );
    }

    // Perfect completion
    if (completedTasks == totalTasks && totalTasks > 0) {
      return AIMessage(
        title: '✅ Excellent Work',
        message:
            'You completed all tasks today and maintained your streak.',
        createdAt: DateTime.now(),
      );
    }

    // No progress
    if (completedTasks == 0) {
      return AIMessage(
        title: '💪 Fresh Start Tomorrow',
        message:
            'You missed today, but tomorrow is another opportunity to get back on track.',
        createdAt: DateTime.now(),
      );
    }

    // Almost done
    if (completedTasks >= totalTasks - 1) {
      return AIMessage(
        title: '⚡ Almost There',
        message:
            'Only a few tasks remain. Complete them to keep your momentum going.',
        createdAt: DateTime.now(),
      );
    }

    return AIMessage(
      title: '🚀 Keep Going',
      message:
          'You are making progress. Stay focused and finish your remaining tasks.',
      createdAt: DateTime.now(),
    );
  }
}