import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a registered app user stored in the `users` Firestore collection.
/// This powers email-based partner lookup — the collection is written to on
/// every sign-in so it stays up-to-date.
class AppUser extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
  });

  // ── Firestore ──────────────────────────────────────────────────────────────

  factory AppUser.fromFirestore(Map<String, dynamic> data) {
    DateTime createdAt;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else if (raw is String) {
      createdAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return AppUser(
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

  // ── Equatable ──────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [uid, email, displayName, photoUrl, createdAt];
}
