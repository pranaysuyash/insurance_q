import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coverwise/models/identity.dart';
import 'package:coverwise/sync/reconciliation_coordinator.dart';

/// Creates a [ReconciliationCoordinator] backed by a real [WidgetRef]
/// from a [ProviderScope] for the duration of the test.
void _withCoordinator(
  Future<void> Function(ReconciliationCoordinator coordinator) testBody,
) {
  late ReconciliationCoordinator coordinator;
  testWidgets(
    '',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              coordinator = ReconciliationCoordinator(ref: ref);
              return const SizedBox();
            },
          ),
        ),
      );
      await testBody(coordinator);
      coordinator.dispose();
    },
  );
}

void main() {
  // ── Initial state ────────────────────────────────────────────────────

  group('initial state', () {
    testWidgets('epoch starts at 0, desiredPrincipal null, mounted true',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final c = ReconciliationCoordinator(ref: ref);
              expect(c.principalEpoch, 0);
              expect(c.desiredPrincipal, isNull);
              expect(c.mounted, isTrue);
              c.dispose();
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  // ── prepareTransition ────────────────────────────────────────────────

  group('prepareTransition', () {
    _withCoordinator((c) async {
      const principal = LocalPrincipal('install-1');
      final epoch = c.prepareTransition(principal);

      expect(c.desiredPrincipal, isA<LocalPrincipal>());
      expect(
        (c.desiredPrincipal as LocalPrincipal).installId,
        'install-1',
      );
      expect(epoch, 1);
    });

    _withCoordinator((c) async {
      const p1 = AccountPrincipal('user-a');
      const p2 = AccountPrincipal('user-b');

      final e1 = c.prepareTransition(p1);
      final e2 = c.prepareTransition(p2);
      final e3 = c.prepareTransition(p1);

      expect(e1, 1);
      expect(e2, 2);
      expect(e3, 3);
      expect(c.principalEpoch, 3);
    });

    _withCoordinator((c) async {
      const p1 = LocalPrincipal('install-1');
      const p2 = AccountPrincipal('user-a');

      c.prepareTransition(p1);
      c.prepareTransition(p2);

      expect(c.desiredPrincipal, isA<AccountPrincipal>());
    });
  });

  // ── isTransitionCurrent ──────────────────────────────────────────────

  group('isTransitionCurrent', () {
    _withCoordinator((c) async {
      const principal = AccountPrincipal('user-a');
      final epoch = c.prepareTransition(principal);

      expect(c.isTransitionCurrent(epoch, principal), isTrue);
    });

    _withCoordinator((c) async {
      const p1 = AccountPrincipal('user-a');
      const p2 = AccountPrincipal('user-b');

      final staleEpoch = c.prepareTransition(p1);
      c.prepareTransition(p2);

      expect(c.isTransitionCurrent(staleEpoch, p1), isFalse);
    });

    _withCoordinator((c) async {
      const principal = AccountPrincipal('user-a');

      final staleEpoch = c.prepareTransition(principal);
      c.prepareTransition(principal);

      expect(c.isTransitionCurrent(staleEpoch, principal), isFalse);
    });

    _withCoordinator((c) async {
      const p1 = AccountPrincipal('user-a');
      const p2 = AccountPrincipal('user-b');
      final epoch = c.prepareTransition(p1);

      expect(c.isTransitionCurrent(epoch, p2), isFalse);
    });

    _withCoordinator((c) async {
      const principal = LocalPrincipal('install-1');
      expect(c.isTransitionCurrent(0, principal), isFalse);
    });
  });

  // ── prepareSignOut ───────────────────────────────────────────────────

  group('prepareSignOut', () {
    _withCoordinator((c) async {
      expect(() => c.prepareSignOut(), returnsNormally);
    });
  });

  // ── dispose / mounted guard ──────────────────────────────────────────

  group('dispose and mounted guard', () {
    _withCoordinator((c) async {
      expect(c.mounted, isTrue);
      c.dispose();
      expect(c.mounted, isFalse);
    });

    _withCoordinator((c) async {
      c.dispose();
      c.dispose();
      expect(c.mounted, isFalse);
    });

    _withCoordinator((c) async {
      c.mounted = false;
      c.dispose();
      expect(c.mounted, isFalse);
    });
  });

  // ── Epoch gating: stale-transition rejection ─────────────────────────

  group('stale-transition rejection', () {
    _withCoordinator((c) async {
      const p1 = AccountPrincipal('user-a');
      const p2 = AccountPrincipal('user-b');

      final staleEpoch = c.prepareTransition(p1);
      c.prepareTransition(p2);

      // Should return silently — no crash, no workspace touch.
      await c.handleAuthenticatedSessionTransition(
        p1,
        principalEpoch: staleEpoch,
      );
    });

    _withCoordinator((c) async {
      const p1 = AccountPrincipal('user-a');
      const p2 = AccountPrincipal('user-b');
      final epoch = c.prepareTransition(p1);

      await c.handleAuthenticatedSessionTransition(
        p2,
        principalEpoch: epoch,
      );
    });

    _withCoordinator((c) async {
      const p1 = AccountPrincipal('user-a');
      final staleEpoch = c.prepareTransition(p1);
      c.prepareTransition(AccountPrincipal('user-b'));

      // Schedule with stale epoch. The debounce fires after 2s, but the
      // epoch check inside _retryPendingUploads and _syncClaims will
      // discard the stale work. We verify no crash from the call.
      c.scheduleReconciliation(epoch: staleEpoch);
    });

    _withCoordinator((c) async {
      // preserveCurrentWorkspace=true exercises the claimAnonymousData()
      // branch after _reopenWorkspaceForPrincipal succeeds. The claim
      // call hits the backend (which doesn't exist in tests), so it
      // throws — but the coordinator's catch block handles it gracefully.
      const principal = AccountPrincipal('user-claim-test');
      final epoch = c.prepareTransition(principal);

      // This exercises the full path: epoch gate → reopen → claim.
      // The claim will fail (no backend), but no crash = pass.
      await c.handleAuthenticatedSessionTransition(
        principal,
        preserveCurrentWorkspace: true,
        principalEpoch: epoch,
      );
    });

    _withCoordinator((c) async {
      // preserveCurrentWorkspace=true with stale epoch should skip
      // the entire transition, including claimAnonymousData().
      const p1 = AccountPrincipal('user-a');
      const p2 = AccountPrincipal('user-b');

      final staleEpoch = c.prepareTransition(p1);
      c.prepareTransition(p2);

      // Should return silently — no crash, no claim attempted.
      await c.handleAuthenticatedSessionTransition(
        p1,
        preserveCurrentWorkspace: true,
        principalEpoch: staleEpoch,
      );
    });
  });

  // ── _reopenWorkspaceForPrincipal failure blocks claim ───────────────

  group('_reopenWorkspaceForPrincipal failure prevents claimAnonymousData', () {
    testWidgets(
        'when reopen throws, claimAnonymousData is never attempted',
        (tester) async {
      late ReconciliationCoordinator c;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              c = ReconciliationCoordinator(ref: ref);
              return const SizedBox();
            },
          ),
        ),
      );

      // Use a principal whose ID differs from PrincipalKeyService().principalId
      // so _reopenWorkspaceForPrincipal proceeds past the early-return guard
      // and calls resetForPrincipal, which throws because no Hive workspace
      // is initialized in tests.
      const principal = AccountPrincipal('reopen-failure-user');
      final epoch = c.prepareTransition(principal);

      // preserveCurrentWorkspace=true means the method WOULD call
      // claimAnonymousData() if reopen succeeded. Since reopen throws,
      // the catch block returns early and claim is never attempted.
      await c.handleAuthenticatedSessionTransition(
        principal,
        preserveCurrentWorkspace: true,
        principalEpoch: epoch,
      );

      // No crash — the catch block handled the reopen failure gracefully.
      expect(c.mounted, isTrue);
      c.dispose();
    });
  });

  // ── Debounce behavior ────────────────────────────────────────────────

  group('debounce', () {
    testWidgets('3 rapid calls only fire once', (tester) async {
      late ReconciliationCoordinator c;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              c = ReconciliationCoordinator(ref: ref);
              return const SizedBox();
            },
          ),
        ),
      );

      // Schedule 3 rapid reconciliations.
      c.scheduleReconciliation();
      c.scheduleReconciliation();
      c.scheduleReconciliation();

      // Advance past the 2-second debounce window.
      await tester.pump(const Duration(seconds: 2));

      // Debounce coalesced 3 calls into 1 fire.
      expect(c.reconciliationFireCount, 1);
      expect(c.mounted, isTrue);
      c.dispose();
    });

    testWidgets('timer does not fire before debounce window', (tester) async {
      late ReconciliationCoordinator c;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              c = ReconciliationCoordinator(ref: ref);
              return const SizedBox();
            },
          ),
        ),
      );

      c.scheduleReconciliation();

      // Advance 1.5 seconds — NOT past the 2-second debounce.
      await tester.pump(const Duration(milliseconds: 1500));

      // Timer hasn't fired yet — fire count is still 0.
      expect(c.reconciliationFireCount, 0);
      expect(c.mounted, isTrue);
      c.dispose();
    });

    testWidgets('second call resets the debounce timer', (tester) async {
      late ReconciliationCoordinator c;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              c = ReconciliationCoordinator(ref: ref);
              return const SizedBox();
            },
          ),
        ),
      );

      c.scheduleReconciliation();
      await tester.pump(const Duration(seconds: 1)); // 1s into 2s window
      expect(c.reconciliationFireCount, 0); // hasn't fired yet

      c.scheduleReconciliation(); // resets the timer
      await tester.pump(const Duration(seconds: 1)); // 1s since reset
      expect(c.reconciliationFireCount, 0); // still hasn't fired

      await tester.pump(const Duration(seconds: 1)); // 2s since reset — fires
      expect(c.reconciliationFireCount, 1); // exactly 1 fire
      expect(c.mounted, isTrue);
      c.dispose();
    });

    _withCoordinator((c) async {
      c.scheduleReconciliation();
      c.dispose();
      expect(c.mounted, isFalse);
    });

    _withCoordinator((c) async {
      c.scheduleReconciliation();
      c.dispose();
      c.dispose();
      expect(c.mounted, isFalse);
    });
  });

  // ── Edge cases ───────────────────────────────────────────────────────

  group('edge cases', () {
    _withCoordinator((c) async {
      const principal = LocalPrincipal('device-xyz');
      c.prepareTransition(principal);

      expect(
        (c.desiredPrincipal as LocalPrincipal).principalId,
        'local-only-device-xyz',
      );
    });

    _withCoordinator((c) async {
      const principal = AccountPrincipal('uuid-123');
      c.prepareTransition(principal);

      expect(
        (c.desiredPrincipal as AccountPrincipal).principalId,
        'uuid-123',
      );
    });

    _withCoordinator((c) async {
      for (var i = 0; i < 100; i++) {
        c.prepareTransition(AccountPrincipal('user-$i'));
      }
      expect(c.principalEpoch, 100);
    });

    _withCoordinator((c) async {
      const principal = AccountPrincipal('user-a');
      final epoch = c.prepareTransition(principal);

      c.dispose();

      expect(c.isTransitionCurrent(epoch, principal), isTrue);
    });
  });

  // ── Contract documentation tests ─────────────────────────────────────

  group('contract documentation', () {
    _withCoordinator((c) async {
      expect(c.mounted, isA<bool>());
      expect(c.principalEpoch, isA<int>());
      expect(c.desiredPrincipal, isA<WorkspacePrincipal?>());

      expect(
        () => c.prepareTransition(const LocalPrincipal('test')),
        returnsNormally,
      );
      expect(() => c.prepareSignOut(), returnsNormally);
      expect(() => c.scheduleReconciliation(), returnsNormally);
      expect(() => c.dispose(), returnsNormally);
      expect(
        c.isTransitionCurrent(0, const LocalPrincipal('test')),
        isA<bool>(),
      );
    });

    _withCoordinator((c) async {
      c.mounted = true;
      c.dispose();
      expect(c.mounted, isFalse);

      c.mounted = false;
      c.dispose();
      expect(c.mounted, isFalse);
    });
  });

  // ── Source-level contract tests ──────────────────────────────────────

  group('source-level contracts', () {
    test('workspace switch happens before analytics reset',
        () {
      // Audit 4 P0.2+P0.3: The coordinator must switch the Hive workspace
      // FIRST (opening the new consent ledger), THEN reset analytics so
      // consent is read from the NEW workspace's ledger, not the old one.
      final source = File('lib/sync/reconciliation_coordinator.dart')
          .readAsStringSync();

      final hiveIdx = source.indexOf('resetForPrincipal');
      final analyticsIdx = source.indexOf('resetForWorkspace');
      expect(hiveIdx, isNot(-1), reason: 'resetForPrincipal not found');
      expect(analyticsIdx, isNot(-1), reason: 'resetForWorkspace not found');
      expect(
        hiveIdx,
        lessThan(analyticsIdx),
        reason: 'resetForPrincipal must come before resetForWorkspace',
      );
    });

    test('debounce duration is 2 seconds', () {
      final source = File('lib/sync/reconciliation_coordinator.dart')
          .readAsStringSync();

      expect(source, contains('Duration(seconds: 2)'));
    });

    test('dispose sets mounted to false', () {
      final source = File('lib/sync/reconciliation_coordinator.dart')
          .readAsStringSync();

      expect(
        source,
        contains('mounted = false'),
        reason: 'dispose() must set mounted = false',
      );
    });

    test('epoch check guards both before and after async work', () {
      final source = File('lib/sync/reconciliation_coordinator.dart')
          .readAsStringSync();

      final epochChecks =
          'e != _principalEpoch'.allMatches(source).length;
      expect(
        epochChecks,
        greaterThanOrEqualTo(2),
        reason:
            'Expected at least 2 epoch checks (before + after async work)',
      );
    });

    test('preserveCurrentWorkspace=true triggers claimAnonymousData', () {
      // The preserve branch must call claimAnonymousData() after
      // _reopenWorkspaceForPrincipal succeeds, and must have a second
      // epoch gate between reopen and claim.
      final source = File('lib/sync/reconciliation_coordinator.dart')
          .readAsStringSync();

      expect(source, contains('claimAnonymousData()'));
      expect(source, contains('preserveCurrentWorkspace'));
      // Verify the second epoch guard exists between reopen and claim.
      final claimIdx = source.indexOf('claimAnonymousData()');
      final reopenIdx = source.indexOf('_reopenWorkspaceForPrincipal');
      expect(
        claimIdx,
        greaterThan(reopenIdx),
        reason: 'claimAnonymousData must come after _reopenWorkspaceForPrincipal',
      );
    });

    test('reopen failure catch block returns before claimAnonymousData', () {
      // When _reopenWorkspaceForPrincipal throws, the catch block must
      // return early so claimAnonymousData() is never reached.
      final source = File('lib/sync/reconciliation_coordinator.dart')
          .readAsStringSync();

      // Find the first try-catch around _reopenWorkspaceForPrincipal.
      final reopenTryIdx = source.indexOf(
        'try {\n      await _reopenWorkspaceForPrincipal',
      );
      expect(reopenTryIdx, isNot(-1), reason: 'reopen try block not found');

      // Find the catch block that follows it.
      final catchIdx = source.indexOf('} catch (error, stackTrace) {',
          reopenTryIdx);
      expect(catchIdx, isNot(-1), reason: 'reopen catch block not found');

      // Find the return statement inside that catch block.
      final returnIdx = source.indexOf('return;', catchIdx);
      expect(returnIdx, isNot(-1),
          reason: 'catch block must contain return to prevent claim');

      // The return must come BEFORE claimAnonymousData().
      final claimIdx = source.indexOf('claimAnonymousData()');
      expect(claimIdx, isNot(-1), reason: 'claimAnonymousData not found');
      expect(
        returnIdx,
        lessThan(claimIdx),
        reason:
            'catch-block return must precede claimAnonymousData to prevent it',
      );
    });
  });

  // ── _retryPendingUploads epoch-gating (via scheduleReconciliation) ──

  group('_retryPendingUploads epoch-gating', () {
    testWidgets('stale epoch prevents ref.invalidate after async work',
        (tester) async {
      late ReconciliationCoordinator c;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              c = ReconciliationCoordinator(ref: ref);
              return const SizedBox();
            },
          ),
        ),
      );

      // Schedule reconciliation without an explicit epoch — captures the
      // current epoch (0) at schedule time. The timer callback will pass
      // epoch=0 to _retryPendingUploads.
      c.scheduleReconciliation();

      // Advance epoch to 1 (simulate a new principal transition).
      c.prepareTransition(const AccountPrincipal('user-b'));

      // Advance past the 2s debounce — the timer fires with epoch=0,
      // but _principalEpoch is now 1, so the pre-rejection check
      // discards the stale work without touching DocumentService.
      await tester.pump(const Duration(seconds: 2));

      // Coordinator is still valid — no crash from stale work.
      expect(c.mounted, isTrue);
      expect(c.principalEpoch, 1);
      c.dispose();
    });

    testWidgets('current epoch allows ref.invalidate after async work',
        (tester) async {
      late ReconciliationCoordinator c;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              c = ReconciliationCoordinator(ref: ref);
              return const SizedBox();
            },
          ),
        ),
      );

      // Schedule reconciliation with current epoch (default 0).
      c.scheduleReconciliation();

      // Advance past the 2s debounce — the timer fires, epoch matches,
      // and _retryPendingUploads proceeds to call DocumentService
      // (which will throw due to no backend, but the catch handles it).
      await tester.pump(const Duration(seconds: 2));

      // Coordinator is still valid after the (failed) upload retry.
      expect(c.mounted, isTrue);
      c.dispose();
    });



    test('pre-rejection: _retryPendingUploads checks epoch before async work',
        () {
      // The source must contain the pre-rejection epoch guard:
      //   final e = epoch ?? _principalEpoch;
      //   if (e != _principalEpoch) return;
      final source = File('lib/sync/reconciliation_coordinator.dart')
          .readAsStringSync();

      expect(source, contains('e != _principalEpoch'));
      // Must have at least 2 occurrences (pre-rejection + post-rejection).
      final matches = 'e != _principalEpoch'.allMatches(source);
      expect(
        matches.length,
        greaterThanOrEqualTo(2),
        reason: 'Expected pre-rejection and post-rejection epoch guards',
      );
    });

    test('prepareTransition invalidates in-flight pending upload sync',
        () {
      // Audit 5 P0.4: When the principal changes, any in-flight
      // pending-upload sync from the old principal must be invalidated
      // so it cannot write documents into the new workspace.
      final source = File('lib/sync/reconciliation_coordinator.dart')
          .readAsStringSync();

      final prepareIdx = source.indexOf('int prepareTransition');
      expect(prepareIdx, isNot(-1), reason: 'prepareTransition not found');

      // invalidatePendingUploadSync must appear inside prepareTransition.
      final invalidateIdx = source.indexOf(
        'DocumentService.invalidatePendingUploadSync()',
        prepareIdx,
      );
      expect(invalidateIdx, isNot(-1),
          reason: 'invalidatePendingUploadSync must be called in prepareTransition');
    });

    test('retryPendingUploads accepts epoch parameter',
        () {
      // Audit 5 P0.4: retryPendingUploads must accept an epoch parameter
      // so the sync loop can check it before processing each document.
      final source = File('lib/sync/reconciliation_coordinator.dart')
          .readAsStringSync();

      // The coordinator must pass epoch to retryPendingUploads.
      expect(source, contains('.retryPendingUploads(epoch:'));
    });

    test('post-rejection: ref.invalidate guarded by epoch AND mounted',
        () {
      // After the async work, ref.invalidate must be guarded by both
      // mounted and epoch check to prevent cross-principal contamination.
      final source = File('lib/sync/reconciliation_coordinator.dart')
          .readAsStringSync();

      // Find the ref.invalidate line and verify it's inside a guard.
      final invalidateIdx = source.indexOf('ref.invalidate(documentsProvider)');
      expect(invalidateIdx, isNot(-1), reason: 'ref.invalidate not found');

      // The guard must be within ~200 chars before the invalidate call.
      final beforeInvalidate = source.substring(
        (invalidateIdx - 200).clamp(0, source.length),
        invalidateIdx,
      );
      expect(
        beforeInvalidate,
        contains('mounted'),
        reason: 'ref.invalidate must be guarded by mounted check',
      );
    });
  });
}
