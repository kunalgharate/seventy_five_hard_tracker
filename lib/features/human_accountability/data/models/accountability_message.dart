import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Type of message a partner can send.
enum MessageType {
  encouragement,
  reminder,
  warning,
  question,
  clarification,
}

extension MessageTypeExtension on MessageType {
  String get label {
    switch (this) {
      case MessageType.encouragement:
        return 'Encouragement';
      case MessageType.reminder:
        return 'Reminder';
      case MessageType.warning:
        return 'Warning';
      case MessageType.question:
        return 'Question';
      case MessageType.clarification:
        return 'Clarification';
    }
  }

  String get emoji {
    switch (this) {
      case MessageType.encouragement:
        return '💪';
      case MessageType.reminder:
        return '⏰';
      case MessageType.warning:
        return '⚠️';
      case MessageType.question:
        return '❓';
      case MessageType.clarification:
        return '🔍';
    }
  }

  static MessageType fromString(String v) => MessageType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => MessageType.encouragement,
      );
}

/// A message sent from a partner to a user (or vice-versa).
/// Stored in Firestore `accountability_messages/{id}`.
class AccountabilityMessage extends Equatable {
  final String id;

  /// UID of the user who sent the message.
  final String senderUid;

  /// Display name of the sender.
  final String senderName;

  /// UID of the user who receives the message.
  final String receiverUid;

  /// The partnership this message belongs to.
  final String partnershipId;

  final String text;
  final MessageType type;
  final DateTime createdAt;

  /// Whether the receiver has read this message.
  final bool isRead;

  const AccountabilityMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.receiverUid,
    required this.partnershipId,
    required this.text,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  AccountabilityMessage copyWith({
    String? id,
    String? senderUid,
    String? senderName,
    String? receiverUid,
    String? partnershipId,
    String? text,
    MessageType? type,
    DateTime? createdAt,
    bool? isRead,
  }) =>
      AccountabilityMessage(
        id: id ?? this.id,
        senderUid: senderUid ?? this.senderUid,
        senderName: senderName ?? this.senderName,
        receiverUid: receiverUid ?? this.receiverUid,
        partnershipId: partnershipId ?? this.partnershipId,
        text: text ?? this.text,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
        isRead: isRead ?? this.isRead,
      );

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory AccountabilityMessage.fromFirestore(Map<String, dynamic> d,
          {String? id}) =>
      AccountabilityMessage(
        id: id ?? d['id'] as String,
        senderUid: d['senderUid'] as String,
        senderName: d['senderName'] as String? ?? 'Partner',
        receiverUid: d['receiverUid'] as String,
        partnershipId: d['partnershipId'] as String,
        text: d['text'] as String,
        type: MessageTypeExtension.fromString(
            d['type'] as String? ?? 'encouragement'),
        createdAt: _parseDate(d['createdAt']),
        isRead: d['isRead'] as bool? ?? false,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'senderUid': senderUid,
        'senderName': senderName,
        'receiverUid': receiverUid,
        'partnershipId': partnershipId,
        'text': text,
        'type': type.name,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': isRead,
      };

  @override
  List<Object?> get props => [
        id,
        senderUid,
        senderName,
        receiverUid,
        partnershipId,
        text,
        type,
        createdAt,
        isRead,
      ];
}
