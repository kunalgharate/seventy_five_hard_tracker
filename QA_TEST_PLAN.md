# 75 Hard Challenge — QA Test Plan

## 1. Challenge Setup (Onboarding)

| ID | Test Case | Steps | Expected Result | Priority |
|---|---|---|---|---|
| TC-CS-001 | Create challenge with title | 1. Open app with no active challenge 2. Tap "Create 75 Hard Challenge" 3. Enter title for challenge 1 | Title appears in the card, "Ready for 75 days!" badge shows | High |
| TC-CS-002 | Add multiple challenges | 1. On setup page, tap "+ Add Challenge" 2. Repeat up to 10 challenges | Each challenge gets its own card, counter updates (e.g., "3 of 5 challenges ready") | High |
| TC-CS-003 | Remove a challenge | 1. Create 3+ challenges 2. Tap the remove/delete button on a challenge | Challenge is removed, remaining challenges reindex | Medium |
| TC-CS-004 | Max 10 challenges limit | 1. Add 10 challenges | "Add Challenge" button disappears at 10 | Low |
| TC-CS-005 | Select predefined icon | 1. Tap icon area on a challenge card 2. In Icons tab, tap any icon | Icon updates on the challenge card immediately | High |
| TC-CS-006 | Select camera image as icon | 1. Tap icon area 2. Go to Image tab 3. Tap Camera, take photo | Photo appears as the challenge icon | Medium |
| TC-CS-007 | Select gallery image as icon | 1. Tap icon area 2. Go to Image tab 3. Tap Gallery, pick image | Image appears as the challenge icon | Medium |
| TC-CS-008 | Remove camera image and switch to icon | 1. Set a camera image as icon 2. Tap icon area again 3. Tap "Remove Image" 4. Go to Icons tab, select an icon | Image is cleared, predefined icon is set | High |
| TC-CS-009 | Change icon color | 1. Tap icon area 2. Go to Color tab 3. Tap any color | Icon background color updates to selected color | High |
| TC-CS-010 | Color persists after icon change | 1. Select a red color 2. Switch to Icons tab, pick a different icon | New icon uses the red color | Medium |
| TC-CS-011 | Set task type to Hard | 1. On challenge card, select "Hard" task type | Task type badge shows "Hard" | High |
| TC-CS-012 | Set task type to Soft | 1. Select "Soft" task type | Task type badge shows "Soft", no reset on miss | Medium |
| TC-CS-013 | Set task type to Regular | 1. Select "Regular" task type | Task type badge shows "Regular" | Medium |
| TC-CS-014 | Configure once reminder | 1. Tap reminder button 2. Enable reminders 3. Select "Once" type 4. Pick time 5. Save | Reminder shows configured time on challenge card | High |
| TC-CS-015 | Configure hourly reminder | 1. Set reminder type to "Every Hour" 2. Set start time 3. Save | Reminder description shows hourly config | Medium |
| TC-CS-016 | Configure interval reminder | 1. Set reminder type to "Every X Hours" 2. Select interval (e.g., 2 hours) 3. Set start time 4. Save | Reminder description shows interval config | Medium |
| TC-CS-017 | Configure multiple reminders | 1. Set type to "Multiple Times" 2. Add 2-3 times 3. Save | All times saved and shown | Medium |
| TC-CS-018 | Configure custom reminder | 1. Set type to "Custom Schedule" 2. Add custom times 3. Save | Custom times saved | Low |
| TC-CS-019 | Save reminder button fully visible | 1. Open reminder setup 2. Scroll to bottom | "Save Reminder Settings" button is fully visible, not cut off | High |
| TC-CS-020 | Review page shows all challenges | 1. Set up 3 challenges with titles 2. Navigate to review page | All 3 challenges listed with icons, titles, reminder info | High |
| TC-CS-021 | Start challenge | 1. Complete setup 2. Tap "Start Challenge" on review page | Navigates to home screen with active session, Day 1 | High |
| TC-CS-022 | Use template challenges | 1. On setup page, tap template picker 2. Select a template | Challenge fields auto-fill from template | Medium |

## 2. Daily Tasks (75 Hard Challenge)

| ID | Test Case | Steps | Expected Result | Priority |
|---|---|---|---|---|
| TC-DT-001 | View today's tasks | 1. Open app with active challenge | All non-regular tasks shown for today with toggle buttons | High |
| TC-DT-002 | Check task (mark complete) | 1. Tap checkbox on an incomplete task | Checkbox turns green immediately (no delay), "Completed ✓" status | High |
| TC-DT-003 | Uncheck task | 1. Tap checkbox on a completed task | Checkbox unchecks immediately, status reverts | High |
| TC-DT-004 | Check speed matches uncheck speed | 1. Toggle a task on 2. Toggle it off 3. Compare response times | Both check and uncheck respond instantly (under 200ms perceived) | High |
| TC-DT-005 | Navigate to past date | 1. Tap a past date in the horizontal date picker | Tasks for that date shown with completion status (read-only) | Medium |
| TC-DT-006 | Navigate to future date | 1. Tap a future date | Message: "Future date - complete today's tasks first!" | Low |
| TC-DT-007 | All tasks completed indicator | 1. Complete all hard/soft tasks for today | Green "All tasks completed!" banner, check icon in header | High |
| TC-DT-008 | Progress stats display | 1. View home screen with active session | Progress stats show current day, total days, session info | Medium |
| TC-DT-009 | Add task note | 1. Tap note icon on a task 2. Enter text 3. Tap "Save Note" | Note saved, icon changes to filled note icon | High |
| TC-DT-010 | View existing task note | 1. Add a note to a task 2. Tap note icon again | Previously entered note text is displayed in the text field | High |
| TC-DT-011 | Add journal entry | 1. Tap "Add Journal" FAB 2. Enter text 3. Tap "Save" | Journal saved, FAB changes to "View Journal" | High |
| TC-DT-012 | View existing journal | 1. Add a journal entry 2. Tap "View Journal" FAB | Previously entered journal text is displayed | High |
| TC-DT-013 | Delete journal entry | 1. Open existing journal 2. Tap delete icon | Journal cleared, FAB reverts to "Add Journal" | Medium |
| TC-DT-014 | Date progress indicator | 1. Complete some tasks 2. Check date progress bar | Shows "Some tasks incomplete" (red) or "All tasks completed!" (green) | Medium |
| TC-DT-015 | Selected day resets after restart | 1. Restart challenge from history 2. Check home screen | Selected day is today (not stuck on old date) | High |

## 3. Regular Tasks

| ID | Test Case | Steps | Expected Result | Priority |
|---|---|---|---|---|
| TC-RT-001 | Create regular task | 1. Go to Daily Tasks tab 2. Tap + button 3. Enter title 4. Set reminder 5. Tap "Create Task" | Task appears in the list | High |
| TC-RT-002 | Reminder required for creation | 1. Enter title but don't set reminder 2. Tap "Create Task" | Error message: "Please set a reminder before creating the task" | Medium |
| TC-RT-003 | Toggle regular task complete | 1. Tap checkbox on a regular task | Checkbox fills green immediately | High |
| TC-RT-004 | Toggle speed is fast | 1. Check a regular task 2. Observe response time | Check responds instantly (no noticeable delay) | High |
| TC-RT-005 | Edit task title | 1. Tap three-dot menu on a task 2. Tap "Edit Task" 3. Change title 4. Tap "Save Changes" | Title updates in the list | High |
| TC-RT-006 | Edit task icon | 1. Edit a task 2. Tap icon area 3. Select new icon | Icon updates after save | Medium |
| TC-RT-007 | Edit task icon color | 1. Edit a task 2. Tap icon area 3. Go to Color tab 4. Select color 5. Save | Icon color updates | High |
| TC-RT-008 | Delete task with confirmation | 1. Tap three-dot menu 2. Tap "Delete Task" 3. Confirm in dialog | Task removed from list | High |
| TC-RT-009 | Cancel delete | 1. Tap three-dot menu 2. Tap "Delete Task" 3. Tap "Cancel" | Task remains, dialog dismissed | Medium |
| TC-RT-010 | Long-press shows options | 1. Long-press on a task card | Bottom sheet with Edit/Delete options appears | Medium |
| TC-RT-011 | Summary header shows progress | 1. Have 4 tasks, complete 2 | Header shows "2 of 4 completed today" in orange | Medium |
| TC-RT-012 | Summary header all done | 1. Complete all regular tasks | Header shows "All N tasks done today!" in green | Medium |
| TC-RT-013 | Streak display | 1. Complete a task for 3 consecutive days | Inline text shows "🔥 3d streak" | Medium |
| TC-RT-014 | Best streak display | 1. Have a historical best streak of 5 | Inline text shows "🏆 5d best" | Low |
| TC-RT-015 | Tasks persist after app restart | 1. Create tasks 2. Close app completely 3. Reopen | All tasks visible | High |
| TC-RT-016 | Tasks show on tab switch | 1. Be on 75 Hard tab 2. Tap Daily Tasks tab | Regular tasks load and display immediately | High |
| TC-RT-017 | Three-dot menu on right side | 1. View regular task list | Menu icon (⋯) is on the right side of each task row | Medium |
| TC-RT-018 | Set icon via add sheet | 1. Create new task 2. Tap icon area 3. Select icon and color | Icon and color appear on the task after creation | Medium |

## 4. Notifications

| ID | Test Case | Steps | Expected Result | Priority |
|---|---|---|---|---|
| TC-NF-001 | Per-task once reminder fires | 1. Set a "once" reminder for 2 min from now 2. Wait | Single notification at the set time | High |
| TC-NF-002 | Per-task hourly reminder fires | 1. Set "hourly" reminder 2. Wait for next hour | Notification fires each hour until task done | Medium |
| TC-NF-003 | Reminder cancelled on task complete | 1. Set a reminder 2. Complete the task before reminder time | No notification fires | High |
| TC-NF-004 | Night summary — single notification | 1. Have pending tasks 2. Wait until 11:30 PM (or latest reminder time) | Exactly ONE notification listing pending tasks | High |
| TC-NF-005 | Night summary — task names listed | 1. Have 3 pending tasks 2. Receive night summary | Notification body lists all 3 task names with bullet points | High |
| TC-NF-006 | Night summary — reset warning | 1. Receive night summary notification | Body includes "⚠️ Missing these will reset your challenge!" | High |
| TC-NF-007 | Night summary — timing with early reminders | 1. All task reminders at 5PM or earlier 2. Wait | Notification fires at 11:30 PM | Medium |
| TC-NF-008 | Night summary — timing with late reminder | 1. One task reminder at 11:45 PM 2. Wait | Notification fires at 11:45 PM (not 11:30) | Medium |
| TC-NF-009 | Night summary — no notification when all done | 1. Complete all tasks before 11:30 PM | No night summary notification | High |
| TC-NF-010 | Night summary — not sent multiple times | 1. Toggle tasks on/off multiple times | Only one night summary scheduled (not accumulating) | Medium |
| TC-NF-011 | Daily motivation at 8 AM | 1. Have active challenge 2. Wait until 8:00 AM | Motivational quote notification | Low |
| TC-NF-012 | Completion notification | 1. Complete all tasks for 75 days | Congratulations notification | Low |
| TC-NF-013 | Reset/failure notification | 1. Miss a hard task 2. App detects at next open | Failure notification with day number and failed tasks | Medium |
| TC-NF-014 | Settings — turn off reminder | 1. Go to Settings 2. Toggle off a task's reminder switch | Reminder disabled, no future notifications for that task | High |
| TC-NF-015 | Settings — change reminder time | 1. Go to Settings 2. Tap on a task with reminder 3. Pick new time | Reminder rescheduled to new time | Medium |

## 5. Challenge History

| ID | Test Case | Steps | Expected Result | Priority |
|---|---|---|---|---|
| TC-CH-001 | View empty history | 1. Open history with no past sessions | "No History Yet" empty state | Low |
| TC-CH-002 | View completed session | 1. Complete a challenge 2. Open history | Session card with trophy icon, green "Completed Challenge" | Medium |
| TC-CH-003 | View reset session | 1. Reset a challenge 2. Open history | Session card with refresh icon, red "Reset Challenge" | Medium |
| TC-CH-004 | Session dates and duration | 1. Expand a session card | Start date, end date, duration in days shown | Medium |
| TC-CH-005 | Mode and target days | 1. Expand a session card | "Mode: Hard • Target: 75 days" shown in subtitle | Medium |
| TC-CH-006 | Per-challenge details | 1. Expand a session card | Each challenge shows title, task type badge (Hard/Soft/Regular), category, reminder info | High |
| TC-CH-007 | Reset info — reason and failed tasks | 1. Expand a reset session | Reset reason, "Reset on Day: X", failed task names shown | Medium |
| TC-CH-008 | Completion info | 1. Expand a completed session | "Challenge Completed!" with check icon, "Full 75-day duration completed" | Medium |
| TC-CH-009 | Session stats | 1. Expand any session | Days Completed, Tasks count, Success Rate shown | Low |
| TC-CH-010 | Restart — no active session | 1. Have no active challenge 2. Open history 3. Tap "Restart Challenge" | New session starts immediately, navigates to home, Day 1 with same tasks | High |
| TC-CH-011 | Restart — active session exists | 1. Have active challenge 2. Open history 3. Tap "Restart Challenge" | Confirmation dialog: "Active Challenge in Progress" | High |
| TC-CH-012 | Restart — confirm end and restart | 1. In confirmation dialog, tap "End & Restart" | Current session ended, new session starts, navigates to home | High |
| TC-CH-013 | Restart — cancel | 1. In confirmation dialog, tap "Cancel" | Dialog dismissed, nothing changes | Medium |
| TC-CH-014 | Restart preserves config | 1. Restart a session 2. Check new session | Same challenges, same reset mode, same target days | High |
| TC-CH-015 | Restart clears progress | 1. Restart a session 2. Check home | Day 1, no completed tasks, fresh start | High |

## 6. Settings

| ID | Test Case | Steps | Expected Result | Priority |
|---|---|---|---|---|
| TC-ST-001 | View reminders for active session | 1. Open Settings with active challenge | All challenges listed with reminder toggle and time | Medium |
| TC-ST-002 | Toggle reminder off | 1. Toggle off a challenge's reminder | Switch turns off, "No reminder set" subtitle | High |
| TC-ST-003 | Toggle reminder on | 1. Toggle on a reminder 2. Pick time | Time picker appears, reminder set to chosen time | High |
| TC-ST-004 | Preview motivational quote | 1. Tap "Preview Quote" | Dialog shows a motivational quote | Low |
| TC-ST-005 | Reset current challenge | 1. Tap "Reset Current Challenge" 2. Confirm | Challenge reset, moved to history, home shows no active challenge | High |
| TC-ST-006 | Cancel reset | 1. Tap "Reset Current Challenge" 2. Tap "Cancel" | Nothing changes | Medium |
| TC-ST-007 | Export data | 1. Tap "Export Data" | Dialog shows JSON data with size info | Low |
| TC-ST-008 | View app version | 1. Check About section | Version number displayed | Low |
| TC-ST-009 | Privacy policy link | 1. Tap "Privacy Policy" | Privacy policy screen opens | Low |

## 7. Data Persistence

| ID | Test Case | Steps | Expected Result | Priority |
|---|---|---|---|---|
| TC-DP-001 | Challenge session persists | 1. Create challenge 2. Close app 3. Reopen | Active session with correct day, tasks visible | High |
| TC-DP-002 | Daily progress persists | 1. Complete some tasks 2. Close app 3. Reopen | Completed tasks still checked | High |
| TC-DP-003 | Journal notes persist | 1. Add journal 2. Close app 3. Reopen 4. Open journal | Journal text preserved | High |
| TC-DP-004 | Task notes persist | 1. Add task note 2. Close app 3. Reopen 4. Open note | Note text preserved | High |
| TC-DP-005 | Regular tasks persist independently | 1. Create regular tasks 2. Reset 75 Hard challenge 3. Check Daily Tasks tab | Regular tasks still present | High |
| TC-DP-006 | History persists | 1. Reset a challenge 2. Close app 3. Reopen 4. Check history | Past session visible in history | Medium |
| TC-DP-007 | Regular task completions persist | 1. Complete regular tasks 2. Close app 3. Reopen | Completion status preserved for today | Medium |

## 8. Navigation

| ID | Test Case | Steps | Expected Result | Priority |
|---|---|---|---|---|
| TC-NV-001 | Bottom nav — 75 Hard tab | 1. Tap "75 Hard" tab | Home screen with challenge tasks | High |
| TC-NV-002 | Bottom nav — Daily Tasks tab | 1. Tap "Daily Tasks" tab | Regular tasks screen loads with tasks | High |
| TC-NV-003 | Bottom nav — Profile tab | 1. Tap "Profile" tab | Profile screen loads | Medium |
| TC-NV-004 | History from home | 1. Tap history icon in app bar | History screen opens | Medium |
| TC-NV-005 | Settings from home | 1. Tap settings icon in app bar | Settings screen opens | Medium |
| TC-NV-006 | Back from history | 1. Open history 2. Tap back | Returns to home | Medium |
| TC-NV-007 | Onboarding to home | 1. Complete onboarding 2. Start challenge | Navigates to home with active session | High |
| TC-NV-008 | Restart navigates to home | 1. Restart from history | Pops back to home screen with new session | High |

## 9. Edge Cases

| ID | Test Case | Steps | Expected Result | Priority |
|---|---|---|---|---|
| TC-EC-001 | No active challenge state | 1. Open app with no challenge | "No Active Challenge" with "Create" and "Start Challenge" buttons | High |
| TC-EC-002 | Empty regular tasks | 1. Go to Daily Tasks with no tasks | Empty state with "No Regular Tasks" and create button | Medium |
| TC-EC-003 | Date before challenge start | 1. Navigate to a date before session start | "Challenge hasn't started yet" message | Low |
| TC-EC-004 | Day 75 completion | 1. Complete all tasks on day 75 | Completion dialog, session marked complete, moved to history | High |
| TC-EC-005 | Missed day auto-reset (hard mode) | 1. Miss all tasks for a day 2. Open app next day | Reset dialog, session ended, moved to history | High |
| TC-EC-006 | Soft mode no reset on miss | 1. Set up soft mode challenge 2. Miss a day | No reset, missed day tracked but challenge continues | Medium |
| TC-EC-007 | App reopen after midnight | 1. Have active challenge 2. Close app before midnight 3. Open after midnight | Day counter advances, missed day check runs | Medium |
| TC-EC-008 | Restart session not found | 1. (Edge case) Attempt restart with invalid session ID | Error message shown, no crash | Low |
| TC-EC-009 | Multiple rapid toggles | 1. Rapidly toggle a task on/off 5 times | Final state is correct, no crashes or duplicate notifications | Medium |
| TC-EC-010 | Challenge with 1 task | 1. Create challenge with only 1 task | Works normally, single task shown | Low |
