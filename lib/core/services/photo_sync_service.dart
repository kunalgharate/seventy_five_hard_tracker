import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Uploads task proof photos to Cloudinary.
class PhotoSyncService {
  static const String _cloudName = 'dudjztvui';
  static const String _uploadPreset = 'jiremalisamajapp-prod';
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  static final PhotoSyncService _instance = PhotoSyncService._internal();
  factory PhotoSyncService() => _instance;
  PhotoSyncService._internal();

  final _picker = ImagePicker();

  /// Pick a photo from camera or gallery.
  Future<File?> pickPhoto({bool fromCamera = true}) async {
    if (kDebugMode) {
      debugPrint('[PhotoSyncService] pickPhoto: fromCamera=$fromCamera');
    }
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) {
      if (kDebugMode) {
        debugPrint(
            '[PhotoSyncService] pickPhoto: user cancelled or permission denied');
      }
      return null;
    }
    if (kDebugMode) {
      debugPrint('[PhotoSyncService] pickPhoto: path=${picked.path}');
    }
    return File(picked.path);
  }

  /// Upload photo to Cloudinary. Returns secure URL or null.
  Future<String?> uploadPhoto(
      File file, String challengeId, DateTime date) async {
    if (kDebugMode) {
      debugPrint(
          '[PhotoSyncService] uploadPhoto: challengeId=$challengeId date=$date');
      try {
        final stat = await file.stat();
        debugPrint(
            '[PhotoSyncService] uploadPhoto: file size=${stat.size} bytes');
      } catch (_) {}
    }

    try {
      final compressed = await _compressImage(file);
      if (kDebugMode) {
        final s = await compressed.stat();
        debugPrint(
            '[PhotoSyncService] uploadPhoto: compressed size=${s.size} bytes');
      }

      final result = await _uploadToCloudinary(compressed);
      if (result == null) {
        if (kDebugMode) {
          debugPrint(
              '[PhotoSyncService] uploadPhoto: Cloudinary upload returned null');
        }
        return null;
      }

      final url = result['secure_url'] as String?;
      if (kDebugMode) {
        debugPrint('[PhotoSyncService] uploadPhoto: Cloudinary URL=$url');
      }
      return url;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PhotoSyncService] uploadPhoto: FAILED — $e');
        debugPrint(
            '[PhotoSyncService] uploadPhoto: error type=${e.runtimeType}');
      }
      return null;
    }
  }

  Future<File> _compressImage(File imageFile) async {
    try {
      final targetPath =
          '${imageFile.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 80,
        minWidth: 1080,
        minHeight: 1080,
      );

      if (compressedXFile != null) {
        final compressedFile = File(compressedXFile.path);
        if (await compressedFile.exists()) {
          final originalSize = await imageFile.length();
          final compressedSize = await compressedFile.length();
          if (kDebugMode) {
            debugPrint(
                'Original: ${(originalSize / 1024).toStringAsFixed(2)} KB');
            debugPrint(
                'Compressed: ${(compressedSize / 1024).toStringAsFixed(2)} KB');
          }
          return compressedFile;
        }
      }

      return imageFile;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Compression failed: $e');
      }
      return imageFile;
    }
  }

  Future<Map<String, dynamic>?> _uploadToCloudinary(File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'task_proofs';

      final multipartFile =
          await http.MultipartFile.fromPath('file', imageFile.path);
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'secure_url': data['secure_url'],
          'public_id': data['public_id'],
        };
      }

      if (kDebugMode) {
        debugPrint(
            '[PhotoSyncService] Cloudinary upload failed: status=${response.statusCode} body=${response.body}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PhotoSyncService] Cloudinary upload error: $e');
      }
      return null;
    }
  }
}
