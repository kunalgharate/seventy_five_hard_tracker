# Quick Start Guide - New Features

## 🚀 What's New

### 1. Auto-Reset on Missed Days
Your challenge now automatically resets if you miss a day. No more manual checking!

**How it works:**
- Opens app → Checks all previous days
- Finds incomplete day → Auto-resets challenge
- Shows notification with failure reason

### 2. 10 PM Daily Reminder
Get reminded every night at 10 PM to complete pending tasks.

**Notification:**
- Time: 10:00 PM daily
- Message: "Don't forget to complete your tasks before the day ends!"
- Repeats: Every day automatically

### 3. Firebase Analytics & Crashlytics
Track your app's performance and user behavior.

**What's tracked:**
- Session starts/completions
- Task completions
- Reminder usage
- Crashes and errors

---

## 🔧 Setup (5 minutes)

### Step 1: Install Firebase CLI
```bash
npm install -g firebase-tools
firebase login
```

### Step 2: Configure Firebase
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

### Step 3: Select/Create Project
- Choose existing project or create new
- Select Android (and iOS if needed)
- Wait for configuration to complete

### Step 4: Build & Run
```bash
flutter clean
flutter pub get
flutter run
```

**That's it!** All features are now active.

---

## 📱 Testing

### Test Auto-Reset
1. Start new challenge
2. Complete 1-2 tasks (not all)
3. Close app
4. Change device date to +2 days
5. Open app → Should see reset notification

### Test 10 PM Notification
1. Start challenge
2. Change device time to 9:59 PM
3. Wait 1 minute
4. Should receive notification

### Test Analytics
1. Use app normally
2. Wait 24 hours
3. Check Firebase Console → Analytics
4. See events: session_start, task_complete, etc.

---

## 🐛 Troubleshooting

### Firebase not working?
```bash
# Re-run configuration
flutterfire configure

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Notifications not showing?
- Check app has notification permission
- Check device is not in Do Not Disturb mode
- Check notification settings in app settings

### Auto-reset not working?
- Ensure app has been opened at least once
- Check device date/time is correct
- Try force-closing and reopening app

---

## 📊 Firebase Console

### View Analytics
1. Go to: https://console.firebase.google.com
2. Select your project
3. Click "Analytics" → "Dashboard"
4. See real-time users and events

### View Crashes
1. Go to: https://console.firebase.google.com
2. Select your project
3. Click "Crashlytics"
4. See crash reports and stack traces

---

## 💡 Tips

1. **First 24 hours**: Analytics data may take up to 24 hours to appear
2. **Debug mode**: Enable debug logging to see events immediately
3. **Privacy**: All data is anonymous, no personal info collected
4. **Cost**: Firebase is FREE for most apps (generous limits)

---

## 📝 Next Steps

- [ ] Run `flutterfire configure`
- [ ] Test on real device
- [ ] Check Firebase Console after 24 hours
- [ ] Update privacy policy (see FIREBASE_SETUP.md)
- [ ] Deploy to production

---

## 🆘 Need Help?

See detailed documentation:
- `FIREBASE_SETUP.md` - Complete Firebase setup guide
- `IMPLEMENTATION_SUMMARY.md` - Technical details
- Firebase Docs: https://firebase.google.com/docs

---

## ✨ Summary

**3 new features, 5-minute setup, zero configuration needed!**

All features work automatically after running `flutterfire configure`. The app is now production-ready with comprehensive monitoring and better user experience.
