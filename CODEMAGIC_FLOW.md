# Codemagic CI/CD Flow Diagram

## 🔄 Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     YOUR LOCAL MACHINE                          │
│                                                                 │
│  1. Make changes to code                                        │
│  2. Commit changes: git commit -m "New feature"                 │
│  3. Create tag: git tag v1.0.2                                  │
│  4. Push tag: git push origin v1.0.2                            │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                         GITHUB                                  │
│                                                                 │
│  • Receives tag push                                            │
│  • Triggers webhook to Codemagic                                │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CODEMAGIC                                 │
│                                                                 │
│  Step 1: Detect tag matching pattern "v*.*.*"                   │
│  Step 2: Clone repository                                       │
│  Step 3: Setup Flutter environment                              │
│  Step 4: Run flutter pub get                                    │
│  Step 5: Build AAB (flutter build appbundle)                    │
│  Step 6: Sign AAB with your keystore                            │
│  Step 7: Upload to Google Play Console                          │
│  Step 8: Send email notification                                │
│                                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   GOOGLE PLAY CONSOLE                           │
│                                                                 │
│  • Draft release created in Internal Testing track             │
│  • Ready for manual review and promotion                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Flow

```
┌──────────────────────┐
│  Service Account     │
│  JSON File           │
└──────┬───────────────┘
       │
       │ Base64 Encode
       ▼
┌──────────────────────┐
│  Base64 String       │
└──────┬───────────────┘
       │
       │ Store as Environment Variable
       ▼
┌──────────────────────┐
│  Codemagic           │
│  (Encrypted Storage) │
└──────┬───────────────┘
       │
       │ Used during build
       ▼
┌──────────────────────┐
│  Google Play API     │
│  Authentication      │
└──────────────────────┘
```

---

## 📦 Build Artifacts Flow

```
Source Code
    │
    ▼
Flutter Build
    │
    ├─► build/app/outputs/bundle/release/app-release.aab
    │   (Signed Android App Bundle)
    │
    ├─► build/app/outputs/mapping/release/mapping.txt
    │   (ProGuard mapping for crash reports)
    │
    └─► Uploaded to Play Console
```

---

## 🏷️ Version Management

```
Tag Format: v1.0.2
            │ │ │
            │ │ └─► Patch (bug fixes)
            │ └───► Minor (new features)
            └─────► Major (breaking changes)

Codemagic Auto-Increment:
    Build Name: 1.0.{BUILD_NUMBER}
    Build Number: {AUTO_INCREMENT}

Example:
    Tag: v1.0.2
    Build #1: 1.0.1 (1)
    Build #2: 1.0.2 (2)
    Build #3: 1.0.3 (3)
```

---

## 🎯 Deployment Tracks

```
Internal Testing (Default)
    │
    │ Manual Promotion
    ▼
Alpha Testing
    │
    │ Manual Promotion
    ▼
Beta Testing
    │
    │ Manual Promotion
    ▼
Production
```

---

## ⚙️ Workflow Trigger Logic

```
Git Push Event
    │
    ├─► Regular commit? → No build
    │
    ├─► Branch push? → No build
    │
    └─► Tag push?
            │
            ├─► Matches "v*.*.*"? → ✅ Build starts
            │
            └─► Doesn't match? → No build
```

---

## 📧 Notification Flow

```
Build Starts
    │
    ▼
Build Running...
    │
    ├─► Success
    │       │
    │       ├─► Email: "Build successful"
    │       ├─► AAB uploaded to Play Console
    │       └─► Draft release created
    │
    └─► Failure
            │
            ├─► Email: "Build failed"
            └─► Error logs attached
```

---

## 🔄 Complete Release Cycle

```
Day 1: Development
    ├─► Write code
    ├─► Test locally
    └─► Commit changes

Day 2: Testing
    ├─► Final testing
    ├─► Update version in pubspec.yaml
    └─► Commit version bump

Day 3: Release
    ├─► Create tag: git tag v1.0.2
    ├─► Push tag: git push origin v1.0.2
    ├─► Codemagic builds automatically
    ├─► Review draft in Play Console
    ├─► Promote to Internal Testing
    ├─► Test on real devices
    └─► Promote to Production

Day 4: Monitor
    ├─► Check crash reports
    ├─► Monitor user feedback
    └─► Plan next release
```

---

## 🛠️ Troubleshooting Decision Tree

```
Build Failed?
    │
    ├─► Keystore Error?
    │       └─► Re-upload keystore with correct reference name
    │
    ├─► Google Play API Error?
    │       └─► Check service account permissions
    │
    ├─► Flutter Build Error?
    │       └─► Test locally: flutter build appbundle
    │
    └─► Other Error?
            └─► Check Codemagic build logs
```

---

## 📊 Environment Variables Structure

```
Codemagic Dashboard
    │
    └─► Environment Variables
            │
            ├─► Group: google_play
            │       │
            │       └─► GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
            │           (Base64 encoded JSON)
            │
            └─► Code Signing
                    │
                    └─► keystore_reference
                        ├─► Keystore file
                        ├─► Keystore password
                        ├─► Key alias
                        └─► Key password
```

---

This visual guide should help you understand the entire CI/CD pipeline! 🚀
