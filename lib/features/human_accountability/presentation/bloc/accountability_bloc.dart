import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seventy_five_hard_tracker/core/services/fcm_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/accountability_notification_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/datasource/review_expiry_service.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/domain/services/review_scoring_engine.dart';
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
  final AccountabilityNotificationService _notificationService;
  final ReviewExpiryService _expiryService;
  final ReviewScoringEngine _scoringEngine;

  AccountabilityBloc({
    AccountabilityService? service,
    DatabaseRepository? repository,
    AccountabilityNotificationService? notificationService,
    ReviewExpiryService? expiryService,
    ReviewScoringEngine? scoringEngine,
  })  : _service = service ?? AccountabilityService(),
        _repository = repository ?? DatabaseRepository(),
        _notificationService =
            notificationService ?? AccountabilityNotificationService(),
        _expiryService = expiryService ?? ReviewExpiryService(),
        _scoringEngine = scoringEngine ?? const ReviewScoringEngine(),
        super(AccountabilityInitial()) {
    on<LoadAccountabilityData>(_onLoad);
    on<InvitePartner>(_onInvitePartner);
    on<AcceptInvite>(_onAcceptInvite);
    on<AcceptIncomingRequest>(_onAcceptIncomingRequest);
    on<RejectIncomingRequest>(_onRejectIncomingRequest);
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

    // Partner review workflow events
    on<SubmitTaskForReview>(_onSubmitTaskForReview);
    on<ApproveTaskReview>(_onApproveTaskReview);
    on<RejectTaskReview>(_onRejectTaskReview);
    on<ExpireOverdueTasks>(_onExpireOverdueTasks);
    on<CheckExpiredTasks>(_onCheckExpiredTasks);
    on<LoadMyResponsibilities>(_onLoadMyResponsibilities);

    // Phase 4: multi-reviewer review system
    on<LoadReviewTabData>(_onLoadReviewTabData);
    on<AcceptReviewRequest>(_onAcceptReviewRequest);
    on<DeclineReviewRequest>(_onDeclineReviewRequest);
    on<SubmitProofForReview>(_onSubmitProofForReview);
    on<ApproveProof>(_onApproveProof);
    on<RejectProof>(_onRejectProof);
  }

  @override
  Future<void> close() {
    // Stop only the timers that were started by this bloc instance. The
    // ReviewExpiryService is a **singleton** — calling full dispose() here
    // would kill timers for the entire app if another widget/bloc also
    // references the singleton. Instead we cancel just the precise timer
    // that _onSubmitTaskForReview may have scheduled.
    _expiryService.cancelPreciseTimer();
    return super.close();
  }

  /// True while a [_onLoad] fetch is running. The default bloc event
  /// transformer runs handlers concurrently, so Firestore stream events
  /// (which fire often) would otherwise stack several overlapping loads —
  /// each one flashing the Squad screen back to the spinner.
  bool _loadInFlight = false;
  bool _loadQueued = false;

  Future<void> _onLoad(
    LoadAccountabilityData event,
    Emitter<AccountabilityState> emit,
  ) async {
    // Coalesce: run one load at a time, and re-run once at the end if more
    // events arrived while this one was in flight.
    if (_loadInFlight) {
      _loadQueued = true;
      return;
    }
    _loadInFlight = true;
    try {
      // Only show the full-screen spinner when there is nothing on screen yet.
      // Reloading with data already visible keeps the current UI in place.
      if (state is! AccountabilityLoaded) {
        emit(AccountabilityLoading());
      }
      try {
        // Keep my `users` doc fresh so partners can find me by email, and
        // claim any tasks a coach/manager assigned to my email before I joined.
        unawaited(_service.registerUser());
        await _service.claimTasksAssignedToMyEmail();
        final results = await Future.wait([
          _service.fetchMyPartnerships(),
          _service.fetchMyReviews(),
          _service.fetchIncomingRequests(),
          _service.fetchMyInvitations(),
          _service.fetchIncomingTaskRequests(),
        ]);
        if (isClosed) return;
        // An email invite pre-creates BOTH an invitations doc and a pending
        // partnerships doc. The invitee must see one card, not two — keep the
        // email-invite card (its accept flow claims both docs atomically).
        final invitations = results[3] as List<AccountabilityInvitation>;
        final linkedPartnershipIds =
            invitations.map((i) => i.partnershipId).toSet();
        final requests = (results[2] as List<AccountabilityPartner>)
            .where((p) => !linkedPartnershipIds.contains(p.id))
            .toList();
        emit(AccountabilityLoaded(
          partners: results[0] as List<AccountabilityPartner>,
          myReviews: results[1] as List<PartnerReview>,
          incomingRequests: requests,
          emailInvitations: invitations,
          taskRequests: results[4] as List<AccountabilityTask>,
        ));
        unawaited(_syncMissingChallenges());
      } catch (e) {
        if (kDebugMode) debugPrint('[AccountabilityBloc] load error: $e');
        if (isClosed) return;
        emit(const AccountabilityError('Failed to load accountability data'));
      }
    } finally {
      _loadInFlight = false;
      if (_loadQueued && !isClosed) {
        _loadQueued = false;
        add(LoadAccountabilityData());
      }
    }
  }

  /// Removes challenges that were copied into my session only because a
  /// partner assigned me their task for review. Under the owner-completes
  /// model those challenges belong to the partner's session, not mine —
  /// leaving them here blocked my day (they can never be completed by me).
  Future<void> _syncMissingChallenges() async {
    try {
      final activeSession = await _repository.getActiveSession();
      if (activeSession == null) return;
      final myUid = _service.currentUid;
      if (myUid == null) return;
      final strayIds = await _service.fetchReviewerChallengeIds();
      if (strayIds.isEmpty) return;
      final kept = activeSession.challenges
          .where((c) => !strayIds.contains(c.id))
          .toList();
      if (kept.length == activeSession.challenges.length) return;
      await _repository.saveSession(
        activeSession.copyWith(challenges: kept),
      );
      debugPrint(
          '[AccountabilityBloc] removed ${activeSession.challenges.length - kept.length} '
          'reviewer-only challenges from session');
    } catch (e) {
      debugPrint('[AccountabilityBloc] reviewer cleanup error: $e');
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
        if (isClosed) return;
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
      if (isClosed) return;
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

  Future<void> _onAcceptIncomingRequest(
    AcceptIncomingRequest event,
    Emitter<AccountabilityState> emit,
  ) async {
    emit(AccountabilityLoading());
    try {
      final partner = await _service.acceptPartnerRequest(event.partner);
      if (isClosed) return;
      if (partner != null) {
        emit(InviteAccepted(partner));
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError('Failed to accept the request.'));
      }
    } on Exception catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      emit(AccountabilityError(msg));
    } catch (e) {
      emit(AccountabilityError('Accept request failed: $e'));
    }
  }

  Future<void> _onRejectIncomingRequest(
    RejectIncomingRequest event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      await _service.rejectPartnerRequest(event.partner);
      emit(const InviteRejected());
      add(LoadAccountabilityData());
    } catch (e) {
      emit(AccountabilityError('Reject request failed: $e'));
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
        if (isClosed) return;
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
      if (isClosed) return;
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
      debugPrint(
          '[AccountabilityBloc] acceptTaskRequest("${event.taskId}") → $ok');
      if (ok) {
        await _syncMissingChallenges();

        final task = await _service.fetchTaskById(event.taskId);
        final challengeId = task?.challengeId;
        debugPrint(
            '[AccountabilityBloc]   task="${task?.title}" challengeId=$challengeId status=${task?.status.name}');
        if (task != null) _subscribeTaskChannels([task.id]);

        if (isClosed) return;
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
      final ok = await _service.declineTaskRequest(event.taskId);
      if (ok) {
        emit(TaskRequestDeclined(event.taskId));
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError('Could not decline task request.'));
      }
    } catch (e) {
      emit(AccountabilityError('Decline task failed: $e'));
    }
  }

  // ── Partner Review Workflow Handlers ──────────────────────────────────────

  Future<void> _onSubmitTaskForReview(
    SubmitTaskForReview event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final task = await _service.submitForReview(event.taskId);
      if (isClosed) return;
      if (task == null) {
        emit(const AccountabilityError('Could not submit for review.'));
        return;
      }

      // Send notification to partner (non-blocking — don't fail the submission)
      if (task.partnerUid != null) {
        try {
          await _notificationService.notifyTaskNeedsReview(
            recipientUid: task.partnerUid!,
            ownerName: task.accountableName,
            taskName: task.title,
            taskId: task.id,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[AccountabilityBloc] Notification failed: $e');
          }
        }
      }

      // Schedule precise expiry timer — but only if the bloc is still alive.
      // If it closed during the notification await, scheduling would recreate
      // a timer after close() already cancelled them.
      if (isClosed) return;
      if (task.expiresAt != null) {
        _expiryService.scheduleNextExpiry(task.expiresAt!);
      }

      if (isClosed) return;
      emit(TaskSubmittedForReview(task.id, task.expiresAt));
    } catch (e) {
      emit(AccountabilityError('Submit for review failed: $e'));
    }
  }

  Future<void> _onApproveTaskReview(
    ApproveTaskReview event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final task = await _service.approveTask(
        event.taskId,
        improvementNote: event.improvementNote,
      );
      if (isClosed) return;
      if (task == null) {
        emit(const AccountabilityError('Could not approve task.'));
        return;
      }

      // Notify the task owner (non-blocking)
      try {
        await _notificationService.notifyReviewApproved(
          recipientUid: task.accountableUid,
          taskName: task.title,
          taskId: task.id,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AccountabilityBloc] Notification failed: $e');
        }
      }
      FcmService.instance.unsubscribeFromTaskChannel(task.id);

      emit(TaskReviewCompleted(task.id, 'approved',
          comment: event.improvementNote));

      // Compute streak impact
      final newStreak = _scoringEngine.compute75HardStreak(
        1, // TODO: pass actual current streak from ChallengeBloc
        'approved',
      );
      if (isClosed) return;
      emit(StreakImpacted(newStreak, 'approved'));
    } catch (e) {
      emit(AccountabilityError('Approve task failed: $e'));
    }
  }

  Future<void> _onRejectTaskReview(
    RejectTaskReview event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final task = await _service.rejectTask(
        event.taskId,
        improvementNote: event.improvementNote,
      );
      if (isClosed) return;
      if (task == null) {
        emit(const AccountabilityError('Could not reject task.'));
        return;
      }

      // Notify the task owner (non-blocking)
      try {
        await _notificationService.notifyReviewRejected(
          recipientUid: task.accountableUid,
          taskName: task.title,
          taskId: task.id,
          comment: event.improvementNote,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AccountabilityBloc] Notification failed: $e');
        }
      }
      FcmService.instance.unsubscribeFromTaskChannel(task.id);

      emit(TaskReviewCompleted(task.id, 'rejected',
          comment: event.improvementNote));

      // Compute streak impact — rejected resets streak
      final newStreak = _scoringEngine.compute75HardStreak(
        1, // TODO: pass actual current streak from ChallengeBloc
        'rejected',
      );
      if (isClosed) return;
      emit(StreakImpacted(newStreak, 'rejected'));
    } catch (e) {
      emit(AccountabilityError('Reject task failed: $e'));
    }
  }

  Future<void> _onExpireOverdueTasks(
    ExpireOverdueTasks event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final expiredIds = await _expiryService.checkAndExpireTasks();
      if (expiredIds.isNotEmpty) {
        emit(TasksExpired(expiredIds));
      }
    } catch (e) {
      // Non-critical — log and continue
      if (kDebugMode) {
        debugPrint('[AccountabilityBloc] Expiry check failed: $e');
      }
    }
  }

  Future<void> _onCheckExpiredTasks(
    CheckExpiredTasks event,
    Emitter<AccountabilityState> emit,
  ) async {
    await _onExpireOverdueTasks(ExpireOverdueTasks(), emit);
  }

  Future<void> _onLoadMyResponsibilities(
    LoadMyResponsibilities event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final responsibilities = await _service.fetchMyResponsibilities();
      final pending = await _service.fetchPendingReviewsForMe();
      if (isClosed) return;
      emit(MyResponsibilitiesLoaded(
        responsibilities: responsibilities,
        pendingReviews: pending,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(AccountabilityError('Failed to load responsibilities: $e'));
    }
  }

  // ── Phase 4: Multi-reviewer review system handlers ────────────────────

  /// Joins the FCM topic of every task I'm attached to (owner or reviewer)
  /// so a future server-side sender can broadcast to all of them.
  void _subscribeTaskChannels(Iterable<String> taskIds) {
    for (final id in taskIds) {
      FcmService.instance.subscribeToTaskChannel(id);
    }
  }

  Future<void> _onLoadReviewTabData(
    LoadReviewTabData event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final results = await Future.wait([
        _service.fetchIncomingReviewRequests(),
        _service.fetchTasksToReview(),
        _service.fetchMyPendingReviewTasks(),
        _service.fetchReviewHistory(),
      ]);
      if (isClosed) return;
      emit(ReviewTabLoaded(
        incomingRequests: results[0],
        tasksToReview: results[1],
        myPendingTasks: results[2],
        reviewHistory: results[3],
      ));
      // I'm a reviewer of these tasks — join their channels.
      _subscribeTaskChannels([
        ...results[0].map((t) => t.id),
        ...results[1].map((t) => t.id),
      ]);
    } catch (e) {
      if (isClosed) return;
      emit(AccountabilityError('Failed to load reviews: $e'));
    }
  }

  Future<void> _onAcceptReviewRequest(
    AcceptReviewRequest event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final ok = await _service.acceptReviewRequest(event.taskId);
      if (isClosed) return;
      if (ok) {
        // Notify the task owner
        final task = await _service.fetchTaskById(event.taskId);
        if (task != null) {
          _subscribeTaskChannels([task.id]);
          try {
            await _notificationService.notifyRequestAccepted(
              recipientUid: task.assignedByUid,
              reviewerName: _service.currentUserDisplayName,
              taskName: task.title,
              taskId: task.id,
            );
          } catch (_) {}
        }
        emit(ReviewRequestAccepted(event.taskId));
        add(LoadReviewTabData());
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError('Could not accept review request.'));
      }
    } catch (e) {
      if (isClosed) return;
      emit(AccountabilityError('Accept review request failed: $e'));
    }
  }

  Future<void> _onDeclineReviewRequest(
    DeclineReviewRequest event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final task = await _service.fetchTaskById(event.taskId);
      final ok = await _service.declineReviewRequest(event.taskId);
      if (isClosed) return;
      if (ok) {
        // Notify the task owner
        if (task != null) {
          try {
            await _notificationService.notifyRequestDeclined(
              recipientUid: task.assignedByUid,
              reviewerName: _service.currentUserDisplayName,
              taskName: task.title,
              taskId: task.id,
            );
          } catch (_) {}
        }
        emit(ReviewRequestDeclined(event.taskId));
        add(LoadReviewTabData());
        add(LoadAccountabilityData());
      } else {
        emit(const AccountabilityError('Could not decline review request.'));
      }
    } catch (e) {
      if (isClosed) return;
      emit(AccountabilityError('Decline review request failed: $e'));
    }
  }

  Future<void> _onSubmitProofForReview(
    SubmitProofForReview event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final task = await _service.submitProofForReview(
        taskId: event.taskId,
        proofUrl: event.proofUrl,
      );
      if (isClosed) return;
      if (task == null) {
        emit(const AccountabilityError('Could not submit proof.'));
        return;
      }

      // Notify all accepted reviewers
      final reviewerUids = <String>{
        ...task.accountableUserIds,
        // Legacy docs list reviewers only in partnerUid/accountableUid —
        // mirror AccountabilityService._isReviewerOf so nobody is missed.
        if (task.partnerUid != null && task.partnerUid!.isNotEmpty)
          task.partnerUid!,
        if (task.accountableUid.isNotEmpty) task.accountableUid,
      }.where((uid) => uid != task.assignedByUid).toList();
      if (reviewerUids.isNotEmpty) {
        try {
          await _notificationService.notifyProofSubmitted(
            reviewerUids: reviewerUids,
            ownerName: task.assignedByName,
            taskName: task.title,
            taskId: task.id,
          );
        } catch (_) {}
      }

      // Schedule expiry timer
      if (task.expiresAt != null) {
        if (!isClosed) _expiryService.scheduleNextExpiry(task.expiresAt!);
      }

      if (isClosed) return;
      emit(ProofSubmittedForReview(task.id, event.challengeId));
      add(LoadAccountabilityData());
    } catch (e) {
      if (isClosed) return;
      emit(AccountabilityError('Submit proof failed: $e'));
    }
  }

  Future<void> _onApproveProof(
    ApproveProof event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final task = await _service.approveProof(
        taskId: event.taskId,
        comment: event.comment,
      );
      if (isClosed) return;
      if (task == null) {
        emit(const AccountabilityError('Could not approve proof.'));
        return;
      }

      final autoCompleted = task.hasEnoughApprovals;

      // Notify the task owner
      try {
        await _notificationService.notifyProofApproved(
          recipientUid: task.assignedByUid,
          reviewerName: _service.currentUserDisplayName,
          taskName: task.title,
          taskId: task.id,
          autoCompleted: autoCompleted,
        );
      } catch (_) {}
      // My review of this task is done — leave its channel (re-subscribed
      // automatically the next time it shows up in the Reviews tab).
      FcmService.instance.unsubscribeFromTaskChannel(task.id);

      if (isClosed) return;
      emit(ProofApproved(
        task.id,
        autoCompleted: autoCompleted,
        challengeId: task.challengeId,
      ));
      add(LoadReviewTabData());
    } catch (e) {
      if (isClosed) return;
      emit(AccountabilityError('Approve proof failed: $e'));
    }
  }

  Future<void> _onRejectProof(
    RejectProof event,
    Emitter<AccountabilityState> emit,
  ) async {
    try {
      final task = await _service.rejectProof(
        taskId: event.taskId,
        comment: event.comment,
      );
      if (isClosed) return;
      if (task == null) {
        emit(const AccountabilityError('Could not reject proof.'));
        return;
      }

      // Notify the task owner
      try {
        await _notificationService.notifyProofRejected(
          recipientUid: task.assignedByUid,
          reviewerName: _service.currentUserDisplayName,
          taskName: task.title,
          taskId: task.id,
          comment: event.comment,
        );
      } catch (_) {}
      FcmService.instance.unsubscribeFromTaskChannel(task.id);

      if (isClosed) return;
      emit(ProofRejected(task.id, comment: event.comment));
      add(LoadReviewTabData());
    } catch (e) {
      if (isClosed) return;
      emit(AccountabilityError('Reject proof failed: $e'));
    }
  }
}
