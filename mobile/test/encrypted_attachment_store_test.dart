import 'dart:io';

import 'package:coverwise/models/identity.dart';
import 'package:coverwise/services/encrypted_attachment_store.dart';
import 'package:coverwise/services/hive_workspace_service.dart';
import 'package:coverwise/services/principal_key_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/services.dart';

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

/// Tests for [EncryptedAttachmentStore]: encrypt/decrypt round-trip,
/// CW01 magic header detection, and backward compatibility with legacy
/// unencrypted files.
///
/// The store requires a workspace path (via [HiveWorkspaceService]) and
/// a principal key (via [PrincipalKeyService]) for encryption. These are
/// initialized once per test group using a temp directory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  const testPrincipalId = 'test-attachment-store-principal';

  setUp(() async {
    _secureStorage.clear();
    _mockSecureStorage();
    tempDir =
        await Directory.systemTemp.createTemp('encrypted_attachment_test_');
    Hive.init(tempDir.path);

    // Initialize the principal key so _getFileKey() returns a valid key.
    await PrincipalKeyService().initForPrincipal(testPrincipalId);

    // Open the workspace to set HiveWorkspaceService.workspacePath.
    await HiveWorkspaceService.openForActivePrincipal(
      LocalPrincipal(testPrincipalId),
    );
  });

  tearDown(() async {
    PrincipalKeyService().clearKey();
    // Reset the mock secure storage handler to prevent leaking to other
    // test files in the same test runner.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
    // Hive.close() is NOT called here — the test isolate owns the temp
    // directory and the OS cleans up after exit. Closing boxes here can
    // deadlock if other tests are running in parallel.
  });

  /// Writes a raw (unencrypted, no CW01 header) legacy file directly into
  /// the workspace attachments directory, creating the directory first.
  ///
  /// The store's own write/copyFrom paths create the attachments directory
  /// lazily, but tests that simulate legacy files bypass those paths. The
  /// directory must be created explicitly because each test gets a fresh
  /// temp workspace — it is no longer inherited from earlier polluted runs
  /// in the repository working directory.
  Future<String> writeLegacyAttachment(String name, List<int> bytes) async {
    final wsPath = HiveWorkspaceService.workspacePath!;
    final attachmentsDir = Directory(p.join(wsPath, 'attachments'));
    await attachmentsDir.create(recursive: true);
    final path = p.join(attachmentsDir.path, name);
    await File(path).writeAsBytes(bytes);
    return path;
  }



  // ─── Encrypt / decrypt round-trip ────────────────────────────────────

  group('encrypt/decrypt round-trip', () {
    test('write + read returns the original bytes', () async {
      final original = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final path = await EncryptedAttachmentStore.write(
        documentId: 'roundtrip-1',
        originalFilename: 'data.bin',
        bytes: original,
      );

      expect(path, isNotNull);
      final readBack = await EncryptedAttachmentStore.read(path!);
      expect(readBack, equals(original));
    });

    test('round-trip preserves empty content', () async {
      final original = Uint8List(0);
      final path = await EncryptedAttachmentStore.write(
        documentId: 'roundtrip-empty',
        originalFilename: 'empty.bin',
        bytes: original,
      );

      expect(path, isNotNull);
      final readBack = await EncryptedAttachmentStore.read(path!);
      expect(readBack, isNotNull);
      expect(readBack!.length, 0);
    });

    test('round-trip preserves large content (1 MiB)', () async {
      final original = Uint8List(1024 * 1024);
      for (var i = 0; i < original.length; i++) {
        original[i] = i & 0xFF;
      }
      final path = await EncryptedAttachmentStore.write(
        documentId: 'roundtrip-large',
        originalFilename: 'large.bin',
        bytes: original,
      );

      expect(path, isNotNull);
      final readBack = await EncryptedAttachmentStore.read(path!);
      expect(readBack, equals(original));
    });

    test('copyFrom + read round-trip preserves source bytes', () async {
      // Write a source file.
      final srcDir = await Directory.systemTemp.createTemp('src_');
      final srcFile = File(p.join(srcDir.path, 'source.pdf'));
      final original = Uint8List.fromList([10, 20, 30, 40, 50]);
      await srcFile.writeAsBytes(original);

      final path = await EncryptedAttachmentStore.copyFrom(
        documentId: 'copy-roundtrip',
        sourceFile: srcFile,
      );

      expect(path, isNotNull);
      final readBack = await EncryptedAttachmentStore.read(path!);
      expect(readBack, equals(original));

      // Clean up.
      await srcDir.delete(recursive: true);
    });

    test('different plaintexts produce different ciphertexts (random IV)',
        () async {
      final a = Uint8List.fromList([1, 2, 3]);
      final b = Uint8List.fromList([1, 2, 3]);

      final pathA = await EncryptedAttachmentStore.write(
        documentId: 'iv-test-a',
        originalFilename: 'a.bin',
        bytes: a,
      );
      final pathB = await EncryptedAttachmentStore.write(
        documentId: 'iv-test-b',
        originalFilename: 'b.bin',
        bytes: b,
      );

      // Read the raw encrypted bytes (skip magic + IV, compare ciphertext).
      final rawA = await File(pathA!).readAsBytes();
      final rawB = await File(pathB!).readAsBytes();
      final ctA = rawA.sublist(16); // 4 magic + 12 IV = 16
      final ctB = rawB.sublist(16);
      expect(ctA, isNot(equals(ctB)));
    });
  });

  // ─── CW01 magic header detection ─────────────────────────────────────

  group('CW01 magic header', () {
    test('encrypted file starts with CW01 (0x43 0x57 0x30 0x31)', () async {
      final original = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
      final path = await EncryptedAttachmentStore.write(
        documentId: 'magic-header-1',
        originalFilename: 'hello.bin',
        bytes: original,
      );

      final raw = await File(path!).readAsBytes();
      expect(raw.length, greaterThanOrEqualTo(4 + 12)); // magic + IV minimum
      expect(raw[0], 0x43); // 'C'
      expect(raw[1], 0x57); // 'W'
      expect(raw[2], 0x30); // '0'
      expect(raw[3], 0x31); // '1'
    });

    test('encrypted file is longer than plaintext by at least 20 bytes '
        '(4 magic + 12 IV + 16 GCM tag)', () async {
      final plaintext = Uint8List.fromList([1, 2, 3]);
      final path = await EncryptedAttachmentStore.write(
        documentId: 'magic-overhead',
        originalFilename: 'small.bin',
        bytes: plaintext,
      );

      final raw = await File(path!).readAsBytes();
      // Minimum overhead: 4 (magic) + 12 (IV) + 16 (GCM tag) = 32
      // But AES-GCM pads to block boundary, so actual overhead may vary.
      expect(raw.length, greaterThanOrEqualTo(plaintext.length + 32));
    });

    test('legacy file without CW01 header is NOT detected as encrypted',
        () async {
      // Write a file that starts with non-CW01 bytes.
      final legacyPath = await writeLegacyAttachment(
        'legacy_no_header.bin',
        Uint8List.fromList([0x00, 0x01, 0x02, 0x03]),
      );

      final raw = await File(legacyPath).readAsBytes();
      // Verify it does NOT start with CW01.
      final isCw01 = raw.length >= 4 &&
          raw[0] == 0x43 &&
          raw[1] == 0x57 &&
          raw[2] == 0x30 &&
          raw[3] == 0x31;
      expect(isCw01, isFalse);
    });
  });

  // ─── Backward compatibility with legacy unencrypted files ─────────────

  group('backward compatibility (legacy unencrypted files)', () {
    test('read() returns raw bytes for a file without CW01 header', () async {
      final legacyContent = Uint8List.fromList([200, 201, 202, 203, 204]);
      final legacyPath =
          await writeLegacyAttachment('legacy_readable.bin', legacyContent);

      final readBack = await EncryptedAttachmentStore.read(legacyPath);
      expect(readBack, equals(legacyContent));
    });

    test('read() returns null for a non-existent file', () async {
      final result =
          await EncryptedAttachmentStore.read('/tmp/nonexistent_file.bin');
      expect(result, isNull);
    });

    test('reEncryptIfNeeded() upgrades a legacy file to encrypted', () async {
      final legacyContent = Uint8List.fromList([100, 101, 102, 103]);
      final legacyPath =
          await writeLegacyAttachment('legacy_reencrypt.bin', legacyContent);

      // Re-encrypt.
      final result =
          await EncryptedAttachmentStore.reEncryptIfNeeded(legacyPath);
      expect(result, isTrue);

      // Verify the file now has the CW01 header.
      final raw = await File(legacyPath).readAsBytes();
      expect(raw[0], 0x43);
      expect(raw[1], 0x57);
      expect(raw[2], 0x30);
      expect(raw[3], 0x31);

      // Verify the original content is recoverable.
      final readBack = await EncryptedAttachmentStore.read(legacyPath);
      expect(readBack, equals(legacyContent));
    });

    test('reEncryptIfNeeded() is a no-op for already-encrypted files',
        () async {
      final original = Uint8List.fromList([50, 51, 52, 53]);
      final path = await EncryptedAttachmentStore.write(
        documentId: 'already-encrypted',
        originalFilename: 'test.bin',
        bytes: original,
      );

      // Read raw bytes before re-encryption attempt.
      final rawBefore = await File(path!).readAsBytes();

      // Re-encrypt should be a no-op (already has CW01 header).
      final result = await EncryptedAttachmentStore.reEncryptIfNeeded(path);
      expect(result, isTrue);

      // File should be byte-identical (same content, same encryption).
      final rawAfter = await File(path).readAsBytes();
      expect(rawAfter, equals(rawBefore));
    });

    test('reEncryptIfNeeded() returns false for non-existent file', () async {
      final result = await EncryptedAttachmentStore
          .reEncryptIfNeeded('/tmp/nonexistent_reencrypt.bin');
      expect(result, isFalse);
    });

    test('read() after reEncryptIfNeeded() decrypts correctly', () async {
      // Simulate a legacy file (no CW01 header).
      final legacyContent = Uint8List.fromList([10, 20, 30, 40, 50]);
      final legacyPath = await writeLegacyAttachment(
        'legacy_read_after.bin',
        legacyContent,
      );

      // Before re-encryption, read() returns raw bytes.
      final beforeReencrypt =
          await EncryptedAttachmentStore.read(legacyPath);
      expect(beforeReencrypt, equals(legacyContent));

      // Re-encrypt.
      await EncryptedAttachmentStore.reEncryptIfNeeded(legacyPath);

      // After re-encryption, read() decrypts and returns original content.
      final afterReencrypt = await EncryptedAttachmentStore.read(legacyPath);
      expect(afterReencrypt, equals(legacyContent));
    });
  });

  // ─── safeDelete path containment ─────────────────────────────────────

  group('safeDelete path containment', () {
    test('deletes a file inside the attachments directory', () async {
      final path = await EncryptedAttachmentStore.write(
        documentId: 'delete-inside',
        originalFilename: 'del.bin',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final result = await EncryptedAttachmentStore.safeDelete(path!);
      expect(result, isTrue);
      expect(await File(path).exists(), isFalse);
    });

    test('refuses to delete a file outside the attachments directory',
        () async {
      // Create a file outside the attachments directory.
      final outsidePath = p.join(tempDir.path, 'outside_file.bin');
      await File(outsidePath).writeAsBytes(Uint8List.fromList([99]));

      final result =
          await EncryptedAttachmentStore.safeDelete(outsidePath);
      expect(result, isFalse);
      // The file must NOT have been deleted.
      expect(await File(outsidePath).exists(), isTrue);
    });

    test('returns true for a non-existent file (idempotent delete)', () async {
      final result = await EncryptedAttachmentStore.safeDelete(
        p.join(HiveWorkspaceService.workspacePath!, 'attachments', 'already_gone.bin'),
      );
      expect(result, isTrue);
    });
  });

  // ─── newPath opaque naming ───────────────────────────────────────────

  group('newPath', () {
    test('generates an opaque path with preserved extension', () async {
      final path = await EncryptedAttachmentStore.newPath(
        documentId: 'abc-123',
        originalFilename: 'policy_document.pdf',
      );

      expect(path, isNotNull);
      expect(path, contains('abc-123'));
      expect(path, endsWith('.pdf'));
      // Must NOT contain the original filename.
      expect(path, isNot(contains('policy_document')));
    });

    test('generates unique paths for successive calls', () async {
      final path1 = await EncryptedAttachmentStore.newPath(
        documentId: 'id-1',
        originalFilename: 'doc.pdf',
      );
      final path2 = await EncryptedAttachmentStore.newPath(
        documentId: 'id-2',
        originalFilename: 'doc.pdf',
      );
      expect(path1, isNotNull);
      expect(path2, isNotNull);
      expect(path1, isNot(equals(path2)));
    });
  });

  // ─── Null-key decryption path ─────────────────────────────────────────

  group('null-key decryption path', () {
    test('read() returns null for encrypted file when no key is available',
        () async {
      // Write an encrypted file while the key IS available.
      final original = Uint8List.fromList([1, 2, 3, 4, 5]);
      final path = await EncryptedAttachmentStore.write(
        documentId: 'null-key-test',
        originalFilename: 'secret.bin',
        bytes: original,
      );
      expect(path, isNotNull);

      // Verify the file has the CW01 header (is encrypted).
      final raw = await File(path!).readAsBytes();
      expect(raw[0], 0x43); // 'C'
      expect(raw[1], 0x57); // 'W'

      // Clear the key to simulate no principal key available.
      PrincipalKeyService().clearKey();

      // read() should return null because it cannot decrypt.
      final result = await EncryptedAttachmentStore.read(path);
      expect(result, isNull);
    });

    test('reEncryptIfNeeded() returns false when no key is available',
        () async {
      // Write an encrypted file while the key IS available.
      final path = await EncryptedAttachmentStore.write(
        documentId: 'null-key-reencrypt',
        originalFilename: 'test.bin',
        bytes: Uint8List.fromList([10, 20, 30]),
      );
      expect(path, isNotNull);

      // Clear the key.
      PrincipalKeyService().clearKey();

      // reEncryptIfNeeded() should return false (no key to encrypt with).
      final result =
          await EncryptedAttachmentStore.reEncryptIfNeeded(path!);
      expect(result, isFalse);
    });
  });

  // ─── CW-P0-003: fail-closed writes (launch audit P0-3) ───────────────

  group('fail-closed writes (no principal key)', () {
    test('write() throws EncryptionUnavailableException when no key',
        () async {
      // Clear the key to simulate no principal key available.
      PrincipalKeyService().clearKey();

      expect(
        () => EncryptedAttachmentStore.write(
          documentId: 'fail-closed-write',
          originalFilename: 'policy.pdf',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<EncryptionUnavailableException>()),
      );
    });

    test('copyFrom() throws EncryptionUnavailableException when no key',
        () async {
      // Write a source file.
      final srcDir = await Directory.systemTemp.createTemp('src_fc_');
      final srcFile = File(p.join(srcDir.path, 'policy.pdf'));
      await srcFile.writeAsBytes(Uint8List.fromList([7, 8, 9]));

      // Clear the key to simulate no principal key available.
      PrincipalKeyService().clearKey();

      expect(
        () => EncryptedAttachmentStore.copyFrom(
          documentId: 'fail-closed-copy',
          sourceFile: srcFile,
        ),
        throwsA(isA<EncryptionUnavailableException>()),
      );

      await srcDir.delete(recursive: true);
    });

    test('failed write() does NOT leave a plaintext file behind', () async {
      // Clear the key first.
      PrincipalKeyService().clearKey();

      final wsPath = HiveWorkspaceService.workspacePath!;
      final attachmentsDir = Directory('$wsPath/attachments');
      final filesBefore = attachmentsDir.existsSync()
          ? attachmentsDir.listSync().whereType<File>().length
          : 0;

      try {
        await EncryptedAttachmentStore.write(
          documentId: 'fail-closed-no-file',
          originalFilename: 'secret.pdf',
          bytes: Uint8List.fromList([99, 98, 97]),
        );
        fail('Expected EncryptionUnavailableException');
      } catch (e) {
        expect(e, isA<EncryptionUnavailableException>());
      }

      // No new file may exist in the attachments directory (no plaintext
      // was persisted), and no partial encrypted file either.
      final filesAfter = attachmentsDir.existsSync()
          ? attachmentsDir.listSync().whereType<File>().length
          : 0;
      expect(filesAfter, filesBefore);
    });

    test('migrateLegacyFile() fails closed when no key is available',
        () async {
      // Write a legacy source file outside the attachments directory.
      final srcDir = await Directory.systemTemp.createTemp('src_legacy_');
      final legacyFile = File(p.join(srcDir.path, 'old_policy.pdf'));
      await legacyFile.writeAsBytes(Uint8List.fromList([1, 5, 9]));

      // Clear the key.
      PrincipalKeyService().clearKey();

      expect(
        () => EncryptedAttachmentStore.migrateLegacyFile(
          documentId: 'fail-closed-migrate',
          legacyPath: legacyFile.path,
          originalFilename: 'old_policy.pdf',
        ),
        throwsA(isA<EncryptionUnavailableException>()),
      );

      // The legacy file must remain untouched (migration failed cleanly).
      expect(await legacyFile.exists(), isTrue);
      await srcDir.delete(recursive: true);
    });
  });
}
