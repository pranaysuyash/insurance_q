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
    await Hive.openBox<String>('consent_ledger', encryptionCipher: cipher);
    await Hive.openBox<String>('qa_history', encryptionCipher: cipher);
    await Hive.openBox<String>('field_overrides_box', encryptionCipher: cipher);
    await Hive.openBox<String>('entitlements', encryptionCipher: cipher);
  }

  /// Reopen the current workspace for [principalId].
  ///
  /// Ordinary principal switches discard the previous workspace. An explicit
  /// anonymous-to-account claim may set [preserveCurrentWorkspace] to carry
  /// the local documents and metadata into the newly encrypted workspace.
  static Future<void> resetForPrincipal(
    String principalId, {
    bool preserveCurrentWorkspace = false,
  }) async {
    final workspaceEntries = <String, Map<dynamic, dynamic>>{};
    if (preserveCurrentWorkspace) {
      for (final boxName in _claimPreservedBoxNames) {
        if (Hive.isBoxOpen(boxName)) {
          workspaceEntries[boxName] = {
            for (final key in Hive.box(boxName).keys)
              if (boxName != AppStateStore.boxName ||
                  !_sessionKeys.contains(key))
                key: Hive.box(boxName).get(key),
          };
        }
      }
    }
    if (Hive.isBoxOpen(AppStateStore.boxName)) {
      await SessionService.clearSession();
    }
    for (final boxName in boxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
      await Hive.deleteBoxFromDisk(boxName);
    }
    await PrincipalKeyService().initForPrincipal(principalId);
    await openForActivePrincipal();
    if (preserveCurrentWorkspace) {
      for (final entry in workspaceEntries.entries) {
        final box = Hive.box(entry.key);
        for (final record in entry.value.entries) {
          await box.put(record.key, record.value);
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
