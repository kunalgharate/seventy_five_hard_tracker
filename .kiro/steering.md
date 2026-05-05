# 75 Hard Tracker — Steering Guide

## Purpose

A **discipline-building application** inspired by the 75 Hard Challenge. Users define daily tasks with varying difficulty levels, maintain streaks through consistent completion, and face consequences (streak loss or reset) when they miss hard tasks. The app enforces accountability through two reset modes — **hard mode** (miss a hard task → lose your streak and restart from day 1) and **soft mode** (missed tasks are tracked but the streak continues). Future plans include short motivational videos shown on day completion and productivity planning tools.

## Tech Stack

- **Framework**: Flutter 3.38.3 · Dart 3.5.0
- **State Management**: BLoC (flutter_bloc 8.x)
- **Local Database**: Hive (hive_flutter)
- **Backend**: Firebase (Auth, Firestore, Crashlytics, Analytics, Messaging, Storage)
- **Notifications**: flutter_local_notifications + custom SmartNotificationService
- **Cloud Sync**: AES-encrypted Firestore sync via CloudSyncService
- **Line Length**: 100

## Architecture

```
lib/
├── bloc/              # Single ChallengeBloc — events, states, business logic
├── models/            # Hive-annotated: Challenge, ChallengeSession, DailyProgress
├── repositories/      # DatabaseRepository — Hive CRUD for sessions, progress, settings
├── screens/           # Home, RegularTasks, Profile, History, Onboarding, Settings, Privacy
├── services/          # Notifications, analytics, cloud sync, quotes, connectivity, etc.
├── widgets/           # Reusable UI: task cards, date picker, journal, progress stats
├── main.dart          # App entry, Hive init, adapter registration, theme
└── firebase_options.dart
```

**Data flow**: Screens → BLoC → Repository → Hive. Firebase services sit alongside for sync, analytics, and push notifications.

## Domain Model

### Task Types (Challenge.taskType)
| Type      | Streak Impact                                  | Tab         |
|-----------|-------------------------------------------------|-------------|
| `hard`    | Missing resets streak to day 1 (hard mode only) | Home        |
| `soft`    | Tracked but does not break streak               | Home        |
| `regular` | Optional habit tracking, no streak impact        | Daily Tasks |

### Reset Modes (ChallengeSession.resetMode)
| Mode   | Behavior                                         |
|--------|--------------------------------------------------|
| `hard` | Any missed hard task → session ends, restart day 1 |
| `soft` | Missed tasks logged, streak continues             |

### Key Models
- **Challenge** — A single task with title, category, icon, taskType, reminder config, photo requirement
- **ChallengeSession** — Active challenge run: list of challenges, start/end dates, currentDay, resetMode, totalDaysTarget (default 75)
- **DailyProgress** — Per-day record: completion map, journal note, task notes, task photos

## Must Follow

- **BLoC only** for state management — no `setState` in BLoC-connected widgets
- **Repository pattern** — no direct Hive or Firebase calls from widgets or screens
- All user-facing strings via `context.l10n` (no hardcoded strings)
- **Package imports** across files (not relative)
- `const` constructors wherever possible
- Handle **loading / success / error** states in every BLoC consumer
- New tasks go through `TaskTemplates` or custom creation via `OnboardingScreen`
- Streak logic lives in `ChallengeBloc._checkForMissedDays` — only hard tasks trigger resets in hard mode

## Must NOT

- Use `setState` in BLoC-connected widgets
- Access Firebase or Hive directly from widgets/screens
- Hardcode user-facing strings
- Create BLoC instances inside `build()` methods
- Modify streak/reset logic without updating both `_checkForMissedDays` and `_onUpdateDailyProgress`

## BLoC Pattern

```dart
class XBloc extends Bloc<XEvent, XState> {
  final XRepository _repo;
  XBloc({required XRepository repo}) : _repo = repo, super(XInitial()) {
    on<SomeEvent>(_onSomeEvent);
  }
}
```

Currently a single `ChallengeBloc` handles all events. If adding a new domain (e.g., motivational videos), create a separate BLoC rather than overloading the existing one.

## Navigation

Three-tab bottom nav via `MainNavigationScreen`:
1. **75 Hard** (HomeScreen) — daily hard/soft task checklist, progress ring, journal
2. **Daily Tasks** (RegularTasksScreen) — regular/optional habit tasks
3. **Profile** (ProfileScreen) — history, settings, cloud sync, stats

## Services

| Service                      | Responsibility                                      |
|------------------------------|-----------------------------------------------------|
| SmartNotificationService     | Scheduled reminders, night summaries, failure alerts |
| AnalyticsService             | Firebase Analytics event logging                    |
| CloudSyncService             | AES-encrypted Firestore backup/restore              |
| QuotesService                | Motivational quotes (API + offline fallback)         |
| ConnectivityService          | Network state monitoring                            |
| ChallengeIconService         | Icon resolution for task categories                 |
| DynamicColorService          | Theme color management                              |
| FCMService                   | Firebase Cloud Messaging push notifications          |
| SimpleBackgroundCheckService | Background missed-day checks                        |

## Commands

```bash
# Run
flutter run

# Analyze
flutter analyze

# Code generation (Hive adapters)
dart run build_runner build --delete-conflicting-outputs

# Tests
flutter test
```

## Future Roadmap

- **Motivational videos**: Short clips shown on daily completion — productivity tips, discipline reinforcement
- **Productivity planning**: Day planning tools tied to challenge tasks
- Keep the architecture extensible for these additions (separate BLoCs, new service layer for video content)
