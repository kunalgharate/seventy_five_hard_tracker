# Implementation Plan

- [ ] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Triple Notification at Static Times
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Scoped PBT Approach**: Scope the property to concrete failing cases — call `scheduleNightSummary` with pending challenges that have various reminder time configurations and assert the expected (correct) behavior
  - Create test file `test/night_summary_bug_condition_test.dart`
  - Read the source of `lib/services/smart_notification_service.dart` to inspect the `scheduleNightSummary` method
  - **Test Case 1 — Triple Notification**: Call `scheduleNightSummary` with 2 pending challenges (reminders at `once:09:00` and `once:17:00`). Assert the method schedules exactly 1 notification (not 3). On unfixed code, 3 notifications are scheduled at 22:00, 23:00, 23:45 — test FAILS.
  - **Test Case 2 — Late Reminder Time**: Call `scheduleNightSummary` with 1 pending challenge (reminder at `once:23:45`). Assert notification is scheduled at 23:45 (since 23:45 > 23:30). On unfixed code, notifications are at hardcoded times — test FAILS.
  - **Test Case 3 — Default Floor Time**: Call `scheduleNightSummary` with 1 pending challenge (no reminder configured, `reminderTime` is null). Assert notification is at 23:30 (default floor). On unfixed code, 3 notifications at hardcoded times — test FAILS.
  - **Test Case 4 — Reset Warning Content**: Call `scheduleNightSummary` and inspect notification body for reset warning text. On unfixed code, body is `'Don't forget:\n...'` without reset warning — test FAILS.
  - **Test Case 5 — Deduplication via Fixed ID**: Assert the notification uses a fixed ID (999950) for deduplication. On unfixed code, three different IDs are used — test FAILS.
  - Use source code inspection (read `smart_notification_service.dart`) to verify structural properties where mocking the notification plugin is impractical
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct — it proves the bug exists)
  - Document counterexamples found: three notifications instead of one, hardcoded times ignoring reminder configuration, missing reset warning, multiple notification IDs
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Night-Summary Behavior Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Create test file `test/night_summary_preservation_test.dart`
  - **Observe on UNFIXED code first**, then write property-based tests capturing observed behavior
  - **Test Case 1 — Empty Pending List Preservation**: Observe that calling `scheduleNightSummary` with an empty list triggers `cancelNightSummaries`. Write test asserting this behavior is preserved (source inspection: method returns early and calls cancel when `pendingChallenges.isEmpty`).
  - **Test Case 2 — Per-Task Reminder Dispatch Preservation**: For all reminder types (`once:`, `multiple:`, `hourly:`, `interval:`, `custom:`, legacy `HH:mm`), verify `scheduleSmartReminders` dispatch logic routes correctly. Generate random reminder format strings and verify the dispatch conditions in source code are unchanged.
  - **Test Case 3 — Cancellation Method Preservation**: Verify `cancelCompletedTaskReminders` iterates all 24×60 time slots and calls cancel for each. Verify `cancelAllRemindersForDate` calls `cancelAll()` and resets `_scheduledCount`.
  - **Test Case 4 — Daily Motivation Preservation**: Verify `scheduleDailyMotivation` schedules at hour 8, minute 0 with the `daily_motivation_v3` channel. Source inspection confirms this method is untouched.
  - **Test Case 5 — Challenge Event Notifications Preservation**: Verify `showFailureNotification` and `showCompletionNotification` use the `challenge_events` channel with IDs 999 and 1000 respectively. Source inspection confirms these methods are untouched.
  - **Test Case 6 — Max Notifications Cap Preservation**: Verify `_maxNotifications` is 400 and `_canScheduleMore()` checks `_scheduledCount < _maxNotifications`. Source inspection confirms this is unchanged.
  - **Test Case 7 — Notification Channel Preservation**: Verify all four notification channels (`smart_reminders_v2`, `night_summary_v2`, `daily_motivation_v3`, `challenge_events`) are created in `_createNotificationChannels`.
  - Property-based approach: generate random lists of reminder format strings and verify the dispatch routing logic in `scheduleSmartReminders` correctly identifies each format prefix
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 3. Fix for pending task notification timing

  - [x] 3.1 Add `_extractLatestReminderTime` helper method
    - Add a private method `_extractLatestReminderTime(List<Challenge> challenges)` to `SmartNotificationService` in `lib/services/smart_notification_service.dart`
    - The method parses each challenge's `reminderTime` field across all formats: `once:HH:mm`, `hourly:HH:mm`, `multiple:HH:mm,HH:mm`, `interval:N:HH:mm`, `custom:HH:mm,HH:mm`, and legacy `HH:mm`
    - For challenges with `reminderTime == null` or `isReminderEnabled == false`, use `(0, 0)` as default so they don't influence the max calculation
    - Returns the latest time as a `({int hour, int minute})` record
    - Extract all `HH:mm` time tokens from the reminder string, parse each, and track the maximum
    - _Bug_Condition: isBugCondition(input) where pendingChallenges.length > 0 — the current code never inspects reminderTime_
    - _Expected_Behavior: latestReminderTime is correctly extracted from all reminder formats_
    - _Preservation: Per-task reminder scheduling in scheduleSmartReminders is not modified_
    - _Requirements: 2.2, 2.3_

  - [x] 3.2 Replace triple-notification loop with single notification at computed time
    - In `scheduleNightSummary`, remove the hardcoded `times` list `[(22, 0, ...), (23, 0, ...), (23, 45, ...)]` and the `for` loop
    - Call `_extractLatestReminderTime(pendingChallenges)` to get the latest reminder time
    - Compute the notification time as `max(23:30, latestReminderTime)` — compare extracted time against the 23:30 floor and use whichever is later
    - Schedule exactly one notification using `_notifications.zonedSchedule` at the computed time
    - Use a fixed notification ID of `999950` for deduplication (prevents duplicates when method is called multiple times for the same day)
    - _Bug_Condition: isBugCondition(input) where pendingChallenges.length > 0 AND date is today — currently schedules 3 notifications at static times_
    - _Expected_Behavior: exactly 1 notification at max(23:30, latestReminderTime) from design_
    - _Preservation: Empty pending list path (early return + cancelNightSummaries) unchanged_
    - _Requirements: 2.1, 2.2, 2.3, 2.7_

  - [x] 3.3 Update notification content to include task names and reset warning
    - Update the notification title to indicate pending task count (e.g., `'⏰ N tasks still pending'`)
    - Update the notification body to list each pending task by name using bullet points and include a reset warning (e.g., `'⚠️ Missing these will reset your challenge!\n\n• Task1\n• Task2'`)
    - Ensure both Android `BigTextStyleInformation` and iOS `DarwinNotificationDetails` include the updated content
    - _Bug_Condition: Current notification body is `'Don't forget:\n$taskList'` without reset warning_
    - _Expected_Behavior: Body contains each pending challenge title AND reset warning text_
    - _Preservation: Notification channel ID (_nightSummaryChannelId) unchanged_
    - _Requirements: 2.4, 2.5_

  - [x] 3.4 Update `cancelNightSummaries` to cancel single ID
    - Replace the loop cancelling three hardcoded IDs `[_nightSummaryId(22, 0), _nightSummaryId(23, 0), _nightSummaryId(23, 45)]` with a single `_notifications.cancel(999950)` call
    - Simplify or remove `_nightSummaryId` helper since it's no longer needed (or keep it returning the fixed ID `999950`)
    - _Bug_Condition: Current cancelNightSummaries cancels 3 IDs that no longer exist after the fix_
    - _Expected_Behavior: Cancels the single fixed notification ID 999950_
    - _Preservation: cancelAllRemindersForDate is not modified — it calls cancelAll() which covers everything_
    - _Requirements: 2.6, 2.7_

  - [x] 3.5 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Single Notification at Computed Time
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1 (`test/night_summary_bug_condition_test.dart`)
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.7_

  - [x] 3.6 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Night-Summary Behavior Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2 (`test/night_summary_preservation_test.dart`)
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions)

- [x] 4. Checkpoint - Ensure all tests pass
  - Run the full test suite: `flutter test test/night_summary_bug_condition_test.dart test/night_summary_preservation_test.dart`
  - Verify bug condition exploration test passes (bug is fixed)
  - Verify preservation property tests pass (no regressions)
  - Run existing tests to ensure no breakage: `flutter test`
  - Ensure all tests pass, ask the user if questions arise.
