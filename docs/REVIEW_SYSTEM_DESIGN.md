# Accountability Review System — Design Document

**Author:** Kiro (AI Architect)
**Date:** September 28, 2026
**Status:** Draft — awaiting approval before implementation
**Scope:** Complete overhaul of the task review workflow

---

## 1. Problem Statement

The current accountability feature has infrastructure but the end-to-end flow is broken:
- Users can't easily see the proof/camera button on tasks
- Task completion bypasses reviewer approval
- No clear "tasks pending my review" list for reviewers
- No push notifications when a task needs review
- Adding multiple reviewers is possible but the approval flow doesn't work like GitHub PRs

## 2. Target UX (GitHub PR Model)

### Analogy
| GitHub PR | DailyMettle Task |
|-----------|-----------------|
| Author opens PR | User completes task + uploads proof |
| Requests reviewers | User adds collaborators (email) |
| Reviewer approves/rejects | Reviewer taps approve/reject on proof |
| 1 approval required to merge | 1 approval required to mark complete |
| Notifications on PR activity | Push notification on task activity |

### User Personas
- **User A (Task Owner):** Creates tasks, does them daily, uploads proof, needs accountability
- **User B, C, D (Reviewers):** Added by email, review proof, approve/reject, get notified

---

## 3. User Flows

### Flow 1: Task Owner adds reviewers
```
Home Screen → Task Card → 👤 Collaborator button → CollaboratorDialog
  → Enter email → "Add collaborator" → Save
  → Push notification sent to each reviewer: "A added you as reviewer for 'Go to Gym'"
  → Reviewer sees task in their Accountability → Reviews tab
```

### Flow 2: Task Owner completes task + submits for review
```
Home Screen → Task Card → Toggle checkbox
  IF task has reviewers:
    → Checkbox does NOT mark complete
    → Shows "Upload Proof" bottom sheet (camera/gallery)
    → User uploads photo
    → Task status: "Pending Review" (orange badge)
    → Push notification to all reviewers: "A submitted proof for 'Go to Gym'"
  IF task has NO reviewers:
    → Normal toggle (instant complete, no review needed)
```

### Flow 3: Reviewer approves/rejects
```
Accountability Screen → Reviews tab → "Tasks to Review" section
  → See task card with proof photo thumbnail
  → Tap "Review"
  → See full proof photo + task details
  → Approve ✅ or Reject ❌ (with optional comment)
  → Push notification to owner:
    Approved: "B approved 'Go to Gym' ✅"
    Rejected: "B rejected 'Go to Gym' — needs better proof"
  → If approved: task auto-completes for the owner
  → If rejected: owner gets notification, can resubmit proof
```

### Flow 4: Accountability tab — Partners view
```
Accountability Screen → Partners tab
  → List of all partners (people I review for + people who review me)
  → Each partner card shows:
    - Name, avatar
    - "X tasks pending review" counter badge
    - Tap → see all shared tasks with status
```

---

## 4. Data Model Changes

### 4.1 Existing `accountability_tasks` collection (Firestore) — modifications

```
accountability_tasks/{taskId}
  ├── assignedByUid: string        // Task owner (User A)
  ├── assignedByName: string
  ├── accountableUid: string       // Primary reviewer (User B)
  ├── accountableName: string
  ├── accountableUserIds: [string]  // All reviewer UIDs
  ├── reviewerEmails: [string]      // NEW — emails of all reviewers for display
  ├── partnershipId: string
  ├── challengeId: string?         // Links to the daily task card
  ├── title: string
  ├── status: string               // requested → pending → pendingReview → approved/rejected
  ├── proofStatus: string          // notRequired → submitted → approved → rejected
  ├── proofUrl: string?            // Cloudinary photo URL
  ├── proofSubmittedAt: timestamp?
  ├── proofReviewedAt: timestamp?
  ├── proofReviewComment: string?
  ├── requiredApprovals: int       // NEW — default 1 (like GitHub: "1 approval required")
  ├── approvals: [                 // NEW — list of who approved
  │     { uid, name, timestamp, comment? }
  │   ]
  ├── rejections: [                // NEW — list of who rejected
  │     { uid, name, timestamp, comment }
  │   ]
  └── updatedAt: timestamp
```

### 4.2 `task_collaborators` collection — no structural changes
Already stores owner + collaborators with UIDs. Used for security rules.

### 4.3 `fcm_notifications` collection — no structural changes
Already supports sending notifications between users.

---

## 5. Screen-by-Screen Changes

### 5.1 Home Screen — DailyTaskCard

**Current:** Collaborator button hidden when no accountability connection. Proof button hidden.

**New behavior:**
- **Collaborator 👤 button:** Always visible on editable tasks (already works)
- **Task toggle (checkbox):**
  - If task has 0 reviewers → normal toggle (instant complete)
  - If task has ≥1 reviewer → opens proof upload sheet instead of toggling
- **Status badge below task title:**
  - No reviewers: (none)
  - Pending Review: 🟠 "Awaiting review"
  - Approved: 🟢 "Approved by B"
  - Rejected: 🔴 "Rejected — resubmit proof"
- **Proof photo thumbnail:** Small thumbnail when proof is submitted

**Files:** `lib/widgets/daily_task_card.dart`, `lib/screens/home_screen.dart`

### 5.2 Accountability Screen — Partners Tab

**Current:** Shows partner cards but no task review counters.

**New behavior:**
- Each partner card shows:
  - Avatar + name
  - **Badge:** "3 tasks to review" (red counter)
  - **Badge:** "2 tasks pending your review" (orange counter for tasks I submitted)
- Tap partner → shows list of all shared tasks between us with status
- "Tasks I assigned" section (tasks where I'm the owner and they're reviewing)
- "Tasks I'm reviewing" section (tasks where they're the owner and I'm reviewing)

**Files:** `lib/features/human_accountability/presentation/pages/accountability_screen.dart`

### 5.3 Accountability Screen — Reviews Tab (Major Overhaul)

**Current:** Shows `PartnerReview` objects (daily reviews). Not useful.

**New behavior — three sections:**

#### Section A: "Tasks to Review" (I am the reviewer)
- List of tasks where I'm in `accountableUserIds` and `proofStatus == submitted`
- Each card shows: task title, owner name, proof thumbnail, submitted time
- Action buttons: "Approve ✅" / "Reject ❌"
- Tap → full proof review screen with photo, comment field

#### Section B: "My Tasks — Pending" (I am the owner, awaiting review)
- Tasks I submitted for review that are still pending
- Shows: task title, reviewer names, "Waiting for review..." status

#### Section C: "Review History"
- Completed reviews (approved/rejected) with comments
- Collapsible/scrollable

**Files:** `lib/features/human_accountability/presentation/pages/accountability_screen.dart`

### 5.4 Proof Upload Sheet (Existing — Minor Changes)

**Current:** `PhotoProofSheet` exists but is hard to trigger.

**Changes:**
- Triggered automatically when user toggles a task that has reviewers
- After upload: set `proofStatus = submitted`, notify all reviewers
- Show upload progress indicator

**Files:** `lib/widgets/photo_proof_sheet.dart`

### 5.5 Proof Review Screen (Existing — Minor Changes)

**Current:** `ProofReviewDialog` exists.

**Changes:**
- Accessible directly from Reviews tab (not buried in partner cards)
- Shows full-size proof photo
- Approve/Reject buttons with optional comment
- After action: update task status, notify owner

**Files:** `lib/widgets/proof_review_dialog.dart`

---

## 6. Notification System

### 6.1 Notification Events

| Event | Sender | Recipient(s) | Title | Body |
|-------|--------|-------------|-------|------|
| Reviewer requested | Owner | Each reviewer | "Review Request" | "A wants you to review 'Go to Gym'" |
| Request accepted | Reviewer | Owner | "Request Accepted" | "B accepted your review request for 'Go to Gym'" |
| Request declined | Reviewer | Owner | "Request Declined" | "B declined your review request for 'Go to Gym'" |
| Proof submitted | Owner | All accepted reviewers | "Proof Submitted" | "A submitted proof for 'Go to Gym'" |
| Proof approved | Reviewer | Owner | "Task Approved ✅" | "B approved 'Go to Gym'" |
| Proof rejected | Reviewer | Owner | "Task Needs Work" | "B rejected 'Go to Gym': needs better proof" |
| Proof resubmitted | Owner | All accepted reviewers | "Proof Resubmitted" | "A resubmitted proof for 'Go to Gym'" |
| Review reminder (20h) | System | Pending reviewers | "Review Reminder ⏰" | "4 hours left to review 'Go to Gym'" |

### 6.2 Implementation
Uses existing `AccountabilityNotificationService` which writes to `fcm_notifications` collection. The recipient's app listens to this collection and shows a local notification. No Cloud Functions needed.

---

## 7. BLoC Changes

### 7.1 New Events
```dart
// When user toggles a task that has reviewers
class SubmitTaskWithProof extends AccountabilityEvent {
  final String challengeId;
  final String proofUrl;
}

// When reviewer approves from the Reviews tab
class ApproveTaskFromReview extends AccountabilityEvent {
  final String taskId;
  final String? comment;
}

// When reviewer rejects from the Reviews tab
class RejectTaskFromReview extends AccountabilityEvent {
  final String taskId;
  final String comment;
}

// Load tasks pending my review
class LoadPendingReviews extends AccountabilityEvent {}
```

### 7.2 New States
```dart
class PendingReviewsLoaded extends AccountabilityState {
  final List<AccountabilityTask> tasksToReview;    // I'm reviewer
  final List<AccountabilityTask> myPendingTasks;   // I'm owner, awaiting review
  final List<AccountabilityTask> reviewHistory;    // Completed reviews
}
```

### 7.3 Modified Flow
```
User toggles task checkbox
  → ChallengeBloc checks if task has reviewers (via collaborators)
  → IF yes: DON'T complete locally. Show proof upload sheet.
  → Proof uploaded → AccountabilityBloc.add(SubmitTaskWithProof)
  → Service: update proofStatus, notify reviewers
  → UI: show "Pending Review" badge

Reviewer taps Approve
  → AccountabilityBloc.add(ApproveTaskFromReview)
  → Service: add approval to approvals[], check if count >= requiredApprovals
  → IF enough approvals: mark task approved, notify owner
  → Owner's ChallengeBloc: auto-complete the daily task
```

---

## 8. Key Business Rules

1. **1 approval required by default** — `requiredApprovals = 1`. Configurable per task later.
2. **Any reviewer can approve** — first approval is enough (like GitHub with 1 required).
3. **Rejection doesn't block** — owner can resubmit proof. Only the latest proof is reviewed.
4. **No reviewers = no review needed** — normal task toggle behavior preserved.
5. **Proof is required when reviewers exist** — can't complete without uploading proof.
6. **24-hour expiry** — if no reviewer responds in 24h, task auto-approves (existing `ReviewExpiryService`).
7. **Owner can't approve own tasks** — enforced in service + Firestore rules.

---

## 9. Files to Modify

| File | Change Type | Effort |
|------|------------|--------|
| `lib/widgets/daily_task_card.dart` | Modify toggle behavior, always show proof button | Medium |
| `lib/screens/home_screen.dart` | Intercept toggle when reviewers exist | Medium |
| `lib/features/.../accountability_screen.dart` | Overhaul Reviews tab, add counters to Partners | Large |
| `lib/features/.../accountability_bloc.dart` | Add new events/handlers | Medium |
| `lib/features/.../accountability_event.dart` | New events | Small |
| `lib/features/.../accountability_state.dart` | New states | Small |
| `lib/features/.../accountability_service.dart` | Add approval tracking, multi-reviewer queries | Medium |
| `lib/features/.../accountability_notification_service.dart` | New notification types | Small |
| `lib/features/.../accountability_task.dart` | Add approvals/rejections fields | Small |
| `lib/widgets/photo_proof_sheet.dart` | Auto-trigger from toggle | Small |
| `lib/widgets/proof_review_dialog.dart` | Standalone access from Reviews tab | Small |
| `firestore.rules` | Allow reviewers to read/update approval fields | Small |

---

## 10. Implementation Order

### Phase 1: Consent + Core Review Flow (do first)
1. Add `approvals`, `rejections`, `requiredApprovals`, `reviewerEmails` to `accountability_task.dart`
2. Wire up accept/decline UI in Reviews tab for `status == requested` tasks
3. Modify task toggle to intercept when reviewers exist → show proof upload
4. Update `accountability_service.dart` for multi-reviewer approval tracking
5. Make Reviews tab show three sections: Requests, Tasks to Review, My Pending Tasks
6. Push notifications on: request sent, accepted, declined, proof submit, review decision

### Phase 2: Partners Tab + Progress View
7. Add pending review counter badges to partner cards
8. Enhance `partner_progress_screen.dart` — calendar heatmap, daily breakdown, proof gallery
9. Both-way progress viewing (A sees B, B sees A)

### Phase 3: Simplify Invite + Cleanup
10. Remove invite code system (codes, code entry UI, `invite_codes` collection)
11. Make CollaboratorDialog the sole entry point for adding reviewers
12. Add native share sheet for inviting non-users
13. Remove dead invite-related code and Firestore rules

### Phase 4: Polish
14. Review history section with comments
15. Proof resubmission flow (rejected → reupload)
16. 24-hour auto-approve timer integration
17. 7-day request expiry

---

## 11. What's NOT in Scope

- Video proof (photos only for now)
- Configurable `requiredApprovals` per task (hardcoded to 1)
- Group reviews / team reviews
- In-app chat between reviewer and owner (exists as `accountability_chat_screen.dart` but separate)
- AI-based proof verification

---

## 12. Open Questions

1. **Should rejected tasks reset the daily progress?** Currently in Hard Mode, a missed task resets the streak. Should a rejection count as "not done"?
2. ~~Can the owner remove a reviewer after submitting proof?~~ **Yes** — owner has full control over reviewers.
3. ~~Should we show reviewer names on the task card?~~ **Yes** — show small avatars.

---

## 13. Partner Progress View (Coach Use Case)

### Scenario
A gym coach (Reviewer B) is added as a reviewer on User A's tasks. Coach B wants to:
- See **all of A's progress** across all days — not just pending reviews
- Check which days A completed, which tasks had proof, which were approved
- Use this as motivation or accountability tracking over time

### UX: Partner Progress Screen
```
Accountability → Partners tab → Tap on partner name
  → Partner Progress Screen:
    - Partner name + avatar at top
    - Overall stats: "Day 45 of 75 | 92% completion | 12-day streak"
    - Calendar heat map (green = completed, red = missed, orange = pending)
    - Daily breakdown (expandable):
      Day 45: ✅ Go to Gym (approved by Coach B)
              ✅ Read 10 pages (approved)
              ❌ Drink 4L water (rejected — resubmitted)
      Day 44: ✅ All tasks completed
    - Proof gallery: thumbnails of all submitted proofs (tap to view full)
```

This screen already partially exists as `partner_progress_screen.dart` — it reads from `public_progress/{uid}/days/{dateKey}`. We enhance it to also show proof photos and review status per task.

### Both directions
- **A taps on B's name** → sees B's progress (motivation)
- **B taps on A's name** → sees A's progress (accountability/coaching)

Both users must be connected as partners to see each other's progress.

---

## 14. Simplified Invite Process (No Invite Codes)

### Current (Remove)
- Generate invite code → share code → recipient enters code → partnership created
- Email-based invite flow with invitation collection

### New (Simple Email Add with Consent)
```
Collaborator Dialog → Enter email → Tap "Add"
  → IF email has an account:
    → Create accountability task with status: "requested"
    → Send push notification: "A wants you to review 'Go to Gym'"
    → Reviewer sees request in Reviews tab with Accept/Decline buttons
    → Accept: status → pending, reviewer can now see progress + review proofs
    → Decline: status → declined, collaborator auto-removed, A gets notified
  → IF email has NO account:
    → Show message: "This user hasn't joined DailyMettle yet"
    → Show "Invite via SMS/WhatsApp" share button
    → Opens native share sheet with message:
      "Hey! I'm using DailyMettle to track my 75 Hard challenge.
       Join and help keep me accountable!
       Download: [app store link]"
    → Do NOT create a phantom collaborator — they must sign up first
```

### Task Status Flow
```
requested ──→ (reviewer accepts) ──→ pending ──→ (owner uploads proof) ──→ pendingReview
    │                                                                          │
    │                                                                    ┌─────┴─────┐
    ▼                                                                    ▼           ▼
declined                                                             approved    rejected
(auto-removed)                                                    (auto-complete) (resubmit)
```

### Consent Rules
- Reviewer can't see owner's progress until they accept
- Owner sees "Waiting for B to accept" status on the task
- If reviewer doesn't respond in 7 days, request auto-expires
- Owner can cancel a pending request and remove the reviewer

### What to remove
- Invite code generation (`_generateCode()`, `invite_codes` collection)
- `AcceptInvite` event and code-entry UI
- The invite code bottom sheet in accountability screen FAB
- `invite_codes` Firestore rules (collection becomes unused)

### What stays
- Email lookup (`findUserByEmail`)
- Partnership auto-creation (`ensurePartnership`)
- `CollaboratorDialog` (this becomes the primary way to add people)
- `AccountabilityTaskStatus.requested` (already exists, just needs UI wiring)

---

**Next step:** Approve this design, then I'll implement Phase 1 end-to-end.
