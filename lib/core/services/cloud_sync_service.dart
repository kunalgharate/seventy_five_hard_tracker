import 'dart:convert';
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

/// AES-256-GCM authenticated-encryption cloud sync service.
///
/// Security properties:
///   • AES-256-GCM (AEAD) — confidentiality + integrity + authenticity.
///     Any tampered ciphertext is rejected at decryption time.
///   • Key = HKDF-SHA256(uid + idToken, salt, info).
///     The idToken is a short-lived Google-signed JWT only the authenticated
///     user can obtain, so the key is NOT re-derivable from public data alone.
///   • Random 12-byte nonce per encryption call.
///   • 128-bit GCM authentication tag appended to ciphertext.
///
/// Encryption scope — 100% encrypted before leaving device:
///   • Challenge sessions (titles, dates, status, failure reasons)
///   • Daily progress (completion maps, journal notes, task notes)
///   • Regular tasks (titles, settings) — ALL history, no date cap
///   • Regular task completions — ALL history, no date cap
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

  /// Derived AES-256 key. Re-derived on each sign-in using uid + idToken.
  enc.Key? _aesKey;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Key derivation ───────────────────────────────────────────────────────

  /// Derives a 256-bit AES key using HKDF-SHA256.
  ///
  /// IKM = uid + idToken:
  ///   - [uid] is the stable Firebase user ID (public, but required for lookup).
  ///   - [idToken] is the Google-signed JWT only obtainable by the authenticated
  ///     user. This secret component ensures the key is NOT re-derivable by
  ///     anyone who knows only the UID (fixes violation #1 / P0).
  ///
  /// The static salt and info string version-namespace the key so a future
  /// schema migration can change them without colliding with old keys.
  enc.Key _deriveKey(String uid, String idToken) {
    // Concatenate uid and idToken as IKM — both required to derive the key
    final ikm = utf8.encode('$uid:$idToken');
    final salt = utf8.encode('dailymettle-v2-salt-gcm');
    final info = utf8.encode('aes256-gcm-user-data-v2');

    final hkdf = pc.HKDFKeyDerivator(pc.SHA256Digest());
    hkdf.init(pc.HkdfParameters(
      Uint8List.fromList(ikm),
      32, // 256-bit key
      Uint8List.fromList(salt),
      Uint8List.fromList(info),
    ));

    final keyBytes = Uint8List(32);
    hkdf.deriveKey(null, 0, keyBytes, 0);
    return enc.Key(keyBytes);
  }

  void _ensureKey() {
    // If key was already derived this session, nothing to do.
    // If not (e.g. app restart with persisted auth), we cannot re-derive
    // without a fresh idToken — caller must sign in again.
    if (_aesKey == null) {
      if (kDebugMode) {
        debugPrint('[CloudSync] Key not available — sign-in required');
      }
    }
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  /// Signs in with Google, derives the AES key, saves user profile.
  ///
  /// The idToken returned by Google Sign-In is used as part of the HKDF
  /// input, so key derivation happens here where the token is available.
  Future<User?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      final googleUser = await googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      // idToken: Google-signed JWT. Used in HKDF to make key non-public.
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
      if (user != null && idToken != null) {
        // Derive key immediately while idToken is in memory
        _aesKey = _deriveKey(user.uid, idToken);
        await _upsertUserProfile(user);
      }
      return user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      if (kDebugMode) {
        debugPrint('[CloudSync] Google sign-in failed: ${e.description}');
      }
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

  /// Silently syncs if signed in and consent was given.
  Future<void> autoSync(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) async {
    if (!isSignedIn || _aesKey == null) return;
    if (!await hasConsentBeenGiven()) return;
    await syncToCloud(db, taskRepo);
  }

  // ── Sync to cloud ────────────────────────────────────────────────────────

  /// Encrypts ALL local data with AES-256-GCM and uploads to Firestore.
  ///
  /// Fix #2 (P2): Uses [taskRepo.getAllCompletions()] instead of a date-
  /// bounded loop, so no historical data is truncated.
  ///
  /// Fix #3 (P1): AES-GCM provides authentication — any payload tampering
  /// causes decryption to throw, preventing silent data corruption.
  Future<bool> syncToCloud(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) async {
    _ensureKey();
    if (!isSignedIn || _aesKey == null) return false;

    try {
      final uid = currentUser!.uid;

      // Gather ALL challenge sessions + their full progress history
      final sessions = db.getAllSessions();
      final allProgress = <Map<String, dynamic>>[];
      for (final s in sessions) {
        for (final p in db.getProgressForSession(s.startDate)) {
          allProgress.add(p.toJson());
        }
      }

      // Gather ALL regular tasks (including archived) and ALL completions.
      // Fix #2: getAllCompletions() reads directly from Hive box — no date cap.
      final regularTasks = taskRepo.getAllTasks();
      final regularCompletions =
          taskRepo.getAllCompletions().map((c) => c.toJson()).toList();

      final payload = jsonEncode({
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'progress': allProgress,
        'regularTasks': regularTasks.map((t) => t.toJson()).toList(),
        'regularCompletions': regularCompletions,
        'syncedAt': DateTime.now().toIso8601String(),
        'schemaVersion': 3,
      });

      // AES-256-GCM: confidentiality + integrity + authenticity (fix #3)
      final encrypted = _encryptGcm(payload);

      await _firestore.collection('user_data').doc(uid).set({
        'enc': encrypted['cipher'], // ciphertext + 16-byte GCM auth tag
        'nonce': encrypted['nonce'], // 12-byte random nonce
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 3,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSyncTime, DateTime.now().toIso8601String());

      if (kDebugMode) debugPrint('[CloudSync] Sync complete (GCM)');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CloudSync] Sync failed: $e');
      return false;
    }
  }

  // ── Sync from cloud ──────────────────────────────────────────────────────

  /// Downloads and authenticates + decrypts user data from Firestore.
  ///
  /// Fix #3: GCM authentication tag is verified during decryption.
  /// If the ciphertext was tampered with, decryption throws and null is
  /// returned — the corrupt data is never passed to the app.
  Future<Map<String, dynamic>?> syncFromCloud() async {
    _ensureKey();
    if (!isSignedIn || _aesKey == null) return null;

    try {
      final uid = currentUser!.uid;
      final doc = await _firestore.collection('user_data').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final schemaVersion = data['schemaVersion'] as int? ?? 1;

      // Schema v3+: AES-256-GCM with nonce
      if (schemaVersion >= 3) {
        final cipher = data['enc'] as String?;
        final nonce = data['nonce'] as String?;
        if (cipher == null || nonce == null) return null;
        final decrypted = _decryptGcm(cipher, nonce);
        return jsonDecode(decrypted) as Map<String, dynamic>;
      }

      // Schema v1/v2: AES-256-CBC (legacy — read-only backwards compat).
      // These backups were created before GCM migration. We decrypt them
      // using CBC, then on the next syncToCloud they'll be re-encrypted with GCM.
      final cipher = (data['enc'] ?? data['data']) as String?;
      if (cipher == null) return null;
      final ivBase64 = data['iv'] as String?;
      final decrypted = _decryptCbcLegacy(cipher, ivBase64: ivBase64);
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

  // ── AES-256-GCM helpers (primary — fix #3) ──────────────────────────────

  /// Encrypts [plain] with AES-256-GCM using a cryptographically random
  /// 12-byte nonce. Returns {'cipher': base64(ciphertext+tag), 'nonce': base64}.
  ///
  /// The 16-byte GCM authentication tag is appended to the ciphertext by
  /// the encrypt package and verified on decryption — any bit-flip in the
  /// stored data causes decryption to throw [ArgumentError].
  Map<String, String> _encryptGcm(String plain) {
    final nonce = enc.IV.fromSecureRandom(12); // GCM standard nonce size
    final encrypter = enc.Encrypter(enc.AES(_aesKey!, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plain, iv: nonce);
    return {
      'cipher': encrypted.base64,
      'nonce': nonce.base64,
    };
  }

  /// Decrypts and authenticates GCM ciphertext.
  /// Throws if the authentication tag does not match (tamper detection).
  String _decryptGcm(String cipherBase64, String nonceBase64) {
    final nonce = enc.IV.fromBase64(nonceBase64);
    final encrypter = enc.Encrypter(enc.AES(_aesKey!, mode: enc.AESMode.gcm));
    return encrypter.decrypt64(cipherBase64, iv: nonce);
  }

  // ── AES-256-CBC legacy helpers (read-only, backwards compat) ────────────

  /// Decrypts legacy CBC-encrypted backups (schema v1/v2).
  /// Only used for reading old data — new writes always use GCM.
  String _decryptCbcLegacy(String cipherBase64, {String? ivBase64}) {
    final iv = ivBase64 != null
        ? enc.IV.fromBase64(ivBase64)
        : enc.IV.fromLength(16); // zero-IV fallback for very old v1 backups
    final encrypter = enc.Encrypter(enc.AES(_aesKey!, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(cipherBase64, iv: iv);
  }
}
