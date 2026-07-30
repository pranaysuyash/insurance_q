import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_state_store.dart';
import 'local_storage_service.dart';
import 'principal_key_service.dart';
import 'session_service.dart';
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
