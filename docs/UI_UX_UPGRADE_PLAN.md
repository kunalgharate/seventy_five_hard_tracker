# DailyMettle UI/UX Upgrade Plan

**Based on:** Figma/Make design files (Design Daily Metal App)
**Date:** September 28, 2026
**Status:** Draft — awaiting approval

---

## 1. Design Overview

The new design is a modern, clean, mobile-first interface with:
- Warm orange-red-pink gradient hero cards
- Soft white/grey card-based layout
- Colorful task icons (blue, purple, coral, pink)
- 6-tab bottom navigation (up from 4)
- Review notification cards inline on home screen
- Motivational quote banner at the bottom
- "Squad" replaces "Accountability/Partners"

---

## 2. Current App vs Design — Gap Analysis

### 2.1 Navigation (Bottom Tabs)

| Current (4 tabs) | Design (6 tabs) | Status |
|-------------------|-----------------|--------|
| 🏋️ 75 Hard | 🏠 **Today** | Rename + redesign |
| ✅ Daily Tasks | ☑️ **Habits** | Rename + merge |
| 👥 Partners | 👥 **Squad** | Rename + redesign |
| 👤 Profile | 👤 **Account** | Rename |
| ❌ (none) | 📓 **Journal** | **NEW TAB** |
| ❌ (none) | 📊 **Insights** | **NEW TAB** |

**Action:** Restructure `MainNavigationScreen` from 4 to 6 tabs.

### 2.2 Today Screen (Home)

| Element | Current | Design | Gap |
|---------|---------|--------|-----|
| Greeting | ❌ None | ✅ "Good morning, Alex" with avatar + date | **NEW** |
| Notification bell | ❌ None | ✅ Bell icon top-right | **NEW** |
| Challenge hero card | ✅ Exists (basic) | ✅ Gradient card with "57 days to go", % ring, streaks | **REDESIGN** — add circular progress, streak row |
| Review notifications | ❌ None | ✅ "Priya approved your Drink 3L water ✓" cards | **NEW** — inline between hero and tasks |
| Task list header | ❌ None | ✅ "Today's focus" with "1 of 3 complete" + "View plan" | **NEW** |
| Task cards | ✅ Exists (glassmorphism) | ✅ Clean white cards with colored icons + checkbox | **REDESIGN** — simpler, cleaner style |
| Daily reflection card | ❌ None | ✅ Pink card with "Daily reflection" → chevron | **NEW** |
| Motivational quote | ❌ Shows in dialog | ✅ Inline banner at bottom | **MOVE** — from dialog to inline |

### 2.3 Habits Screen (Regular Tasks)

| Element | Current | Design | Gap |
|---------|---------|--------|-----|
| Tab name | "Daily Tasks" | "Habits" | Rename |
| Weekly calendar | ❌ None | ✅ Weekly completion dots/calendar | **NEW** |
| Filter chips | ❌ None | ✅ "Daily / Weekly / Challenge" filter | **NEW** |
| Habit cards | ✅ Exists | ✅ With streak, performance indicator | **ENHANCE** |
| Active challenge summary | ❌ None | ✅ Challenge card in habits tab | **NEW** |

### 2.4 Journal Screen — **ENTIRELY NEW**

| Element | Status |
|---------|--------|
| Mood selector (emoji row) | **NEW** |
| Daily reflection text field | **NEW** |
| Previous journal entries list | **NEW** |
| Per-day and per-task notes | Exists in data model, needs dedicated UI |

### 2.5 Insights Screen — **ENTIRELY NEW**

| Element | Status |
|---------|--------|
| Completion rate chart | **NEW** |
| Streak history graph | **NEW** |
| Task performance breakdown | **NEW** |
| Weekly/monthly view toggle | **NEW** |
| Leaderboard (squad comparison) | **NEW** |

### 2.6 Squad Screen (Accountability → Squad)

| Element | Current | Design | Gap |
|---------|---------|--------|-----|
| Tab name | "Partners" / "Accountability" | "Squad" | Rename |
| Stats banner | ❌ None | ✅ 4-stat row (partners, shared tasks, approved, pending) | **NEW** |
| Reviewers row | ✅ Partner cards (expandable) | ✅ Horizontal scrollable avatars + "Add" | **REDESIGN** |
| Leaderboard | ❌ None | ✅ Ranked by streak | **NEW** |
| Create task card | ❌ Via collaborator dialog | ✅ Prominent "Create task" card | **NEW** |
| Invite partner | ✅ Email sheet | ✅ "Invite partner" card | **KEEP** (already simplified) |
| Task review list | ✅ Reviews tab | ✅ Cards with approve/reject | **KEEP** |
| Task detail sheet | ❌ Basic | ✅ Full detail with comment thread | **ENHANCE** |

### 2.7 Account Screen (Profile)

| Element | Current | Design | Gap |
|---------|---------|--------|-----|
| Tab name | "Profile" | "Account" | Rename |
| Content | ✅ Stats + settings + cloud sync | Same | **KEEP** mostly |

---

## 3. Visual Design System Changes

### 3.1 Colors
| Token | Current | Design | Action |
|-------|---------|--------|--------|
| Primary gradient | Orange (#FFA726) | Orange → Red → Pink gradient | Update |
| Card background | Glassmorphism blur | Clean white (`#FFFFFF`) | Simplify |
| Page background | Blue/purple gradient | Light grey (`#F5F5F5`) | Simplify |
| Task icon colors | Grey/orange | Blue, Purple, Coral, Pink per task | Add per-task color |
| Text primary | Grey[800] | Dark grey/black | Keep |
| Text secondary | Grey[600] | Grey[500] | Keep |
| Success | Green | Green (`#4CAF50`) | Keep |

### 3.2 Typography
| Element | Current | Design |
|---------|---------|--------|
| Greeting | N/A | Bold, 24px, Poppins |
| Section headers | Mixed | Semi-bold 18px "Today's focus" |
| Task title | 15px w600 | 16px w600 |
| Subtitle | 11px | 13px grey |
| Font family | Poppins + Inter | Keep (matches) |

### 3.3 Components
| Component | Current | Design | Action |
|-----------|---------|--------|--------|
| Task card | Glassmorphism + checkbox | White card + colored icon + circular checkbox | **REDESIGN** |
| Challenge hero | Basic progress bar | Gradient card + circular % + streak row | **REDESIGN** |
| Bottom nav | 4 items, Material icons | 6 items, outlined icons, "Today" label | **RESTRUCTURE** |
| Notification cards | None | White card with avatar + action icon | **NEW** |
| Quote banner | Dialog popup | Inline warm-toned banner | **MOVE** |

---

## 4. New Features Required

### 4.1 Journal Tab (Priority: High)
- Mood emoji selector (😊 😐 😢 😤 🤩)
- Daily reflection text area
- Journal entry list (scrollable, by date)
- Data: leverage existing `journalNote` field in DailyProgress + add `mood` field

### 4.2 Insights Tab (Priority: Medium)
- Completion rate line/bar chart (use `fl_chart` package)
- Streak trend visualization
- Task-level performance breakdown
- Weekly vs monthly toggle
- Squad leaderboard (who has the longest streak)

### 4.3 Squad Leaderboard (Priority: Medium)
- Ranked list of all partners by current streak
- Show avatar, name, streak count, completion %
- Data: read from `public_progress` collection

### 4.4 Notification Cards on Today Screen (Priority: High)
- Show recent review activity inline: "Priya approved your task ✓"
- Pull from `fcm_notifications` collection, display last 2-3
- Dismissible

### 4.5 Greeting Header (Priority: Low)
- "Good morning/afternoon/evening, [Name]"
- Date display
- Notification bell icon with badge count

---

## 5. Implementation Phases

### Phase A: Navigation Restructure + Naming (1 day)
1. Rename tabs: 75 Hard → Today, Daily Tasks → Habits, Partners → Squad, Profile → Account
2. Add 2 new tabs: Journal, Insights (placeholder screens)
3. Update `MainNavigationScreen` to 6 tabs
4. Update bottom nav icons to outlined style

### Phase B: Today Screen Redesign (2-3 days)
5. Add greeting header with avatar + date + notification bell
6. Redesign challenge hero card (gradient, circular %, streaks)
7. Add review notification cards between hero and tasks
8. Redesign task cards (white, colored icons, cleaner)
9. Add "Today's focus" header with count + "View plan"
10. Add daily reflection card
11. Move motivational quote to inline banner

### Phase C: Journal Tab (1-2 days)
12. Create `journal_screen.dart` with mood selector
13. Daily reflection text input
14. Journal entry history list
15. Add `mood` field to DailyProgress model

### Phase D: Insights Tab (2-3 days)
16. Create `insights_screen.dart`
17. Completion rate chart (add `fl_chart` dependency)
18. Streak trend visualization
19. Task performance breakdown
20. Weekly/monthly toggle

### Phase E: Squad Redesign (1-2 days)
21. Add stats banner (partners, shared, approved, pending)
22. Horizontal reviewer scroll row with "Add" card
23. Leaderboard section
24. Prominent "Create task" card

### Phase F: Visual Polish (1-2 days)
25. Update color scheme to match design gradients
26. Replace glassmorphism with clean white cards
27. Update page backgrounds to light grey
28. Per-task colored icons
29. Consistent spacing and typography

---

## 6. Dependencies to Add

```yaml
# For charts in Insights tab
fl_chart: ^0.70.0
```

---

## 7. Files to Create

| File | Description |
|------|-------------|
| `lib/screens/journal_screen.dart` | Journal tab with mood + reflection |
| `lib/screens/insights_screen.dart` | Insights tab with charts |
| `lib/widgets/greeting_header.dart` | "Good morning, Alex" + date + bell |
| `lib/widgets/challenge_hero_card.dart` | Gradient hero with circular progress |
| `lib/widgets/review_notification_card.dart` | Inline review notification |
| `lib/widgets/task_card_v2.dart` | Redesigned clean task card |
| `lib/widgets/motivation_banner.dart` | Inline quote banner |

## 8. Files to Modify

| File | Changes |
|------|---------|
| `main_navigation_screen.dart` | 4 → 6 tabs, rename labels, new icons |
| `home_screen.dart` | Add greeting, hero redesign, notification cards, new task cards |
| `accountability_screen.dart` | Rename to Squad, add stats + leaderboard + horizontal scroll |
| `regular_tasks_screen.dart` | Rename to Habits, add weekly calendar + filters |
| `profile_screen.dart` | Rename to Account |
| `models/daily_progress.dart` | Add `mood` field |

---

## 9. Effort Estimate

| Phase | Effort | Priority |
|-------|--------|----------|
| A: Navigation | 1 day | 🔴 Do first |
| B: Today redesign | 2-3 days | 🔴 High |
| C: Journal | 1-2 days | 🟡 Medium |
| D: Insights | 2-3 days | 🟡 Medium |
| E: Squad redesign | 1-2 days | 🟡 Medium |
| F: Visual polish | 1-2 days | 🟢 Low |
| **Total** | **~10-13 days** | |

---

## 10. What NOT to Change

- Core challenge logic (hard/soft mode, reset, completion)
- Cloud sync / encryption
- Firestore security rules
- Notification scheduling system
- The review system we just built (Phase 1-4)
- Data models (except adding `mood` field)

---

**Next step:** Approve this plan, then I start with Phase A (navigation restructure).
