enum ReminderType {
  custom, // Specific times set by user
  hourly, // Every hour
  interval, // Every X hours (2, 3, 4, etc.)
  daily, // Once or multiple times per day
}

class TaskReminder {
  String id;
  String challengeId; // Links to the challenge this reminder is for
  ReminderType type;
  List<DateTime> customTimes; // For custom and daily types
  int intervalHours; // For interval type (2, 3, 4 hours)
  DateTime startTime; // When to start reminders (for hourly/interval)
  DateTime endTime; // When to stop reminders (for hourly/interval)
  bool isEnabled;
  List<DateTime> completedTimes; // Track when user completed the task
  DateTime createdAt;

  TaskReminder({
    required this.id,
    required this.challengeId,
    required this.type,
    this.customTimes = const [],
    this.intervalHours = 1,
    required this.startTime,
    required this.endTime,
    this.isEnabled = true,
    this.completedTimes = const [],
    required this.createdAt,
  });

  // Get all reminder times for a specific date
  List<DateTime> getReminderTimesForDate(DateTime date) {
    final List<DateTime> times = [];
    
    switch (type) {
      case ReminderType.custom:
        for (final time in customTimes) {
          times.add(DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ));
        }
        break;
        
      case ReminderType.hourly:
        for (int hour = startTime.hour; hour <= endTime.hour; hour++) {
          times.add(DateTime(date.year, date.month, date.day, hour));
        }
        break;
        
      case ReminderType.interval:
        for (int hour = startTime.hour; hour <= endTime.hour; hour += intervalHours) {
          times.add(DateTime(date.year, date.month, date.day, hour));
        }
        break;
        
      case ReminderType.daily:
        for (final time in customTimes) {
          times.add(DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ));
        }
        break;
    }
    
    return times;
  }

  // Check if a specific time is completed
  bool isTimeCompleted(DateTime dateTime) {
    return completedTimes.any((completed) =>
        completed.year == dateTime.year &&
        completed.month == dateTime.month &&
        completed.day == dateTime.day &&
        completed.hour == dateTime.hour &&
        (type == ReminderType.custom || type == ReminderType.daily 
            ? completed.minute == dateTime.minute 
            : true));
  }

  // Get completion count for a specific date
  int getCompletionCountForDate(DateTime date) {
    return completedTimes.where((completed) =>
        completed.year == date.year &&
        completed.month == date.month &&
        completed.day == date.day).length;
  }

  // Get total expected completions for a date
  int getExpectedCompletionsForDate(DateTime date) {
    return getReminderTimesForDate(date).length;
  }

  // Get completion percentage for a date
  double getCompletionPercentageForDate(DateTime date) {
    final expected = getExpectedCompletionsForDate(date);
    if (expected == 0) return 0.0;
    final completed = getCompletionCountForDate(date);
    return (completed / expected).clamp(0.0, 1.0);
  }
}
