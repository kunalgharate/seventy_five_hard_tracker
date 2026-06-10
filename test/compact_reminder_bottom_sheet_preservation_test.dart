// Preservation Property Tests — Compact Reminder Bottom Sheet
//
// These tests verify functional behavior that must be PRESERVED after the
// layout fix. They must PASS on the current unfixed code, establishing a
// baseline of correct behavior.
//
// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/widgets/reminder_bottom_sheet.dart';

void main() {
  // Helper to create a test Challenge
  Challenge createTestChallenge({
    bool isReminderEnabled = true,
    String? reminderTime,
  }) {
    return Challenge(
      id: 'test-challenge-1',
      title: 'Test Challenge',
      isReminderEnabled: isReminderEnabled,
      reminderTime: reminderTime,
      category: 'general',
      taskType: 'hard',
      reminderType: 'once',
    );
  }

  // Helper to pump the ReminderBottomSheet directly inside a Navigator
  // (not via showModalBottomSheet) to avoid width constraints that cause
  // the known overflow bug in the disabled state info message Row.
  Future<void> pumpReminderSheet(
    WidgetTester tester, {
    required Challenge challenge,
    required Function(Challenge) onSave,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (context) => Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  size: Size(800, 900),
                  viewPadding: EdgeInsets.zero,
                ),
                child: ReminderBottomSheet(
                  challenge: challenge,
                  onSave: onSave,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Preservation Property — Save Data Format', () {
    // **Validates: Requirements 3.3**

    testWidgets('once + time 09:00 → "once:09:00"',
        (WidgetTester tester) async {
      Challenge? savedChallenge;

      await pumpReminderSheet(
        tester,
        challenge: createTestChallenge(
          isReminderEnabled: true,
          reminderTime: 'once:09:00',
        ),
        onSave: (c) => savedChallenge = c,
      );

      // Tap save button
      await tester.tap(find.text('Save Reminder Settings'));
      await tester.pumpAndSettle();

      expect(savedChallenge, isNotNull);
      expect(savedChallenge!.isReminderEnabled, isTrue);
      expect(savedChallenge!.reminderTime, equals('once:09:00'));
    });

    testWidgets('multiple + times [09:00, 18:00] → "multiple:09:00,18:00"',
        (WidgetTester tester) async {
      Challenge? savedChallenge;

      await pumpReminderSheet(
        tester,
        challenge: createTestChallenge(
          isReminderEnabled: true,
          reminderTime: 'multiple:09:00,18:00',
        ),
        onSave: (c) => savedChallenge = c,
      );

      // Tap save button
      await tester.tap(find.text('Save Reminder Settings'));
      await tester.pumpAndSettle();

      expect(savedChallenge, isNotNull);
      expect(savedChallenge!.isReminderEnabled, isTrue);
      expect(savedChallenge!.reminderTime, equals('multiple:09:00,18:00'));
    });

    testWidgets('hourly + time 08:00 → "hourly:08:00"',
        (WidgetTester tester) async {
      Challenge? savedChallenge;

      await pumpReminderSheet(
        tester,
        challenge: createTestChallenge(
          isReminderEnabled: true,
          reminderTime: 'hourly:08:00',
        ),
        onSave: (c) => savedChallenge = c,
      );

      // Tap save button
      await tester.tap(find.text('Save Reminder Settings'));
      await tester.pumpAndSettle();

      expect(savedChallenge, isNotNull);
      expect(savedChallenge!.isReminderEnabled, isTrue);
      expect(savedChallenge!.reminderTime, equals('hourly:08:00'));
    });

    testWidgets('interval + 120 min + time 07:00 → "interval:120:07:00"',
        (WidgetTester tester) async {
      Challenge? savedChallenge;

      await pumpReminderSheet(
        tester,
        challenge: createTestChallenge(
          isReminderEnabled: true,
          reminderTime: 'interval:120:07:00',
        ),
        onSave: (c) => savedChallenge = c,
      );

      // Tap save button
      await tester.tap(find.text('Save Reminder Settings'));
      await tester.pumpAndSettle();

      expect(savedChallenge, isNotNull);
      expect(savedChallenge!.isReminderEnabled, isTrue);
      expect(savedChallenge!.reminderTime, equals('interval:120:07:00'));
    });

    testWidgets(
        'custom + times [06:00, 12:00, 20:00] → "custom:06:00,12:00,20:00"',
        (WidgetTester tester) async {
      Challenge? savedChallenge;

      await pumpReminderSheet(
        tester,
        challenge: createTestChallenge(
          isReminderEnabled: true,
          reminderTime: 'custom:06:00,12:00,20:00',
        ),
        onSave: (c) => savedChallenge = c,
      );

      // Tap save button
      await tester.tap(find.text('Save Reminder Settings'));
      await tester.pumpAndSettle();

      expect(savedChallenge, isNotNull);
      expect(savedChallenge!.isReminderEnabled, isTrue);
      expect(savedChallenge!.reminderTime, equals('custom:06:00,12:00,20:00'));
    });
  });

  group('Preservation Property — Disabled State', () {
    // **Validates: Requirements 3.3, 3.5**

    testWidgets(
        'when disabled, saving produces isReminderEnabled: false and reminderTime: null',
        (WidgetTester tester) async {
      Challenge? savedChallenge;

      await pumpReminderSheet(
        tester,
        challenge: createTestChallenge(
          isReminderEnabled: false,
          reminderTime: null,
        ),
        onSave: (c) => savedChallenge = c,
      );

      // When disabled, button text is 'Disable Reminder'
      await tester.tap(find.text('Disable Reminder'));
      await tester.pumpAndSettle();

      expect(savedChallenge, isNotNull);
      expect(savedChallenge!.isReminderEnabled, isFalse);
      expect(savedChallenge!.reminderTime, isNull);
    });

    testWidgets(
        'disabled state shows info message "Enable reminders to configure settings"',
        (WidgetTester tester) async {
      await pumpReminderSheet(
        tester,
        challenge: createTestChallenge(
          isReminderEnabled: false,
          reminderTime: null,
        ),
        onSave: (_) {},
      );

      // **Validates: Requirements 3.5**
      expect(
        find.text('Enable reminders to configure settings'),
        findsOneWidget,
      );
    });
  });

  group('Preservation Property — Toggle Behavior', () {
    // **Validates: Requirements 3.2**

    testWidgets('toggle shows/hides configuration options',
        (WidgetTester tester) async {
      await pumpReminderSheet(
        tester,
        challenge: createTestChallenge(
          isReminderEnabled: true,
          reminderTime: 'once:09:00',
        ),
        onSave: (_) {},
      );

      // When enabled, should show 'Reminder Type' section
      expect(find.text('Reminder Type'), findsOneWidget);
      expect(find.text('Once'), findsOneWidget);

      // Toggle off
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // When disabled, should hide type options and show info message
      expect(find.text('Reminder Type'), findsNothing);
      expect(
          find.text('Enable reminders to configure settings'), findsOneWidget);

      // Toggle back on
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Should show configuration again
      expect(find.text('Reminder Type'), findsOneWidget);
      expect(find.text('Once'), findsOneWidget);
    });
  });

  group('Preservation Property — Type Selection', () {
    // **Validates: Requirements 3.1**

    testWidgets('type selection updates UI', (WidgetTester tester) async {
      await pumpReminderSheet(
        tester,
        challenge: createTestChallenge(
          isReminderEnabled: true,
          reminderTime: 'once:09:00',
        ),
        onSave: (_) {},
      );

      // Initially 'once' is selected — should show time selector with 'Reminder Time'
      expect(find.text('Reminder Time'), findsOneWidget);

      // Tap 'Multiple Times' option
      await tester.tap(find.text('Multiple Times'));
      await tester.pumpAndSettle();

      // Should show 'Reminder Times' (plural) for multiple type
      expect(find.text('Reminder Times'), findsOneWidget);

      // Tap 'Every Hour' option — scroll if needed
      final scrollable = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text('Every Hour'),
        50.0,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Every Hour'));
      await tester.pumpAndSettle();

      // Should show 'Start Time' for hourly type
      await tester.scrollUntilVisible(
        find.text('Start Time'),
        50.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Start Time'), findsOneWidget);

      // Tap 'Custom Schedule' option — scroll to find it
      await tester.scrollUntilVisible(
        find.text('Custom Schedule'),
        -50.0,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Custom Schedule'));
      await tester.pumpAndSettle();

      // Should show 'Custom Times' for custom type
      await tester.scrollUntilVisible(
        find.text('Custom Times'),
        50.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Custom Times'), findsOneWidget);

      // Tap 'Every X Hours' option — scroll to find it
      await tester.scrollUntilVisible(
        find.text('Every X Hours'),
        -50.0,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Every X Hours'));
      await tester.pumpAndSettle();

      // Should show 'Interval' label for interval type
      await tester.scrollUntilVisible(
        find.text('Interval'),
        50.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Interval'), findsOneWidget);
    });
  });
}
