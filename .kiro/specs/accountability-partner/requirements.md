# Requirements Document

## Introduction

The Accountability Partner feature enables cloud-signed users of the Daily Mettle app (75 Hard Challenge tracker) to invite external partners who review and approve/reject daily task completions. Partners act as human validators — users cannot self-approve tasks that have a partner assigned. This enforces real accountability through human oversight with consequences: rejected or expired reviews reset the 75 Hard streak or reduce the regular task completion percentage.

## Glossary

- **Daily_Mettle_App**: The Flutter mobile application for tracking the 75 Hard Challenge and regular daily habits
- **Cloud_Signed_User**: A user authenticated via Google Sign-In with an active Firebase Auth session and a valid Firebase UID
- **Local_User**: A user operating in offline/guest mode using only Hive local storage without Firebase authentication
- **Accountability_Partner**: A Cloud_Signed_User who has accepted an invitation to review and validate another user's task completions
- **Task_Owner**: The Cloud_Signed_User who created a task and invited an Accountability_Partner to validate completions
- **Partnership**: A bidirectional relationship between a Task_Owner and an Accountability_Partner stored in the Firestore `partnerships` collection
- **Review_Window**: The 24-hour period starting from when a Task_Owner marks a task as complete, during which the Accountability_Partner must submit a review
- **FCM_Notification**: A Firebase Cloud Messaging push notification delivered to a user's device
- **Pending_Review_Status**: The intermediate state of a task after the Task_Owner marks it complete but before the Accountability_Partner approves or rejects it
- **75_Hard_Task**: A task associated with the 75 Hard Challenge where rejection or expiry triggers a streak reset to Day 1
- **Regular_Task**: A daily habit task where rejection or expiry marks the day as incomplete and affects the completion percentage
- **Streak**: A count of consecutive days where all 75_Hard_Tasks have been partner-approved
- **Partners_Tab**: The dedicated UI section where an Accountability_Partner views and manages tasks assigned to them for review
- **Improvement_Note**: Optional text feedback an Accountability_Partner attaches to an approval or rejection decision
- **Invite_Code**: A unique 6-character alphanumeric code generated for a partnership invitation

## Requirements

### Requirement 1: Authentication Gate for Partner Invitations

**User Story:** As a cloud-signed user, I want to invite an accountability partner to validate my tasks, so that I have real external oversight on my daily completions.

#### Acceptance Criteria

1. WHEN a Cloud_Signed_User navigates to a task detail screen, THE Daily_Mettle_App SHALL display an "Invite Partner" button
2. WHEN a Local_User navigates to a task detail screen, THE Daily_Mettle_App SHALL display a "Sign in to add partner" label instead of the "Invite Partner" button
3. WHEN a Local_User taps the "Sign in to add partner" label, THE Daily_Mettle_App SHALL navigate the Local_User to the Google Sign-In screen
4. THE Daily_Mettle_App SHALL restrict all partner invitation actions to Cloud_Signed_Users with a valid Firebase UID

### Requirement 2: Partner Invitation via Email

**User Story:** As a cloud-signed user, I want to invite a partner by entering their email address, so they receive a notification to become my accountability partner.

#### Acceptance Criteria

1. WHEN a Cloud_Signed_User taps "Invite Partner" and submits a valid email address, THE Daily_Mettle_App SHALL create a Partnership record in Firestore with status "pending" and generate an Invite_Code
2. WHEN a Partnership record is created, THE Daily_Mettle_App SHALL send an FCM_Notification to the invited email's associated device containing the task name and Invite_Code
3. IF the invited email does not correspond to an existing Cloud_Signed_User, THEN THE Daily_Mettle_App SHALL store the invitation as pending until the invitee installs the app and signs in with that email
4. WHEN a Cloud_Signed_User attempts to invite their own email address, THE Daily_Mettle_App SHALL reject the invitation and display an error message "You cannot invite yourself"
5. THE Daily_Mettle_App SHALL allow at most one Accountability_Partner per task

### Requirement 3: Partner Accepts or Declines Invitation

**User Story:** As an invited user, I want to accept or decline a partnership invitation, so I only take responsibility for tasks I agree to monitor.

#### Acceptance Criteria

1. WHEN a Cloud_Signed_User opens the Partners_Tab, THE Daily_Mettle_App SHALL display all pending invitations under a "Requests for You" section
2. THE Daily_Mettle_App SHALL display each pending invitation with: the task name, the Task_Owner's display name, and the task type (75 Hard or Regular)
3. WHEN an invited user taps "Accept" on a pending invitation, THE Daily_Mettle_App SHALL update the Partnership status to "accepted" and set the partnerUid field to the accepting user's Firebase UID
4. WHEN an invited user taps "Decline" on a pending invitation, THE Daily_Mettle_App SHALL update the Partnership status to "declined" and send an FCM_Notification to the Task_Owner informing them the invitation was declined
5. WHEN a Partnership is accepted, THE Daily_Mettle_App SHALL display the task under the "My Responsibilities" section of the Partners_Tab

### Requirement 4: Self-Approval Prevention

**User Story:** As a user with an accountability partner assigned, I want the system to prevent me from approving my own tasks, so the accountability is genuine.

#### Acceptance Criteria

1. WHILE a task has an active Partnership with status "accepted", THE Daily_Mettle_App SHALL prevent the Task_Owner from changing the task status directly to "approved" or "complete"
2. WHEN a Task_Owner marks a task as done, THE Daily_Mettle_App SHALL set the task status to Pending_Review_Status instead of "complete"
3. THE Daily_Mettle_App SHALL only allow a user with the Accountability_Partner role (partnerUid matching Firebase UID) to submit approval or rejection decisions for a task

### Requirement 5: Task Completion Triggers Partner Review

**User Story:** As a user who completed a task, I want my partner to be notified immediately so they can review my completion within the 24-hour window.

#### Acceptance Criteria

1. WHEN a Task_Owner marks a task as done, THE Daily_Mettle_App SHALL change the task status to Pending_Review_Status and record a submittedAt timestamp
2. WHEN a task transitions to Pending_Review_Status, THE Daily_Mettle_App SHALL send an FCM_Notification to the Accountability_Partner with title "{Task_Owner_Name}'s Task" and body "'{Task_Name}' needs your review"
3. WHEN a task transitions to Pending_Review_Status, THE Daily_Mettle_App SHALL set an expiresAt timestamp equal to submittedAt plus 24 hours
4. THE Daily_Mettle_App SHALL display Pending_Review_Status tasks to the Task_Owner with a "Waiting for partner review" indicator

### Requirement 6: Partner Review Actions

**User Story:** As an accountability partner, I want to approve, reject, or add feedback to a task completion, so the user gets meaningful validation.

#### Acceptance Criteria

1. WHEN an Accountability_Partner opens a task in Pending_Review_Status, THE Daily_Mettle_App SHALL display the task completion status, the Task_Owner's notes, and any uploaded photo proof
2. WHEN an Accountability_Partner taps "Approve", THE Daily_Mettle_App SHALL update the task status to "approved" and record a reviewedAt timestamp
3. WHEN an Accountability_Partner taps "Reject", THE Daily_Mettle_App SHALL update the task status to "rejected", record a reviewedAt timestamp, and send an FCM_Notification to the Task_Owner with the rejection feedback
4. WHEN an Accountability_Partner submits a review, THE Daily_Mettle_App SHALL allow the Accountability_Partner to attach an optional Improvement_Note of up to 500 characters
5. THE Daily_Mettle_App SHALL prevent an Accountability_Partner from changing a review decision after submission

### Requirement 7: 24-Hour Review Window Expiry

**User Story:** As a user, I want unreviewed tasks to be automatically marked incomplete after 24 hours, so that missing accountability responses have real consequences.

#### Acceptance Criteria

1. WHEN the Review_Window of 24 hours elapses without a partner review, THE Daily_Mettle_App SHALL automatically update the task status to "expired"
2. WHEN a task status changes to "expired", THE Daily_Mettle_App SHALL treat the expired task identically to a rejected task for scoring purposes
3. WHEN a Review_Window is about to expire, THE Daily_Mettle_App SHALL send a reminder FCM_Notification to the Accountability_Partner at the 20-hour mark with body "Only 4 hours left to review '{Task_Name}'"
4. WHEN a task expires, THE Daily_Mettle_App SHALL send an FCM_Notification to the Task_Owner informing them the review window has closed and the task is marked incomplete

### Requirement 8: Impact on 75 Hard Challenge Progress

**User Story:** As a user on the 75 Hard Challenge, I want partner rejections and expiry to reset my streak, so the challenge rules are strictly enforced.

#### Acceptance Criteria

1. WHEN a 75_Hard_Task receives a "rejected" review decision, THE Daily_Mettle_App SHALL reset the user's Streak counter to Day 1
2. WHEN a 75_Hard_Task review expires without a response, THE Daily_Mettle_App SHALL reset the user's Streak counter to Day 1
3. WHEN a 75_Hard_Task receives an "approved" review decision, THE Daily_Mettle_App SHALL increment the user's Streak counter by one day
4. THE Daily_Mettle_App SHALL prevent the Task_Owner from overriding or disputing a partner's review decision on a 75_Hard_Task

### Requirement 9: Impact on Regular Task Progress

**User Story:** As a user with regular daily tasks, I want partner rejections to affect my completion percentage accurately, so my progress reflects genuine validated completions.

#### Acceptance Criteria

1. WHEN a Regular_Task receives a "rejected" review decision, THE Daily_Mettle_App SHALL mark that day as incomplete for the task
2. WHEN a Regular_Task review expires without a response, THE Daily_Mettle_App SHALL mark that day as incomplete for the task
3. THE Daily_Mettle_App SHALL calculate the completion percentage for Regular_Tasks as (partner-approved days / total days) × 100
4. THE Daily_Mettle_App SHALL display the streak counter for Regular_Tasks based on consecutive partner-approved days only

### Requirement 10: Partner's View — Responsibilities Dashboard

**User Story:** As an accountability partner, I want a dedicated view showing all tasks I'm responsible for, so I can efficiently review pending completions.

#### Acceptance Criteria

1. THE Daily_Mettle_App SHALL display a "My Responsibilities" section in the Partners_Tab listing all tasks where the current user is the assigned Accountability_Partner
2. THE Daily_Mettle_App SHALL display each responsibility item with: the Task_Owner's name, the task title, the current day's status, and a countdown to the Review_Window expiry
3. WHEN a task is in Pending_Review_Status, THE Daily_Mettle_App SHALL highlight the task with a badge indicator in the Partners_Tab
4. WHEN an Accountability_Partner taps a task in "My Responsibilities", THE Daily_Mettle_App SHALL display the Task_Owner's completion notes, photo proof (if uploaded), and the task's approval history
5. THE Daily_Mettle_App SHALL display the Task_Owner's current Streak count and overall completion percentage to the Accountability_Partner (without revealing details of unassigned tasks)

### Requirement 11: Partner Data Visibility Restriction

**User Story:** As a user, I want my partner to see only the tasks they are invited to review, so my other tasks remain private.

#### Acceptance Criteria

1. THE Daily_Mettle_App SHALL restrict the Accountability_Partner's view to only tasks where the Partnership record links the partner's Firebase UID to the task
2. THE Daily_Mettle_App SHALL enforce Firestore security rules so that only the Task_Owner can write task data, and only the Task_Owner and assigned Accountability_Partner can read task data
3. WHEN a Partnership is removed or ended, THE Daily_Mettle_App SHALL revoke the former Accountability_Partner's read access to all associated task data immediately
4. THE Daily_Mettle_App SHALL display only aggregate progress numbers (streak count, completion percentage) to the Accountability_Partner for unassigned tasks

### Requirement 12: Push Notification Delivery

**User Story:** As a user, I want all accountability-related notifications delivered via FCM push, so partners and I stay informed in real time.

#### Acceptance Criteria

1. THE Daily_Mettle_App SHALL deliver all accountability-related notifications exclusively via FCM push notifications
2. WHEN an FCM_Notification is tapped, THE Daily_Mettle_App SHALL deep-link to the relevant task in the Partners_Tab
3. THE Daily_Mettle_App SHALL send the following notification types: invitation received, invitation accepted, invitation declined, task needs review, review submitted (approved/rejected), review window reminder at 20 hours, and review window expired
4. THE Daily_Mettle_App SHALL respect device-level Do Not Disturb settings for all FCM_Notifications
