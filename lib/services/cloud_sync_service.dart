import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/database_repository.dart';

/// Encrypts and syncs user data to Firestore.
/// All data is AES-encrypted before upload — Firestore stores only ciphertext.
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // 32-char key derived from UID (set after sign-in)
  encrypt.Key? _encryptionKey;
  final _iv = encrypt.IV.fromLength(16);

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  void _ensureEncryptionKey() {
    if (_encryptionKey == null && _auth.currentUser != null) {
      _initEncryption(_auth.currentUser!.uid);
    }
  }

  // ── Auth ─────────────────────────────────────────────────────────

  Future<User?> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      _initEncryption(result.user!.uid);
      return result.user;
    } catch (e) {
      if (kDebugMode) print('Anonymous sign-in failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _encryptionKey = null;
  }

  void _initEncryption(String uid) {
    // Derive a 32-byte key from UID (padded/truncated)
    final keyStr = (uid * 2).substring(0, 32);
    _encryptionKey = encrypt.Key.fromUtf8(keyStr);
  }

  // ── Sync ─────────────────────────────────────────────────────────

  /// Upload all local data to Firestore (encrypted).
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

      final encrypted = _encrypt(payload);

      await _firestore.collection('user_data').doc(uid).set({
        'data': encrypted,
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

      final decrypted = _decrypt(doc.data()!['data'] as String);
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

  // ── Encryption helpers ──────────────────────────────────────────

  String _encrypt(String plainText) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));
    return encrypter.encrypt(plainText, iv: _iv).base64;
  }

  String _decrypt(String cipherText) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));
    return encrypter.decrypt64(cipherText, iv: _iv);
  }
}
