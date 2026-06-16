# Major Update Implementation Plan
## 75 Hard Tracker → Comprehensive Habit Tracker

**Date:** April 4, 2026
**Version:** 2.0.0

---

## Overview
Transform the app from a simple 75 Hard tracker to a comprehensive habit tracking system with:
- Hard/Soft/Regular task types
- Smart notification system
- Photo capture for tasks
- Firebase cloud sync with encryption
- Profile management
- Improved UX

---

## Phase 1: Data Model Updates ✅ (COMPLETED)

### 1.1 Challenge Model
- ✅ Added `TaskType` enum (hard, soft, regular)
- ✅ Added `ReminderType` enum (once, hourly, custom)
- ✅ Added notification time window (start/end hours)
- ✅ Added `allowNightReminders` flag
- ✅ Added `reminderIntervalMinutes` for custom reminders
- ✅ Added `photoRequired` flag
- ✅ Added `showInRegularTab` flag

### 1.2 ChallengeSession Model
- ✅ Added `ResetMode` enum (hard, soft)
- ✅ Added `resetMode` field
- ✅ Added `totalDaysTarget` field (flexible for soft mode)

### 1.3 DailyProgress Model
- ✅ Added `taskPhotos` map for photo storage

---

## Phase 2: Notification System Overhaul (NEXT)

### 2.1 Smart Reminder Service
**File:** `lib/services/smart_notification_service.dart`

```dart
class SmartNotificationService {
  // Only send reminders for pending tasks
  Future<void> scheduleSmartReminders(DateTime date, List<Challenge> challenges, DailyProgress? progress);
  
  // Cancel reminders for completed tasks
  Future<void> cancelCompletedTaskReminders(String challengeId);
  
  // Hourly reminders within time window
  Future<void> scheduleHourlyReminders(Challenge challenge);
  
  // Night summary (10pm-11:45pm) for pending tasks
  Future<void> scheduleNightSummary(DateTime date, List<Challenge> pendingChallenges);
  
  // Background service for offline reset detection
  Future<void> startBackgroundService();
}
```

### 2.2 Notification Fixes
- Fix notification sound (update AndroidNotificationDetails)
- Add proper notification channels
- Implement notification action buttons
- Add notification grouping

### 2.3 Background Service
**File:** `lib/services/background_check_service.dart`
- Check for missed days even when app is closed
- Auto-reset for hard mode
- Send reset notification
- Cancel all reminders on reset

---

## Phase 3: UI Updates

### 3.1 Bottom Navigation Update
**File:** `lib/screens/main_navigation_screen.dart`

```dart
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: '75 Hard'),
    BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Regular Tasks'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ],
)
```

### 3.2 Task Creation Screen Updates
**File:** `lib/screens/onboarding_screen.dart`
- Add task type selector (Hard/Soft/Regular)
- Add reminder type selector (Once/Hourly/Custom)
- Add time window picker (start/end hours)
- Add night reminder toggle
- Add photo requirement toggle
- Make reminder setup mandatory for hard tasks

### 3.3 Task Card Updates
**File:** `lib/widgets/daily_task_card.dart`
- Add photo capture button
- Show task type badge
- Display photo thumbnail if captured
- Show reminder status

### 3.4 Profile Screen (NEW)
**File:** `lib/screens/profile_screen.dart`
```dart
- User stats (total days, completion rate, streaks)
- Firebase sync status
- Data encryption indicator
- Export/Import data
- Account settings
- Productivity insights
```

### 3.5 Regular Tasks Screen (NEW)
**File:** `lib/screens/regular_tasks_screen.dart`
```dart
- List of regular tasks
- Skip functionality
- Progress analytics
- Discipline score
```

---

## Phase 4: Firebase Integration

### 4.1 Firebase Setup
**Dependencies to add:**
```yaml
cloud_firestore: ^4.15.0
firebase_auth: ^4.17.0
encrypt: ^5.0.3
```

### 4.2 Cloud Sync Service
**File:** `lib/services/firebase_sync_service.dart`

```dart
class FirebaseSyncService {
  // Encrypt and upload data
  Future<void> syncToCloud(ChallengeSession session, List<DailyProgress> progress);
  
  // Download and decrypt data
  Future<void> syncFromCloud();
  
  // Upload photos to Cloudinary
  Future<String> uploadPhoto(File photo, String challengeId, DateTime date);
  
  // Auto-sync on changes
  Stream<SyncStatus> watchSyncStatus();
}
```

### 4.3 Analytics Service Update
**File:** `lib/services/analytics_service.dart`
- Track task completion patterns
- Identify best/worst performing tasks
- Calculate discipline score
- Generate productivity insights

---

## Phase 5: App Configuration Updates

### 5.1 Update App Name
**Files to update:**
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `pubspec.yaml`

**New name:** "Habit Tracker Pro" or "75 Hard & Beyond"

### 5.2 Update Dependencies
**File:** `pubspec.yaml`
```yaml
dependencies:
  # Existing
  flutter_bloc: ^8.1.3
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_local_notifications: ^17.2.2
  
  # New
  image_picker: ^1.0.7  # Already exists
  cloud_firestore: ^4.15.0
  firebase_auth: ^4.17.0
  encrypt: ^5.0.3
  workmanager: ^0.5.2  # Background tasks
  shared_preferences: ^2.2.2
```

### 5.3 Regenerate Hive Adapters
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

---

## Phase 6: BLoC Updates

### 6.1 New Events
**File:** `lib/bloc/challenge_event.dart`
```dart
class AddTaskPhoto extends ChallengeEvent {
  final DateTime date;
  final String challengeId;
  final File photo;
}

class ToggleTaskType extends ChallengeEvent {
  final String challengeId;
  final TaskType newType;
}

class SyncWithCloud extends ChallengeEvent {}

class SkipRegularTask extends ChallengeEvent {
  final DateTime date;
  final String challengeId;
}
```

### 6.2 Update Challenge BLoC
**File:** `lib/bloc/challenge_bloc.dart`
- Handle new events
- Implement soft reset logic
- Add photo handling
- Integrate Firebase sync
- Update reset logic based on task types

---

## Phase 7: Bug Fixes

### 7.1 Notification Issues
- ✅ Only show reminders for pending tasks
- ✅ Cancel reminders when task is completed
- ✅ Don't send reminders at midnight
- ✅ Fix notification sound
- ✅ Stop notifications after reset

### 7.2 App Opening Issue
- ✅ Remove internet requirement for app launch
- ✅ Add offline mode support
- ✅ Show sync status when online

### 7.3 Reset Logic
- ✅ Implement hard reset (current behavior)
- ✅ Implement soft reset (track but don't reset)
- ✅ Only reset on hard tasks
- ✅ Cancel notifications on hard reset

---

## Phase 8: Testing & Deployment

### 8.1 Testing Checklist
- [ ] Test hard reset functionality
- [ ] Test soft reset functionality
- [ ] Test regular task tracking
- [ ] Test smart notifications
- [ ] Test photo capture and storage
- [ ] Test Firebase sync
- [ ] Test offline mode
- [ ] Test background service
- [ ] Test notification cancellation
- [ ] Test time window restrictions

### 8.2 Migration Strategy
- Create data migration script for existing users
- Preserve existing sessions
- Set default task type to 'hard' for existing challenges
- Add migration version tracking

### 8.3 Deployment
- Update version to 2.0.0
- Update Play Store listing
- Add new screenshots
- Update app description
- Create migration guide

---

## Implementation Priority

### HIGH PRIORITY (Week 1)
1. ✅ Update data models
2. Regenerate Hive adapters
3. Fix notification system
4. Implement smart reminders
5. Add background service
6. Fix app opening without internet

### MEDIUM PRIORITY (Week 2)
1. Update UI for task types
2. Add bottom navigation
3. Create regular tasks screen
4. Add photo capture
5. Update task cards

### LOW PRIORITY (Week 3)
1. Firebase integration
2. Profile screen
3. Analytics and insights
4. Data encryption
5. Cloud sync

---

## Breaking Changes

### For Existing Users
1. **Data Migration Required:** Existing challenges will be set to 'hard' type by default
2. **New Permissions:** Camera permission for photo capture
3. **Optional Firebase:** Users can choose to enable cloud sync
4. **Notification Changes:** Smarter notification system may behave differently

### Backward Compatibility
- Existing Hive data will be migrated automatically
- Old sessions will continue to work
- No data loss during migration

---

## New Features Summary

### For Users
✅ **Task Types:** Choose between Hard, Soft, and Regular tasks
✅ **Smart Notifications:** Only get reminders for pending tasks
✅ **Time Windows:** Set when you want to receive notifications
✅ **Night Summary:** Get a summary of pending tasks before bed
✅ **Photo Proof:** Capture photos for task completion
✅ **Cloud Sync:** Backup data to Firebase (encrypted)
✅ **Regular Tasks:** Track habits without the pressure of resets
✅ **Discipline Score:** See your overall consistency
✅ **Offline Mode:** App works without internet
✅ **Background Service:** Auto-reset even when app is closed

### For Developers
- Cleaner architecture with task types
- Better notification management
- Firebase integration for future features
- Encrypted cloud storage
- Background service support
- Improved state management

---

## Next Steps

1. **Run Hive code generation:**
   ```bash
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```

2. **Update dependencies:**
   ```bash
   flutter pub get
   ```

3. **Test data models:**
   - Create test challenges with new fields
   - Verify Hive storage
   - Test migration from old data

4. **Implement notification service:**
   - Start with smart reminder logic
   - Add time window checks
   - Implement night summary

5. **Update UI:**
   - Add task type selector
   - Update bottom navigation
   - Create new screens

---

## Questions to Address

1. **App Name:** What should the new app name be?
   - "Habit Tracker Pro"
   - "75 Hard & Beyond"
   - "Challenge Master"
   - Keep "75 Hard Tracker"

2. **Firebase:** Should cloud sync be:
   - Mandatory (requires account)
   - Optional (anonymous + optional account)
   - Disabled by default

3. **Regular Tasks:** Should they:
   - Have their own separate 75-day challenge
   - Be tracked indefinitely
   - Have custom duration

4. **Soft Reset:** Should it:
   - Track missed days but continue
   - Allow X missed days before reset
   - Never reset

---

## Resources Needed

### Design Assets
- [ ] New app icon (if name changes)
- [ ] Task type icons (hard/soft/regular)
- [ ] Profile screen mockup
- [ ] Regular tasks screen mockup

### Documentation
- [ ] User migration guide
- [ ] New feature tutorial
- [ ] Firebase setup guide
- [ ] Privacy policy update (for cloud sync)

### Testing
- [ ] Test devices for notification testing
- [ ] Firebase test project
- [ ] Beta testers for new features

---

## Estimated Timeline

- **Phase 1:** ✅ Completed (Data Models)
- **Phase 2:** 3-4 days (Notifications)
- **Phase 3:** 4-5 days (UI Updates)
- **Phase 4:** 5-6 days (Firebase)
- **Phase 5:** 1 day (Configuration)
- **Phase 6:** 2-3 days (BLoC Updates)
- **Phase 7:** 2-3 days (Bug Fixes)
- **Phase 8:** 3-4 days (Testing & Deployment)

**Total:** ~3-4 weeks for complete implementation

---

## Notes

- Keep existing functionality working during migration
- Add feature flags for gradual rollout
- Maintain backward compatibility
- Test thoroughly before release
- Consider beta release first
- Update documentation continuously

---

**Status:** Phase 1 Complete ✅
**Next:** Phase 2 - Notification System Overhaul
**Updated:** April 4, 2026
