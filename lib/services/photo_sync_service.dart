import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

/// Uploads task proof photos to Firebase Storage.
class PhotoSyncService {
  static final PhotoSyncService _instance = PhotoSyncService._internal();
  factory PhotoSyncService() => _instance;
  PhotoSyncService._internal();

  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  /// Pick a photo from camera or gallery.
  Future<File?> pickPhoto({bool fromCamera = true}) async {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    return picked != null ? File(picked.path) : null;
  }

  /// Upload photo to Firebase Storage. Returns download URL or null.
  Future<String?> uploadPhoto(
      File file, String challengeId, DateTime date) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final path = 'users/${user.uid}/photos/$dateStr/$challengeId.jpg';
      final ref = _storage.ref().child(path);

      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) print('Photo upload failed: $e');
      return null;
    }
  }
}
