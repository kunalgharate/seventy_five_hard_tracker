import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/challenge.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await NotificationService()._init();
  }

  Future<void> _init() async {
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(initSettings);
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  Future<void> scheduleDailyMotivation() async {
    await _notifications.zonedSchedule(
      0, // Notification ID
      '75 Hard Challenge',
      _getMotivationalMessage(),
      _nextInstanceOf8AM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_motivation',
          'Daily Motivation',
          channelDescription: 'Daily motivational messages for 75 Hard Challenge',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleTaskReminder(Challenge challenge, String time) async {
    if (!challenge.isReminderEnabled || challenge.reminderTime == null) return;

    // Cancel any existing reminders for this challenge
    await cancelTaskReminder(challenge.id);

    // Parse reminder data to determine type and schedule accordingly
    final reminderData = challenge.reminderTime!;
    
    if (reminderData.startsWith('once:')) {
      await _scheduleOnceReminder(challenge, reminderData.substring(5));
    } else if (reminderData.startsWith('multiple:')) {
      await _scheduleMultipleReminders(challenge, reminderData.substring(9));
    } else if (reminderData.startsWith('hourly:')) {
      await _scheduleHourlyReminders(challenge, reminderData.substring(7));
    } else if (reminderData.startsWith('interval:')) {
      await _scheduleIntervalReminders(challenge, reminderData.substring(9));
    } else if (reminderData.startsWith('custom:')) {
      await _scheduleCustomReminders(challenge, reminderData.substring(7));
    } else {
      // Fallback to simple daily reminder
      await _scheduleOnceReminder(challenge, time);
    }
  }

  Future<void> _scheduleOnceReminder(Challenge challenge, String time) async {
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    await _notifications.zonedSchedule(
      challenge.id.hashCode,
      '75 Hard Reminder',
      'Time for: ${challenge.title}',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Reminders for individual challenge tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleMultipleReminders(Challenge challenge, String timesData) async {
    final times = timesData.split(',');
    for (int i = 0; i < times.length; i++) {
      final timeParts = times[i].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      await _notifications.zonedSchedule(
        challenge.id.hashCode + i, // Unique ID for each reminder
        '75 Hard Reminder',
        'Time for: ${challenge.title}',
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Reminders for individual challenge tasks',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _scheduleHourlyReminders(Challenge challenge, String startTime) async {
    final timeParts = startTime.split(':');
    final startHour = int.parse(timeParts[0]);
    
    // Schedule hourly reminders from start time until 10 PM
    for (int hour = startHour; hour <= 22; hour++) {
      await _notifications.zonedSchedule(
        challenge.id.hashCode + hour, // Unique ID for each hour
        '75 Hard Reminder',
        'Hourly reminder: ${challenge.title}',
        _nextInstanceOfTime(hour, 0),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Reminders for individual challenge tasks',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _scheduleIntervalReminders(Challenge challenge, String intervalData) async {
    final parts = intervalData.split(':');
    final intervalMinutes = int.parse(parts[0]);
    final startTimeParts = parts[1].split(':');
    final startHour = int.parse(startTimeParts[0]);
    final startMinute = int.parse(startTimeParts[1]);
    
    // Calculate how many reminders fit in the day
    final startTimeInMinutes = startHour * 60 + startMinute;
    final endTimeInMinutes = 22 * 60; // 10 PM
    final totalMinutes = endTimeInMinutes - startTimeInMinutes;
    final numberOfReminders = (totalMinutes / intervalMinutes).floor() + 1;
    
    for (int i = 0; i < numberOfReminders; i++) {
      final reminderTimeInMinutes = startTimeInMinutes + (i * intervalMinutes);
      if (reminderTimeInMinutes > endTimeInMinutes) break;
      
      final hour = (reminderTimeInMinutes / 60).floor();
      final minute = reminderTimeInMinutes % 60;
      
      await _notifications.zonedSchedule(
        challenge.id.hashCode + i,
        '75 Hard Reminder',
        'Interval reminder: ${challenge.title}',
        _nextInstanceOfTime(hour, minute.toInt()),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            'Task Reminders',
            channelDescription: 'Reminders for individual challenge tasks',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _scheduleCustomReminders(Challenge challenge, String timesData) async {
    // Same as multiple reminders
    await _scheduleMultipleReminders(challenge, timesData);
  }

  Future<void> cancelTaskReminder(String challengeId) async {
    // Cancel multiple possible notification IDs for this challenge
    final baseId = challengeId.hashCode;
    
    // Cancel up to 50 possible notifications (covers hourly, interval, and multiple reminders)
    for (int i = 0; i < 50; i++) {
      await _notifications.cancel(baseId + i);
    }
  }

  Future<void> showFailureNotification(int daysFailed, List<String> failedTasks) async {
    final taskList = failedTasks.join(', ');
    await _notifications.show(
      999, // Special ID for failure notifications
      'Challenge Reset!',
      'You missed: $taskList on day $daysFailed. Starting over from Day 1!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'challenge_reset',
          'Challenge Reset',
          channelDescription: 'Notifications when challenge is reset',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
    );
  }

  Future<void> showCompletionNotification() async {
    await _notifications.show(
      1000, // Special ID for completion
      '🎉 Congratulations! 🎉',
      'You completed the 75 Hard Challenge! You are amazing!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'challenge_completion',
          'Challenge Completion',
          channelDescription: 'Notification for completing the 75 Hard Challenge',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
    );
  }

  tz.TZDateTime _nextInstanceOf8AM() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  String _getMotivationalMessage() {
    final messages = [
      "Today is another chance to become the person you want to be!",
      "Discipline is choosing between what you want now and what you want most.",
      "The only impossible journey is the one you never begin.",
      "Success is the sum of small efforts repeated day in and day out.",
      "You are stronger than you think and more capable than you imagine.",
      "Every day is a new opportunity to improve yourself.",
      "The pain of discipline weighs ounces, but the pain of regret weighs tons.",
      "Your only limit is your mind. Push through!",
      "Great things never come from comfort zones.",
      "The difference between ordinary and extraordinary is that little extra.",
      "You didn't come this far to only come this far.",
      "Believe in yourself and all that you are.",
      "Champions keep playing until they get it right.",
      "The harder you work, the luckier you get.",
      "Don't stop when you're tired. Stop when you're done.",
    ];
    
    final now = DateTime.now();
    final index = now.day % messages.length;
    return messages[index];
  }
}
