import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum StreakActionType {
  flagged, // Partner flagged repeated failures
  reviewRequested, // Partner requested a streak review
  resetConfirmed, // User confirmed streak reset
  resetDenied, // User denied streak reset request
}

extension StreakActionTypeExtension on StreakActionType {
  String get label {
    switch (this) {
      case StreakActionType.flagged:
        return 'Flagged';
      case StreakActionType.reviewRequested:
        return 'Review Requested';
      case StreakActionType.resetConfirmed:
        return 'Reset Confirmed';
      case StreakActionType.resetDenied:
        return 'Reset Denied';
    }
  }

  static StreakActionType fromString(String v) =>
      StreakActionType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => StreakActionType.flagged,
      );
}

/// An action taken on a user's streak by a partner or the user themselves.
/// Stored in `streak_actions/{id}`.
class StreakAction extends Equatable {
  final String id;

  /// UID of the user whose streak is involved.
  final String subjectUid;

  /// UID of the partner who initiated the action.
  final String initiatorUid;
  final String initiatorName;

  final StreakActionType type;
  final String reason;

  /// Current streak value at the time of the action.
  final int currentStreakAtAction;

  final DateTime? createdAt;

  /// Whether the subject user has acknowledged this action.
  final bool acknowledged;

  const StreakAction({
    required this.id,
    required this.subjectUid,
    required this.initiatorUid,
    required this.initiatorName,
    required this.type,
    required this.reason,
    required this.currentStreakAtAction,
    this.createdAt,
    this.acknowledged = false,
  });

  StreakAction copyWith({bool? acknowledged}) => StreakAction(
        id: id,
        subjectUid: subjectUid,
        initiatorUid: initiatorUid,
        initiatorName: initiatorName,
        type: type,
        reason: reason,
        currentStreakAtAction: currentStreakAtAction,
        createdAt: createdAt,
        acknowledged: acknowledged ?? this.acknowledged,
      );

  static DateTime? _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return null;
  }

  factory StreakAction.fromFirestore(Map<String, dynamic> d, {String? id}) =>
      StreakAction(
        id: id ?? d['id'] as String,
        subjectUid: d['subjectUid'] as String,
        initiatorUid: d['initiatorUid'] as String,
        initiatorName: d['initiatorName'] as String? ?? 'Partner',
        type: StreakActionTypeExtension.fromString(
            d['type'] as String? ?? 'flagged'),
        reason: d['reason'] as String,
        currentStreakAtAction: d['currentStreakAtAction'] as int? ?? 0,
        createdAt: _parseDate(d['createdAt']),
        acknowledged: d['acknowledged'] as bool? ?? false,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'subjectUid': subjectUid,
        'initiatorUid': initiatorUid,
        'initiatorName': initiatorName,
        'type': type.name,
        'reason': reason,
        'currentStreakAtAction': currentStreakAtAction,
        'createdAt': FieldValue.serverTimestamp(),
        'acknowledged': acknowledged,
      };

  @override
  List<Object?> get props => [
        id,
        subjectUid,
        initiatorUid,
        type,
        reason,
        currentStreakAtAction,
        createdAt,
        acknowledged,
      ];
}
