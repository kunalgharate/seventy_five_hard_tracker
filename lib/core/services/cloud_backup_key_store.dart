import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The storage operations used by [CloudBackupKeyStore].
///
/// Keeping this small interface separate from the plugin makes the key
/// lifecycle testable without a platform Keychain or Keystore.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Production adapter for the platform secure storage implementation.
///
/// `flutter_secure_storage` stores values in the iOS Keychain and Android
/// Keystore-backed storage. No key material is kept in SharedPreferences or
/// the Hive database.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

typedef SecureRandomBytes = List<int> Function(int length);

/// Owns one random 256-bit encryption key per signed-in account.
///
/// The account is part of the storage namespace, so signing into another
/// Firebase account never reuses the first account's key. Existing keys are
/// read before a new key is generated. Newly generated keys are read back
/// after writing; a storage implementation that cannot persist the key is
/// treated as unavailable instead of silently falling back to a weaker key.
class CloudBackupKeyStore {
  static const int keyLengthBytes = 32;
  static const String keyNamespace = 'cloud_backup_key_v1';

  CloudBackupKeyStore({
    SecureKeyValueStore? storage,
    SecureRandomBytes? randomBytes,
  })  : _storage = storage ?? FlutterSecureKeyValueStore(),
        _randomBytes = randomBytes ?? _secureRandomBytes;

  final SecureKeyValueStore _storage;
  final SecureRandomBytes _randomBytes;
  final Map<String, Future<Uint8List>> _inFlight = {};
  final Map<String, Completer<void>> _deleting = {};

  /// Returns the platform-storage key for an account without exposing the
  /// account's key material. Firebase UIDs are opaque strings and are safe to
  /// use as a namespace component here.
  static String storageKeyForAccount(String uid) {
    final accountId = uid.trim();
    if (accountId.isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'must not be empty');
    }
    return '$keyNamespace:$accountId';
  }

  /// Reads the existing account key, returning null only when no key exists.
  /// A malformed stored value throws so it cannot be replaced silently.
  Future<Uint8List?> readKey(String uid) async {
    final storageKey = storageKeyForAccount(uid);
    final encoded = await _storage.read(storageKey);
    return _decodeKey(encoded, storageKey: storageKey);
  }

  /// Reads or creates the account's random 256-bit key.
  Future<Uint8List> getOrCreateKey(String uid) {
    final storageKey = storageKeyForAccount(uid);
    final existing = _inFlight[storageKey];
    if (existing != null) return existing;

    // If a deletion is in progress for this key, wait for it to complete
    // and then re-check if the key was recreated.
    final deleting = _deleting[storageKey];
    if (deleting != null) {
      return deleting.future.then((_) {
        // After deletion completes, check if a new key was created
        final newInFlight = _inFlight[storageKey];
        if (newInFlight != null) return newInFlight;
        // No new key created, proceed with normal getOrCreateKey logic
        return getOrCreateKey(uid);
      });
    }

    late final Future<Uint8List> pending;
    pending = _getOrCreateKey(storageKey).whenComplete(() {
      if (identical(_inFlight[storageKey], pending)) {
        _inFlight.remove(storageKey);
      }
    });
    _inFlight[storageKey] = pending;
    return pending;
  }

  /// Deletes only the requested account's key. Sign-out does not call this;
  /// retaining the key allows that same account to restore its backups after a
  /// later sign-in while still isolating it from other accounts.
  ///
  /// This method serializes with in-flight `getOrCreateKey` operations:
  /// it waits for any pending create to complete, then deletes the key,
  /// and blocks new `getOrCreateKey` calls until deletion is done.
  Future<void> deleteKey(String uid) async {
    final storageKey = storageKeyForAccount(uid);

    // Wait for any in-flight getOrCreateKey to complete
    final inFlight = _inFlight[storageKey];
    if (inFlight != null) {
      await inFlight;
    }

    // Mark deletion as in progress to block new getOrCreateKey calls
    final completer = Completer<void>();
    _deleting[storageKey] = completer;

    try {
      await _storage.delete(storageKey);
    } finally {
      _deleting.remove(storageKey);
      completer.complete();
    }
  }

  Future<Uint8List> _getOrCreateKey(String storageKey) async {
    final existing = _decodeKey(
      await _storage.read(storageKey),
      storageKey: storageKey,
    );
    if (existing != null) return existing;

    final generated = _randomBytes(keyLengthBytes);
    if (generated.length != keyLengthBytes ||
        generated.any((byte) => byte < 0 || byte > 255)) {
      throw StateError(
        'Secure random source must return exactly $keyLengthBytes bytes.',
      );
    }

    final encoded = base64UrlEncode(generated);
    await _storage.write(storageKey, encoded);

    // Read-back detects platform storage failures and ensures the value used
    // by the caller is exactly the value that was persisted.
    final persisted = _decodeKey(
      await _storage.read(storageKey),
      storageKey: storageKey,
    );
    if (persisted == null) {
      throw StateError('Secure storage did not persist the cloud backup key.');
    }
    return persisted;
  }

  static Uint8List _secureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List? _decodeKey(String? encoded, {required String storageKey}) {
    if (encoded == null) return null;

    try {
      final decoded = Uint8List.fromList(base64Url.decode(encoded));
      if (decoded.length != keyLengthBytes) {
        throw const FormatException('wrong key length');
      }
      return decoded;
    } on FormatException catch (error) {
      throw FormatException(
        'Stored cloud backup key for "$storageKey" is invalid: $error',
      );
    } on Object catch (error) {
      throw FormatException(
        'Stored cloud backup key for "$storageKey" is not valid base64: '
        '$error',
      );
    }
  }
}
