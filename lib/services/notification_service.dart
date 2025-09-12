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
    print('🔔 DEBUG: Device timezone offset: $offset');
    print('🔔 DEBUG: Device timezone name: ${now.timeZoneName}');
    
    // Set timezone based on device offset
    try {
      // Try common timezone names first
      if (offset.inHours == 5 && offset.inMinutes == 330) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        print('🔔 DEBUG: Set timezone to Asia/Kolkata');
      } else {
        // Fallback to UTC and handle offset manually
        tz.setLocalLocation(tz.getLocation('UTC'));
        print('🔔 DEBUG: Using UTC with manual offset handling');
      }
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
      print('🔔 DEBUG: Fallback to UTC: $e');
    }
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    await _requestPermissions();
  }
  
  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 DEBUG: Notification tapped: ${response.payload}');
    // Handle notification tap here
  }

  Future<void> _requestPermissions() async {
    print('🔔 DEBUG: Requesting notification permissions');
    
    // Use flutter_local_notifications API for permission requests
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      // Request notification permission (Android 13+)
      final notificationPermission = await androidImplementation.requestNotificationsPermission();
      print('🔔 DEBUG: Notification permission: $notificationPermission');
      
      // Request exact alarm permission
      final exactAlarmPermission = await androidImplementation.requestExactAlarmsPermission();
      print('🔔 DEBUG: Exact alarm permission: $exactAlarmPermission');
    }
  }

  // Test method to send immediate notification
  Future<void> sendTestNotification() async {
    print('🔔 DEBUG: Sending test notification');
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
            sound: RawResourceAndroidNotificationSound('notification_sound'),
          ),
        ),
      );
      print('🔔 DEBUG: Test notification sent successfully');
    } catch (e) {
      print('🔔 ERROR: Failed to send test notification: $e');
    }
  }

  // Test method to schedule notification in 10 seconds
  Future<void> scheduleTestNotification() async {
    print('🔔 DEBUG: Scheduling test notification for 10 seconds from now');
    try {
      final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
      print('🔔 DEBUG: Test notification scheduled for: $scheduledTime');
      
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
            sound: RawResourceAndroidNotificationSound('notification_sound'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print('🔔 DEBUG: Test notification scheduled successfully');
    } catch (e) {
      print('🔔 ERROR: Failed to schedule test notification: $e');
    }
  }
  
  // Simple test following the guide pattern
  Future<void> scheduleSimpleTest() async {
    print('🔔 DEBUG: Scheduling simple test notification');
    final DateTime scheduledTime = DateTime.now().add(const Duration(seconds: 30));
    final tz.TZDateTime tzScheduleTime = tz.TZDateTime.from(scheduledTime, tz.local);
    
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
            sound: RawResourceAndroidNotificationSound('notification_sound'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print('🔔 DEBUG: Simple test notification scheduled successfully');
    } catch (e) {
      print('🔔 ERROR: Failed to schedule simple test: $e');
    }
  }

  Future<void> scheduleDailyMotivation() async {
    try {
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
            sound: RawResourceAndroidNotificationSound('notification_sound'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('🔔 DEBUG: Daily motivation scheduled successfully');
    } catch (e) {
      print('🔔 ERROR: Failed to schedule daily motivation: $e');
    }
  }

  Future<void> scheduleTaskReminder(Challenge challenge, String time) async {
    print('🔔 DEBUG: scheduleTaskReminder called');
    print('🔔 DEBUG: Challenge: ${challenge.title}');
    print('🔔 DEBUG: isReminderEnabled: ${challenge.isReminderEnabled}');
    print('🔔 DEBUG: reminderTime: ${challenge.reminderTime}');
    print('🔔 DEBUG: time parameter: $time');
    
    if (!challenge.isReminderEnabled || challenge.reminderTime == null) {
      print('🔔 DEBUG: Reminder not enabled or time is null - returning');
      return;
    }

    // Cancel any existing reminders for this challenge
    await cancelTaskReminder(challenge.id);
    print('🔔 DEBUG: Cancelled existing reminders for ${challenge.id}');

    // Parse reminder data to determine type and schedule accordingly
    final reminderData = challenge.reminderTime!;
    print('🔔 DEBUG: Processing reminderData: $reminderData');
    
    if (reminderData.startsWith('once:')) {
      print('🔔 DEBUG: Scheduling ONCE reminder');
      await _scheduleOnceReminder(challenge, reminderData.substring(5));
    } else if (reminderData.startsWith('multiple:')) {
      print('🔔 DEBUG: Scheduling MULTIPLE reminders');
      await _scheduleMultipleReminders(challenge, reminderData.substring(9));
    } else if (reminderData.startsWith('hourly:')) {
      print('🔔 DEBUG: Scheduling HOURLY reminders');
      await _scheduleHourlyReminders(challenge, reminderData.substring(7));
    } else if (reminderData.startsWith('interval:')) {
      print('🔔 DEBUG: Scheduling INTERVAL reminders');
      await _scheduleIntervalReminders(challenge, reminderData.substring(9));
    } else if (reminderData.startsWith('custom:')) {
      print('🔔 DEBUG: Scheduling CUSTOM reminders');
      await _scheduleCustomReminders(challenge, reminderData.substring(7));
    } else {
      // Handle both simple time format (18:03) and fallback
      print('🔔 DEBUG: Using FALLBACK - scheduling simple daily reminder');
      print('🔔 DEBUG: Fallback time: $reminderData');
      await _scheduleOnceReminder(challenge, reminderData);
    }
    
    print('🔔 DEBUG: scheduleTaskReminder completed');
  }

  Future<void> _scheduleOnceReminder(Challenge challenge, String time) async {
    print('🔔 DEBUG: _scheduleOnceReminder called with time: $time');
    
    try {
      final timeParts = time.split(':');
      print('🔔 DEBUG: Time parts: $timeParts');
      
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      print('🔔 DEBUG: Parsed hour: $hour, minute: $minute');

      final scheduledTime = _nextInstanceOfTime(hour, minute);
      print('🔔 DEBUG: Scheduled time: $scheduledTime');
      print('🔔 DEBUG: Current time: ${tz.TZDateTime.now(tz.local)}');
      
      final notificationId = challenge.id.hashCode;
      print('🔔 DEBUG: Notification ID: $notificationId');

      if (_canScheduleMoreNotifications()) {
        await _notifications.zonedSchedule(
          notificationId,
          '75 Hard Reminder',
          'Time for: ${challenge.title}',
          scheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_reminders',
              'Task Reminders',
              channelDescription: 'Reminders for individual challenge tasks',
              importance: Importance.high,
              priority: Priority.high,
              sound: RawResourceAndroidNotificationSound('notification_sound'),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        _scheduledNotificationCount++;
      } else {
        print('🔔 WARNING: Notification limit reached, skipping notification');
      }
      
      print('🔔 DEBUG: Notification scheduled successfully');
    } catch (e) {
      print('🔔 ERROR: Failed to schedule notification: $e');
    }
  }

  Future<void> _scheduleMultipleReminders(Challenge challenge, String timesData) async {
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
              sound: RawResourceAndroidNotificationSound('notification_sound'),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        _scheduledNotificationCount++;
      } else {
        print('🔔 WARNING: Notification limit reached, skipping notification');
        break;
      }
    }
  }

  Future<void> _scheduleHourlyReminders(Challenge challenge, String startTime) async {
    print('🔔 DEBUG: _scheduleHourlyReminders called with: $startTime');
    
    final timeParts = startTime.split(':');
    final startHour = int.parse(timeParts[0]);
    final startMinute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
    
    print('🔔 DEBUG: Starting hourly reminders from $startHour:${startMinute.toString().padLeft(2, '0')}');
    
    // Schedule hourly reminders from start time until 11 PM (23:00)
    for (int hour = startHour; hour <= 23; hour++) {
      print('🔔 DEBUG: Scheduling hourly reminder for $hour:${startMinute.toString().padLeft(2, '0')}');
      
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
              sound: RawResourceAndroidNotificationSound('notification_sound'),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        _scheduledNotificationCount++;
        print('🔔 DEBUG: Scheduled hourly reminder for $hour:${startMinute.toString().padLeft(2, '0')} successfully');
      } else {
        print('🔔 WARNING: Notification limit reached, skipping hourly notification');
        break;
      }
    }
    
    print('🔔 DEBUG: Finished scheduling hourly reminders');
  }

  Future<void> _scheduleIntervalReminders(Challenge challenge, String intervalData) async {
    print('🔔 DEBUG: _scheduleIntervalReminders called with: $intervalData');
    
    try {
      // Parse interval data - expecting format like "15:09:00" (15 min interval starting at 09:00)
      final parts = intervalData.split(':');
      print('🔔 DEBUG: Interval parts: $parts');
      
      if (parts.length < 3) {
        print('🔔 ERROR: Invalid interval format. Expected format: "15:09:00"');
        return;
      }
      
      final intervalMinutes = int.parse(parts[0]);
      final startHour = int.parse(parts[1]);
      final startMinute = int.parse(parts[2]);
      
      print('🔔 DEBUG: Interval: $intervalMinutes minutes, Start: $startHour:$startMinute');
      
      // Calculate how many reminders fit in the day (from start time to 10 PM)
      final startTimeInMinutes = startHour * 60 + startMinute;
      final endTimeInMinutes = 22 * 60; // 10 PM
      final totalMinutes = endTimeInMinutes - startTimeInMinutes;
      final numberOfReminders = (totalMinutes / intervalMinutes).floor() + 1;
      
      print('🔔 DEBUG: Will schedule $numberOfReminders reminders');
      
      for (int i = 0; i < numberOfReminders; i++) {
        final reminderTimeInMinutes = startTimeInMinutes + (i * intervalMinutes);
        if (reminderTimeInMinutes > endTimeInMinutes) break;
        
        final hour = (reminderTimeInMinutes / 60).floor();
        final minute = reminderTimeInMinutes % 60;
        
        print('🔔 DEBUG: Scheduling reminder $i at $hour:${minute.toString().padLeft(2, '0')}');
        
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
                sound: RawResourceAndroidNotificationSound('notification_sound'),
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
          );
          _scheduledNotificationCount++;
          print('🔔 DEBUG: Scheduled reminder $i successfully');
        } else {
          print('🔔 WARNING: Notification limit reached, skipping interval notification');
          break;
        }
      }
    } catch (e) {
      print('🔔 ERROR: Failed to parse interval data: $e');
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
      _scheduledNotificationCount = (_scheduledNotificationCount - 1).clamp(0, _maxNotifications);
    }
  }

  Future<void> cancelAllNotifications() async {
    print('🔔 DEBUG: Cancelling all notifications');
    await _notifications.cancelAll();
    _scheduledNotificationCount = 0;
    print('🔔 DEBUG: All notifications cancelled');
  }
  
  bool _canScheduleMoreNotifications() {
    return _scheduledNotificationCount < _maxNotifications;
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
          sound: RawResourceAndroidNotificationSound('notification_sound'),
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
          sound: RawResourceAndroidNotificationSound('notification_sound'),
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
    final now = DateTime.now();
    print('🔔 DEBUG: _nextInstanceOfTime - Device local time: $now');
    print('🔔 DEBUG: _nextInstanceOfTime - Target hour: $hour, minute: $minute');
    
    // Create target time in device local time
    var targetTime = DateTime(now.year, now.month, now.day, hour, minute);
    print('🔔 DEBUG: _nextInstanceOfTime - Target device time: $targetTime');
    
    // If time is in the past, add one day
    if (targetTime.isBefore(now)) {
      targetTime = targetTime.add(const Duration(days: 1));
      print('🔔 DEBUG: _nextInstanceOfTime - Time was in past, moved to tomorrow: $targetTime');
    }
    
    // Convert to TZDateTime using the device's timezone offset
    final offset = now.timeZoneOffset;
    final utcTime = targetTime.subtract(offset);
    final scheduledDate = tz.TZDateTime.from(utcTime, tz.UTC).add(offset);
    
    print('🔔 DEBUG: _nextInstanceOfTime - Final scheduled time: $scheduledDate');
    return scheduledDate;
  }
  
  // Get pending notifications for debugging
  Future<void> debugPendingNotifications() async {
    final pendingNotifications = await _notifications.pendingNotificationRequests();
    print('🔔 DEBUG: Pending notifications count: ${pendingNotifications.length}');
    for (final notification in pendingNotifications) {
      print('🔔 DEBUG: ID: ${notification.id}, Title: ${notification.title}');
    }
  }
  
  // Quick test - schedule notification 2 minutes from now
  Future<void> scheduleQuickTest() async {
    final now = DateTime.now();
    final testTime = now.add(const Duration(minutes: 2));
    final tzTestTime = tz.TZDateTime.from(testTime, tz.local);
    
    print('🔔 DEBUG: Quick test - Current time: $now');
    print('🔔 DEBUG: Quick test - Scheduled for: $testTime');
    print('🔔 DEBUG: Quick test - TZ scheduled for: $tzTestTime');
    
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
            sound: RawResourceAndroidNotificationSound('notification_sound'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print('🔔 DEBUG: Quick test notification scheduled successfully');
    } catch (e) {
      print('🔔 ERROR: Failed to schedule quick test: $e');
    }
  }
  
  // Simple working method following exact guide pattern
  Future<void> scheduleWorkingTest(int hour, int minute) async {
    print('🔔 DEBUG: scheduleWorkingTest called for $hour:$minute');
    
    // Create target DateTime in device local time
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
    
    // If time is in the past, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    
    print('🔔 DEBUG: Device time now: $now');
    print('🔔 DEBUG: Target device time: $scheduledTime');
    
    // Convert to TZDateTime using the exact guide pattern
    final tz.TZDateTime tzScheduleTime = tz.TZDateTime.from(scheduledTime, tz.local);
    print('🔔 DEBUG: TZ scheduled time: $tzScheduleTime');
    
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
            sound: RawResourceAndroidNotificationSound('notification_sound'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print('🔔 DEBUG: Working test scheduled successfully');
    } catch (e) {
      print('🔔 ERROR: Failed to schedule working test: $e');
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
