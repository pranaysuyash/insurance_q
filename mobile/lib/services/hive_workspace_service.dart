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

  /// Discard the current workspace and reopen it for [principalId].
  ///
  /// This is called only after the caller has intentionally cleared local
  /// account data during sign-out or account transition.
  static Future<void> resetForPrincipal(String principalId) async {
    if (Hive.isBoxOpen(AppStateStore.boxName)) {
      await SessionService.clearSession();
    }
    for (final boxName in boxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {
        // Fresh installs may not have a file for every logical box.
      }
    }
    await PrincipalKeyService().initForPrincipal(principalId);
    await openForActivePrincipal();
  }
}
