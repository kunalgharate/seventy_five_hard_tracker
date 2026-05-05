# Implementation Plan: Restart Challenge from History

## Overview

Implement the ability for users to restart a past challenge session from the History screen. The implementation adds a new `RestartFromHistory` BLoC event, a pure helper function for testability, and enhances the `HistoryScreen` with full session details, a restart button, a confirmation dialog, and post-restart navigation.

## Tasks

- [x] 1. Add RestartFromHistory event and pure helper function
  - [x] 1.1 Add `RestartFromHistory` event class to `lib/bloc/challenge_event.dart`
    - Create a new `RestartFromHistory` class extending `ChallengeEvent` with a `sessionId` field
    - Include `props` override for Equatable
    - _Requirements: 5.1_

  - [x] 1.2 Add `createRestartedSession` pure helper function to `lib/bloc/challenge_bloc.dart`
    - Create a top-level pure function `createRestartedSession(ChallengeSession historicalSession)` that returns a new `ChallengeSession`
    - New session copies `challenges`, `resetMode`, `totalDaysTarget` from the historical session
    - New session sets `id` to timestamp, `startDate` to now, `currentDay` to 1, `isActive` to true, `isCompleted` to false, `failureReason` to null, `failedChallenges` to null
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [x] 1.3 Add `_onRestartFromHistory` handler to `ChallengeBloc`
    - Register `on<RestartFromHistory>(_onRestartFromHistory)` in the constructor
    - Handler: cancel all reminders, look up historical session by ID from `getAllSessions()`, emit `ChallengeError` if not found
    - If active session exists, deactivate it (set `isActive: false`, `endDate: now`)
    - Call `clearAllDailyProgress()`, create new session via `createRestartedSession()`, save it, log analytics, schedule reminders, dispatch `LoadChallengeData()`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.3, 5.1, 5.2, 5.3, 5.4_

  - [ ]* 1.4 Write property test for `createRestartedSession` — Property 1
    - **Property 1: Session restart preserves configuration and resets state fields**
    - Generate random `ChallengeSession` objects with varying challenges, resetMode, and totalDaysTarget
    - Assert preserved fields match (challenges, resetMode, totalDaysTarget) and reset fields are correct (currentDay=1, isActive=true, isCompleted=false, new id, null failureReason/failedChallenges)
    - Minimum 100 iterations
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 5.4**

  - [ ]* 1.5 Write property test for active session deactivation — Property 2
    - **Property 2: Active session deactivation on restart**
    - Generate random pairs of (active session, historical session)
    - Execute the deactivation logic (copyWith isActive=false, endDate=now)
    - Assert previously active session has `isActive == false` and `endDate != null`
    - Minimum 100 iterations
    - **Validates: Requirements 4.3**

- [x] 2. Checkpoint — Verify BLoC layer
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Enhance HistoryScreen with full session details
  - [x] 3.1 Display reset mode, total days target, and duration on each session card
    - Add reset mode label (Hard/Soft) and total days target to the `ExpansionTile` subtitle area
    - _Requirements: 1.1_

  - [x] 3.2 Display per-challenge details in expanded session card
    - Show each challenge's title, task type badge (hard/soft/regular), category, and reminder configuration summary
    - _Requirements: 1.2_

  - [x] 3.3 Display reset-specific details for reset sessions
    - Show failure reason, failed challenges list, and the day on which the reset occurred
    - _Requirements: 1.3_

  - [x] 3.4 Display completion indicator for completed sessions
    - Show a completion indicator and full 75-day duration confirmation for completed sessions
    - _Requirements: 1.4_

- [x] 4. Add Restart button and confirmation dialog to HistoryScreen
  - [x] 4.1 Add "Restart Challenge" button to expanded session card
    - Place an `ElevatedButton` labeled "Restart Challenge" at the bottom of the expanded section
    - Style with the app's orange accent color, ensure it is visually distinct
    - Add `Semantics` widget for screen reader accessibility
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 4.2 Implement confirmation dialog when active session exists
    - When restart is tapped and `state.hasActiveSession` is true, show an `AlertDialog`
    - Dialog title: "Active Challenge in Progress", body explains current session will be ended
    - "Cancel" button dismisses dialog, "End & Restart" button dispatches `RestartFromHistory(sessionId)`
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

  - [x] 4.3 Dispatch `RestartFromHistory` directly when no active session
    - When restart is tapped and no active session exists, dispatch `RestartFromHistory(sessionId)` immediately
    - _Requirements: 3.1_

- [x] 5. Add BlocListener for post-restart navigation
  - [x] 5.1 Add `BlocListener` to HistoryScreen for navigation after restart
    - Convert `HistoryScreen` to a `StatefulWidget` to track a local `_isRestarting` flag
    - Set `_isRestarting = true` before dispatching `RestartFromHistory`
    - In the `BlocListener`, when `ChallengeLoaded` is emitted and `_isRestarting` is true, navigate to home screen via `Navigator.pushReplacementNamed(context, '/home')` or `Navigator.pop()`
    - Also listen for `ChallengeError` to reset the flag and show error feedback
    - _Requirements: 3.7, 5.3_

  - [ ]* 5.2 Write unit tests for BLoC restart handler
    - Test that `RestartFromHistory` event is accepted and processes correctly
    - Test `ChallengeError` is emitted when session ID is not found
    - Test `clearAllDailyProgress()` is called during restart
    - Test `scheduleSmartReminders()` is called with new session's challenges
    - Test active session is deactivated when one exists before restart
    - _Requirements: 3.5, 3.6, 5.1, 5.2, 5.3, 5.4_

- [x] 6. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- The `createRestartedSession` pure function enables property-based testing without BLoC/repository dependencies
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific scenarios and integration points
