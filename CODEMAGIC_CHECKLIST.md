# Codemagic Quick Start Checklist

## ✅ Pre-Setup (You've Already Done)
- [x] Created Codemagic account
- [x] Created Google Play service account JSON
- [x] Have upload keystore file (`upload-keystore.jks`)

---

## 🚀 Setup Steps (Do These Now)

### 1. Encode Service Account JSON
```bash
# Run this command with your service account JSON file
./encode_service_account.sh path/to/your-service-account.json

# This will create: service-account-base64.txt
```

### 2. Add to Codemagic Environment Variables
- Go to: https://codemagic.io/apps
- Select your app → **Environment variables**
- Click **Add variable**
- Add:
  - **Variable name**: `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`
  - **Variable value**: (paste content from `service-account-base64.txt`)
  - **Group**: `google_play`
  - **Secure**: ✅ Check this box
- Click **Add**

### 3. Upload Keystore to Codemagic
- Go to: **Code signing identities** → **Android**
- Click **Upload keystore**
- Fill in:
  - **Keystore file**: Upload `upload-keystore.jks`
  - **Keystore password**: Your keystore password
  - **Key alias**: `upload` (or your alias)
  - **Key password**: Your key password
  - **Reference name**: `keystore_reference`
- Click **Save**

### 4. Update Email in Workflow
Edit `codemagic.yaml` line 50:
```yaml
recipients:
  - your-email@example.com  # ← Change this to your actual email
```

### 5. Commit and Push Workflow
```bash
git add codemagic.yaml CODEMAGIC_SETUP.md CODEMAGIC_CHECKLIST.md encode_service_account.sh
git commit -m "Add Codemagic CI/CD workflow for Play Store deployment"
git push origin main
```

### 6. Enable codemagic.yaml in Dashboard
- Go to Codemagic app settings
- Switch to **codemagic.yaml** mode (not Flutter workflow editor)
- Save settings

### 7. Test with a Tag
```bash
# Create a test tag
git tag v1.0.2

# Push the tag
git push origin v1.0.2

# Watch the build at: https://codemagic.io/apps
```

---

## 📋 Verification Checklist

After pushing the tag, verify:

- [ ] Build starts automatically in Codemagic dashboard
- [ ] Build completes successfully (green checkmark)
- [ ] AAB file is generated in artifacts
- [ ] Draft release appears in Play Console → Internal Testing
- [ ] You receive success email notification

---

## 🎯 Quick Commands Reference

```bash
# Create and push a new release
git tag v1.0.3
git push origin v1.0.3

# Check current tags
git tag -l

# Delete a tag (if you made a mistake)
git tag -d v1.0.3
git push origin :refs/tags/v1.0.3
```

---

## 🆘 Common Issues

### "Keystore not found"
→ Check reference name is exactly: `keystore_reference`

### "Google Play API error"
→ Verify service account has "Release Manager" role in Play Console

### "Build not triggered"
→ Ensure tag format is `v*.*.*` (e.g., v1.0.2)

### "Invalid credentials"
→ Re-encode service account JSON and update environment variable

---

## 📞 Need Help?

1. Check build logs in Codemagic dashboard
2. Review `CODEMAGIC_SETUP.md` for detailed instructions
3. Verify all steps in this checklist are completed

---

**Ready? Let's deploy! 🚀**
