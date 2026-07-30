import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/hive_workspace_service.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:coverwise/services/principal_key_service.dart';
import 'package:coverwise/models/identity.dart';

/// In-memory flutter_secure_storage mock that tracks key/value pairs across
/// read/write/delete calls so the migration test can pre-populate the old
/// device key and observe the migration flag and new DEK being written.
Map<String, String> _secureStorage = {};

void _mockSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      switch (call.method) {
        case 'read':
          final key = (call.arguments as Map)['key'] as String;
          return _secureStorage[key];
        case 'write':
          final args = call.arguments as Map;
          _secureStorage[args['key'] as String] = args['value'] as String;
          return null;
        case 'readAll':
          return Map<String, String>.from(_secureStorage);
        case 'delete':
          _secureStorage.remove((call.arguments as Map)['key'] as String);
          return null;
        case 'deleteAll':
          _secureStorage.clear();
          return null;
        case 'containsKey':
          final key = (call.arguments as Map)['key'] as String;
          return _secureStorage.containsKey(key);
        default:
          return null;
      }
    },
  );
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

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _mockSecureStorage();
  });

  setUp(() async {
    _secureStorage = {};
    tempDir = await Directory.systemTemp.createTemp('migration_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    PrincipalKeyService().clearKey();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('migrateBox end-to-end', () {
    test('migrates a box from old device key to new principal DEK', () async {
      const testPrincipalId = 'test-user-1';
      const boxName = 'migration_test_box';
      final oldKey = _bytes(32);
      final oldKeyBase64 = base64Encode(oldKey);

      _secureStorage[PrincipalKeyService.oldDeviceKeyStorageKey] = oldKeyBase64;

      final oldBox = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(oldKey),
      );
      await oldBox.put('string_value', 'hello, world');
      await oldBox.put('int_value', 42);
      await oldBox.put('bool_value', true);
      await oldBox.put('double_value', 3.14);
      await oldBox.close();

      await PrincipalKeyService().initForPrincipal(testPrincipalId);
      final migrated = await PrincipalKeyService().migrateBox(
        boxName: boxName,
        boxPath: '',
      );

      expect(migrated, isTrue);

      final newBox = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(PrincipalKeyService().getOrThrow()),
      );
      expect(newBox.get('string_value'), 'hello, world');
      expect(newBox.get('int_value'), 42);
      expect(newBox.get('bool_value'), isTrue);
      expect(newBox.get('double_value'), 3.14);

      final migrationDone =
          await PrincipalKeyService().hasMigrationRun(boxName);
      expect(migrationDone, isTrue);

      await newBox.close();
    });

    test('second migrateBox call is a no-op (idempotent)', () async {
      const testPrincipalId = 'test-user-2';
      const boxName = 'idempotent_box';
      final oldKey = _bytes(32);
      final oldKeyBase64 = base64Encode(oldKey);

      _secureStorage[PrincipalKeyService.oldDeviceKeyStorageKey] = oldKeyBase64;

      final oldBox = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(oldKey),
      );
      await oldBox.put('data', 'persistent value');
      await oldBox.close();

      await PrincipalKeyService().initForPrincipal(testPrincipalId);
      await PrincipalKeyService().migrateBox(boxName: boxName, boxPath: '');

      final result = await PrincipalKeyService().migrateBox(
        boxName: boxName,
        boxPath: '',
      );

      expect(result, isFalse);

      final newBox = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(PrincipalKeyService().getOrThrow()),
      );
      expect(newBox.get('data'), 'persistent value');
      await newBox.close();
    });

    test('fresh install skips migration (no legacy key)', () async {
      const testPrincipalId = 'test-user-3';
      const boxName = 'fresh_install_box';

      final oldBox = await Hive.openBox(boxName);
      await oldBox.put('data', 'fresh value');
      await oldBox.close();

      await PrincipalKeyService().initForPrincipal(testPrincipalId);

      final result = await PrincipalKeyService().migrateBox(
        boxName: boxName,
        boxPath: '',
      );

      expect(result, isFalse);

      final migrationDone =
          await PrincipalKeyService().hasMigrationRun(boxName);
      expect(migrationDone, isTrue);
    });

    test('migrates complex entry types (map, list, empty, large string)',
        () async {
      const testPrincipalId = 'test-user-4';
      const boxName = 'type_preservation_box';
      final oldKey = _bytes(32);
      final oldKeyBase64 = base64Encode(oldKey);

      _secureStorage[PrincipalKeyService.oldDeviceKeyStorageKey] = oldKeyBase64;

      final oldBox = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(oldKey),
      );
      await oldBox.put('empty_string', '');
      await oldBox.put('large_string', 'x' * 10000);
      await oldBox.put('negative_int', -1);
      await oldBox.put('zero', 0);
      final nestedMap = {'key': 'value', 'number': 99};
      await oldBox.put('map', nestedMap);
      await oldBox.put('list', [1, 2, 3]);
      await oldBox.close();

      await PrincipalKeyService().initForPrincipal(testPrincipalId);

      final result = await PrincipalKeyService().migrateBox(
        boxName: boxName,
        boxPath: '',
      );

      expect(result, isTrue);

      final newBox = await Hive.openBox(
        boxName,
        encryptionCipher: HiveAesCipher(PrincipalKeyService().getOrThrow()),
      );
      expect(newBox.get('empty_string'), '');
      expect(newBox.get('large_string'), 'x' * 10000);
      expect(newBox.get('negative_int'), -1);
      expect(newBox.get('zero'), 0);
      expect(newBox.get('map'), nestedMap);
      expect(newBox.get('list'), [1, 2, 3]);

      await newBox.close();
    });

    test('throws StateError when initForPrincipal has not been called', () {
      expect(
        () => PrincipalKeyService().migrateBox(
          boxName: 'uninitialized',
          boxPath: '',
        ),
        throwsStateError,
      );
    });

    test('hasMigrationRun returns false for unknown principal', () async {
      expect(await PrincipalKeyService().hasMigrationRun('any_box'), isFalse);
    });

    test('hasLegacyDeviceKey returns true when old key is present', () async {
      _secureStorage[PrincipalKeyService.oldDeviceKeyStorageKey] =
          base64Encode(_bytes(32));
      expect(await PrincipalKeyService().hasLegacyDeviceKey(), isTrue);
    });

    test('hasLegacyDeviceKey returns false when no old key is present',
        () async {
      expect(await PrincipalKeyService().hasLegacyDeviceKey(), isFalse);
    });
  });

  group('claim flow (anonymous → account)', () {
    Future<void> openAllBoxes(Uint8List dek) async {
      final cipher = HiveAesCipher(dek);
      // Must match openForActivePrincipal() type signatures exactly.
      await Hive.openBox<String>(LocalStorageService.documentsBoxName,
          encryptionCipher: cipher);
      await Hive.openBox(AppStateStore.boxName, encryptionCipher: cipher);
      await Hive.openBox<String>('resolved_gaps', encryptionCipher: cipher);
      await Hive.openBox<String>('analytics_events', encryptionCipher: cipher);
      await Hive.openBox('consent_ledger', encryptionCipher: cipher);
      await Hive.openBox<String>('qa_history', encryptionCipher: cipher);
      await Hive.openBox<String>('field_overrides_box',
          encryptionCipher: cipher);
      await Hive.openBox<String>('entitlements', encryptionCipher: cipher);
    }

    test('preserves claim-preserved boxes and resets non-preserved', () async {
      const anonId = 'anon-claim-test';
      const realId = 'user-claim-test';

      // --- arrange: anonymous workspace ---
      await PrincipalKeyService().initForPrincipal(anonId);
      await openAllBoxes(PrincipalKeyService().getOrThrow());

      // Open alignment: openForActivePrincipal opens docs/gaps/ledger/qa/fields/entitlements as
      // Box<String> and app_state_box as Box<dynamic>. Test accesses must match exactly because
      // Hive reifies generics (Box<String> is! Box<dynamic> at runtime).
      await Hive.box<String>(LocalStorageService.documentsBoxName)
          .put('doc_1', '{"id":"1","status":"active"}');
      await Hive.box<String>(LocalStorageService.documentsBoxName)
          .put('doc_2', '{"id":"2","status":"pending"}');
      Hive.box(AppStateStore.boxName).put('theme', 'dark');
      await Hive.box('consent_ledger').put('marketing', 'v2');
      await Hive.box<String>('resolved_gaps').put('gap_a', 'fixed');

      await Hive.box<String>('entitlements').put('premium', 'true');
      await Hive.box<String>('analytics_events').put('session_1', 'install');

      // --- act: claim ---
      await HiveWorkspaceService.resetForPrincipal(
        AccountPrincipal(realId),
        preserveCurrentWorkspace: true,
      );

      // --- assert ---
      expect(
        Hive.box<String>(LocalStorageService.documentsBoxName).get('doc_1'),
        '{"id":"1","status":"active"}',
      );
      expect(
        Hive.box<String>(LocalStorageService.documentsBoxName).get('doc_2'),
        '{"id":"2","status":"pending"}',
      );
      expect(Hive.box(AppStateStore.boxName).get('theme'), 'dark');
      expect(Hive.box('consent_ledger').get('marketing'), 'v2');
      expect(Hive.box<String>('resolved_gaps').get('gap_a'), 'fixed');

      expect(Hive.box<String>('entitlements').get('premium'), isNull);
      expect(
          Hive.box<String>('analytics_events').get('session_1'), isNull);

      expect(PrincipalKeyService().principalId, realId);
    });

    test('claim without preserve empties all boxes', () async {
      const anonId = 'anon-no-preserve';
      const realId = 'user-no-preserve';

      await PrincipalKeyService().initForPrincipal(anonId);
      await openAllBoxes(PrincipalKeyService().getOrThrow());

      await Hive.box<String>(LocalStorageService.documentsBoxName).put(
        'doc_1',
        '{"id":"1"}',
      );
      await Hive.box('consent_ledger').put('marketing', 'v2');

      await HiveWorkspaceService.resetForPrincipal(
        AccountPrincipal(realId),
        preserveCurrentWorkspace: false,
      );

      expect(
        Hive.box<String>(LocalStorageService.documentsBoxName).get('doc_1'),
        isNull,
      );
      expect(Hive.box('consent_ledger').get('marketing'), isNull);
      expect(PrincipalKeyService().principalId, realId);
    });

    test('session keys are not preserved during claim', () async {
      const anonId = 'anon-session-clean';
      const realId = 'user-session-clean';

      await PrincipalKeyService().initForPrincipal(anonId);
      await openAllBoxes(PrincipalKeyService().getOrThrow());

      // Set up an existing session.
      final box = Hive.box(AppStateStore.boxName);
      await box.put(AppStateStore.sessionIdKey, 'old-session-id');
      await box.put(AppStateStore.sessionCreatedKey, 1000);
      await box.put('some_setting', 'should-survive');

      await HiveWorkspaceService.resetForPrincipal(
        AccountPrincipal(realId),
        preserveCurrentWorkspace: true,
      );

      expect(
        Hive.box(AppStateStore.boxName).get(AppStateStore.sessionIdKey),
        isNull,
      );
      expect(
        Hive.box(AppStateStore.boxName).get(AppStateStore.sessionCreatedKey),
        isNull,
      );
      expect(
        Hive.box(AppStateStore.boxName).get('some_setting'),
        'should-survive',
      );
    });
  });

  group('DEK lifecycle (P0.7)', () {
    test('corrupt base64 key throws StateError', () async {
      const testPrincipalId = 'corrupt-dek-user';
      final storageKey = '${testPrincipalId}_coverwise_dek_v1';
      // Store invalid base64 in secure storage to simulate corruption.
      _secureStorage[storageKey] = '!!!not-valid-base64!!!';

      await expectLater(
        () async {
          await PrincipalKeyService().initForPrincipal(testPrincipalId);
        },
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Corrupt encryption key'),
          ),
        ),
      );
    });

    test('length-mismatched key throws StateError', () async {
      const testPrincipalId = 'short-dek-user';
      final storageKey = '${testPrincipalId}_coverwise_dek_v1';
      // Store a valid base64 string that decodes to 16 bytes instead of 32.
      _secureStorage[storageKey] = base64Encode(Uint8List.fromList(List.filled(16, 0xAB)));

      await expectLater(
        () async {
          await PrincipalKeyService().initForPrincipal(testPrincipalId);
        },
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('unexpected length'),
          ),
        ),
      );
    });

    test('valid key returns normally', () async {
      const testPrincipalId = 'valid-dek-user';
      final storageKey = '${testPrincipalId}_coverwise_dek_v1';
      // Store a valid 32-byte key.
      _secureStorage[storageKey] = base64Encode(Uint8List.fromList(List.filled(32, 0x42)));

      await PrincipalKeyService().initForPrincipal(testPrincipalId);

      final dek = PrincipalKeyService().getOrThrow();
      expect(dek.length, 32);
      // The key should be our pre-stored value.
      for (int i = 0; i < 32; i++) {
        expect(dek[i], 0x42);
      }
    });

    test('missing key generates new 32-byte key', () async {
      const testPrincipalId = 'fresh-dek-user';
      // No pre-existing key in _secureStorage.

      await PrincipalKeyService().initForPrincipal(testPrincipalId);

      final dek = PrincipalKeyService().getOrThrow();
      expect(dek.length, 32);
      // Key should be random, not all zeros.
      expect(dek.any((b) => b != 0), isTrue);

      // The key should be persisted in secure storage.
      final storageKey = '${testPrincipalId}_coverwise_dek_v1';
      final persisted = _secureStorage[storageKey];
      expect(persisted, isNotNull);
      final decoded = base64Decode(persisted!);
      expect(Uint8List.fromList(decoded), dek);
    });
  });
}
