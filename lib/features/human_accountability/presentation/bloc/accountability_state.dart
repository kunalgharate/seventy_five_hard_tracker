import 'package:equatable/equatable.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/partner_review.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/app_user.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_invitation.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';

abstract class AccountabilityState extends Equatable {
  const AccountabilityState();

  @override
  List<Object?> get props => [];
}

class AccountabilityInitial extends AccountabilityState {}

class AccountabilityLoading extends AccountabilityState {}

class AccountabilityLoaded extends AccountabilityState {
  final List<AccountabilityPartner> partners;
  final List<PartnerReview> myReviews;
  final List<AccountabilityPartner> incomingRequests;
  final List<AccountabilityInvitation> emailInvitations;
  final List<AccountabilityTask> taskRequests;

  const AccountabilityLoaded({
    required this.partners,
    required this.myReviews,
    this.incomingRequests = const [],
    this.emailInvitations = const [],
    this.taskRequests = const [],
  });

  AccountabilityLoaded copyWith({
    List<AccountabilityPartner>? partners,
    List<PartnerReview>? myReviews,
    List<AccountabilityPartner>? incomingRequests,
    List<AccountabilityInvitation>? emailInvitations,
    List<AccountabilityTask>? taskRequests,
  }) {
    return AccountabilityLoaded(
      partners: partners ?? this.partners,
      myReviews: myReviews ?? this.myReviews,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      emailInvitations: emailInvitations ?? this.emailInvitations,
      taskRequests: taskRequests ?? this.taskRequests,
    );
  }

  @override
  List<Object> get props =>
      [partners, myReviews, incomingRequests, emailInvitations, taskRequests];
}

class AccountabilityError extends AccountabilityState {
  final String message;
  const AccountabilityError(this.message);

  @override
  List<Object> get props => [message];
}

class PartnerInvited extends AccountabilityState {
  final AccountabilityPartner partner;
  const PartnerInvited(this.partner);

  @override
  List<Object> get props => [partner];
}

class InviteAccepted extends AccountabilityState {
  final AccountabilityPartner partner;
  const InviteAccepted(this.partner);

  @override
  List<Object> get props => [partner];
}

class ReviewSubmitted extends AccountabilityState {
  final PartnerReview review;
  const ReviewSubmitted(this.review);

  @override
  List<Object> get props => [review];
}

class InviteRejected extends AccountabilityState {
  const InviteRejected();
}

// ── Email invitation states ───────────────────────────────────────────────────

class EmailLookupLoading extends AccountabilityState {}

class EmailLookupFound extends AccountabilityState {
  final AppUser user;
  const EmailLookupFound(this.user);

  @override
  List<Object> get props => [user];
}

class EmailLookupNotFound extends AccountabilityState {
  final String email;
  const EmailLookupNotFound(this.email);

  @override
  List<Object> get props => [email];
}

class EmailInviteSent extends AccountabilityState {
  final AccountabilityInvitation invitation;
  const EmailInviteSent(this.invitation);

  @override
  List<Object> get props => [invitation];
}

class EmailInviteAccepted extends AccountabilityState {
  final AccountabilityPartner partner;
  const EmailInviteAccepted(this.partner);

  @override
  List<Object> get props => [partner];
}

class EmailInviteRejected extends AccountabilityState {
  const EmailInviteRejected();
}

// ── Task request states ───────────────────────────────────────────────────────

class TaskRequestAccepted extends AccountabilityState {
  final String taskId;
  final String? challengeId;
  const TaskRequestAccepted(this.taskId, {this.challengeId});

  @override
  List<Object?> get props => [taskId, challengeId];
}

class TaskRequestDeclined extends AccountabilityState {
  final String taskId;
  const TaskRequestDeclined(this.taskId);

  @override
  List<Object> get props => [taskId];
}

// ── Partner Review Workflow States ────────────────────────────────────────────

/// Emitted when a task transitions to pendingReview status.
class TaskSubmittedForReview extends AccountabilityState {
  final String taskId;

  /// May be null if the server has not yet resolved the expiry timestamp.
  final DateTime? expiresAt;
  const TaskSubmittedForReview(this.taskId, this.expiresAt);

  @override
  List<Object?> get props => [taskId, expiresAt];
}

/// Emitted when a partner's review decision is recorded.
class TaskReviewCompleted extends AccountabilityState {
  final String taskId;
  final String decision; // 'approved' or 'rejected'
  final String? comment;
  const TaskReviewCompleted(this.taskId, this.decision, {this.comment});

  @override
  List<Object?> get props => [taskId, decision, comment];
}

/// Emitted when tasks expire past the 24h review window.
class TasksExpired extends AccountabilityState {
  final List<String> expiredTaskIds;
  const TasksExpired(this.expiredTaskIds);

  @override
  List<Object> get props => [expiredTaskIds];
}

/// Emitted when a review outcome impacts the user's streak.
class StreakImpacted extends AccountabilityState {
  final int newStreakDay;
  final String reason; // 'approved', 'rejected', 'expired'
  const StreakImpacted(this.newStreakDay, this.reason);

  @override
  List<Object> get props => [newStreakDay, reason];
}

/// Emitted when partner responsibilities are loaded.
class MyResponsibilitiesLoaded extends AccountabilityState {
  final List<AccountabilityTask> responsibilities;
  final List<AccountabilityTask> pendingReviews;
  const MyResponsibilitiesLoaded({
    required this.responsibilities,
    required this.pendingReviews,
  });

  @override
  List<Object> get props => [responsibilities, pendingReviews];
}

// ── Phase 4: Multi-Reviewer Review Tab States ─────────────────────────────────

/// Loaded data for the Reviews tab with all sections.
class ReviewTabLoaded extends AccountabilityState {
  /// Tasks where I'm a reviewer and status == requested (need accept/decline)
  final List<AccountabilityTask> incomingRequests;

  /// Tasks where I'm a reviewer and proofStatus == submitted (need review)
  final List<AccountabilityTask> tasksToReview;

  /// Tasks where I'm the owner and status == pendingReview (awaiting)
  final List<AccountabilityTask> myPendingTasks;

  /// Tasks where review is completed (approved/rejected history)
  final List<AccountabilityTask> reviewHistory;

  const ReviewTabLoaded({
    this.incomingRequests = const [],
    this.tasksToReview = const [],
    this.myPendingTasks = const [],
    this.reviewHistory = const [],
  });

  /// Total count of items requiring my action (requests + reviews).
  int get actionCount => incomingRequests.length + tasksToReview.length;

  @override
  List<Object> get props =>
      [incomingRequests, tasksToReview, myPendingTasks, reviewHistory];
}

/// Emitted after a review request is accepted.
class ReviewRequestAccepted extends AccountabilityState {
  final String taskId;
  const ReviewRequestAccepted(this.taskId);

  @override
  List<Object> get props => [taskId];
}

/// Emitted after a review request is declined.
class ReviewRequestDeclined extends AccountabilityState {
  final String taskId;
  const ReviewRequestDeclined(this.taskId);

  @override
  List<Object> get props => [taskId];
}

/// Emitted after proof is submitted for review.
class ProofSubmittedForReview extends AccountabilityState {
  final String taskId;
  final String challengeId;
  const ProofSubmittedForReview(this.taskId, this.challengeId);

  @override
  List<Object> get props => [taskId, challengeId];
}

/// Emitted after a reviewer approves proof. Includes whether the task
/// auto-completed (enough approvals reached).
class ProofApproved extends AccountabilityState {
  final String taskId;
  final bool autoCompleted;
  final String? challengeId;
  const ProofApproved(this.taskId,
      {this.autoCompleted = false, this.challengeId});

  @override
  List<Object?> get props => [taskId, autoCompleted, challengeId];
}

/// Emitted after a reviewer rejects proof.
class ProofRejected extends AccountabilityState {
  final String taskId;
  final String comment;
  const ProofRejected(this.taskId, {required this.comment});

  @override
  List<Object> get props => [taskId, comment];
}
