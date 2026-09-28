# DailyMettle — iOS App Store Publishing Guide

App: **DailyMettle: Habit & Challenge**
Bundle ID: `com.seventyfive.hard.challenge`
Apple Team ID: `XJ2WNZKCMT`
Firebase project: `dailymettle`
Current version: `1.0.7 (build 7)`

This guide takes you from the current state (app builds & runs on device, login works)
through TestFlight testing and full App Store submission.

---

## PART 0 — What's already done (code/config side)

These are complete in the project — you do NOT need to redo them:

- [x] iOS bundle ID set to `com.seventyfive.hard.challenge` (matches Android)
- [x] Firebase iOS app wired (`GoogleService-Info.plist`, `firebase_options.dart`, `firebase.json` all aligned)
- [x] Google Sign-In configured (`GIDClientID` + URL scheme in Info.plist)
- [x] Required permission strings in Info.plist (camera, photo library)
- [x] `ITSAppUsesNonExemptEncryption = false` (skips export-compliance prompt)
- [x] Apple privacy manifest `PrivacyInfo.xcprivacy`
- [x] Push notifications entitlement (`Runner.entitlements` with `aps-environment = production`)
- [x] `connectivity_plus` upgraded to v7 (fixed the iOS 26 launch crash)
- [x] In-app Privacy Policy + Terms & Conditions screens
- [x] App icon (1024, no alpha) and signing team set
- [x] Release build verified (`flutter build ios --release`)

---

## PART 1 — Apple Developer prerequisites (one-time)

You need these before anything can be uploaded:

1. **Apple Developer Program membership** ($99/year) on the account tied to Team `XJ2WNZKCMT`.
   - Verify at https://developer.apple.com/account — membership must be active.

2. **Register the App ID** (if not already):
   - https://developer.apple.com/account → Certificates, IDs & Profiles → Identifiers → (+)
   - Type: App IDs → App
   - Bundle ID: **Explicit** → `com.seventyfive.hard.challenge`
   - Capabilities: enable **Push Notifications**.
   - Save.

3. **APNs key for Firebase push** (needed for FCM on iOS):
   - Keys → (+) → enable **Apple Push Notifications service (APNs)** → download the `.p8` key.
   - Note the **Key ID** and your **Team ID**.
   - In Firebase Console → Project Settings → Cloud Messaging → Apple app configuration →
     upload the `.p8`, Key ID, and Team ID.
   - (Without this, push notifications won't be delivered on iOS. Local reminders still work.)

---

## PART 2 — Create the app record in App Store Connect (one-time)

1. Go to https://appstoreconnect.apple.com → **My Apps** → (+) → **New App**.
2. Fill in:
   - Platform: **iOS**
   - Name: **DailyMettle: Habit & Challenge** (must be unique on the App Store; if taken,
     pick a variant like "DailyMettle - Habit Tracker")
   - Primary language: English
   - Bundle ID: select **com.seventyfive.hard.challenge**
   - SKU: any unique string, e.g. `dailymettle-ios-001`
   - User access: Full
3. Create.

---

## PART 3 — Build & upload the archive

You upload from **Xcode** (simplest for a first release).

### 3a. Set version/build
- Current: `1.0.7+7`. App Store Connect requires each uploaded build to have a unique build number.
- If you upload more than once, bump the build: in `pubspec.yaml` change `version: 1.0.7+7` → `1.0.7+8`, etc.
- (You can do this in pubspec; Flutter maps `+N` to `CFBundleVersion`.)

### 3b. Create the archive
Run these in the project root:

```bash
flutter clean
flutter pub get
flutter build ipa --release
```

`flutter build ipa` produces:
- Archive: `build/ios/archive/Runner.xcarchive`
- IPA: `build/ios/ipa/*.ipa`

If signing errors occur, open the workspace and let Xcode manage signing:
```bash
open ios/Runner.xcworkspace
```
- Runner target → Signing & Capabilities → "Automatically manage signing" ON, Team = your team.
- Confirm **Push Notifications** capability is listed (it should be, via the entitlements file).

### 3c. Upload
**Option A — Xcode Organizer (recommended first time):**
1. `open ios/Runner.xcworkspace`
2. Product menu → **Archive** (select "Any iOS Device" as the run destination first).
3. When the Organizer opens → **Distribute App** → **App Store Connect** → **Upload** → follow prompts.

**Option B — Transporter app:**
1. Install "Transporter" from the Mac App Store.
2. Sign in with your Apple ID.
3. Drag the `.ipa` from `build/ios/ipa/` into Transporter → **Deliver**.

After upload, the build appears in App Store Connect under
**TestFlight** and **App Store → Build** after ~5–30 min of processing.

---

## PART 4 — TestFlight (share for testing)

TestFlight is how you share the app with testers before public release.

### Internal testing (fastest, up to 100 testers on your team)
1. App Store Connect → your app → **TestFlight** tab.
2. Wait for the build to finish "Processing".
3. **Test Information**: fill in the "What to Test" notes and your email for feedback.
4. Under **Internal Testing** → add testers (they must be users in your App Store Connect team).
5. Testers install the **TestFlight** app from the App Store, then accept your invite.

### External testing (up to 10,000 testers via public/email links)
1. TestFlight → **External Testing** → create a group → add testers by email or get a public link.
2. External builds require a **Beta App Review** (usually quick, ~1 day) the first time.
3. **Export Compliance**: you'll be asked about encryption — since `ITSAppUsesNonExemptEncryption`
   is set to `false` in Info.plist, this should auto-answer. If prompted, select
   "uses standard encryption / exempt".

---

## PART 5 — App Store listing (required before submitting for review)

In App Store Connect → your app → the version page, fill in ALL of these:

### Required text
- **Promotional text** (optional, 170 chars)
- **Description** — full description of the app (reuse your Play Store description)
- **Keywords** — comma-separated (e.g. `habit tracker,75 hard,challenge,discipline,goals,routine`)
- **Support URL** — a working URL (a simple landing page or your site). REQUIRED.
- **Marketing URL** (optional)

### Privacy Policy URL — REQUIRED (Apple needs a hosted URL, not just in-app text)
- Host your privacy policy publicly and paste the URL. Options:
  - GitHub Pages / any static host
  - The in-app text in `lib/screens/privacy_policy_screen.dart` is your source content —
    copy it to a hosted page.
- Enter it under App Information → **Privacy Policy URL**.

### Screenshots — REQUIRED
Provide screenshots for at least:
- **6.7" / 6.9" iPhone** (e.g. iPhone 15/16 Pro Max) — REQUIRED
- 5.5" is no longer required for new apps, but 6.5"/6.7" is.
- iPad screenshots ONLY if you mark the app as iPad-compatible.
Capture them by running the app on the simulator of that device size and taking screenshots.
Sizes (portrait):
- 6.7": 1290 x 2796
- 6.5": 1242 x 2688

### App icon
- Already in the app (1024, no alpha). App Store Connect pulls it from the build.

### App Privacy ("nutrition label") — REQUIRED
App Store Connect → App Privacy → answer the data-collection questionnaire.
Based on this app, declare:
- **Contact Info → Email address** — linked to identity, App Functionality (Firebase Auth)
- **Identifiers → User ID** — linked, App Functionality
- **Usage Data → Product Interaction** — Analytics (Firebase Analytics)
- **Diagnostics → Crash Data / Performance Data** — App Functionality (Crashlytics)
- **User Content → Photos** — linked, App Functionality (photo proof)
- Tracking: **No** (you are not tracking across other companies' apps)
(These match the `PrivacyInfo.xcprivacy` in the project.)

### Age rating
- Fill the content questionnaire. This app is likely **4+** (no objectionable content).

### Pricing & Availability
- Set price (Free, presumably) and territories.

---

## PART 6 — Submit for review

1. On the version page, under **Build**, click (+) and select the uploaded build.
2. Answer **Export Compliance** (encryption) — should be exempt (`false`).
3. **App Review Information**:
   - Provide a **demo account** (email + password) so reviewers can log in, OR note that
     Google Sign-In is used. Since login is required to use cloud features, giving a working
     test login (email/password if enabled, or a Google test account) avoids rejection.
   - Contact name, phone, email.
   - Notes: briefly explain the app and that partner/cloud features need sign-in.
4. Click **Add for Review** → **Submit**.
5. Review typically takes 24–48 hours. You'll get email updates.

---

## PART 7 — Common rejection reasons (avoid these)

- **Missing/incorrect Privacy Policy URL** — must be live and match the app's data use. (Handled: policy text is accurate.)
- **App Privacy answers don't match behavior** — make sure the nutrition label matches actual Firebase data collection.
- **Reviewer can't log in** — provide a working demo account in App Review Information.
- **Guideline 5.1.1 (permission strings)** — Info.plist camera/photo strings are set. (Handled.)
- **Push without APNs configured** — complete PART 1 step 3.
- **Crashes on launch** — fixed (connectivity_plus v7). Test on TestFlight first.

---

## Quick command reference

```bash
# Build a signed archive + IPA for upload
flutter clean && flutter pub get && flutter build ipa --release

# Open Xcode to manage signing / archive manually
open ios/Runner.xcworkspace

# Bump build number before re-upload (edit pubspec.yaml)
# version: 1.0.7+8   (increment the +N each upload)
```

---

## What I (the assistant) have prepared vs. what needs you

**Prepared in the repo (done):** all native config, entitlements, privacy manifest,
legal screens, Firebase wiring, the crash fix, and a verified release build.

**Only you can do (needs Apple account / console access):**
- Apple Developer membership, App ID registration, APNs key + Firebase upload (PART 1)
- Create App Store Connect record (PART 2)
- Archive & upload via Xcode/Transporter (PART 3)
- TestFlight tester setup (PART 4)
- Listing text, screenshots, hosted Privacy Policy URL, App Privacy answers (PART 5)
- Submit for review (PART 6)
