import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/accountability_message.dart';
import '../models/accountability_notification.dart';
import '../models/streak_action.dart';

/// Extension service that adds messaging, notifications, streak actions,
/// weekly summaries, and partner progress visibility to the base
/// [AccountabilityService].
///
/// New Firestore collections:
///   accountability_messages/{id}
///   accountability_notifications/{id}
///   streak_actions/{id}
class AccountabilityExtensionService {
  static final AccountabilityExtensionService _instance =
      AccountabilityExtensionService._internal();
  factory AccountabilityExtensionService() => _instance;
  AccountabilityExtensionService._internal();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool get _isReady {
    try {
      Firebase.app();
      return _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  String? get currentUid => _auth.currentUser?.uid;

  String get currentDisplayName {
    final user = _auth.currentUser;
    if (user == null) return 'Partner';
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
    return 'User ${user.uid.substring(0, 6)}';
  }

  // ── Messaging ────────────────────────────────────────────────────

  /// Send a message from the current user to [receiverUid].
  Future<AccountabilityMessage?> sendMessage({
    required String receiverUid,
    required String partnershipId,
    required String text,
    required MessageType type,
  }) async {
    if (!_isReady) return null;
    try {
      final uid = currentUid!;
      final ref = _db.collection('accountability_messages').doc();
      final msg = AccountabilityMessage(
        id: ref.id,
        senderUid: uid,
        senderName: currentDisplayName,
        receiverUid: receiverUid,
        partnershipId: partnershipId,
        text: text,
        type: type,
        createdAt: DateTime.now(),
      );
      await ref.set(msg.toFirestore());

      // Notify the receiver
      await _createNotification(
        recipientUid: receiverUid,
        type: NotificationType.partnerMessage,
        title: '${msg.type.emoji} New message from $currentDisplayName',
        body: text.length > 80 ? '${text.substring(0, 80)}…' : text,
        referenceId: ref.id,
      );

      if (kDebugMode) {
        debugPrint('[AccountabilityExtensionService] sendMessage: ${ref.id}');
      }
      return msg;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityExtensionService] sendMessage error: $e');
      }
      return null;
    }
  }

  /// Fetch all messages for a partnership, ordered by time.
  Future<List<AccountabilityMessage>> fetchMessages(
      String partnershipId) async {
    if (!_isReady) return [];
    try {
      final snap = await _db
          .collection('accountability_messages')
          .where('partnershipId', isEqualTo: partnershipId)
          .orderBy('createdAt', descending: false)
          .limit(100)
          .get();
      return snap.docs
          .map((d) => AccountabilityMessage.fromFirestore(d.data(), id: d.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityExtensionService] fetchMessages error: $e');
      }
      return [];
    }
  }

  /// Real-time stream of messages for a partnership.
  Stream<List<AccountabilityMessage>> messagesStream(String partnershipId) {
    if (!_isReady) return const Stream.empty();
    return _db
        .collection('accountability_messages')
        .where('partnershipId', isEqualTo: partnershipId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AccountabilityMessage.fromFirestore(d.data(), id: d.id))
            .toList());
  }

  /// Mark a message as read.
  Future<void> markMessageRead(String messageId) async {
    if (!_isReady) return;
    try {
      await _db
          .collection('accountability_messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityExtensionService] markMessageRead error: $e');
      }
    }
  }

  // ── Notifications ────────────────────────────────────────────────

  /// Create a notification for a recipient.
  Future<void> _createNotification({
    required String recipientUid,
    required NotificationType type,
    required String title,
    required String body,
    String? referenceId,
  }) async {
    try {
      final ref = _db.collection('accountability_notifications').doc();
      final notif = AccountabilityNotification(
        id: ref.id,
        recipientUid: recipientUid,
        senderUid: currentUid ?? '',
        senderName: currentDisplayName,
        type: type,
        title: title,
        body: body,
        referenceId: referenceId,
        createdAt: DateTime.now(),
      );
      await ref.set(notif.toFirestore());
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityExtensionService] createNotification error: $e');
      }
    }
  }

  /// Fetch unread notifications for the current user.
  Future<List<AccountabilityNotification>> fetchMyNotifications(
      {int limit = 30}) async {
    if (!_isReady) return [];
    try {
      final snap = await _db
          .collection('accountability_notifications')
          .where('recipientUid', isEqualTo: currentUid)
          .where('isRead', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) =>
              AccountabilityNotification.fromFirestore(d.data(), id: d.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityExtensionService] fetchMyNotifications error: $e');
      }
      return [];
    }
  }

  /// Real-time stream of unread notifications.
  Stream<List<AccountabilityNotification>> notificationsStream() {
    if (!_isReady) return const Stream.empty();
    return _db
        .collection('accountability_notifications')
        .where('recipientUid', isEqualTo: currentUid)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                AccountabilityNotification.fromFirestore(d.data(), id: d.id))
            .toList());
  }

  Future<void> markNotificationRead(String notifId) async {
    if (!_isReady) return;
    try {
      await _db
          .collection('accountability_notifications')
          .doc(notifId)
          .update({'isRead': true});
    } catch (_) {}
  }

  /// Notify partners when a user submits progress.
  Future<void> notifyProgressSubmitted({
    required List<String> partnerUids,
    required String dateKey,
    required int completed,
    required int total,
  }) async {
    for (final uid in partnerUids) {
      await _createNotification(
        recipientUid: uid,
        type: NotificationType.progressSubmitted,
        title: '✅ $currentDisplayName submitted progress',
        body: 'Completed $completed/$total tasks on $dateKey',
      );
    }
  }

  /// Notify partners when tasks are missed.
  Future<void> notifyTasksMissed({
    required List<String> partnerUids,
    required String dateKey,
    required int missed,
  }) async {
    for (final uid in partnerUids) {
      await _createNotification(
        recipientUid: uid,
        type: NotificationType.tasksMissed,
        title: '❌ $currentDisplayName missed tasks',
        body: '$missed task(s) incomplete on $dateKey',
      );
    }
  }

  /// Notify partners when streak is at risk (e.g. end of day, tasks incomplete).
  Future<void> notifyStreakAtRisk({
    required List<String> partnerUids,
    required int currentStreak,
  }) async {
    for (final uid in partnerUids) {
      await _createNotification(
        recipientUid: uid,
        type: NotificationType.streakAtRisk,
        title: '🔥 $currentDisplayName\'s streak is at risk',
        body:
            'Current streak: $currentStreak days. Tasks still incomplete today.',
      );
    }
  }

  // ── Streak Actions ───────────────────────────────────────────────

  /// Partner flags repeated failures.
  Future<StreakAction?> flagStreak({
    required String subjectUid,
    required String reason,
    required int currentStreak,
  }) async {
    if (!_isReady) return null;
    try {
      final ref = _db.collection('streak_actions').doc();
      final action = StreakAction(
        id: ref.id,
        subjectUid: subjectUid,
        initiatorUid: currentUid!,
        initiatorName: currentDisplayName,
        type: StreakActionType.flagged,
        reason: reason,
        currentStreakAtAction: currentStreak,
        createdAt: DateTime.now(),
      );
      await ref.set(action.toFirestore());

      // Notify the user
      await _createNotification(
        recipientUid: subjectUid,
        type: NotificationType.streakFlagged,
        title: '🚩 Your streak has been flagged',
        body: '$currentDisplayName flagged your progress: $reason',
        referenceId: ref.id,
      );

      if (kDebugMode) {
        debugPrint('[AccountabilityExtensionService] flagStreak: ${ref.id}');
      }
      return action;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AccountabilityExtensionService] flagStreak error: $e');
      }
      return null;
    }
  }

  /// Partner requests a streak review.
  Future<StreakAction?> requestStreakReview({
    required String subjectUid,
    required String reason,
    required int currentStreak,
  }) async {
    if (!_isReady) return null;
    try {
      final ref = _db.collection('streak_actions').doc();
      final action = StreakAction(
        id: ref.id,
        subjectUid: subjectUid,
        initiatorUid: currentUid!,
        initiatorName: currentDisplayName,
        type: StreakActionType.reviewRequested,
        reason: reason,
        currentStreakAtAction: currentStreak,
        createdAt: DateTime.now(),
      );
      await ref.set(action.toFirestore());

      await _createNotification(
        recipientUid: subjectUid,
        type: NotificationType.streakFlagged,
        title: '🔍 Streak review requested',
        body: '$currentDisplayName has requested a review: $reason',
        referenceId: ref.id,
      );

      return action;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityExtensionService] requestStreakReview error: $e');
      }
      return null;
    }
  }

  /// Acknowledge a streak action (user confirms or denies).
  Future<void> acknowledgeStreakAction({
    required String actionId,
    required bool confirmed,
    required String subjectUid,
  }) async {
    if (!_isReady) return;
    try {
      // Verify the streak action belongs to the subject user before updating.
      final docRef = _db.collection('streak_actions').doc(actionId);
      final docSnap = await docRef.get();
      if (!docSnap.exists || docSnap.data()?['subjectUid'] != subjectUid) {
        if (kDebugMode) {
          debugPrint(
              '[AccountabilityExtensionService] acknowledgeStreakAction: '
              'action $actionId does not belong to user $subjectUid');
        }
        return;
      }

      final type = confirmed
          ? StreakActionType.resetConfirmed
          : StreakActionType.resetDenied;
      await docRef.update({
        'acknowledged': true,
        'type': type.name,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityExtensionService] acknowledgeStreakAction error: $e');
      }
    }
  }

  /// Fetch streak actions for a subject user.
  Future<List<StreakAction>> fetchStreakActions(String subjectUid) async {
    if (!_isReady) return [];
    try {
      final snap = await _db
          .collection('streak_actions')
          .where('subjectUid', isEqualTo: subjectUid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      return snap.docs
          .map((d) => StreakAction.fromFirestore(d.data(), id: d.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityExtensionService] fetchStreakActions error: $e');
      }
      return [];
    }
  }

  // ── Weekly Summary ───────────────────────────────────────────────

  /// Fetch a weekly summary map for a partner's progress.
  /// Returns: {completionPct, completedDays, totalDays, missedTasks,
  ///           streakTrend, disciplineScoreTrend}
  Future<Map<String, dynamic>> fetchWeeklySummary(String subjectUid) async {
    if (!_isReady) return {};
    try {
      final snap = await _db
          .collection('public_progress')
          .doc(subjectUid)
          .collection('days')
          .orderBy('dateKey', descending: true)
          .limit(7)
          .get();

      if (snap.docs.isEmpty) return {};

      final days = snap.docs.map((d) => d.data()).toList();
      final totalDays = days.length;
      final completedDays = days.where((d) => d['dayCompleted'] == true).length;
      final totalTasks =
          days.fold<int>(0, (s, d) => s + (d['totalTasks'] as int? ?? 0));
      final completedTasks =
          days.fold<int>(0, (s, d) => s + (d['completedTasks'] as int? ?? 0));
      final missedTasks = totalTasks - completedTasks;
      final completionPct =
          totalTasks == 0 ? 0.0 : completedTasks / totalTasks * 100;

      // Streak trend: list of booleans for each day (chronological: oldest first)
      final streakTrend =
          days.map((d) => d['dayCompleted'] as bool? ?? false).toList().reversed.toList();

      return {
        'completionPct': completionPct,
        'completedDays': completedDays,
        'totalDays': totalDays,
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'missedTasks': missedTasks,
        'streakTrend': streakTrend,
        'currentDay': days.first['currentDay'] as int? ?? 0,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityExtensionService] fetchWeeklySummary error: $e');
      }
      return {};
    }
  }

  // ── Partner progress detail ──────────────────────────────────────

  /// Fetch full progress detail for a partner (all available days).
  Future<List<Map<String, dynamic>>> fetchPartnerFullProgress(
      String partnerUid) async {
    if (!_isReady) return [];
    try {
      final snap = await _db
          .collection('public_progress')
          .doc(partnerUid)
          .collection('days')
          .orderBy('dateKey', descending: true)
          .limit(75)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[AccountabilityExtensionService] fetchPartnerFullProgress error: $e');
      }
      return [];
    }
  }
}
