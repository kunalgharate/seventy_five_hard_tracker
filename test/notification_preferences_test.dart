import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/core/services/notification_preferences.dart';

void main() {
  group('NotificationPreferences.categoryForType', () {
    test('review types map to reviews', () {
      for (final t in [
        'taskNeedsReview',
        'reviewApproved',
        'reviewRejected',
        'reviewReminder20h',
        'reviewExpired',
      ]) {
        expect(NotificationPreferences.categoryForType(t),
            NotificationPreferences.keyReviews);
      }
    });

    test('other known types map to their categories', () {
      expect(NotificationPreferences.categoryForType('taskAssigned'),
          NotificationPreferences.keyTasks);
      expect(NotificationPreferences.categoryForType('invitationReceived'),
          NotificationPreferences.keyInvitations);
      expect(NotificationPreferences.categoryForType('invitationAccepted'),
          NotificationPreferences.keyInvitations);
      expect(NotificationPreferences.categoryForType('invitationDeclined'),
          NotificationPreferences.keyInvitations);
      expect(NotificationPreferences.categoryForType('partnerMessage'),
          NotificationPreferences.keyMessages);
    });

    test('unknown and empty types return null (fail-open)', () {
      expect(NotificationPreferences.categoryForType('nope'), isNull);
      expect(NotificationPreferences.categoryForType(''), isNull);
    });
  });

  group('NotificationPreferences.isEnabledIn', () {
    test('absent prefs and null prefs mean enabled', () {
      expect(NotificationPreferences.isEnabledIn({}, 'taskNeedsReview'), true);
      expect(
          NotificationPreferences.isEnabledIn(null, 'taskNeedsReview'), true);
    });

    test('disabled category blocks its types only', () {
      const prefs = {'reviews': false};
      expect(
          NotificationPreferences.isEnabledIn(prefs, 'taskNeedsReview'), false);
      expect(
          NotificationPreferences.isEnabledIn(prefs, 'reviewApproved'), false);
      expect(
          NotificationPreferences.isEnabledIn(prefs, 'partnerMessage'), true);
      expect(NotificationPreferences.isEnabledIn(prefs, 'taskAssigned'), true);
    });

    test('unknown types stay enabled regardless of prefs', () {
      expect(
          NotificationPreferences.isEnabledIn(
              {'reviews': false, 'messages': false}, 'futureType'),
          true);
    });
  });
}
