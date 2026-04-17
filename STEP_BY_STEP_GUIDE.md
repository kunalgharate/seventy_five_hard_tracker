# Step-by-Step Implementation Guide

## 🎯 Goal
Get the smart notification system working in your app to fix all notification-related issues.

---

## Step 1: Install Dependencies (5 minutes)

```bash
cd /Users/kunalgharate/seventy_five_hard_tracker
flutter pub get
```

**Expected output:** All dependencies installed successfully

---

## Step 2: Update main.dart (10 minutes)

**File:** `lib/main.dart`

### Find this section:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ... existing code
}
```

### Add these imports at the top:
```dart
import 'services/smart_notification_service.dart';
import 'services/background_check_service.dart';
```

### Add initialization after Firebase:
```dart
// Initialize smart notifications
final smartNotifications = SmartNotificationService();
await smartNotifications.initialize();

// Initialize background service for offline reset detection
final backgroundService = BackgroundCheckService();
await backgroundService.initialize();
```

---

## Step 3: Update Challenge BLoC (30 minutes)

**File:** `lib/bloc/challenge_bloc.dart`

### 3.1: Add imports
```dart
import '../services/smart_notification_service.dart';
import '../services/background_check_service.dart';
```

### 3.2: Add service instances
Find the class declaration and add:
```dart
class ChallengeBloc extends Bloc<ChallengeEvent, ChallengeState> {
  final DatabaseRepository _repository;
  final SmartNotificationService _smartNotifications;
  final BackgroundCheckService _backgroundService;
  
  ChallengeBloc({
    required DatabaseRepository repository,
    required SmartNotificationService smartNotifications,
    required BackgroundCheckService backgroundService,
  })  : _repository = repository,
        _smartNotifications = smartNotifications,
        _backgroundService = backgroundService,
        super(ChallengeInitial()) {
    // ... event handlers
  }
}
```

### 3.3: Update UpdateDailyProgress handler
Find the `_onUpdateDailyProgress` method and update it:

```dart
Future<void> _onUpdateDailyProgress(
  UpdateDailyProgress event,
  Emitter<ChallengeState> emit,
) async {
  if (state is! ChallengeLoaded) return;
  
  final currentState = state as ChallengeLoaded;
  
  // ... existing progress update code ...
  
  // NEW: Cancel reminders for completed tasks
  if (event.isCompleted) {
    await _smartNotifications.cancelCompletedTaskReminders(event.challengeId);
  }
  
  // NEW: Reschedule smart reminders for pending tasks
  await _smartNotifications.scheduleSmartReminders(
    event.date,
    currentState.activeSession!.challenges,
    updatedProgress,
  );
  
  // NEW: Schedule night summary if there are pending tasks
  final pendingChallenges = _getPendingChallenges(
    currentState.activeSession!.challenges,
    updatedProgress,
  );
  
  if (pendingChallenges.isNotEmpty) {
    await _smartNotifications.scheduleNightSummary(
      event.date,
      pendingChallenges,
    );
  }
  
  // ... rest of existing code ...
}
```

### 3.4: Add helper method
Add this method to the ChallengeBloc class:

```dart
List<Challenge> _getPendingChallenges(
  List<Challenge> challenges,
  DailyProgress progress,
) {
  return challenges.where((challenge) {
    final isCompleted = progress.challengeCompletions[challenge.id] ?? false;
    return !isCompleted;
  }).toList();
}
```

### 3.5: Update ResetChallenge handler
Find the `_onResetChallenge` method and add at the beginning:

```dart
Future<void> _onResetChallenge(
  ResetChallenge event,
  Emitter<ChallengeState> emit,
) async {
  if (state is! ChallengeLoaded) return;
  
  final currentState = state as ChallengeLoaded;
  
  // NEW: Cancel all notifications on reset
  await _smartNotifications.cancelAllRemindersForDate(DateTime.now());
  
  // Only reset if it's a hard mode session
  if (currentState.activeSession!.mode == ResetMode.hard) {
    // ... existing reset code ...
  } else {
    // Soft mode: track but don't reset
    // Just emit current state with failure tracked
  }
}
```

### 3.6: Update StartNewSession handler
Find the `_onStartNewSession` method and add:

```dart
Future<void> _onStartNewSession(
  StartNewSession event,
  Emitter<ChallengeState> emit,
) async {
  // ... existing session creation code ...
  
  // NEW: Schedule initial reminders
  await _smartNotifications.scheduleSmartReminders(
    DateTime.now(),
    event.challenges,
    null, // No progress yet
  );
  
  // ... rest of existing code ...
}
```

---

## Step 4: Update BLoC Provider (5 minutes)

**File:** `lib/main.dart`

Find where you create the BLoC provider and update it:

```dart
BlocProvider(
  create: (context) => ChallengeBloc(
    repository: DatabaseRepository(),
    smartNotifications: smartNotifications,
    backgroundService: backgroundService,
  )..add(LoadChallengeData()),
),
```

---

## Step 5: Test the Changes (15 minutes)

### 5.1: Run the app
```bash
flutter run
```

### 5.2: Test scenarios

#### Test 1: Pending Task Reminder
1. Create a new challenge with a reminder in 2 minutes
2. Don't complete it
3. Wait for reminder
4. ✅ Should receive notification

#### Test 2: Completed Task (No Reminder)
1. Create a challenge with a reminder
2. Complete it immediately
3. Wait for reminder time
4. ✅ Should NOT receive notification

#### Test 3: No Midnight Notifications
1. Create a challenge with reminder at 12:00 AM
2. ✅ Should NOT schedule (blocked by time window)

#### Test 4: Time Window
1. Create a challenge with hourly reminders
2. Set time window: 8 AM - 8 PM
3. ✅ Should only get reminders between 8 AM - 8 PM

#### Test 5: Night Summary
1. Have pending tasks at 10 PM
2. ✅ Should receive summary notification

---

## Step 6: Fix Common Issues

### Issue: "Cannot find SmartNotificationService"
**Solution:** Make sure the file exists at:
`lib/services/smart_notification_service.dart`

### Issue: "Hive adapter error"
**Solution:** Regenerate adapters:
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Issue: "Notification not showing"
**Solution:** Check permissions in AndroidManifest.xml:
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### Issue: "Background service not working"
**Solution:** Add to AndroidManifest.xml:
```xml
<service
    android:name="be.tramckrijte.workmanager.BackgroundWorker"
    android:exported="false" />
```

---

## Step 7: Update Onboarding Screen (Optional - 20 minutes)

**File:** `lib/screens/onboarding_screen.dart`

Add task type selector when creating challenges:

```dart
// Add this to your challenge creation form
DropdownButton<String>(
  value: _selectedTaskType,
  items: const [
    DropdownMenuItem(value: 'hard', child: Text('Hard (Resets on miss)')),
    DropdownMenuItem(value: 'soft', child: Text('Soft (Tracks only)')),
    DropdownMenuItem(value: 'regular', child: Text('Regular (Optional)')),
  ],
  onChanged: (value) {
    setState(() => _selectedTaskType = value!);
  },
)

// Add reminder type selector
DropdownButton<String>(
  value: _selectedReminderType,
  items: const [
    DropdownMenuItem(value: 'once', child: Text('Once per day')),
    DropdownMenuItem(value: 'hourly', child: Text('Every hour')),
    DropdownMenuItem(value: 'custom', child: Text('Custom interval')),
  ],
  onChanged: (value) {
    setState(() => _selectedReminderType = value!);
  },
)

// Add time window pickers
Row(
  children: [
    Text('Reminders from:'),
    DropdownButton<int>(
      value: _startHour,
      items: List.generate(24, (i) => DropdownMenuItem(
        value: i,
        child: Text('${i.toString().padLeft(2, '0')}:00'),
      )),
      onChanged: (value) => setState(() => _startHour = value!),
    ),
    Text('to:'),
    DropdownButton<int>(
      value: _endHour,
      items: List.generate(24, (i) => DropdownMenuItem(
        value: i,
        child: Text('${i.toString().padLeft(2, '0')}:00'),
      )),
      onChanged: (value) => setState(() => _endHour = value!),
    ),
  ],
)

// Add night reminder toggle
SwitchListTile(
  title: Text('Allow night reminders (10-11:45 PM)'),
  value: _allowNightReminders,
  onChanged: (value) => setState(() => _allowNightReminders = value),
)
```

Then update the Challenge creation:

```dart
Challenge(
  id: uuid.v4(),
  title: _titleController.text,
  taskType: _selectedTaskType,
  reminderType: _selectedReminderType,
  reminderStartHour: _startHour,
  reminderEndHour: _endHour,
  allowNightReminders: _allowNightReminders,
  isReminderEnabled: true,
  // ... other fields
)
```

---

## Step 8: Verify Everything Works

### Checklist
- [ ] App builds without errors
- [ ] Notifications only show for pending tasks
- [ ] Notifications stop when task is completed
- [ ] No notifications at midnight
- [ ] Time window is respected
- [ ] Night summary works at 10 PM
- [ ] Background service resets challenge when day is missed
- [ ] App works offline

---

## Next Steps After This

Once the smart notification system is working:

1. **Add Photo Capture** (Phase 3)
   - Update daily_task_card.dart
   - Add camera button
   - Store photos in DailyProgress

2. **Create Regular Tasks Screen** (Phase 3)
   - New screen for regular tasks
   - Skip functionality
   - Progress tracking

3. **Add Profile Screen** (Phase 3)
   - User stats
   - Settings
   - Sync status

4. **Firebase Integration** (Phase 4)
   - Cloud sync
   - Photo storage
   - Cross-device support

---

## Estimated Time

- **Step 1-2:** 15 minutes
- **Step 3-4:** 35 minutes
- **Step 5:** 15 minutes
- **Step 6:** As needed
- **Step 7:** 20 minutes (optional)
- **Step 8:** 10 minutes

**Total:** ~1.5 hours for core functionality

---

## Success Criteria

You'll know it's working when:
1. ✅ You only get reminders for tasks you haven't completed
2. ✅ Reminders stop immediately when you complete a task
3. ✅ No notifications wake you up at midnight
4. ✅ Reminders only come during your specified time window
5. ✅ You get a helpful summary at 10 PM of pending tasks
6. ✅ Challenge auto-resets if you miss a day (even when app is closed)

---

## Need Help?

If you get stuck on any step:
1. Check the error message
2. Look at the "Fix Common Issues" section
3. Verify all files are in the correct location
4. Make sure dependencies are installed
5. Try `flutter clean && flutter pub get`

---

**Ready to start?** Begin with Step 1! 🚀

**Estimated completion:** 1-2 hours
**Difficulty:** Medium
**Impact:** High (fixes all major notification issues)
