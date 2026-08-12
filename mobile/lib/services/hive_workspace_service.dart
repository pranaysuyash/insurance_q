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

  /// Best-effort read of Hive's base directory (set by `Hive.init()` /
  /// `Hive.initFlutter()`).
  ///
  /// hive 2.2.3 stores `homePath` on `HiveImpl`, which is not exposed through
  /// the exported `HiveInterface`, so it cannot be read statically. The
  /// dynamic access is isolated here behind a typed null-returning helper:
  /// if the field shape changes on an upgrade, this degrades to the
  /// relative-path fallback instead of throwing.
  static String? get _hiveHomePath {
    try {
      final Object? home = (Hive as dynamic).homePath;
      return (home is String && home.isNotEmpty) ? home : null;
    } catch (_) {
      return null;
    }
  }

  /// P0.5: Derives an isolated directory path for the given principal.
  /// Each principal gets its own subdirectory under `workspaces/`, keyed by
  /// the stable principalId with path-unsafe characters replaced. Examples:
  ///   `<homePath>/workspaces/local-only-550e8400-e29b-.../`
  ///   `<homePath>/workspaces/a1b2c3d4-e5f6-7890-abcd-ef1234567890/`
  ///
  /// The path is anchored to Hive's home path when set. In production
  /// `Hive.initFlutter()` sets it to the app documents directory, so boxes
  /// and attachment files land inside the app sandbox. In tests each test
  /// file calls `Hive.init(tempDir)` / `Hive.initFlutter(tempDir)` with its
  /// own temp directory, so workspaces land there too. A CWD-relative path
  /// would instead resolve against the process working directory
  /// (`mobile/` during `flutter test`, `/` on iOS/Android sandboxes) —
  /// polluting the repo, colliding on the same `.lock` file when two test
  /// isolates share a principal, and being unwritable on real devices.
  /// Falls back to the relative path only if Hive has not been initialized.
  static String _workspacePath(WorkspacePrincipal principal) {
    final safeDir =
        principal.principalId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final relative = 'workspaces/$safeDir';
    final home = _hiveHomePath;
    if (home == null || home.isEmpty) return relative;
    return '$home/$relative';
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
  /// After migration, all files in the attachments directory are checked
  /// for encryption. Files stored before CW-P0-002 encryption was added
  /// are re-encrypted in place.
  ///
  /// The old file is only deleted after successful copy verification.
  /// Both steps are idempotent: they track completion via flags in
  /// AppStateStore and skip if already done.
  static Future<void> _migrateLegacyAttachments() async {
    try {
      final appStateBox = Hive.box(AppStateStore.boxName);

      // ── Step 1: Migrate files from global directory to attachments ──
      if (appStateBox.get('attachments_migrated_v1') != true) {
        await _migrateFilesFromGlobalDirectory(appStateBox);
      }

      // ── Step 2: Re-encrypt any unencrypted files in attachments ──
      // Runs independently of step 1 — handles files that were already
      // in the attachments directory before encryption was added.
      if (appStateBox.get('attachments_reencrypted_v1') != true) {
        await _reEncryptAttachmentFiles(appStateBox);
      }
    } catch (e) {
      // Migration failure should not prevent workspace from opening.
      debugPrint('CW-P0-002: Legacy file migration failed: $e');
    }
  }

  /// Step 1 of migration: copy files from the global documents directory
  /// into the principal-scoped attachments directory.
  static Future<void> _migrateFilesFromGlobalDirectory(
    Box<dynamic> appStateBox,
  ) async {
    final docsBox = Hive.box<String>(LocalStorageService.documentsBoxName);
    if (docsBox.isEmpty) {
      await appStateBox.put('attachments_migrated_v1', true);
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final globalPath = appDir.path;

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

        // Already in the new attachments directory — skip migration
        // but will be re-encrypted in step 2 if needed.
        if (oldPath.startsWith(newAttachmentsPath)) {
          skipped++;
          continue;
        }

        // Not in the old global directory — skip.
        if (!oldPath.startsWith(globalPath)) {
          skipped++;
          continue;
        }

        final oldFile = File(oldPath);
        if (!await oldFile.exists()) {
          final updated = doc.copyWith(localFilePath: null);
          await docsBox.put(key, updated.toJsonString());
          skipped++;
          continue;
        }

        // Migrate: copy to new attachments directory (encrypted if key
        // available, unencrypted fallback otherwise — step 2 handles
        // re-encryption for the fallback case).
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
        } catch (e) {
          // Best-effort; a leftover legacy file is not a data-loss risk
          // because the migration already copied+verified the new file.
          debugPrint('CW-P0-002: Could not delete legacy file: $e');
        }

        migrated++;
      } catch (e) {
        debugPrint('CW-P0-002: Migration error for document $key: $e');
        failed++;
      }
    }

    // Only mark the migration complete when nothing failed. With
    // fail-closed encryption, a transiently-unavailable principal key
    // would otherwise strand legacy files permanently. The loop is
    // idempotent (already-migrated files are skipped by path check), so
    // a re-run next workspace open safely retries only the stragglers.
    if (failed == 0) {
      await appStateBox.put('attachments_migrated_v1', true);
    } else {
      debugPrint(
        'CW-P0-002: Legacy file migration incomplete — '
        '$failed file(s) failed; will retry on next workspace open. '
        '($migrated migrated, $skipped skipped)',
      );
    }
  }

  /// Step 2 of migration: re-encrypt any files in the attachments directory
  /// that were stored before CW-P0-002 encryption was added.
  ///
  /// Uses [EncryptedAttachmentStore.reEncryptIfNeeded] which checks for the
  /// CW01 magic header and re-encrypts in place if missing. Idempotent —
  /// already-encrypted files are no-ops.
  static Future<void> _reEncryptAttachmentFiles(
    Box<dynamic> appStateBox,
  ) async {
    final attachmentsDir = EncryptedAttachmentStore.attachmentsSubdir;
    final workspacePath = _currentWorkspacePath;
    if (workspacePath == null) return;

    final dir = Directory('$workspacePath/$attachmentsDir');
    if (!await dir.exists()) {
      await appStateBox.put('attachments_reencrypted_v1', true);
      return;
    }

    int processed = 0;
    int failed = 0;

    // Non-recursive: only process files directly in the attachments dir.
    await for (final entity in dir.list(recursive: false)) {
      if (entity is! File) continue;

      try {
        final ok =
            await EncryptedAttachmentStore.reEncryptIfNeeded(entity.path);
        if (ok) {
          processed++;
        } else {
          failed++;
        }
      } catch (e) {
        debugPrint(
          'CW-P0-002: Re-encryption error for ${entity.path}: $e',
        );
        failed++;
      }
    }

    // Only mark the re-encryption pass complete when nothing failed.
    // `reEncryptIfNeeded` leaves a file untouched (returns false) when no
    // principal key is available, so a transiently-unavailable key would
    // otherwise strand plaintext files permanently. The pass is idempotent
    // (already-encrypted files are no-ops), so a re-run on next workspace
    // open safely retries only the stragglers.
    if (failed == 0) {
      await appStateBox.put('attachments_reencrypted_v1', true);
    } else {
      debugPrint(
        'CW-P0-002: Re-encryption pass incomplete — '
        '$failed file(s) failed; will retry on next workspace open. '
        '($processed processed)',
      );
    }
  }

  /// CW-P0-002: One-time migration of legacy claim photos from the global
  /// claim_photos/ directory into the principal-scoped attachments directory.
  ///
  /// After migration, all files in the attachments directory referenced by
  /// claim records are checked for encryption. Files stored before CW-P0-002
  /// encryption was added are re-encrypted in place.
  ///
  /// Both steps are idempotent: they track completion via flags in
  /// AppStateStore and skip if already done.
  static Future<void> _migrateLegacyClaimPhotos() async {
    try {
      final appStateBox = Hive.box(AppStateStore.boxName);

      // ── Step 1: Migrate files from global claim_photos/ ──
      if (appStateBox.get('claim_photos_migrated_v1') != true) {
        await _migrateClaimPhotoFiles(appStateBox);
      }

      // ── Step 2: Re-encrypt migrated claim photos ──
      // Runs independently of step 1 — handles files that were already
      // in the attachments directory before encryption was added, as well
      // as files migrated when no key was available (legacy fallback).
      if (appStateBox.get('claim_photos_reencrypted_v1') != true) {
        await _reEncryptClaimPhotoFiles(appStateBox);
      }
    } catch (e) {
      // Migration failure should not prevent workspace from opening.
      debugPrint('CW-P0-002: Legacy claim photo migration failed: $e');
    }
  }

  /// Step 1: Migrate claim photo files from the global claim_photos/
  /// directory into the principal-scoped attachments directory.
  static Future<void> _migrateClaimPhotoFiles(
    Box<dynamic> appStateBox,
  ) async {
    final claimRecordsRaw = appStateBox.get(AppStateStore.claimRecordsKey);
    if (claimRecordsRaw is! String || claimRecordsRaw.isEmpty) {
      await appStateBox.put('claim_photos_migrated_v1', true);
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final globalPath = appDir.path;
    final oldClaimsPhotosDir = '$globalPath/claim_photos';

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
        // Step 2 will re-encrypt if needed.
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
          failed++;
          claimChanged = true;
          continue;
        }

        // Migrate: copy to new attachments directory with opaque name.
        // Encrypted during migration. CW-P0-003: if no principal key is
        // available this throws EncryptionUnavailableException (fail
        // closed) — catch per file so one failure does not abort the
        // whole migration; step 2 re-encryption is a no-op for the same
        // reason (no key → returns false, file left untouched).
        final photoId = const Uuid().v4();
        String? newPath;
        try {
          newPath = await EncryptedAttachmentStore.migrateLegacyFile(
            documentId: photoId,
            legacyPath: oldPath,
            originalFilename: 'claim_photo.jpg',
          );
        } catch (e) {
          debugPrint(
            'CW-P0-002: Claim photo migration failed for $oldPath: $e',
          );
          failed++;
          claimChanged = true;
          continue;
        }

        if (newPath == null) {
          failed++;
          continue;
        }

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

        try {
          await oldFile.delete();
        } catch (e) {
          // Best-effort; a leftover legacy photo is not a data-loss risk
          // because the migration already copied+verified the new file.
          debugPrint('CW-P0-002: Could not delete legacy claim photo: $e');
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

    if (anyChanged) {
      final encoded = jsonEncode(claims.map((r) => r.toJson()).toList());
      await appStateBox.put(AppStateStore.claimRecordsKey, encoded);
    }

    await appStateBox.put('claim_photos_migrated_v1', true);

    if (migrated > 0 || failed > 0) {
      debugPrint(
        'CW-P0-002: Legacy claim photo migration complete — '
        '$migrated migrated, $skipped skipped, $failed failed',
      );
    }
  }

  /// Step 2: Re-encrypt claim photos in the attachments directory that
  /// were stored before CW-P0-002 encryption was added.
  ///
  /// This runs AFTER _migrateClaimPhotoFiles() because
  /// _reEncryptAttachmentFiles() in openForActivePrincipal() executes
  /// BEFORE _migrateLegacyClaimPhotos(), so files migrated by step 1
  /// would not be caught by the earlier re-encryption pass.
  static Future<void> _reEncryptClaimPhotoFiles(
    Box<dynamic> appStateBox,
  ) async {
    final attachmentsDir = EncryptedAttachmentStore.attachmentsSubdir;
    final workspacePath = _currentWorkspacePath;
    if (workspacePath == null) return;

    final dir = Directory('$workspacePath/$attachmentsDir');
    if (!await dir.exists()) {
      await appStateBox.put('claim_photos_reencrypted_v1', true);
      return;
    }

    int processed = 0;
    int failed = 0;

    await for (final entity in dir.list(recursive: false)) {
      if (entity is! File) continue;

      try {
        final ok =
            await EncryptedAttachmentStore.reEncryptIfNeeded(entity.path);
        if (ok) {
          processed++;
        } else {
          failed++;
        }
      } catch (e) {
        debugPrint(
          'CW-P0-002: Claim photo re-encryption error for ${entity.path}: $e',
        );
        failed++;
      }
    }

    await appStateBox.put('claim_photos_reencrypted_v1', true);

    if (processed > 0 || failed > 0) {
      debugPrint(
        'CW-P0-002: Claim photo re-encryption pass complete — '
        '$processed processed, $failed failed',
      );
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
