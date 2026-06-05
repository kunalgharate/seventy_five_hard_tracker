import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';

/// Single, consolidated notification service for the entire app.
class SmartNotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'smart_reminders_v2';
  static const String _channelName = 'Smart Task Reminders';
  static const String _nightSummaryChannelId = 'night_summary_v2';

  /// Tracks scheduled count to stay under Samsung's 500-alarm limit.
  int _scheduledCount = 0;
  static const int _maxNotifications = 400;

  // ── Initialization ──────────────────────────────────────────────

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    // Map device UTC offset to a known timezone
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    const offsetToTz = {
      -720: 'Pacific/Kwajalein', // UTC-12
      -660: 'Pacific/Midway', // UTC-11
      -600: 'Pacific/Honolulu', // UTC-10 (HST)
      -540: 'America/Anchorage', // UTC-9 (AKST)
      -480: 'America/Los_Angeles', // UTC-8 (PST)
      -420: 'America/Denver', // UTC-7 (MST)
      -360: 'America/Chicago', // UTC-6 (CST)
      -300: 'America/New_York', // UTC-5 (EST)
      -240: 'America/Halifax', // UTC-4 (AST)
      -210: 'America/St_Johns', // UTC-3:30
      -180: 'America/Sao_Paulo', // UTC-3
      -120: 'Atlantic/South_Georgia', // UTC-2
      -60: 'Atlantic/Azores', // UTC-1
      0: 'Europe/London', // UTC+0
      60: 'Europe/Paris', // UTC+1 (CET)
      120: 'Europe/Helsinki', // UTC+2 (EET)
      180: 'Europe/Moscow', // UTC+3
      210: 'Asia/Tehran', // UTC+3:30
      240: 'Asia/Dubai', // UTC+4
      270: 'Asia/Kabul', // UTC+4:30
      300: 'Asia/Karachi', // UTC+5
      330: 'Asia/Kolkata', // UTC+5:30 (IST)
      345: 'Asia/Kathmandu', // UTC+5:45
      360: 'Asia/Dhaka', // UTC+6
      420: 'Asia/Bangkok', // UTC+7
      480: 'Asia/Shanghai', // UTC+8
      540: 'Asia/Tokyo', // UTC+9
      570: 'Australia/Darwin', // UTC+9:30
      600: 'Australia/Sydney', // UTC+10
      660: 'Pacific/Noumea', // UTC+11
      720: 'Pacific/Auckland', // UTC+12
    };
    try {
      final tzName = offsetToTz[offset] ?? 'UTC';
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _createNotificationChannels();
    // Don't request permissions here — runs before UI is ready.
    // Call requestPermissions() after the app is visible.
  }

  /// Request notification permissions. Call after the UI is ready.
  Future<void> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    const channels = [
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Smart reminders for pending tasks',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
      AndroidNotificationChannel(
        _nightSummaryChannelId,
        'Night Summary',
        description: 'Summary of pending tasks before bed',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
      AndroidNotificationChannel(
        'daily_motivation_v3',
        'Daily Motivation',
        description: 'Daily motivational messages',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'challenge_events',
        'Challenge Events',
        description: 'Reset and completion notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    ];

    for (final channel in channels) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  // ── Smart Reminders ─────────────────────────────────────────────

  Future<void> scheduleSmartReminders(
    DateTime date,
    List<Challenge> challenges,
    DailyProgress? progress,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate.isBefore(today)) return;

    for (final challenge in challenges) {
      if (!challenge.isReminderEnabled) continue;
      if (challenge.reminderTime == null) continue;

      final isCompleted = progress?.challengeCompletions[challenge.id] ?? false;
      if (isCompleted) continue;

      final data = challenge.reminderTime!;
      if (data.startsWith('once:')) {
        await _scheduleOnceReminder(challenge, date, data.substring(5));
      } else if (data.startsWith('multiple:')) {
        final times = data.substring(9).split(',');
        for (final t in times) {
          await _scheduleOnceReminder(challenge, date, t);
        }
      } else if (data.startsWith('hourly:')) {
        await _scheduleHourlyReminders(challenge, date, data.substring(7));
      } else if (data.startsWith('interval:')) {
        final parts = data.substring(9).split(':');
        final intervalMin = int.tryParse(parts[0]) ?? 120;
        final startTime =
            parts.length >= 3 ? '${parts[1]}:${parts[2]}' : '09:00';
        await _scheduleIntervalReminders(
            challenge, date, intervalMin, startTime);
      } else if (data.startsWith('custom:')) {
        final times = data.substring(7).split(',');
        for (final t in times) {
          await _scheduleOnceReminder(challenge, date, t);
        }
      } else {
        // Legacy plain "HH:mm" format
        await _scheduleOnceReminder(challenge, date, data);
      }
    }
  }

  Future<void> _scheduleOnceReminder(
      Challenge challenge, DateTime date, String time) async {
    final timeParts = time.split(':');
    if (timeParts.length < 2) return;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return;

    if (!_isWithinTimeWindow(hour, challenge)) return;

    final scheduledDate =
        tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, minute);

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;
    if (!_canScheduleMore()) return;

    await _notifications.zonedSchedule(
      _getNotificationId(challenge.id, hour, minute),
      challenge.title,
      'Time to complete your task!',
      scheduledDate,
      _taskNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    _scheduledCount++;
  }

  Future<void> _scheduleHourlyReminders(
      Challenge challenge, DateTime date, String startTime) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    if (!targetDate.isAtSameMomentAs(today)) return;

    final startParts = startTime.split(':');
    final startHour =
        int.tryParse(startParts[0]) ?? challenge.reminderStartHour;

    for (int hour = startHour; hour <= challenge.reminderEndHour; hour++) {
      if (!_isWithinTimeWindow(hour, challenge)) continue;

      final scheduledDate =
          tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, 0);
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) continue;
      if (!_canScheduleMore()) break;

      await _notifications.zonedSchedule(
        _getNotificationId(challenge.id, hour, 0),
        challenge.title,
        'Hourly reminder: Complete your task!',
        scheduledDate,
        _taskNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      _scheduledCount++;
    }
  }

  Future<void> _scheduleIntervalReminders(Challenge challenge, DateTime date,
      int intervalMinutes, String startTime) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    if (!targetDate.isAtSameMomentAs(today)) return;

    final startParts = startTime.split(':');
    final startHour =
        int.tryParse(startParts[0]) ?? challenge.reminderStartHour;
    final startMinute =
        (startParts.length >= 2) ? (int.tryParse(startParts[1]) ?? 0) : 0;

    DateTime current =
        DateTime(date.year, date.month, date.day, startHour, startMinute);
    final end = DateTime(
        date.year, date.month, date.day, challenge.reminderEndHour, 59);

    while (current.isBefore(end)) {
      if (_isWithinTimeWindow(current.hour, challenge)) {
        final scheduledDate = tz.TZDateTime.from(current, tz.local);
        if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local)) &&
            _canScheduleMore()) {
          await _notifications.zonedSchedule(
            _getNotificationId(challenge.id, current.hour, current.minute),
            challenge.title,
            'Reminder: Complete your task!',
            scheduledDate,
            _taskNotificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
          );
          _scheduledCount++;
        }
      }
      current = current.add(Duration(minutes: intervalMinutes));
    }
  }

  // ── Daily Motivation ────────────────────────────────────────────

  Future<void> scheduleDailyMotivation() async {
    try {
      final message = await _fetchMotivationalMessage();
      final scheduledDate = _nextInstanceOfTime(8, 0);

      await _notifications.zonedSchedule(
        0,
        '75 Hard Challenge',
        message,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_motivation_v3',
            'Daily Motivation',
            importance: Importance.max,
            priority: Priority.max,
            sound: RawResourceAndroidNotificationSound('notification'),
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) print('Failed to schedule daily motivation: $e');
    }
  }

  Future<String> _fetchMotivationalMessage() async {
    try {
      final response = await http
          .get(Uri.parse('https://zenquotes.io/api/random'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          return '${data[0]['q']} - ${data[0]['a']}';
        }
      }
    } catch (_) {}

    const messages = [
      "Today is another chance to become the person you want to be!",
      "Discipline is choosing between what you want now and what you want most.",
      "The only impossible journey is the one you never begin.",
      "Success is the sum of small efforts repeated day in and day out.",
      "You are stronger than you think and more capable than you imagine.",
    ];
    return messages[DateTime.now().day % messages.length];
  }

  // ── Challenge Events ────────────────────────────────────────────

  Future<void> showFailureNotification(
      int daysFailed, List<String> failedTasks) async {
    final taskList = failedTasks.join(', ');
    await _notifications.show(
      999,
      'Challenge Reset!',
      'You missed: $taskList on day $daysFailed. Starting over from Day 1!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'challenge_events',
          'Challenge Events',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
    );
  }

  Future<void> showCompletionNotification() async {
    await _notifications.show(
      1000,
      '🎉 Congratulations! 🎉',
      'You completed the 75 Hard Challenge! You are amazing!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'challenge_events',
          'Challenge Events',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
    );
  }

  // ── Night Summary ───────────────────────────────────────────────

  /// Schedule a single night summary notification at max(23:30, latestReminderTime)
  /// for pending tasks. Only schedules if there are pending tasks.
  Future<void> scheduleNightSummary(
    DateTime date,
    List<Challenge> pendingChallenges,
  ) async {
    if (pendingChallenges.isEmpty) {
      // Cancel any previously scheduled night summaries
      await cancelNightSummaries();
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    if (!targetDate.isAtSameMomentAs(today)) return;

    // Compute notification time: max(23:30, latestReminderTime)
    final latestReminder = _extractLatestReminderTime(pendingChallenges);
    const floorHour = 23;
    const floorMinute = 30;

    int notifHour;
    int notifMinute;
    if (latestReminder.hour > floorHour ||
        (latestReminder.hour == floorHour &&
            latestReminder.minute > floorMinute)) {
      notifHour = latestReminder.hour;
      notifMinute = latestReminder.minute;
    } else {
      notifHour = floorHour;
      notifMinute = floorMinute;
    }

    final scheduledDate = tz.TZDateTime(
        tz.local, date.year, date.month, date.day, notifHour, notifMinute);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    final count = pendingChallenges.length;
    final title = '⏰ $count task${count > 1 ? 's' : ''} still pending';
    final body =
        '⚠️ Missing these will reset your challenge!\n\n${pendingChallenges.map((c) => '• ${c.title}').join('\n')}';

    await _notifications.zonedSchedule(
      999950,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _nightSummaryChannelId,
          'Night Summary',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notification'),
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          sound: 'notification.wav',
          subtitle: body,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel the night summary notification
  Future<void> cancelNightSummaries() async {
    await _notifications.cancel(999950);
  }

  /// Extract the latest reminder time across all pending challenges.
  /// Parses all supported reminder time formats and returns the maximum time.
  /// Defaults to (hour: 0, minute: 0) if no valid times found.
  ({int hour, int minute}) _extractLatestReminderTime(
      List<Challenge> challenges) {
    int maxHour = 0;
    int maxMinute = 0;

    for (final challenge in challenges) {
      if (challenge.reminderTime == null || !challenge.isReminderEnabled) {
        continue;
      }

      final data = challenge.reminderTime!;
      final times = <String>[];

      if (data.startsWith('once:')) {
        times.add(data.substring(5));
      } else if (data.startsWith('hourly:')) {
        times.add(data.substring(7));
      } else if (data.startsWith('multiple:')) {
        times.addAll(data.substring(9).split(','));
      } else if (data.startsWith('interval:')) {
        // Format: interval:N:HH:mm (e.g., interval:120:09:00)
        // Take the last two colon-separated parts as HH:mm
        final parts = data.substring(9).split(':');
        if (parts.length >= 3) {
          times.add('${parts[parts.length - 2]}:${parts[parts.length - 1]}');
        }
      } else if (data.startsWith('custom:')) {
        times.addAll(data.substring(7).split(','));
      } else {
        // Legacy plain "HH:mm" format
        times.add(data);
      }

      for (final t in times) {
        final trimmed = t.trim();
        final timeParts = trimmed.split(':');
        if (timeParts.length < 2) continue;
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (hour == null || minute == null) continue;

        if (hour > maxHour || (hour == maxHour && minute > maxMinute)) {
          maxHour = hour;
          maxMinute = minute;
        }
      }
    }

    return (hour: maxHour, minute: maxMinute);
  }

  // ── Cancellation ────────────────────────────────────────────────

  Future<void> cancelCompletedTaskReminders(String challengeId) async {
    try {
      // Batch cancel calls per hour using Future.wait instead of
      // 1,440 sequential awaits. This is ~24x faster.
      for (int hour = 0; hour < 24; hour++) {
        final futures = <Future>[];
        for (int minute = 0; minute < 60; minute++) {
          futures.add(_notifications
              .cancel(_getNotificationId(challengeId, hour, minute)));
        }
        await Future.wait(futures);
      }
    } catch (_) {
      // Swallow — cancellation failure is non-critical
    }
  }

  Future<void> cancelAllRemindersForDate(DateTime date) async {
    await _notifications.cancelAll();
    _scheduledCount = 0;
  }

  // ── Debug / Test (only used in debug builds) ────────────────────

  Future<void> sendTestNotification() async {
    await _notifications.show(
      998,
      'Test Notification',
      'This is a test notification to verify the system works',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> scheduleTestNotification() async {
    final scheduledTime =
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
    await _notifications.zonedSchedule(
      997,
      'Scheduled Test',
      'This test notification was scheduled 10 seconds ago',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  bool _isWithinTimeWindow(int hour, Challenge challenge) {
    if (hour < challenge.reminderStartHour ||
        hour > challenge.reminderEndHour) {
      return false;
    }
    // Block late night (10pm+) unless user opted in
    if (hour >= 22 && !challenge.allowNightReminders) return false;
    // Block midnight-6am unless user opted in
    if (hour < 6 && !challenge.allowNightReminders) return false;
    return true;
  }

  bool _canScheduleMore() => _scheduledCount < _maxNotifications;

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  int _getNotificationId(String challengeId, int hour, int minute) {
    // Use a wider hash space to reduce collisions between challenge IDs.
    // Android notification IDs are 32-bit signed ints (max ~2.1 billion).
    // time component: hour * 60 + minute = 0..1439
    // hash component: up to ~1,490,000 unique slots
    final hash = challengeId.hashCode.abs() % 1490000;
    return hash * 1440 + (hour * 60 + minute);
  }

  NotificationDetails _taskNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Smart reminders for pending tasks',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification.wav',
      ),
    );
  }
}
