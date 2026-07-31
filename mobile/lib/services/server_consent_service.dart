import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'document_service.dart';

// ---------------------------------------------------------------------------
// Typed result classes for consent operations
// ---------------------------------------------------------------------------

/// Audit 5 P0.13: Typed result for consent write operations.
///
/// Previously, `recordConsent` returned `String?` — null for 503, 404, 401,
/// validation failure, network error, malformed response, parsing error, and
/// programming error. These are not equivalent and callers could not
/// distinguish "offline deferral" from "wrong credentials" from "bad payload".
sealed class ConsentWriteResult {
  const ConsentWriteResult();
}

/// The server accepted and persisted the consent record.
class ConsentRecorded extends ConsentWriteResult {
  final String serverRecordId;
  const ConsentRecorded(this.serverRecordId);
}

/// The consent type was not in [ServerConsentRecord.knownConsentTypes].
/// The request was never sent to the server.
class ConsentTypeRejected extends ConsentWriteResult {
  final String consentType;
  const ConsentTypeRejected(this.consentType);
}

/// The server returned 401 — the user is not authenticated or the token
/// is expired. The caller should re-authenticate before retrying.
class ConsentAuthenticationRequired extends ConsentWriteResult {
  const ConsentAuthenticationRequired();
}

/// The server returned 404 — the consent endpoint does not exist on this
/// backend deployment. The caller should not retry.
class ConsentEndpointNotFound extends ConsentWriteResult {
  const ConsentEndpointNotFound();
}

/// The server returned 422 or another 4xx — the consent payload was
/// rejected (e.g. unknown consent_type, missing fields, invalid
/// policy_version). The caller should not retry without fixing the payload.
class ConsentRejected extends ConsentWriteResult {
  final int statusCode;
  final String? detail;
  const ConsentRejected(this.statusCode, {this.detail});
}

/// The server returned 503 or another 5xx — the server is temporarily
/// unavailable. The local cache remains valid; the caller may retry
/// later.
class ConsentServiceUnavailable extends ConsentWriteResult {
  final int? statusCode;
  const ConsentServiceUnavailable({this.statusCode});
}

/// A network or transport-level failure prevented the request from
/// reaching the server. The local cache remains valid.
class ConsentNetworkError extends ConsentWriteResult {
  final Object error;
  const ConsentNetworkError(this.error);
}

/// Audit 5 P0.13: Typed result for consent read operations.
///
/// Previously, `getCurrentConsentAll` returned `List<ServerConsentRecord>?`
/// where null meant "unreachable" and an empty list could mean either
/// "no consents" or "malformed response".
sealed class ConsentReadResult {
  const ConsentReadResult();
}

/// The server returned a valid list of consent records (possibly empty).
/// An empty list here means the user genuinely has no server-side consent
/// records — this is distinct from "unreachable" or "malformed".
class ConsentSnapshotLoaded extends ConsentReadResult {
  final List<ServerConsentRecord> records;
  const ConsentSnapshotLoaded(this.records);
}

/// The server is unreachable (503, 401, 404, network error). The caller
/// should keep the local cache.
class ConsentSnapshotUnavailable extends ConsentReadResult {
  const ConsentSnapshotUnavailable();
}

/// The server returned a response that could not be parsed as a valid
/// consent list. The caller should keep the local cache and log the
/// anomaly.
class ConsentSnapshotInvalid extends ConsentReadResult {
  const ConsentSnapshotInvalid();
}

// ---------------------------------------------------------------------------
// Server consent service
// ---------------------------------------------------------------------------

/// Server-side consent ledger client (Security Phase 2).
///
/// Per docs/decisions/ADR-2026-07-19-07-...md, the consent
/// ledger is server-side and append-only. The Flutter app's
/// local Hive box (`mobile/lib/services/consent_ledger.dart`)
/// is the cache; the server is the source of truth.
///
/// This client is the Flutter-side bridge to the FastAPI
/// endpoints at `src/api/consent.py`. The Flutter app calls
/// `recordConsent` to record a consent event, and
/// `getCurrentConsentAll` on app start to populate the local
/// cache.
class ServerConsentService {
  final Dio _dio;

  ServerConsentService({Dio? dio})
      : _dio = dio ?? DocumentService.authenticatedDio;

  /// Record a consent event. The user_id is NOT in the body
  /// — the server extracts it from the Supabase Auth token
  /// to prevent spoofing. The Flutter app sends the consent
  /// type, the granted bool, and the policy_version.
  ///
  /// Audit 5 P0.13: Returns a typed [ConsentWriteResult] so callers can
  /// distinguish every failure mode. Callers MUST switch on the result type
  /// rather than testing for null.
  ///
  /// Audit 5 P0.14: Validates [consentType] against [ServerConsentRecord.knownConsentTypes]
  /// before sending. Returns [ConsentTypeRejected] for unknown types.
  Future<ConsentWriteResult> recordConsent({
    required String consentType,
    required bool granted,
    required String policyVersion,
  }) async {
    // P0.14: Validate consent type before sending to prevent typos like
    // 'document_processsing' or 'analytic' from creating divergent local
    // and server ledgers.
    if (!ServerConsentRecord.knownConsentTypes.contains(consentType)) {
      debugPrint(
        'consent record rejected: unknown type "$consentType" '
        '(valid: ${ServerConsentRecord.knownConsentTypes})',
      );
      return ConsentTypeRejected(consentType);
    }

    try {
      final response = await _dio.post(
        '/consent',
        data: {
          'consent_type': consentType,
          'granted': granted,
          'policy_version': policyVersion,
        },
      );
      if (response.statusCode == 201 && response.data is Map) {
        final id = (response.data as Map)['id'] as String?;
        if (id != null) {
          return ConsentRecorded(id);
        }
        // Server returned 201 but no id — treat as service error.
        return const ConsentServiceUnavailable();
      }
      // Unexpected status code on a nominally successful request.
      return ConsentRejected(
        response.statusCode ?? 0,
        detail: 'Unexpected status code on consent record',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        return const ConsentAuthenticationRequired();
      }
      if (status == 404) {
        return const ConsentEndpointNotFound();
      }
      if (status != null && status >= 400 && status < 500) {
        return ConsentRejected(status, detail: e.message);
      }
      if (status == 503 || (status != null && status >= 500)) {
        return ConsentServiceUnavailable(statusCode: status);
      }
      // Network-level failure (timeout, connection refused, etc.).
      return ConsentNetworkError(e);
    } catch (e) {
      return ConsentNetworkError(e);
    }
  }

  /// Parse a raw JSON list from the server into [ServerConsentRecord]
  /// instances, quarantining any malformed entries. Used by both
  /// [getCurrentConsentAll] and [getConsentHistory].
  List<ServerConsentRecord> _parseServerRecords(dynamic data) {
    final records = <ServerConsentRecord>[];
    for (final item in data as List) {
      if (item is Map<String, dynamic>) {
        try {
          records.add(ServerConsentRecord.fromJson(item));
        } catch (e) {
          debugPrint('consent read: skipping malformed record: $e');
        }
      }
    }
    return records;
  }

  /// Read the current consent state for the authenticated
  /// user. Returns one row per consent_type (the most recent
  /// record). The Flutter app calls this on app start to
  /// populate the local cache.
  ///
  /// Audit 5 P0.13/P0.15: Returns a typed [ConsentReadResult] so callers
  /// can distinguish "authoritative empty" from "unreachable" from
  /// "malformed response". Callers MUST switch on the result type.
  Future<ConsentReadResult> getCurrentConsentAll() async {
    try {
      final response = await _dio.get('/consent/current');
      if (response.statusCode == 200 && response.data is List) {
        return ConsentSnapshotLoaded(_parseServerRecords(response.data));
      }
      // Non-200 status that wasn't caught as DioException — treat as
      // invalid response rather than empty consent.
      return const ConsentSnapshotInvalid();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 404 || status == 503) {
        return const ConsentSnapshotUnavailable();
      }
      // Other Dio errors (timeout, connection refused, etc.).
      return const ConsentSnapshotUnavailable();
    } catch (e) {
      // Parsing error or unexpected exception — response is invalid.
      debugPrint('consent read unexpected error: $e');
      return const ConsentSnapshotInvalid();
    }
  }

  /// Read the append-only consent activity for the authenticated user.
  ///
  /// Audit 5 P0.13/P0.15: Returns a typed [ConsentReadResult].
  /// A [ConsentSnapshotUnavailable] means the authoritative ledger could
  /// not be reached; callers must not present the local cache as the
  /// complete account history.
  Future<ConsentReadResult> getConsentHistory({
    int limit = 100,
  }) async {
    // Runtime validation (not assert) so validation works in release builds.
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 500');
    }
    try {
      final response = await _dio.get(
        '/consent/history',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200 && response.data is List) {
        return ConsentSnapshotLoaded(_parseServerRecords(response.data));
      }
      return const ConsentSnapshotInvalid();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 404 || status == 503) {
        return const ConsentSnapshotUnavailable();
      }
      return const ConsentSnapshotUnavailable();
    } catch (e) {
      debugPrint('consent history read unexpected error: $e');
      return const ConsentSnapshotInvalid();
    }
  }
}

/// The typed shape of one row from v_current_consent.
/// Mirrors the server-side ConsentType enum + the
/// CurrentConsent Pydantic model.
class ServerConsentRecord {
  final String id;
  final String userId;
  final String consentType;
  final bool granted;
  final String policyVersion;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  const ServerConsentRecord({
    required this.id,
    required this.userId,
    required this.consentType,
    required this.granted,
    required this.policyVersion,
    required this.ipAddress,
    required this.userAgent,
    required this.createdAt,
  });

  factory ServerConsentRecord.fromJson(Map<String, dynamic> json) {
    return ServerConsentRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      consentType: json['consent_type'] as String,
      granted: json['granted'] as bool,
      policyVersion: json['policy_version'] as String,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// The 7 known consent types in v1. Mirrors the server
  /// enum; a drift here means the Flutter UI is showing a
  /// type the server does not recognize.
  static const Set<String> knownConsentTypes = {
    'privacy_policy',
    'document_processing',
    'analytics',
    'marketing_emails',
    'camera_access',
    'evaluation_dataset',
    'model_improvement',
  };
}
