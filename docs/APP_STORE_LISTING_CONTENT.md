# DailyMettle — App Store Connect Listing Content

Copy-paste ready content for the App Store Connect listing, adapted from the live
Play Store listing (com.seventyfive.hard.challenge) and tailored to Apple's fields.

App: **DailyMettle: Habit & Challenge**
Developer: TheCodersHub (Kunal Gharate)
Category: **Productivity** (Primary). Suggested Secondary: Health & Fitness
Support email: hello@thecodershub.in
Website / Support URL: http://thecodershub.in
Existing hosted Privacy Policy: https://sites.google.com/view/75hardchallengeapp/home
  ⚠️ See "Privacy Policy note" at the bottom — this page must be updated to reflect
     Firebase data collection before you submit.

---

## App Name (max 30 chars)
`DailyMettle: Habit & Challenge`
(Exactly 30 characters — fits Apple's limit.)

## Subtitle (max 30 chars)
`Build discipline, 75 Hard`
(alt: `75 Hard & daily habit builder`)

## Promotional Text (max 170 chars, editable anytime without review)
`Forge daily discipline and conquer the 75 Hard journey. Offline-first tracking, smart reminders, and daily motivation to keep you consistent from Day 1 to Day 75.`

## Keywords (max 100 chars, comma-separated, no spaces after commas for efficiency)
`75 hard,habit,tracker,challenge,discipline,routine,goals,streak,motivation,productivity,self care`
(97 chars. Do NOT repeat words already in the app name/subtitle; Apple indexes those separately.)

## Description (full)
```
Transform your mindset. Forge daily discipline. Conquer the 75 Hard Challenge.

DailyMettle is your personal companion for the 75 Hard journey — designed to keep you consistent, motivated, and accountable from Day 1 to Day 75. Whether you're focusing on fitness, reading, hydration, or personal growth, this app helps you build habits that stick long after the challenge ends.

WHY DAILYMETTLE?

• Offline-First Design — Your progress is always safe and accessible, with or without internet. Track anytime, anywhere.

• Smart Daily Reminders — Customizable alerts that keep you on track without overwhelming you. Never miss a task again.

• Daily Motivation — Start each day with a powerful quote to fuel your focus and push through tough moments.

• Clear Progress Tracking — Visualize your journey with clean stats and streaks. See how far you've come.

• Accountability Partners — Invite a partner to review your progress and keep each other on track.

• Encrypted Cloud Backup — Optional AES-256 encrypted sync so your backup data is restorable across reinstalls.

• Daily Journal — Reflect on each day with per-day notes and per-task journaling.

• Built for Consistency — Minimalist interface, no distractions — just you and your goals.

More than a challenge tracker — it's a daily discipline builder. Join others using DailyMettle to stay focused, build resilience, and prove to themselves they can follow through.

Stay consistent. Stay strong. Grow your mettle — one day at a time.
```

## What's New (release notes for v1.0.7)
```
• First release on the App Store!
• Regular Tasks tab for daily habit tracking
• Profile screen with stats & optional encrypted cloud backup
• Accountability partner reviews
• Smart notifications with flexible reminders
• Daily journal entries and night summary for pending tasks
```

---

## Screenshots required
- **6.7"/6.9" iPhone** (e.g. iPhone 15/16 Pro Max): 1290 x 2796 px — REQUIRED
- 6.5" (1242 x 2688) recommended for older-device display
- iPad: only if you enable iPad support
Reuse the same scenes as your Play Store screenshots (you have 9 there). Capture on the
matching iOS simulator: run the app, navigate to each screen, ⌘S to save screenshots.

Suggested screens to capture (match Play Store order):
1. Onboarding / welcome
2. Daily tasks (home) with progress
3. Task completion + streak
4. Regular tasks tab
5. Profile / stats
6. Journal entry
7. Reminders setup
8. Accountability partner
9. Cloud backup / settings

---

## Age Rating
Answer the questionnaire → expect **4+** (no objectionable content).
(Play rates it 3+; Apple's equivalent is 4+.)

---

## App Privacy ("nutrition label") — answer to match the app's real behavior
Data collected (all: NOT used for tracking, most NOT linked unless noted):

| Data type | Collected | Linked to identity | Purpose |
|---|---|---|---|
| Email Address | Yes | Yes | App Functionality (Firebase Auth) |
| Name | Yes | Yes | App Functionality (display name for partners) |
| User ID | Yes | Yes | App Functionality |
| Photos | Yes | Yes | App Functionality (photo proof) |
| Product Interaction | Yes | No | Analytics (Firebase Analytics) |
| Crash Data | Yes | No | App Functionality (Crashlytics) |
| Performance Data | Yes | No | App Functionality (Crashlytics) |

Tracking: **No** (not tracking across other companies' apps/sites).

⚠️ NOTE: This differs from your current Play Store "No data collected" declaration.
Because the app now uses Firebase (Auth, Analytics, Crashlytics, cloud sync, photo
upload), the accurate answer is "data IS collected" as above. You should also update
the **Play Console Data safety** form to match, to stay consistent across both stores.

---

## App Review Information (critical — prevents rejection)
- **Sign-in required:** Yes (for cloud/partner features).
- Provide a **demo account** the reviewer can use. Since the app uses Google Sign-In,
  either:
  (a) enable Email/Password auth in Firebase and create a test account, then supply it, OR
  (b) supply a dedicated Google test account's credentials.
  Without a working login, Apple often rejects under Guideline 2.1.
- Contact: Kunal Gharate, hello@thecodershub.in, phone.
- Notes to reviewer (example):
  "DailyMettle is a habit/challenge tracker. Core tracking works offline without login.
   Cloud backup and accountability-partner features require sign-in. A demo account is
   provided above. Notifications are used for task reminders."

---

## Privacy Policy note (must fix before submission)
Your hosted policy at https://sites.google.com/view/75hardchallengeapp/home reflects the
OLD offline-only app ("no data collected"). The current app collects data via Firebase.
Before submitting to Apple (and to keep Play compliant):
1. Update that hosted page to match the accurate policy now shipped in the app
   (see lib/screens/privacy_policy_screen.dart for the current, accurate text).
2. Use that same URL in App Store Connect → App Information → Privacy Policy URL.

---

## Export Compliance
When prompted at upload/submission: the app uses only standard encryption (AES for its
own data). `ITSAppUsesNonExemptEncryption` is set to `false` in Info.plist, so it should
auto-answer as exempt. If asked, select the standard-encryption exemption.
