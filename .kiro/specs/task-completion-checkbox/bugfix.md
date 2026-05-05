# Bugfix: Task Completion Toggle Errors

## Bug Description
When toggling task completion in the 75 Hard Challenge app, users get an "unexpected error" message. The error originates from multiple issues in the task completion flow across the BLoC, notification service, UI, and repository layers.

## Root Causes Identified
1. `firstWhere` without `orElse` in BLoC crashes on missing challenge ID
2. Notification failures kill the entire toggle even though data is saved
3. `add(LoadChallengeData())` causes loading flash on every toggle
4. 1,440 sequential awaits in `cancelCompletedTaskReminders`
5. Notification ID hash collisions possible
6. Double rebuild from redundant BlocListener + BlocConsumer
7. Invalid `margin` on fixed SnackBar
8. Overlay entry leak on widget disposal
9. `logError` in analytics can throw, preventing error state emission
10. `getActiveSession` swallows all exceptions silently
11. SnackBar margin parameter invalid for fixed behavior

## Affected Files
- `lib/bloc/challenge_bloc.dart`
- `lib/services/smart_notification_service.dart`
- `lib/screens/home_screen.dart`
- `lib/widgets/daily_task_card.dart`
- `lib/services/analytics_service.dart`
- `lib/repositories/database_repository.dart`
