# UI/UX Upgrade — Remaining TODO

## Data Wiring — DONE ✅

### Journal Screen ✅
- [x] Save mood + reflection to DailyProgress via ChallengeBloc
- [x] Mood stored as emoji prefix in journalNote (no Hive migration)
- [x] Load previous journal entries from repository
- [x] Real data replaces placeholder entries

### Insights Screen ✅
- [x] Completion rate from real progress data
- [x] Streak data computed from progress history
- [x] Task performance per challenge with progress bars
- [x] Weekly trend from last 7 days real data

### Today Screen Notifications ✅
- [x] Load recent notifications from fcm_notifications collection
- [x] Populate _recentNotifications in initState
- [x] Fetch daily quote from QuotesService

## Visual Polish (Priority: Medium) — DONE ✅

### Clean Card Style ✅
- [x] Replace glassmorphism task cards with clean white cards
      (daily_task_card.dart: _buildCleanCard, theme-aware surface + soft shadow)
- [x] Update page backgrounds from gradient to light grey (#F5F5F5, theme-aware)
      (home_screen + regular_tasks_screen; journal/insights already had it)
- [x] Per-task colored icons (AnimatedChallengeIcon + colored left accent bar
      via DynamicColorService)
- [x] Consistent card border radius (kCardRadius = 16)

### Dark Mode ✅
- [x] Verify all screens use theme-aware colors
- [x] Update home_screen background for dark mode (grey900 in dark)
- [x] Test all new widgets in dark mode
- [x] Added darkTheme + themeMode: ThemeMode.system in main.dart so the
      existing isDark checks are now functional

## Cleanup (Priority: Low) — DONE ✅
- [x] Remove dead _JoinWithCodeSheet code (class + dead _showJoinSheet caller)
- [x] Remove dead _showInviteSheet caller (unused)
- [~] _InvitePartnerSheet KEPT — still reachable via the live "Use invite code
      instead" fallback button in _InviteByEmailSheet (not dead)
- [~] _ReviewSheet KEPT — still wired to the live "Review Progress" popup menu
      item via _onMenu (not dead)
- [x] Run dart format on all changed files
- [x] flutter test: 106 passed, 1 skipped (pre-existing), 0 failed
- [x] flutter analyze lib/: no issues
