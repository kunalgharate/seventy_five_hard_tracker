# Bugfix Requirements Document

## Introduction

The app's end-of-day pending task notification system has two related defects. First, `SmartNotificationService.scheduleNightSummary` sends three separate notifications at 10:00 PM, 11:00 PM, and 11:45 PM for pending tasks, instead of sending a single consolidated notification. Second, the notification timing is static rather than being calculated relative to the user's latest task reminder time. The correct behavior is to send exactly one pending-task notification per day, timed at the later of 11:30 PM or the last task's reminder time, that lists all incomplete tasks and warns the user that missing them will cause a challenge reset. If all tasks are already completed, no notification should be sent.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN there are pending (incomplete) tasks at the end of the day THEN the system sends three separate night summary notifications at 10:00 PM, 11:00 PM, and 11:45 PM instead of a single consolidated notification

1.2 WHEN there are pending tasks THEN the system uses hardcoded notification times (10:00 PM, 11:00 PM, 11:45 PM) that do not account for the latest task reminder time configured by the user

1.3 WHEN the last task reminder is scheduled at or before 11:30 PM (e.g., 5:00 PM or 11:00 PM) THEN the system does not send a single pending notification at 11:30 PM, instead sending multiple notifications at the three fixed times

1.4 WHEN the last task reminder is scheduled after 11:30 PM (e.g., 11:45 PM) THEN the system does not send the pending notification at the last task's reminder time, instead still using the three fixed times

1.5 WHEN the night summary notifications are sent THEN the notification content does not include a warning that incomplete tasks will cause a challenge reset

1.6 WHEN all tasks are already completed for the day THEN the system correctly cancels night summaries, however the cancellation only happens reactively when `scheduleNightSummary` is called with an empty list rather than being proactively checked at notification time

### Expected Behavior (Correct)

2.1 WHEN there are pending (incomplete) tasks at the end of the day THEN the system SHALL send exactly one consolidated notification listing all pending tasks

2.2 WHEN there are pending tasks and the latest task reminder time across all challenges is at or before 11:30 PM THEN the system SHALL schedule the single pending notification at 11:30 PM

2.3 WHEN there are pending tasks and the latest task reminder time across all challenges is after 11:30 PM THEN the system SHALL schedule the single pending notification at the latest task reminder time (e.g., if the last reminder is at 11:45 PM, the pending notification fires at 11:45 PM)

2.4 WHEN the single pending notification is sent THEN the system SHALL include the list of specific tasks that are still incomplete (e.g., "• Workout\n• Read 10 pages")

2.5 WHEN the single pending notification is sent THEN the system SHALL include a warning that incomplete tasks will cause a challenge reset

2.6 WHEN all tasks for the day are already completed THEN the system SHALL NOT send any pending task notification

2.7 WHEN the pending notification has already been sent for the current day THEN the system SHALL NOT send it again (once per day maximum)

### Unchanged Behavior (Regression Prevention)

3.1 WHEN individual task reminders are configured with specific times and types (once, hourly, custom, interval) THEN the system SHALL CONTINUE TO schedule those per-task reminders as before

3.2 WHEN a task is marked as completed THEN the system SHALL CONTINUE TO cancel that task's individual reminders via `cancelCompletedTaskReminders`

3.3 WHEN the daily motivation notification is scheduled THEN the system SHALL CONTINUE TO send it at 8:00 AM as before

3.4 WHEN a challenge reset occurs due to missed hard tasks THEN the system SHALL CONTINUE TO show the failure notification via `showFailureNotification`

3.5 WHEN the 75-day challenge is completed THEN the system SHALL CONTINUE TO show the completion notification via `showCompletionNotification`

3.6 WHEN `cancelAllRemindersForDate` is called (e.g., on session start/reset) THEN the system SHALL CONTINUE TO cancel all scheduled notifications

3.7 WHEN the Samsung 500-alarm limit is approached THEN the system SHALL CONTINUE TO respect the `_maxNotifications` cap of 400 scheduled notifications
