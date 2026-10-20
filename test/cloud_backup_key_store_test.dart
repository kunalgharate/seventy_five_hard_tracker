import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seventy_five_hard_tracker/core/services/cloud_backup_key_store.dart';

void main() {
  group('CloudBackupKeyStore', () {
    test('generates a random 256-bit key, persists it, and reads it back',
        () async {
      final storage = _MemorySecureStore();
      final generated = List<int>.generate(
        CloudBackupKeyStore.keyLengthBytes,
        (index) => index,
      );
      final store = CloudBackupKeyStore(
        storage: storage,
        randomBytes: (_) => generated,
      );

      final first = await store.getOrCreateKey('account-a');
      final second = await store.getOrCreateKey('account-a');

      expect(first, Uint8List.fromList(generated));
      expect(second, first);
      expect(storage.writeCount, 1);
      expect(
        storage.values[CloudBackupKeyStore.storageKeyForAccount('account-a')],
        isNotNull,
      );
    });

    test('keeps keys isolated by account namespace', () async {
      final storage = _MemorySecureStore();
      var seed = 0;
      final store = CloudBackupKeyStore(
        storage: storage,
        randomBytes: (length) =>
            List<int>.generate(length, (_) => (seed++) % 256),
      );

      final accountA = await store.getOrCreateKey('account-a');
      final accountB = await store.getOrCreateKey('account-b');

      expect(accountA, isNot(accountB));
      expect(
          storage.values.keys,
          containsAll(<String>[
            CloudBackupKeyStore.storageKeyForAccount('account-a'),
            CloudBackupKeyStore.storageKeyForAccount('account-b'),
          ]));
    });

    test('does not replace a malformed stored key silently', () async {
      final storage = _MemorySecureStore()
        ..values[CloudBackupKeyStore.storageKeyForAccount('account-a')] =
            'not-a-256-bit-key';
      final store = CloudBackupKeyStore(
        storage: storage,
        randomBytes: (_) => List<int>.filled(32, 7),
      );

      await expectLater(
        store.getOrCreateKey('account-a'),
        throwsA(isA<FormatException>()),
      );
      expect(storage.writeCount, 0);
    });

    test('readKey reports absence without creating a key', () async {
      final storage = _MemorySecureStore();
      final store = CloudBackupKeyStore(
        storage: storage,
        randomBytes: (_) => List<int>.filled(32, 3),
      );

      expect(await store.readKey('account-a'), isNull);
      expect(storage.writeCount, 0);
    });

    test('rejects an empty account id', () {
      expect(
        () => CloudBackupKeyStore.storageKeyForAccount('  '),
        throwsArgumentError,
      );
    });
  });
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};
  int writeCount = 0;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    values[key] = value;
  }
}
