# Codemagic CI/CD Setup Guide

## Overview
This guide will help you set up automatic Play Store deployment when you push a new tag to GitHub.

## Prerequisites Checklist
✅ Codemagic account created
✅ Google Play Console service account JSON created
✅ Upload keystore file (`upload-keystore.jks`)
✅ GitHub repository connected to Codemagic

---

## Step 1: Encode Service Account JSON to Base64

You mentioned you have the service account JSON. Let's encode it:

### On macOS/Linux:
```bash
base64 -i path/to/your-service-account.json -o service-account-base64.txt
```

### Alternative (if file is in current directory):
```bash
cat your-service-account.json | base64 > service-account-base64.txt
```

The output file `service-account-base64.txt` will contain the base64-encoded string you need.

---

## Step 2: Configure Codemagic Environment Variables

Go to Codemagic Dashboard → Your App → Environment variables

### Add these variables:

1. **GCLOUD_SERVICE_ACCOUNT_CREDENTIALS**
   - Value: Paste the entire base64 string from Step 1
   - Group: `google_play`
   - Secure: ✅ Yes

---

## Step 3: Upload Android Keystore to Codemagic

1. Go to Codemagic Dashboard → Your App → Code signing identities
2. Click on **Android** tab
3. Upload your keystore:
   - **Keystore file**: Upload `upload-keystore.jks`
   - **Keystore password**: Enter your keystore password
   - **Key alias**: Enter your key alias (usually `upload`)
   - **Key password**: Enter your key password
   - **Reference name**: `keystore_reference` (must match workflow)

---

## Step 4: Connect GitHub Repository

1. Go to Codemagic Dashboard
2. Click **Add application**
3. Select **GitHub** as source
4. Authorize Codemagic to access your repositories
5. Select: `kunalgharate/seventy_five_hard_tracker`
6. Choose **Flutter App** as project type
7. Click **Finish**

---

## Step 5: Enable Workflow

1. In your app settings, go to **Workflow editor**
2. Switch to **codemagic.yaml** mode (not Flutter workflow editor)
3. The workflow file is already created in your repository
4. Save and commit the `codemagic.yaml` file to your repo

---

## Step 6: Update Email Notification

Edit `codemagic.yaml` and replace the email:

```yaml
email:
  recipients:
    - your-actual-email@example.com  # Change this!
```

---

## Step 7: Test the Workflow

### Create and push a tag:

```bash
# Make sure you're on the main/master branch
git checkout main

# Create a tag (version format: v1.0.2, v1.0.3, etc.)
git tag v1.0.2

# Push the tag to GitHub
git push origin v1.0.2
```

This will automatically trigger the Codemagic build!

---

## How It Works

### Trigger Mechanism
- **Event**: Tag push to GitHub
- **Pattern**: Tags matching `v*.*.*` (e.g., v1.0.1, v1.0.2, v2.0.0)
- **Action**: Automatically builds and deploys to Play Store

### Build Process
1. Codemagic detects new tag
2. Checks out code
3. Sets up Flutter environment
4. Builds Android App Bundle (AAB)
5. Signs the AAB with your keystore
6. Uploads to Play Store Internal Testing track
7. Submits as draft (you can promote manually)

### Version Management
- Build name: `1.0.$BUILD_NUMBER` (auto-incremented)
- Build number: Auto-incremented by Codemagic

---

## Workflow Configuration Explained

```yaml
triggering:
  events:
    - tag                    # Trigger on tag push
  tag_patterns:
    - pattern: 'v*.*.*'      # Match tags like v1.0.1
      include: true
```

```yaml
environment:
  android_signing:
    - keystore_reference     # References your uploaded keystore
  groups:
    - google_play            # Contains GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
```

```yaml
publishing:
  google_play:
    credentials: $GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
    track: internal          # Deploys to Internal Testing
    submit_as_draft: true    # Creates draft release (safe!)
```

---

## Deployment Tracks

You can change the deployment track in `codemagic.yaml`:

- `internal` - Internal testing (default, safest)
- `alpha` - Closed testing
- `beta` - Open testing
- `production` - Production release

---

## Troubleshooting

### Build Fails: "Keystore not found"
- Verify keystore reference name matches: `keystore_reference`
- Re-upload keystore in Codemagic dashboard

### Build Fails: "Google Play API error"
- Check service account JSON is correctly base64 encoded
- Verify service account has "Release Manager" role in Play Console
- Ensure app is already created in Play Console

### Build Fails: "Flutter packages error"
- Check `pubspec.yaml` dependencies are valid
- Try running `flutter pub get` locally first

### Tag doesn't trigger build
- Verify tag pattern matches `v*.*.*` format
- Check Codemagic webhook is configured in GitHub
- Go to GitHub repo → Settings → Webhooks

---

## Best Practices

### Version Tagging Strategy
```bash
# Bug fixes: v1.0.1 → v1.0.2
git tag v1.0.2

# New features: v1.0.2 → v1.1.0
git tag v1.1.0

# Major changes: v1.1.0 → v2.0.0
git tag v2.0.0
```

### Before Creating a Tag
1. Test the app thoroughly locally
2. Update version in `pubspec.yaml` if needed
3. Commit all changes
4. Create and push tag
5. Monitor Codemagic build

### Release Process
1. Push tag → Automatic build
2. Build succeeds → Draft created in Play Console
3. Review draft in Play Console
4. Promote to desired track (internal → alpha → beta → production)

---

## Monitoring Builds

### Codemagic Dashboard
- View real-time build logs
- Download artifacts (AAB files)
- Check build duration and status

### Email Notifications
- Success: Build completed and uploaded
- Failure: Build failed with error logs

---

## Security Notes

- ✅ Service account JSON is stored as encrypted environment variable
- ✅ Keystore is securely stored in Codemagic
- ✅ Credentials never exposed in logs
- ✅ Draft submission prevents accidental production releases

---

## Next Steps After First Successful Build

1. Check Play Console → Internal Testing
2. Verify the draft release is created
3. Review release notes (add them in Play Console)
4. Promote to desired track
5. Test the release thoroughly

---

## Quick Reference Commands

```bash
# Create and push a new release tag
git tag v1.0.3
git push origin v1.0.3

# List all tags
git tag -l

# Delete a tag (if needed)
git tag -d v1.0.3
git push origin :refs/tags/v1.0.3

# View tag details
git show v1.0.3
```

---

## Support

If you encounter issues:
1. Check Codemagic build logs
2. Verify all environment variables are set
3. Ensure service account has correct permissions
4. Review this guide step-by-step

---

**You're all set! 🚀**

Push your first tag and watch the magic happen!
