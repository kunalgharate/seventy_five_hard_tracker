import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:seventy_five_hard_tracker/features/human_accountability/data/models/accountability_partner.dart';

/// Status of an email-based invitation.
enum InvitationStatus { pending, accepted, rejected }

extension InvitationStatusExtension on InvitationStatus {
  static InvitationStatus fromString(String value) {
    return InvitationStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => InvitationStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case InvitationStatus.pending:
        return 'Pending';
      case InvitationStatus.accepted:
        return 'Accepted';
      case InvitationStatus.rejected:
        return 'Rejected';
    }
  }
}

/// An email-based collaborator invitation stored in the `invitations` collection.
///
/// When created:
///   - [partnershipId] points to a pre-created `partnerships` doc (status: pending)
///   - [toUid] is populated if the invitee was already registered in `users`
///   - [toUid] is null if they haven't signed up yet (matched later by email)
///
/// On accept/reject:
///   - This doc's [status] is updated
///   - The linked `partnerships` doc is updated accordingly
class AccountabilityInvitation extends Equatable {
  final String id;

  /// Sender
  final String fromUid;
  final String fromName;
  final String fromEmail;

  /// Recipient
  final String toEmail;
  final String? toUid; // null until the invitee has registered

  /// Pre-created partnership doc this invitation is linked to
  final String partnershipId;

  final PartnerRole role;
  final InvitationStatus status;

  final DateTime createdAt;
  final DateTime? respondedAt;

  const AccountabilityInvitation({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromEmail,
    required this.toEmail,
    this.toUid,
    required this.partnershipId,
    required this.role,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  // ── Firestore ──────────────────────────────────────────────────────────────

  factory AccountabilityInvitation.fromFirestore(Map<String, dynamic> data,
      {String? id}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return AccountabilityInvitation(
      id: id ?? data['id'] as String? ?? '',
      fromUid: data['fromUid'] as String? ?? '',
      fromName: data['fromName'] as String? ?? 'Someone',
      fromEmail: data['fromEmail'] as String? ?? '',
      toEmail: data['toEmail'] as String? ?? '',
      toUid: data['toUid'] as String?,
      partnershipId: data['partnershipId'] as String? ?? '',
      role:
          PartnerRoleExtension.fromString(data['role'] as String? ?? 'friend'),
      status: InvitationStatusExtension.fromString(
          data['status'] as String? ?? 'pending'),
      createdAt: parseDate(data['createdAt']),
      respondedAt:
          data['respondedAt'] != null ? parseDate(data['respondedAt']) : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'fromUid': fromUid,
        'fromName': fromName,
        'fromEmail': fromEmail,
        'toEmail': toEmail.toLowerCase(),
        'toUid': toUid,
        'partnershipId': partnershipId,
        'role': role.name,
        'status': status.name,
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      };

  AccountabilityInvitation copyWith({
    String? id,
    String? fromUid,
    String? fromName,
    String? fromEmail,
    String? toEmail,
    String? toUid,
    String? partnershipId,
    PartnerRole? role,
    InvitationStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return AccountabilityInvitation(
      id: id ?? this.id,
      fromUid: fromUid ?? this.fromUid,
      fromName: fromName ?? this.fromName,
      fromEmail: fromEmail ?? this.fromEmail,
      toEmail: toEmail ?? this.toEmail,
      toUid: toUid ?? this.toUid,
      partnershipId: partnershipId ?? this.partnershipId,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  // ── Equatable ──────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
        id,
        fromUid,
        fromName,
        fromEmail,
        toEmail,
        toUid,
        partnershipId,
        role,
        status,
        createdAt,
        respondedAt,
      ];
}
