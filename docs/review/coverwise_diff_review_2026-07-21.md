# CoverWise Dirty-Diff Review — 2026-07-21

This dated review covers the current uncommitted diff and neighboring
untracked artifacts. It preserves parallel-agent work and records what is
verified, overstated, fragile, or still requiring an owner decision.

## Findings

### Account-switch isolation is not proven

The current audit diff labels account-switch workspace isolation `DONE`, but
`mobile/lib/screens/profile_screen.dart` signs out, clears the principal key,
clears Hive boxes, and closes those boxes. It then calls
`AnalyticsService.clear()` and `ContactService.clearSavedContact()`, which both
access `app_state_box` after it has been closed; the outer catch masks partial
cleanup.

The app also does not visibly reinitialize the principal DEK and reopen boxes
for the next account during an in-process sign-out/sign-in transition. Principal
migration runs only during process bootstrap. The diff therefore does not prove
same-process account A → sign out → account B isolation, nor that account B
writes use account B’s DEK.

Disposition: high-risk Tier 1 gap. Do not treat the audit’s `DONE` as an
end-to-end claim until an auth-transition lifecycle exists and is tested, or the
product explicitly requires a process restart between principals.

### Legacy Hive migration is stronger in documentation than in the call site

`PrincipalKeyService.migrateBox` documents deleting and reopening a box file,
but `main.dart` calls it with `boxPath: ''`, so the file-delete branch is
skipped. Real legacy-box, crash-during-rewrite, and partial per-box migration
proof are missing.

### Anonymous bootstrap has two concurrent identity acquisitions

`main.dart` starts `_warmAnonymousSession()` without awaiting it and then calls
Supabase `signInAnonymously()` again to derive the principal ID. The warm path
acquires the separate custom API token. This reinforces the J03 dual-principal
gap: local principal, API bearer identity, and Supabase identity are not
established by one explicit lifecycle.

### Purchase-loading test fixture is invalid

`mobile/test/upgrade_screen_test.dart` expects a spinner after tapping “Upgrade
to Plus”, but `FakeBillingAdapter.purchasePlan` returns immediately with `null`.
The test cannot observe a pending state. The correct fix is a completer-backed
fake that remains pending, followed by a terminal-state assertion; production
loading behavior should not be weakened to satisfy the current test.

### Test teardown trades lifecycle proof for suite completion

Several changed tests remove `Hive.close()` and delete temporary directories
instead. This may avoid hangs, but it can hide open-box leaks and cross-test
state. Keep the workaround only with a documented harness limitation and add a
separate lifecycle test that proves boxes can be closed and reopened.

### Analyzer and artifact hygiene are incomplete

`flutter analyze` reports 28 issues, including unused imports, debug prints,
unused locals, and widget-lint findings in debug/legal test artifacts. The
worktree also contains `insurance_app.db`, SQLite `-shm`/`-wal` files, and
untracked debug tests. None were deleted or ignored; each requires explicit
classification before cleanup.

The latest status shows several of these artifacts are already staged:
`mobile/test/debug_*.dart`, `mobile/test/legal_content_loader_test.dart`,
`storage/rag_hybrid_index.db-shm`, `storage/rag_hybrid_index.db-wal`, and the
binary `insurance_app.db` change. Staged does not make an artifact product
source. Their intended classification and retention decision must be made
before any commit.

### Python fallback verification is environment-gated

The fallback suite completed with **39 passed, 15 failed**. Most failures were
collection/runtime dependency gaps (`qdrant_client`, `doctr`, and `redis` are
not installed in this environment), so the fallback paths are not currently
verified here. One LLM quota-short-circuit assertion also failed because the
configured fallback chain returned without raising; this needs isolation from
local-provider state before deciding whether it is a product bug or a test
environment leak.

`python -m compileall -q src tools/validate_production_config.py` passed. The
documented production validator could not start because `python-dotenv` is
missing from the active environment.

### Status language needs evidence reconciliation

The TODO and audit diffs mark document type recognition, family management,
More menu, history, and Q&A accordion work `DONE`. Focused UI tests provide
some Tier 2 rendering evidence, not full persistence, synchronization,
real-document, operator, or restart proof. The journey map correctly keeps
those broader claims open.

### Documents empty-state overflow is a confirmed, narrowly closed UI defect

The shared `EmptyStateWidget` now scrolls when its composition exceeds the
available viewport, while preserving centered layout when it fits. The new
short-viewport regression test passed with the Documents suite. This is a
focused Tier 2 UI closure; it does not prove all device sizes, text scales, or
other screens that reuse the widget.

### Analytics view hardening is structurally sound but migration proof is pending

`supabase/migrations/20260721061309_secure_analytics_views.sql` marks the three
operator analytics views `security_invoker`, revokes client-role access, and
grants service-role select. The source migration creates the views and already
restricts the underlying `analytics_events` table. Static review supports the
decision, but applying the migration and testing role behavior against the
actual Supabase project remain Tier 3 work.

### Launch status is a snapshot, not current proof

`docs/review/launch_execution_status_2026-07-21.md` reports “No issues found”
from `flutter analyze` and a complete Flutter suite of 554 passing tests. The
current rerun reports 37 analyzer diagnostics and the reviewed focused suite
reports 111 passing tests, so the launch-status claims cannot be reused as
current evidence without reproducing their exact command, checkout, and
environment. Its local runtime/Tier 3 claims also remain historical until the
same runtime path is observed against the current tree.

Disposition: retain the launch record for provenance, but label it as a dated
snapshot and update it only with reproducible current commands/results.

### Staged doctrine conflicts with the working-tree doctrine

The current worktree has `motto_v4.md` and `docs/context/agent-start/STEP1_ENV.sh`
pointing at v4, but the index stages `motto_v4.md` and `STEP1_ENV.sh` with v3
content/source references. `git show HEAD:motto_v4.md` is v4, so the staged
state would regress the repository’s canonical instruction surface even though
the working tree is aligned to v4.

Disposition: preservation hazard. Do not commit or stage further work until the
operator resolves whether the staged v3 rollback is intentional. No unstage,
reset, checkout, or other Git mutation was performed.

### Splash dependency classification is not yet justified

The unstaged `mobile/pubspec.yaml` change moves `flutter_native_splash` from
`dev_dependencies` to runtime `dependencies`. The current code search finds no
Dart import; the package is referenced by the build-time generation command and
configuration block. Unless the release pipeline invokes package APIs from
runtime code, the move broadens the production dependency graph without a
demonstrated product requirement.

Disposition: verify the actual build/release command before retaining the move.
If generation is build-time only, keep the package as a development dependency
and document the generation step instead.

## Verification performed

`flutter analyze`: completed without compile errors; 37 warnings/info findings
remain, primarily debug/legal test artifact diagnostics.

Focused command:

```text
flutter test test/consent_ledger_test.dart test/legal_screens_test.dart test/legal_content_loader_test.dart test/principal_key_service_test.dart test/dashboard_screen_test.dart test/documents_screen_test.dart test/qa_screen_test.dart test/upgrade_screen_test.dart
```

Result after repairing the pending purchase fixture: **111 tests passed**.
The process exited successfully.

The affected subset (`upgrade_screen_test.dart` and
`consent_ledger_test.dart`) also passed independently with 50 tests.

The Documents screen suite also passed independently with **8 tests**, including
the short-viewport overflow regression.

No staging, commit, reset, checkout, branch operation, deletion, or ignore-rule
change was performed.

## Priority next pass

1. Decide whether same-process account switching is required; if yes, implement
   one auth-transition-owned close/reopen/rekey lifecycle.
2. Repair the purchase test fixture with a pending completer.
3. Prove legacy Hive migration against an actual encrypted box.
4. Reconcile audit/TODO status language with evidence tiers.
5. Classify generated/debug artifacts before cleanup.

## Anything else?

The largest diff risk is completion language outpacing lifecycle proof. Visible
surface improvements do not close ownership, encryption-transition, durable
cleanup, or operator-recoverability requirements.
