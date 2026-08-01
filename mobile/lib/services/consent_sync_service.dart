import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state_store.dart';
import 'consent_ledger.dart';
import 'server_consent_service.dart';
import 'session_service.dart';

/// Converges the principal's local consent cache with the server ledger.
///
/// CW-P0-004: The server is the source of truth for consent state.
/// This service now performs bidirectional sync:
/// - [syncAll]: Push local decisions → server (for offline grants)
/// - [pullFromServer]: Pull server authority → local cache (for cross-device
///   revocations and server-side overrides)
///
/// Local consent remains the immediate offline decision. Successful server
/// record IDs are represented by a principal-scoped signature so retries do
/// not append the same current decision on every app start or upload.
class ConsentSyncService {
  static final ConsentSyncService _instance = ConsentSyncService._();
  factory ConsentSyncService({Dio? dio}) {
    if (dio != null) return ConsentSyncService._(dio: dio);
    return _instance;
  }
  ConsentSyncService._({Dio? dio}) : _dio = dio;

  final Dio? _dio;
  Future<int>? _inFlight;
  Future<bool>? _pullInFlight;

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

  /// CW-P0-004: Pull server consent authority and reconcile local cache.
  ///
  /// The server is the source of truth. If the server says consent was
  /// revoked (or granted) on another device, the local cache must update.
  /// This prevents stale local grants from bypassing a server-side revocation.
  ///
  /// Returns true if the local cache was updated (server had newer state).
  Future<bool> pullFromServer() async {
    final existing = _pullInFlight;
    if (existing != null) return existing;
    final future = _pullFromServer();
    _pullInFlight = future;
    future.then<void>(
      (_) => _pullInFlight = null,
      onError: (_, __) => _pullInFlight = null,
    );
    return future;
  }

  Future<bool> _pullFromServer() async {
    final server = ServerConsentService(dio: _dio);
    final result = await server.getCurrentConsentAll();
    if (result is! ConsentSnapshotLoaded) {
      // Server unreachable or invalid — keep local cache as-is.
      return false;
    }

    final ledger = ConsentLedger();
    var updated = false;

    for (final serverRecord in result.records) {
      final purpose = ConsentPurpose.fromString(serverRecord.consentType);
      if (purpose == null) continue;

      final localRecord = ledger.getLatestRecord(purpose);
      final serverTime = serverRecord.createdAt;

      // Server record is newer than local — adopt server authority.
      if (localRecord == null || serverTime.isAfter(localRecord.timestamp)) {
        await ledger.recordConsent(
          purpose: purpose,
          version: serverRecord.policyVersion,
          granted: serverRecord.granted,
        );
        updated = true;
      }
    }
    return updated;
  }

  Future<int> _syncAll() async {
    final box = Hive.box(AppStateStore.boxName);
    // Gracefully degrade when Supabase is not initialized (e.g. unit tests).
    String principal;
    try {
      principal = Supabase.instance.client.auth.currentUser?.id ??
          await SessionService.getSessionId();
    } catch (_) {
      principal = await SessionService.getSessionId();
    }
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
    final server = ServerConsentService(dio: _dio);
    for (final candidate in candidates) {
      final record = candidate.record;
      final signature =
          '${candidate.serverType}:${record.version}:${record.granted}';
      final cacheKey = 'server_consent_sync:$principal:${candidate.serverType}';
      if (box.get(cacheKey) == signature) continue;
      try {
        final result = await server
            .recordConsent(
              consentType: candidate.serverType,
              granted: record.granted,
              policyVersion: record.version,
            )
            .timeout(const Duration(seconds: 5));
        // P0.13: Only cache the signature on explicit server success.
        // ConsentTypeRejected means the type was invalid — do not cache.
        // ConsentAuthenticationRequired means re-auth needed — do not cache.
        // ConsentServiceUnavailable / ConsentNetworkError — retry next time.
        if (result is ConsentRecorded) {
          await box.put(cacheKey, signature);
          synced++;
        } else if (result is ConsentTypeRejected) {
          // ConsentTypeRejected indicates a programming bug: the sync
          // service is trying to push a consent type that the server
          // does not recognize. Log explicitly so this surfaces during
          // development rather than being silently swallowed.
          debugPrint(
            'ConsentSyncService BUG: tried to push unknown type '
            '"${result.consentType}" — check the add() calls in '
            'ConsentSyncService._syncAll and '
            'ServerConsentRecord.knownConsentTypes.',
          );
        }
        // ConsentAuthenticationRequired, ConsentRejected,
        // ConsentServiceUnavailable, ConsentNetworkError: leave the
        // signature absent so the next startup/upload retries it.
      } catch (_) {
        // Leave the signature absent. The next startup/upload retries it.
      }
    }
    return synced;
  }
}
