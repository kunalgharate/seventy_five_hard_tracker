import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum AccountabilityTaskStatus { requested, pending, completed, declined, approved }

extension AccountabilityTaskStatusExtension on AccountabilityTaskStatus {
  String get label {
    switch (this) {
      case AccountabilityTaskStatus.requested:
        return 'Pending';
      case AccountabilityTaskStatus.pending:
        return 'Accepted';
      case AccountabilityTaskStatus.completed:
        return 'Completed';
      case AccountabilityTaskStatus.declined:
        return 'Declined';
      case AccountabilityTaskStatus.approved:
        return 'Approved';
    }
  }

  static AccountabilityTaskStatus fromString(String v) =>
      AccountabilityTaskStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => AccountabilityTaskStatus.pending,
      );
}

enum ProofStatus { not_required, submitted, approved, rejected }

extension ProofStatusExtension on ProofStatus {
  String get label {
    switch (this) {
      case ProofStatus.not_required:
        return 'Not Required';
      case ProofStatus.submitted:
        return 'Proof Submitted';
      case ProofStatus.approved:
        return 'Approved';
      case ProofStatus.rejected:
        return 'Rejected';
    }
  }

  static ProofStatus fromString(String v) => ProofStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ProofStatus.not_required,
      );
}

/// A task assigned by one user to an accountability partner.
/// Stored in Firestore `accountability_tasks/{id}`.
class AccountabilityTask extends Equatable {
  final String id;

  /// UID of the user who created/assigned this task.
  final String assignedByUid;

  /// Display name of the assigner.
  final String assignedByName;

  /// UID of the user who is accountable for completing it.
  final String accountableUid;

  /// Additional UIDs accountable for this task (collaborators).
  final List<String> accountableUserIds;

  /// Display name of the accountable person.
  final String accountableName;

  /// The partnership this task belongs to.
  final String partnershipId;

  /// The challenge ID this task was created from (links back to the daily task card).
  /// Null for manually created tasks.
  final String? challengeId;

  final String title;
  final String? description;
  final AccountabilityTaskStatus status;
  final DateTime? dueDate;
  final DateTime assignedAt;
  final DateTime? completedAt;

  // ── Photo proof fields ──
  final ProofStatus proofStatus;
  final String? proofUrl;
  final String? proofReviewComment;
  final DateTime? proofSubmittedAt;
  final DateTime? proofReviewedAt;

  const AccountabilityTask({
    required this.id,
    required this.assignedByUid,
    required this.assignedByName,
    required this.accountableUid,
    required this.accountableName,
    required this.partnershipId,
    this.challengeId,
    required this.title,
    this.description,
    required this.status,
    this.dueDate,
    required this.assignedAt,
    this.completedAt,
    this.proofStatus = ProofStatus.not_required,
    this.proofUrl,
    this.proofReviewComment,
    this.proofSubmittedAt,
    this.proofReviewedAt,
    this.accountableUserIds = const [],
  });

  bool get isApproved => status == AccountabilityTaskStatus.approved;
  bool get isCompleted => status == AccountabilityTaskStatus.completed;
  bool get isFinished => isCompleted || isApproved;
  bool get isPending => status == AccountabilityTaskStatus.pending;
  bool get isRequested => status == AccountabilityTaskStatus.requested;
  bool get isDeclined => status == AccountabilityTaskStatus.declined;
  bool get hasProofSubmitted => proofStatus == ProofStatus.submitted;
  bool get hasProofApproved => proofStatus == ProofStatus.approved;
  bool get hasProofRejected => proofStatus == ProofStatus.rejected;

  AccountabilityTask copyWith({
    AccountabilityTaskStatus? status,
    DateTime? completedAt,
    String? title,
    String? description,
    DateTime? dueDate,
    String? challengeId,
    ProofStatus? proofStatus,
    String? proofUrl,
    String? proofReviewComment,
    DateTime? proofSubmittedAt,
    DateTime? proofReviewedAt,
    List<String>? accountableUserIds,
  }) =>
      AccountabilityTask(
        id: id,
        assignedByUid: assignedByUid,
        assignedByName: assignedByName,
        accountableUid: accountableUid,
        accountableName: accountableName,
        partnershipId: partnershipId,
        challengeId: challengeId ?? this.challengeId,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        dueDate: dueDate ?? this.dueDate,
        assignedAt: assignedAt,
        completedAt: completedAt ?? this.completedAt,
        proofStatus: proofStatus ?? this.proofStatus,
        proofUrl: proofUrl ?? this.proofUrl,
        proofReviewComment: proofReviewComment ?? this.proofReviewComment,
        proofSubmittedAt: proofSubmittedAt ?? this.proofSubmittedAt,
        proofReviewedAt: proofReviewedAt ?? this.proofReviewedAt,
        accountableUserIds: accountableUserIds ?? this.accountableUserIds,
      );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return null;
  }

  static DateTime _parseDateRequired(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory AccountabilityTask.fromFirestore(Map<String, dynamic> d,
          {String? id}) =>
      AccountabilityTask(
        id: id ?? d['id'] as String,
        assignedByUid: d['assignedByUid'] as String,
        assignedByName: d['assignedByName'] as String? ?? 'Partner',
        accountableUid: d['accountableUid'] as String,
        accountableName: d['accountableName'] as String? ?? 'Partner',
        partnershipId: d['partnershipId'] as String,
        challengeId: d['challengeId'] as String?,
        title: d['title'] as String,
        description: d['description'] as String?,
        status: AccountabilityTaskStatusExtension.fromString(
            d['status'] as String? ?? 'pending'),
        dueDate: _parseDate(d['dueDate']),
        assignedAt: _parseDateRequired(d['assignedAt']),
        completedAt: _parseDate(d['completedAt']),
        proofStatus: ProofStatusExtension.fromString(
            d['proofStatus'] as String? ?? 'not_required'),
        proofUrl: d['proofUrl'] as String?,
        proofReviewComment: d['proofReviewComment'] as String?,
        proofSubmittedAt: _parseDate(d['proofSubmittedAt']),
        proofReviewedAt: _parseDate(d['proofReviewedAt']),
        accountableUserIds: (d['accountableUserIds'] as List<dynamic>?)
                ?.cast<String>() ?? [d['accountableUid'] as String],
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'assignedByUid': assignedByUid,
        'assignedByName': assignedByName,
        'accountableUid': accountableUid,
        'accountableName': accountableName,
        'partnershipId': partnershipId,
        'challengeId': challengeId,
        'title': title,
        'description': description,
        'status': status.name,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
        'assignedAt': FieldValue.serverTimestamp(),
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'proofStatus': proofStatus.name,
        'proofUrl': proofUrl,
        'proofReviewComment': proofReviewComment,
        'proofSubmittedAt':
            proofSubmittedAt != null ? Timestamp.fromDate(proofSubmittedAt!) : null,
        'proofReviewedAt':
            proofReviewedAt != null ? Timestamp.fromDate(proofReviewedAt!) : null,
        'accountableUserIds': accountableUserIds,
      };

  @override
  List<Object?> get props => [
        id,
        assignedByUid,
        accountableUid,
        accountableUserIds,
        partnershipId,
        challengeId,
        title,
        description,
        status,
        dueDate,
        assignedAt,
        completedAt,
        proofStatus,
        proofUrl,
        proofReviewComment,
        proofSubmittedAt,
        proofReviewedAt,
      ];
}
