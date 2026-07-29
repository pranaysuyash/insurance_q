import 'package:hive_flutter/hive_flutter.dart';

import 'app_state_store.dart';
import 'local_storage_service.dart';
import 'principal_key_service.dart';
import 'session_service.dart';

/// Owns the lifecycle of all principal-scoped Hive boxes.
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

  static Future<void> openForActivePrincipal() async {
    final cipher = HiveAesCipher(PrincipalKeyService().getOrThrow());
    await Hive.openBox<String>(
      LocalStorageService.documentsBoxName,
      encryptionCipher: cipher,
    );
    await Hive.openBox(AppStateStore.boxName, encryptionCipher: cipher);
    await Hive.openBox<String>('resolved_gaps', encryptionCipher: cipher);
    await Hive.openBox<String>('analytics_events', encryptionCipher: cipher);
    await Hive.openBox('consent_ledger', encryptionCipher: cipher);
    await Hive.openBox<String>('qa_history', encryptionCipher: cipher);
    await Hive.openBox<String>('field_overrides_box', encryptionCipher: cipher);
    await Hive.openBox<String>('entitlements', encryptionCipher: cipher);
  }

  /// Reopen the current workspace for [principalId].
  ///
  /// Ordinary principal switches discard the previous workspace. An explicit
  /// anonymous-to-account claim may set [preserveCurrentWorkspace] to carry
  /// the local documents and metadata into the newly encrypted workspace.
  ///
  /// If the operation fails after closing the old boxes but before
  /// successfully opening the new ones, the workspace is left in an
  /// unusable state. The caller should catch this and surface it to the
  /// user (e.g., a "workspace error, please restart" screen).
  static Future<void> resetForPrincipal(
    String principalId, {
    bool preserveCurrentWorkspace = false,
  }) async {
    // Step 1: Back up entries from the current workspace before closing.
    final workspaceEntries = <String, Map<dynamic, dynamic>>{};
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

    // Step 2: Clear session and close all boxes.
    if (Hive.isBoxOpen(AppStateStore.boxName)) {
      await SessionService.clearSession();
    }
    await Hive.close();

    // Step 3: Delete old boxes from disk.
    for (final boxName in boxNames) {
      await Hive.deleteBoxFromDisk(boxName);
    }

    // Step 4: Initialize the new principal's encryption key.
    await PrincipalKeyService().initForPrincipal(principalId);

    // Step 5: Open fresh boxes with the new key.
    await openForActivePrincipal();

    // Step 6: Restore backed-up entries into the new workspace.
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
