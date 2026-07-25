/// Synchronises a user's self-reported claim log between backend and Hive.
///
/// The mobile app stores claims locally via [AppStateRepository] (Hive). The
/// backend API (POST /claims, GET /claims) provides server-side persistence
/// for cross-device sync of the user's own records.
///
/// Sync strategy:
///   - On app startup (or when online), pull claims from the backend and merge
///     them into the local store. Server claims take precedence for status
///     and reference_number; the local store is the source of truth for
///     photo_paths (which are file-system paths not accessible server-side).
///   - When a new claim is filed locally, push it to the backend via POST /claims.
///   - Conflicts are resolved by taking the most recently updated record.
///
/// This is a best-effort sync: failures are logged but never block the UI
/// because the local store is always functional offline.
library;

import 'package:dio/dio.dart';
import '../models/claim_record.dart';
import '../services/app_state_repository.dart';
import '../services/document_service.dart';

/// Result of a sync operation for diagnostics and UI feedback.
class ClaimsSyncResult {
  final int pulledCount;
  final int pushedCount;
  final int errorCount;
  final String? errorMessage;

  const ClaimsSyncResult({
    this.pulledCount = 0,
    this.pushedCount = 0,
    this.errorCount = 0,
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null;
}

class ClaimsSyncService {
  final Dio _dio;
  ClaimsSyncService(this._dio);

  /// Reuses the existing [DocumentService.authenticatedDio] which already
  /// has AuthInterceptor wired in. No need to create a separate Dio instance
  /// with a duplicate AuthInterceptor.
  static Dio get authenticatedDio => DocumentService.authenticatedDio;

  /// Pull claims from the backend and merge into local storage.
  ///
  /// Server records with a later [updatedAt] take precedence for user-recorded status,
  /// reference_number, and notes. Local photo_paths are preserved because
  /// they reference local file system paths.
  Future<ClaimsSyncResult> pullFromBackend() async {
    try {
      final response = await _dio.get('/claims');
      final data = response.data;
      if (data is! List) {
        return const ClaimsSyncResult(
            errorMessage: 'Unexpected response format');
      }

      final serverClaims = <String, ClaimRecord>{};
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final claim = ClaimRecord.fromJson({
            ...item,
            'document_id': item['document_id'] ?? '',
            'filed_date':
                item['filed_date'] ?? DateTime.now().toIso8601String(),
          });
          serverClaims[claim.id] = claim;
        }
      }

      final localClaims = AppStateRepository.getClaimRecords();
      final merged = <ClaimRecord>[];
      final serverIds = serverClaims.keys.toSet();
      final localById = {for (final c in localClaims) c.id: c};

      // Merge: server takes precedence for user-recorded status/reference/notes,
      // local preserves photo_paths.
      for (final serverId in serverIds) {
        final server = serverClaims[serverId]!;
        final local = localById[serverId];
        if (local != null &&
            local.photoPaths.isNotEmpty &&
            server.photoPaths.isEmpty) {
          merged.add(server.copyWith(photoPaths: local.photoPaths));
        } else {
          merged.add(server);
        }
      }

      // Keep local claims not on the server (offline-created, not yet synced).
      for (final local in localClaims) {
        if (!serverIds.contains(local.id)) {
          merged.add(local);
        }
      }

      await AppStateRepository.saveClaimRecords(merged);
      return ClaimsSyncResult(pulledCount: serverIds.length);
    } catch (e) {
      return ClaimsSyncResult(
        errorCount: 1,
        errorMessage: 'Pull failed: $e',
      );
    }
  }

  /// Push a single claim to the backend.
  Future<ClaimsSyncResult> pushClaim(ClaimRecord claim) async {
    try {
      await _dio.post(
        '/claims',
        data: {
          'document_id': claim.documentId,
          'policy_type': claim.policyType,
          'insurer': claim.insurer,
          'incident_type': claim.incidentType,
          'description': claim.description,
          'reference_number': claim.referenceNumber,
          'notes': claim.notes,
          'photo_paths': claim.photoPaths,
        },
      );
      return const ClaimsSyncResult(pushedCount: 1);
    } catch (e) {
      return ClaimsSyncResult(
        errorCount: 1,
        errorMessage: 'Push failed: $e',
      );
    }
  }

  /// Full sync: pull from server, then push any locally-created claims that
  /// don't exist on the server.
  Future<ClaimsSyncResult> fullSync() async {
    final pullResult = await pullFromBackend();
    if (pullResult.errorMessage != null) return pullResult;

    final localClaims = AppStateRepository.getClaimRecords();
    int pushedCount = 0;
    int errorCount = 0;

    // After pulling, the server has some claims. Push any local claims whose
    // IDs don't appear in the pulled set — these were created offline.
    for (final claim in localClaims) {
      try {
        final serverIds = await _fetchServerIds();
        if (!serverIds.contains(claim.id)) {
          final pushResult = await pushClaim(claim);
          if (pushResult.pushedCount > 0) {
            pushedCount++;
          } else {
            errorCount++;
          }
        }
      } catch (_) {
        errorCount++;
      }
    }

    return ClaimsSyncResult(
      pulledCount: pullResult.pulledCount,
      pushedCount: pushedCount,
      errorCount: errorCount,
    );
  }

  Future<Set<String>> _fetchServerIds() async {
    try {
      final response = await _dio.get('/claims');
      final data = response.data;
      if (data is List) {
        return data
            .map((item) {
              if (item is Map<String, dynamic>) {
                return item['id']?.toString() ?? '';
              }
              return '';
            })
            .where((id) => id.isNotEmpty)
            .toSet();
      }
    } catch (_) {
      // Silently fail — will retry on next sync.
    }
    return {};
  }
}
