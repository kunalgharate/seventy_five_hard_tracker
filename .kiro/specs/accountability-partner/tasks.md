# Tasks — Accountability Partner Feature

## Task 1: Extend AccountabilityTask model with review fields
- [ ] Add new status values: `pendingReview`, `rejected`, `expired` to `AccountabilityTaskStatus` enum
- [ ] Add fields: `taskType` (hard/regular), `submittedAt`, `expiresAt`, `reviewedAt`, `reviewDecision`, `reviewComment`, `partnerUid`
- [ ] Update `toJson()` and `fromJson()` to handle new fields
- [ ] Ensure backward compatibility with existing tasks in Firestore

## Task 2: Create ReviewScoringEngine (pure functions)
- [ ] Create `lib/features/human_accountability/domain/services/review_scoring_engine.dart`
- [ ] Implement `compute75HardStreak(int currentStreak, String outcome)` → returns new streak
- [ ] Implement `isRegularDayComplete(String outcome)` → returns bool
- [ ] Implement `computeCompletionPercentage(List<String> dailyOutcomes)` → returns double
- [ ] Implement `computeRegularStreak(List<String> dailyOutcomes)` → returns int
> Depends on: Task 1

## Task 3: Create ReviewExpiryService (client-side timer)
- [ ] Create `lib/features/human_accountability/data/datasource/review_expiry_service.dart`
- [ ] Implement `checkAndExpireTasks()` — queries Firestore for pendingReview tasks past expiresAt, batch-updates to expired
- [ ] Implement `startPeriodicCheck()` — Timer.periodic every 5 minutes
- [ ] Implement `scheduleNextExpiry(DateTime expiresAt)` — precise timer for a specific task
- [ ] Call `checkAndExpireTasks()` on app open (in main.dart _initApp)
> Depends on: Task 1

## Task 4: Create AccountabilityNotificationService (FCM via Firestore)
- [ ] Create `lib/features/human_accountability/data/datasource/accountability_notification_service.dart`
- [ ] Implement `sendNotification(recipientUid, type, title, body, data)` — writes to `fcm_notifications` collection
- [ ] Define 8 notification types: invitation_received, invitation_accepted, invitation_declined, task_needs_review, review_approved, review_rejected, review_reminder_20h, review_expired
- [ ] Add Firestore listener on client to read incoming notifications from `fcm_notifications` collection
> Depends on: Task 1

## Task 5: Extend AccountabilityService with review workflow methods
- [ ] Add `submitForReview(taskId)` — sets status=pendingReview, submittedAt=now, expiresAt=now+24h
- [ ] Add `approveTask(taskId, improvementNote?)` — validates partnerUid match, sets status=approved, reviewedAt=now
- [ ] Add `rejectTask(taskId, improvementNote?)` — validates partnerUid match, sets status=rejected, reviewedAt=now
- [ ] Add `isReviewExpired(task)` helper — checks if expiresAt < now
- [ ] Add validation: reject late reviews (after expiresAt), reject self-reviews, reject duplicate reviews (reviewedAt already set)
- [ ] Add `fetchPendingReviewsForPartner()` — query tasks where partnerUid=me AND status=pendingReview
> Depends on: Task 1, Task 3

## Task 6: Add new BLoC events and states
- [ ] Add events: `SubmitTaskForReview`, `ApproveTaskReview`, `RejectTaskReview`, `ExpireOverdueTasks`, `CheckExpiredTasks`
- [ ] Add states: `TaskSubmittedForReview`, `TaskReviewCompleted`, `TasksExpired`, `StreakImpacted`
- [ ] Register event handlers in AccountabilityBloc constructor
> Depends on: Task 1

## Task 7: Implement BLoC event handlers for review workflow
- [ ] `_onSubmitTaskForReview` — calls service.submitForReview, sends FCM notification to partner, emits TaskSubmittedForReview
- [ ] `_onApproveTaskReview` — calls service.approveTask, sends FCM to owner, computes streak impact via ReviewScoringEngine, emits TaskReviewCompleted + StreakImpacted
- [ ] `_onRejectTaskReview` — calls service.rejectTask, sends FCM to owner, computes streak impact, emits TaskReviewCompleted + StreakImpacted
- [ ] `_onExpireOverdueTasks` — calls ReviewExpiryService.checkAndExpireTasks, sends FCM to owners, emits TasksExpired
- [ ] `_onCheckExpiredTasks` — dispatched on app open, delegates to _onExpireOverdueTasks
> Depends on: Task 2, Task 3, Task 4, Task 5, Task 6

## Task 8: Update DailyTaskCard for pending_review state
- [ ] When task has partner AND status=pendingReview, show "Waiting for review" indicator instead of checkbox
- [ ] When task has partner AND status=approved, show green checkmark with "Partner approved"
- [ ] When task has partner AND status=rejected/expired, show red indicator with "Rejected" or "Expired"
- [ ] Disable self-toggle when task has active partner (user taps "Mark Done" → dispatches SubmitTaskForReview instead of direct complete)
> Depends on: Task 6

## Task 9: Update Partners Tab — "My Responsibilities" section
- [ ] Add "My Responsibilities" section showing tasks where current user is partnerUid
- [ ] Each item shows: owner name, task title, status badge, time remaining countdown
- [ ] Tasks in pendingReview are highlighted with review badge
- [ ] Tapping opens review detail view with: notes, photo, history
- [ ] Add Approve/Reject buttons on the review detail view
- [ ] Add optional improvement note text field (max 500 chars)
> Depends on: Task 7, Task 8

## Task 10: Update Firestore security rules
- [ ] Restrict `accountability_tasks` read to: assignedByUid OR accountableUid OR partnerUid
- [ ] Add `fcm_notifications` collection rules: create by any auth user, read/update/delete by recipientUid only
- [ ] Deploy rules with `firebase deploy --only firestore:rules --project dailymettle`
> Depends on: Task 4

## Task 11: Integrate expiry timer in app lifecycle
- [ ] Start ReviewExpiryService.startPeriodicCheck() in main.dart after Hive init
- [ ] Call CheckExpiredTasks event on AppLifecycleState.resumed
- [ ] Schedule precise timer when SubmitTaskForReview succeeds
- [ ] Cancel timer on sign-out
> Depends on: Task 3, Task 7

## Task 12: Integrate scoring with ChallengeBloc
- [ ] When TaskReviewCompleted is emitted with decision=rejected on a 75 Hard task, dispatch ResetChallenge event to ChallengeBloc
- [ ] When TasksExpired emits for a 75 Hard task, dispatch ResetChallenge
- [ ] For Regular tasks, update completion percentage display using ReviewScoringEngine
- [ ] Show streak based on partner-approved consecutive days
> Depends on: Task 2, Task 7

## Task 13: Write property-based tests for ReviewScoringEngine
- [ ] Property: streak reset on rejection (any currentStreak ≥ 1, outcome=rejected → result=1)
- [ ] Property: streak increment on approval (any currentStreak ≥ 1, outcome=approved → result=currentStreak+1)
- [ ] Property: completion percentage formula (approved/total × 100)
- [ ] Property: regular streak is longest consecutive approved suffix
- [ ] Property: expired treated identically to rejected for all scoring functions
> Depends on: Task 2

## Task 14: Write integration tests for review state transitions
- [ ] Test: pending → pendingReview on submitForReview
- [ ] Test: pendingReview → approved on approveTask (partner UID matches)
- [ ] Test: pendingReview → rejected on rejectTask (partner UID matches)
- [ ] Test: pendingReview → expired when expiresAt passes
- [ ] Test: reject review from non-partner (should fail)
- [ ] Test: reject review after already reviewed (should fail)
- [ ] Test: reject review after expiry (should fail)
> Depends on: Task 5, Task 7

## Task 15: FCM notification listener + deep-linking
- [ ] Add Firestore listener on `fcm_notifications` where recipientUid=me AND delivered=false
- [ ] On new notification doc: show local notification via flutter_local_notifications
- [ ] On notification tap: deep-link to Partners tab → specific task based on data.taskId
- [ ] Mark notification doc as delivered=true after display
- [ ] Schedule 20-hour reminder notification when task enters pendingReview
> Depends on: Task 4, Task 9
