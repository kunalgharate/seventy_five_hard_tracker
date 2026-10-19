# 75 Hard Challenge Tracker

A Flutter mobile app for tracking the 75 Hard mental toughness challenge with customizable daily tasks, smart notifications, and cloud backup.

## Overview

The 75 Hard Challenge Tracker helps users commit to a 75-day personal development challenge. Users define their daily tasks, track completion each day, receive smart reminders, and monitor progress with detailed statistics. The app supports both strict "Hard Mode" (miss a task, restart from Day 1) and flexible "Soft Mode" (track without penalties).

## Key Features

- **Two challenge modes** — Hard (strict reset on failure) and Soft (flexible tracking)
- **Three task types** — Hard (must-do), Soft (should-do), Regular (optional habits)
- **Smart notifications** — Once, multiple, hourly, interval, and custom reminders
- **Daily journal** — Per-day reflections and per-task notes
- **Photo proof** — Attach photos to tasks as evidence
- **Progress tracking** — Day counter, completion %, streaks, and history
- **Cloud backup** — AES-256 encrypted sync via Firebase
- **Offline-first** — All core features work without internet
- **50+ icons, 25+ colors** — Rich customization for tasks

## Documentation

| Document | Description |
|---|---|
| [Product Requirements (PRD)](docs/PRODUCT_REQUIREMENTS.md) | Full product specification for QA — features, user flows, business rules, data models, notification system, edge cases, and testing checklist |

### What the PRD Covers

The product requirements document is the single source of truth for QA testing. It includes:

- **Challenge modes** — How Hard Mode and Soft Mode work, reset logic, completion criteria
- **Task types** — Hard, Soft, Regular — what each means and how they interact with resets
- **User flows** — Onboarding, daily tracking, missed-day detection, completion, manual reset, cloud sync
- **Screens & navigation** — Every screen in the app, what it shows, and how to navigate
- **Notification system** — All 5 reminder types, night summary, motivation quotes, notification ID generation, limits
- **Data models** — Challenge, ChallengeSession, DailyProgress — every field documented
- **Business rules** — Day counter calculation, completion checks, midnight timer, scheduling logic
- **Cloud sync & security** — AES-256 encryption, Firebase auth, backup/restore flows
- **Edge cases** — Offline behavior, timezone handling, notification limits, boundary conditions
- **QA testing checklist** — 100+ test cases organized by feature area

## Tech Stack

- **Framework:** Flutter (Dart)
- **State Management:** flutter_bloc
- **Local Database:** Hive
- **Notifications:** flutter_local_notifications + timezone
- **Cloud:** Firebase (Auth, Firestore, Storage, Analytics, Crashlytics, FCM)
- **Encryption:** AES-256 via encrypt package
- **UI:** Material 3, Glassmorphism, flutter_animate, Poppins + Inter fonts

## Getting Started

### Prerequisites

- Flutter **3.38.3** (stable), which includes Dart **3.10.1**. The version is
  pinned in [.fvmrc](.fvmrc).
- Git and a platform toolchain for the target you want to run (Android Studio
  for Android, or Xcode and CocoaPods for iOS).

If you use [FVM](https://fvm.app/), install and select the repository's pinned
SDK before running the commands below:

```bash
fvm install
fvm use
export FLUTTER="fvm flutter"
export DART="fvm dart"
```

Without FVM, install Flutter 3.38.3 and make its `flutter` and `dart`
executables available on `PATH`.

### Setup, run, test, and build

```bash
# Resolve the locked dependency graph (requires network access the first time)
make get

# Generate Hive adapters when generated sources are needed
dart run build_runner build --delete-conflicting-outputs

# Run the app on an available Flutter device
flutter run

# Run the complete offline test suite. Dependencies must already be cached.
make test

# Analyze the project and check formatting
make analyze
make format-check

# Build the production Flutter web artifact in build/web/
make build

# Start a local Flutter web-server preview
make run
```

`make test` is the single offline test command for this repository; it uses
Flutter's supported `--no-pub` flag so it cannot trigger dependency resolution.
Run `make get` while online before using it on a clean machine. The FVM setup
above exports the Make variables; they can also be passed per invocation, for
example: `make FLUTTER="fvm flutter" test`.

### Docker web preview

The Docker build downloads the pinned Flutter 3.38.3 SDK, installs the Linux
build prerequisites, resolves `pubspec.lock`, and builds the release web
artifact. The final image serves that artifact with Python's web server:

```bash
docker build --tag seventy-five-hard-tracker:local .
docker run --rm --publish 8080:8080 seventy-five-hard-tracker:local
```

Open <http://localhost:8080> after the container starts.

### Mobile release notes

- **Android:** configure signing values in the local, ignored
  `android/key.properties` and provide the keystore through your CI secret
  store. Build an AAB with `flutter build appbundle --release` (or an APK with
  `flutter build apk --release`). The Android minimum SDK is 23.
- **iOS:** use macOS with Xcode and CocoaPods, configure the bundle identifier,
  signing team, provisioning profile, and Firebase plist in Xcode, then run
  `flutter build ipa --release`. App Store distribution and signing are
  described in [docs/APP_STORE_PUBLISHING.md](docs/APP_STORE_PUBLISHING.md).

Firebase, Google Sign-In, and Cloudinary credentials are environment/CI
configuration and are **not committed** to this repository. Keep local
credential files and signing material out of git; use your CI secret store or
an untracked `.env` file for local configuration.

## Project Structure

```
lib/
├── bloc/                  # BLoC state management (events, states, business logic)
├── models/                # Data models (Challenge, ChallengeSession, DailyProgress)
├── repositories/          # Database repository (Hive CRUD operations)
├── screens/               # App screens (Home, Onboarding, Settings, Profile, History)
├── services/              # Services (notifications, cloud sync, analytics, icons, colors)
├── widgets/               # Reusable widgets (task cards, date picker, journal, reminders)
└── main.dart              # App entry point, theming, routing

test/
├── bug_condition_exploration_test.dart   # Bug condition verification tests
└── preservation_property_test.dart       # Preservation property tests

docs/
└── PRODUCT_REQUIREMENTS.md              # Full PRD for QA
```

## Version

**Current:** 1.0.8+8
**Min SDK:** Android 23 (6.0 Marshmallow)
**Flutter:** 3.38.3 (Dart 3.10.1)
**Dart SDK constraint:** ^3.5.0
