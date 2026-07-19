import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

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
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: Duration(seconds: AppConfig.connectTimeoutSeconds),
    receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
  ));

  /// Record a consent event. The user_id is NOT in the body
  /// — the server extracts it from the Supabase Auth token
  /// to prevent spoofing. The Flutter app sends the consent
  /// type, the granted bool, and the policy_version.
  ///
  /// Returns the new consent record's id on success.
  /// Returns null on 503 (server not configured) or 401
  /// (unauthenticated) — the caller should keep the local
  /// cache and show a 'last verified at' timestamp.
  Future<String?> recordConsent({
    required String consentType,
    required bool granted,
    required String policyVersion,
  }) async {
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
        return (response.data as Map)['id'] as String?;
      }
      return null;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 503 || status == 401 || status == 404) {
        debugPrint('consent record failed: $status (cache will be used)');
        return null;
      }
      debugPrint('consent record unexpected error: $e');
      return null;
    } catch (e) {
      debugPrint('consent record unexpected error: $e');
      return null;
    }
  }

  /// Read the current consent state for the authenticated
  /// user. Returns one row per consent_type (the most recent
  /// record). The Flutter app calls this on app start to
  /// populate the local cache.
  ///
  /// Returns null on 503 (server not configured), 401
  /// (unauthenticated), or transport-level failure. The
  /// caller keeps the local cache in that case.
  Future<List<ServerConsentRecord>?> getCurrentConsentAll() async {
    try {
      final response = await _dio.get('/consent/current');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => ServerConsentRecord.fromJson(
                  (item as Map).cast<String, dynamic>(),
                ))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 503 || status == 401 || status == 404) {
        debugPrint('consent read failed: $status (cache will be used)');
        return null;
      }
      debugPrint('consent read unexpected error: $e');
      return null;
    } catch (e) {
      debugPrint('consent read unexpected error: $e');
      return null;
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

  /// The 4 known consent types in v1. Mirrors the server
  /// enum; a drift here means the Flutter UI is showing a
  /// type the server does not recognize.
  static const Set<String> knownConsentTypes = {
    'privacy_policy',
    'analytics',
    'marketing_emails',
    'camera_access',
  };
}
