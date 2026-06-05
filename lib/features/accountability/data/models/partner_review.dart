import 'package:equatable/equatable.dart';

/// Whether a partner approved or rejected a day's submission.
enum ReviewDecision { approved, rejected, pending }

extension ReviewDecisionExtension on ReviewDecision {
  static ReviewDecision fromString(String value) {
    return ReviewDecision.values.firstWhere(
      (d) => d.name == value,
      orElse: () => ReviewDecision.pending,
    );
  }

  String get label {
    switch (this) {
      case ReviewDecision.approved:
        return 'Approved';
      case ReviewDecision.rejected:
        return 'Needs Work';
      case ReviewDecision.pending:
        return 'Pending Review';
    }
  }
}

/// A review left by an accountability partner for a specific day.
class PartnerReview extends Equatable {
  /// Firestore document ID.
  final String id;

  /// UID of the user whose progress is being reviewed.
  final String subjectUid;

  /// UID of the partner who wrote the review.
  final String reviewerUid;

  /// Display name of the reviewer.
  final String reviewerName;

  /// The date (YYYY-MM-DD) this review covers.
  final String dateKey;

  /// Approve / reject / pending.
  final ReviewDecision decision;

  /// Optional comment or motivational message.
  final String? comment;

  /// When the review was submitted.
  final DateTime createdAt;

  const PartnerReview({
    required this.id,
    required this.subjectUid,
    required this.reviewerUid,
    required this.reviewerName,
    required this.dateKey,
    required this.decision,
    this.comment,
    required this.createdAt,
  });

  PartnerReview copyWith({
    String? id,
    String? subjectUid,
    String? reviewerUid,
    String? reviewerName,
    String? dateKey,
    ReviewDecision? decision,
    String? comment,
    DateTime? createdAt,
  }) {
    return PartnerReview(
      id: id ?? this.id,
      subjectUid: subjectUid ?? this.subjectUid,
      reviewerUid: reviewerUid ?? this.reviewerUid,
      reviewerName: reviewerName ?? this.reviewerName,
      dateKey: dateKey ?? this.dateKey,
      decision: decision ?? this.decision,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectUid': subjectUid,
        'reviewerUid': reviewerUid,
        'reviewerName': reviewerName,
        'dateKey': dateKey,
        'decision': decision.name,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PartnerReview.fromJson(Map<String, dynamic> json) {
    return PartnerReview(
      id: json['id'] as String,
      subjectUid: json['subjectUid'] as String,
      reviewerUid: json['reviewerUid'] as String,
      reviewerName: json['reviewerName'] as String? ?? 'Partner',
      dateKey: json['dateKey'] as String,
      decision: ReviewDecisionExtension.fromString(
          json['decision'] as String? ?? 'pending'),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        subjectUid,
        reviewerUid,
        reviewerName,
        dateKey,
        decision,
        comment,
        createdAt,
      ];
}
