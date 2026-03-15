# Firebase Setup Guide

## Overview
This app now includes Firebase Analytics and Crashlytics for tracking user behavior and monitoring app stability.

## Features Implemented

### 1. Auto-Reset on Missed Days ✅
- **App Lifecycle Check**: When app opens/resumes, checks if previous days were completed
- **Midnight Timer**: Background timer checks at midnight for incomplete days
- **Auto-Reset**: Automatically resets challenge if any day is missed

### 2. Daily Pending Task Notification ✅
- **10 PM Notification**: Daily reminder at 10 PM to complete pending tasks
- **Local Time Based**: Uses device local time zone
- **Persistent**: Scheduled daily, repeats automatically

### 3. Firebase Analytics & Crashlytics ✅
- **Analytics Events**:
  - `session_start`: When user starts new challenge
  - `session_complete`: When user completes 75 days
  - `session_reset`: When challenge is reset/failed
  - `task_complete`: When individual task is completed
  - `reminder_set`: When user sets a reminder
  - `app_open`: When app is opened

- **Crashlytics**: Automatic crash reporting with stack traces

## Setup Instructions

### Step 1: Install Firebase CLI
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```

### Step 3: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `75-hard-tracker`
4. Enable Google Analytics (recommended)
5. Create project

### Step 4: Add Android App
1. In Firebase Console, click "Add app" → Android
2. Package name: `com.yourcompany.seventyfivehardtracker` (from `android/app/build.gradle`)
3. Download `google-services.json`
4. Place in `android/app/` directory

### Step 5: Add iOS App (if needed)
1. In Firebase Console, click "Add app" → iOS
2. Bundle ID: `com.yourcompany.seventyfivehardtracker`
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/` directory

### Step 6: Configure FlutterFire
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your Flutter app
flutterfire configure
```

This will:
- Auto-detect your Firebase projects
- Generate `lib/firebase_options.dart` with your credentials
- Configure both Android and iOS

### Step 7: Update Android build.gradle

Add to `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
        classpath 'com.google.firebase:firebase-crashlytics-gradle:2.9.9'
    }
}
```

Add to `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
apply plugin: 'com.google.firebase.crashlytics'
```

### Step 8: Enable Crashlytics in Firebase Console
1. Go to Firebase Console → Crashlytics
2. Click "Enable Crashlytics"
3. Wait for first crash report (or force one for testing)

### Step 9: Test Installation
```bash
flutter pub get
flutter run
```

## Analytics Dashboard

### View Analytics
1. Firebase Console → Analytics → Dashboard
2. See real-time users, events, and user properties

### View Crashlytics
1. Firebase Console → Crashlytics
2. See crash reports, stack traces, and affected users

## Testing

### Test Analytics
```dart
// Events are automatically logged when:
// - User starts a session
// - User completes a task
// - User sets a reminder
// - Challenge is completed/reset
```

### Test Crashlytics
```dart
// Force a crash for testing:
FirebaseCrashlytics.instance.crash();
```

### Test Missed Day Detection
1. Start a new challenge
2. Complete some tasks (but not all)
3. Close the app
4. Change device date to 2 days later
5. Open app → Should auto-reset

### Test Pending Task Notification
1. Start a challenge
2. Wait until 10 PM (or change device time)
3. Should receive notification about pending tasks

## Privacy Considerations

### Data Collected
- Anonymous user ID
- App usage events (session start/end, task completion)
- Crash reports with stack traces
- Device information (OS version, model)

### GDPR Compliance
- No personal information collected
- Users can opt-out via device settings
- Data is anonymized

### Update Privacy Policy
Add to your privacy policy:
```
We use Firebase Analytics and Crashlytics to improve app performance 
and user experience. This includes anonymous usage data and crash reports. 
No personal information is collected.
```

## Monitoring

### Key Metrics to Track
1. **Daily Active Users (DAU)**
2. **Session Start Rate**
3. **Session Completion Rate** (75-day completion)
4. **Average Days Before Reset**
5. **Crash-Free Users %**
6. **Most Completed Tasks**
7. **Reminder Usage Rate**

### Set Up Alerts
1. Firebase Console → Analytics → Custom Events
2. Create alerts for:
   - Crash rate > 1%
   - Session completion rate drops
   - Daily active users drops

## Troubleshooting

### Firebase not initializing
- Check `google-services.json` is in `android/app/`
- Run `flutterfire configure` again
- Clean build: `flutter clean && flutter pub get`

### Analytics not showing data
- Wait 24 hours for first data
- Check DebugView in Firebase Console
- Enable debug mode: `adb shell setprop debug.firebase.analytics.app com.yourcompany.seventyfivehardtracker`

### Crashlytics not receiving crashes
- Ensure Crashlytics is enabled in Firebase Console
- Check `build.gradle` has crashlytics plugin
- Force a test crash

## Cost Estimation

### Free Tier Limits
- **Analytics**: Unlimited events
- **Crashlytics**: Unlimited crash reports
- **Storage**: 1 GB

### Expected Usage
For 10,000 monthly active users:
- Analytics: FREE (within limits)
- Crashlytics: FREE (within limits)
- Total: **$0/month**

Firebase is free for most apps. Only pay if you exceed generous limits.

## Next Steps

1. ✅ Run `flutterfire configure`
2. ✅ Test on real device
3. ✅ Monitor Firebase Console for 24 hours
4. ✅ Set up alerts for crashes
5. ✅ Update privacy policy
6. ✅ Submit to Play Store/App Store

## Support

- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Console](https://console.firebase.google.com/)
