import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  FirebaseAnalyticsObserver getObserver() =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logSessionStart(int challengeCount) async {
    await _analytics.logEvent(
      name: 'challenge_started',
      parameters: {'challenge_count': challengeCount},
    );
  }

  Future<void> logChallengeSelection(List<String> challengeTitles) async {
    await _analytics.logEvent(
      name: 'challenges_selected',
      parameters: {
        'challenge_list': challengeTitles.join(', '),
        'total_challenges': challengeTitles.length,
      },
    );
  }

  Future<void> logSessionComplete(int daysCompleted) async {
    await _analytics.logEvent(
      name: 'challenge_completed',
      parameters: {'days_completed': daysCompleted},
    );
  }

  Future<void> logSessionReset(int dayFailed, String reason) async {
    await _analytics.logEvent(
      name: 'challenge_reset',
      parameters: {'day_failed': dayFailed, 'reason': reason},
    );
  }

  Future<void> logTaskComplete(String taskName, int currentDay) async {
    await _analytics.logEvent(
      name: 'task_completed',
      parameters: {'task_name': taskName, 'current_day': currentDay},
    );
  }

  Future<void> logReminderSet(String taskName, String time) async {
    await _analytics.logEvent(
      name: 'reminder_configured',
      parameters: {'task_name': taskName, 'time': time},
    );
  }

  Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
    await _crashlytics.setUserIdentifier(userId);
  }

  Future<void> logError(dynamic error, StackTrace? stack) async {
    await _crashlytics.recordError(error, stack);
  }

  Future<void> setCustomKey(String key, dynamic value) async {
    await _crashlytics.setCustomKey(key, value);
  }
}
