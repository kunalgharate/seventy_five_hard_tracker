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

## Visual Polish (Priority: Medium) — remaining

### Clean Card Style
- [ ] Replace glassmorphism task cards with clean white cards
- [ ] Update page backgrounds from gradient to light grey
- [ ] Per-task colored icons
- [ ] Consistent card border radius

### Dark Mode
- [ ] Verify all screens use theme-aware colors
- [ ] Update home_screen background for dark mode
- [ ] Test all new widgets in dark mode

## Cleanup (Priority: Low) — remaining
- [ ] Remove dead _InvitePartnerSheet code
- [ ] Remove dead _JoinWithCodeSheet code
- [ ] Remove dead _ReviewSheet code
- [ ] Run dart format on all files
