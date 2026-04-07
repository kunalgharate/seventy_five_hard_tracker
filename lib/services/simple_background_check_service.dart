import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/challenge_session.dart';
import '../models/daily_progress.dart';
import '../models/challenge.dart';
import 'smart_notification_service.dart';

/// Simple background check service using app lifecycle.
/// Checks for missed days when app is opened or resumed.
class SimpleBackgroundCheckService {
  static final SimpleBackgroundCheckService _instance =
      SimpleBackgroundCheckService._internal();
  factory SimpleBackgroundCheckService() => _instance;
  SimpleBackgroundCheckService._internal();

  final SmartNotificationService _notifications = SmartNotificationService();

  /// Check for missed days when app opens.
  /// Returns list of missed task titles if a reset is needed, null otherwise.
  Future<List<String>?> checkOnAppOpen() async {
    try {
      if (!Hive.isBoxOpen('challenge_sessions')) {
        await Hive.openBox<ChallengeSession>('challenge_sessions');
      }
      if (!Hive.isBoxOpen('daily_progress')) {
        await Hive.openBox<DailyProgress>('daily_progress');
      }

      final sessionBox = Hive.box<ChallengeSession>('challenge_sessions');
      final progressBox = Hive.box<DailyProgress>('daily_progress');

      ChallengeSession? activeSession;
      try {
        activeSession =
            sessionBox.values.firstWhere((session) => session.isActive);
      } catch (_) {
        return null; // No active session
      }

      // Only check hard mode sessions
      if (activeSession.mode != ResetMode.hard) return null;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sessionStart = DateTime(
        activeSession.startDate.year,
        activeSession.startDate.month,
        activeSession.startDate.day,
      );

      // Don't check if session started today — nothing to miss yet
      if (!today.isAfter(sessionStart)) return null;

      final yesterday = today.subtract(const Duration(days: 1));

      // Don't check if yesterday is before session start
      if (yesterday.isBefore(sessionStart)) return null;

      final key =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final yesterdayProgress = progressBox.get(key) ??
          DailyProgress(
            date: yesterday,
            challengeCompletions: {},
            isCompleted: false,
          );

      final hardChallenges =
          activeSession.challenges.where((c) => c.type == TaskType.hard).toList();

      final missedTasks = <String>[];
      for (final challenge in hardChallenges) {
        final isCompleted =
            yesterdayProgress.challengeCompletions[challenge.id] ?? false;
        if (!isCompleted) missedTasks.add(challenge.title);
      }

      if (missedTasks.isNotEmpty) {
        await _notifications.cancelAllRemindersForDate(DateTime.now());
        // Return missed tasks so the caller (BLoC) can dispatch a reset
        return missedTasks;
      }

      return null;
    } catch (e) {
      if (kDebugMode) print('Background check error: $e');
      return null;
    }
  }
}
