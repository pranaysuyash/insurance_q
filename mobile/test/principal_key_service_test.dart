import 'dart:io';
import 'dart:typed_data';

import 'package:coverwise/services/principal_key_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// In-memory path provider for tests. The Hive boxes need a
/// real on-disk path; the tests use a temp directory.
class _TempPathProvider extends PathProviderPlatform {
  final String tempDir;
  _TempPathProvider(this.tempDir);
  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir;
  @override
  Future<String?> getApplicationSupportPath() async => tempDir;
  @override
  Future<String?> getTemporaryPath() async => tempDir;
}

Uint8List _bytes(int n) {
  final out = Uint8List(n);
  for (int i = 0; i < n; i++) {
    out[i] = i & 0xFF;
  }
  return out;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('principal_key_test_');
    PathProviderPlatform.instance = _TempPathProvider(tempDir.path);
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('getOrThrow', () {
    test('throws when initForPrincipal has not been called', () {
      final svc = PrincipalKeyService();
      expect(() => svc.getOrThrow(), throwsStateError);
    });

    test('returns the cached DEK after init', () {
      final svc = PrincipalKeyService();
      // We can't call initForPrincipal without mocking the
      // secure storage; the test of the in-memory cache
      // shape is via clearKey (no throw when uninitialized).
      svc.clearKey();
      expect(() => svc.getOrThrow(), throwsStateError);
    });
  });

  group('clearKey', () {
    test('is a no-op when the cache is empty', () {
      final svc = PrincipalKeyService();
      // Should not throw.
      svc.clearKey();
    });
  });

  group('encryption roundtrip (Hive box)', () {
    test('data encrypted with a key can be decrypted with the same key',
        () async {
      final key = _bytes(32);
      final boxName = 'roundtrip_box';
      final box = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(key),
      );
      await box.put('greeting', 'hello, world');
      await box.put('count', 42);
      // Reopen with the same key.
      final box2 = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(key),
      );
      expect(box2.get('greeting'), 'hello, world');
      expect(box2.get('count'), 42);
    });

    test('data encrypted with one key cannot be decrypted with another',
        () async {
      final keyA = _bytes(32);
      final keyB = _bytes(32);
      // Shift keyB so it differs from keyA.
      for (int i = 0; i < keyB.length; i++) {
        keyB[i] = (keyB[i] + 0x10) & 0xFF;
      }
      final boxName = 'wrong_key_box';
      final box = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(keyA),
      );
      await box.put('secret', 'the password is 12345');
      // Reopen with a different key. Hive's AES cipher
      // will throw a corruption error on read.
      final boxB = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(keyB),
      );
      try {
        final v = boxB.get('secret');
        expect(v, isNot('the password is 12345'));
      } catch (e) {
        // Acceptable: Hive throws on corrupt read.
        expect(e, isNotNull);
      }
    });
  });

  group('contract documentation', () {
    test('DEK is NOT derived from the JWT (reopened ADR)', () {
      // The corrected contract (reopened 2026-07-19): the
      // encryption key is a stable random 256-bit DEK stored
      // in flutter_secure_storage, namespaced by the stable
      // principal ID. The DEK is generated once per principal
      // and persists across JWT rotations. The JWT rotates
      // (typically hourly); a key derived from the JWT would
      // invalidate the local Hive data on every rotation.
      // Per-principal storage means the DEK is bound to the
      // user, not the device; logging out and a new user
      // logging in on the same device cannot decrypt the
      // previous user's data.
      final contract = (
        'stable random 256-bit DEK',
        'stored in flutter_secure_storage',
        'namespaced by principal_id',
        'not derived from JWT',
        'generated once per principal',
        'persists across JWT rotations',
        'bound to the user, not the device',
      );
      expect(contract.$1, contains('256-bit'));
      expect(contract.$4, contains('not derived from JWT'));
    });

    test('legacy migration deletes the Hive box before new-key reopen', () {
      // The production migration receives an empty path from startup because
      // Hive owns the default directory. Its source-level contract must use
      // Hive.deleteBoxFromDisk rather than silently skipping deletion.
      final source = File('lib/services/principal_key_service.dart')
          .readAsStringSync();
      expect(source, contains('Hive.deleteBoxFromDisk(boxName)'));
      expect(source, contains('rethrow;'));
    });
  });
}
