import 'package:equatable/equatable.dart';
import '../models/accountability_partner.dart';
import '../models/partner_review.dart';

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
