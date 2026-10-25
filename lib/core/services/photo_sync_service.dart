import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seventy_five_hard_tracker/core/services/cloudinary_upload_signer.dart';

/// Uploads task proof photos to Cloudinary.
class PhotoSyncService {
  static final PhotoSyncService _instance = PhotoSyncService._internal();
  factory PhotoSyncService({
    CloudinaryUploadSigner? signer,
    CloudinarySignerConfiguration? configuration,
  }) {
    if (signer != null || configuration != null) {
      _instance.configureSigner(
        signer: signer,
        configuration: configuration,
      );
    }
    return _instance;
  }

  PhotoSyncService._internal()
      : _picker = ImagePicker(),
        _configuration = CloudinarySignerConfiguration.fromEnvironment(),
        _signer = _createEnvironmentSigner();

  @visibleForTesting
  PhotoSyncService.forTesting({
    ImagePicker? picker,
    CloudinaryUploadSigner? signer,
    CloudinarySignerConfiguration? configuration,
  })  : _picker = picker ?? ImagePicker(),
        _signer = signer,
        _configuration = configuration;

  final ImagePicker _picker;
  CloudinaryUploadSigner? _signer;
  CloudinarySignerConfiguration? _configuration;

  static CloudinaryUploadSigner? _createEnvironmentSigner() {
    final configuration = CloudinarySignerConfiguration.fromEnvironment();
    if (configuration == null || !configuration.isValid) return null;
    return HttpCloudinaryUploadSigner(endpoint: configuration.endpoint);
  }

  /// Configures the signed-upload path. Passing null clears that component;
  /// uploads fail closed until both a signer and valid configuration exist.
  @visibleForTesting
  void configureSigner({
    CloudinaryUploadSigner? signer,
    CloudinarySignerConfiguration? configuration,
  }) {
    _signer = signer;
    _configuration = configuration;
  }

  @visibleForTesting
  bool get hasConfiguredSigner =>
      _signer != null && (_configuration?.isValid ?? _signer != null);

  /// Pick a photo from camera or gallery.
  ///
  /// The full-resolution original is returned on purpose: downscaling here
  /// (maxWidth/imageQuality) would throw away detail *before* the lossless-ish
  /// compression step in [_compressImage].
  Future<File?> pickPhoto({bool fromCamera = true}) async {
    if (kDebugMode) {
      debugPrint('[PhotoSyncService] pickPhoto: fromCamera=$fromCamera');
    }
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
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

  /// Upload photo to Cloudinary (or Firebase Storage fallback). Returns secure URL or null.
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

      if (hasConfiguredSigner) {
        final result = await _uploadToCloudinary(
          compressed,
          challengeId: challengeId,
          date: date,
        );
        if (result != null) {
          final url = result['secure_url'] as String?;
          if (url != null && url.isNotEmpty) {
            if (kDebugMode) {
              debugPrint('[PhotoSyncService] uploadPhoto: Cloudinary URL=$url');
            }
            return url;
          }
        }
      }

      // Fallback to Firebase Storage
      if (kDebugMode) {
        debugPrint(
            '[PhotoSyncService] uploadPhoto: using Firebase Storage fallback');
      }
      return await _uploadToFirebaseStorage(
        compressed,
        challengeId: challengeId,
        date: date,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PhotoSyncService] uploadPhoto: FAILED — $e');
        debugPrint(
            '[PhotoSyncService] uploadPhoto: error type=${e.runtimeType}');
      }
      return null;
    }
  }

  /// Compresses for upload while keeping the photo visually identical.
  ///
  /// quality 92 + max 1920px is the practical "no visible loss" point for
  /// phone photos — file size drops 5-10x with no perceivable difference.
  /// If compression somehow produces a larger file than the original, the
  /// original is uploaded untouched.
  Future<File> _compressImage(File imageFile) async {
    try {
      final targetPath =
          '${imageFile.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 92,
        minWidth: 1920,
        minHeight: 1920,
        keepExif: true,
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
          // Never upload a "compressed" file that is bigger than the source.
          if (compressedSize < originalSize) return compressedFile;
          if (kDebugMode) {
            debugPrint('[PhotoSyncService] compression grew the file — '
                'uploading the original instead');
          }
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

  Future<Map<String, dynamic>?> _uploadToCloudinary(
    File imageFile, {
    required String challengeId,
    required DateTime date,
  }) async {
    final signer = _signer;
    final configuration = _configuration;
    if (signer == null || configuration == null || !configuration.isValid) {
      if (kDebugMode) {
        debugPrint(
          '[PhotoSyncService] signed Cloudinary uploader is not configured',
        );
      }
      return null;
    }

    try {
      // Cloudinary signatures expire quickly, so the signature timestamp is
      // the current time. The task date is used only to keep public IDs
      // stable for a task proof.
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final proofDate = date.toIso8601String().split('T').first;
      final request = CloudinarySignRequest(
        parameters: {
          'folder': 'task_proofs',
          'public_id': '${challengeId}_$proofDate',
          'timestamp': timestamp.toString(),
        },
      );
      // Get Firebase ID token for authenticated signer request
      String? authToken;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          authToken = await user.getIdToken();
        }
      } catch (_) {
        // Token unavailable; proceed without it (backend may reject)
      }
      final signed = await signer.sign(request, authToken: authToken);
      if (signed.timestamp.toString() != request.parameters['timestamp']) {
        throw const CloudinarySignerException(
          'Cloudinary signer timestamp does not match the requested payload.',
        );
      }
      final apiKey = signed.apiKey ?? configuration.apiKey;
      final cloudName = signed.cloudName ?? configuration.cloudName;
      if (apiKey == null || apiKey.isEmpty || cloudName.isEmpty) {
        throw const CloudinarySignerException(
          'Cloudinary signer response/configuration did not provide api key '
          'and cloud name.',
        );
      }

      final uploadUrl = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final multipartRequest = http.MultipartRequest('POST', uploadUrl);
      multipartRequest.fields.addAll({
        'api_key': apiKey,
        'folder': request.parameters['folder']!,
        'public_id': request.parameters['public_id']!,
        'signature': signed.signature,
        'timestamp': signed.timestamp.toString(),
      });

      final multipartFile =
          await http.MultipartFile.fromPath('file', imageFile.path);
      multipartRequest.files.add(multipartFile);

      final streamedResponse = await multipartRequest.send();
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

  /// Upload profile avatar to Cloudinary (or Firebase Storage fallback). Returns secure URL or null.
  ///
  /// Uses a dedicated 'profile_avatars' folder and the user's UID as public_id
  /// so each user has exactly one avatar that gets replaced on re-upload.
  Future<String?> uploadAvatar(File file, String uid) async {
    if (kDebugMode) {
      debugPrint('[PhotoSyncService] uploadAvatar: uid=$uid');
      try {
        final stat = await file.stat();
        debugPrint(
            '[PhotoSyncService] uploadAvatar: file size=${stat.size} bytes');
      } catch (_) {}
    }

    try {
      final compressed = await _compressImage(file);
      if (kDebugMode) {
        final s = await compressed.stat();
        debugPrint(
            '[PhotoSyncService] uploadAvatar: compressed size=${s.size} bytes');
      }

      if (hasConfiguredSigner) {
        final result = await _uploadToCloudinaryAvatar(compressed, uid: uid);
        if (result != null) {
          final url = result['secure_url'] as String?;
          if (url != null && url.isNotEmpty) {
            if (kDebugMode) {
              debugPrint(
                  '[PhotoSyncService] uploadAvatar: Cloudinary URL=$url');
            }
            return url;
          }
        }
      }

      // Fallback to Firebase Storage
      if (kDebugMode) {
        debugPrint(
            '[PhotoSyncService] uploadAvatar: using Firebase Storage fallback');
      }
      return await _uploadAvatarToFirebaseStorage(compressed, uid: uid);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PhotoSyncService] uploadAvatar: FAILED — $e');
        debugPrint(
            '[PhotoSyncService] uploadAvatar: error type=${e.runtimeType}');
      }
      return null;
    }
  }

  /// Upload photo to Firebase Storage fallback.
  Future<String?> _uploadToFirebaseStorage(
    File imageFile, {
    required String challengeId,
    required DateTime date,
  }) async {
    try {
      final proofDate = date.toIso8601String().split('T').first;
      final fileName = '${challengeId}_$proofDate.jpg';
      final ref =
          FirebaseStorage.instance.ref().child('task_proofs').child(fileName);

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await uploadTask.ref.getDownloadURL();
      if (kDebugMode) {
        debugPrint('[PhotoSyncService] Firebase Storage upload URL=$url');
      }
      return url;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PhotoSyncService] Firebase Storage upload failed: $e');
      }
      return null;
    }
  }

  /// Upload avatar to Firebase Storage fallback.
  Future<String?> _uploadAvatarToFirebaseStorage(
    File imageFile, {
    required String uid,
  }) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_avatars')
          .child('$uid.jpg');

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await uploadTask.ref.getDownloadURL();
      if (kDebugMode) {
        debugPrint('[PhotoSyncService] Firebase Storage avatar URL=$url');
      }
      return url;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[PhotoSyncService] Firebase Storage avatar upload failed: $e');
      }
      return null;
    }
  }

  /// Upload avatar to Cloudinary with a stable public_id based on user UID.
  Future<Map<String, dynamic>?> _uploadToCloudinaryAvatar(
    File imageFile, {
    required String uid,
  }) async {
    final signer = _signer;
    final configuration = _configuration;
    if (signer == null || configuration == null || !configuration.isValid) {
      if (kDebugMode) {
        debugPrint(
          '[PhotoSyncService] signed Cloudinary uploader is not configured',
        );
      }
      return null;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final request = CloudinarySignRequest(
        parameters: {
          'folder': 'profile_avatars',
          'public_id': uid,
          'timestamp': timestamp.toString(),
          'overwrite': 'true',
        },
      );
      final signed = await signer.sign(request);
      if (signed.timestamp.toString() != request.parameters['timestamp']) {
        throw const CloudinarySignerException(
          'Cloudinary signer timestamp does not match the requested payload.',
        );
      }
      final apiKey = signed.apiKey ?? configuration.apiKey;
      final cloudName = signed.cloudName ?? configuration.cloudName;
      // cloudName is guaranteed non-null (CloudinarySignerConfiguration.cloudName is non-nullable)
      if (apiKey == null || apiKey.isEmpty || cloudName.isEmpty) {
        throw const CloudinarySignerException(
          'Cloudinary signer response/configuration did not provide api key '
          'and cloud name.',
        );
      }

      final uploadUrl = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final multipartRequest = http.MultipartRequest('POST', uploadUrl);
      multipartRequest.fields.addAll({
        'api_key': apiKey,
        'folder': request.parameters['folder']!,
        'public_id': request.parameters['public_id']!,
        'signature': signed.signature,
        'timestamp': signed.timestamp.toString(),
        'overwrite': 'true',
      });

      final multipartFile =
          await http.MultipartFile.fromPath('file', imageFile.path);
      multipartRequest.files.add(multipartFile);

      final streamedResponse = await multipartRequest.send();
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
            '[PhotoSyncService] Cloudinary avatar upload failed: status=${response.statusCode} body=${response.body}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PhotoSyncService] Cloudinary avatar upload error: $e');
      }
      return null;
    }
  }
}
