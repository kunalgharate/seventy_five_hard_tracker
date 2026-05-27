import 'package:equatable/equatable.dart';
import '../models/accountability_partner.dart';
import '../models/partner_review.dart';

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

  const AccountabilityLoaded({
    required this.partners,
    required this.myReviews,
  });

  AccountabilityLoaded copyWith({
    List<AccountabilityPartner>? partners,
    List<PartnerReview>? myReviews,
  }) {
    return AccountabilityLoaded(
      partners: partners ?? this.partners,
      myReviews: myReviews ?? this.myReviews,
    );
  }

  @override
  List<Object> get props => [partners, myReviews];
}

class AccountabilityError extends AccountabilityState {
  final String message;

  const AccountabilityError(this.message);

  @override
  List<Object> get props => [message];
}

/// Emitted after a successful invite — carries the new partner so the UI
/// can show the invite code immediately.
class PartnerInvited extends AccountabilityState {
  final AccountabilityPartner partner;

  const PartnerInvited(this.partner);

  @override
  List<Object> get props => [partner];
}

/// Emitted after successfully accepting an invite.
class InviteAccepted extends AccountabilityState {
  final AccountabilityPartner partner;

  const InviteAccepted(this.partner);

  @override
  List<Object> get props => [partner];
}

/// Emitted after a review is submitted.
class ReviewSubmitted extends AccountabilityState {
  final PartnerReview review;

  const ReviewSubmitted(this.review);

  @override
  List<Object> get props => [review];
}
