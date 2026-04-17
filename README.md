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

```bash
# Install dependencies
flutter pub get

# Generate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Run tests
flutter test

# Run linter
flutter analyze

# Format code
dart format .
```

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

**Current:** 1.1.0+5  
**Min SDK:** Android 23 (6.0 Marshmallow)  
**Dart SDK:** ^3.5.0
