import 'package:equatable/equatable.dart';

class Collaborator extends Equatable {
  final String uid;
  final String email;
  final String name;
  final String? photoUrl;

  const Collaborator({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
  });

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'email': email,
        'name': name,
        'photoUrl': photoUrl,
      };

  factory Collaborator.fromFirestore(Map<String, dynamic> data) {
    return Collaborator(
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Collaborator copyWith({
    String? uid,
    String? email,
    String? name,
    String? photoUrl,
  }) {
    return Collaborator(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  String get initials {
    if (name.isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  @override
  List<Object?> get props => [uid, email, name, photoUrl];
}
