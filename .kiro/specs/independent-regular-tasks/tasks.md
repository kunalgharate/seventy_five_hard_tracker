# Implementation Plan: Independent Regular Tasks

## Overview

Decouple Regular Tasks from the 75 Hard Challenge system by creating a fully independent vertical slice: new Hive models (RegularTask, RegularTaskCompletion), a dedicated repository, a standalone BLoC, an Apple-style checkbox widget, data migration, history restart, and UI updates. Each task builds incrementally on the previous, wiring everything together at the end.

## Tasks

- [x] 1. Create RegularTask and RegularTaskCompletion models with Hive adapters
  - [x] 1.1 Create `lib/models/regular_task.dart` with `@HiveType(typeId: 3)` RegularTask class
    - Include all fields from design: id, title, reminderTime, isReminderEnabled, imagePath, iconName, iconColor, category, reminderType, reminderStartHour, reminderEndHour, allowNightReminders, reminderIntervalMinutes, createdAt, isArchived
    - Implement `copyWith()`, `toJson()`, `fromJson()`, `toChallenge()` adapter method, and Equatable props
    - _Requirements: 1.1, 1.3, 1.5_

  - [x] 1.2 Create `lib/models/regular_task_completion.dart` with `@HiveType(typeId: 4)` RegularTaskCompletion class
    - Include fields: date (DateTime), taskCompletions (Map<String, bool>)
    - Implement `copyWith()`, `toJson()`, `fromJson()`, and Equatable props
    - _Requirements: 1.2, 1.4_

  - [x] 1.3 Run `dart run build_runner build --delete-conflicting-outputs` to generate Hive adapters
    - Verify `regular_task.g.dart` and `regular_task_completion.g.dart` are generated
    - _Requirements: 1.1, 1.2_

  - [x] 1.4 Write property test for RegularTask serialization round-trip
    - **Property 1: RegularTask serialization round-trip**
    - **Validates: Requirement 1.5**

  - [x] 1.5 Write property test for completion date normalization
    - **Property 2: Completion date normalization**
    - **Validates: Requirement 1.4**

- [x] 2. Create RegularTaskRepository
  - [x] 2.1 Create `lib/repositories/regular_task_repository.dart`
    - Implement `init()`, `_ensureInitialized()` with auto-init pattern (matching DatabaseRepository)
    - Open `regular_tasks` and `regular_task_completions` Hive boxes
    - Implement `saveTask()`, `deleteTask()` (archive, not hard delete), `archiveTask()`, `getAllTasks()`, `getActiveTasks()`, `getTaskById()`
    - Implement `saveCompletion()`, `getCompletion()`, `getCompletionsInRange()` with date key normalization ("YYYY-MM-DD")
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 2.2 Write property test for repository data isolation
    - **Property 5: Repository data isolation**
    - **Validates: Requirements 2.5, 1.1, 1.2**

  - [x] 2.3 Write property test for archive-on-delete preserves records
    - **Property 4: Archive-on-delete preserves records**
    - **Validates: Requirement 2.4**

- [x] 3. Create RegularTaskBloc with events and states
  - [x] 3.1 Create `lib/bloc/regular_task_event.dart`
    - Define events: LoadRegularTasks, AddRegularTask, UpdateRegularTask, DeleteRegularTask, ToggleRegularTaskCompletion, UpdateRegularTaskReminder
    - _Requirements: 3.1_

  - [x] 3.2 Create `lib/bloc/regular_task_state.dart`
    - Define states: RegularTaskInitial, RegularTaskLoading, RegularTaskLoaded (with tasks, todayCompletions, recentCompletions), RegularTaskError
    - _Requirements: 3.1, 3.2_

  - [x] 3.3 Create `lib/bloc/regular_task_bloc.dart`
    - Inject RegularTaskRepository and SmartNotificationService
    - Handle all events: _onLoadRegularTasks, _onAddRegularTask, _onUpdateRegularTask, _onDeleteRegularTask, _onToggleCompletion, _onUpdateReminder
    - On ToggleRegularTaskCompletion: update completion, emit RegularTaskLoaded, cancel reminder if completed
    - _Requirements: 3.1, 3.2, 3.5_

  - [x] 3.4 Write property test for BLoC bidirectional independence
    - **Property 3: BLoC bidirectional independence**
    - **Validates: Requirements 3.3, 3.4, 9.1**

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Create AppleCheckbox widget
  - [x] 5.1 Create `lib/widgets/apple_checkbox.dart`
    - Render empty circle when unchecked, filled green circle with white checkmark when checked
    - Use AnimationController with 150ms duration and Curves.easeInOut
    - Trigger haptic feedback via HapticFeedback.lightImpact() on toggle
    - Respect `isEnabled` property — no tap response when disabled
    - Add Semantics widget with label for screen reader accessibility
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 6. Update DailyTaskCard to use AppleCheckbox
  - [x] 6.1 Replace the pill toggle in `lib/widgets/daily_task_card.dart` `_buildCompletionWidget()` with AppleCheckbox
    - Replace the existing GestureDetector + AnimatedContainer pill toggle with `AppleCheckbox(isChecked: widget.isCompleted, isEnabled: widget.isEditable, onChanged: (value) => widget.onToggle(value))`
    - Keep the non-editable status icon unchanged
    - _Requirements: 5.1, 5.2_

- [x] 7. Update RegularTasksScreen to use RegularTaskBloc
  - [x] 7.1 Rewrite `lib/screens/regular_tasks_screen.dart` to use `BlocBuilder<RegularTaskBloc, RegularTaskState>`
    - Replace all ChallengeBloc references with RegularTaskBloc
    - Use `state.tasks` and `state.todayCompletions` from RegularTaskLoaded
    - Dispatch ToggleRegularTaskCompletion instead of UpdateDailyProgress
    - Remove the "No Active Challenge" empty state — screen always works
    - Keep the add task bottom sheet but dispatch AddRegularTask instead of AddChallengeToSession
    - Calculate stats using RegularTaskCompletion data via `getCompletionsInRange()`
    - _Requirements: 4.1, 4.3, 4.4, 3.2_

  - [x] 7.2 Write property test for streak and statistics calculation
    - **Property 6: Streak and statistics invariants**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4**

- [x] 8. Update main.dart to register new Hive adapters and provide RegularTaskBloc
  - [x] 8.1 Modify `lib/main.dart`
    - Register `RegularTaskAdapter()` with typeId 3 and `RegularTaskCompletionAdapter()` with typeId 4 (with `isAdapterRegistered` guards)
    - Replace single `BlocProvider` with `MultiBlocProvider` providing both ChallengeBloc and RegularTaskBloc
    - Initialize RegularTaskBloc with `RegularTaskRepository()` and `smartNotifications`, dispatch `LoadRegularTasks()`
    - _Requirements: 1.1, 1.2, 3.1, 4.1_

- [x] 9. Update MainNavigationScreen to not gate Regular Tasks behind active session
  - [x] 9.1 Modify `lib/screens/main_navigation_screen.dart`
    - Remove the `BlocBuilder<ChallengeBloc, ChallengeState>` wrapper that gates the entire navigation
    - Always show the bottom navigation bar with all three tabs
    - The 75 Hard tab (HomeScreen) handles its own empty state internally
    - The Regular Tasks tab always renders RegularTasksScreen (uses RegularTaskBloc)
    - The Profile tab remains unchanged
    - _Requirements: 4.1, 4.2_

- [x] 10. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Create data migration service
  - [ ] 11.1 Create `lib/services/regular_task_migration_service.dart`
    - Implement `migrateRegularTasks(DatabaseRepository, RegularTaskRepository)` following the design pseudocode
    - Step 1: Find all sessions containing regular tasks
    - Step 2: Check if already migrated (idempotent — skip if task ID exists)
    - Step 3: Create RegularTask from each Challenge with taskType 'regular'
    - Step 4: Copy completion data from DailyProgress to RegularTaskCompletion
    - Step 5: Remove regular tasks from active ChallengeSession challenges list
    - Add a `hasMigrated` flag in Hive settings box to skip on subsequent launches
    - _Requirements: 7.1, 7.2, 7.3, 7.5_

  - [ ] 11.2 Call migration service from `main.dart` or `InitialScreen` on app startup
    - Run migration after Hive init and before BLoC creation
    - Only run if `hasMigrated` flag is not set
    - _Requirements: 7.1, 7.4_

  - [ ] 11.3 Write property test for migration correctness
    - **Property 7: Migration correctness**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.5**

  - [ ] 11.4 Write property test for migration idempotency
    - **Property 8: Migration idempotency**
    - **Validates: Requirement 7.4**

- [ ] 12. Update ChallengeBloc to exclude regular tasks from reset checks
  - [ ] 12.1 Modify `lib/bloc/challenge_bloc.dart` `_checkForMissedDays()` method
    - Ensure the missed-day check only evaluates hard tasks (already partially done — verify `c.type == TaskType.hard` filter is correct)
    - Verify `_onUpdateDailyProgress` excludes regular tasks from the `allCompleted` check (already filters `c.taskType != 'regular'` — confirm)
    - _Requirements: 9.2, 9.3_

  - [ ] 12.2 Write property test for regular tasks excluded from reset evaluation
    - **Property 10: Regular tasks excluded from reset evaluation**
    - **Validates: Requirements 9.2, 9.3**

- [ ] 13. Add history restart feature to HistoryScreen
  - [ ] 13.1 Modify `lib/screens/history_screen.dart`
    - Add a "Restart with these tasks" button to each historical session card
    - Show confirmation dialog warning that current active session will be ended
    - On confirm: clone non-regular challenges with new unique IDs, dispatch `StartNewSession(clonedChallenges)` to ChallengeBloc
    - Navigate back to home after restart
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [ ] 13.2 Write property test for history restart produces unique non-regular clones
    - **Property 9: History restart produces unique non-regular clones**
    - **Validates: Requirements 8.2, 8.3, 8.5**

- [ ] 14. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- The `toChallenge()` adapter method on RegularTask allows reuse of the existing DailyTaskCard widget without modifying its interface
- Run `dart run build_runner build --delete-conflicting-outputs` after creating models (task 1.3) before proceeding
