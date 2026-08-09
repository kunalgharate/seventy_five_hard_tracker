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
}
