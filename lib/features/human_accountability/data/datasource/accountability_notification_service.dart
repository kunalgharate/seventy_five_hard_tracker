import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Notification types used by the accountability partner system.
enum AccountabilityNotificationType {
  invitationReceived,
  invitationAccepted,
  invitationDeclined,
  taskNeedsReview,
  taskAssigned,
  reviewApproved,
  reviewRejected,
  reviewReminder20h,
  reviewExpired,
  partnerMessage,
}

/// Canonical snake_case spelling of each [AccountabilityNotificationType]
/// (enum name → snake_case, so `reviewReminder20h` → `review_reminder_20h`).
/// Single source of truth for both the Firestore doc `type` field and the
/// push payload `data.type`.
const Map<String, String> _canonicalTypeByName = {
  'invitationReceived': 'invitation_received',
  'invitationAccepted': 'invitation_accepted',
  'invitationDeclined': 'invitation_declined',
  'taskNeedsReview': 'task_needs_review',
  'taskAssigned': 'task_assigned',
  'reviewApproved': 'review_approved',
  'reviewRejected': 'review_rejected',
  'reviewReminder20h': 'review_reminder_20h',
  'reviewExpired': 'review_expired',
  'partnerMessage': 'partner_message',
};

/// Names used by the older in-app accountability notification enum.
/// Keep them mapped to their equivalent current FCM types so legacy callers
/// and stored payloads continue to resolve to the same preference category.
const Map<String, String> _legacyTypeAliases = {
  'partnerReview': 'task_needs_review',
  'progressSubmitted': 'task_needs_review',
};

extension AccountabilityNotificationTypeX on AccountabilityNotificationType {
  /// Canonical snake_case type string derived from this enum value.
  String get canonicalType =>
      AccountabilityNotificationService.canonicalTypeFromName(name);
}

/// Writes FCM notification documents to Firestore.
///
/// Since Cloud Functions are unavailable, notifications are delivered via:
/// 1. The sender writes a doc to `fcm_notifications/{id}` with recipient UID
/// 2. The recipient's app listens to this collection (delivered=false)
/// 3. On receiving, the client shows a local notification and marks delivered=true
///
/// Every doc carries a `channel` — `task_<taskId>` for task/proof/review
/// events, `partner_<partnershipId>` for chat messages, `invite_<id>` for
/// invitations. The channel doubles as the FCM topic name and as the local
/// notification id key, so repeated events for the same task replace one
/// notification instead of stacking.
class AccountabilityNotificationService {
  static final AccountabilityNotificationService _instance =
      AccountabilityNotificationService._();
  factory AccountabilityNotificationService() => _instance;
  AccountabilityNotificationService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Maps any stored type spelling (legacy camelCase enum name or canonical
  /// snake_case) to the canonical snake_case form — single source of truth
  /// for both the Firestore doc's `type` field and the push payload's
  /// `data.type`. Unknown values pass through unchanged (canonical strings
  /// contain no capitals and already match themselves).
  static String canonicalTypeFromName(String name) =>
      _canonicalTypeByName[name] ?? _legacyTypeAliases[name] ?? name;

  /// Inverse of [canonicalTypeFromName]: maps a canonical snake_case type
  /// back to the top-level enum name spelling notification prefs are keyed
  /// on (e.g. 'review_reminder_20h' → 'reviewReminder20h'). Names without
  /// '_' are legacy camelCase enum names and pass through untouched.
  static String enumNameFromCanonicalType(String canonical) {
    if (!canonical.contains('_')) return canonical;
    final words = canonical.split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return canonical;
    final enumName = StringBuffer(words.first);
    for (final word in words.skip(1)) {
      enumName.write(word[0].toUpperCase() + word.substring(1));
    }
    return enumName.toString();
  }

  /// Sends a notification by writing to the fcm_notifications collection.
  Future<void> sendNotification({
    required String recipientUid,
    required AccountabilityNotificationType type,
    required String title,
    required String body,
    Map<String, String>? data,
    String? channel,
  }) async {
    if (_auth.currentUser == null) return;
    if (recipientUid.isEmpty) return;

    try {
      await _db.collection('fcm_notifications').add({
        'recipientUid': recipientUid,
        // Stamp the authenticated sender so security rules can verify the
        // sender is not being spoofed.
        'senderUid': _auth.currentUser!.uid,
        // Canonical snake_case type — mirrors the payload's data.type.
        'type': type.canonicalType,
        'title': title,
        'body': body,
        'data': data ?? {},
        if (channel != null && channel.isNotEmpty) 'channel': channel,
        'createdAt': FieldValue.serverTimestamp(),
        'delivered': false,
        // Unread until the recipient views/dismisses it on the Today
        // screen — drives the unread bell badge (home_screen).
        'isRead': false,
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
    String? taskName,
    String? taskId,
    required String partnershipId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.invitationReceived,
        title: 'Partner Invitation',
        body: taskName != null
            ? '$senderName invited you to review \'$taskName\''
            : '$senderName invited you to be their accountability partner',
        data: {
          'type':
              AccountabilityNotificationType.invitationReceived.canonicalType,
          if (taskId != null) 'taskId': taskId,
          'partnershipId': partnershipId,
        },
        channel: 'invite_$partnershipId',
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
          'type':
              AccountabilityNotificationType.invitationAccepted.canonicalType,
          'partnershipId': partnershipId,
        },
        channel: 'invite_$partnershipId',
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
          'type':
              AccountabilityNotificationType.invitationDeclined.canonicalType,
          'partnershipId': partnershipId,
        },
        channel: 'invite_$partnershipId',
      );

  /// Notify the assigned user that a task was created for them.
  Future<void> notifyTaskAssigned({
    required String recipientUid,
    required String ownerName,
    required String taskName,
    required String taskId,
  }) =>
      sendNotification(
        recipientUid: recipientUid,
        type: AccountabilityNotificationType.taskAssigned,
        title: 'New Task Assigned',
        body: '$ownerName assigned \'$taskName\' to you',
        data: {
          'type': AccountabilityNotificationType.taskAssigned.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
          'type': AccountabilityNotificationType.taskNeedsReview.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
          'type': AccountabilityNotificationType.reviewApproved.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
          'type': AccountabilityNotificationType.reviewRejected.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
          'type':
              AccountabilityNotificationType.reviewReminder20h.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
          'type': AccountabilityNotificationType.reviewExpired.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
        // Phase-4 conveniences reuse a parent enum value above; the payload
        // type still travels as that enum's canonical string.
        data: {
          'type': AccountabilityNotificationType.taskNeedsReview.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
          'type':
              AccountabilityNotificationType.invitationAccepted.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
          'type':
              AccountabilityNotificationType.invitationDeclined.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
          'type': AccountabilityNotificationType.taskNeedsReview.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
          'type': AccountabilityNotificationType.reviewApproved.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
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
          'type': AccountabilityNotificationType.reviewRejected.canonicalType,
          'taskId': taskId,
        },
        channel: 'task_$taskId',
      );
}
