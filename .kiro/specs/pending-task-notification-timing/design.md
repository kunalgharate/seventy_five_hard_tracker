# Pending Task Notification Timing Bugfix Design

## Overview

The `SmartNotificationService.scheduleNightSummary` method currently fires three hardcoded notifications at 10:00 PM, 11:00 PM, and 11:45 PM for pending tasks. The fix replaces this with a single consolidated notification whose timing is dynamically computed as `max(23:30, latestReminderTime)` across all pending challenges. The notification must list every incomplete task by name, warn the user that missing them causes a challenge reset, and be skipped entirely when all tasks are already done.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug — `scheduleNightSummary` is called with a non-empty list of pending challenges, causing three separate notifications at static times instead of one dynamically-timed notification
- **Property (P)**: The desired behavior — exactly one notification is scheduled at `max(23:30, latestReminderTime)`, containing pending task names and a reset warning
- **Preservation**: Existing per-task reminders (`scheduleSmartReminders`), completed-task cancellation, daily motivation, failure/completion notifications, and the Samsung alarm cap must remain unchanged
- **scheduleNightSummary**: The method in `lib/services/smart_notification_service.dart` that schedules end-of-day pending task notifications
- **reminderTime**: A `String?` field on `Challenge` encoding the reminder schedule (e.g., `"once:09:00"`, `"hourly:14:00"`, `"multiple:08:00,12:00,18:00"`, `"interval:120:09:00"`, `"custom:07:30,15:00"`, or legacy `"HH:mm"`)
- **latestReminderTime**: The maximum reminder time extracted from all pending challenges' `reminderTime` fields, used to compute notification scheduling time

## Bug Details

### Bug Condition

The bug manifests when `scheduleNightSummary` is called with one or more pending (incomplete) challenges. Instead of computing a single optimal notification time based on the challenges' reminder configurations, the method unconditionally schedules three notifications at hardcoded times (22:00, 23:00, 23:45). Additionally, the notification content lacks a reset warning, and the timing ignores the user's configured reminder times entirely.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type { date: DateTime, pendingChallenges: List<Challenge> }
  OUTPUT: boolean

  RETURN pendingChallenges.length > 0
         AND date is today
END FUNCTION
```

### Examples

- **Example 1**: User has 2 pending tasks with reminders at 09:00 and 17:00. Current behavior: 3 notifications at 22:00, 23:00, 23:45. Expected: 1 notification at 23:30 (since max reminder 17:00 < 23:30).
- **Example 2**: User has 1 pending task with reminder at 23:45. Current behavior: 3 notifications at 22:00, 23:00, 23:45. Expected: 1 notification at 23:45 (since 23:45 > 23:30).
- **Example 3**: User has 3 pending tasks with reminders at 08:00, 12:00, 23:50. Current behavior: 3 notifications at 22:00, 23:00, 23:45. Expected: 1 notification at 23:50 (latest reminder time).
- **Example 4**: All tasks completed. Current behavior: `cancelNightSummaries` called (correct). Expected: no notification scheduled (same — this path is already correct).
- **Example 5**: User has 1 pending task with no reminder configured (`reminderTime` is null). Current behavior: 3 notifications. Expected: 1 notification at 23:30 (default floor since no reminder time to compare).

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Per-task reminders scheduled via `scheduleSmartReminders` for all reminder types (once, hourly, multiple, interval, custom, legacy) must continue to work exactly as before
- `cancelCompletedTaskReminders` must continue to cancel individual task reminders when a task is marked complete
- `scheduleDailyMotivation` must continue to send the daily motivation notification at 8:00 AM
- `showFailureNotification` must continue to display the challenge reset notification
- `showCompletionNotification` must continue to display the 75-day completion notification
- `cancelAllRemindersForDate` must continue to cancel all scheduled notifications
- The `_maxNotifications` cap of 400 must continue to be respected

**Scope:**
All inputs that do NOT involve `scheduleNightSummary` should be completely unaffected by this fix. This includes:
- Individual task reminder scheduling and cancellation
- Daily motivation notifications
- Challenge event notifications (reset, completion)
- Notification channel creation and initialization
- Permission requests

## Hypothesized Root Cause

Based on the bug description and code analysis, the root causes are:

1. **Hardcoded Triple Scheduling**: `scheduleNightSummary` iterates over a fixed list of `(22, 0), (23, 0), (23, 45)` time tuples and schedules a notification for each, rather than computing a single optimal time.

2. **No Reminder Time Extraction Logic**: The method receives `List<Challenge>` but never inspects the `reminderTime` field on each challenge. There is no logic to parse the various reminder time formats (`once:HH:mm`, `hourly:HH:mm`, `multiple:...`, `interval:...`, `custom:...`, legacy `HH:mm`) and extract the latest time.

3. **Missing Reset Warning in Content**: The notification body template uses `'Don\'t forget:\n$taskList'` without any mention of challenge reset consequences.

4. **No Deduplication Guard**: There is no mechanism to prevent the method from scheduling duplicate notifications if called multiple times for the same day (e.g., when the user toggles multiple tasks).

## Correctness Properties

Property 1: Bug Condition - Single Notification at Computed Time

_For any_ input where there are pending (incomplete) challenges and the date is today, the fixed `scheduleNightSummary` function SHALL schedule exactly one notification at `max(23:30, latestReminderTime)`, where `latestReminderTime` is the maximum time extracted from all pending challenges' `reminderTime` fields (defaulting to 00:00 if no reminder is configured). The notification body SHALL contain each pending task's title and a reset warning.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**

Property 2: Preservation - Non-Night-Summary Behavior Unchanged

_For any_ input that does NOT involve `scheduleNightSummary` (per-task reminders, daily motivation, challenge events, cancellation), the fixed code SHALL produce exactly the same behavior as the original code, preserving all existing notification scheduling, cancellation, and display functionality.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `lib/services/smart_notification_service.dart`

**Function**: `scheduleNightSummary`

**Specific Changes**:

1. **Add Reminder Time Extraction Helper**: Create a private method `_extractLatestReminderTime(List<Challenge> challenges)` that parses each challenge's `reminderTime` field across all formats (`once:HH:mm`, `hourly:HH:mm`, `multiple:HH:mm,HH:mm`, `interval:N:HH:mm`, `custom:HH:mm,HH:mm`, legacy `HH:mm`) and returns the latest time as a `(int hour, int minute)` tuple. For challenges with no `reminderTime` or reminders disabled, use `(0, 0)` as the default so they don't influence the max calculation.

2. **Compute Single Notification Time**: Replace the hardcoded `times` list with a single computed time: `max(23:30, latestReminderTime)`. Compare the extracted latest reminder time against the 23:30 floor and use whichever is later.

3. **Schedule One Notification**: Replace the loop over three time tuples with a single `_notifications.zonedSchedule` call at the computed time.

4. **Update Notification Content**: Change the notification title and body to include pending task names and a reset warning message (e.g., "⚠️ Missing these will reset your challenge!").

5. **Update `cancelNightSummaries`**: Replace the loop cancelling three hardcoded notification IDs with cancellation of the single notification ID used by the new implementation. Use a fixed notification ID (e.g., `999950`) for the single night summary so it can be reliably cancelled and prevents duplicates when the method is called multiple times.

6. **Update `_nightSummaryId`**: Simplify to return a single fixed ID since there is now only one night summary notification per day.

**File**: `lib/bloc/challenge_bloc.dart`

**No changes required**: The BLoC already calls `scheduleNightSummary` with the correct arguments (`date` and `pendingChallenges`). The interface remains the same.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write tests that call `scheduleNightSummary` with various pending challenge configurations and inspect how many notifications are scheduled and at what times. Run these tests on the UNFIXED code to observe failures and understand the root cause.

**Test Cases**:
1. **Triple Notification Test**: Call `scheduleNightSummary` with 2 pending challenges (reminders at 09:00 and 17:00). Assert only 1 notification is scheduled. (Will fail on unfixed code — 3 notifications are scheduled.)
2. **Late Reminder Time Test**: Call `scheduleNightSummary` with 1 pending challenge (reminder at 23:45). Assert notification is at 23:45. (Will fail on unfixed code — notifications at 22:00, 23:00, 23:45 regardless of reminder time.)
3. **Default Floor Time Test**: Call `scheduleNightSummary` with 1 pending challenge (no reminder configured). Assert notification is at 23:30. (Will fail on unfixed code — 3 notifications at hardcoded times.)
4. **Reset Warning Content Test**: Call `scheduleNightSummary` and inspect notification body for reset warning text. (Will fail on unfixed code — no warning present.)

**Expected Counterexamples**:
- Three notifications are scheduled instead of one
- Notification times are always 22:00, 23:00, 23:45 regardless of challenge reminder configuration
- Notification body lacks reset warning text
- Possible causes: hardcoded time list, no reminder time parsing, static content template

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := scheduleNightSummary_fixed(input.date, input.pendingChallenges)
  ASSERT notificationCount(result) == 1
  ASSERT notificationTime(result) == max(23:30, latestReminderTime(input.pendingChallenges))
  ASSERT notificationBody(result) CONTAINS each pending challenge title
  ASSERT notificationBody(result) CONTAINS reset warning
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT scheduleNightSummary_original(input) = scheduleNightSummary_fixed(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the input domain of reminder time formats
- It catches edge cases in reminder time parsing that manual unit tests might miss
- It provides strong guarantees that per-task reminder behavior is unchanged

**Test Plan**: Observe behavior on UNFIXED code first for empty pending lists and non-night-summary methods, then write property-based tests capturing that behavior.

**Test Cases**:
1. **Empty Pending List Preservation**: Verify that calling `scheduleNightSummary` with an empty list cancels night summaries (same behavior before and after fix)
2. **Per-Task Reminder Preservation**: Verify that `scheduleSmartReminders` continues to schedule reminders correctly for all reminder formats (once, hourly, multiple, interval, custom, legacy)
3. **Cancellation Preservation**: Verify that `cancelCompletedTaskReminders` and `cancelAllRemindersForDate` continue to work correctly
4. **Other Notification Preservation**: Verify that `scheduleDailyMotivation`, `showFailureNotification`, and `showCompletionNotification` are unaffected

### Unit Tests

- Test `_extractLatestReminderTime` with each reminder format: `once:HH:mm`, `hourly:HH:mm`, `multiple:HH:mm,HH:mm`, `interval:N:HH:mm`, `custom:HH:mm,HH:mm`, legacy `HH:mm`
- Test notification time computation: `max(23:30, latestReminderTime)` for various inputs
- Test edge cases: all challenges have null `reminderTime`, single challenge, challenges with reminders disabled
- Test notification content includes all pending task titles and reset warning
- Test that calling `scheduleNightSummary` twice for the same day results in only one notification (deduplication via fixed ID)

### Property-Based Tests

- Generate random lists of challenges with random reminder time formats and verify exactly one notification is scheduled at the correct computed time
- Generate random reminder time strings across all supported formats and verify `_extractLatestReminderTime` correctly identifies the maximum time
- Generate random sets of challenges and verify that `scheduleSmartReminders` behavior is identical before and after the fix

### Integration Tests

- Test full flow: BLoC calls `_onUpdateDailyProgress` → pending challenges computed → `scheduleNightSummary` called → single notification scheduled at correct time
- Test toggle scenario: mark task complete → mark task incomplete → verify notification is rescheduled correctly (single notification, not accumulating)
- Test all-done scenario: complete all tasks → verify no night summary notification exists
