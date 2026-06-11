import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';

/// Encrypts and syncs user data to Firestore.
/// All data is AES-encrypted before upload — Firestore stores only ciphertext.
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // 32-char AES key derived from UID
  encrypt.Key? _encryptionKey;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  void _ensureEncryptionKey() {
    if (_encryptionKey == null && _auth.currentUser != null) {
      _initEncryption(_auth.currentUser!.uid);
    }
  }

  void _initEncryption(String uid) {
    // Derive a stable 32-byte key from the UID
    final keyStr = (uid * 3).substring(0, 32);
    _encryptionKey = encrypt.Key.fromUtf8(keyStr);
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Sign in with Google and save user profile to Firestore.
  Future<User?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      final googleUser = await googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      final idToken = googleUser.authentication.idToken;
      final clientAuth = await googleUser.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);

      final credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        _initEncryption(user.uid);
        await _saveUserToFirestore(user);
      }
      return user;
    } on GoogleSignInException catch (e) {
      // User cancelled — not an error
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      if (kDebugMode) print('Google sign-in failed: ${e.description}');
      return null;
    } catch (e) {
      if (kDebugMode) print('Sign-in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _encryptionKey = null;
  }

  /// Saves user profile to Firestore on first login only.
  Future<void> _saveUserToFirestore(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      await docRef.set({
        'id': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.set(
        {'lastLoginAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
  }

  // ── Sync ──────────────────────────────────────────────────────────────────

  /// Upload all local data to Firestore (AES encrypted).
  Future<bool> syncToCloud(DatabaseRepository repository) async {
    _ensureEncryptionKey();
    if (!isSignedIn || _encryptionKey == null) return false;

    try {
      final uid = currentUser!.uid;
      final sessions = repository.getAllSessions();
      final allProgress = <Map<String, dynamic>>[];

      for (final session in sessions) {
        final progress = repository.getProgressForSession(session.startDate);
        for (final p in progress) {
          allProgress.add(p.toJson());
        }
      }

      final payload = jsonEncode({
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'progress': allProgress,
        'syncedAt': DateTime.now().toIso8601String(),
      });

      final encryptedResult = _encrypt(payload);

      await _firestore.collection('user_data').doc(uid).set({
        'data': encryptedResult['cipher'],
        'iv': encryptedResult['iv'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastSyncTime', DateTime.now().toIso8601String());

      return true;
    } catch (e) {
      if (kDebugMode) print('Sync to cloud failed: $e');
      return false;
    }
  }

  /// Download and decrypt data from Firestore.
  Future<Map<String, dynamic>?> syncFromCloud() async {
    _ensureEncryptionKey();
    if (!isSignedIn || _encryptionKey == null) return null;

    try {
      final uid = currentUser!.uid;
      final doc = await _firestore.collection('user_data').doc(uid).get();

      if (!doc.exists || doc.data()?['data'] == null) return null;

      final docData = doc.data()!;
      final cipher = docData['data'] as String;
      // Support both new (random IV stored) and old (fixed IV) backups
      final ivBase64 = docData['iv'] as String?;

      final decrypted = _decrypt(cipher, ivBase64: ivBase64);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) print('Sync from cloud failed: $e');
      return null;
    }
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastSyncTime');
  }

  // ── Encryption helpers ────────────────────────────────────────────────────

  /// Encrypts [plainText] with a random IV each time.
  /// Returns a map with 'cipher' (base64) and 'iv' (base64).
  Map<String, String> _encrypt(String plainText) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return {
      'cipher': encrypted.base64,
      'iv': iv.base64,
    };
  }

  /// Decrypts [cipherBase64].
  /// Uses stored [ivBase64] if provided, otherwise falls back to zero IV
  /// for backwards compatibility with old backups.
  String _decrypt(String cipherBase64, {String? ivBase64}) {
    final iv = ivBase64 != null
        ? encrypt.IV.fromBase64(ivBase64)
        : encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));
    return encrypter.decrypt64(cipherBase64, iv: iv);
  }
}
