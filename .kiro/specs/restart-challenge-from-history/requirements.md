# Requirements Document

## Introduction

This feature enables users to restart a past challenge directly from the Challenge History screen. Users can view full details of completed or reset challenge sessions and restart any historical session with the same task configuration, bypassing the onboarding flow entirely. The system handles conflicts when an active challenge already exists.

## Glossary

- **History_Screen**: The screen displaying all past (inactive) challenge sessions, accessible from the home screen app bar
- **Session_Card**: An expandable card widget on the History_Screen representing a single past ChallengeSession
- **Challenge_Session**: A data model containing the challenge configuration, dates, progress metadata, and active/completed status
- **Active_Session**: A ChallengeSession where isActive is true and isCompleted is false
- **Restart_Button**: A UI button displayed on each Session_Card that initiates the restart flow
- **Challenge_Bloc**: The BLoC component managing challenge state, events, and business logic
- **Notification_Service**: The SmartNotificationService responsible for scheduling task reminders
- **Database_Repository**: The Hive-based persistence layer for sessions and daily progress

## Requirements

### Requirement 1: Display Full Session Details in History

**User Story:** As a user, I want to see complete details of my past challenge sessions in the history screen, so that I can review what tasks I had and how far I progressed.

#### Acceptance Criteria

1. WHEN a user opens the History_Screen, THE History_Screen SHALL display each inactive Challenge_Session with its start date, end date, duration, reset mode, and total days target
2. WHEN a user expands a Session_Card, THE History_Screen SHALL display all challenges in that session including each challenge title, task type, category, and reminder configuration
3. WHEN a user expands a Session_Card for a reset session, THE History_Screen SHALL display the failure reason, failed challenges list, and the day on which the reset occurred
4. WHEN a user expands a Session_Card for a completed session, THE History_Screen SHALL display a completion indicator and the full 75-day duration confirmation

### Requirement 2: Display Restart Button on History Entries

**User Story:** As a user, I want a clearly visible restart button on each history entry, so that I can quickly restart a past challenge without navigating through the onboarding flow.

#### Acceptance Criteria

1. THE History_Screen SHALL display a Restart_Button on each Session_Card in the expanded details section
2. THE Restart_Button SHALL be visually distinct and labeled "Restart Challenge"
3. THE Restart_Button SHALL be accessible and include appropriate semantics for screen readers

### Requirement 3: Restart Challenge When No Active Session Exists

**User Story:** As a user, I want to immediately restart a past challenge when I have no active challenge, so that I can resume my routine without re-entering all task configurations.

#### Acceptance Criteria

1. WHEN the user taps the Restart_Button AND no Active_Session exists, THE Challenge_Bloc SHALL create a new Challenge_Session using the same list of Challenge objects from the historical session
2. WHEN the Challenge_Bloc creates a restarted session, THE Challenge_Bloc SHALL set the new session start date to the current date and time
3. WHEN the Challenge_Bloc creates a restarted session, THE Challenge_Bloc SHALL set currentDay to 1, isActive to true, and isCompleted to false
4. WHEN the Challenge_Bloc creates a restarted session, THE Challenge_Bloc SHALL preserve the resetMode and totalDaysTarget from the original historical session
5. WHEN the Challenge_Bloc creates a restarted session, THE Database_Repository SHALL clear all existing daily progress data
6. WHEN the Challenge_Bloc creates a restarted session, THE Notification_Service SHALL schedule smart reminders for all challenges in the new session
7. WHEN the restart completes successfully, THE History_Screen SHALL navigate the user to the home screen showing the new active session

### Requirement 4: Handle Restart When Active Session Exists

**User Story:** As a user, I want to be informed when I cannot directly restart because I already have an active challenge, so that I do not accidentally lose my current progress.

#### Acceptance Criteria

1. WHEN the user taps the Restart_Button AND an Active_Session exists, THE History_Screen SHALL display a confirmation dialog explaining that an active challenge is in progress
2. THE confirmation dialog SHALL present the user with options to either cancel the action or end the current session and proceed with the restart
3. WHEN the user confirms ending the current session, THE Challenge_Bloc SHALL mark the Active_Session as inactive with an end date of the current time before creating the restarted session
4. WHEN the user cancels the confirmation dialog, THE History_Screen SHALL dismiss the dialog and take no further action

### Requirement 5: Restart Event in Challenge Bloc

**User Story:** As a developer, I want a dedicated BLoC event for restarting from history, so that the restart logic is cleanly separated from the new session creation flow.

#### Acceptance Criteria

1. THE Challenge_Bloc SHALL accept a RestartFromHistory event containing the historical Challenge_Session identifier
2. WHEN the Challenge_Bloc receives a RestartFromHistory event, THE Challenge_Bloc SHALL retrieve the historical session from the Database_Repository using the provided identifier
3. IF the historical session cannot be found in the Database_Repository, THEN THE Challenge_Bloc SHALL emit a ChallengeError state with a descriptive message
4. WHEN the Challenge_Bloc successfully processes a RestartFromHistory event, THE Challenge_Bloc SHALL emit a ChallengeLoaded state with the new active session
