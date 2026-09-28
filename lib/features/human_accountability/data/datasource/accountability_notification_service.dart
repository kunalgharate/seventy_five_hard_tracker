import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Notification types used by the accountability partner system.
enum AccountabilityNotificationType {
  invitationReceived,
  invitationAccepted,
  invitationDeclined,
  taskNeedsReview,
  reviewApproved,
  reviewRejected,
  reviewReminder20h,
  reviewExpired,
}

/// Writes FCM notification documents to Firestore.
///
/// Since Cloud Functions are unavailable, notifications are delivered via:
/// 1. The sender writes a doc to `fcm_notifications/{id}` with recipient UID
/// 2. The recipient's app listens to this collection (delivered=false)
/// 3. On receiving, the client shows a local notification and marks delivered=true
class AccountabilityNotificationService {
  static final AccountabilityNotificationService _instance =
      AccountabilityNotificationService._();
  factory AccountabilityNotificationService() => _instance;
  AccountabilityNotificationService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Sends a notification by writing to the fcm_notifications collection.
  Future<void> sendNotification({
    required String recipientUid,
    required AccountabilityNotificationType type,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      await _db.collection('fcm_notifications').add({
        'recipientUid': recipientUid,
        // Stamp the authenticated sender so security rules can verify the
        // sender is not being spoofed.
        'senderUid': _auth.currentUser!.uid,
        'type': type.name,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'delivered': false,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityNotification] Send failed: $e');
      }
    }
  }

  // ── Convenience methods for each notification type ──────────────────────

  /// Notify partner they have been invited.
  Future<void> notifyInvitationReceived({
    required String recipientUid,
    required String senderName,
    required String taskName,
    required String taskId,
    required String partnershipId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.invitationReceived,
        title: 'Partner Invitation',
        body: '$senderName invited you to review \'$taskName\'',
        data: {
          'type': 'invitation_received',
          'taskId': taskId,
          'partnershipId': partnershipId,
        },
      );

  /// Notify task owner that their invitation was accepted.
  Future<void> notifyInvitationAccepted({
    required String recipientUid,
    required String partnerName,
    required String partnershipId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.invitationAccepted,
        title: 'Invitation Accepted',
        body: '$partnerName accepted your invitation',
        data: {
          'type': 'invitation_accepted',
          'partnershipId': partnershipId,
        },
      );

  /// Notify task owner that their invitation was declined.
  Future<void> notifyInvitationDeclined({
    required String recipientUid,
    required String partnerName,
    required String partnershipId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.invitationDeclined,
        title: 'Invitation Declined',
        body: '$partnerName declined your invitation',
        data: {
          'type': 'invitation_declined',
          'partnershipId': partnershipId,
        },
      );

  /// Notify partner that a task needs their review.
  Future<void> notifyTaskNeedsReview({
    required String recipientUid,
    required String ownerName,
    required String taskName,
    required String taskId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.taskNeedsReview,
        title: '$ownerName\'s Task',
        body: '\'$taskName\' needs your review',
        data: {
          'type': 'task_needs_review',
          'taskId': taskId,
        },
      );

  /// Notify task owner that partner approved.
  Future<void> notifyReviewApproved({
    required String recipientUid,
    required String taskName,
    required String taskId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.reviewApproved,
        title: 'Task Approved ✅',
        body: 'Your partner approved \'$taskName\'',
        data: {
          'type': 'review_approved',
          'taskId': taskId,
        },
      );

  /// Notify task owner that partner rejected.
  Future<void> notifyReviewRejected({
    required String recipientUid,
    required String taskName,
    required String taskId,
    String? comment,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.reviewRejected,
        title: 'Task Needs Work',
        body: comment != null
            ? 'Your partner rejected \'$taskName\': $comment'
            : 'Your partner rejected \'$taskName\'',
        data: {
          'type': 'review_rejected',
          'taskId': taskId,
        },
      );

  /// Remind partner at 20-hour mark.
  Future<void> notifyReviewReminder({
    required String recipientUid,
    required String taskName,
    required String taskId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.reviewReminder20h,
        title: 'Review Reminder ⏰',
        body: 'Only 4 hours left to review \'$taskName\'',
        data: {
          'type': 'review_reminder',
          'taskId': taskId,
        },
      );

  /// Notify task owner that review window expired.
  Future<void> notifyReviewExpired({
    required String recipientUid,
    required String taskName,
    required String taskId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.reviewExpired,
        title: 'Review Expired',
        body: 'Review window closed — \'$taskName\' marked incomplete',
        data: {
          'type': 'review_expired',
          'taskId': taskId,
        },
      );

  // ── Phase 4: Multi-reviewer notifications ──────────────────────────────

  /// Notify a reviewer that they've been requested to review a task.
  Future<void> notifyReviewRequested({
    required String recipientUid,
    required String ownerName,
    required String taskName,
    required String taskId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.taskNeedsReview,
        title: 'Review Request',
        body: '$ownerName wants you to review \'$taskName\'',
        data: {
          'type': 'review_requested',
          'taskId': taskId,
        },
      );

  /// Notify the task owner that a reviewer accepted their request.
  Future<void> notifyRequestAccepted({
    required String recipientUid,
    required String reviewerName,
    required String taskName,
    required String taskId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.invitationAccepted,
        title: 'Request Accepted',
        body: '$reviewerName accepted your review request for \'$taskName\'',
        data: {
          'type': 'request_accepted',
          'taskId': taskId,
        },
      );

  /// Notify the task owner that a reviewer declined their request.
  Future<void> notifyRequestDeclined({
    required String recipientUid,
    required String reviewerName,
    required String taskName,
    required String taskId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.invitationDeclined,
        title: 'Request Declined',
        body: '$reviewerName declined your review request for \'$taskName\'',
        data: {
          'type': 'request_declined',
          'taskId': taskId,
        },
      );

  /// Notify all reviewers that proof has been submitted.
  Future<void> notifyProofSubmitted({
    required List<String> reviewerUids,
    required String ownerName,
    required String taskName,
    required String taskId,
  }) async {
    for (final uid in reviewerUids) {
      await sendNotification(
        recipientUid: uid,
        type: AccountabilityNotificationType.taskNeedsReview,
        title: 'Proof Submitted',
        body: '$ownerName submitted proof for \'$taskName\'',
        data: {
          'type': 'proof_submitted',
          'taskId': taskId,
        },
      );
    }
  }

  /// Notify the task owner that their proof was approved.
  Future<void> notifyProofApproved({
    required String recipientUid,
    required String reviewerName,
    required String taskName,
    required String taskId,
    bool autoCompleted = false,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.reviewApproved,
        title: autoCompleted ? 'Task Completed ✅' : 'Proof Approved ✅',
        body: autoCompleted
            ? '$reviewerName approved \'$taskName\' — task completed!'
            : '$reviewerName approved your proof for \'$taskName\'',
        data: {
          'type': 'proof_approved',
          'taskId': taskId,
        },
      );

  /// Notify the task owner that their proof was rejected.
  Future<void> notifyProofRejected({
    required String recipientUid,
    required String reviewerName,
    required String taskName,
    required String taskId,
    required String comment,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.reviewRejected,
        title: 'Task Needs Work',
        body: '$reviewerName rejected \'$taskName\': $comment',
        data: {
          'type': 'proof_rejected',
          'taskId': taskId,
        },
      );
}
