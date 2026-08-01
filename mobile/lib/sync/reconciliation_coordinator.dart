import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/identity.dart';
import '../services/auth_service.dart';
import '../providers/document_providers.dart';
import '../services/analytics_service.dart';
import '../services/claims_sync_service.dart';
import '../services/document_service.dart';
import '../services/hive_workspace_service.dart';
import '../services/principal_key_service.dart';

/// Coordinates reconciliation (upload retry + claims sync) and workspace
/// transitions for authenticated sessions.
///
/// Extracted from `_InsuranceAppState` to reduce app.dart from ~727 lines
/// and isolate the reconciliation/transition logic into a testable unit.
///
/// The coordinator owns:
/// - Principal epoch tracking (stale-transition rejection)
/// - Debounced reconciliation scheduling
/// - Epoch-gated upload retry and claims sync
/// - Authenticated session transitions (workspace reopen + claim)
class ReconciliationCoordinator {
  ReconciliationCoordinator({
    required this.ref,
    this.mounted = true,
  });

  /// Riverpod ref for reading providers and invalidating state.
  final WidgetRef ref;

  /// Whether the owning widget is still mounted. Used to guard
  /// ref.invalidate() calls that would fail if the widget is disposed.
  bool mounted;

  /// The workspace principal that is currently being transitioned to.
  WorkspacePrincipal? _desiredPrincipal;

  /// Monotonically increasing epoch for each principal change. Used to
  /// discard stale reconciliation results after a newer transition.
  int _principalEpoch = 0;

  /// Debounce timer for reconciliation jobs. When multiple triggers
  /// fire in quick succession, only the last one within the debounce
  /// window executes.
  Timer? _reconciliationDebounce;

  /// Debounce duration for reconciliation triggers.
  static const Duration _reconciliationDebounceDuration = Duration(seconds: 2);

  /// Lightweight instrumentation counter. Increments each time the debounce
  /// timer fires and executes reconciliation work. Exposed for test assertions
  /// that need to verify debounce coalescing (e.g. '3 calls → 1 fire').
  int reconciliationFireCount = 0;

  /// The current principal epoch. Read-only for external callers that need
  /// to pass epoch values for stale-rejection checks.
  int get principalEpoch => _principalEpoch;

  /// The currently desired principal. Read-only for stale-transition checks.
  WorkspacePrincipal? get desiredPrincipal => _desiredPrincipal;

  /// Dispose the debounce timer and mark as unmounted. Call from the
  /// widget's dispose() method.
  void dispose() {
    mounted = false;
    _reconciliationDebounce?.cancel();
  }

  // ── Reconciliation ──────────────────────────────────────────────────

  /// Debounced reconciliation scheduler. Cancels any pending
  /// reconciliation and schedules a new one after [debounceDuration].
  /// This coalesces burst triggers (auth + connectivity + init) into a
  /// single sync cycle, preventing duplicate uploads and rate-limit pressure.
  void scheduleReconciliation({int? epoch}) {
    _reconciliationDebounce?.cancel();
    _reconciliationDebounce = Timer(_reconciliationDebounceDuration, () {
      reconciliationFireCount++;
      unawaited(_retryPendingUploads(epoch: epoch));
      unawaited(_syncClaims(epoch: epoch));
    });
  }

  /// Epoch-gated upload reconciliation. Stale requests are discarded
  /// both before and after the work to prevent cross-principal data corruption.
  Future<void> _retryPendingUploads({int? epoch}) async {
    final e = epoch ?? _principalEpoch;
    if (e != _principalEpoch) return;
    try {
      await DocumentService(DocumentService.authenticatedDio)
          .retryPendingUploads(epoch: e);
      if (mounted && e == _principalEpoch) {
        ref.invalidate(documentsProvider);
      }
    } catch (error, stackTrace) {
      debugPrint('Pending upload reconciliation failed: $error');
      Sentry.captureException(error, stackTrace: stackTrace);
    }
  }

  /// Epoch-gated claims sync. Stale requests are discarded both
  /// before and after the work.
  ///
  /// Audit 5 P0.10: ClaimsSyncService uses its own epoch, independent
  /// of DocumentService. The coordinator sets the epoch before initiating
  /// the sync and the service verifies it before each mutation.
  Future<void> _syncClaims({int? epoch}) async {
    final e = epoch ?? _principalEpoch;
    if (e != _principalEpoch) return;
    try {
      // Set the claims sync epoch before initiating the sync.
      ClaimsSyncService.setClaimsSyncEpoch(e);
      final syncService = ClaimsSyncService(ClaimsSyncService.authenticatedDio);
      final result = await syncService.fullSync(epoch: e);
      if (result.errorMessage != null) {
        debugPrint('Claims sync failed: ${result.errorMessage}');
        Sentry.captureMessage(
          'Claims sync failed: ${result.errorMessage}',
          level: SentryLevel.warning,
        );
      }
    } catch (error) {
      debugPrint('Claims sync error: $error');
      Sentry.captureException(error);
    }
  }

  // ── Workspace transitions ───────────────────────────────────────────

  /// Handle an authenticated session transition (sign-in or sign-out).
  /// Epoch-gated: if a newer transition has been requested since this
  /// one started, the workspace reopen is skipped.
  Future<void> handleAuthenticatedSessionTransition(
    WorkspacePrincipal principal, {
    bool preserveCurrentWorkspace = false,
    required int principalEpoch,
  }) async {
    if (principalEpoch != _principalEpoch ||
        _desiredPrincipal != principal) {
      return;
    }

    try {
      await _reopenWorkspaceForPrincipal(
        principal,
        preserveCurrentWorkspace: preserveCurrentWorkspace,
      );
    } catch (error, stackTrace) {
      debugPrint('Workspace transition failed (epoch $principalEpoch): $error');
      Sentry.captureException(error, stackTrace: stackTrace);
      return;
    }

    if (!preserveCurrentWorkspace) return;

    if (principalEpoch != _principalEpoch ||
        _desiredPrincipal != principal) {
      return;
    }
    try {
      await ref.read(authServiceProvider.notifier).claimAnonymousData();
    } catch (error, stackTrace) {
      debugPrint(
          'Anonymous workspace claim failed after auth transition: $error');
      Sentry.captureException(error, stackTrace: stackTrace);
    }
  }

  /// Prepare and execute a workspace transition for the given principal.
  /// Bumps the epoch, sets the desired principal, and reopens the workspace.
  /// Returns the new epoch for callers that need to pass it to
  /// [handleAuthenticatedSessionTransition].
  int prepareTransition(WorkspacePrincipal principal) {
    _desiredPrincipal = principal;
    _principalEpoch++;
    // Audit 5 P0.4: Invalidate any in-flight pending-upload sync from the
    // previous principal so it cannot write documents into the new workspace.
    DocumentService.invalidatePendingUploadSync();
    // Audit 5 P0.10: Invalidate any in-flight claims sync from the
    // previous principal so it cannot write claims into the new workspace.
    ClaimsSyncService.invalidateClaimsSync();
    // CW-P0-011: Invalidate analytics epoch so any in-flight analytics
    // upload from the previous principal is cancelled. This prevents
    // stale events from being sent under the new identity.
    AnalyticsNotifier.invalidateEpoch();
    return _principalEpoch;
  }

  /// Clear the key and prepare a local-only transition for sign-out.
  void prepareSignOut() {
    PrincipalKeyService().clearKey();
  }

  /// Reopen the workspace for the given principal, resetting analytics
  /// identity if the principal has changed.
  ///
  /// Audit 4 P0.2+P0.3: The workspace switch (Hive box close/reopen)
  /// MUST happen before analytics reset so that consent is read from the
  /// NEW workspace's consent ledger, not the old one.
  Future<void> _reopenWorkspaceForPrincipal(
    WorkspacePrincipal principal, {
    bool preserveCurrentWorkspace = false,
  }) async {
    if (PrincipalKeyService().principalId == principal.principalId) {
      return;
    }
    // 1. Switch to the new principal's workspace first. This closes the
    //    old consent ledger box and opens the new one.
    await HiveWorkspaceService.resetForPrincipal(
      principal,
      preserveCurrentWorkspace: preserveCurrentWorkspace,
    );
    // 2. NOW reset analytics — consent is read from the NEW workspace's
    //    ledger, so the identity epoch, consent state, and buffered
    //    events all belong to the correct principal.
    ref.read(analyticsServiceProvider.notifier).resetForWorkspace();
  }

  /// Check whether a transition is still current (not superseded by a newer one).
  bool isTransitionCurrent(int epoch, WorkspacePrincipal principal) {
    return epoch == _principalEpoch && _desiredPrincipal == principal;
  }
}
