import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/core/services/analytics_service.dart';
import 'package:seventy_five_hard_tracker/core/services/premium_entitlement_service.dart';

void main() {
  group('AnalyticsService privacy boundary', () {
    test('removes user content while retaining safe aggregates', () async {
      final events = <String, Map<String, Object>>{};
      final analytics = AnalyticsService.forTesting((name, parameters) async {
        events[name] = parameters;
      });

      await analytics.logChallengeSelection(['Private challenge title']);
      await analytics.logTaskComplete('Private task title', 4);
      await analytics.logSessionReset(2, 'Private journal reason');
      await analytics.logReminderSet('Private task title', '23:45');

      expect(events['challenges_selected'], {
        'total_challenges': 1,
      });
      expect(events['task_completed'], {
        'current_day': 4,
      });
      expect(events['challenge_reset'], {
        'day_failed': 2,
      });
      expect(events['reminder_configured'], {
        'reminder_period': 'night',
      });

      final serialized = events.values
          .expand((event) => event.keys)
          .map((key) => key.toLowerCase())
          .toList();
      expect(serialized, isNot(contains('challenge_list')));
      expect(serialized, isNot(contains('task_name')));
      expect(serialized, isNot(contains('reason')));
    });

    test('sanitizes arbitrary parameters and keeps only safe scalar values',
        () {
      final parameters = AnalyticsService.sanitizeParameters({
        'challenge_title': 'Do not send this',
        'journal_text': 'Do not send this either',
        'total_challenges': 3,
        'entry_point': 'HOME',
        'unsupported_string': 'freeform content',
        'bad key': 1,
        'invalid_double': double.nan,
      });

      expect(parameters, {
        'total_challenges': 3,
        'entry_point': 'home',
      });
    });

    test('uses coarse retention buckets without sending dates', () async {
      final events = <String, Map<String, Object>>{};
      final analytics = AnalyticsService.forTesting((name, parameters) async {
        events[name] = parameters;
      });

      await analytics.logAppOpen(daysSinceInstall: 7);

      expect(events['app_open'], {'day_bucket': 'd4_7'});
      expect(events['app_open']!.values, isNot(contains(7)));
    });

    test('exposes onboarding and partner lifecycle event names', () async {
      final names = <String>[];
      final analytics = AnalyticsService.forTesting((name, _) async {
        names.add(name);
      });

      await analytics.logOnboardingStarted(entryPoint: 'home');
      await analytics.logOnboardingCompleted(
        challengeCount: 2,
        setupMode: 'hard',
      );
      await analytics.logPartnerInvitationSent(channel: 'email');
      await analytics.logPartnerInvitationAccepted(channel: 'email');

      expect(names, [
        'onboarding_started',
        'onboarding_completed',
        'partner_invitation_sent',
        'partner_invitation_accepted',
      ]);
    });

    test('premium events use allow-listed catalog values', () async {
      final events = <String, Map<String, Object>>{};
      final analytics = AnalyticsService.forTesting((name, parameters) async {
        events[name] = parameters;
      });

      await analytics.logPremiumPurchase(
        feature: PremiumFeature.advancedInsights,
        productId: 'premium.monthly',
        source: 'RevenueCat',
      );
      await analytics.logPremiumRestore(
        productId: 'receipt-with-user-content/unsafe',
        source: 'unknown-source',
      );

      expect(events['premium_purchase'], {
        'feature': 'advanced_insights',
        'product_id': 'premium.monthly',
        'source': 'revenuecat',
      });
      expect(events['premium_restore'], {
        'feature': 'unknown',
        'product_id': 'unknown',
        'source': 'unknown',
      });
    });
  });

  group('PremiumEntitlement parsing', () {
    final now = DateTime.utc(2026, 1, 1);

    test('accepts an active future entitlement', () {
      final entitlement = PremiumEntitlement.fromFirestore(
        {
          'isPremium': true,
          'status': 'active',
          'productId': 'premium.monthly',
          'expiresAt': Timestamp.fromDate(DateTime.utc(2026, 2, 1)),
        },
        now: now,
      );

      expect(entitlement.isPremium, isTrue);
      expect(entitlement.productId, 'premium.monthly');
      expect(entitlement.expiresAt, DateTime.utc(2026, 2, 1));
    });

    test('defaults missing, malformed, and inactive data to false', () {
      expect(
        PremiumEntitlement.fromFirestore(null, now: now).isPremium,
        isFalse,
      );
      expect(
        PremiumEntitlement.fromFirestore({'isPremium': 'not-a-bool'}, now: now)
            .isPremium,
        isFalse,
      );
      expect(
        PremiumEntitlement.fromFirestore(
          {'isPremium': true, 'status': 'revoked'},
          now: now,
        ).isPremium,
        isFalse,
      );
    });

    test('expired entitlements are not premium even with a true flag', () {
      final entitlement = PremiumEntitlement.fromMap(
        {
          'isPremium': true,
          'expiresAt': '2025-12-31T23:59:59Z',
        },
        now: now,
      );

      expect(entitlement.isPremium, isFalse);
    });

    test('malformed expiration fails closed', () {
      final entitlement = PremiumEntitlement.fromMap(
        {
          'isPremium': true,
          'expiresAt': {'unexpected': 'shape'},
        },
        now: now,
      );

      expect(entitlement.isPremium, isFalse);
    });

    test('premium feature guard is false offline and true when entitled', () {
      expect(
        PremiumEntitlementService.allows(
          PremiumFeature.customThemes,
          isPremium: false,
        ),
        isFalse,
      );
      expect(
        PremiumEntitlementService.allows(
          PremiumFeature.customThemes,
          isPremium: true,
        ),
        isTrue,
      );
    });

    test('service safely defaults to false without Firebase/auth state',
        () async {
      final service = PremiumEntitlementService();
      expect(await service.getIsPremium(), isFalse);
    });
  });
}
