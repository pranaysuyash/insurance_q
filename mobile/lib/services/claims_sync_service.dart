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
import 'package:flutter/foundation.dart';
import '../models/claim_record.dart';
import '../services/app_state_repository.dart';
import '../services/document_service.dart';

/// P0.9: Typed result for server claim index fetch — distinguishes
/// "server has no claims" from "server is unreachable".
sealed class ServerClaimIndexResult {
  const ServerClaimIndexResult();
}

class ServerClaimIndexLoaded extends ServerClaimIndexResult {
  final Set<String> ids;
  const ServerClaimIndexLoaded(this.ids);
}

class ServerClaimIndexUnavailable extends ServerClaimIndexResult {
  const ServerClaimIndexUnavailable();
}

/// Audit 5 P1.14: Explicit completion status for sync operations.
/// Replaces the ambiguous `isSuccess` getter which could treat
/// `errorCount: 5, errorMessage: null` as success.
enum SyncCompletion {
  /// All operations completed without errors.
  complete,

  /// Some operations succeeded, some failed. Partial results available.
  partial,

  /// Operation failed entirely or was aborted (epoch stale, server unreachable).
  failed,
}

/// Result of a sync operation for diagnostics and UI feedback.
class ClaimsSyncResult {
  final int pulledCount;
  final int pushedCount;
  final int errorCount;
  final String? errorMessage;

  /// Audit 5 P1.14: Explicit completion status. Callers should switch
  /// on [completion] rather than checking [isSuccess] or [errorMessage].
  final SyncCompletion completion;

  const ClaimsSyncResult({
    this.pulledCount = 0,
    this.pushedCount = 0,
    this.errorCount = 0,
    this.errorMessage,
    this.completion = SyncCompletion.complete,
  });

  /// Backward-compatible getter. Prefer switching on [completion].
  bool get isSuccess => completion == SyncCompletion.complete;
}

class ClaimsSyncService {
  final Dio _dio;
  ClaimsSyncService(this._dio);

  /// Reuses the existing [DocumentService.authenticatedDio] which already
  /// has AuthInterceptor wired in. No need to create a separate Dio instance
  /// with a duplicate AuthInterceptor.
  static Dio get authenticatedDio => DocumentService.authenticatedDio;

  // ── Epoch protection (Audit 5 P0.10) ───────────────────────────────
  // ClaimsSyncService maintains its own epoch, independent of
  // DocumentService. This prevents cross-principal data contamination
  // when claims sync is in-flight during a workspace transition.

  /// The epoch at which the current claims sync was initiated.
  /// Set to -1 when no sync is in-flight.
  static int _claimsSyncEpoch = -1;

  /// Public getter for the current claims sync epoch. Used by the
  /// reconciliation coordinator to verify epoch before and after mutations.
  static int get claimsSyncEpoch => _claimsSyncEpoch;

  /// Set the epoch for the current claims sync. Called by the reconciliation
  /// coordinator before initiating a sync.
  static void setClaimsSyncEpoch(int epoch) {
    _claimsSyncEpoch = epoch;
  }

  /// Invalidate any in-flight claims sync by bumping the epoch to an
  /// impossible value. Called by the reconciliation coordinator during
  /// workspace transitions to prevent stale claims from being pushed.
  static void invalidateClaimsSync() {
    _claimsSyncEpoch = -1;
  }

  /// Pull claims from the backend and merge into local storage.
  ///
  /// The most recently updated record wins for each field. Local photo_paths
  /// are preserved because they reference local file system paths.
  ///
  /// Audit 5 P0.10: [epoch] is checked before writing to Hive to prevent
  /// cross-principal data contamination if a workspace transition happened
  /// during the network call.
  ///
  /// Audit 5 P0.10 (claim contracts): Conflict resolution now uses
  /// timestamps. Server takes precedence only when its updatedAt is
  /// >= local updatedAt. This prevents older server data from overriding
  /// newer local edits.
  ///
  /// Audit 5 P0.11 (tombstones): Local claims absent from the server
  /// snapshot are removed only when the server response is authoritative
  /// (full list, not a partial page). A local claim that has never been
  /// uploaded (no referenceNumber) is preserved.
  Future<ClaimsSyncResult> pullFromBackend({int? epoch}) async {
    try {
      // CW-P0-003 Fix 3: Paginate through all pages to get a complete
      // server snapshot. Without pagination, users with >50 claims would
      // only see the first page and incorrectly tombstone the rest.
      const pageSize = 200;
      var offset = 0;
      const maxPages = 50;
      var page = 0;

      final serverClaims = <String, ClaimRecord>{};

      while (page < maxPages) {
        final response = await _dio.get(
          '/claims',
          queryParameters: {
            'limit': pageSize,
            'offset': offset,
          },
        );
        final data = response.data;
        if (data is! List || data.isEmpty) break;
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final claim = ClaimRecord.fromJson({
              ...item,
              'document_id': item['document_id'] ?? '',
              'filed_date':
                  item['filed_date'] ?? DateTime.now().toIso8601String(),
              // Audit 6 P0.5: Server claims arrive already synced.
              'sync_state': 'synced',
            });
            serverClaims[claim.id] = claim;
          }
        }
        if (data.length < pageSize) break;
        offset += pageSize;
        page++;
      }

      // Audit 5 P0.10: Check epoch AFTER the network call but BEFORE
      // writing to Hive. If a workspace transition happened during the
      // pull, discard the server response to prevent cross-principal
      // data contamination.
      if (epoch != null && _claimsSyncEpoch != epoch) {
        return ClaimsSyncResult(
          errorCount: 1,
          errorMessage: 'Principal epoch changed during pull; discarding server response',
          completion: SyncCompletion.failed,
        );
      }

      final localClaims = AppStateRepository.getClaimRecords();
      final merged = <ClaimRecord>[];
      final serverIds = serverClaims.keys.toSet();
      final localById = {for (final c in localClaims) c.id: c};

      // Merge: most recently updated record wins for each claim.
      // Local photo_paths are always preserved (server doesn't have them).
      for (final serverId in serverIds) {
        final server = serverClaims[serverId]!;
        final local = localById[serverId];
        if (local == null) {
          // Server-only claim (created on another device).
          merged.add(server);
        } else {
          // Both exist — pick the most recently updated.
          // Audit 6 P0.5: Uses the new updatedAt field for conflict resolution
          // instead of filedDate as a proxy. This is accurate because edits
          // to status/notes now update updatedAt.
          // Version precedence is purely timestamp-based — syncState tracks
          // whether re-push is needed, not which version is authoritative.
          final serverTime = server.updatedAt;
          final localTime = local.updatedAt;
          if (localTime.isAfter(serverTime)) {
            // Local is newer — keep local content but adopt server's
            // remoteId if present.
            merged.add(local.copyWith(
              remoteId: server.remoteId ?? local.remoteId,
            ));
          } else {
            // Server is newer or equal — take server but preserve local
            // photo_paths (server doesn't have filesystem paths).
            merged.add(server.copyWith(
              photoPaths: local.photoPaths.isNotEmpty
                  ? local.photoPaths
                  : server.photoPaths,
              // Preserve local syncState if it has pending local edits.
              syncState: local.syncState == ClaimSyncState.modified
                  ? ClaimSyncState.modified
                  : ClaimSyncState.synced,
            ));
          }
        }
      }

      // Audit 5 P0.11 (tombstones): Remove local claims that were
      // previously synced but are absent from the server snapshot.
      // Audit 6 P0.5: Uses the dedicated syncState field instead of the
      // referenceNumber heuristic.
      for (final local in localClaims) {
        if (!serverIds.contains(local.id)) {
          final wasSynced = local.syncState == ClaimSyncState.synced ||
              local.syncState == ClaimSyncState.modified;
          if (wasSynced) {
            // This claim was synced to the server but is no longer there.
            // Server deletion is authoritative — remove locally.
          } else {
            // Never synced — preserve for future push.
            merged.add(local);
          }
        }
      }

      await AppStateRepository.replaceClaimRecords(merged);
      return ClaimsSyncResult(
        pulledCount: serverIds.length,
        completion: SyncCompletion.complete,
      );
    } catch (e) {
      return ClaimsSyncResult(
        errorCount: 1,
        errorMessage: 'Pull failed: $e',
        completion: SyncCompletion.failed,
      );
    }
  }

  /// Push a single claim to the backend.
  ///
  /// P0.7: Local file-system paths are never sent to the server — they leak
  /// device information and are not useful server-side.
  ///
  /// 7-P0.3: The server ID is NOT stored in [ClaimRecord.referenceNumber].
  /// That field is user-visible insurer data (e.g. 'CLM-2026-00421') and
  /// must never be repurposed as an internal database identifier. If the
  /// server returns a different ID, it is logged but not persisted — the
  /// local ID remains the canonical reference for the claim organizer.
  Future<ClaimsSyncResult> pushClaim(ClaimRecord claim) async {
    try {
      // CW-P0-003 Fix 1: Do NOT send 'id' in the POST body.
      // The backend CreateClaimRequest has extra="forbid" and generates
      // its own UUID. Sending a client ID causes HTTP 422.
      final response = await _dio.post(
        '/claims',
        data: {
          'document_id': claim.documentId,
          'policy_type': claim.policyType,
          'insurer': claim.insurer,
          'incident_type': claim.incidentType,
          'description': claim.description,
          'reference_number': claim.referenceNumber,
          'notes': claim.notes,
        },
      );
      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        final serverRemoteId = responseData['id']?.toString();
        if (serverRemoteId != null && serverRemoteId != claim.id) {
          // 7-P0.3: Log the server ID but do NOT overwrite referenceNumber.
          // Audit 6 P0.5: Store the server ID in the dedicated remoteId field.
          debugPrint(
            'ClaimsSyncService: server returned remoteId=$serverRemoteId '
            'for local claim ${claim.id}',
          );
        }
        // Audit 6 P0.5: Update the claim's syncState and remoteId after
        // successful push. This replaces the old referenceNumber heuristic.
        final updatedClaim = claim.copyWith(
          remoteId: serverRemoteId ?? claim.remoteId,
          syncState: ClaimSyncState.synced,
          updatedAt: DateTime.now(),
        );
        await AppStateRepository.updateClaimRecord(updatedClaim);
      }
      return const ClaimsSyncResult(
        pushedCount: 1,
        completion: SyncCompletion.complete,
      );
    } catch (e) {
      return ClaimsSyncResult(
        errorCount: 1,
        errorMessage: 'Push failed: $e',
        completion: SyncCompletion.failed,
      );
    }
  }  /// Patch a modified claim on the backend.
  ///
  /// CW-P0-003 Fix 2: Send PATCH for claims with [ClaimSyncState.modified]
  /// so that local status/notes edits are pushed to the server.
  /// Only sends fields that the backend [UpdateClaimRequest] accepts:
  /// status, reference_number, notes.
  Future<ClaimsSyncResult> patchClaim(ClaimRecord claim) async {
    try {
      final remoteId = claim.remoteId ?? claim.id;
      // Build the update payload — only fields accepted by UpdateClaimRequest.
      final data = <String, dynamic>{};
      data['status'] = claim.status.wireValue;
      if (claim.referenceNumber != null) {
        data['reference_number'] = claim.referenceNumber;
      }
      if (claim.notes != null) {
        data['notes'] = claim.notes;
      }
      await _dio.patch('/claims/$remoteId', data: data);
      // Mark as synced after successful PATCH.
      final updatedClaim = claim.copyWith(
        syncState: ClaimSyncState.synced,
        updatedAt: DateTime.now(),
      );
      await AppStateRepository.updateClaimRecord(updatedClaim);
      return const ClaimsSyncResult(
        pushedCount: 1,
        completion: SyncCompletion.complete,
      );
    } catch (e) {
      return ClaimsSyncResult(
        errorCount: 1,
        errorMessage: 'PATCH failed: $e',
        completion: SyncCompletion.failed,
      );
    }
  }

  /// Full sync: pull from server, then push new claims and patch modified ones.
  ///
  /// P0.9: If the server index is unavailable, no pushes are attempted —
  /// an unknown server state must not be treated as empty.
  ///
  /// P0.8: The server index is fetched once before the push loop to avoid
  /// redundant network reads inside the loop (N+1 problem).
  ///
  /// CW-P0-003 Fix 2: After pushing new claims, PATCH any claims with
  /// [ClaimSyncState.modified] so local edits are synced to the server.
  ///
  /// Audit 5 P0.10: [epoch] is the principal epoch at the time the caller
  /// decided to run claims sync. The epoch is captured by the caller and
  /// verified before each mutation to prevent claims from a stale principal
  /// being pushed after a workspace transition.
  ///
  /// ClaimsSyncService uses its own epoch ([claimsSyncEpoch]), independent
  /// of DocumentService's epoch. This prevents cross-principal data
  /// contamination when claims sync is in-flight during a workspace transition.
  Future<ClaimsSyncResult> fullSync({int? epoch}) async {
    // Audit 5 P0.10: Check epoch BEFORE the pull network call to prevent
    // cross-principal data contamination. If a workspace transition
    // happened since this sync was requested, abort immediately.
    if (epoch != null) {
      final currentEpoch = _claimsSyncEpoch;
      if (currentEpoch != epoch) {
        return ClaimsSyncResult(
          errorCount: 1,
          errorMessage: 'Principal epoch stale at sync start; aborting',
          completion: SyncCompletion.failed,
        );
      }
    }
    try {
      final pullResult = await pullFromBackend(epoch: epoch);
      if (pullResult.completion == SyncCompletion.failed) return pullResult;

      final localClaims = AppStateRepository.getClaimRecords();
      int pushedCount = 0;
      int patchedCount = 0;
      int errorCount = 0;

      // P0.8: Fetch the authoritative server index once, not per claim.
      final indexResult = await _fetchServerIds();
      if (indexResult is ServerClaimIndexUnavailable) {
        // P0.9: Server unreachable — do NOT push (we can't know what's there).
        return ClaimsSyncResult(
          pulledCount: pullResult.pulledCount,
          errorMessage: 'Server claim index unavailable; push deferred',
          completion: SyncCompletion.failed,
        );
      }
      final serverIds = (indexResult as ServerClaimIndexLoaded).ids;

      for (final claim in localClaims) {
        // Audit 5 P0.10: Check epoch before each push/patch to prevent claims
        // from a stale principal being pushed after a workspace transition.
        if (epoch != null && _claimsSyncEpoch != epoch) {
          return ClaimsSyncResult(
            pulledCount: pullResult.pulledCount,
            pushedCount: pushedCount,
            errorCount: errorCount + 1,
            errorMessage: 'Principal epoch changed during sync; partial sync',
            completion: SyncCompletion.partial,
          );
        }

        if (serverIds.contains(claim.id)) {
          // CW-P0-003 Fix 2: Claim exists on server — if locally modified,
          // send a PATCH to push local edits (status/notes) upstream.
          if (claim.syncState == ClaimSyncState.modified) {
            try {
              final patchResult = await patchClaim(claim);
              if (patchResult.pushedCount > 0) {
                patchedCount++;
              } else {
                errorCount++;
              }
            } catch (_) {
              errorCount++;
            }
          }
        } else {
          // Claim not on server — push as new.
          try {
            final pushResult = await pushClaim(claim);
            if (pushResult.pushedCount > 0) {
              pushedCount++;
            } else {
              errorCount++;
            }
          } catch (_) {
            errorCount++;
          }
        }
      }

      return ClaimsSyncResult(
        pulledCount: pullResult.pulledCount,
        pushedCount: pushedCount + patchedCount,
        errorCount: errorCount,
        completion:
            errorCount > 0 ? SyncCompletion.partial : SyncCompletion.complete,
      );
    } finally {
      // Audit 5 P0.10: Reset epoch after completion to prevent stale
      // epoch from persisting across calls.
      _claimsSyncEpoch = -1;
    }
  }

  /// P0.9: Return a typed result so callers can distinguish "server has no
  /// claims" from "server is unreachable". An empty set from a network
  /// failure must never be treated as an authoritative empty server state.
  ///
  /// CW-P0-003 Fix 3: Paginate through all pages to build a complete server
  /// index. Without pagination, users with >50 claims would have an incomplete
  /// index, causing valid server claims to be re-pushed as duplicates.
  ///
  /// The backend defaults to 50 records per request with limit/offset params.
  Future<ServerClaimIndexResult> _fetchServerIds() async {
    try {
      final ids = <String>{};
      const pageSize = 200; // Backend max is 200.
      var offset = 0;

      // CW-P0-003: Safety bound — never paginate beyond 50 pages (10k claims).
      // A user with >10k claims is an extraordinary edge case; capping prevents
      // infinite loops if the backend ignores offset or returns stale data.
      const maxPages = 50;
      var page = 0;

      while (page < maxPages) {
        final response = await _dio.get(
          '/claims',
          queryParameters: {
            'limit': pageSize,
            'offset': offset,
          },
        );
        final data = response.data;
        if (data is! List || data.isEmpty) {
          // Empty page or unexpected format — we have all data.
          break;
        }
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) ids.add(id);
          }
        }
        // If the page returned fewer than pageSize, we've reached the end.
        if (data.length < pageSize) break;
        offset += pageSize;
        page++;
      }

      // 7-P0.10: Even an empty set is treated as loaded (authoritative empty)
      // because we paginated through all pages. Only a network error or
      // malformed response returns ServerClaimIndexUnavailable.
      return ServerClaimIndexLoaded(ids);
    } catch (_) {
      return ServerClaimIndexUnavailable();
    }
  }
}
