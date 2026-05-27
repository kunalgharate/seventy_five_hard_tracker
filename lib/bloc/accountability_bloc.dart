import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/accountability_service.dart';
import 'accountability_event.dart';
import 'accountability_state.dart';

class AccountabilityBloc
    extends Bloc<AccountabilityEvent, AccountabilityState> {
  final AccountabilityService _service;

  AccountabilityBloc({AccountabilityService? service})
      : _service = service ?? AccountabilityService(),
        super(AccountabilityInitial()) {
    on<LoadAccountabilityData>(_onLoad);
    on<InvitePartner>(_onInvitePartner);
    on<AcceptInvite>(_onAcceptInvite);
    on<RemovePartner>(_onRemovePartner);
    on<SubmitReview>(_onSubmitReview);
    on<PublishProgress>(_onPublishProgress);
  }

  Future<void> _onLoad(
    LoadAccountabilityData event,
    Emitter<AccountabilityState> emit,
  ) async {
    emit(AccountabilityLoading());
    try {
      final partners = await _service.fetchMyPartnerships();
      final reviews = await _service.fetchMyReviews();
      emit(AccountabilityLoaded(partners: partners, myReviews: reviews));
    } catch (e) {
      if (kDebugMode) debugPrint('[AccountabilityBloc] load error: $e');
      emit(const AccountabilityError('Failed to load accountability data'));
    }
  }

  Future<void> _onInvitePartner(
    InvitePartner event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final partner = await _service.invitePartner(
        partnerName: event.partnerName,
        partnerEmail: event.partnerEmail,
        role: event.role,
      );
      if (partner != null) {
        emit(PartnerInvited(partner));
        // Reload the full list after emitting the success state
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError(
            'Failed to create invite. Make sure you are signed in.'));
      }
    } catch (e) {
      emit(AccountabilityError('Invite failed: $e'));
    }
  }

  Future<void> _onAcceptInvite(
    AcceptInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final partner = await _service.acceptInvite(event.code);
      if (partner != null) {
        emit(InviteAccepted(partner));
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError(
            'Invalid or expired invite code. Please check and try again.'));
      }
    } catch (e) {
      emit(AccountabilityError('Accept invite failed: $e'));
    }
  }

  Future<void> _onRemovePartner(
    RemovePartner event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      await _service.removePartner(event.partnershipId);
      add(LoadAccountabilityData());
    } catch (e) {
      emit(AccountabilityError('Remove partner failed: $e'));
    }
  }

  Future<void> _onSubmitReview(
    SubmitReview event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final review = await _service.submitReview(
        subjectUid: event.subjectUid,
        reviewerName: event.reviewerName,
        dateKey: event.dateKey,
        decision: event.decision,
        comment: event.comment,
      );
      if (review != null) {
        emit(ReviewSubmitted(review));
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError('Failed to submit review'));
      }
    } catch (e) {
      emit(AccountabilityError('Submit review failed: $e'));
    }
  }

  Future<void> _onPublishProgress(
    PublishProgress event,
    Emitter<AccountabilityState> emit,
  ) async {
    // Fire-and-forget — don't change UI state for this
    try {
      await _service.publishDailyProgress(
        dateKey: event.dateKey,
        completedTasks: event.completedTasks,
        totalTasks: event.totalTasks,
        dayCompleted: event.dayCompleted,
        currentDay: event.currentDay,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityBloc] publishProgress error: $e');
      }
    }
  }
}
