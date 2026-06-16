import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/challenge.dart';
import 'package:seventy_five_hard_tracker/features/challenges/data/models/daily_progress.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/partner_review.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_invitation.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';
import 'accountability_event.dart';
import 'accountability_state.dart';

class AccountabilityBloc
    extends Bloc<AccountabilityEvent, AccountabilityState> {
  final AccountabilityService _service;
  final DatabaseRepository _repository;

  AccountabilityBloc({
    AccountabilityService? service,
    DatabaseRepository? repository,
  })  : _service = service ?? AccountabilityService(),
        _repository = repository ?? DatabaseRepository(),
        super(AccountabilityInitial()) {
    on<LoadAccountabilityData>(_onLoad);
    on<InvitePartner>(_onInvitePartner);
    on<AcceptInvite>(_onAcceptInvite);
    on<RemovePartner>(_onRemovePartner);
    on<RejectInvite>(_onRejectInvite);
    on<SubmitReview>(_onSubmitReview);
    on<PublishProgress>(_onPublishProgress);
    // Phase 3: email-based invite events
    on<LookupUserByEmail>(_onLookupUserByEmail);
    on<SendEmailInvite>(_onSendEmailInvite);
    on<AcceptEmailInvite>(_onAcceptEmailInvite);
    on<RejectEmailInvite>(_onRejectEmailInvite);
    // Task request events
    on<AcceptTaskRequest>(_onAcceptTaskRequest);
    on<DeclineTaskRequest>(_onDeclineTaskRequest);
  }

  Future<void> _onLoad(
    LoadAccountabilityData event,
    Emitter<AccountabilityState> emit,
  ) async {
    emit(AccountabilityLoading());
    try {
      final results = await Future.wait([
        _service.fetchMyPartnerships(),
        _service.fetchMyReviews(),
        _service.fetchIncomingRequests(),
        _service.fetchMyInvitations(),
        _service.fetchIncomingTaskRequests(),
      ]);
      emit(AccountabilityLoaded(
        partners: results[0] as List<AccountabilityPartner>,
        myReviews: results[1] as List<PartnerReview>,
        incomingRequests: results[2] as List<AccountabilityPartner>,
        emailInvitations: results[3] as List<AccountabilityInvitation>,
        taskRequests: results[4] as List<AccountabilityTask>,
      ));
      unawaited(_syncMissingChallenges());
    } catch (e) {
      if (kDebugMode) debugPrint('[AccountabilityBloc] load error: $e');
      emit(const AccountabilityError('Failed to load accountability data'));
    }
  }

  Future<void> _syncMissingChallenges() async {
    try {
      final activeSession = await _repository.getActiveSession();
      if (activeSession == null) {
        debugPrint('[AccountabilityBloc] _syncMissingChallenges: no active session');
        return;
      }
      final tasks = await _service.fetchTasksAssignedToMe();
      debugPrint('[AccountabilityBloc] _syncMissingChallenges: ${tasks.length} tasks, '
          'session has ${activeSession.challenges.length} challenges');
      var changed = false;
      for (final task in tasks) {
        if (task.challengeId == null || task.challengeId!.isEmpty) continue;
        final cid = task.challengeId!;
        if (activeSession.challenges.any((c) => c.id == cid)) continue;
        debugPrint('[AccountabilityBloc] _syncMissingChallenges: creating local challenge cid=$cid title="${task.title}"');
        final challenge = Challenge(
          id: cid,
          title: task.title,
          taskType: 'hard',
          category: 'general',
        );
        final updatedChallenges = [...activeSession.challenges, challenge];
        final updatedSession =
            activeSession.copyWith(challenges: updatedChallenges);
        await _repository.saveSession(updatedSession);
        activeSession.challenges.add(challenge);

        final today = DateTime.now();
        var todayProgress = _repository.getDailyProgress(today);
        if (todayProgress != null) {
          final updatedCompletions = Map<String, bool>.from(
              todayProgress.challengeCompletions);
          updatedCompletions[cid] = false;
          todayProgress = todayProgress.copyWith(
            challengeCompletions: updatedCompletions,
          );
        } else {
          final challengeCompletions = <String, bool>{};
          for (final c in updatedChallenges) {
            challengeCompletions[c.id] = false;
          }
          todayProgress = DailyProgress(
            date: today,
            challengeCompletions: challengeCompletions,
            isCompleted: false,
          );
        }
        await _repository.saveDailyProgress(todayProgress);
        changed = true;
      }
      debugPrint('[AccountabilityBloc] _syncMissingChallenges: done, changed=$changed');
      if (changed) {
        // Notify UI to reload challenge data
      }
    } catch (e) {
      debugPrint('[AccountabilityBloc] _syncMissingChallenges error: $e');
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
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AccountabilityError('Failed to create invite: $msg'));
    }
  }

  Future<void> _onAcceptInvite(
    AcceptInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    emit(AccountabilityLoading());
    try {
      final partner = await _service.acceptInvite(event.code);
      if (partner != null) {
        emit(InviteAccepted(partner));
        add(LoadAccountabilityData());
      } else {
        // acceptInvite now throws instead of returning null,
        // so this branch is a safety fallback.
        emit(const AccountabilityError(
            'Invalid or expired invite code. Please check and try again.'));
      }
    } on Exception catch (e) {
      // Strip the "Exception: " prefix for a cleaner user-facing message
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AccountabilityError(msg));
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

  Future<void> _onRejectInvite(
    RejectInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      await _service.rejectInvite(event.partnershipId);
      emit(const InviteRejected());
      add(LoadAccountabilityData());
    } catch (e) {
      emit(AccountabilityError('Reject invite failed: $e'));
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

  // ── Phase 3: Email-based invite handlers ────────────────────────────────────

  Future<void> _onLookupUserByEmail(
    LookupUserByEmail event,
    Emitter<AccountabilityState> emit,
  ) async {
    emit(EmailLookupLoading());
    try {
      final user = await _service.findUserByEmail(event.email);
      if (user != null) {
        emit(EmailLookupFound(user));
      } else {
        emit(EmailLookupNotFound(event.email));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityBloc] lookupUserByEmail error: $e');
      }
      emit(EmailLookupNotFound(event.email));
    }
  }

  Future<void> _onSendEmailInvite(
    SendEmailInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final invitation = await _service.sendEmailInvite(
        toEmail: event.toEmail,
        role: event.role,
      );
      emit(EmailInviteSent(invitation));
      add(LoadAccountabilityData());
    } on Exception catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AccountabilityError('Failed to send invite: $msg'));
    } catch (e) {
      emit(AccountabilityError('Failed to send invite: $e'));
    }
  }

  Future<void> _onAcceptEmailInvite(
    AcceptEmailInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    emit(AccountabilityLoading());
    try {
      final partner = await _service.acceptEmailInvite(event.invitationId);
      if (partner != null) {
        emit(EmailInviteAccepted(partner));
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError('Failed to accept invitation.'));
      }
    } on Exception catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AccountabilityError(msg));
    } catch (e) {
      emit(AccountabilityError('Accept invitation failed: $e'));
    }
  }

  Future<void> _onRejectEmailInvite(
    RejectEmailInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      await _service.rejectEmailInvite(event.invitationId);
      emit(const EmailInviteRejected());
      add(LoadAccountabilityData());
    } catch (e) {
      emit(AccountabilityError('Reject invitation failed: $e'));
    }
  }

  Future<void> _onAcceptTaskRequest(
    AcceptTaskRequest event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final ok = await _service.acceptTaskRequest(event.taskId);
      debugPrint('[AccountabilityBloc] acceptTaskRequest("${event.taskId}") → $ok');
      if (ok) {
        await _syncMissingChallenges();

        final task = await _service.fetchTaskById(event.taskId);
        final challengeId = task?.challengeId;
        debugPrint('[AccountabilityBloc]   task="${task?.title}" challengeId=$challengeId status=${task?.status.name}');

        emit(TaskRequestAccepted(event.taskId, challengeId: challengeId));
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError('Could not accept task request.'));
      }
    } catch (e) {
      debugPrint('[AccountabilityBloc] _onAcceptTaskRequest error: $e');
      emit(AccountabilityError('Accept task failed: $e'));
    }
  }

  Future<void> _onDeclineTaskRequest(
    DeclineTaskRequest event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      await _service.declineTaskRequest(event.taskId);
      emit(TaskRequestDeclined(event.taskId));
      add(LoadAccountabilityData());
    } catch (e) {
      emit(AccountabilityError('Decline task failed: $e'));
    }
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/partner_review.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_invitation.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_task.dart';
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
    on<RejectInvite>(_onRejectInvite);
    on<SubmitReview>(_onSubmitReview);
    on<PublishProgress>(_onPublishProgress);
    // Phase 3: email-based invite events
    on<LookupUserByEmail>(_onLookupUserByEmail);
    on<SendEmailInvite>(_onSendEmailInvite);
    on<AcceptEmailInvite>(_onAcceptEmailInvite);
    on<RejectEmailInvite>(_onRejectEmailInvite);
    // Task request events
    on<AcceptTaskRequest>(_onAcceptTaskRequest);
    on<DeclineTaskRequest>(_onDeclineTaskRequest);
  }

  Future<void> _onLoad(
    LoadAccountabilityData event,
    Emitter<AccountabilityState> emit,
  ) async {
    emit(AccountabilityLoading());
    try {
      final results = await Future.wait([
        _service.fetchMyPartnerships(),
        _service.fetchMyReviews(),
        _service.fetchIncomingRequests(),
        _service.fetchMyInvitations(),
        _service.fetchIncomingTaskRequests(),
      ]);
      emit(AccountabilityLoaded(
        partners: results[0] as List<AccountabilityPartner>,
        myReviews: results[1] as List<PartnerReview>,
        incomingRequests: results[2] as List<AccountabilityPartner>,
        emailInvitations: results[3] as List<AccountabilityInvitation>,
        taskRequests: results[4] as List<AccountabilityTask>,
      ));
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
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AccountabilityError('Failed to create invite: $msg'));
    }
  }

  Future<void> _onAcceptInvite(
    AcceptInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    emit(AccountabilityLoading());
    try {
      final partner = await _service.acceptInvite(event.code);
      if (partner != null) {
        emit(InviteAccepted(partner));
        add(LoadAccountabilityData());
      } else {
        // acceptInvite now throws instead of returning null,
        // so this branch is a safety fallback.
        emit(const AccountabilityError(
            'Invalid or expired invite code. Please check and try again.'));
      }
    } on Exception catch (e) {
      // Strip the "Exception: " prefix for a cleaner user-facing message
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AccountabilityError(msg));
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

  Future<void> _onRejectInvite(
    RejectInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      await _service.rejectInvite(event.partnershipId);
      emit(const InviteRejected());
      add(LoadAccountabilityData());
    } catch (e) {
      emit(AccountabilityError('Reject invite failed: $e'));
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

  // ── Phase 3: Email-based invite handlers ────────────────────────────────────

  Future<void> _onLookupUserByEmail(
    LookupUserByEmail event,
    Emitter<AccountabilityState> emit,
  ) async {
    emit(EmailLookupLoading());
    try {
      final user = await _service.findUserByEmail(event.email);
      if (user != null) {
        emit(EmailLookupFound(user));
      } else {
        emit(EmailLookupNotFound(event.email));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityBloc] lookupUserByEmail error: $e');
      }
      emit(EmailLookupNotFound(event.email));
    }
  }

  Future<void> _onSendEmailInvite(
    SendEmailInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final invitation = await _service.sendEmailInvite(
        toEmail: event.toEmail,
        role: event.role,
      );
      emit(EmailInviteSent(invitation));
      add(LoadAccountabilityData());
    } on Exception catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AccountabilityError('Failed to send invite: $msg'));
    } catch (e) {
      emit(AccountabilityError('Failed to send invite: $e'));
    }
  }

  Future<void> _onAcceptEmailInvite(
    AcceptEmailInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    emit(AccountabilityLoading());
    try {
      final partner = await _service.acceptEmailInvite(event.invitationId);
      if (partner != null) {
        emit(EmailInviteAccepted(partner));
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError('Failed to accept invitation.'));
      }
    } on Exception catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AccountabilityError(msg));
    } catch (e) {
      emit(AccountabilityError('Accept invitation failed: $e'));
    }
  }

  Future<void> _onRejectEmailInvite(
    RejectEmailInvite event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      await _service.rejectEmailInvite(event.invitationId);
      emit(const EmailInviteRejected());
      add(LoadAccountabilityData());
    } catch (e) {
      emit(AccountabilityError('Reject invitation failed: $e'));
    }
  }

  Future<void> _onAcceptTaskRequest(
    AcceptTaskRequest event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final ok = await _service.acceptTaskRequest(event.taskId);
      if (ok) {
        emit(TaskRequestAccepted(event.taskId));
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError('Could not accept task request.'));
      }
    } catch (e) {
      emit(AccountabilityError('Accept task failed: $e'));
    }
  }

  Future<void> _onDeclineTaskRequest(
    DeclineTaskRequest event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      await _service.declineTaskRequest(event.taskId);
      emit(TaskRequestDeclined(event.taskId));
      add(LoadAccountabilityData());
    } catch (e) {
      emit(AccountabilityError('Decline task failed: $e'));
    }
  }
}
