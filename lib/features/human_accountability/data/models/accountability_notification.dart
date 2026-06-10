import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum NotificationType {
  tasksMissed,
  streakAtRisk,
  progressSubmitted,
  partnerMessage,
  partnerReview,
  partnerClarification,
  streakFlagged,
}

extension NotificationTypeExtension on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.tasksMissed:
        return 'Tasks Missed';
      case NotificationType.streakAtRisk:
        return 'Streak at Risk';
      case NotificationType.progressSubmitted:
        return 'Progress Submitted';
      case NotificationType.partnerMessage:
        return 'New Message';
      case NotificationType.partnerReview:
        return 'Progress Reviewed';
      case NotificationType.partnerClarification:
        return 'Clarification Requested';
      case NotificationType.streakFlagged:
        return 'Streak Flagged';
    }
  }

  String get emoji {
    switch (this) {
      case NotificationType.tasksMissed:
        return '❌';
      case NotificationType.streakAtRisk:
        return '🔥';
      case NotificationType.progressSubmitted:
        return '✅';
      case NotificationType.partnerMessage:
        return '💬';
      case NotificationType.partnerReview:
        return '📋';
      case NotificationType.partnerClarification:
        return '🔍';
      case NotificationType.streakFlagged:
        return '🚩';
    }
  }

  static NotificationType fromString(String v) =>
      NotificationType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => NotificationType.partnerMessage,
      );
}

/// In-app notification stored in `accountability_notifications/{id}`.
class AccountabilityNotification extends Equatable {
  final String id;

  /// UID of the user who should receive this notification.
  final String recipientUid;

  /// UID of the user who triggered the notification.
  final String senderUid;
  final String senderName;

  final NotificationType type;
  final String title;
  final String body;

  /// Optional reference to the related document (message/review/partnership).
  final String? referenceId;

  final DateTime createdAt;
  final bool isRead;

  const AccountabilityNotification({
    required this.id,
    required this.recipientUid,
    required this.senderUid,
    required this.senderName,
    required this.type,
    required this.title,
    required this.body,
    this.referenceId,
    required this.createdAt,
    this.isRead = false,
  });

  AccountabilityNotification copyWith({bool? isRead}) =>
      AccountabilityNotification(
        id: id,
        recipientUid: recipientUid,
        senderUid: senderUid,
        senderName: senderName,
        type: type,
        title: title,
        body: body,
        referenceId: referenceId,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory AccountabilityNotification.fromFirestore(Map<String, dynamic> d,
          {String? id}) =>
      AccountabilityNotification(
        id: id ?? d['id'] as String,
        recipientUid: d['recipientUid'] as String,
        senderUid: d['senderUid'] as String,
        senderName: d['senderName'] as String? ?? 'Partner',
        type: NotificationTypeExtension.fromString(
            d['type'] as String? ?? 'partnerMessage'),
        title: d['title'] as String,
        body: d['body'] as String,
        referenceId: d['referenceId'] as String?,
        createdAt: _parseDate(d['createdAt']),
        isRead: d['isRead'] as bool? ?? false,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'recipientUid': recipientUid,
        'senderUid': senderUid,
        'senderName': senderName,
        'type': type.name,
        'title': title,
        'body': body,
        'referenceId': referenceId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': isRead,
      };

  @override
  List<Object?> get props => [
        id,
        recipientUid,
        senderUid,
        type,
        title,
        body,
        createdAt,
        isRead,
      ];
}
