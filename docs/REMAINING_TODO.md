# UI/UX Upgrade — Remaining TODO

## Data Wiring (Priority: High)

### Journal Screen
- [ ] Save mood + reflection to DailyProgress via ChallengeBloc
- [ ] Add `mood` field to DailyProgress model + Hive adapter
- [ ] Load previous journal entries from repository
- [ ] Replace placeholder entries with real data

### Insights Screen  
- [ ] Load completion rate from DatabaseRepository
- [ ] Load streak data from progress history
- [ ] Load task performance from daily completions
- [ ] Build weekly trend from real 7-day data
- [ ] Load squad leaderboard from public_progress collection
- [ ] Add `fl_chart` dependency for proper charts (optional)

### Today Screen Notifications
- [ ] Load recent review notifications from fcm_notifications collection
- [ ] Populate _recentNotifications in home_screen initState
- [ ] Fetch daily quote from QuotesService instead of hardcoded string

## Visual Polish (Priority: Medium)

### Clean Card Style
- [ ] Replace glassmorphism task cards with clean white cards
- [ ] Update page backgrounds from gradient to light grey (#F5F5F5)
- [ ] Per-task colored icons (blue=water, purple=read, coral=workout, pink=reflect)
- [ ] Consistent card border radius (14-16px throughout)

### Dark Mode
- [ ] Verify all screens use theme-aware colors
- [ ] Update home_screen background for dark mode
- [ ] Update calendar card for dark mode
- [ ] Test all new widgets in dark mode

### Typography
- [ ] Ensure "Today's focus" header with "X of Y complete" + "View plan"
- [ ] Consistent font sizes across all task cards

## Cleanup (Priority: Low)
- [ ] Remove dead _InvitePartnerSheet code from accountability_screen.dart
- [ ] Remove dead _JoinWithCodeSheet code
- [ ] Remove dead _ReviewSheet code
- [ ] Remove unused invite_codes references
- [ ] Run dart format on all changed files
