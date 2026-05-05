import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool get _isFirebaseReady {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseAnalyticsObserver getObserver() =>
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);

  Future<void> logSessionStart(int challengeCount) async {
    if (!_isFirebaseReady) return;
    await FirebaseAnalytics.instance.logEvent(
      name: 'challenge_started',
      parameters: {'challenge_count': challengeCount},
    );
  }

  Future<void> logChallengeSelection(List<String> challengeTitles) async {
    if (!_isFirebaseReady) return;
    await FirebaseAnalytics.instance.logEvent(
      name: 'challenges_selected',
      parameters: {
        'challenge_list': challengeTitles.join(', '),
        'total_challenges': challengeTitles.length,
      },
    );
  }

  Future<void> logSessionComplete(int daysCompleted) async {
    if (!_isFirebaseReady) return;
    await FirebaseAnalytics.instance.logEvent(
      name: 'challenge_completed',
      parameters: {'days_completed': daysCompleted},
    );
  }

  Future<void> logSessionReset(int dayFailed, String reason) async {
    if (!_isFirebaseReady) return;
    await FirebaseAnalytics.instance.logEvent(
      name: 'challenge_reset',
      parameters: {'day_failed': dayFailed, 'reason': reason},
    );
  }

  Future<void> logTaskComplete(String taskName, int currentDay) async {
    if (!_isFirebaseReady) return;
    await FirebaseAnalytics.instance.logEvent(
      name: 'task_completed',
      parameters: {'task_name': taskName, 'current_day': currentDay},
    );
  }

  Future<void> logReminderSet(String taskName, String time) async {
    if (!_isFirebaseReady) return;
    await FirebaseAnalytics.instance.logEvent(
      name: 'reminder_configured',
      parameters: {'task_name': taskName, 'time': time},
    );
  }

  Future<void> logAppOpen() async {
    if (!_isFirebaseReady) return;
    await FirebaseAnalytics.instance.logAppOpen();
  }

  Future<void> setUserId(String userId) async {
    if (!_isFirebaseReady) return;
    await FirebaseAnalytics.instance.setUserId(id: userId);
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  Future<void> logError(dynamic error, StackTrace? stack) async {
    if (!_isFirebaseReady) return;
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack);
    } catch (_) {
      // Swallow — error logging must never prevent error state emission
    }
  }

  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_isFirebaseReady) return;
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }
}
