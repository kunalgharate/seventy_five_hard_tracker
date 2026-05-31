import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';

/// Predefined task templates for common challenge categories.
class TaskTemplates {
  static const List<TaskTemplate> all = [
    // Fitness
    TaskTemplate(
        title: 'Workout 45 minutes',
        category: 'fitness',
        iconName: 'fitness_center'),
    TaskTemplate(
        title: 'Gym session', category: 'fitness', iconName: 'fitness_center'),
    TaskTemplate(
        title: 'Run 5km', category: 'fitness', iconName: 'directions_run'),
    TaskTemplate(
        title: 'Yoga 30 minutes',
        category: 'fitness',
        iconName: 'self_improvement'),
    TaskTemplate(
        title: '10,000 steps',
        category: 'fitness',
        iconName: 'directions_walk'),

    // Mindfulness
    TaskTemplate(
        title: 'Meditate 15 minutes',
        category: 'meditation',
        iconName: 'self_improvement'),
    TaskTemplate(
        title: 'Breathing exercises', category: 'meditation', iconName: 'air'),
    TaskTemplate(
        title: 'Gratitude journaling',
        category: 'meditation',
        iconName: 'edit_note'),

    // Nutrition
    TaskTemplate(
        title: 'Drink 3L water', category: 'water', iconName: 'water_drop'),
    TaskTemplate(
        title: 'No junk food', category: 'nutrition', iconName: 'no_food'),
    TaskTemplate(
        title: 'Eat healthy meal',
        category: 'nutrition',
        iconName: 'restaurant'),
    TaskTemplate(
        title: 'No alcohol', category: 'nutrition', iconName: 'no_drinks'),

    // Learning
    TaskTemplate(
        title: 'Read 10 pages', category: 'reading', iconName: 'menu_book'),
    TaskTemplate(
        title: 'Learn something new', category: 'reading', iconName: 'school'),
    TaskTemplate(
        title: 'Listen to podcast',
        category: 'reading',
        iconName: 'headphones'),

    // Productivity
    TaskTemplate(
        title: 'Wake up at 5 AM', category: 'sleep', iconName: 'alarm'),
    TaskTemplate(
        title: 'No social media',
        category: 'productivity',
        iconName: 'phone_disabled'),
    TaskTemplate(title: 'Cold shower', category: 'general', iconName: 'shower'),
    TaskTemplate(
        title: 'Take progress photo',
        category: 'general',
        iconName: 'camera_alt'),
    TaskTemplate(
        title: 'Sleep by 10 PM', category: 'sleep', iconName: 'bedtime'),
  ];

  /// Get templates grouped by category.
  static Map<String, List<TaskTemplate>> get grouped {
    final map = <String, List<TaskTemplate>>{};
    for (final t in all) {
      map.putIfAbsent(t.category, () => []).add(t);
    }
    return map;
  }

  /// Convert a template to a Challenge model.
  static Challenge toChallenge(TaskTemplate template,
      {String taskType = 'hard'}) {
    return Challenge(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: template.title,
      category: template.category,
      iconName: template.iconName,
      taskType: taskType,
      isReminderEnabled: true,
      reminderStartHour: 8,
      reminderEndHour: 22,
      allowNightReminders: true,
    );
  }
}

class TaskTemplate {
  final String title;
  final String category;
  final String iconName;

  const TaskTemplate({
    required this.title,
    required this.category,
    required this.iconName,
  });
}
