# 75 Hard Challenge Tracker — Product Requirements Document

**Version:** 1.1.0  
**Last Updated:** April 2026  
**Platform:** Android (Flutter)  
**Audience:** QA Engineers, Developers, Product Stakeholders

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [Challenge Modes](#2-challenge-modes)
3. [Task Types](#3-task-types)
4. [User Flows](#4-user-flows)
5. [Screens & Navigation](#5-screens--navigation)
6. [Notification System](#6-notification-system)
7. [Data Models](#7-data-models)
8. [Cloud Sync & Security](#8-cloud-sync--security)
9. [Services & Integrations](#9-services--integrations)
10. [Configuration Options](#10-configuration-options)
11. [Business Rules & Logic](#11-business-rules--logic)
12. [Theming & UI](#12-theming--ui)
13. [Edge Cases & Constraints](#13-edge-cases--constraints)
14. [QA Testing Checklist](#14-qa-testing-checklist)

---

## 1. Product Overview

The 75 Hard Challenge Tracker is a mobile app that helps users complete a 75-day mental toughness challenge by tracking customizable daily tasks. Users create a set of daily challenges (1–10 tasks), track completion each day, receive smart reminders, and monitor their progress over the full 75-day period.

### Key Capabilities

- Two challenge modes: Hard (strict reset on failure) and Soft (flexible tracking)
- Three task types: Hard, Soft, and Regular
- Smart notification system with five reminder types
- Daily journal and per-task notes
- Photo proof for tasks
- Horizontal date picker for reviewing past days
- Cloud backup with AES-256 encryption via Firebase
- Offline-first architecture with lazy Firebase initialization
- Progress statistics, streaks, and history tracking
- 50+ predefined icons, 25+ color themes, and task templates

---

## 2. Challenge Modes

### 2.1 Hard Mode (Default)

| Aspect | Behavior |
|---|---|
| Reset trigger | Any missed **hard** task on any past day resets the challenge to Day 1 |
| Missed-day detection | Runs automatically at app startup; checks every day from session start to yesterday |
| Soft/Regular tasks | Tracked but do not trigger resets |
| Failure notification | Shows the day that failed and which hard tasks were missed |
| Total days | Fixed at 75 |

### 2.2 Soft Mode

| Aspect | Behavior |
|---|---|
| Reset trigger | None — missed tasks are tracked but the challenge continues |
| Missed-day detection | Skipped entirely |
| Total days | Configurable via `totalDaysTarget` (default 75) |
| Use case | Flexible habit tracking without the penalty of restarting |

---

## 3. Task Types

| Type | Description | Reset Impact (Hard Mode) | Shown In |
|---|---|---|---|
| **Hard** | Must complete daily | Yes — missing triggers reset | Home screen |
| **Soft** | Should complete daily | No — tracked but no reset | Home screen |
| **Regular** | Optional habit tracking | No impact | Regular Tasks tab |

Each task has:
- Title, icon/image, color, category
- Reminder configuration (type, time, interval, time window)
- Optional photo requirement
- Optional `showInRegularTab` flag

---

## 4. User Flows

### 4.1 Onboarding (First Launch)

1. **Welcome page** — App title, 75 Hard rules, animated intro
2. **Challenge setup page** — User adds 1–10 tasks:
   - Enter task title or pick from 20+ templates
   - Select task type (hard / soft / regular)
   - Choose icon from 50+ predefined icons or upload custom image
   - Pick a color from 19 vibrant options
   - Configure reminder (type, time, interval)
3. **Review page** — Summary of all tasks before starting
4. **Start challenge** — Creates a `ChallengeSession`, redirects to Home

### 4.2 Daily Task Tracking

1. Open app → Home screen shows current day and progress stats
2. Horizontal date picker defaults to today
3. Each task appears as a card with toggle for completion
4. **Today only**: tasks are editable (toggle on/off)
5. **Past days**: read-only view of completion status
6. Tap a task card to add a note or photo
7. FAB opens journal bottom sheet for daily reflection

### 4.3 Missed Day Detection (Hard Mode)

1. App startup triggers `_checkForMissedDays`
2. Iterates from session start date to yesterday
3. For each day, checks if all **hard** tasks are completed
4. If any hard task is missing on any day:
   - Session is marked inactive with `failureReason` and `failedChallenges`
   - Failure notification is sent
   - User sees reset state on next load
5. Guard prevents re-entrant checks (`_isCheckingMissedDays`)

### 4.4 Challenge Completion

1. When 75 days have elapsed, completion check runs
2. Verifies all 75 days have `isCompleted == true`
3. Marks session as completed with `endDate`
4. Sends completion notification

### 4.5 Manual Reset

1. Settings → Danger Zone → Reset Challenge
2. Confirmation dialog required
3. Clears current session, creates new one on next start

### 4.6 Cloud Sync

1. Profile screen → Sign in anonymously via Firebase
2. Backup: encrypts all sessions + progress with AES-256, uploads to Firestore
3. Restore: downloads encrypted data, decrypts, replaces local data
4. Encryption key derived from Firebase UID

### 4.7 Regular Tasks

1. Navigate to Regular Tasks tab (bottom nav)
2. View all regular-type tasks with stats (streak, best streak, completed, missed)
3. Toggle completion for today
4. Water intake tracker: hourly grid (6 AM – 11 PM), tap to log
5. Add new regular tasks via FAB

---

## 5. Screens & Navigation

### 5.1 Bottom Navigation Bar (3 tabs)

| Tab | Screen | Purpose |
|---|---|---|
| **75 Hard** | Home Screen | Main challenge tracking, daily tasks, progress |
| **Daily Tasks** | Regular Tasks Screen | Regular habit tracking, water intake |
| **Profile** | Profile Screen | Cloud sync, stats, privacy |

### 5.2 Screen Details

#### Home Screen
- **App bar**: Title "75 Hard Challenge", debug notification test button, history icon, settings icon
- **Progress stats card**: Current day / 75, completion percentage, streak info
- **Horizontal date picker**: Scrollable day selector (Day 1 – Day 75)
- **Task list**: Animated staggered list of `DailyTaskCard` widgets
- **Journal FAB**: Opens `JournalBottomSheet` for daily notes

#### Onboarding Screen
- Multi-page with `PageView`
- Welcome page with animated text and rules
- Challenge setup with add/edit/remove tasks
- Icon picker widget with category tabs
- Color picker with 19 options
- Reminder configuration via `ReminderBottomSheet`
- Review page with all tasks listed

#### Regular Tasks Screen
- List of regular tasks with completion stats
- Water reminder widget (expandable hourly grid)
- Add task button
- Per-task streak tracking

#### Profile Screen
- User card (anonymous Firebase user)
- Journey stats: total sessions, completed, days tracked, completion rate
- Cloud sync: backup and restore buttons with status indicators
- Privacy & security link

#### History Screen
- Chronological list of all sessions (active, completed, reset)
- Expandable cards showing: dates, duration, challenges, reset reason, success rate

#### Settings Screen
- Per-task reminder configuration
- Motivational quote preview
- Danger zone: manual reset with confirmation dialog
- Data export as JSON

#### Privacy Policy Screen
- Static content: data collection, local storage, third-party services, user rights

---

## 6. Notification System

### 6.1 Reminder Types

| Type | Behavior | Example |
|---|---|---|
| **Once** | Single notification at a specific time | "Remind me at 8:00 AM" |
| **Multiple** | Several notifications at specified times | "8:00 AM, 12:00 PM, 6:00 PM" |
| **Hourly** | Every hour from start time until 11 PM | "Starting at 9:00 AM" |
| **Interval** | Every X minutes from start time until 10 PM | "Every 30 minutes from 8:00 AM" |
| **Custom** | Same as multiple (flexible timing) | User-defined times |

### 6.2 Notification Channels (Android)

| Channel | Importance | Sound | Purpose |
|---|---|---|---|
| `smart_reminders_v2` | High | `notification.wav` | Task reminders |
| `night_summary_v2` | High | `notification.wav` | End-of-day pending task summary |
| `daily_motivation_v2` | Max | `tune.wav` | Morning motivational quote |
| `task_reminders_v2` | Max | `tune.wav` | Legacy task reminders |
| `challenge_events` | Max | Default | Reset/completion alerts |

### 6.3 Night Summary Notifications

- Scheduled at **10:00 PM**, **11:00 PM**, and **11:45 PM**
- Shows count and list of pending (incomplete) tasks
- Only sent if there are incomplete tasks for the day
- Automatically cancelled when all tasks are completed

### 6.4 Challenge Event Notifications

| Event | Content |
|---|---|
| **Failure/Reset** | "Challenge Reset! You missed: [tasks] on day X. Starting over from Day 1!" |
| **Completion** | "Congratulations! You completed the 75 Hard Challenge!" |
| **Daily Motivation** | Motivational quote at 8:00 AM (online via ZenQuotes API, offline fallback) |

### 6.5 Notification ID Generation

- Base hash: `challengeId.hashCode.abs() % 100000`
- Final ID: `(baseHash * 10000) + (hour * 100) + minute`
- Deterministic: same inputs always produce same ID
- Time-differentiated: different times produce different IDs
- Max possible ID: 999,992,359 (within 32-bit signed int range)

### 6.6 Notification Limits

- **Max scheduled**: 400 (safety margin below Samsung's 500-alarm limit)
- Automatic cancellation when task is completed or challenge resets
- Graceful degradation: stops scheduling when limit reached

### 6.7 Time Window Filtering

- Each task has `reminderStartHour` (default 0) and `reminderEndHour` (default 23)
- `allowNightReminders` flag controls 10 PM – 6 AM window
- Reminders outside the window are silently skipped

---

## 7. Data Models

### 7.1 Challenge

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique identifier |
| `title` | String | Task name |
| `taskType` | String | `hard`, `soft`, or `regular` |
| `reminderType` | String | `once`, `hourly`, `custom`, `interval` |
| `reminderTime` | String? | Encoded time (e.g., `"once:08:00"`, `"hourly:09:00"`, `"interval:30:08:00"`) |
| `isReminderEnabled` | bool | Whether reminders are active |
| `reminderStartHour` | int | Start of reminder window (0–23) |
| `reminderEndHour` | int | End of reminder window (0–23) |
| `allowNightReminders` | bool | Allow 10 PM – 6 AM reminders |
| `reminderIntervalMinutes` | int | Interval in minutes (for interval type) |
| `photoRequired` | bool | Whether photo proof is required |
| `showInRegularTab` | bool | Show in Regular Tasks tab |
| `imagePath` | String? | Path to custom image |
| `iconName` | String? | Predefined icon name |
| `iconColor` | int? | ARGB color value |
| `category` | String | `fitness`, `health`, `learning`, `productivity`, `lifestyle`, `social`, `general` |

### 7.2 ChallengeSession

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique identifier (milliseconds since epoch) |
| `challenges` | List\<Challenge\> | All tasks in this session |
| `startDate` | DateTime | When the challenge started |
| `endDate` | DateTime? | When it ended (null if active) |
| `isActive` | bool | Currently running |
| `isCompleted` | bool | Successfully finished all 75 days |
| `currentDay` | int | Current day (1–totalDaysTarget) |
| `resetMode` | String | `hard` or `soft` |
| `totalDaysTarget` | int | Default 75, configurable for soft mode |
| `failureReason` | String? | Why the challenge was reset |
| `failedChallenges` | List\<String\>? | Task titles that caused the reset |

### 7.3 DailyProgress

| Field | Type | Description |
|---|---|---|
| `date` | DateTime | The day this progress is for |
| `challengeCompletions` | Map\<String, bool\> | `challengeId → completed` |
| `isCompleted` | bool | All hard tasks done for this day |
| `journalNote` | String? | Daily reflection text |
| `taskNotes` | Map\<String, String\>? | `challengeId → note` |
| `taskPhotos` | Map\<String, String\>? | `challengeId → photo path` |

---

## 8. Cloud Sync & Security

### 8.1 Authentication
- Anonymous Firebase sign-in (no personal data required)
- UID used as encryption key seed

### 8.2 Encryption
- Algorithm: AES-256
- Key derivation: From Firebase UID
- Encrypted data: Sessions, daily progress, metadata
- Storage: Firebase Firestore under user UID path

### 8.3 Backup Flow
1. User taps "Backup to Cloud" on Profile screen
2. App serializes all sessions and progress to JSON
3. JSON encrypted with AES-256
4. Encrypted payload uploaded to Firestore

### 8.4 Restore Flow
1. User taps "Restore from Cloud" on Profile screen
2. App downloads encrypted payload from Firestore
3. Decrypts with AES-256
4. Replaces local Hive data with restored data

### 8.5 Photo Storage
- Photos uploaded to **Cloudinary** (cloud: `dudjztvui`, preset: `jiremalisamajapp-prod`, folder: `task_proofs`)
- Image capture: 1024×1024, 80% JPEG quality; compression: 1080×1080, quality 80
- `secure_url` stored in Firestore `accountability_tasks.{id}.proofUrl`
- Displayed via `Image.network(proofUrl)` in `ProofReviewDialog`
- Firebase Storage is NOT used for proof images

---

## 9. Services & Integrations

| Service | Purpose |
|---|---|
| **SmartNotificationService** | Primary notification scheduling (reminders, night summary, events) |
| **NotificationService** | Legacy notification service (daily motivation, test notifications) |
| **CloudSyncService** | AES-256 encrypted backup/restore via Firestore |
| **ConnectivityService** | Lazy Firebase init, retry on connectivity change |
| **FCMService** | Firebase Cloud Messaging, subscribes to `all_users` topic |
| **PhotoSyncService** | Camera/gallery image picker, Cloudinary upload |
| **AnalyticsService** | Firebase Analytics events (session start, task completion, resets) |
| **SimpleBackgroundCheckService** | Missed-day detection on app open/resume |
| **ChallengeIconService** | 50+ predefined icons in 7 categories, keyword auto-detection |
| **DynamicColorService** | 25+ colors, 16 gradients, hash-based color selection |
| **TaskTemplates** | 20+ predefined task templates grouped by category |

### External APIs

| API | Usage | Timeout | Fallback |
|---|---|---|---|
| ZenQuotes (`zenquotes.io/api/random`) | Daily motivational quote | 5 seconds | 15 hardcoded quotes, rotated by day of month |

---

## 10. Configuration Options

### 10.1 Per-Task Reminder Settings

| Setting | Options |
|---|---|
| Reminder type | Once, Multiple, Hourly, Interval, Custom |
| Time | Any HH:MM (24-hour) |
| Time window | Start hour (0–23), End hour (0–23) |
| Night reminders | On/Off (controls 10 PM – 6 AM) |
| Interval | 15 min, 30 min, 1 hr, 2 hr, 3 hr, 4 hr, 6 hr, 8 hr, 12 hr |

### 10.2 Task Customization

| Setting | Options |
|---|---|
| Icon | 50+ predefined icons across 7 categories |
| Custom image | Camera or gallery |
| Color | 19 vibrant colors |
| Category | Fitness, Health, Learning, Productivity, Lifestyle, Social, General |
| Photo required | On/Off |

### 10.3 App Settings

| Setting | Location |
|---|---|
| Reminder config per task | Settings screen |
| Motivational quote preview | Settings screen |
| Manual reset | Settings → Danger Zone |
| Data export (JSON) | Settings screen |
| Cloud backup/restore | Profile screen |

---

## 11. Business Rules & Logic

### 11.1 Day Counter Calculation

```
currentDay = (today - startDate).inDays + 1
result = currentDay.clamp(1, session.totalDaysTarget)
```

- Day 1 = start date
- Clamped to `totalDaysTarget` (75 for hard mode, configurable for soft)
- Computed dynamically, not stored

### 11.2 Daily Completion Check

A day is marked `isCompleted = true` when all **hard** tasks in `challengeCompletions` are `true`.

### 11.3 Missed Day Reset (Hard Mode)

```
for each day from startDate to yesterday:
  if progress is null OR any hard task is not completed:
    → reset session (failureReason = "Missed day X", failedChallenges = [task titles])
    → send failure notification
    → break
```

### 11.4 Midnight Timer

- A timer fires at midnight to trigger a fresh data load
- Ensures the day counter advances and new progress record is created

### 11.5 Notification Scheduling

- On session load, all reminders are rescheduled for active tasks
- On task completion, that task's reminders are cancelled
- On challenge reset/completion, all notifications are cancelled
- Night summary is rescheduled daily based on pending tasks

### 11.6 Task Limits

- Minimum 1 task per challenge
- Maximum 10 tasks per challenge
- Maximum 400 scheduled notifications

---

## 12. Theming & UI

### 12.1 Color Palette

| Role | Color | Hex |
|---|---|---|
| Primary | Orange | `#FFA726` |
| Secondary | Orange-Red | `#FF7043` |
| Accent | Pink | `#EC407A` |
| Background gradient | Orange → Orange-Red → Pink | — |

### 12.2 Typography

| Usage | Font | Weight |
|---|---|---|
| Display / Headings | Poppins | Bold / Semi-bold |
| Body text | Inter | Regular |

### 12.3 UI Components

- Glassmorphic task cards with blur effects
- Animated progress indicators
- Staggered list animations on load
- Smooth scale/fade transitions
- Custom gradient app bar
- Horizontal scrolling date picker
- Bottom sheets for journal and reminders

---

## 13. Edge Cases & Constraints

| Scenario | Expected Behavior |
|---|---|
| App opened offline | All features work locally; Firebase init fails silently; retries when online |
| Timezone change | Notifications use device timezone; mapped from UTC offset at init |
| Notification limit reached (400) | New reminders silently skipped; existing ones continue |
| Past day with no progress data | Treated as all tasks incomplete (triggers reset in hard mode) |
| Day 75 reached | Completion check runs; if all days complete → success notification |
| Day 76+ (soft mode) | Day counter continues up to `totalDaysTarget` |
| Multiple sessions in history | All stored and viewable; only one active at a time |
| App backgrounded then resumed | Background check service runs missed-day detection |
| Photo upload fails | Error caught silently; task can still be completed without photo |
| ZenQuotes API down | Falls back to 15 hardcoded motivational quotes |
| Firebase init timeout (5s) | Fails silently; cloud features disabled until retry |
| Manual reset during active session | Confirmation required; session marked inactive; new session on next start |

---

## 14. QA Testing Checklist

### 14.1 Onboarding & Challenge Setup

- [ ] First launch shows onboarding screen
- [ ] Can add 1–10 tasks with title, icon, color, type
- [ ] Task templates load and can be selected
- [ ] Icon picker shows all 7 categories with 50+ icons
- [ ] Custom image upload works (camera and gallery)
- [ ] Color picker shows 19 options
- [ ] Reminder configuration works for all 5 types
- [ ] Review page shows all configured tasks
- [ ] Starting challenge creates session and navigates to Home
- [ ] Cannot start with 0 tasks

### 14.2 Daily Task Management

- [ ] Home screen shows correct current day
- [ ] Progress stats card shows accurate completion % and streak
- [ ] Date picker scrolls through all days (1–75)
- [ ] Today's tasks are toggleable (on/off)
- [ ] Past days are read-only
- [ ] Future days show no data
- [ ] Task completion triggers animation
- [ ] Journal FAB opens bottom sheet
- [ ] Journal notes save and persist
- [ ] Per-task notes save and persist
- [ ] Photo attachment works and displays

### 14.3 Hard Mode — Missed Day Detection

- [ ] Missing a hard task yesterday → reset on next app open
- [ ] Missing a hard task 3 days ago → reset on next app open
- [ ] Missing a soft task → no reset
- [ ] Missing a regular task → no reset
- [ ] Reset notification shows correct day and failed tasks
- [ ] Session marked inactive with failure reason
- [ ] Re-entrant check guard prevents duplicate resets

### 14.4 Soft Mode

- [ ] Missing any task → no reset, challenge continues
- [ ] Day counter goes beyond 75 if `totalDaysTarget > 75`
- [ ] Missed-day detection is skipped entirely

### 14.5 Challenge Completion

- [ ] Completing all 75 days → completion notification
- [ ] Session marked as completed with end date
- [ ] History shows completed session

### 14.6 Notifications

- [ ] Once reminder fires at specified time
- [ ] Multiple reminders fire at all specified times
- [ ] Hourly reminders fire every hour from start until 11 PM
- [ ] Interval reminders fire at correct intervals until 10 PM
- [ ] Night summary at 10 PM, 11 PM, 11:45 PM with pending tasks
- [ ] Night summary not sent when all tasks complete
- [ ] Daily motivation at 8 AM (online quote or offline fallback)
- [ ] Failure notification on reset
- [ ] Completion notification on day 75
- [ ] Completing a task cancels its reminders
- [ ] Resetting challenge cancels all notifications
- [ ] Time window filtering works (reminders outside window skipped)
- [ ] Night reminder toggle works (10 PM – 6 AM)
- [ ] Notification limit (400) prevents over-scheduling

### 14.7 Regular Tasks Tab

- [ ] Regular tasks displayed with stats
- [ ] Toggle completion for today
- [ ] Streak calculation is correct
- [ ] Best streak tracks highest streak
- [ ] Water intake tracker shows hourly grid (6 AM – 11 PM)
- [ ] Water intake taps register and persist
- [ ] Add new regular task works

### 14.8 Cloud Sync

- [ ] Anonymous Firebase sign-in works
- [ ] Backup encrypts and uploads data
- [ ] Restore downloads and decrypts data
- [ ] Restored data matches original
- [ ] Backup/restore works after app restart
- [ ] Offline state shows appropriate messaging
- [x] Photo upload to Cloudinary works (Firebase Storage not used)

### 14.9 History & Profile

- [ ] History shows all past sessions
- [ ] Completed sessions show success info
- [ ] Reset sessions show failure reason and failed tasks
- [ ] Session cards expand/collapse
- [ ] Profile shows correct journey stats
- [ ] Completion rate calculation is accurate

### 14.10 Settings

- [ ] Per-task reminder reconfiguration works
- [ ] Motivational quote preview loads
- [ ] Manual reset requires confirmation
- [ ] Manual reset clears current session
- [ ] Data export generates valid JSON
- [ ] Privacy policy screen loads

### 14.11 Edge Cases

- [ ] App works fully offline
- [ ] Timezone change doesn't break notifications
- [ ] App resume after background triggers missed-day check
- [ ] 400 notification limit handled gracefully
- [ ] Empty challenge list prevented
- [ ] Day 75 boundary handled correctly
- [ ] Multiple rapid task toggles don't corrupt state
- [ ] Large journal notes save correctly
- [ ] Special characters in task titles handled

### 14.12 UI & Performance

- [ ] Animations are smooth (no jank)
- [ ] Staggered list animations play on load
- [ ] Glassmorphic cards render correctly
- [ ] Gradient app bar displays properly
- [ ] Bottom sheets open/close smoothly
- [ ] Date picker scrolls smoothly
- [ ] No layout overflow on small screens
- [ ] Loading states shown during async operations
