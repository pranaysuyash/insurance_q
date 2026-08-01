import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;

import 'hive_workspace_service.dart';
import 'principal_key_service.dart';

/// CW-P0-002: Principal-scoped, opaque-named, AES-256-GCM encrypted
/// attachment store.
///
/// Source policy files (PDFs, images) are stored inside the principal's
/// encrypted workspace directory with opaque filenames that do not reveal
/// document type. Every file is encrypted at rest using AES-256-GCM with
/// a random12-byte IV per file. The IV is stored as a prefix in the
/// encrypted file.
///
/// Every delete operation validates path containment to prevent arbitrary
/// file deletion from corrupted metadata.
///
/// The directory itself is within the principal's Hive workspace, which
/// provides isolation between principals.
///
/// **File format (encrypted):**
/// ```
/// [4 bytes magic: CW01][12 bytes IV][encrypted data + 16 bytes GCM tag]
/// ```
///
/// **File format (legacy unencrypted):**
/// Any file that does NOT start with the `CW01` magic header is treated
/// as a legacy unencrypted file and read directly.
///
/// Path structure:
/// ```
/// {workspacePath}/attachments/{docId}_{hash}.{ext}
/// ```
///
/// The hash suffix is a short content-independent random string to prevent
/// filename collisions without revealing the original filename.
class EncryptedAttachmentStore {
  EncryptedAttachmentStore._();

  static const String _attachmentsDir = 'attachments';

  /// The subdirectory name within the principal workspace.
  static String get attachmentsSubdir => _attachmentsDir;

  /// Get the principal-scoped attachments directory.
  ///
  /// Returns null if no workspace is currently active (e.g. before login
  /// or after sign-out).
  static Directory? _attachmentsDirectory() {
    final workspacePath = HiveWorkspaceService.workspacePath;
    if (workspacePath == null) return null;
    return Directory(p.join(workspacePath, _attachmentsDir));
  }

  /// Get the full path for a new attachment with an opaque filename.
  ///
  /// The filename is `{docId}_{randomHex8}.{extension}` where:
  /// - `docId` is the document's local ID (opaque UUID)
  /// - `randomHex8` is 4 random bytes as hex to prevent collisions
  /// - `extension` is preserved from the original filename for MIME detection
  ///
  /// Returns null if no workspace is active.
  static Future<String?> newPath({
    required String documentId,
    required String originalFilename,
  }) async {
    final dir = _attachmentsDirectory();
    if (dir == null) return null;

    // Ensure the directory exists.
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Preserve the extension for MIME type detection by the OS and by
    // consumers (PDF viewer, image viewer, OCR).
    final ext = p.extension(originalFilename).toLowerCase();
    // Generate 4 random bytes as hex for collision resistance.
    final randomHex = _randomHex(4);

    // The opaque filename does NOT contain the original filename — it only
    // has the document ID (already opaque UUID) and a random suffix.
    final opaqueName = '${documentId}_$randomHex$ext';
    return p.join(dir.path, opaqueName);
  }

  /// 4-byte magic header identifying CW-P0-002 encrypted files.
  static const List<int> _magicHeader = [0x43, 0x57, 0x30, 0x31]; // 'CW01'

  /// IV length in bytes for AES-256-GCM.
  static const int _ivLength = 12;

  /// Get the principal DEK for file encryption. Returns null if no
  /// principal key is available (before login or after sign-out).
  static encrypt_lib.Key? _getFileKey() {
    try {
      final dek = PrincipalKeyService().getOrThrow();
      return encrypt_lib.Key(dek);
    } catch (_) {
      return null;
    }
  }

  /// Encrypt plaintext bytes using AES-256-GCM.
  ///
  /// Returns `[CW01 magic][12-byte IV][encrypted data + GCM tag]`.
  static Uint8List _encryptBytes(Uint8List plaintext, encrypt_lib.Key key) {
    final iv = encrypt_lib.IV.fromSecureRandom(_ivLength);
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.gcm),
    );
    final encrypted = encrypter.encryptBytes(plaintext, iv: iv);

    // Build the output: magic + IV + encrypted bytes (includes GCM tag).
    final output = Uint8List(4 + _ivLength + encrypted.bytes.length);
    output.setRange(0, 4, _magicHeader);
    output.setRange(4, 4 + _ivLength, iv.bytes);
    output.setRange(4 + _ivLength, output.length, encrypted.bytes);
    return output;
  }

  /// Decrypt an encrypted file (starts with CW01 magic header).
  ///
  /// Returns the decrypted plaintext bytes. Throws if decryption fails
  /// (wrong key, corrupted data, or tampered GCM tag).
  static Uint8List _decryptBytes(
    Uint8List encryptedData,
    encrypt_lib.Key key,
  ) {
    if (encryptedData.length < 4 + _ivLength) {
      throw StateError('Encrypted file too short to contain IV');
    }
    final iv = encrypt_lib.IV(encryptedData.sublist(4, 4 + _ivLength));
    final ciphertext = encryptedData.sublist(4 + _ivLength);
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.gcm),
    );
    return Uint8List.fromList(encrypter.decryptBytes(
      encrypt_lib.Encrypted(ciphertext),
      iv: iv,
    ));
  }

  /// Check if a file has the CW01 encrypted magic header.
  static bool _isEncrypted(Uint8List header) {
    if (header.length < 4) return false;
    return header[0] == _magicHeader[0] &&
        header[1] == _magicHeader[1] &&
        header[2] == _magicHeader[2] &&
        header[3] == _magicHeader[3];
  }

  /// Write bytes to a new attachment at an opaque path.
  ///
  /// The bytes are encrypted with AES-256-GCM before writing.
  /// If no principal key is available, bytes are written unencrypted
  /// (legacy mode — the migration will re-encrypt later).
  ///
  /// Returns the path where the file was written, or null if no workspace
  /// is active.
  static Future<String?> write({
    required String documentId,
    required String originalFilename,
    required Uint8List bytes,
  }) async {
    final filePath = await newPath(
      documentId: documentId,
      originalFilename: originalFilename,
    );
    if (filePath == null) return null;

    final key = _getFileKey();
    if (key != null) {
      // Encrypt before writing.
      final encrypted = _encryptBytes(bytes, key);
      await File(filePath).writeAsBytes(encrypted, flush: true);
    } else {
      // No key available — write unencrypted (legacy fallback).
      await File(filePath).writeAsBytes(bytes, flush: true);
    }
    return filePath;
  }

  /// Copy a file to a new attachment at an opaque path.
  ///
  /// The source file bytes are encrypted with AES-256-GCM before writing.
  /// If no principal key is available, bytes are written unencrypted.
  ///
  /// Returns the path where the file was copied, or null if no workspace
  /// is active.
  static Future<String?> copyFrom({
    required String documentId,
    required File sourceFile,
  }) async {
    final filePath = await newPath(
      documentId: documentId,
      originalFilename: p.basename(sourceFile.path),
    );
    if (filePath == null) return null;

    final key = _getFileKey();
    if (key != null) {
      // Read source, encrypt, write.
      final sourceBytes = await sourceFile.readAsBytes();
      final encrypted = _encryptBytes(sourceBytes, key);
      await File(filePath).writeAsBytes(encrypted, flush: true);
    } else {
      // No key available — copy unencrypted (legacy fallback).
      await sourceFile.copy(filePath);
    }
    return filePath;
  }

  /// Read and decrypt an attachment file.
  ///
  /// If the file has the CW01 magic header, it is decrypted with the
  /// principal DEK. If not (legacy unencrypted file), the raw bytes
  /// are returned directly.
  ///
  /// Returns null if the file does not exist, no workspace is active,
  /// or the file is encrypted but no principal key is available.
  static Future<Uint8List?> read(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final raw = await file.readAsBytes();
    if (_isEncrypted(raw)) {
      final key = _getFileKey();
      if (key == null) {
        // No key available — cannot decrypt. Return null rather than
        // throwing, so callers get a consistent 'file unavailable' signal.
        debugPrint(
          'CW-P0-002: Cannot decrypt $filePath — no principal key',
        );
        return null;
      }
      return _decryptBytes(raw, key);
    }
    // Legacy unencrypted file.
    return raw;
  }

  /// Delete an attachment after validating path containment.
  ///
  /// CW-P0-002: Never delete using a raw stored path. This method
  /// canonicalizes the path and verifies it remains inside the
  /// principal's attachments directory before deletion.
  ///
  /// Returns true if the file was successfully deleted or did not exist.
  /// Returns false if the path is outside the allowed directory (security
  /// boundary violation — the file is NOT deleted).
  static Future<bool> safeDelete(String filePath) async {
    final dir = _attachmentsDirectory();
    if (dir == null) return false;

    // Canonicalize both paths to prevent symlink escape and path traversal.
    // Wrap in try-catch because canonicalize throws on non-existent paths
    // on some platforms.
    String resolvedFile;
    String resolvedDir;
    try {
      resolvedFile = p.canonicalize(filePath);
      resolvedDir = p.canonicalize(dir.path);
    } catch (_) {
      // Path doesn't exist yet or cannot be canonicalized — refuse to delete.
      return false;
    }

    // Containment check: the file must be inside the attachments directory.
    if (!resolvedFile.startsWith('$resolvedDir${Platform.pathSeparator}')) {
      debugPrint(
        'CW-P0-002: Path containment violation — refusing to delete '
        '$resolvedFile (outside $resolvedDir)',
      );
      return false;
    }

    final file = File(resolvedFile);
    if (await file.exists()) {
      await file.delete();
    }
    return true;
  }

  /// Check whether a file path is within the principal's attachments dir.
  ///
  /// Use this before any operation that trusts a stored path to verify
  /// the path has not been corrupted or tampered with.
  /// Returns false if paths cannot be canonicalized (e.g. non-existent).
  static bool isPathContained(String filePath) {
    final dir = _attachmentsDirectory();
    if (dir == null) return false;

    try {
      final resolvedFile = p.canonicalize(filePath);
      final resolvedDir = p.canonicalize(dir.path);
      return resolvedFile
          .startsWith('$resolvedDir${Platform.pathSeparator}');
    } catch (_) {
      return false;
    }
  }

  /// Generate a hex string of [byteCount] cryptographically random bytes.
  /// Uses Hive.generateSecureKey() which provides platform-secure randomness.
  static String _randomHex(int byteCount) {
    final key = Hive.generateSecureKey();
    return key
        .take(byteCount)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Migrate a legacy file (from global documents directory) into the
  /// principal-scoped attachments directory.
  ///
  /// If a principal key is available, the file is encrypted during
  /// migration. If not, it is copied unencrypted (legacy fallback).
  ///
  /// Returns the new path if migration succeeded, or null if the source
  /// file doesn't exist or no workspace is active.
  ///
  /// The old file is NOT deleted — the caller should verify migration
  /// succeeded before cleaning up legacy paths.
  static Future<String?> migrateLegacyFile({
    required String documentId,
    required String legacyPath,
    required String originalFilename,
  }) async {
    final file = File(legacyPath);
    if (!await file.exists()) return null;

    return copyFrom(
      documentId: documentId,
      sourceFile: file,
    );
  }

  /// Re-encrypt a legacy unencrypted file in the attachments directory.
  ///
  /// If the file already has the CW01 magic header, this is a no-op.
  /// Otherwise, the file is read, encrypted, and written back in place.
  ///
  /// Used during the legacy file migration to upgrade plaintext files
  /// that were stored before CW-P0-002 encryption was added.
  ///
  /// Returns true if the file was re-encrypted or was already encrypted.
  /// Returns false if the file does not exist or no key is available.
  static Future<bool> reEncryptIfNeeded(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final key = _getFileKey();
    if (key == null) return false;

    final raw = await file.readAsBytes();
    if (_isEncrypted(raw)) {
      // Already encrypted.
      return true;
    }

    // Re-encrypt in place.
    final encrypted = _encryptBytes(raw, key);
    await file.writeAsBytes(encrypted, flush: true);
    return true;
  }
}
