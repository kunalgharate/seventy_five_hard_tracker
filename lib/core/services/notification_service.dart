import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Track scheduled notifications to avoid Samsung's 500 alarm limit
  static int _scheduledNotificationCount = 0;
  static const int _maxNotifications = 400; // Safe limit below Samsung's 500

  static Future<void> initialize() async {
    await NotificationService()._init();
  }

  Future<void> _init() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    // Get device timezone info
    final now = DateTime.now();
    final offset = now.timeZoneOffset;

    // Set timezone based on device offset
    try {
      // Try common timezone names first
      if (offset.inHours == 5 && offset.inMinutes == 330) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } else {
        // Fallback to UTC and handle offset manually
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const initSettings = InitializationSettings(android: androidSettings);

    // Create notification channels with tune.wav
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Daily motivation channel
      const dailyChannel = AndroidNotificationChannel(
        'daily_motivation_v2',
        'Daily Motivation',
        description: 'Daily motivational messages for 75 Hard Challenge',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('tune'),
        enableVibration: true,
      );

      // Task reminders channel
      const taskChannel = AndroidNotificationChannel(
        'task_reminders_v2',
        'Task Reminders',
        description: 'Reminders for individual challenge tasks',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('tune'),
        enableVibration: true,
      );

      // Pending tasks channel
      const pendingChannel = AndroidNotificationChannel(
        'pending_tasks',
        'Pending Tasks',
        description: 'Reminder for incomplete daily tasks',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('tune'),
        enableVibration: true,
      );

      await androidPlugin.createNotificationChannel(dailyChannel);
      await androidPlugin.createNotificationChannel(taskChannel);
      await androidPlugin.createNotificationChannel(pendingChannel);
    }

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _requestPermissions();
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap here
  }

  Future<void> _requestPermissions() async {
    // Use flutter_local_notifications API for permission requests
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Request notification permission (Android 13+)

      // Request exact alarm permission
    }
  }

  // Test method to send immediate notification
  Future<void> sendTestNotification() async {
    try {
      await _notifications.show(
        999, // Test notification ID
        'Test Notification',
        'This is a test notification to verify the system works',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Test Notifications',
            channelDescription: 'Test notifications to verify system works',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Notification error in sendTestNotification: $e');
    }
  }

  // Test method to schedule notification in 10 seconds
  Future<void> scheduleTestNotification() async {
    try {
      final scheduledTime =
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));

      await _notifications.zonedSchedule(
        998, // Test scheduled notification ID
        'Scheduled Test',
        'This scheduled test notification should appear in 10 seconds',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Test Notifications',
            channelDescription: 'Test notifications to verify system works',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Notification error in scheduleTestNotification: $e');
      }
    }
  }

  // Simple test following the guide pattern
  Future<void> scheduleSimpleTest() async {
    final DateTime scheduledTime =
        DateTime.now().add(const Duration(seconds: 30));
    final tz.TZDateTime tzScheduleTime =
        tz.TZDateTime.from(scheduledTime, tz.local);

    try {
      await _notifications.zonedSchedule(
        997,
        'Simple Test',
        'This is a simple test notification in 30 seconds',
        tzScheduleTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'main_channel',
            'Main Channel',
            channelDescription: 'Main notification channel',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) print('Notification error in scheduleSimpleTest: $e');
    }
  }

  Future<void> scheduleDailyMotivation() async {
    try {
      // Fetch motivational message (online or offline)
      final message = await _fetchMotivationalMessage();

      await _notifications.zonedSchedule(
        0, // Notification ID
        '75 Hard Challenge',
        message,
        _nextInstanceOf8AM(),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_motivation_v2',
            'Daily Motivation',
            channelDescription:
                'Daily motivational messages for 75 Hard Challenge',
            importance: Importance.max,
            priority: Priority.max,
            sound: RawResourceAndroidNotificationSound('tune'),
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Notification error in scheduleDailyMotivation: $e');
      }
    }
  }

  Future<String> _fetchMotivationalMessage() async {
    try {
      // Try to fetch from ZenQuotes API
      final response = await http
          .get(
            Uri.parse('https://zenquotes.io/api/random'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final quote = data[0]['q'] as String;
          final author = data[0]['a'] as String;
          return '$quote - $author';
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Notification error in _fetchMotivationalMessage: $e');
      }
    }

    // Fallback to offline messages
    return _getMotivationalMessage();
  }

  Future<void> scheduleTaskReminder(Challenge challenge, String time) async {
    if (!challenge.isReminderEnabled || challenge.reminderTime == null) {
      return;
    }

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
      // Handle both simple time format (18:03) and fallback
      await _scheduleOnceReminder(challenge, reminderData);
    }
  }

  Future<void> _scheduleOnceReminder(Challenge challenge, String time) async {
    try {
      final timeParts = time.split(':');

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final scheduledTime = _nextInstanceOfTime(hour, minute);

      final notificationId = challenge.id.hashCode;

      if (_canScheduleMoreNotifications()) {
        await _notifications.zonedSchedule(
          notificationId,
          '75 Hard Reminder',
          'Time for: ${challenge.title}',
          scheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_reminders_v2',
              'Task Reminders',
              channelDescription: 'Reminders for individual challenge tasks',
              importance: Importance.max,
              priority: Priority.max,
              sound: RawResourceAndroidNotificationSound('tune'),
              playSound: true,
              enableVibration: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        _scheduledNotificationCount++;
      } else {
        if (kDebugMode) {
          print(
              'Notification error in _scheduleOnceReminder: max notifications reached');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Notification error in _scheduleOnceReminder: $e');
    }
  }

  Future<void> _scheduleMultipleReminders(
      Challenge challenge, String timesData) async {
    final times = timesData.split(',');
    for (int i = 0; i < times.length; i++) {
      final timeParts = times[i].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      if (_canScheduleMoreNotifications()) {
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
          matchDateTimeComponents: DateTimeComponents.time,
        );
        _scheduledNotificationCount++;
      } else {
        break;
      }
    }
  }

  Future<void> _scheduleHourlyReminders(
      Challenge challenge, String startTime) async {
    final timeParts = startTime.split(':');
    final startHour = int.parse(timeParts[0]);
    final startMinute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;

    // Schedule hourly reminders from start time until 11 PM (23:00)
    for (int hour = startHour; hour <= 23; hour++) {
      if (_canScheduleMoreNotifications()) {
        await _notifications.zonedSchedule(
          challenge.id.hashCode + hour, // Unique ID for each hour
          '75 Hard Reminder',
          'Hourly reminder: ${challenge.title}',
          _nextInstanceOfTime(hour, startMinute),
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
          matchDateTimeComponents: DateTimeComponents.time,
        );
        _scheduledNotificationCount++;
      } else {
        break;
      }
    }
  }

  Future<void> _scheduleIntervalReminders(
      Challenge challenge, String intervalData) async {
    try {
      // Parse interval data - expecting format like "15:09:00" (15 min interval starting at 09:00)
      final parts = intervalData.split(':');

      if (parts.length < 3) {
        return;
      }

      final intervalMinutes = int.parse(parts[0]);
      final startHour = int.parse(parts[1]);
      final startMinute = int.parse(parts[2]);

      // Calculate how many reminders fit in the day (from start time to 10 PM)
      final startTimeInMinutes = startHour * 60 + startMinute;
      const endTimeInMinutes = 22 * 60; // 10 PM
      final totalMinutes = endTimeInMinutes - startTimeInMinutes;
      final numberOfReminders = (totalMinutes / intervalMinutes).floor() + 1;

      for (int i = 0; i < numberOfReminders; i++) {
        final reminderTimeInMinutes =
            startTimeInMinutes + (i * intervalMinutes);
        if (reminderTimeInMinutes > endTimeInMinutes) break;

        final hour = (reminderTimeInMinutes / 60).floor();
        final minute = reminderTimeInMinutes % 60;

        if (_canScheduleMoreNotifications()) {
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
            matchDateTimeComponents: DateTimeComponents.time,
          );
          _scheduledNotificationCount++;
        } else {
          break;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Notification error in _scheduleIntervalReminders: $e');
      }
    }
  }

  Future<void> _scheduleCustomReminders(
      Challenge challenge, String timesData) async {
    // Same as multiple reminders
    await _scheduleMultipleReminders(challenge, timesData);
  }

  Future<void> cancelTaskReminder(String challengeId) async {
    // Cancel multiple possible notification IDs for this challenge
    final baseId = challengeId.hashCode;

    // Cancel up to 50 possible notifications (covers hourly, interval, and multiple reminders)
    for (int i = 0; i < 50; i++) {
      await _notifications.cancel(baseId + i);
      _scheduledNotificationCount =
          (_scheduledNotificationCount - 1).clamp(0, _maxNotifications);
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    _scheduledNotificationCount = 0;
  }

  bool _canScheduleMoreNotifications() {
    return _scheduledNotificationCount < _maxNotifications;
  }

  Future<void> showFailureNotification(
      int daysFailed, List<String> failedTasks) async {
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
          channelDescription:
              'Notification for completing the 75 Hard Challenge',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
    );
  }

  tz.TZDateTime _nextInstanceOf8AM() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = DateTime.now();

    // Create target time in device local time
    var targetTime = DateTime(now.year, now.month, now.day, hour, minute);

    // If time is in the past, add one day
    if (targetTime.isBefore(now)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }

    // Convert to TZDateTime using the device's timezone offset
    final offset = now.timeZoneOffset;
    final utcTime = targetTime.subtract(offset);
    final scheduledDate = tz.TZDateTime.from(utcTime, tz.UTC).add(offset);

    return scheduledDate;
  }

  // Quick test - schedule notification 2 minutes from now
  Future<void> scheduleQuickTest() async {
    final now = DateTime.now();
    final testTime = now.add(const Duration(minutes: 2));
    final tzTestTime = tz.TZDateTime.from(testTime, tz.local);

    try {
      await _notifications.zonedSchedule(
        995,
        'Quick Test - 2 Minutes',
        'This notification was scheduled 2 minutes ago at ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
        tzTestTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Test Channel',
            importance: Importance.max,
            priority: Priority.max,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) print('Notification error in scheduleQuickTest: $e');
    }
  }

  // Simple working method following exact guide pattern
  Future<void> scheduleWorkingTest(int hour, int minute) async {
    // Create target DateTime in device local time
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

    // If time is in the past, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // Convert to TZDateTime using the exact guide pattern
    final tz.TZDateTime tzScheduleTime =
        tz.TZDateTime.from(scheduledTime, tz.local);

    try {
      await _notifications.zonedSchedule(
        994,
        'Working Test',
        'Scheduled for $hour:${minute.toString().padLeft(2, '0')} - Device time was $now',
        tzScheduleTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'main_channel',
            'Main Channel',
            channelDescription: 'Main notification channel',
            importance: Importance.max,
            priority: Priority.max,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) print('Notification error in scheduleWorkingTest: $e');
    }
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
