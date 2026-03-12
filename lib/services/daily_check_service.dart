import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/challenge_session.dart';
import '../models/daily_progress.dart';
import '../repositories/database_repository.dart';

class DailyCheckService {
  static final DailyCheckService _instance = DailyCheckService._internal();
  factory DailyCheckService() => _instance;
  DailyCheckService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final DatabaseRepository _repository = DatabaseRepository();

  Future<void> checkMissedDaysOnAppOpen() async {
    await _repository.init();
    final activeSession = _repository.getActiveSession();
    if (activeSession == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(
      activeSession.startDate.year,
      activeSession.startDate.month,
      activeSession.startDate.day,
    );

    final daysSinceStart = today.difference(startDate).inDays;

    for (int i = 0; i < daysSinceStart; i++) {
      final checkDate = startDate.add(Duration(days: i));
      
      // Grace period: Don't check yesterday if it's within 2 hours of midnight
      if (now.hour < 2 && checkDate.day == now.day - 1) {
        continue; // Skip yesterday during grace period
      }
      
      final progress = _repository.getDailyProgress(checkDate);

      if (progress == null || !progress.isCompleted) {
        final failedChallenges = activeSession.challenges
            .where((c) => progress?.challengeCompletions[c.id] != true)
            .map((c) => c.title)
            .toList();

        await _resetSession(activeSession, i + 1, failedChallenges);
        return;
      }
    }
  }

  Future<void> _resetSession(
    ChallengeSession session,
    int dayFailed,
    List<String> failedChallenges,
  ) async {
    final failedSession = session.copyWith(
      isActive: false,
      endDate: DateTime.now(),
      failureReason: 'Missed day $dayFailed',
      failedChallenges: failedChallenges,
    );
    await _repository.updateSession(failedSession);
  }

  Future<void> schedulePendingTaskNotification() async {
    await _cancelPendingTaskNotification();

    // Schedule 9 PM warning notification
    final warningTime = _nextInstanceOf9PM();
    await _notifications.zonedSchedule(
      9998,
      '⚠️ Task Check-In',
      'Don\'t forget to complete your tasks! 1 hour left before the day ends.',
      warningTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pending_tasks',
          'Pending Tasks',
          channelDescription: 'Reminder for incomplete daily tasks',
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

    // Schedule 10 PM final reminder
    final scheduledTime = _nextInstanceOf10PM();
    await _notifications.zonedSchedule(
      9999,
      '⏰ Daily Check-In',
      'Don\'t forget to complete your tasks before the day ends!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pending_tasks',
          'Pending Tasks',
          channelDescription: 'Reminder for incomplete daily tasks',
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
  }

  Future<void> _cancelPendingTaskNotification() async {
    await _notifications.cancel(9998);
    await _notifications.cancel(9999);
  }

  tz.TZDateTime _nextInstanceOf9PM() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      21,
      0,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOf10PM() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      22,
      0,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
