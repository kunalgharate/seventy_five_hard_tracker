import 'package:equatable/equatable.dart';

/// Roles a partner can hold.
enum PartnerRole {
  friend,
  familyMember,
  gymTrainer,
  mentorCoach,
  studyPartner,
}

extension PartnerRoleExtension on PartnerRole {
  String get label {
    switch (this) {
      case PartnerRole.friend:
        return 'Friend';
      case PartnerRole.familyMember:
        return 'Family Member';
      case PartnerRole.gymTrainer:
        return 'Gym Trainer';
      case PartnerRole.mentorCoach:
        return 'Mentor / Coach';
      case PartnerRole.studyPartner:
        return 'Study Partner';
    }
  }

  String get emoji {
    switch (this) {
      case PartnerRole.friend:
        return '👫';
      case PartnerRole.familyMember:
        return '👨‍👩‍👧';
      case PartnerRole.gymTrainer:
        return '🏋️';
      case PartnerRole.mentorCoach:
        return '🎓';
      case PartnerRole.studyPartner:
        return '📚';
    }
  }

  static PartnerRole fromString(String value) {
    return PartnerRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => PartnerRole.friend,
    );
  }
}

/// Status of a partnership invitation.
enum PartnershipStatus { pending, accepted, declined }

extension PartnershipStatusExtension on PartnershipStatus {
  static PartnershipStatus fromString(String value) {
    return PartnershipStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PartnershipStatus.pending,
    );
  }
}

/// A single accountability partner relationship.
class AccountabilityPartner extends Equatable {
  /// Firestore document ID (also used as local key).
  final String id;

  /// Firebase UID of the user who owns this record.
  final String ownerUid;

  /// Firebase UID of the partner (null until they accept).
  final String? partnerUid;

  /// Display name of the partner.
  final String partnerName;

  /// Optional email used to send the invite.
  final String? partnerEmail;

  /// Role assigned to this partner.
  final PartnerRole role;

  /// Current status of the partnership.
  final PartnershipStatus status;

  /// Short invite code the partner enters to link accounts.
  final String inviteCode;

  /// When the partnership was created.
  final DateTime createdAt;

  /// When the partner accepted (null if still pending).
  final DateTime? acceptedAt;

  /// The type of partnership: 'accountability' or 'collaborator'.
  final String type;

  const AccountabilityPartner({
    required this.id,
    required this.ownerUid,
    this.partnerUid,
    required this.partnerName,
    this.partnerEmail,
    required this.role,
    required this.status,
    required this.inviteCode,
    required this.createdAt,
    this.acceptedAt,
    this.type = 'accountability',
  });

  AccountabilityPartner copyWith({
    String? id,
    String? ownerUid,
    String? partnerUid,
    String? partnerName,
    String? partnerEmail,
    PartnerRole? role,
    PartnershipStatus? status,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? acceptedAt,
    String? type,
  }) {
    return AccountabilityPartner(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      partnerUid: partnerUid ?? this.partnerUid,
      partnerName: partnerName ?? this.partnerName,
      partnerEmail: partnerEmail ?? this.partnerEmail,
      role: role ?? this.role,
      status: status ?? this.status,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerUid': ownerUid,
        'partnerUid': partnerUid,
        'partnerName': partnerName,
        'partnerEmail': partnerEmail,
        'role': role.name,
        'status': status.name,
        'inviteCode': inviteCode,
        'createdAt': createdAt.toIso8601String(),
        'acceptedAt': acceptedAt?.toIso8601String(),
        'type': type,
      };

  factory AccountabilityPartner.fromJson(Map<String, dynamic> json) {
    return AccountabilityPartner(
      id: json['id'] as String,
      ownerUid: json['ownerUid'] as String,
      partnerUid: json['partnerUid'] as String?,
      partnerName: json['partnerName'] as String,
      partnerEmail: json['partnerEmail'] as String?,
      role:
          PartnerRoleExtension.fromString(json['role'] as String? ?? 'friend'),
      status: PartnershipStatusExtension.fromString(
          json['status'] as String? ?? 'pending'),
      inviteCode: json['inviteCode'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'] as String)
          : null,
      type: json['type'] as String? ?? 'accountability',
    );
  }

  @override
  List<Object?> get props => [
        id,
        ownerUid,
        partnerUid,
        partnerName,
        partnerEmail,
        role,
        status,
        inviteCode,
        createdAt,
        acceptedAt,
        type,
      ];
}
