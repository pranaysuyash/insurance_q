import 'package:hive/hive.dart';

import 'app_state_store.dart';
import 'auth_service.dart';
import 'consent_ledger.dart';
import 'server_consent_service.dart';
import 'session_service.dart';

/// Converges the principal's local consent cache with the server ledger.
///
/// Local consent remains the immediate offline decision. Successful server
/// record IDs are represented by a principal-scoped signature so retries do
/// not append the same current decision on every app start or upload.
class ConsentSyncService {
  static final ConsentSyncService _instance = ConsentSyncService._();
  factory ConsentSyncService() => _instance;
  ConsentSyncService._();

  Future<int>? _inFlight;

  Future<int> syncAll() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _syncAll();
    _inFlight = future;
    future.then<void>(
      (_) => _inFlight = null,
      onError: (_, __) => _inFlight = null,
    );
    return future;
  }

  Future<int> _syncAll() async {
    final box = Hive.box(AppStateStore.boxName);
    final principal =
        AuthService.accountUserId ?? await SessionService.getSessionId();
    final ledger = ConsentLedger();
    final candidates = <({
      String serverType,
      ConsentRecord record,
    })>[];

    void add(ConsentPurpose purpose, String serverType) {
      final record = ledger.getLatestRecord(purpose);
      if (record != null) {
        candidates.add((serverType: serverType, record: record));
      }
    }

    add(ConsentPurpose.analytics, ConsentPurpose.analytics.value);
    add(ConsentPurpose.documentProcessing, ConsentPurpose.documentProcessing.value);
    add(ConsentPurpose.privacyPolicy, ConsentPurpose.privacyPolicy.value);
    add(ConsentPurpose.marketingEmails, ConsentPurpose.marketingEmails.value);
    add(ConsentPurpose.cameraAccess, ConsentPurpose.cameraAccess.value);
    add(ConsentPurpose.evaluationDataset, ConsentPurpose.evaluationDataset.value);
    add(ConsentPurpose.modelImprovement, ConsentPurpose.modelImprovement.value);

    var synced = 0;
    final server = ServerConsentService();
    for (final candidate in candidates) {
      final record = candidate.record;
      final signature =
          '${candidate.serverType}:${record.version}:${record.granted}';
      final cacheKey = 'server_consent_sync:$principal:${candidate.serverType}';
      if (box.get(cacheKey) == signature) continue;
      try {
        final id = await server
            .recordConsent(
              consentType: candidate.serverType,
              granted: record.granted,
              policyVersion: record.version,
            )
            .timeout(const Duration(seconds: 5));
        if (id != null) {
          await box.put(cacheKey, signature);
          synced++;
        }
      } catch (_) {
        // Leave the signature absent. The next startup/upload retries it.
      }
    }
    return synced;
  }
}
