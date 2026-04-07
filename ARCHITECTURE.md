# Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │  75 Hard Tab │  │ Regular Tasks│  │ Profile Tab  │        │
│  │              │  │     Tab      │  │              │        │
│  │ - Day tracker│  │ - Habit list │  │ - Stats      │        │
│  │ - Task cards │  │ - Skip option│  │ - Sync status│        │
│  │ - Calendar   │  │ - Analytics  │  │ - Settings   │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      STATE MANAGEMENT (BLoC)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                    ChallengeBloc                         │ │
│  │                                                          │ │
│  │  Events:                        States:                 │ │
│  │  • LoadChallengeData           • ChallengeLoaded       │ │
│  │  • StartNewSession             • ChallengeCompleted    │ │
│  │  • UpdateDailyProgress         • ChallengeReset        │ │
│  │  • AddTaskPhoto                • ChallengeError        │ │
│  │  • ResetChallenge                                      │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          SERVICES LAYER                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────┐  ┌──────────────────────┐          │
│  │ SmartNotification    │  │ BackgroundCheck      │          │
│  │ Service              │  │ Service              │          │
│  │                      │  │                      │          │
│  │ • Schedule reminders │  │ • Hourly checks      │          │
│  │ • Cancel on complete │  │ • Auto-reset         │          │
│  │ • Time windows       │  │ • Offline support    │          │
│  │ • Night summary      │  │ • Notification mgmt  │          │
│  └──────────────────────┘  └──────────────────────┘          │
│                                                                 │
│  ┌──────────────────────┐  ┌──────────────────────┐          │
│  │ FirebaseSync         │  │ Encryption           │          │
│  │ Service              │  │ Service              │          │
│  │                      │  │                      │          │
│  │ • Cloud backup       │  │ • Encrypt data       │          │
│  │ • Photo upload       │  │ • Decrypt data       │          │
│  │ • Cross-device sync  │  │ • Key management     │          │
│  └──────────────────────┘  └──────────────────────┘          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         DATA LAYER                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────┐  ┌──────────────────────┐          │
│  │ Local Storage (Hive) │  │ Cloud Storage        │          │
│  │                      │  │ (Firebase)           │          │
│  │ • Challenges         │  │ • Encrypted backup   │          │
│  │ • Sessions           │  │ • Photos             │          │
│  │ • Daily progress     │  │ • Sync metadata      │          │
│  │ • Photos (local)     │  │                      │          │
│  └──────────────────────┘  └──────────────────────┘          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### 1. User Completes a Task

```
User taps ✓ on task
       │
       ▼
UpdateDailyProgress event
       │
       ▼
ChallengeBloc processes
       │
       ├─► Update Hive database
       │
       ├─► Cancel task reminders (SmartNotificationService)
       │
       ├─► Reschedule reminders for pending tasks
       │
       ├─► Schedule night summary if needed
       │
       └─► Emit new state
              │
              ▼
         UI updates
```

### 2. Background Reset Check

```
Every hour (WorkManager)
       │
       ▼
BackgroundCheckService runs
       │
       ├─► Check yesterday's progress
       │
       ├─► Identify missed hard tasks
       │
       └─► If missed:
              │
              ├─► Update session (inactive)
              │
              ├─► Cancel all notifications
              │
              └─► Send reset notification
```

### 3. Smart Notification Scheduling

```
Task created or progress updated
       │
       ▼
SmartNotificationService.scheduleSmartReminders()
       │
       ├─► Get current progress
       │
       ├─► Filter pending tasks
       │
       └─► For each pending task:
              │
              ├─► Check time window
              │
              ├─► Check task type
              │
              └─► Schedule based on reminder type:
                     │
                     ├─► Once: Single notification
                     │
                     ├─► Hourly: Multiple notifications
                     │
                     └─► Custom: Interval-based
```

---

## Task Type Decision Tree

```
User creates a task
       │
       ▼
What type of task?
       │
       ├─► HARD
       │      │
       │      ├─► Must complete daily
       │      ├─► Resets to day 1 if missed
       │      ├─► Counts toward 75 Hard
       │      └─► Mandatory reminders
       │
       ├─► SOFT
       │      │
       │      ├─► Should complete daily
       │      ├─► Tracked but no reset
       │      ├─► Affects discipline score
       │      └─► Optional reminders
       │
       └─► REGULAR
              │
              ├─► Optional habit tracking
              ├─► Can skip anytime
              ├─► Shows in Regular tab
              └─► Optional reminders
```

---

## Notification Flow

```
                    ┌─────────────────┐
                    │  Task Created   │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Reminder Enabled?│
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                   YES               NO
                    │                 │
                    ▼                 ▼
          ┌─────────────────┐   [No reminders]
          │ What type?      │
          └────────┬────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
       ONCE     HOURLY     CUSTOM
        │          │          │
        ▼          ▼          ▼
    [Single]  [Every hr]  [Every X min]
        │          │          │
        └──────────┼──────────┘
                   │
                   ▼
          ┌─────────────────┐
          │ Within time     │
          │ window?         │
          └────────┬────────┘
                   │
          ┌────────┴────────┐
          │                 │
         YES               NO
          │                 │
          ▼                 ▼
    [Schedule]        [Skip this hour]
          │
          ▼
    ┌─────────────────┐
    │ Task completed? │
    └────────┬────────┘
             │
    ┌────────┴────────┐
    │                 │
   YES               NO
    │                 │
    ▼                 ▼
[Cancel]        [Keep reminder]
```

---

## Reset Logic Flow

```
                    ┌─────────────────┐
                    │  New Day Starts │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Check yesterday │
                    │ progress        │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ Any hard tasks  │
                    │ incomplete?     │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                   YES               NO
                    │                 │
                    ▼                 ▼
          ┌─────────────────┐   [Continue]
          │ What reset mode?│
          └────────┬────────┘
                   │
          ┌────────┴────────┐
          │                 │
        HARD              SOFT
          │                 │
          ▼                 ▼
    ┌─────────┐      ┌─────────┐
    │ RESET   │      │ TRACK   │
    │ to Day 1│      │ only    │
    └────┬────┘      └────┬────┘
         │                │
         ├─► Cancel all   ├─► Keep going
         │   notifications│
         │                │
         ├─► Send reset   ├─► Update stats
         │   notification │
         │                │
         └─► Mark session └─► Continue
             inactive         session
```

---

## File Structure

```
lib/
├── main.dart                          [Entry point]
│
├── models/                            [Data models]
│   ├── challenge.dart                 ✅ Updated
│   ├── challenge_session.dart         ✅ Updated
│   └── daily_progress.dart            ✅ Updated
│
├── services/                          [Business logic]
│   ├── smart_notification_service.dart ✅ NEW
│   ├── background_check_service.dart   ✅ NEW
│   ├── firebase_sync_service.dart      ⏳ TODO
│   ├── encryption_service.dart         ⏳ TODO
│   ├── notification_service.dart       ❌ OLD (can remove)
│   └── analytics_service.dart          📝 Existing
│
├── bloc/                              [State management]
│   ├── challenge_bloc.dart            ⏳ Needs update
│   ├── challenge_event.dart           ⏳ Needs update
│   └── challenge_state.dart           ✅ OK
│
├── screens/                           [UI screens]
│   ├── home_screen.dart               ✅ Existing
│   ├── onboarding_screen.dart         ⏳ Needs update
│   ├── main_navigation_screen.dart    ⏳ TODO
│   ├── regular_tasks_screen.dart      ⏳ TODO
│   └── profile_screen.dart            ⏳ TODO
│
└── widgets/                           [UI components]
    ├── daily_task_card.dart           ⏳ Needs update
    ├── task_reminder_widget.dart      ✅ Existing
    └── [other widgets]                ✅ Existing
```

---

## Component Interactions

```
┌─────────────────────────────────────────────────────────────┐
│                      User Actions                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                            │
│  • HomeScreen                                               │
│  • OnboardingScreen                                         │
│  • RegularTasksScreen                                       │
│  • ProfileScreen                                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (Events)
┌─────────────────────────────────────────────────────────────┐
│                      ChallengeBloc                          │
│  • Receives events                                          │
│  • Processes business logic                                 │
│  • Emits states                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│   SmartNotification      │  │   BackgroundCheck        │
│   Service                │  │   Service                │
│                          │  │                          │
│  • Schedule reminders    │  │  • Check missed days     │
│  • Cancel on complete    │  │  • Auto-reset            │
│  • Time window checks    │  │  • Offline support       │
└──────────────────────────┘  └──────────────────────────┘
                    │                   │
                    └─────────┬─────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DatabaseRepository                       │
│  • Hive operations                                          │
│  • CRUD operations                                          │
│  • Query helpers                                            │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│   Local Storage          │  │   Cloud Storage          │
│   (Hive)                 │  │   (Firebase)             │
│                          │  │                          │
│  • Challenges            │  │  • Encrypted backup      │
│  • Sessions              │  │  • Photos                │
│  • Progress              │  │  • Sync metadata         │
└──────────────────────────┘  └──────────────────────────┘
```

---

## State Transitions

```
                    ┌─────────────────┐
                    │ ChallengeInitial│
                    └────────┬────────┘
                             │
                             ▼ LoadChallengeData
                    ┌─────────────────┐
                    │ ChallengeLoading│
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
              Success            Error
                    │                 │
                    ▼                 ▼
          ┌─────────────────┐   ┌─────────────┐
          │ ChallengeLoaded │   │ChallengeError│
          └────────┬────────┘   └──────────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
        ▼          ▼          ▼
   [Update]   [Complete]  [Reset]
        │          │          │
        ▼          ▼          ▼
   [Loaded]  [Completed] [Reset]
```

---

## Legend

```
✅ Complete
⏳ In Progress / TODO
❌ Deprecated / Remove
📝 Existing / No changes needed
```

---

This architecture provides:
- Clear separation of concerns
- Scalable service layer
- Offline-first design
- Background task support
- Cloud sync capability
- Flexible notification system
