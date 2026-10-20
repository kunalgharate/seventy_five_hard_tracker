import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:seventy_five_hard_tracker/core/services/premium_entitlement_service.dart';

/// A small seam used by unit tests and by future analytics providers.
///
/// The production implementation always writes through Firebase Analytics.
/// Keeping the event boundary typed makes it possible to verify the payload
/// without initializing a Firebase platform in a unit test.
typedef AnalyticsEventSink = Future<void> Function(
  String name,
  Map<String, Object> parameters,
);

/// App analytics facade.
///
/// Event payloads are intentionally built from aggregates and allow-listed
/// categories. User-entered strings are never sent to Analytics. In
/// particular, challenge titles, task names, journal text, notes, and freeform
/// reasons are excluded even when older call sites still pass them to the
/// compatibility methods below.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();

  factory AnalyticsService() => _instance;

  AnalyticsService._internal() : _eventSink = null;

  /// Creates an instance that delivers sanitized events to [sink].
  ///
  /// This is useful for focused tests and keeps the production singleton API
  /// unchanged. The sink receives the same payload shape that would be sent to
  /// Firebase Analytics.
  AnalyticsService.forTesting(AnalyticsEventSink sink) : _eventSink = sink;

  final AnalyticsEventSink? _eventSink;

  static const Map<String, Set<String>> _safeCategoricalValues = {
    'channel': {'code', 'email'},
    'day_bucket': {
      'd0',
      'd1',
      'd2_3',
      'd4_7',
      'd8_14',
      'd15_30',
      'd31_plus',
    },
    'entry_point': {'first_run', 'home', 'settings', 'unknown'},
    'feature': {
      'unlimited_challenges',
      'advanced_insights',
      'custom_themes',
      'unknown',
    },
    'reminder_period': {'night', 'morning', 'afternoon', 'evening', 'unknown'},
    'reset_type': {'hard', 'soft', 'unknown'},
    'source': {'iap', 'revenuecat', 'web', 'unknown'},
    'status': {'active', 'inactive', 'accepted', 'declined', 'unknown'},
  };

  static const Set<String> _sensitiveKeyFragments = {
    'challenge_title',
    'challenge_list',
    'challenge_name',
    'content',
    'description',
    'display_name',
    'email',
    'journal',
    'name',
    'note',
    'reason',
    'task_name',
    'task_title',
    'text',
    'title',
    'user_content',
  };

  static final RegExp _safeParameterName =
      RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');
  static final RegExp _safeProductId =
      RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$');

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

  /// Removes unsupported, arbitrary, and content-bearing values from an event.
  ///
  /// Firebase Analytics accepts only scalar values, but scalar strings can
  /// still contain sensitive user content. Only known categorical keys are
  /// allowed through; numeric aggregates are retained. This method is public
  /// so the privacy contract can be tested without a Firebase runtime.
  static Map<String, Object> sanitizeParameters(
    Map<String, Object?> parameters,
  ) {
    final sanitized = <String, Object>{};

    for (final entry in parameters.entries) {
      final key = entry.key.trim().toLowerCase();
      if (!_safeParameterName.hasMatch(key) || _isSensitiveKey(key)) {
        continue;
      }

      final value = entry.value;
      if (value is int) {
        sanitized[key] = value;
      } else if (value is double && value.isFinite) {
        sanitized[key] = value;
      } else if (value is String &&
          (_safeCategoricalValues.containsKey(key) ||
              key == 'currency' ||
              key == 'product_id')) {
        final normalized = value.trim().toLowerCase();
        if (normalized.isEmpty || normalized.length > 100) continue;
        if (key == 'currency') {
          if (RegExp(r'^[a-z]{3}$').hasMatch(normalized)) {
            sanitized[key] = normalized;
          }
        } else if (key == 'product_id' && _safeProductId.hasMatch(normalized)) {
          sanitized[key] = normalized;
        } else if (_safeCategoricalValues[key]?.contains(normalized) ?? false) {
          sanitized[key] = normalized;
        }
      }
    }

    return sanitized;
  }

  static bool _isSensitiveKey(String key) {
    for (final fragment in _sensitiveKeyFragments) {
      if (key == fragment || key.contains(fragment)) return true;
    }
    return false;
  }

  Future<void> _logEvent(
    String name,
    Map<String, Object?> parameters,
  ) async {
    final safeParameters = sanitizeParameters(parameters);
    final sink = _eventSink;
    if (sink != null) {
      try {
        await sink(name, safeParameters);
      } catch (_) {
        // Analytics must never affect the user-facing flow.
      }
      return;
    }

    if (!_isFirebaseReady) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: safeParameters.isEmpty ? null : safeParameters,
      );
    } catch (_) {
      // Analytics is best-effort, including when the device is offline.
    }
  }

  Future<void> _logAppOpen(Map<String, Object?> parameters) async {
    final safeParameters = sanitizeParameters(parameters);
    final sink = _eventSink;
    if (sink != null) {
      try {
        await sink('app_open', safeParameters);
      } catch (_) {
        // Analytics must never affect the user-facing flow.
      }
      return;
    }

    if (!_isFirebaseReady) return;
    try {
      await FirebaseAnalytics.instance.logAppOpen(
        parameters: safeParameters.isEmpty ? null : safeParameters,
      );
    } catch (_) {
      // Analytics is best-effort, including when the device is offline.
    }
  }

  static int _boundedCount(int value) {
    if (value < 0) return 0;
    if (value > 100000) return 100000;
    return value;
  }

  static String _category(
    String? value,
    Set<String> allowed, {
    String fallback = 'unknown',
  }) {
    final normalized = value?.trim().toLowerCase();
    return normalized != null && allowed.contains(normalized)
        ? normalized
        : fallback;
  }

  static String _reminderPeriod(String value) {
    final match = RegExp(r'^(\d{1,2})(?::\d{2})?').firstMatch(value.trim());
    final hour = int.tryParse(match?.group(1) ?? '');
    if (hour == null || hour < 0 || hour > 23) return 'unknown';
    if (hour < 6) return 'night';
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    if (hour < 22) return 'evening';
    return 'night';
  }

  static String _safeProduct(String? productId) {
    final normalized = productId?.trim().toLowerCase();
    if (normalized != null && _safeProductId.hasMatch(normalized)) {
      return normalized;
    }
    return 'unknown';
  }

  /// Returns stable retention cohorts without sending an install date.
  static String retentionDayBucket(int daysSinceInstall) {
    final days = daysSinceInstall < 0 ? 0 : daysSinceInstall;
    if (days == 0) return 'd0';
    if (days == 1) return 'd1';
    if (days <= 3) return 'd2_3';
    if (days <= 7) return 'd4_7';
    if (days <= 14) return 'd8_14';
    if (days <= 30) return 'd15_30';
    return 'd31_plus';
  }

  /// Existing challenge-start event retained for compatibility.
  Future<void> logSessionStart(int challengeCount) async {
    await _logEvent(
      'challenge_started',
      {'challenge_count': _boundedCount(challengeCount)},
    );
  }

  /// Existing selection event retained for compatibility.
  ///
  /// [challengeTitles] is used only to derive a count. The titles themselves
  /// are deliberately never included in the payload.
  Future<void> logChallengeSelection(List<String> challengeTitles) async {
    await _logEvent(
      'challenges_selected',
      {'total_challenges': _boundedCount(challengeTitles.length)},
    );
  }

  Future<void> logSessionComplete(int daysCompleted) async {
    await _logEvent(
      'challenge_completed',
      {'days_completed': _boundedCount(daysCompleted)},
    );
  }

  /// [reason] is accepted for source compatibility but is never transmitted.
  Future<void> logSessionReset(int dayFailed, String reason) async {
    await _logEvent(
      'challenge_reset',
      {'day_failed': _boundedCount(dayFailed)},
    );
  }

  /// [taskName] is accepted for source compatibility but is never transmitted.
  Future<void> logTaskComplete(String taskName, int currentDay) async {
    await _logEvent(
      'task_completed',
      {'current_day': _boundedCount(currentDay)},
    );
  }

  /// Records only a broad time-of-day bucket, never a task name or raw time.
  Future<void> logReminderSet(String taskName, String time) async {
    await _logEvent(
      'reminder_configured',
      {'reminder_period': _reminderPeriod(time)},
    );
  }

  /// Logs Firebase's standard app-open event with an optional retention bucket.
  ///
  /// Callers can provide either [daysSinceInstall] or [firstSeenAt]. Dates are
  /// converted locally to a bucket and are never sent as event parameters.
  Future<void> logAppOpen({
    int? daysSinceInstall,
    DateTime? firstSeenAt,
    DateTime? now,
  }) async {
    int? retentionDays = daysSinceInstall;
    if (retentionDays == null && firstSeenAt != null) {
      final current = now ?? DateTime.now();
      retentionDays = current.toUtc().difference(firstSeenAt.toUtc()).inDays;
    }

    await _logAppOpen({
      if (retentionDays != null)
        'day_bucket': retentionDayBucket(retentionDays),
    });
  }

  Future<void> logRetentionAppOpen(int daysSinceInstall) =>
      logAppOpen(daysSinceInstall: daysSinceInstall);

  Future<void> logOnboardingStarted({String? entryPoint}) async {
    await _logEvent(
      'onboarding_started',
      {
        'entry_point': _category(
          entryPoint,
          {'first_run', 'home', 'settings'},
        ),
      },
    );
  }

  Future<void> logOnboardingCompleted({
    int? challengeCount,
    String? setupMode,
  }) async {
    await _logEvent(
      'onboarding_completed',
      {
        if (challengeCount != null)
          'challenge_count': _boundedCount(challengeCount),
        if (setupMode != null)
          'reset_type': _category(setupMode, {'hard', 'soft'}),
      },
    );
  }

  Future<void> logPartnerInvitationSent({String? channel}) async {
    await _logEvent(
      'partner_invitation_sent',
      {
        'channel': _category(channel, {'code', 'email'}),
      },
    );
  }

  Future<void> logPartnerInvitationAccepted({String? channel}) async {
    await _logEvent(
      'partner_invitation_accepted',
      {
        'channel': _category(channel, {'code', 'email'}),
      },
    );
  }

  Map<String, Object?> _premiumParameters({
    PremiumFeature? feature,
    String? productId,
    String? source,
  }) {
    return {
      'feature': feature?.analyticsKey ?? 'unknown',
      'product_id': _safeProduct(productId),
      'source': _category(source, {'iap', 'revenuecat', 'web', 'unknown'}),
    };
  }

  Future<void> logPremiumPaywallViewed({
    PremiumFeature? feature,
    String? productId,
    String? source,
  }) async {
    await _logEvent(
      'premium_paywall_viewed',
      _premiumParameters(
        feature: feature,
        productId: productId,
        source: source,
      ),
    );
  }

  Future<void> logPremiumPaywall({
    PremiumFeature? feature,
    String? productId,
    String? source,
  }) =>
      logPremiumPaywallViewed(
        feature: feature,
        productId: productId,
        source: source,
      );

  /// Records a completed premium purchase. Product identifiers are treated as
  /// catalog identifiers and are accepted only when they contain safe ID
  /// characters; no receipt or account data is sent.
  Future<void> logPremiumPurchase({
    PremiumFeature? feature,
    String? productId,
    String? source,
  }) async {
    await _logEvent(
      'premium_purchase',
      _premiumParameters(
        feature: feature,
        productId: productId,
        source: source,
      ),
    );
  }

  Future<void> logPremiumPurchaseStarted({
    PremiumFeature? feature,
    String? productId,
    String? source,
  }) async {
    await _logEvent(
      'premium_purchase_started',
      _premiumParameters(
        feature: feature,
        productId: productId,
        source: source,
      ),
    );
  }

  Future<void> logPremiumPurchaseCompleted({
    PremiumFeature? feature,
    String? productId,
    String? source,
  }) =>
      logPremiumPurchase(
        feature: feature,
        productId: productId,
        source: source,
      );

  Future<void> logPremiumRestore({
    PremiumFeature? feature,
    String? productId,
    String? source,
  }) async {
    await _logEvent(
      'premium_restore',
      _premiumParameters(
        feature: feature,
        productId: productId,
        source: source,
      ),
    );
  }

  Future<void> logPremiumRestoreStarted({
    PremiumFeature? feature,
    String? productId,
    String? source,
  }) =>
      logPremiumRestore(
        feature: feature,
        productId: productId,
        source: source,
      );

  Future<void> logPremiumPurchaseRestored({
    PremiumFeature? feature,
    String? productId,
    String? source,
  }) =>
      logPremiumRestore(
        feature: feature,
        productId: productId,
        source: source,
      );

  Future<void> logPremiumRestoreCompleted({
    PremiumFeature? feature,
    String? productId,
    String? source,
  }) =>
      logPremiumRestore(
        feature: feature,
        productId: productId,
        source: source,
      );

  Future<void> setUserId(String userId) async {
    if (!_isFirebaseReady) return;
    try {
      await FirebaseAnalytics.instance.setUserId(id: userId);
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (_) {
      // Identity setup is best-effort and must not block the app.
    }
  }

  Future<void> logError(dynamic error, StackTrace? stack) async {
    if (!_isFirebaseReady) return;
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack);
    } catch (_) {
      // Swallow — error logging must never prevent error state emission.
    }
  }

  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_isFirebaseReady || _isSensitiveKey(key.trim().toLowerCase())) return;
    final safeValue = sanitizeParameters({'status': value})['status'];
    if (safeValue == null) return;
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, safeValue);
    } catch (_) {
      // Crash diagnostics are best-effort.
    }
  }
}
