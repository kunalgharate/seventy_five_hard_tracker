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
import 'package:seventy_five_hard_tracker/core/services/cloud_backup_key_store.dart';
import 'package:seventy_five_hard_tracker/core/services/data_ownership.dart';
import 'package:seventy_five_hard_tracker/core/services/fcm_service.dart';

/// Keys for SharedPreferences
const _kLastSyncTime = 'lastSyncTime';
const _kConsentGiven = 'cloudSyncConsentGiven';

/// The decision returned before a destructive sign-out cleanup is allowed.
///
/// A failed backup must leave the account signed in and all local data intact.
enum SignOutPreparationStatus {
  readyToSignOut,
  backupFailed,
  localCleanupFailed,
}

extension SignOutPreparationStatusX on SignOutPreparationStatus {
  bool get maySignOut => this == SignOutPreparationStatus.readyToSignOut;

  bool get keepsLocalData => this != SignOutPreparationStatus.readyToSignOut;
}

/// AES-256-GCM authenticated-encryption cloud sync service.
///
/// Security properties:
///   • AES-256-GCM (AEAD) — confidentiality + integrity + authenticity.
///     Tampered ciphertext is rejected at decryption time whenever the
///     attacker does not know the account key.
///   • New backups use a random 256-bit key held in platform secure storage.
///   • Old UID-derived backups are read-only migration fallback and are never
///     used for new writes.
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
  CloudSyncService._internal()
      : _auth = FirebaseAuth.instance,
        _firestore = FirebaseFirestore.instance,
        _keyStore = CloudBackupKeyStore();

  @visibleForTesting
  CloudSyncService.forTesting({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    CloudBackupKeyStore? keyStore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _keyStore = keyStore ?? CloudBackupKeyStore();

  static const int _currentBackupSchemaVersion = 4;
  static const String _secureStorageKeySource = 'secure-storage-v1';
  static const String _legacyUidKeySource = 'uid-derived-v3';
  static const String _legacyBackupField = 'legacyBackup';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final CloudBackupKeyStore _keyStore;

  /// Random account key loaded from platform secure storage.
  enc.Key? _userHeldKey;
  String? _userHeldKeyUid;
  Future<enc.Key?>? _keyLoadInFlight;
  Future<bool>? _autoSyncInFlight;
  Future<bool>? _syncToCloudInFlight;

  bool _lastRestoreUsedLegacyKey = false;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// True when the last successful restore used the UID-derived migration
  /// fallback. The next successful sync can migrate it to the user-held key.
  @visibleForTesting
  bool get lastRestoreUsedLegacyKey => _lastRestoreUsedLegacyKey;

  // ── Key derivation and secure key loading ────────────────────────────────

  /// Derives the key used by the pre-secure-storage backup format.
  ///
  /// This is intentionally retained only so backups written by older app
  /// versions remain restorable. It must not be used by new writes.
  enc.Key _deriveLegacyKey(String uid) {
    final ikm = utf8.encode(uid);
    final salt = utf8.encode('dailymettle-v3-stable-key');
    final info = utf8.encode('aes256-gcm-user-data-v3');

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

  Future<enc.Key?> _loadUserHeldKey() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Future<enc.Key?>.value(null);

    if (_userHeldKeyUid != uid) {
      _userHeldKey = null;
      _userHeldKeyUid = uid;
      _keyLoadInFlight = null;
    }
    if (_userHeldKey != null) return Future.value(_userHeldKey);

    final activeLoad = _keyLoadInFlight;
    if (activeLoad != null) return activeLoad;

    late final Future<enc.Key?> pending;
    pending = _readUserHeldKey(uid).whenComplete(() {
      if (identical(_keyLoadInFlight, pending)) _keyLoadInFlight = null;
    });
    _keyLoadInFlight = pending;
    return pending;
  }

  Future<enc.Key?> _readUserHeldKey(String uid) async {
    try {
      final bytes = await _keyStore.getOrCreateKey(uid);
      final key = enc.Key(bytes);
      if (_auth.currentUser?.uid == uid) {
        _userHeldKey = key;
        _userHeldKeyUid = uid;
      }
      return key;
    } catch (error) {
      // A secure-storage failure must not cause a new backup to fall back to
      // UID-derived encryption. The legacy key remains available only to
      // decrypt an already-existing legacy backup.
      if (kDebugMode) {
        debugPrint('[CloudSync] Secure backup key unavailable: $error');
      }
      return null;
    }
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  /// Signs in with Google, loads/creates the account's platform-held key, and
  /// saves the user profile.
  ///
  /// If secure storage is temporarily unavailable, authentication still
  /// succeeds so the caller can use the rest of the app. Cloud backup writes
  /// fail closed until the key can be loaded; old UID-derived backups can
  /// still be attempted through the read-only migration path.
  Future<User?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      final googleUser = await googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      // idToken: Google-signed JWT used to build the Firebase credential.
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
        _userHeldKey = null;
        _userHeldKeyUid = user.uid;
        _keyLoadInFlight = null;
        await _loadUserHeldKey();
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
    // Cross-account isolation: drop this device's push token from the
    // outgoing account BEFORE auth is revoked — security rules only let the
    // owner update their `users` doc, so this would fail after sign-out.
    try {
      await FcmService.instance.unregisterCurrentDeviceToken();
    } catch (_) {}
    try {
      // Also drop the Google account so the next sign-in cannot silently
      // re-authenticate as the previous user.
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    // Drop the device-local Firestore disk cache so this account's offline
    // data can't be read by the next account signed in on this device.
    try {
      await _firestore.clearPersistence();
    } catch (_) {}
    await _auth.signOut();
    _userHeldKey = null;
    _userHeldKeyUid = null;
    _keyLoadInFlight = null;
    _lastRestoreUsedLegacyKey = false;
  }

  /// Removes all device-local user data and ownership markers. Used on
  /// sign-out and account switches so one account's data is never visible,
  /// uploaded, or published under another account.
  Future<void> clearLocalData(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) async {
    await db.clearAllData();
    await taskRepo.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastSyncTime);
    await DataOwnership.clear();
  }

  /// Backs up local data and performs the local cleanup needed before auth
  /// sign-out. The caller must only continue with auth sign-out when the
  /// returned status [maySignOut] is true.
  ///
  /// This is deliberately a separate decision path: a failed backup returns
  /// before [clearLocalData], so local data remains available for retry.
  Future<SignOutPreparationStatus> prepareForSignOut(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) async {
    final backedUp = await syncToCloud(db, taskRepo);
    final backupStatus = signOutStatusForBackup(backedUp);
    if (!backupStatus.maySignOut) return backupStatus;

    try {
      await clearLocalData(db, taskRepo);
      return SignOutPreparationStatus.readyToSignOut;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudSync] Local sign-out cleanup failed: $e');
      }
      return SignOutPreparationStatus.localCleanupFailed;
    }
  }

  /// Pure decision function for the safety boundary before local deletion.
  static SignOutPreparationStatus signOutStatusForBackup(bool backedUp) =>
      backedUp
          ? SignOutPreparationStatus.readyToSignOut
          : SignOutPreparationStatus.backupFailed;

  /// Reconciles device-local data with the signed-in account after a
  /// sign-in: another account's data is wiped (never uploaded) and this
  /// account's cloud backup restored if needed; matching data is uploaded.
  Future<({bool restored, bool uploaded})> reconcileOnSignIn(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) async {
    final uid = currentUser?.uid;
    if (uid == null) return (restored: false, uploaded: false);

    if (await DataOwnership.ownedByOther(uid)) {
      await clearLocalData(db, taskRepo);
    }

    final hasLocal =
        db.getAllSessions().isNotEmpty || taskRepo.getAllTasks().isNotEmpty;
    if (hasLocal) {
      final uploaded = await syncToCloud(db, taskRepo);
      return (restored: false, uploaded: uploaded);
    }

    final cloudData = await syncFromCloud();
    if (cloudData != null && hasRestorablePayload(cloudData)) {
      await db.restoreFromJson(cloudData);
      await taskRepo.restoreFromJson(cloudData);
      await DataOwnership.claim(uid);

      // A legacy restore is immediately re-encrypted with the user-held key.
      // syncToCloud archives the UID-derived envelope before replacing the
      // active fields, and a failed migration leaves the old backup intact.
      final migrated =
          _lastRestoreUsedLegacyKey ? await syncToCloud(db, taskRepo) : false;
      return (restored: true, uploaded: migrated);
    }

    await DataOwnership.claim(uid);
    return (restored: false, uploaded: false);
  }

  /// Returns true when a decrypted backup contains at least one supported
  /// collection. Presence of a collection key matters: an intentionally empty
  /// array is a valid replacement and must still be restored.
  static bool hasRestorablePayload(Map<String, dynamic> data) {
    const collectionKeys = [
      'sessions',
      'progress',
      'regularTasks',
      'regularCompletions',
    ];
    return collectionKeys.any(data.containsKey);
  }

  // ── User profile ─────────────────────────────────────────────────────────

  Future<void> _upsertUserProfile(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    // Write both the legacy keys (`id`, `name`) and the ones the partner
    // lookup reads (`uid`, `displayName`). Writing only `id`/`name` made
    // AppUser.fromFirestore produce uid: '' / displayName: '', which then
    // got stored on partnership docs as partnerUid: '' — and security rules
    // treat '' as "claimed by someone else", so the invitee was denied.
    final data = <String, dynamic>{
      'uid': user.uid,
      'id': user.uid,
      'name': user.displayName ?? '',
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
    if (!snap.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
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
  ///
  /// Called on connectivity restore and app-resume. The secure key is loaded
  /// inside [syncToCloud], so a restored session (no in-memory key yet) still
  /// syncs on reconnect.
  Future<void> autoSync(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) async {
    if (!await autoSyncWithResult(db, taskRepo)) {
      throw StateError('Automatic cloud sync did not complete successfully.');
    }
  }

  /// Runs auto-sync once when concurrent resume/reconnect requests overlap.
  ///
  /// A signed-out user or a user without cloud-sync consent has no sync work
  /// to perform and is considered successful. Upload failures are reported.
  Future<bool> autoSyncWithResult(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) {
    final activeSync = _autoSyncInFlight;
    if (activeSync != null) return activeSync;

    late final Future<bool> sync;
    sync = _runAutoSync(db, taskRepo).whenComplete(() {
      if (identical(_autoSyncInFlight, sync)) _autoSyncInFlight = null;
    });
    _autoSyncInFlight = sync;
    return sync;
  }

  Future<bool> _runAutoSync(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) async {
    if (!isSignedIn) return true;
    if (!await hasConsentBeenGiven()) return true;
    return syncToCloud(db, taskRepo);
  }

  // ── Sync to cloud ────────────────────────────────────────────────────────

  /// Encrypts ALL local data with AES-256-GCM and uploads to Firestore.
  ///
  /// Uses [taskRepo.getAllCompletions()] instead of a date-bounded loop,
  /// so no historical data is truncated.
  ///
  /// New writes require the random account key from platform secure storage.
  /// If that key is unavailable, this method returns false and leaves any old
  /// cloud backup untouched; it never silently writes a weaker UID-derived
  /// replacement.
  Future<bool> syncToCloud(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) {
    final activeSync = _syncToCloudInFlight;
    if (activeSync != null) return activeSync;

    late final Future<bool> sync;
    sync = _syncToCloud(db, taskRepo).whenComplete(() {
      if (identical(_syncToCloudInFlight, sync)) _syncToCloudInFlight = null;
    });
    _syncToCloudInFlight = sync;
    return sync;
  }

  Future<bool> _syncToCloud(
    DatabaseRepository db,
    RegularTaskRepository taskRepo,
  ) async {
    final user = currentUser;
    if (user == null) return false;

    final userHeldKey = await _loadUserHeldKey();
    if (userHeldKey == null || _auth.currentUser?.uid != user.uid) return false;

    try {
      final uid = user.uid;

      // Never upload local data that belongs to a different account.
      if (await DataOwnership.ownedByOther(uid)) return false;

      // Gather ALL challenge sessions + their full progress history
      final sessions = db.getAllSessions();
      final allProgress = <Map<String, dynamic>>[];
      for (final s in sessions) {
        for (final p in db.getProgressForSession(
          s.startDate,
          sessionId: s.id,
          totalDaysTarget: s.totalDaysTarget,
        )) {
          allProgress.add(p.toJson());
        }
      }

      // Gather ALL regular tasks (including archived) and ALL completions.
      // getAllCompletions() reads directly from the Hive box — no date cap.
      final regularTasks = taskRepo.getAllTasks();
      final regularCompletions =
          taskRepo.getAllCompletions().map((c) => c.toJson()).toList();

      final payload = jsonEncode({
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'progress': allProgress,
        'regularTasks': regularTasks.map((t) => t.toJson()).toList(),
        'regularCompletions': regularCompletions,
        'syncedAt': DateTime.now().toIso8601String(),
        'schemaVersion': _currentBackupSchemaVersion,
      });

      // AES-256-GCM: confidentiality + integrity + authenticity
      final encrypted = _encryptGcm(payload, userHeldKey);

      final ref = _firestore.collection('user_data').doc(uid);
      final existing = await ref.get();
      final writeData = <String, dynamic>{};
      if (existing.exists && existing.data() != null) {
        // Preserve unknown fields and archive the old UID-derived envelope
        // before replacing its active fields. This makes migration explicit
        // and avoids silently destroying the only copy of a legacy backup.
        writeData.addAll(existing.data()!);
        final oldData = existing.data()!;
        if (_isLegacyBackup(oldData)) {
          writeData[_legacyBackupField] = _legacyEnvelope(oldData);
        }
      }
      writeData.addAll({
        'enc': encrypted['cipher'], // ciphertext + 16-byte GCM auth tag
        'nonce': encrypted['nonce'], // 12-byte random nonce
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': _currentBackupSchemaVersion,
        'encryptionKeySource': _secureStorageKeySource,
      });
      await ref.set(writeData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSyncTime, DateTime.now().toIso8601String());
      await DataOwnership.claim(uid);

      if (kDebugMode) {
        debugPrint('[CloudSync] Sync complete (GCM, secure account key)');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CloudSync] Sync failed: $e');
      return false;
    }
  }

  // ── Sync from cloud ──────────────────────────────────────────────────────

  /// Downloads and authenticates + decrypts user data from Firestore.
  ///
  /// The GCM authentication tag is verified during decryption. If the
  /// ciphertext was tampered with by someone who does not know the account
  /// key, decryption throws and null is returned — the corrupt data is never
  /// passed to the app.
  ///
  /// Current backups use the random account key. Schema v1-v3 backups use the
  /// old UID-derived key only as a read-only migration fallback. A failed
  /// secure-key restore does not downgrade a current backup to the UID key.
  Future<Map<String, dynamic>?> syncFromCloud() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final uid = user.uid;
      final doc = await _firestore.collection('user_data').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      _lastRestoreUsedLegacyKey = false;

      final secureKey = await _loadUserHeldKey();
      if (_auth.currentUser?.uid != uid) return null;
      if (_isCurrentSecureBackup(data)) {
        final restored = _tryDecryptEnvelope(
          data,
          key: secureKey,
        );
        if (restored != null) return restored;

        // A prior migration archives the old envelope alongside the current
        // one. It remains readable if the new key is lost or the current
        // ciphertext is damaged, without trying the UID key on current data.
        final archived = _legacyMap(data[_legacyBackupField]);
        if (archived != null) {
          final legacy = _tryDecryptLegacyEnvelope(archived, uid);
          if (legacy != null) {
            _lastRestoreUsedLegacyKey = true;
            return legacy;
          }
        }
        return null;
      }

      final legacy = _tryDecryptLegacyEnvelope(data, uid);
      if (legacy != null) _lastRestoreUsedLegacyKey = true;
      return legacy;
    } catch (e) {
      if (kDebugMode) debugPrint('[CloudSync] Restore failed: $e');
      return null;
    }
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastSyncTime);
  }

  static bool _isCurrentSecureBackup(Map<String, dynamic> data) {
    final schemaVersion = _schemaVersion(data);
    return schemaVersion >= _currentBackupSchemaVersion ||
        data['encryptionKeySource'] == _secureStorageKeySource;
  }

  static bool _isLegacyBackup(Map<String, dynamic> data) {
    if (_isCurrentSecureBackup(data)) return false;
    final hasCipher = data['enc'] is String || data['data'] is String;
    return hasCipher;
  }

  static int _schemaVersion(Map<String, dynamic> data) {
    final value = data['schemaVersion'];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  static Map<String, dynamic> _legacyEnvelope(Map<String, dynamic> data) {
    final envelope = <String, dynamic>{};
    for (final field in const [
      'enc',
      'data',
      'nonce',
      'iv',
      'schemaVersion',
      'encryptionKeySource',
    ]) {
      if (data.containsKey(field)) envelope[field] = data[field];
    }
    // This marker is informational only. The decryptor still validates the
    // schema and ciphertext shape before attempting the legacy key.
    envelope['encryptionKeySource'] = _legacyUidKeySource;
    return envelope;
  }

  static Map<String, dynamic>? _legacyMap(Object? value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  Map<String, dynamic>? _tryDecryptEnvelope(
    Map<String, dynamic> data, {
    required enc.Key? key,
  }) {
    if (key == null) return null;

    try {
      final cipher = data['enc'] as String?;
      final nonce = data['nonce'] as String?;
      if (cipher == null || nonce == null) return null;
      final decrypted = _decryptGcm(cipher, nonce, key);
      return _decodePayload(decrypted);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CloudSync] Current backup decryption failed: $error');
      }
      return null;
    }
  }

  Map<String, dynamic>? _tryDecryptLegacyEnvelope(
    Map<String, dynamic> data,
    String uid,
  ) {
    final key = _deriveLegacyKey(uid);
    final schemaVersion = _schemaVersion(data);

    try {
      final cipher = (data['enc'] ?? data['data']) as String?;
      if (cipher == null) return null;

      if (schemaVersion >= 3 && data['nonce'] is String) {
        final decrypted = _decryptGcm(cipher, data['nonce'] as String, key);
        return _decodePayload(decrypted);
      }

      final ivBase64 = data['iv'] as String?;
      final decrypted = _decryptCbcLegacy(
        cipher,
        key,
        ivBase64: ivBase64,
      );
      return _decodePayload(decrypted);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CloudSync] Legacy backup decryption failed: $error');
      }
      return null;
    }
  }

  static Map<String, dynamic> _decodePayload(String decrypted) {
    final decoded = jsonDecode(decrypted);
    if (decoded is! Map) {
      throw const FormatException('Cloud backup payload must be an object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  // ── AES-256-GCM helpers ─────────────────────────────────────────────

  /// Encrypts [plain] with AES-256-GCM using a cryptographically random
  /// 12-byte nonce. Returns {'cipher': base64(ciphertext+tag), 'nonce': base64}.
  ///
  /// The 16-byte GCM authentication tag is appended to the ciphertext by
  /// the encrypt package and verified on decryption — any bit-flip by an
  /// attacker who does not know the derived key causes decryption to throw
  /// [ArgumentError].
  Map<String, String> _encryptGcm(String plain, enc.Key key) {
    final nonce = enc.IV.fromSecureRandom(12); // GCM standard nonce size
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plain, iv: nonce);
    return {
      'cipher': encrypted.base64,
      'nonce': nonce.base64,
    };
  }

  /// Decrypts and authenticates GCM ciphertext.
  /// Throws if the authentication tag does not match, rejecting tampering by
  /// anyone who does not know the derived key.
  String _decryptGcm(
    String cipherBase64,
    String nonceBase64,
    enc.Key key,
  ) {
    final nonce = enc.IV.fromBase64(nonceBase64);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return encrypter.decrypt64(cipherBase64, iv: nonce);
  }

  // ── AES-256-CBC legacy helpers (read-only, backwards compat) ────────────

  /// Decrypts legacy CBC-encrypted backups (schema v1/v2).
  /// Only used for reading old data — new writes always use GCM.
  String _decryptCbcLegacy(
    String cipherBase64,
    enc.Key key, {
    String? ivBase64,
  }) {
    // Legacy read-only path for very old v1 backups. Newer backups use
    // AES-256-GCM with a per-record random nonce (see _encryptGcm). Some v1
    // records were written without a stored IV; we fall back to a zero IV to
    // remain able to RESTORE them. This is weak (fixed-IV CBC leaks plaintext
    // prefix equality) but the data was already stored this way — refusing to
    // decrypt would only cause data loss on restore without improving the
    // confidentiality of data already at rest. No new records are ever written
    // on this path.
    final iv =
        ivBase64 != null ? enc.IV.fromBase64(ivBase64) : enc.IV.fromLength(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(cipherBase64, iv: iv);
  }
}
