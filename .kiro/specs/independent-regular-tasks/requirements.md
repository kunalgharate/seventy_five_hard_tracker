# Requirements Document

## Introduction

This document defines the requirements for making Regular Tasks fully independent from the 75 Hard Challenge system. Currently, regular tasks share the same model, repository, BLoC, and storage as the 75 Hard challenge — meaning they cannot exist without an active session. This feature introduces a dedicated vertical slice (model → repository → BLoC → UI) for regular tasks, an Apple-style rounded checkbox widget, a history restart feature, and a one-time data migration from the shared system.

## Glossary

- **Regular_Task_System**: The new independent subsystem comprising RegularTask model, RegularTaskRepository, RegularTaskBloc, and RegularTasksScreen that manages regular habit-tracking tasks separately from the 75 Hard challenge.
- **Challenge_System**: The existing 75 Hard Challenge subsystem comprising Challenge model, DatabaseRepository, ChallengeBloc, and HomeScreen.
- **RegularTask**: A standalone Hive-persisted data model (TypeId 3) representing a user-defined habit-tracking task, independent of the Challenge model.
- **RegularTaskCompletion**: A per-day completion record (TypeId 4) stored in its own Hive box, tracking which regular tasks were completed on a given date.
- **RegularTaskRepository**: The data access layer that manages the `regular_tasks` and `regular_task_completions` Hive boxes exclusively.
- **RegularTaskBloc**: The BLoC state manager that handles all regular task events and emits regular task states, with no dependency on ChallengeBloc.
- **AppleCheckbox**: A custom widget rendering an Apple-style rounded checkbox with a 150ms animated transition, replacing the current pill toggle.
- **Migration_Service**: A one-time utility that copies existing regular-type challenges and their completion data from the Challenge_System into the Regular_Task_System.
- **History_Restart**: A feature allowing users to start a new 75 Hard session by cloning the task configuration from a previously completed or failed session.
- **Hive_Box**: A local key-value storage container provided by the Hive database library.
- **Streak**: The count of consecutive calendar days on which a regular task was marked as completed.

## Requirements

### Requirement 1: Independent Regular Task Data Model

**User Story:** As a user, I want regular tasks to have their own data model and storage, so that they are not tied to or affected by the 75 Hard challenge lifecycle.

#### Acceptance Criteria

1. THE Regular_Task_System SHALL store RegularTask objects in a dedicated `regular_tasks` Hive_Box with TypeId 3, separate from the `challenge_sessions` Hive_Box
2. THE Regular_Task_System SHALL store RegularTaskCompletion objects in a dedicated `regular_task_completions` Hive_Box with TypeId 4, separate from the `daily_progress` Hive_Box
3. WHEN a RegularTask is created, THE Regular_Task_System SHALL persist the task with a non-empty id, non-empty title (max 100 characters), category, reminder settings, createdAt timestamp, and isArchived flag defaulting to false
4. WHEN a RegularTaskCompletion is saved, THE Regular_Task_System SHALL normalize the date to midnight and key the record by "YYYY-MM-DD" format
5. THE RegularTask serialization SHALL support round-trip conversion: serializing a RegularTask to JSON and deserializing it back SHALL produce an equivalent object

### Requirement 2: Independent Regular Task Repository

**User Story:** As a developer, I want a dedicated repository for regular tasks, so that data operations on regular tasks never touch 75 Hard challenge data.

#### Acceptance Criteria

1. THE RegularTaskRepository SHALL provide CRUD operations (saveTask, deleteTask, archiveTask, getAllTasks, getActiveTasks) that operate exclusively on the `regular_tasks` Hive_Box
2. THE RegularTaskRepository SHALL provide completion operations (saveCompletion, getCompletion, getCompletionsInRange) that operate exclusively on the `regular_task_completions` Hive_Box
3. WHEN any RegularTaskRepository method is called before initialization, THE RegularTaskRepository SHALL auto-initialize by opening the required Hive boxes
4. WHEN a regular task is deleted, THE RegularTaskRepository SHALL archive the task by setting isArchived to true instead of removing the record, preserving completion history
5. THE RegularTaskRepository SHALL never read from or write to the `challenge_sessions` or `daily_progress` Hive boxes

### Requirement 3: Independent Regular Task BLoC

**User Story:** As a user, I want regular task state management to be independent, so that toggling a regular task never triggers a 75 Hard challenge reset or affects challenge progress.

#### Acceptance Criteria

1. THE RegularTaskBloc SHALL handle LoadRegularTasks, AddRegularTask, UpdateRegularTask, DeleteRegularTask, ToggleRegularTaskCompletion, and UpdateRegularTaskReminder events using only the RegularTaskRepository
2. WHEN a ToggleRegularTaskCompletion event is processed, THE RegularTaskBloc SHALL update the completion state for the specified taskId and date, and emit a RegularTaskLoaded state with updated completions
3. WHEN any event is processed by the RegularTaskBloc, THE Challenge_System state SHALL remain unchanged
4. WHEN any event is processed by the ChallengeBloc, THE Regular_Task_System state SHALL remain unchanged
5. WHEN a regular task completion is toggled to true, THE RegularTaskBloc SHALL cancel the task's reminder for that day

### Requirement 4: Session-Independent Regular Tasks UI

**User Story:** As a user, I want to create and manage regular tasks even when no 75 Hard session is active, so that I can track habits independently.

#### Acceptance Criteria

1. WHEN the app launches with no active ChallengeSession, THE RegularTasksScreen SHALL still render and allow full interaction with regular tasks
2. WHEN the user navigates to the Regular Tasks tab, THE MainNavigationScreen SHALL display the RegularTasksScreen without gating it behind an active session check
3. THE RegularTasksScreen SHALL use RegularTaskBloc for all data operations instead of ChallengeBloc
4. WHEN the user taps the add button on RegularTasksScreen, THE Regular_Task_System SHALL present a task creation form that saves directly to the RegularTaskRepository

### Requirement 5: Apple-Style Rounded Checkbox Widget

**User Story:** As a user, I want a clean Apple-style checkbox instead of the pill toggle, so that task completion feels snappy and visually polished.

#### Acceptance Criteria

1. THE AppleCheckbox SHALL render as an empty circle when unchecked and a filled green circle with a white checkmark when checked
2. WHEN the AppleCheckbox is toggled, THE AppleCheckbox SHALL animate the transition in 150 milliseconds using an easeInOut curve
3. WHEN the AppleCheckbox is toggled, THE AppleCheckbox SHALL trigger haptic feedback
4. WHEN the AppleCheckbox isEnabled property is false, THE AppleCheckbox SHALL not respond to tap gestures
5. THE AppleCheckbox SHALL include a semantics label for screen reader accessibility

### Requirement 6: Streak and Statistics Calculation

**User Story:** As a user, I want to see accurate streak and completion statistics for each regular task, so that I can track my habit consistency.

#### Acceptance Criteria

1. THE Regular_Task_System SHALL calculate currentStreak as the length of the longest suffix of consecutive completed days for a given task
2. THE Regular_Task_System SHALL calculate bestStreak as the length of the longest consecutive run of completed days for a given task
3. FOR ALL completion histories, THE Regular_Task_System SHALL ensure that completed count plus missed count equals total count
4. FOR ALL completion histories, THE Regular_Task_System SHALL ensure that bestStreak is greater than or equal to currentStreak

### Requirement 7: Data Migration from Shared System

**User Story:** As an existing user, I want my current regular tasks and their completion history to be automatically migrated to the new independent system, so that I do not lose any data.

#### Acceptance Criteria

1. WHEN the app starts and migration has not been run, THE Migration_Service SHALL copy all Challenge objects with taskType 'regular' from ChallengeSession into the RegularTaskRepository as RegularTask objects
2. WHEN the Migration_Service copies completion data, THE Migration_Service SHALL transfer regular task completion entries from DailyProgress to RegularTaskCompletion records
3. WHEN migration completes for the active session, THE Migration_Service SHALL remove regular-type challenges from the active ChallengeSession challenges list
4. IF the Migration_Service is run multiple times, THEN THE Migration_Service SHALL produce the same result as running it once (idempotent behavior)
5. WHEN the Migration_Service runs, THE Migration_Service SHALL not modify any hard or soft task data in the Challenge_System

### Requirement 8: History Restart Feature

**User Story:** As a user, I want to restart a 75 Hard challenge using the task configuration from a previous attempt, so that I can quickly re-launch without re-entering all my tasks.

#### Acceptance Criteria

1. WHEN a user taps the restart button on a historical session, THE Challenge_System SHALL display a confirmation dialog warning that any current active session will be ended
2. WHEN the user confirms a history restart, THE Challenge_System SHALL create a new ChallengeSession with cloned non-regular challenges from the historical session
3. WHEN cloning challenges for a history restart, THE Challenge_System SHALL generate new unique IDs for each cloned challenge to avoid ID collisions with the source session
4. WHEN a history restart creates a new session, THE Challenge_System SHALL set currentDay to 1 and clear all daily progress
5. THE History_Restart feature SHALL only clone hard and soft task types, excluding regular tasks from the cloned challenge list

### Requirement 9: No-Reset Behavior for Regular Tasks

**User Story:** As a user, I want regular tasks to never trigger a challenge reset when missed, so that I can track habits without pressure.

#### Acceptance Criteria

1. WHEN a regular task is not completed on a given day, THE Regular_Task_System SHALL mark it as incomplete for that day without triggering any reset, session end, or penalty
2. WHEN the Challenge_System checks for missed days, THE Challenge_System SHALL exclude regular tasks from the missed-day evaluation
3. WHEN determining if all daily tasks are completed for a day, THE Challenge_System SHALL exclude regular tasks from the "all completed" calculation

