# Quick Reference Guide - App Update

## What's Been Done ✅

### 1. Data Models Enhanced
Your app now supports three types of tasks:
- **Hard Tasks**: Must complete or reset to day 1 (original 75 Hard behavior)
- **Soft Tasks**: Should complete but won't reset if missed
- **Regular Tasks**: Optional habit tracking

### 2. Smart Notifications Created
New notification system that:
- Only reminds you about **pending tasks** (not completed ones)
- Respects **time windows** (you set start/end hours)
- **Blocks midnight** notifications (no more 12 AM reminders!)
- Supports **three reminder types**:
  - Once: Single reminder at specific time
  - Hourly: Every hour within your time window
  - Custom: Every X minutes within your time window
- **Night summary**: Get a summary at 10 PM of pending tasks
- **Auto-cancels** reminders when you complete a task

### 3. Background Service Added
Runs even when app is closed:
- Checks for missed days every hour
- Auto-resets hard mode challenges if you miss a day
- Cancels all notifications on reset
- Works completely offline

---

## What You Need to Do Next

### Step 1: Install New Dependencies
```bash
cd /Users/kunalgharate/seventy_five_hard_tracker
flutter pub get
```

### Step 2: Update Your BLoC
The challenge_bloc.dart needs to use the new SmartNotificationService instead of the old NotificationService.

**Key changes:**
1. Replace `NotificationService` with `SmartNotificationService`
2. When a task is completed, cancel its reminders
3. When checking daily progress, only send reminders for pending tasks
4. On reset, cancel all notifications

### Step 3: Update main.dart
Initialize the new services:
```dart
// Add these initializations
final smartNotifications = SmartNotificationService();
await smartNotifications.initialize();

final backgroundService = BackgroundCheckService();
await backgroundService.initialize();
```

### Step 4: Test Notifications
Run the app and verify:
- Reminders only show for pending tasks
- No midnight notifications
- Reminders stop when you complete a task
- Night summary works at 10 PM

---

## New Features You Can Add

### 1. Task Type Selector (in onboarding)
Let users choose:
- Hard (resets on miss)
- Soft (tracks but doesn't reset)
- Regular (optional tracking)

### 2. Reminder Configuration
Let users set:
- Reminder type (once/hourly/custom)
- Time window (e.g., 8 AM - 10 PM)
- Allow night reminders (yes/no)
- Custom interval (for custom type)

### 3. Photo Capture
Add camera button to task cards to capture proof photos

### 4. Regular Tasks Tab
Create a separate tab for regular tasks that can be skipped

### 5. Profile Screen
Show user stats, sync status, and settings

---

## File Structure

```
lib/
├── models/
│   ├── challenge.dart ✅ (updated with new fields)
│   ├── challenge_session.dart ✅ (updated with reset mode)
│   └── daily_progress.dart ✅ (updated with photo support)
├── services/
│   ├── smart_notification_service.dart ✅ (NEW)
│   ├── background_check_service.dart ✅ (NEW)
│   ├── notification_service.dart (OLD - can be removed)
│   └── firebase_sync_service.dart (TODO)
├── screens/
│   ├── home_screen.dart (existing)
│   ├── onboarding_screen.dart (needs update)
│   ├── main_navigation_screen.dart (TODO)
│   ├── regular_tasks_screen.dart (TODO)
│   └── profile_screen.dart (TODO)
└── bloc/
    ├── challenge_bloc.dart (needs update)
    ├── challenge_event.dart (needs new events)
    └── challenge_state.dart (existing)
```

---

## Common Issues & Solutions

### Issue: "Hive adapter not registered"
**Solution:** Run code generation:
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Issue: "Notification sound not playing"
**Solution:** The new SmartNotificationService has proper sound configuration. Make sure:
1. `tune.wav` exists in `assets/sounds/`
2. Android notification channel is created
3. Sound permission is granted

### Issue: "App won't open without internet"
**Solution:** Remove any internet checks in main.dart. The app should work completely offline.

### Issue: "Reminders still showing after completion"
**Solution:** Call `cancelCompletedTaskReminders(challengeId)` when marking task as complete.

---

## Testing Checklist

Before releasing:
- [ ] Create a hard task with once reminder
- [ ] Complete it and verify reminder is cancelled
- [ ] Create a task with hourly reminders
- [ ] Verify reminders only come during time window
- [ ] Verify no reminders at midnight
- [ ] Miss a hard task and verify auto-reset
- [ ] Check night summary at 10 PM
- [ ] Test app works offline
- [ ] Test background service resets challenge

---

## Key Concepts

### Task Types
```dart
enum TaskType {
  hard,    // Must complete - resets to day 1 if missed
  soft,    // Should complete - doesn't reset but tracked
  regular  // Optional - for habit tracking only
}
```

### Reminder Types
```dart
enum ReminderType {
  once,    // Single reminder at specific time
  hourly,  // Hourly reminders within time window
  custom   // Custom interval (e.g., every 30 minutes)
}
```

### Reset Modes
```dart
enum ResetMode {
  hard,  // Any missed hard task resets to day 1
  soft   // Missed tasks tracked but no reset
}
```

---

## Example Usage

### Creating a Hard Task with Hourly Reminders
```dart
Challenge(
  id: 'workout',
  title: 'Workout 45 minutes',
  taskType: 'hard',
  reminderType: 'hourly',
  reminderStartHour: 8,  // 8 AM
  reminderEndHour: 20,   // 8 PM
  allowNightReminders: false,
  isReminderEnabled: true,
)
```

### Creating a Regular Task
```dart
Challenge(
  id: 'meditation',
  title: 'Meditate 10 minutes',
  taskType: 'regular',
  reminderType: 'once',
  reminderTime: '07:00',
  showInRegularTab: true,
  isReminderEnabled: true,
)
```

### Scheduling Smart Reminders
```dart
final smartNotifications = SmartNotificationService();
await smartNotifications.scheduleSmartReminders(
  DateTime.now(),
  challenges,
  currentProgress,
);
```

### Cancelling Reminders on Completion
```dart
await smartNotifications.cancelCompletedTaskReminders(challengeId);
```

---

## Migration Guide for Existing Users

Your existing data will be automatically migrated:
1. All existing challenges will be set to `taskType: 'hard'`
2. All existing reminders will be set to `reminderType: 'once'`
3. Default time window: 8 AM - 10 PM
4. Night reminders: Enabled by default
5. All existing sessions will be `resetMode: 'hard'`

No data will be lost!

---

## Future Enhancements

### Phase 1 (Current) ✅
- Smart notifications
- Task types
- Background service

### Phase 2 (Next)
- Photo capture
- Regular tasks screen
- Profile screen

### Phase 3 (Future)
- Firebase cloud sync
- Data encryption
- Cross-device sync
- Analytics dashboard

---

## Support & Troubleshooting

### Debug Mode
To see notification logs:
```dart
SmartNotificationService(isDebugMode: true)
```

### Check Background Service
```dart
final backgroundService = BackgroundCheckService();
await backgroundService.initialize(); // Start
await backgroundService.cancel(); // Stop
```

### Verify Hive Data
```dart
final box = await Hive.openBox<Challenge>('challenges');
print(box.values.first.taskType); // Should print 'hard', 'soft', or 'regular'
```

---

## Contact & Questions

If you need help with:
- BLoC integration
- UI updates
- Firebase setup
- Testing

Just ask! I can help you implement any of these features step by step.

---

**Version:** 2.0.0-beta
**Last Updated:** April 4, 2026
**Status:** Phase 1 Complete ✅
