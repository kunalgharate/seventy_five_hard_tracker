# Codemagic Deployment Guide - Version 1.0.3+4

**Date**: March 12, 2026  
**Current Branch**: release  
**Trigger Method**: Git Tag

---

## 🎯 How Codemagic Works

Your Codemagic is configured to trigger on **Git tags** (not branch pushes).

**Trigger Pattern**: `v*.*.*` (e.g., v1.0.3, v1.0.4)

When you create and push a tag like `v1.0.3`, Codemagic will:
1. Automatically detect the tag
2. Start the build process
3. Build the AAB
4. Upload to Play Store (production track)
5. Send email notification

---

## 🚀 Step-by-Step Deployment

### Step 1: Commit All Changes
```bash
# Add all new files
git add .

# Commit with message
git commit -m "Release v1.0.3 - Grace period, notifications, privacy policy, data export"
```

### Step 2: Create Git Tag
```bash
# Create tag for version 1.0.3
git tag -a v1.0.3 -m "Release v1.0.3
- Grace period (2-hour window after midnight)
- Warning notifications (9 PM + 10 PM)
- Privacy policy screen
- Data export functionality
- UI fixes (bottom sheet backgrounds)
- Firebase Analytics & Crashlytics verified"
```

### Step 3: Push to Remote
```bash
# Push the release branch
git push origin release

# Push the tag (this triggers Codemagic)
git push origin v1.0.3
```

### Step 4: Monitor Build
1. Go to Codemagic: https://codemagic.io
2. Login with your account
3. Select project: 75 Hard Challenge
4. Watch the build progress

---

## 📋 Quick Commands (Copy-Paste)

```bash
# 1. Commit everything
git add .
git commit -m "Release v1.0.3 - New features and improvements"

# 2. Create and push tag
git tag -a v1.0.3 -m "Release v1.0.3"
git push origin release
git push origin v1.0.3

# 3. Check tags
git tag -l
```

---

## ⚙️ Codemagic Configuration Summary

### Trigger
- **Event**: Tag push
- **Pattern**: `v*.*.*`
- **Branch**: Any (triggered by tag, not branch)

### Build Process
1. Set up keystore (from environment variable)
2. Configure signing
3. Get Flutter packages
4. Build AAB with release signing
5. Upload to Play Store

### Environment Variables Required
These should already be set in Codemagic:
- `CM_KEYSTORE` - Base64 encoded keystore
- `CM_KEYSTORE_PASSWORD` - Keystore password
- `CM_KEY_PASSWORD` - Key password
- `CM_KEY_ALIAS` - Key alias (upload)
- `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` - Play Store credentials

### Publishing
- **Track**: Production
- **Submit as draft**: No (goes live after review)
- **Email**: kunalgharate@gmail.com

---

## 🔍 Verify Before Pushing

### Check Current Status
```bash
# Check branch
git branch
# Should show: * release

# Check status
git status

# Check existing tags
git tag -l
```

### Verify Files Changed
Key files that should be updated:
- ✅ `pubspec.yaml` - Version 1.0.3+4
- ✅ `lib/screens/settings_screen.dart` - Version display
- ✅ `lib/services/daily_check_service.dart` - Grace period + notifications
- ✅ `lib/screens/privacy_policy_screen.dart` - New file
- ✅ `lib/models/*.dart` - toJson() methods

---

## 📊 What Happens After Push

### Codemagic Build (Automatic)
1. **Trigger**: Detects tag `v1.0.3`
2. **Build**: ~8-10 minutes
3. **Upload**: Automatic to Play Store
4. **Email**: Success/failure notification

### Play Store (Manual Review)
1. **Review**: 1-3 days
2. **Status**: Check Play Console
3. **Release**: Automatic after approval

---

## 🎯 Alternative: Manual Trigger

If you prefer to trigger manually instead of using tags:

### Option 1: Codemagic Web UI
1. Go to Codemagic dashboard
2. Select your app
3. Click "Start new build"
4. Select branch: release
5. Click "Start build"

### Option 2: Update Workflow (Change Trigger)
Edit `codemagic.yaml`:
```yaml
triggering:
  events:
    - push
  branch_patterns:
    - pattern: 'release'
      include: true
```

---

## 📧 Email Notification

You'll receive an email at `kunalgharate@gmail.com` with:
- Build status (success/failure)
- Build logs
- Download link for AAB
- Play Store upload status

---

## 🔧 Troubleshooting

### If Build Fails

**Check Environment Variables**:
1. Go to Codemagic → App settings → Environment variables
2. Verify all variables are set:
   - CM_KEYSTORE
   - CM_KEYSTORE_PASSWORD
   - CM_KEY_PASSWORD
   - CM_KEY_ALIAS
   - GCLOUD_SERVICE_ACCOUNT_CREDENTIALS

**Check Build Logs**:
1. Codemagic dashboard → Build history
2. Click on failed build
3. Check logs for errors

**Common Issues**:
- Missing environment variables
- Keystore password incorrect
- Play Store credentials expired
- Build timeout (increase max_build_duration)

---

## 📱 After Successful Build

### 1. Check Play Console
1. Go to: https://play.google.com/console
2. Select: 75 Hard Challenge
3. Navigate to: Production → Releases
4. Verify: New version uploaded

### 2. Monitor Release
- Check review status
- Monitor crash reports
- Check user feedback
- Track analytics

### 3. Test on Device
Download from Play Store (internal testing track) or use the AAB from Codemagic artifacts.

---

## 🎉 Summary

**To Deploy Version 1.0.3**:

```bash
# 1. Commit changes
git add .
git commit -m "Release v1.0.3"

# 2. Create and push tag
git tag -a v1.0.3 -m "Release v1.0.3"
git push origin release
git push origin v1.0.3

# 3. Wait for Codemagic to build and deploy
# 4. Check email for build status
# 5. Monitor Play Console for review status
```

**That's it!** Codemagic handles everything else automatically. 🚀

---

## 📞 Quick Reference

**Codemagic Dashboard**: https://codemagic.io  
**Play Console**: https://play.google.com/console  
**Firebase Console**: https://console.firebase.google.com/project/dailymettle  

**Current Version**: 1.0.3+4  
**Previous Version**: 1.0.2+3  
**Tag to Create**: v1.0.3  

---

**Ready to deploy?** Just run the commands above! 🎯
