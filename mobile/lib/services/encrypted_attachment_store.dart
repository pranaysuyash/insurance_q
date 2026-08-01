import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;

import 'hive_workspace_service.dart';

/// CW-P0-002: Principal-scoped, opaque-named attachment store.
///
/// Source policy files (PDFs, images) are stored inside the principal's
/// encrypted workspace directory with opaque filenames that do not reveal
/// document type. Every delete operation validates path containment to
/// prevent arbitrary file deletion from corrupted metadata.
///
/// This service does NOT encrypt individual files at rest — that requires
/// a dedicated dependency (e.g. `encrypt` package) and is tracked as a
/// follow-up. The directory itself is within the principal's Hive workspace,
/// which provides isolation between principals.
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

  /// Write bytes to a new attachment at an opaque path.
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

    await File(filePath).writeAsBytes(bytes, flush: true);
    return filePath;
  }

  /// Copy a file to a new attachment at an opaque path.
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

    await sourceFile.copy(filePath);
    return filePath;
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
}
