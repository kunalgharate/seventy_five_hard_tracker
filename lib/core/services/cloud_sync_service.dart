import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seventy_five_hard_tracker/repositories/database_repository.dart';
import 'package:seventy_five_hard_tracker/repositories/regular_task_repository.dart';

/// Keys for SharedPreferences
const _kLastSyncTime = 'lastSyncTime';
const _kConsentGiven = 'cloudSyncConsentGiven';

/// AES-256 encrypted cloud sync service.
///
/// Encryption scope — 100% encrypted before leaving device:
///   • Challenge sessions (titles, dates, status, failure reasons)
///   • Daily progress (completion maps, journal notes, task notes)
///   • Regular tasks (titles, settings)
///   • Regular task completions
///
/// Plaintext in Firestore (by design):
///   • users/{uid} — name, email, photo (needed for partner lookups)
///   • public_progress — aggregate counts only, no task details
///   • partnerships, partner_reviews — needed for cross-user features
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  enc.Key? _aesKey;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Key derivation ───────────────────────────────────────────────────────

  /// Derives a 256-bit AES key from the Firebase UID using HKDF-SHA256.
  /// This is a proper one-way KDF — the key cannot be reversed to get the UID.
  enc.Key _deriveKey(String uid) {
    final ikm = utf8.encode(uid);
    final salt = utf8.encode('dailymettle-v1-salt');
    final info = utf8.encode('aes256-user-data');

    final hkdf = pc.HKDFKeyDerivator(pc.SHA256Digest());
    hkdf.init(pc.HkdfParameters(
      Uint8List.fromList(ikm),
      32, // 256 bits
      Uint8List.fromList(salt),
      Uint8List.fromList(info),
    ));

    final keyBytes = Uint8List(32);
    hkdf.deriveKey(null, 0, keyBytes, 0);
    return enc.Key(keyBytes);
  }

  void _ensureKey() {
    if (_aesKey == null && _auth.currentUser != null) {
      _aesKey = _deriveKey(_auth.currentUser!.uid);
    }
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  /// Signs in with Google, saves user profile to Firestore (first login only).
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

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user != null) {
        _aesKey = _deriveKey(user.uid);
        await _upsertUserProfile(user);
      }
      return user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      if (kDebugMode)
        debugPrint('[CloudSync] Google sign-in: ${e.description}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[CloudSync] Sign-in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _aesKey = null;
  }

  // ── User profile ─────────────────────────────────────────────────────────

  /// Creates the user doc on first login; only updates lastLoginAt on repeat.
  Future<void> _upsertUserProfile(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'id': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set(
        {'lastLoginAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
  }

  // ── Consent ──────────────────────────────────────────────────────────────

  Future<bool> hasConsentBeenGiven() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConsentGiven) ?? false;
  }

  Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsentGiven, true);
  }

  // ── Auto-sync ────────────────────────────────────────────────────────────

  /// Called after sign-in or on internet reconnect.
  /// Silently syncs if the user is signed in and consent was given.
  Future<void> autoSync(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) async {
    if (!isSignedIn) return;
    if (!await hasConsentBeenGiven()) return;
    await syncToCloud(db, taskRepo);
  }

  // ── Sync to cloud ────────────────────────────────────────────────────────

  /// Encrypts and uploads all user data to Firestore.
  /// Returns true on success, false on any failure.
  Future<bool> syncToCloud(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) async {
    _ensureKey();
    if (!isSignedIn || _aesKey == null) return false;

    try {
      final uid = currentUser!.uid;

      // 1. Gather all local data
      final sessions = db.getAllSessions();
      final allProgress = <Map<String, dynamic>>[];
      for (final s in sessions) {
        for (final p in db.getProgressForSession(s.startDate)) {
          allProgress.add(p.toJson());
        }
      }
      final regularTasks = taskRepo.getAllTasks();
      final regularCompletions = <Map<String, dynamic>>[];
      // Completions are stored by date key — iterate last 365 days
      final today = DateTime.now();
      for (int i = 0; i < 365; i++) {
        final date = today.subtract(Duration(days: i));
        final c = taskRepo.getCompletion(date);
        if (c != null) regularCompletions.add(c.toJson());
      }

      // 2. Build payload — everything that is personal/sensitive
      final payload = jsonEncode({
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'progress': allProgress,
        'regularTasks': regularTasks.map((t) => t.toJson()).toList(),
        'regularCompletions': regularCompletions,
        'syncedAt': DateTime.now().toIso8601String(),
        'version': 2,
      });

      // 3. Encrypt with AES-256-CBC + random IV
      final encrypted = _encrypt(payload);

      // 4. Upload to Firestore — only ciphertext touches the server
      await _firestore.collection('user_data').doc(uid).set({
        'enc': encrypted['cipher'],
        'iv': encrypted['iv'],
        'updatedAt': FieldValue.serverTimestamp(),
        // version field so future migrations can detect the schema
        'schemaVersion': 2,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSyncTime, DateTime.now().toIso8601String());

      if (kDebugMode) debugPrint('[CloudSync] Sync complete');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CloudSync] Sync failed: $e');
      return false;
    }
  }

  // ── Sync from cloud ──────────────────────────────────────────────────────

  /// Downloads and decrypts user data from Firestore.
  /// Returns the decoded payload map, or null if nothing found.
  Future<Map<String, dynamic>?> syncFromCloud() async {
    _ensureKey();
    if (!isSignedIn || _aesKey == null) return null;

    try {
      final uid = currentUser!.uid;
      final doc = await _firestore.collection('user_data').doc(uid).get();

      if (!doc.exists) return null;
      final data = doc.data()!;

      // Support both v1 (field: 'data') and v2 (field: 'enc') schemas
      final cipher = (data['enc'] ?? data['data']) as String?;
      if (cipher == null) return null;

      final ivBase64 = data['iv'] as String?;
      final decrypted = _decrypt(cipher, ivBase64: ivBase64);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('[CloudSync] Restore failed: $e');
      return null;
    }
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastSyncTime);
  }

  // ── AES-256 encryption helpers ───────────────────────────────────────────

  /// Encrypts [plain] with AES-256-CBC using a fresh random IV each call.
  /// Returns {'cipher': base64, 'iv': base64}.
  Map<String, String> _encrypt(String plain) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_aesKey!, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    return {'cipher': encrypted.base64, 'iv': iv.base64};
  }

  /// Decrypts [cipherBase64] using the provided IV (base64).
  /// Falls back to zero-IV for backwards compatibility with v1 backups.
  String _decrypt(String cipherBase64, {String? ivBase64}) {
    final iv =
        ivBase64 != null ? enc.IV.fromBase64(ivBase64) : enc.IV.fromLength(16);
    final encrypter = enc.Encrypter(enc.AES(_aesKey!, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(cipherBase64, iv: iv);
  }
}
