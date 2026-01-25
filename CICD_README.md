# 🚀 Automated Play Store Deployment

This repository is configured with **Codemagic CI/CD** for automatic Play Store deployment.

## How It Works

Push a tag → Automatic build → Deploy to Play Store

```bash
git tag v1.0.2
git push origin v1.0.2
```

That's it! Codemagic handles the rest.

---

## 📚 Documentation

- **[Quick Start Checklist](CODEMAGIC_CHECKLIST.md)** - Step-by-step setup guide
- **[Complete Setup Guide](CODEMAGIC_SETUP.md)** - Detailed instructions
- **[Flow Diagram](CODEMAGIC_FLOW.md)** - Visual representation of the CI/CD pipeline

---

## 🔧 Setup Required (First Time Only)

1. **Encode service account JSON**:
   ```bash
   ./encode_service_account.sh path/to/service-account.json
   ```

2. **Add to Codemagic**:
   - Environment variable: `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`
   - Upload keystore: `keystore_reference`

3. **Update email** in `codemagic.yaml`

4. **Push a tag** to test

See [CODEMAGIC_CHECKLIST.md](CODEMAGIC_CHECKLIST.md) for complete steps.

---

## 🏷️ Tag Format

Use semantic versioning:

- `v1.0.1` - Patch (bug fixes)
- `v1.1.0` - Minor (new features)
- `v2.0.0` - Major (breaking changes)

---

## 📦 What Gets Deployed

- **Track**: Internal Testing (draft)
- **Format**: Android App Bundle (AAB)
- **Signed**: Yes (with your keystore)
- **Auto-increment**: Build number

---

## 🔐 Security

- ✅ All credentials encrypted
- ✅ No secrets in repository
- ✅ Draft releases (manual promotion required)

---

## 📧 Notifications

You'll receive emails for:
- ✅ Successful builds
- ❌ Failed builds

---

## 🆘 Troubleshooting

Check the documentation files above or view build logs at:
https://codemagic.io/apps

---

**Happy Deploying! 🎉**
