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

  /// Display name of the partner (as stored at invite time).
  ///
  /// The partnership doc is shared by both users, and `partnerName` always
  /// holds the *invitee's* name. When the current user is the invitee this
  /// is their own name, so the service swaps in [ownerName] — the inviter.
  final String partnerName;

  /// Display name of the user who created the partnership (the inviter).
  final String? ownerName;

  /// Optional email used to send the invite.
  final String? partnerEmail;

  /// Email of the user who created the partnership (the inviter).
  ///
  /// Needed because `partnerEmail` is always the *invitee's* email — on the
  /// invitee's side of the doc that is their own address, not the partner's.
  final String? ownerEmail;

  /// Role assigned to this partner.
  final PartnerRole role;

  /// Current status of the partnership.
  final PartnershipStatus status;

  /// Short invite code the partner enters to link accounts.
  /// Empty for email-based invites.
  final String inviteCode;

  /// 'code' (default) or 'email' — how this partnership was invited.
  final String inviteType;

  /// ID of the linked `invitations` document for email invites.
  /// Needed so the invitee can accept without an invite code.
  final String? invitationId;

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
    this.ownerName,
    this.partnerEmail,
    this.ownerEmail,
    required this.role,
    required this.status,
    required this.inviteCode,
    this.inviteType = 'code',
    this.invitationId,
    required this.createdAt,
    this.acceptedAt,
    this.type = 'accountability',
  });

  /// Email of the *other* person in this partnership, from [myUid]'s view.
  ///
  /// `partnerEmail` is always the invitee's address, so on the invitee's own
  /// side of the doc it is their email — use [ownerEmail] there instead.
  String? emailOf(String? myUid) {
    if (myUid == null || myUid.isEmpty) return partnerEmail;
    return ownerUid == myUid ? partnerEmail : ownerEmail;
  }

  /// UID of the *other* person in this partnership, from [myUid]'s view.
  ///
  /// On the invitee's side of the doc `partnerUid` is their own uid, so the
  /// partner is the owner.
  String? uidOf(String? myUid) {
    if (myUid == null || myUid.isEmpty) return partnerUid;
    return ownerUid == myUid ? partnerUid : ownerUid;
  }

  /// Name of the *other* person, already corrected by the service resolve.
  String get displayName => partnerName.isNotEmpty ? partnerName : 'Partner';

  AccountabilityPartner copyWith({
    String? id,
    String? ownerUid,
    String? partnerUid,
    String? partnerName,
    String? ownerName,
    String? partnerEmail,
    String? ownerEmail,
    PartnerRole? role,
    PartnershipStatus? status,
    String? inviteCode,
    String? inviteType,
    String? invitationId,
    DateTime? createdAt,
    DateTime? acceptedAt,
    String? type,
  }) {
    return AccountabilityPartner(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      partnerUid: partnerUid ?? this.partnerUid,
      partnerName: partnerName ?? this.partnerName,
      ownerName: ownerName ?? this.ownerName,
      partnerEmail: partnerEmail ?? this.partnerEmail,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      role: role ?? this.role,
      status: status ?? this.status,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteType: inviteType ?? this.inviteType,
      invitationId: invitationId ?? this.invitationId,
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
        'ownerName': ownerName,
        'partnerEmail': partnerEmail,
        'ownerEmail': ownerEmail,
        'role': role.name,
        'status': status.name,
        'inviteCode': inviteCode,
        'inviteType': inviteType,
        'invitationId': invitationId,
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
      ownerName: json['ownerName'] as String?,
      partnerEmail: json['partnerEmail'] as String?,
      ownerEmail: json['ownerEmail'] as String?,
      role:
          PartnerRoleExtension.fromString(json['role'] as String? ?? 'friend'),
      status: PartnershipStatusExtension.fromString(
          json['status'] as String? ?? 'pending'),
      inviteCode: json['inviteCode'] as String,
      inviteType: json['inviteType'] as String? ?? 'code',
      invitationId: json['invitationId'] as String?,
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
        ownerName,
        partnerEmail,
        ownerEmail,
        role,
        status,
        inviteCode,
        inviteType,
        invitationId,
        createdAt,
        acceptedAt,
        type,
      ];
}
