# Tasks: Task Completion Toggle Bugfix

- [x] 1. Fix `firstWhere` without `orElse` in `_onUpdateDailyProgress` (challenge_bloc.dart)
  - [x] 1.1 Add `orElse` or use `firstWhereOrNull` pattern to handle missing challenge ID gracefully
  - [x] 1.2 Return early or skip analytics if challenge not found
  - [x] 1.3 Verify no crash when challengeId doesn't match any challenge

- [x] 2. Isolate notification failures from task toggle success (challenge_bloc.dart)
  - [x] 2.1 Wrap notification calls in separate try-catch so data save isn't affected
  - [x] 2.2 Ensure progress is saved and UI updates even if notifications fail
  - [x] 2.3 Verify toggle works when notification service throws

- [x] 3. Fix loading flash on every toggle (challenge_bloc.dart)
  - [x] 3.1 Emit `ChallengeLoaded` directly instead of dispatching `LoadChallengeData` after progress update
  - [x] 3.2 Verify no loading spinner flash on task toggle

- [x] 4. Fix `cancelCompletedTaskReminders` 1,440 sequential awaits (smart_notification_service.dart)
  - [x] 4.1 Replace brute-force loop with targeted cancellation based on actual scheduled notifications
  - [x] 4.2 Wrap in try-catch to prevent single cancel failure from crashing the flow
  - [x] 4.3 Verify task toggle performance improvement

- [x] 5. Fix notification ID hash collisions (smart_notification_service.dart)
  - [x] 5.1 Improve hash function to reduce collision probability
  - [x] 5.2 Verify different challenge IDs produce different notification IDs

- [x] 6. Remove redundant BlocListener causing double rebuilds (home_screen.dart)
  - [x] 6.1 Remove outer BlocListener that calls setState on ChallengeLoaded
  - [x] 6.2 Verify UI still updates correctly on state changes

- [x] 7. Fix invalid SnackBar margin parameter (home_screen.dart)
  - [x] 7.1 Remove `margin: null` from fixed SnackBar
  - [x] 7.2 Verify error SnackBar displays correctly

- [x] 8. Fix overlay entry leak on widget disposal (daily_task_card.dart)
  - [x] 8.1 Track overlay entry and remove it in dispose if still active
  - [x] 8.2 Verify no overlay leak when navigating away during animation

- [x] 9. Fix `logError` throwing and preventing error state emission (analytics_service.dart)
  - [x] 9.1 Wrap Crashlytics call in try-catch inside `logError`
  - [x] 9.2 Verify error state is always emitted even when Crashlytics fails

- [x] 10. Fix `getActiveSession` swallowing all exceptions (database_repository.dart)
  - [x] 10.1 Only catch `StateError` (no element) instead of all exceptions
  - [x] 10.2 Log or rethrow unexpected exceptions
  - [x] 10.3 Verify Hive corruption errors are not silently swallowed
