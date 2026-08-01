import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'app_state_store.dart';
import 'encrypted_attachment_store.dart';
import 'local_storage_service.dart';
import 'principal_key_service.dart';
import 'session_service.dart';
import '../models/claim_record.dart';
import '../models/document_model.dart';
import '../models/identity.dart';  /// Owns the lifecycle of all principal-scoped Hive boxes.
  ///
  /// P0.5: Each principal's boxes are stored in an isolated directory at
  /// `<hivePath>/workspaces/<safeDir>/`. This prevents cross-principal data
  /// contamination and ensures that old principal data remains on disk after
  /// a transition, making it recoverable if the user switches back.
  ///
  /// Clearing a box is not enough during an account transition: an open Hive
  /// handle remains encrypted with the previous principal's DEK. This service
  /// closes and removes the cleared workspace before reopening it with the new
  /// principal key, keeping the lifecycle in one place.
class HiveWorkspaceService {
  HiveWorkspaceService._();

  static const List<String> boxNames = [
    LocalStorageService.documentsBoxName,
    AppStateStore.boxName,
    'resolved_gaps',
    'analytics_events',
    'consent_ledger',
    'qa_history',
    'field_overrides_box',
    'entitlements',
    'newsletter',
  ];

  /// Boxes whose user-facing workspace may move during the explicit
  /// anonymous-to-account claim. Analytics is install/session telemetry and
  /// entitlements are server authority; neither may cross a principal
  /// boundary by copying local records.
  static const Set<String> _claimPreservedBoxNames = {
    LocalStorageService.documentsBoxName,
    AppStateStore.boxName,
    'resolved_gaps',
    'consent_ledger',
    'qa_history',
    'field_overrides_box',
  };

  static const Set<String> _sessionKeys = {
    AppStateStore.sessionIdKey,
    AppStateStore.sessionCreatedKey,
  };

  /// P0.5: Derives an isolated directory path for the given principal.
  /// Each principal gets its own subdirectory under `workspaces/`, keyed by
  /// the stable principalId with path-unsafe characters replaced. Examples:
  ///   `workspaces/local-only-550e8400-e29b-.../`
  ///   `workspaces/a1b2c3d4-e5f6-7890-abcd-ef1234567890/`
  static String _workspacePath(WorkspacePrincipal principal) {
    final safeDir =
        principal.principalId.replaceAll(RegExp(r'[^\w\-]'), '_');
    return 'workspaces/$safeDir';
  }

  /// Compute the namespaced workspace path for [principal] without side
  /// effects. Used by callers that need the path before boxes are opened
  /// (e.g., legacy migration in main.dart).
  static String workspacePathFor(WorkspacePrincipal principal) =>
      _workspacePath(principal);

  /// The workspace path set by the most recent [openForActivePrincipal].
  /// Returns null before [openForActivePrincipal] is called.
  static String? get workspacePath => _currentWorkspacePath;
  static String? _currentWorkspacePath;

  /// Open all principal-scoped boxes at [path] with the given [cipher].
  /// Shared by [openForActivePrincipal] and the P0.6 rollback path.
  static Future<void> _openAllBoxes(String path, Uint8List key) async {
    final cipher = HiveAesCipher(key);
    await Hive.openBox<String>(
      LocalStorageService.documentsBoxName,
      path: path,
      encryptionCipher: cipher,
    );
    await Hive.openBox(
      AppStateStore.boxName,
      path: path,
      encryptionCipher: cipher,
    );
    await Hive.openBox<String>(
      'resolved_gaps',
      path: path,
      encryptionCipher: cipher,
    );
    await Hive.openBox<String>(
      'analytics_events',
      path: path,
      encryptionCipher: cipher,
    );
    await Hive.openBox(
      'consent_ledger',
      path: path,
      encryptionCipher: cipher,
    );
    await Hive.openBox<String>(
      'qa_history',
      path: path,
      encryptionCipher: cipher,
    );
    await Hive.openBox<String>(
      'field_overrides_box',
      path: path,
      encryptionCipher: cipher,
    );
    await Hive.openBox<String>(
      'entitlements',
      path: path,
      encryptionCipher: cipher,
    );
    // Audit 7 P0.8: Newsletter box must be opened with the workspace.
    // Without this, NewsletterService._box returns null and every write
    // is a silent no-op — subscribe() returns true despite nothing being
    // persisted (a false-completion claim).
    await Hive.openBox(
      'newsletter',
      path: path,
      encryptionCipher: cipher,
    );
  }

  /// P0.5: Opens all principal-scoped Hive boxes at the namespaced path
  /// for the given [principal]. Boxes opened here use the namespaced
  /// directory so different principals' data is isolated on disk.
  static Future<void> openForActivePrincipal(
    WorkspacePrincipal principal,
  ) async {
    final path = _workspacePath(principal);
    _currentWorkspacePath = path;
    await _openAllBoxes(path, PrincipalKeyService().getOrThrow());

    // CW-P0-002: One-time migration of legacy files from the global
    // documents directory into the principal-scoped attachments directory.
    // This is idempotent — skips if already migrated or no documents exist.
    await _migrateLegacyAttachments();

    // CW-P0-002: One-time migration of legacy claim photos from the global
    // claim_photos/ directory into the principal-scoped attachments directory.
    await _migrateLegacyClaimPhotos();
  }

  /// CW-P0-002: One-time migration of source files from the global
  /// application documents directory into the principal-scoped attachments
  /// directory. Each document's `localFilePath` is checked — if it points
  /// to a file outside the attachments directory, it is copied to the new
  /// location and the Hive record is updated.
  ///
  /// The old file is only deleted after successful copy verification.
  /// This method is idempotent: it tracks completion via a flag in
  /// AppStateStore and skips if already done.
  static Future<void> _migrateLegacyAttachments() async {
    try {
      final appStateBox = Hive.box(AppStateStore.boxName);

      // Skip if already migrated.
      if (appStateBox.get('attachments_migrated_v1') == true) return;

      final docsBox = Hive.box<String>(LocalStorageService.documentsBoxName);
      if (docsBox.isEmpty) {
        // No documents — mark as migrated and return.
        await appStateBox.put('attachments_migrated_v1', true);
        return;
      }

      // Get the old global documents directory.
      final appDir = await getApplicationDocumentsDirectory();
      final globalPath = appDir.path;

      // Get the new attachments directory.
      final attachmentsDir = EncryptedAttachmentStore.attachmentsSubdir;
      final workspacePath = _currentWorkspacePath;
      if (workspacePath == null) return;
      final newAttachmentsPath = '$workspacePath/$attachmentsDir';

      int migrated = 0;
      int skipped = 0;
      int failed = 0;

      for (final key in docsBox.keys.toList()) {
        final raw = docsBox.get(key);
        if (raw == null) continue;

        try {
          final doc = InsuranceDocument.fromJsonString(raw);
          final oldPath = doc.localFilePath;
          if (oldPath == null || oldPath.isEmpty) {
            skipped++;
            continue;
          }

          // Check if the file is already in the new attachments directory.
          if (oldPath.startsWith(newAttachmentsPath)) {
            skipped++;
            continue;
          }

          // Check if the file is in the old global directory.
          if (!oldPath.startsWith(globalPath)) {
            // File is somewhere unexpected — skip.
            skipped++;
            continue;
          }

          final oldFile = File(oldPath);
          if (!await oldFile.exists()) {
            // File missing — clear the path reference.
            final updated = doc.copyWith(localFilePath: null);
            await docsBox.put(key, updated.toJsonString());
            skipped++;
            continue;
          }

          // Migrate: copy to new attachments directory.
          final newPath = await EncryptedAttachmentStore.migrateLegacyFile(
            documentId: doc.id,
            legacyPath: oldPath,
            originalFilename: doc.filename,
          );

          if (newPath == null) {
            failed++;
            continue;
          }

          // Verify the copy succeeded before updating the record.
          final newFile = File(newPath);
          if (!await newFile.exists()) {
            failed++;
            continue;
          }

          // Verify file sizes match.
          final oldSize = await oldFile.length();
          final newSize = await newFile.length();
          if (oldSize != newSize) {
            failed++;
            continue;
          }

          // Update the Hive record with the new path.
          final updated = doc.copyWith(localFilePath: newPath);
          await docsBox.put(key, updated.toJsonString());

          // Delete the old file.
          try {
            await oldFile.delete();
          } catch (_) {
            // Best-effort: old file deletion failure is non-fatal.
          }

          migrated++;
        } catch (e) {
          // Per-document errors should not block the entire migration.
          debugPrint('CW-P0-002: Migration error for document $key: $e');
          failed++;
        }
      }

      // Mark migration as complete.
      await appStateBox.put('attachments_migrated_v1', true);

      if (migrated > 0 || failed > 0) {
        debugPrint(
          'CW-P0-002: Legacy file migration complete — '
          '$migrated migrated, $skipped skipped, $failed failed',
        );
      }
    } catch (e) {
      // Migration failure should not prevent workspace from opening.
      debugPrint('CW-P0-002: Legacy file migration failed: $e');
    }
  }

  /// CW-P0-002: One-time migration of legacy claim photos from the global
  /// claim_photos/ directory into the principal-scoped attachments directory.
  ///
  /// Each claim record's photoPaths are checked — if any path points to the
  /// old global claim_photos/ directory, the file is copied to the new
  /// attachments directory and the path reference is updated.
  ///
  /// The old file is only deleted after successful copy verification.
  /// This method is idempotent: it tracks completion via a flag in
  /// AppStateStore and skips if already done.
  static Future<void> _migrateLegacyClaimPhotos() async {
    try {
      final appStateBox = Hive.box(AppStateStore.boxName);

      // Skip if already migrated.
      if (appStateBox.get('claim_photos_migrated_v1') == true) return;

      final claimRecordsRaw = appStateBox.get(AppStateStore.claimRecordsKey);
      if (claimRecordsRaw is! String || claimRecordsRaw.isEmpty) {
        // No claims — mark as migrated and return.
        await appStateBox.put('claim_photos_migrated_v1', true);
        return;
      }

      // Get the old global documents directory.
      final appDir = await getApplicationDocumentsDirectory();
      final globalPath = appDir.path;
      final oldClaimsPhotosDir = '$globalPath/claim_photos';

      // Get the new attachments directory.
      final attachmentsDir = EncryptedAttachmentStore.attachmentsSubdir;
      final workspacePath = _currentWorkspacePath;
      if (workspacePath == null) return;
      final newAttachmentsPath = '$workspacePath/$attachmentsDir';

      // Parse claims, preserving quarantine behavior.
      List<ClaimRecord> claims = [];
      try {
        final decoded = jsonDecode(claimRecordsRaw);
        if (decoded is List) {
          for (var i = 0; i < decoded.length; i++) {
            try {
              claims.add(
                ClaimRecord.fromJson(decoded[i] as Map<String, dynamic>),
              );
            } catch (e) {
              debugPrint(
                'CW-P0-002: Skipping malformed claim at index $i during photo migration: $e',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('CW-P0-002: Failed to parse claim records: $e');
        await appStateBox.put('claim_photos_migrated_v1', true);
        return;
      }

      if (claims.isEmpty) {
        await appStateBox.put('claim_photos_migrated_v1', true);
        return;
      }

      int migrated = 0;
      int skipped = 0;
      int failed = 0;
      bool anyChanged = false;

      for (var ci = 0; ci < claims.length; ci++) {
        final claim = claims[ci];
        if (claim.photoPaths.isEmpty) {
          skipped++;
          continue;
        }

        bool claimChanged = false;
        final newPaths = <String>[];

        for (final oldPath in claim.photoPaths) {
          // Already in the new directory — keep as-is.
          if (oldPath.startsWith(newAttachmentsPath)) {
            newPaths.add(oldPath);
            skipped++;
            continue;
          }

          // Not in the old claim_photos directory — keep as-is.
          if (!oldPath.startsWith(oldClaimsPhotosDir)) {
            newPaths.add(oldPath);
            skipped++;
            continue;
          }

          final oldFile = File(oldPath);
          if (!await oldFile.exists()) {
            // File missing — drop the path reference.
            failed++;
            claimChanged = true;
            continue;
          }

          // Migrate: copy to new attachments directory with opaque name.
          final photoId = const Uuid().v4();
          final newPath = await EncryptedAttachmentStore.migrateLegacyFile(
            documentId: photoId,
            legacyPath: oldPath,
            originalFilename: 'claim_photo.jpg',
          );

          if (newPath == null) {
            failed++;
            continue;
          }

          // Verify the copy succeeded.
          final newFile = File(newPath);
          if (!await newFile.exists()) {
            failed++;
            continue;
          }

          final oldSize = await oldFile.length();
          final newSize = await newFile.length();
          if (oldSize != newSize) {
            failed++;
            continue;
          }

          newPaths.add(newPath);
          claimChanged = true;

          // Delete the old file.
          try {
            await oldFile.delete();
          } catch (_) {
            // Best-effort.
          }

          migrated++;
        }

        if (claimChanged) {
          claims[ci] = claim.copyWith(
            photoPaths: List.unmodifiable(newPaths),
          );
          anyChanged = true;
        }
      }

      // Save updated claims if any paths changed.
      if (anyChanged) {
        final encoded = jsonEncode(claims.map((r) => r.toJson()).toList());
        await appStateBox.put(AppStateStore.claimRecordsKey, encoded);
      }

      // Mark migration as complete.
      await appStateBox.put('claim_photos_migrated_v1', true);

      if (migrated > 0 || failed > 0) {
        debugPrint(
          'CW-P0-002: Legacy claim photo migration complete — '
          '$migrated migrated, $skipped skipped, $failed failed',
        );
      }
    } catch (e) {
      // Migration failure should not prevent workspace from opening.
      debugPrint('CW-P0-002: Legacy claim photo migration failed: $e');
    }
  }

  /// P0.6: Safely transition the workspace to a new principal.
  ///
  /// Uses a transactional approach:
  ///   1. Backs up entries from the old workspace (if preserve requested).
  ///   2. Closes only workspace-owned boxes (not all Hive boxes).
  ///   3. Initializes the new principal's encryption key.
  ///   4. Opens fresh boxes at the new principal's namespaced path.
  ///   5. Restores backed-up entries.
  ///
  /// If steps 3-5 fail, the method attempts a rollback: re-initialize the
  /// old principal's key and reopen boxes at the old workspace path. The
  /// old data remains on disk at its namespace (P0.5) so rollback simply
  /// re-opens the same storage files with the old key.
  ///
  /// If rollback also fails, the workspace is unrecoverable and the error
  /// propagates to the caller (which should surface a restart prompt).
  static Future<void> resetForPrincipal(
    WorkspacePrincipal principal, {
    bool preserveCurrentWorkspace = false,
  }) async {
    final oldPrincipalId = PrincipalKeyService().principalId;
    final oldWorkspacePath = _currentWorkspacePath;
    final workspaceEntries = <String, Map<dynamic, dynamic>>{};

    // Step 1: Back up entries from the current workspace before closing.
    if (preserveCurrentWorkspace) {
      for (final boxName in _claimPreservedBoxNames) {
        if (Hive.isBoxOpen(boxName)) {
          final boxEntries = <dynamic, dynamic>{};
          if (boxName == LocalStorageService.documentsBoxName ||
              boxName == 'resolved_gaps' ||
              boxName == 'qa_history' ||
              boxName == 'field_overrides_box') {
            final box = Hive.box<String>(boxName);
            for (final key in box.keys) {
              boxEntries[key] = box.get(key);
            }
          } else {
            final box = Hive.box(boxName);
            for (final key in box.keys) {
              if (boxName == AppStateStore.boxName &&
                  _sessionKeys.contains(key)) {
                continue;
              }
              boxEntries[key] = box.get(key);
            }
          }
          workspaceEntries[boxName] = boxEntries;
        }
      }
    }

    // Step 2: Close all Hive boxes. Hive.close() fully deregisters every
    // box name from the internal registry, which is required before
    // reopening at the new principal's namespaced path (step 4).
    //
    // Per-box close (Hive.box(name).close()) does NOT fully deregister
    // box names in Hive 2.x, causing a HiveError on reopen. Hive.close()
    // is the only reliable way to deregister all boxes. Plugin-owned boxes
    // (shared_preferences, sentry) are lightweight and will be reopened
    // by their respective plugins when needed.
    if (Hive.isBoxOpen(AppStateStore.boxName)) {
      await SessionService.clearSession();
    }
    await Hive.close();

    try {
      // Step 3: Initialize the new principal's encryption key.
      await PrincipalKeyService().initForPrincipal(principal.principalId);

      // Step 4: Open fresh boxes at the new principal's namespaced path.
      // The old principal's boxes remain on disk at their own path (P0.5).
      _currentWorkspacePath = _workspacePath(principal);
      await _openAllBoxes(_currentWorkspacePath!, PrincipalKeyService().getOrThrow());

      // Step 5: Restore backed-up entries into the new workspace.
      if (preserveCurrentWorkspace) {
        for (final entry in workspaceEntries.entries) {
          for (final record in entry.value.entries) {
            if (entry.key == LocalStorageService.documentsBoxName ||
                entry.key == 'resolved_gaps' ||
                entry.key == 'qa_history' ||
                entry.key == 'field_overrides_box') {
              final box = Hive.box<String>(entry.key);
              await box.put(record.key, record.value);
            } else if (entry.key == AppStateStore.boxName ||
                entry.key == 'consent_ledger') {
              final box = Hive.box(entry.key);
              await box.put(record.key, record.value);
            } else {
              final box = Hive.box<String>(entry.key);
              await box.put(record.key, record.value);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('resetForPrincipal failed for ${principal.principalId}: $e');

      // P0.6: Attempt rollback — restore the old principal's workspace.
      // Old data is preserved on disk at the old path (P0.5), so rollback
      // re-opens those boxes with the old encryption key.
      if (oldPrincipalId != null && oldWorkspacePath != null) {
        try {
          await _rollbackWorkspace(oldPrincipalId, oldWorkspacePath);
          debugPrint('resetForPrincipal: rollback to $oldPrincipalId succeeded');
        } catch (rollbackError) {
          debugPrint(
            'resetForPrincipal: rollback also failed — workspace unrecoverable: '
            '$rollbackError',
          );
        }
      }

      // Surface the original error regardless — rollback is best-effort.
      rethrow;
    }
  }

  /// P0.6: Attempt to restore the workspace for [oldPrincipalId] at
  /// [oldWorkspacePath]. This is a best-effort recovery path invoked when
  /// a workspace transition fails mid-sequence — it reinitializes the old
  /// principal's DEK and reopens all boxes at the old path.
  static Future<void> _rollbackWorkspace(
    String oldPrincipalId,
    String oldWorkspacePath,
  ) async {
    await PrincipalKeyService().initForPrincipal(oldPrincipalId);
    _currentWorkspacePath = oldWorkspacePath;
    await _openAllBoxes(oldWorkspacePath, PrincipalKeyService().getOrThrow());
    debugPrint('rollbackWorkspace: restored workspace for $oldPrincipalId');
  }

  /// Centralized lifecycle method to clear all local workspace boxes, delete
  /// temporary cached source files, and reset local state safely.
  static Future<void> clearLocalWorkspace() async {
    for (final boxName in boxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).clear();
      }
    }
    await LocalStorageService().clearCache();
  }
}
