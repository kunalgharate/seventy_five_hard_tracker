import 'package:equatable/equatable.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/partner_review.dart';

abstract class AccountabilityEvent extends Equatable {
  const AccountabilityEvent();

  @override
  List<Object?> get props => [];
}

/// Load all partnerships and recent reviews for the current user.
class LoadAccountabilityData extends AccountabilityEvent {}

/// Invite a new accountability partner.
class InvitePartner extends AccountabilityEvent {
  final String partnerName;
  final String? partnerEmail;
  final PartnerRole role;

  const InvitePartner({
    required this.partnerName,
    this.partnerEmail,
    required this.role,
  });

  @override
  List<Object?> get props => [partnerName, partnerEmail, role];
}

/// Accept an invite using a 6-character code.
class AcceptInvite extends AccountabilityEvent {
  final String code;

  const AcceptInvite(this.code);

  @override
  List<Object> get props => [code];
}

/// Remove a partnership.
class RemovePartner extends AccountabilityEvent {
  final String partnershipId;

  const RemovePartner(this.partnershipId);

  @override
  List<Object> get props => [partnershipId];
}

/// Reject an incoming invite.
class RejectInvite extends AccountabilityEvent {
  final String partnershipId;

  const RejectInvite(this.partnershipId);

  @override
  List<Object> get props => [partnershipId];
}

/// Submit a review for a partner's day.
class SubmitReview extends AccountabilityEvent {
  final String subjectUid;
  final String reviewerName;
  final String dateKey;
  final ReviewDecision decision;
  final String? comment;

  const SubmitReview({
    required this.subjectUid,
    required this.reviewerName,
    required this.dateKey,
    required this.decision,
    this.comment,
  });

  @override
  List<Object?> get props =>
      [subjectUid, reviewerName, dateKey, decision, comment];
}

/// Publish today's progress so partners can see it.
class PublishProgress extends AccountabilityEvent {
  final String dateKey;
  final int completedTasks;
  final int totalTasks;
  final bool dayCompleted;
  final int currentDay;

  const PublishProgress({
    required this.dateKey,
    required this.completedTasks,
    required this.totalTasks,
    required this.dayCompleted,
    required this.currentDay,
  });

  @override
  List<Object> get props =>
      [dateKey, completedTasks, totalTasks, dayCompleted, currentDay];
}

// ── Phase 3: Email-based invitation events ────────────────────────────────────

/// Look up a user by email to show a preview before sending the invite.
class LookupUserByEmail extends AccountabilityEvent {
  final String email;
  const LookupUserByEmail(this.email);

  @override
  List<Object> get props => [email];
}

/// Send an email-based collaborator invitation.
class SendEmailInvite extends AccountabilityEvent {
  final String toEmail;
  final PartnerRole role;

  const SendEmailInvite({required this.toEmail, required this.role});

  @override
  List<Object> get props => [toEmail, role];
}

/// Accept an email-based invitation by its Firestore document ID.
class AcceptEmailInvite extends AccountabilityEvent {
  final String invitationId;
  const AcceptEmailInvite(this.invitationId);

  @override
  List<Object> get props => [invitationId];
}

/// Reject an email-based invitation by its Firestore document ID.
class RejectEmailInvite extends AccountabilityEvent {
  final String invitationId;
  const RejectEmailInvite(this.invitationId);

  @override
  List<Object> get props => [invitationId];
}

// ── Task request events ───────────────────────────────────────────────────────

/// Accept an incoming task request.
class AcceptTaskRequest extends AccountabilityEvent {
  final String taskId;
  const AcceptTaskRequest(this.taskId);

  @override
  List<Object> get props => [taskId];
}

/// Decline an incoming task request.
class DeclineTaskRequest extends AccountabilityEvent {
  final String taskId;
  const DeclineTaskRequest(this.taskId);

  @override
  List<Object> get props => [taskId];
}

// ── Partner Review Workflow Events ────────────────────────────────────────────

/// Task owner marks a task as done → status changes to pendingReview.
/// Triggers FCM notification to the assigned partner.
class SubmitTaskForReview extends AccountabilityEvent {
  final String taskId;
  const SubmitTaskForReview(this.taskId);

  @override
  List<Object> get props => [taskId];
}

/// Partner approves a pending review.
class ApproveTaskReview extends AccountabilityEvent {
  final String taskId;
  final String? improvementNote;
  const ApproveTaskReview(this.taskId, {this.improvementNote});

  @override
  List<Object?> get props => [taskId, improvementNote];
}

/// Partner rejects a pending review.
class RejectTaskReview extends AccountabilityEvent {
  final String taskId;
  final String? improvementNote;
  const RejectTaskReview(this.taskId, {this.improvementNote});

  @override
  List<Object?> get props => [taskId, improvementNote];
}

/// Fired by the expiry timer when tasks pass their 24h review window.
class ExpireOverdueTasks extends AccountabilityEvent {}

/// Check and process expired tasks on app open.
class CheckExpiredTasks extends AccountabilityEvent {}

/// Load tasks that are pending the current user's review (partner responsibilities).
class LoadMyResponsibilities extends AccountabilityEvent {}
