# CoverWise Dirty-Diff Review — 2026-07-21

This dated review covers the current uncommitted diff and neighboring
untracked artifacts. It preserves parallel-agent work and records what is
verified, overstated, fragile, or still requiring an owner decision.

## Findings

### Account-switch isolation required a lifecycle owner and is still not E2E-proven

The current audit diff labels account-switch workspace isolation `DONE`, but
`mobile/lib/screens/profile_screen.dart` signs out, clears the principal key,
clears Hive boxes, and closes those boxes. It then calls
`AnalyticsService.clear()` and `ContactService.clearSavedContact()`, which both
access `app_state_box` after it has been closed; the outer catch masks partial
cleanup.

The new `HiveWorkspaceService` and `InsuranceApp` auth listener now reinitialize
the principal DEK and reopen boxes for an in-process authenticated principal
change. The diff still does not prove same-process account A → sign out →
account B isolation, nor that account B writes use account B’s DEK, because no
two-real-account integration traversal is available in this session.

Disposition: lifecycle implementation is now Tier 1/2 static and focused-test
evidence; the high-risk Tier 3 gap remains the real two-principal traversal.
Do not treat the audit’s `DONE` as an end-to-end claim yet.

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

The same current diff also changes the Documents upload journey: the empty
library uses a prominent `Add policy file` CTA, a populated library uses
`Add new policy`, and the detailed upload surface appears only after a file is
selected. `flutter analyze lib/screens/documents_screen.dart` reports no issues
and the Documents suite passes 8 tests, but those tests do not exercise the
populated CTA or selected-file branch. The overflow review’s former
“layout-only” description was therefore too narrow and has been corrected.

The parallel edit to `docs/planning/product/TODO_app_improvements.md` now marks
P2-01 as `DONE`, but the acceptance evidence remains partial: empty and
populated CTA rendering, saved-policy rendering, short-viewport behavior, and
the shared `CoverWiseSectionLabel` trailing-widget API are covered by focused
regressions. The provider-loading transition and file-selection panel remain
untested. There is still no broad screen-render regression across all existing
callers of the shared component.

Disposition: keep the UI change, but add focused assertions for both branches
before claiming the upload journey is fully verified. This is Tier 2 static/UI
evidence; file picker, upload, duplicate detection, processing, and paywall
branches remain separate higher-risk journey evidence.

There is also a loading-state edge case: `hasDocuments` is derived from
`documentsAsync.valueOrNull?.isNotEmpty ?? false`, so while the provider is
loading the screen chooses the first-use `Add policy file` branch even if the
user already has saved policies. Once the provider resolves it switches to
`Add new policy`. This may be a harmless brief transition, but it is not
tested and can create a misleading first-use affordance for returning users.

Disposition: make the CTA state explicit for loading, empty, and populated
library states (or preserve the existing state while refreshing), then add a
provider-loading regression test before claiming the upload journey is closed.

### Upload entitlement enforcement is client-only and asymmetric

The current upload path checks `documentLimit` in
`DocumentService.uploadDocumentWithLimitCheck` by counting locally loaded
documents, but the Documents screen calls `uploadWebDocument` directly for web
files, bypassing that check. The check is also a non-atomic read-before-upload,
so concurrent uploads can both observe capacity and exceed it. Static review of
`src/api/document.py` found authentication, content validation, idempotency by
source hash, and anti-abuse rate limits, but no plan/entitlement capacity check
or atomic owner-scoped quota reservation at the canonical upload boundary.

This is a high-risk contract gap: client-side limits are advisory and cannot
protect paid/free entitlements across platforms, retries, multiple devices, or
parallel requests. It also directly affects the pending monetization proposal,
which must not be implemented by changing only the Flutter counter.

Disposition: make the server the canonical entitlement decision point, with an
owner-scoped atomic reservation/idempotency contract and explicit responses for
limit reached, duplicate replay, partial batch success, rollback, and retry.
Then make native and web clients consume the same response. Required evidence
is a Tier 3 cross-client/concurrent upload test against the real persistence
boundary; the current local widget tests do not cover it.

The project virtual-environment upload subset currently passes **16 tests**:

```text
.venv/bin/python -m pytest -q tests/test_document_owner_isolation.py tests/test_pdf_access.py tests/test_document_repository.py
16 passed, 1 warning
```

That is useful Tier 2 evidence for the existing security/processing contracts,
not evidence that entitlement limits are enforced. Running the same command
with the system Python is blocked at collection by the missing `jose` package;
the project environment is the authoritative result for this subset.

### Billing and Q&A entitlements remain client-authoritative

The entitlement surface currently has several parallel authorities:

- `EntitlementService` stores plan tier, monthly usage, and Q&A packs in local
  Hive and describes itself as the client-side source of truth.
- `BillingAdapter` maps RevenueCat customer info into that local state, but a
  failed or unavailable sync leaves the cached plan in place.
- `POST /subscription/sync` accepts a client-declared plan and RevenueCat
  identifiers. Its own docstring says the client is the source of truth and
  webhook verification is future work; no receipt/webhook verification was
  found in the inspected path.
- Flutter gates Q&A locally and deducts a question after an answer is returned,
  while the backend `/query` path derives owner scope but does not enforce a
  plan, question budget, or atomic usage reservation.

This creates high-risk failure modes: a forged non-free sync can unlock local
features; two concurrent questions can pass the same local budget check; a
successful expensive query can be returned without a durable charge if the
client dies before deduction; retries can be charged inconsistently; and a
stale local paid entitlement can survive a failed refresh. The subscription
endpoint also stores a client-supplied raw customer-info blob and returns the
un-normalized requested tier in its response even when an invalid tier was
forced to free internally.

Disposition: establish one server-side entitlement and usage ledger. Verify
store state through the provider’s trusted webhook/receipt path, make query
authorization and question reservation owner-scoped and atomic, record a
request/idempotency key and final charge/refund state, and let the client be an
offline cache only. Required Tier 3 checks include spoofed plan, expired plan,
duplicate request, concurrent requests at the cap, timeout after reservation,
answer-generation failure, provider webhook replay/out-of-order delivery,
refund/downgrade, and cross-owner access.

There is an additional source-of-truth mismatch: `src/api/subscription.py`
stores sync rows in a local SQLite file (`insurance_app.db`), while the
project’s canonical deployment and RevOps plans identify Supabase as the
durable database. The mobile client does not consume `/subscription/status` in
the inspected path, and the query/upload routes do not read this SQLite ledger.
On a multi-instance or ephemeral deployment, this is a parallel, non-authority
billing store rather than enforcement.

Disposition: do not extend the SQLite sync endpoint as a second billing
system. Either migrate it into the canonical server entitlement pipeline or
explicitly deprecate it behind a provider-verified webhook/reconciliation path;
then remove client-only assumptions from the affected callers in the same
decision-driven change.

External primary-source alignment: RevenueCat’s [Trusted Entitlements]
(https://www.revenuecat.com/docs/customers/trusted-entitlements) documentation
explicitly describes client-side entitlement manipulation as a threat and
offers response-signature verification. Its [subscription status]
(https://www.revenuecat.com/docs/customers/customer-info) documentation also
identifies the REST API as the path for checking status outside the SDK. These
sources support the architecture concern; they do not prove that this project
has enabled either control.

### Analytics view hardening is structurally sound but migration proof is pending

`supabase/migrations/20260721061309_secure_analytics_views.sql` marks the three
operator analytics views `security_invoker`, revokes client-role access, and
grants service-role select. The source migration creates the views and already
restricts the underlying `analytics_events` table. Static review supports the
decision, but applying the migration and testing role behavior against the
actual Supabase project remain Tier 3 work.

### Launch status is a snapshot, not current proof

`docs/review/launch_execution_status_2026-07-21.md` reports “No issues found”
from `flutter analyze` and a complete Flutter suite of 555 passing tests. The
current rerun reports 37 analyzer diagnostics and the reviewed focused suite
reports 111 passing tests, so the launch-status claims cannot be reused as
current evidence without reproducing their exact command, checkout, and
environment. Its local runtime/Tier 3 claims also remain historical until the
same runtime path is observed against the current tree.

Disposition: retain the launch record for provenance, but label it as a dated
snapshot and update it only with reproducible current commands/results.

### Processing status has a shared-client lifecycle bug

`ProcessingStatusScreen` assigns `DocumentService.authenticatedDio`—a shared
singleton with the auth interceptor—to its `_dio` field, then calls `_dio.close()`
in `dispose()`. Closing that client from one status screen also closes the
client used by later document, query, deletion, and status requests. The
focused fallback tests prove that the screen remains renderable during network
failure, but they do not prove that a later authenticated request still works
after the screen is dismissed.

Disposition: the screen must not close a process-wide client it does not own.
Either give the screen an owned Dio instance or remove disposal and centralize
client lifecycle at the service/app boundary, then add a regression that opens
and dismisses processing status before issuing a second authenticated request.

### Offline upload claims a sync path that is not present

When transport fails, `DocumentService.uploadFile` and `uploadWebDocument` save
the source locally with `syncState: 'pending_upload'` and return a message that
it “will sync when online.” Current code search finds the state mapping and UI
labels, but no pending-upload queue consumer, connectivity-triggered retry,
foreground-resume sync, or user retry action that uploads the preserved source
and reconciles its local/remote IDs. The backend restart-recovery path only
recovers documents already persisted on the server; it cannot recover a file
that never reached the server.

This is a non-happy-path contract mismatch: the user is told the document is
durable and will sync, while the current implementation provides local storage
without a demonstrated delivery mechanism. It affects processing, evidence,
Q&A availability, deletion, and account deletion semantics.

Disposition: choose one truthful contract—implement an owner-scoped durable
outbox with retry/backoff, idempotency, connectivity/resume triggers, conflict
handling, operator visibility, and explicit user status; or change the UI to
say the file is local-only and requires manual retry. Required evidence for
the former is Tier 3 offline → reconnect → server processing with duplicate,
timeout, restart, and account-switch cases.

The current processing-status subset passes **75 tests** across stage mapping,
static rendering, navigation warnings, and network-fallback behavior. This is
Tier 2 evidence for the visible state machine only. The repeated `Document not
found` debug output in fallback tests is expected for synthetic IDs, but also
shows that those tests do not exercise a real local document → remote status
transition or the shared-client-after-dispose failure mode.

### Account-switch isolation is not a complete in-process journey

Static inspection of the current auth path confirms the earlier risk. The
profile sign-out flow signs out, clears the principal key, clears and closes
the Hive boxes, and only then calls `AnalyticsService.clear()` and
`ContactService.clearSavedContact()`. Both services read the already-closed
`app_state_box`; the outer catch can therefore mask a partial cleanup. There is
also no auth-transition-owned reinitialization that derives the next
principal, reopens the encrypted boxes, and rebinds providers for a second
account in the same process.

The app bootstrap initializes the principal only once, and the Supabase auth
stream currently rebuilds UI state but does not own storage lifecycle. This
means “sign out and sign in as another account without killing the app” is not
Tier 3-proven and may fail with a closed-box error or retain stale in-memory
state. The risk spans J02 identity, J03 upload, J04 processing, J05 evidence,
and J07 Q&A because all of those journeys consume principal-scoped local and
server data.

Disposition: treat auth transitions as a single lifecycle boundary. Before
claiming account switching works, define and test: cancellation of in-flight
work, ordered flush/clear, timer disposal, box close, key clear, next-principal
key derivation, encrypted-box reopen, provider invalidation, anonymous-data
claim/rollback behavior, and user-visible recovery on any partial failure.
The required evidence is a same-process two-principal integration test, not a
unit test of the sign-out button.

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

### Android Kotlin state is a generated artifact outside ignore coverage

The current worktree also contains `mobile/android/.kotlin/` with a Kotlin
compiler session marker. It is not covered by the existing Android ignore rules
(`.gradle`, build outputs, captures, and credentials are covered; `.kotlin/` is
not). This is runtime/build state, not product source.

Disposition: classify it as generated state and add an intentional ignore rule
only after confirming no project-owned Kotlin source is stored beneath that
directory. No deletion or ignore-rule change was performed.

`mobile/test/debug_tos4.dart` is also currently modified outside the staged
snapshot and contains diagnostic `print` calls. It is tracked debugging
residue, not a product regression test; its current edits should remain out of
any release-quality test claim until either converted into an assertion-based
test or explicitly archived.

### Monetization research is a proposal, not an approved product decision

`docs/planning/product/monetization_research_and_decision_2026-07-21.md` is a
useful founder-review artifact, but its status is explicitly **DECISION
PENDING**. It must not yet drive entitlement, ad-SDK, pricing, privacy-policy,
or billing implementation.

The proposal creates four review hazards:

1. Its commission/web-aggregator path conflicts with the permanent product
   boundary in `docs/review/exploration_map.md` and the product spec, which
   reject selling, soliciting, procuring, renewing, lead selling, and
   commission revenue. IRDAI identifies a web aggregator as a regulated
   intermediary, so this is a separate regulated-business decision.
2. Rewarded ads require affirmative opt-in, clear reward disclosure, delivery
   of the promised reward, and non-transferable in-app value under Google’s
   policy. They also create a privacy/subprocessor disclosure and consent
   review; adding `google_mobile_ads` alone would not close that work.
3. The market figures and pricing conclusions are research inputs, not current
   product evidence. Revenue, conversion, churn, refund, eCPM, and commission
   assumptions need source-date and methodology verification before becoming
   forecasts or acceptance criteria.
4. The proposal is not yet compatible with the current entitlement contract:
   code still exposes 1 policy and 20 free questions/month, Plus/Family tiers,
   and Q&A packs. Five questions/month, rewarded credits, remove-ads
   entitlement, grandfathering, and server enforcement are unimplemented
   contract changes.

Disposition: retain the document as decision-pending exploration; do not
implement its plan. Reconcile the stale platform-decision link, keep the
commission branch outside the current product unless the founder explicitly
opens a regulated workstream, and require a written decision plus privacy,
entitlement, billing, and abuse/replay acceptance criteria before code changes.

Primary-source checks for this review used Google AdMob’s rewarded-ad policy
and overview and IRDAI’s insurance web-aggregator guidance. These support the
policy/regulatory constraints above; they do not validate the commercial
forecasts in the proposal.

### Updated launch-status claims still exceed reproducible evidence

The modified `docs/review/launch_execution_status_2026-07-21.md` now records
555 Flutter tests and a successful Android bundle build. The current session
has independently reproduced the focused 111-test suite and the field-overrides
suite (16 tests), but has not reproduced the complete 555-test command or a
real-define release build. The document itself says the bundle used placeholder
defines, so it is staging compile evidence rather than release-readiness proof.

Disposition: retain the status report as provenance, but keep the complete-suite
and release claims dated/environment-bound until the exact commands, checkout,
SDK/toolchain, defines, and artifacts are reproducible. The field-overrides
test change is a sound isolation improvement: it uses the shared Hive helper,
initializes the Flutter test binding, and tears down the temporary store; its
current focused result is Tier 2 (16 passed).

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

### J03/J05/J06/J07 identity-key drift breaks some returning-user routes

The local document record has two identifiers: `id` (local Hive key) and
`remoteId` (server document identifier). Upload success stores the server ID,
and `QueryService` translates local IDs before Q&A. That translation is not
uniform: library/dashboard navigation passes `doc.id` to policy detail, while
summary, evidence, status, and source APIs require the server ID. A synced
policy can therefore be queryable but show no summary, no evidence, or a
source-preview failure when opened from those entry points. Existing detail
tests use matching fixture IDs (Tier 2); they do not prove distinct-ID
navigation (Tier 1 static finding).

Disposition: create one canonical identity resolver at the detail/navigation
boundary. Use the resolved server ID for backend calls and the local ID for
Hive/file operations. Add a distinct local-ID/server-ID library → detail →
evidence → Q&A regression test.

### Offline persistence currently stops at a durable local queue marker

Native and web uploads save `syncState: pending_upload` on transport failure.
The UI labels this “Waiting to sync” and blocks Q&A until ready, but repository
search found no connectivity/resume worker, explicit retry, or app-restart
reconciliation consumer. Backend recovery only handles documents already
persisted server-side. The user is therefore promised eventual sync with no
closure path; a pending record may remain indefinitely. Deletion of a local-only
record reaches the remote endpoint with a local ID and relies on 404 cleanup,
which is safe but is not an explicit queue-cancellation contract.

Disposition: define durable reconciliation ownership, source-hash idempotent
retry, consent/byte preservation, backoff, observability, and offline → restart
→ reconnect → server ID → processing → Q&A tests. Until then, call this
**queued locally, sync unverified** (Tier 1), not offline sync supported.

### Evidence route owner-check test wiring is repaired

The focused backend command initially produced **19 passed, 2 failed** because
the fixture patched `src.api.user.get_current_user` while the evidence router
had imported that function directly. The test now uses FastAPI's dependency
override against the router-bound dependency. `tests/test_evidence_api_owner_check.py`
passes **2 tests**, covering the correct `current_user.uid` owner lookup and
404 behavior for a non-owned document. This is executable owner-boundary
evidence (Tier 2); a deployed authenticated route traversal remains Tier 3.

### Deletion copy is stale relative to the current service

`DocumentService.deleteDocument` now attempts remote-first deletion and removes
local data only after 200/204, treating remote 404 as stale state. `DocumentsList`
still tells users the action only removes the local copy and that the server is
unaffected; the comments describe an older security phase. This is a
customer-facing data-deletion contract mismatch. Reconcile copy and tests,
distinguish synced remote deletion from local-only queue cancellation, and
verify failure, 404, retry, and post-delete cleanup before calling deletion
Tier 3-complete.

### Supabase migration rename set is semantically coherent but not yet a safe checkpoint

The current worktree replaces the legacy underscore-named migration files with
timestamped names. Seven replacement files are byte-identical to their deleted
predecessors; the analytics replacement adds `security_invoker`, revokes client
roles on dashboard views, and grants `service_role`. The timestamp order now
places the canonical schema before leases, rate limits, evidence, RevOps,
consent, outbox, RAG tables, and analytics hardening, which is the correct
dependency direction on static inspection (Tier 1).

Two risks remain. The old files are deleted while the replacements are
untracked, so a checkpoint could lose migration history or leave a fresh reset
without the expected files. Also, `20260721061309_secure_analytics_views.sql`
says the canonical migrations sort after the hardening migration on a fresh
reset; their actual timestamps sort before it. The executable guard is
harmless, but the comment is stale and can mislead future operators.

Local Supabase verification is now available: `supabase db lint --local
--level error --fail-on error` passed with no schema errors; `supabase migration
list --local` reports all 13 timestamped migrations present and applied; and
direct read-only catalog checks show the expected documents/evidence/outbox/RAG
tables with RLS enabled, analytics and dashboard views with
`security_invoker=true`, and no client-role grants on the dashboard views.
This is Tier 3 local integration evidence, not proof that a remote linked
project has the same migration state. A remote/production check remains
required before deployment claims.

### Branding generation exposed test-contract drift; asset checks are now class-aware

The generated branding assets initially failed `asset_integrity_test.dart`: the
transparent monochrome glyph measured 13.3% visible pixels against an 18%
generic threshold, and the rounded macOS icon measured 64.4% against a 90%
full-bleed threshold. Visual inspection showed both assets were intentional:
the monochrome test separately requires transparent shield interior, and macOS
app icons use transparent rounded corners.

The test now uses a lower visibility floor for the transparent monochrome glyph
and a macOS-specific floor, while retaining the strict opaque-canvas threshold
for iOS/Android/web. The asset and upgrade suites then passed **23 tests**.
This is Tier 2 asset/UI evidence, not proof of platform install behavior.

### Onboarding and paywall surface consolidation is directionally correct but monetization remains unapproved

Onboarding now requires privacy/terms acceptance before completion and changes
“Skip” to “Skip intro”, which lands on the consent/first-policy page rather
than silently bypassing consent. Paywall is now a compatibility wrapper that
routes limit context into the single `UpgradeScreen`, removing a second pricing
surface. These are coherent J02/J08 journey improvements.

The underlying entitlement and billing risks remain unchanged: local Hive state
still gates access, RevenueCat sync is client-triggered, server subscription
sync accepts client-declared tier, and the founder monetization proposal is
still **DECISION PENDING**. The new UI is not proof of server-enforced
entitlement, refund/downgrade correctness, or approved pricing.

### Local/server identity mismatch is now normalized at policy-detail boundary

The policy-detail screen now resolves a local Hive ID to its `remoteId` when
selecting summaries and when passing IDs to Q&A, evidence, and other
backend-owned surfaces. It continues to use the original widget ID for local
file preview and field overrides. The screen watches the document provider so
the mapping is re-evaluated after asynchronous local storage loading.

Regression coverage uses distinct `local-policy-1` and `remote-policy-1` IDs
and confirms the server-keyed summary renders. The full policy-detail suite now
passes **24 tests**, and targeted analyzer output is clean. This closes the
previously documented static identity gap for the detail boundary (Tier 2),
while a live backend evidence/Q&A traversal remains Tier 3 work.

The family-member path still passes the local ID into policy detail, which is
now safe because it enters the resolver. Callers should continue passing the
local ID when local preview or override continuity matters.

### Empty states and legal failures are now actionable, with stale assertions repaired

The newly changed feature screens consistently route “no policy” states to the
canonical DocumentsScreen picker: claims guidance, emergency card, renewal
calendar, insurance cards, policy comparison, search, and the what-if
calculator. Claims guidance and what-if copy retains its preparation/estimate
boundary; it does not imply claim filing, approval, or insurer underwriting.
Legal privacy and terms screens now use the shared retryable `AppErrorView`
instead of exposing raw loader errors.

The first regression run found stale tests rather than runtime defects: old
empty-state copy and old raw-error icon/message expectations. Those assertions
were updated to the new canonical surface. Verification now passes: emergency
offline/interactions **17 tests**, legal/onboarding **22 tests**, what-if
calculator **31 tests**; analyzer passes for all 12 changed screens/tests.

One attempted standalone onboarding test path was invalid because no such file
exists; onboarding coverage is embedded in `legal_screens_test.dart` and passed.

### Backend dependency pin and test fixture alignment are clean

The backend dependency diff pins `supabase==2.8.1`, aligns `gotrue==2.8.1`,
and moves `httpx` to 0.27.2 for the proxy keyword used by the Supabase client.
The project virtual environment reports those versions and `pip check` reports
no broken requirements. The Supabase FTS test fixture now supplies a
JWT-shaped key before replacing the client double; the broader backend
regression run passed **140 tests**.

The backend test run also produced/updated local runtime artifacts: the tracked
`insurance_app.db` and untracked sample files under `storage/documents/`.
They remain preserved for classification; they are not treated as product
source or release evidence, and no cleanup was performed.

## Priority next pass

1. Run a same-process two-principal integration traversal against real Supabase
   sessions and verify account B cannot read or write account A’s local data.
2. Prove legacy Hive migration against an actual encrypted box.
3. Reconcile audit/TODO status language with evidence tiers.
4. Classify generated/debug artifacts before cleanup.
5. Complete a live authenticated detail → evidence → Q&A traversal using the new identity resolver.
6. Implement and verify pending-upload reconciliation with a visible retry action, or keep the current explicit “server upload required” contract.
7. Implement the durable account-erasure job/receipt and verify retry/404/queue-cancellation semantics.
8. Verify remote migration history and perform platform-level deep-link traversal.
9. Keep asset integrity class-aware and validate platform build/install artifacts separately from Flutter tests.

## Migration source and deep-link follow-up (2026-07-21)

The diff exposed two contract mismatches around the deployment surface:

1. `.env.example` introduced `SUPABASE_SECRET_KEY` and
   `SUPABASE_EXPERIMENTAL_API_KEY`, but all server consumers require the
   canonical `SUPABASE_SERVICE_ROLE_KEY`. A misleading example can produce a
   deployment that looks configured while account, storage, evidence, and
   retrieval paths remain disabled.
2. The timestamped `supabase/migrations/` chain is now the executable local
   migration source, while multiple runbooks and architecture sections still
   instructed operators to apply `infra/supabase/*.sql`. The first three base,
   lease, and rate-limit sets are byte-identical snapshots, but presenting both
   as active sources creates a duplicate-schema risk.

Focused closure: `.env.example`, the Supabase setup runbook, canonical
architecture, storage contract, and `infra/supabase/README.md` now identify the
timestamped CLI chain as canonical and the `infra/supabase/` files as retained
historical snapshots. Stale migration-header commands were corrected to
`supabase db push`. Initial deep-link lookup now has an explicit error path so a
platform API error does not become an unhandled future during app startup.

Evidence: Tier 1 static inspection found all active server consumers use
`SUPABASE_SERVICE_ROLE_KEY`; Tier 2 `flutter analyze` for the changed app
surfaces passed; Tier 2 claims-assistant tests passed (5 tests); Tier 1
`git diff --check` passed. Remaining gaps are remote migration-history proof
and cold-start deep-link traversal on each release platform.

## Account-switch cleanup hardening (2026-07-21)

The sign-out cleanup path had a concrete ordering defect: it closed
`app_state_box` and then called `AnalyticsService.clear()` and
`ContactService.clearSavedContact()`, both of which access that box. One broad
catch made the failure look like successful workspace isolation. The cleanup
now clears those service-owned values before closing boxes, awaits analytics
cleanup, and clears the in-memory principal ID together with the DEK.

Verification: `flutter analyze` for `profile_screen.dart` and
`principal_key_service.dart` passed; the profile processing-guard suite passed
(10 tests). This is Tier 2 only. Same-process re-authentication is still not
closed: the app does not yet own one post-auth transition that reinitializes the
new principal and reopens all encrypted boxes. That remains a Tier 3 blocker
for claiming account-switch isolation.

The deletion response had a parallel claim defect: partial responses promised
that a durable deletion job would retry failed stages, but static inspection of
`src/api/user.py`, the outbox job types, and worker registration found no
account-deletion job or enqueue call. The API and Flutter profile message now
state that server deletion may remain incomplete and identify the failed stages
instead of asserting an unimplemented retry guarantee.

Verification: `.venv/bin/python -m pytest -q tests/test_user_account_deletion.py`
passed (5 tests); the changed mobile analyzer and profile/legal suites passed
(32 tests). This is Tier 2. A production-safe account-erasure contract still
needs a durable job/receipt, complete data inventory, retry semantics, and
operator verification before deletion can be called complete.

## Offline upload honesty and shared-client lifecycle (2026-07-21)

The mobile upload path persists an offline file as `pending_upload`, but no
consumer or connectivity-triggered reconciliation worker was found. The old
copy (“will sync when online” / “Waiting to sync”) therefore implied an
automatic behavior the code does not implement. The copy now says the file is
saved locally and server upload is still required; the existing offline banner
already states that uploads require a connection.

`ProcessingStatusScreen` also disposed `DocumentService.authenticatedDio`, a
process-wide shared client. Its disposal is now limited to cancelling the
screen-owned timer, preventing one screen from closing the client used by other
requests.

Verification: analyzer passed for the four changed mobile files; the combined
processing-status and documents suites passed (**84 tests**); `git diff --check`
passed. The durable follow-up is a true pending-upload
reconciliation owner with idempotency, retry/backoff, auth-transition handling,
and a visible retry action; until then, pending local files must not be
described as queued for automatic sync.

## Anything else?

The largest diff risk is completion language outpacing lifecycle proof. Visible
surface improvements do not close ownership, encryption-transition, durable
cleanup, or operator-recoverability requirements.

## Monetization and onboarding claim hardening (2026-07-21)

Paywall consolidation is directionally correct: `PaywallScreen` now records the
limit reason and delegates pricing/purchase UI to `UpgradeScreen`, leaving one
monetization surface. Adjacent customer copy was tightened: onboarding now
says policy content is not included in anonymous usage events without claiming
that no personal data is ever transmitted; plan changes defer timing,
proration, and refunds to platform subscription terms; and the plan banner says
“Access until” rather than implying auto-renewal.

The deeper billing boundary remains open: RevenueCat synchronizes into local
Hive state, while the backend subscription endpoint still accepts client-declared
plan state and is not used for server-side upload/Q&A enforcement. RevenueCat
purchase UI therefore cannot be treated as entitlement proof or launch-ready
billing integrity. This remains a high-risk Tier 3+ requirement.

Verification for this pass: `flutter analyze` on onboarding and upgrade screens
passed; the combined upgrade and legal/onboarding suites passed (**39 tests**);
`git diff --check` passed. No RevenueCat sandbox purchase, store receipt, or
server-enforced entitlement traversal was available, so the billing conclusion
remains static/Tier 1 rather than E2E evidence.

## Principal workspace lifecycle hardening (2026-07-21)

The auth review found that sign-out could close `app_state_box` while
`ProfileScreen` immediately rebuilt and read it, while `SessionService` and
analytics retained the previous session identity. A new
`HiveWorkspaceService` now owns the sensitive-box list, closes/deletes the
cleared workspace, and reopens it with the new principal DEK. `InsuranceApp`
listens for authenticated principal changes and performs the same reset before
reinitializing analytics; it clears buffered analytics and the prior session
before the reset, and sign-out resets to an install-local fallback first.

Verification: `flutter analyze` passed for `main.dart`, `profile_screen.dart`,
and `hive_workspace_service.dart`; the focused profile guard test passed (1
test). A full two-account authenticated traversal remains Tier 3 work because
the current session lacks two real Supabase identities and live encrypted-box
transition evidence.

## Platform identity and generated asset review (2026-07-21)

The new Linux packaging files are intentional source artifacts: the desktop
entry declares `com.coverwise.app`, CMake installs the desktop file and 256px
icon, and the GTK window title is `CoverWise`. The macOS test bundle identifier,
launcher-icon configuration, web metadata, and platform icons are aligned to
the CoverWise identity. The Linux icon and macOS source icon were visually
inspected; asset integrity tests already use platform/class-specific thresholds.

Verification: the web release build produced `build/web/index.html`; Linux
build/install verification is unavailable on this macOS host because Flutter
only supports `build linux` on Linux. This is a platform evidence gap, not a
claim of Linux release readiness. The untracked runtime screenshots under
`docs/review/evidence/asset-revamp-2026-07-21/` remain preserved as visual QA
evidence, not source code.

The insurance-card action row had an active “Call insurer” control that only
showed a snackbar and a “Share card” control that only said “coming soon”. The
row now launches the platform phone handler and shares a deliberately limited
text card with a source-document verification disclaimer. This keeps the
customer-facing action aligned with its label without implying insurer claim
filing or proof beyond the displayed policy fields.

Verification: `flutter analyze lib/screens/insurance_card_screen.dart` passed.
Platform phone/share sheets were not exercised in this session, so this remains
Tier 1/2 rather than platform E2E evidence.

## Subscription response normalization and share failure handling (2026-07-21)

Two small contract corrections were made at canonical boundaries. The
subscription sync endpoint already forced unknown client-declared tiers to
`free` before persistence, but its response echoed the untrusted request value;
it now returns the normalized tier that was actually written. This prevents a
client or operator from treating the response as stronger entitlement evidence
than the server stored. The endpoint remains client-asserted and therefore is
not server-side billing verification.

The insurance-card share action now catches platform share failures and gives
the user an explicit recovery message, matching the existing phone-handler
failure behavior. The card remains intentionally limited and includes a
source-document/insurer verification disclaimer.

Verification: `flutter analyze lib/screens/insurance_card_screen.dart` passed;
the Python subscription module compiles; no dedicated subscription endpoint
test was present in the repository search. Store-sheet behavior and a live
authenticated subscription traversal remain unverified Tier 3+ work.

Additional focused regression verification in this continuation: the
upgrade/legal/claims suite passed **44 tests**, and the
documents/emergency/offline/what-if/policy-detail suite passed **72 tests**.
The repository-wide `git diff --check` still reports one trailing-space line
in the unrelated current `src/utils/anti_abuse.py` diff; it was preserved as
parallel work and not changed in this review.

## Entitlement expiry and access-gate correction (2026-07-21)

The access-control review found that an expired paid entitlement still reported
its unused monthly question quota. `QaScreen` read that property directly,
which bypassed the provider's separate expiry check and could allow questions
after subscription expiry. Upload submission also lacked a final canonical
entitlement gate.

The entitlement model now requires an active paid plan for subscription
questions; purchased Q&A packs remain available after subscription expiry.
Q&A submission uses the provider gate, and upload submission checks the same
gate before consent/upload work begins. Existing paid-plan quota fixtures were
made explicit about their future expiry rather than weakening the rule.

During verification, malformed snackbar edits in the current policy-detail
diff and an incorrect shared-widget theme import were also exposed and fixed;
these were compile failures in the touched customer flows, not silently
deferred pre-existing failures.

Verification: analyzer passed for six affected Dart files; entitlement tests
passed **20 tests**; Q&A and documents tests passed **20 tests**. Server-side
entitlement enforcement and a real store/authenticated traversal remain open.

## Retrieval embedding boundary (2026-07-21)

The Supabase vector store already rejected non-canonical dimensions during
ingestion, but dense query vectors were passed to the RPC without the same
local contract check. The query path now rejects anything other than the
canonical 1536 dimensions before making a remote call, keeping ingestion and
retrieval failure behavior aligned.

Verification: the Supabase FTS/vector-focused tests cover both upsert and
dense-search dimension rejection. Live Supabase migration execution and a real
owner-scoped retrieval traversal remain Tier 3+ evidence gaps.

## Durable outbox transition fencing and job-type parity (2026-07-21)

The queue claim path is now database-atomic, but terminal service transitions
were still update-by-ID only. A stale worker could therefore mark a later
attempt completed or failed after its lease had been reclaimed. `complete()`
and `fail()` now require the row to still be `running`, preventing mutation of
completed/pending jobs. A lease-token/fencing version remains the stronger
long-term design for distinguishing two simultaneous running attempts.

The queue also had a concrete schema parity defect: `ACCOUNT_DELETION` existed
in the typed model and worker registration but was absent from the base SQL
check. The canonical migration and account-lifecycle migration now include it.

Verification: job-outbox and Supabase vector tests passed **33 tests**. Live
multi-worker contention and deployed migration execution remain unverified.

## RevenueCat identity reset on sign-out (2026-07-21)

Account sign-in now associates RevenueCat with the durable account UID, but
sign-out previously only reset local Hive state. That left the store SDK's
customer identity attached to the former account, creating a cross-account
purchase/entitlement leakage risk for the next guest or account session.

`BillingAdapter.clearAccountIdentity()` now calls the provider logout operation
from the existing profile workspace-clear path. A provider failure is logged
and does not prevent local isolation; the next authenticated sync remains the
recovery path.

Verification: analyzer passed for billing and profile; the focused profile
guard suite passed **10 tests**. Store-account switching remains unverified
without a RevenueCat sandbox traversal.

## Durable deletion retry and enqueue idempotency (2026-07-21)

The expanded account-lifecycle worker now withdraws evaluation items, marks
owner artifacts deleted, removes storage/chunks/documents, and deletes the auth
user. Its failure path now persists `failed`, stage state, and an error class
before re-raising so the outbox can retry without leaving an apparently active
request.

Production delete retries also now look up an existing account-deletion job and
the queue has a unique request-payload index. This prevents repeated client
submits or concurrent API calls from creating multiple destructive jobs for one
request. A forward migration must preflight existing duplicate payloads before
the unique index is applied; that deployment check is not yet live-verified.

Verification: the lifecycle, identity, user-deletion, and job-outbox tests
passed **36 tests**. Live Supabase job uniqueness, worker retry, and complete
erasure verification remain Tier 3+ work.

## Dataset and artifact lifecycle boundaries (2026-07-21)

The current diff now contains a canonical, service-role-only registry for
evaluation/training/benchmark releases. It correctly prevents customer-derived
items without a consent reference, prevents edits after release approval, and
represents withdrawal as state. One audit gap was found and closed: release
revocation accepted a reason but previously discarded it. `revoked_reason` is
now persisted by the service and migration, with a focused regression test.

The registry still does not independently verify that a referenced consent row
belongs to the declared owner or covers the dataset purpose. That is a Tier 1
contract boundary, not proof of consent validity. Before customer-derived data
enters a release, add a server-side consent lookup/eligibility check and a
release manifest/hash verification path; require operator review for training
purpose. The existing source snapshot is useful provenance but is not a
replacement for consent validation.

`document_artifacts` is a useful canonical inventory for source and derived
objects, and account deletion now marks an owner's inventory rows deleted.
However, the physical deletion loop currently follows document payload source
paths; it does not enumerate and delete every `page_image`, `derived`, or
`embedding_cache` object referenced only by the artifact table. Metadata marked
`deleted` must not be interpreted as physical erasure. The long-term closure is
an artifact deletion worker that claims inventory rows, deletes each validated
object reference idempotently, records per-artifact outcome, and only reaches
`deleted` after storage confirmation. Until then, deployed erasure evidence is
incomplete for derived artifacts.

The production rate-limit transparency endpoint also had a stale-window bug:
it read `request_count` without checking `window_started_at`, so an expired
window could display old usage until another upload rotated the row. The
reader now treats windows at least 24 hours old as zero and preserves current
counts; two focused tests pass. This is usage-display correctness, not a
change to the atomic `consume_rate_limit` enforcement primitive.

## Retrieval context-expansion owner fence (2026-07-21)

Primary dense and FTS retrieval already required an owner filter, but adjacent
context expansion accepted only chunk IDs. A linked target could therefore be
returned without the primary owner predicate. The vector adapter now carries
the owner into retrieval hit metadata, requires it for adjacent expansion, and
applies it when fetching target chunks. The RAG pipeline skips expansion when
owner scope is absent rather than widening the query.

Verification: Supabase retrieval and RAG pipeline tests passed **13 tests**.
This is Tier 2 evidence; a live cross-owner linked-chunk traversal against the
deployed RPC/table policies remains required before claiming Tier 3 isolation.

## Durable document-processing adoption (2026-07-21)

The accepted outbox-only decision was not reflected by the live upload path:
production still called FastAPI `BackgroundTasks`, while the outbox handler
accepted base64 document bytes and bypassed the API path's durable terminal
status/classification finalization. That was a real split contract, not merely
an implementation detail.

The first coherent migration stage is now implemented. Production composition
requires the outbox; upload jobs carry the already-persisted source-object
reference rather than duplicating document bytes in JSONB; the worker validates
the owner-scoped document, fetches the source through the canonical object
store, claims the repository lease, and uses the shared job runner. The local
compatibility path remains explicit for development without Supabase. Enqueue
failure rolls back metadata/source state and returns 503 rather than 202.

The shared runner persists the processing result and releases the lease before
returning, while classification remains best-effort and cannot hide a failed
processing state. Focused runner/upload tests pass **4 tests** and syntax checks
pass. A deployed worker traversal is still required: production outbox
configuration, object-store fetch, lease contention, retry after worker death,
and UI-visible status must be verified together at Tier 3.

Remaining outbox adoption is not silently considered complete: substrate
extraction is still invoked inline inside `DocumentProcessingService`, and
Q&A/subscription/claim job types lack registered handlers. Continue with a
separate migration stage only after the current document-processing path has
live evidence.

## RevenueCat webhook ordering fence (2026-07-21)

The new authenticated webhook path had event-ID idempotency, but delivery
reordering could still let an older expiration/refund overwrite a newer
renewal. The local compatibility ledger now records `event_timestamp_ms` and
marks older or equal provider-timestamp events `stale_ignored` without changing
verified state. Events without a provider timestamp retain arrival-order
compatibility because no safe ordering signal exists.

Verification: webhook authorization, duplicate delivery, expiration, and
out-of-order state preservation passed **3 tests**. The endpoint still writes a
SQLite compatibility ledger and processes inline; provider-backed durable
storage, outbox delivery, signature rotation, and live RevenueCat replay tests
remain required for production entitlement authority.

## Model-lineage configuration hash stability (2026-07-21)

Model runs already required an approved, purpose-matching dataset release and
recorded a configuration hash. The hash previously depended on Python's
representation of nested dictionaries, so equivalent configurations could
produce different lineage identities. Hashing now uses canonical JSON with
sorted keys and stable separators/default string conversion.

Verification: model-lineage, webhook, and retrieval-audit tests passed **7
tests** in the focused run. This proves deterministic local hashing, not
production artifact retention or operator replay of a real model run.

## Migration-chain coherence (2026-07-21)

The timestamped executable chain currently contains **33 uniquely versioned
SQL files**, ordered from the base documents schema through processing events.
Static inspection confirms the new lifecycle, retrieval-audit, artifact, and
model-lineage tables reference earlier tables/functions in the ordered chain;
the account-lifecycle trigger uses the previously defined outbox timestamp
function, and the model registry follows the dataset registry.

This is Tier 1 evidence only. No claim is made that the 33 files are applied to
the target Supabase project. A clean CLI reset, migration-history comparison,
duplicate account-deletion payload preflight, and production push are required
before deployment readiness.

The new additive migration also adds partial indexes for the remaining nullable
foreign keys on dataset, retrieval-candidate, and answer-evidence tables. The
local Supabase database was not running during this pass, so `supabase migration
list --local` could not connect; SQL execution and advisor output remain open.

The current static inventory has since grown to **33 uniquely versioned SQL
files**, including policy summaries, the FTS source-text contract, and stable
analytics event identity. This count is repository evidence only; no deployment
or fresh-reset claim is made.

## Analytics replay identity and retention boundary (2026-07-21)

The production analytics branch now derives a deterministic `event_id` from
the authenticated server user, event payload, and client event context. The
new migration backfills historical rows, removes the timestamp-based unique
key, and adds a unique stable key. This makes a retried batch safe to replay
and prevents distinct same-batch events from colliding on `received_at`.

`AnalyticsRetentionService` remains the service-role boundary for the
past-cutoff purge RPC; scheduling, audit reporting, and live Supabase execution
remain open.

The full Flutter suite now passes **588 tests** after removing a concurrent
duplicate upload-size constant and making the initial-file widget test pump
around the intentional indeterminate allowance spinner. Mobile advertises a
20 MB early UX limit; the backend retains its independent 50 MB authoritative
safety ceiling, so clients cannot expand server acceptance and server errors
remain authoritative.

## Governed dataset execution terminal-state fence (2026-07-21)

The approved-manifest execution service now keeps manifest artifact persistence
inside the model-run terminal-state fence. If artifact storage fails after a
run is created, the run is finalized as `failed` rather than left indefinitely
in `started`. Per-item results remain hash/metric-only, and raw evaluator output
is not persisted.

Verification: dataset execution, model lineage, and registry tests pass **11
tests**. This is Tier 2 evidence; a real approved release, evaluator/provider
run, artifact store, and operator replay remain research-lane gates.

Verification: analytics idempotency, retention, error aggregation, production
anti-abuse startup, and runtime configuration tests pass **24 tests**. This is
Tier 2 evidence; migration execution and deployed replay are not verified.

## Policy projection identity and artifact transition fencing (2026-07-21)

The normalized policy projection now resolves an existing `policy_versions`
row by `document_id` first and verifies that its policy belongs to the current
owner. A document without a stable policy number is not allowed to merge into
an arbitrary owner policy; it creates an independent projection. The projection
boundary remains intentionally bounded to typed classification metadata and
section structure, not raw OCR/source text.

Artifact retention and orphan scans now use compare-and-set state transitions.
Only the worker that successfully changes the expected prior state emits the
corresponding lifecycle audit event and increments the transition count. The
physical object deletion worker, retry policy, and live concurrent-worker proof
remain open.

Verification: policy-domain and artifact-lifecycle focused tests passed **9
tests** together with model-lineage and webhook checks. This is Tier 2 evidence;
production Supabase projection, transition races, and object-store deletion are
not verified in this environment.

## Remote billing ledger concurrency fence (2026-07-21)

Production billing is routed to the server-side Supabase ledger; SQLite remains
development/test-only. The RevenueCat RPC now takes a per-account advisory
transaction lock, atomically inserts the event ID, rejects duplicate delivery,
and applies provider-timestamp ordering before changing entitlement state.

The local Supabase database was unavailable, so the RPC, grants, and migration
were statically inspected rather than executed. Tier 3 verification still
requires concurrent webhook delivery, replay, stale-event ordering, provider
signature handling, entitlement reads after commit, and operator-visible audit
inspection. Billing remains a high-risk production gate until that evidence
exists.

## Substrate worker owner binding (2026-07-21)

The durable substrate-extraction job already kept raw OCR out of the queue,
but its handler initially trusted the payload's `document_id` without checking
the corresponding `owner_id` through the canonical document repository. The
handler now requires both fields and rejects a missing or owner-mismatched
document before loading page artifacts or invoking the evidence pipeline.

Verification: substrate wiring, document runner, and owner-isolation tests pass
**10 tests** together. This is Tier 2 evidence; a deployed worker and
cross-principal job-injection test remain Tier 3 operational gates.

## Localization boundary remains partial (2026-07-21)

The new localization catalog is used by the Q&A surface, but the other screens
in this diff still contain direct user-facing literals. Its source comment now
describes that scope accurately instead of claiming that all copy is already
centralized. Complete extraction should be staged by screen with locale tests;
this pass records the boundary without creating a parallel copy system.

The snackbar helper has the same boundary: migrated screens use the shared
styling, while claim assistance, policy detail, and document subflows still
contain legacy raw snackbars. Complete consolidation requires screen-level
visual checks and accessibility review before removing those calls.

Flutter verification for this mobile cluster is now stronger: `flutter analyze`
reports no issues, and the focused Q&A, profile deletion guard, documents,
legal, and upgrade suite passes **69 tests**. This is Tier 2 evidence; device
matrix, accessibility, and real billing/notification-provider behavior remain
runtime gates.

The document-picker audit also closed a client-side parity gap: web uploads now
enforce the same 20 MB size limit as native uploads, and the browser accept list
matches the screen's PDF/JPEG/PNG contract. Flutter analysis remains clean and
the documents-screen suite passes **11 tests**. Server-side validation remains
authoritative; this is client usability and early-failure evidence only.

Document processing now records policy-domain projection failure separately
from classifier failure. A successful heuristic/LLM classification no longer
silently implies that the normalized policy projection succeeded; the stage
stores only a bounded error type and remains visible in the processing result.
Focused document/outbox/policy tests pass **13 tests** after this hardening.

The broad Python suite then passed **337 tests**, with 4 skips and 42 dependency
warnings. The skips are unmarked async verification scripts; they are not
counted as end-to-end proof. A direct local endpoint probe found OCR and RAG
health endpoints available, while the optional frontend service on port 8080
was unavailable. Credentialed model-fallback and full deployed-service probes
remain open.

## Addendum — remaining diff audit: retention, backfill, and evidence status (2026-07-21)

The final small-diff pass found and closed three boundary gaps:

- scheduled retention now normalizes the modern Supabase server-secret alias,
  and analytics/artifact retention accept the same canonical fallback as the
  billing and outbox adapters;
- contextual retrieval backfill now rejects unsafe batch sizes, orders pages
  deterministically, and preserves an explicit owner predicate on scoped
  updates;
- Q&A citation cards now use verified/error/unknown icons according to the
  citation status instead of presenting every citation as verified, and long
  status labels are ellipsized within the card.
- subscription writeback now validates serialized boolean values explicitly,
  preventing a string `"false"` from becoming truthy during entitlement sync.

Verification: 39 focused Python tests passed; Flutter analysis passed; the
Q&A, pack, and document screen suite passed 53 tests. This is Tier 2 evidence
for local contracts and Tier 1/2 evidence for the UI boundary. Retention
scheduler execution against Supabase, a real backfill replay, and deployed
cross-owner/citation rendering remain Tier 3+ gates.

## Addendum — platform, CI, and renewal journey pass (2026-07-21)

The next diff cluster was re-audited against the user journey. Android
17/API 37.1 cold-launch artifacts were visually inspected and are consistent
with the recorded package/onboarding accessibility dump; this remains Tier 4
startup evidence and does not prove launcher icon placement.

The CI workflow now calls the canonical backend test runner, and its trailing
whitespace regression was removed. The renewal-calendar empty path had an
incorrect CTA label (`renewalEmptySubtitle`); it now uses the canonical policy
file action. A new widget test covers the empty renewal state.

Verification: Flutter analysis passed; the affected mobile suite passed 64
tests; the backend outbox/writeback/retention subset passed 6 tests. Full
deployment and CI-host execution remain unverified in this environment.

The new `tools/verify_supabase_schema.py` probe was also executed read-only
against the configured remote project. It returned Auth HTTP 200, confirmed
email enabled and anonymous users disabled, found the established required
tables, and exited 2 because `model_run_results` is absent remotely. This is
Tier 3 schema-drift evidence; no remote write or test account was created.

The Postgres best-practices pass identified and closed a missing leading index
for the `model_run_results.dataset_item_id` foreign key. The migration now
indexes that column separately from its `(model_run_id, dataset_item_id)`
uniqueness index, improving restriction checks and item-level joins.

The dependency contract was also tightened: the tested Pydantic/Pydantic
Settings pair is now pinned exactly, `uv pip install --dry-run` proposed no
changes, and `uv pip check` passed. The legacy Firebase package remains
omitted intentionally because its adapter is a lazy compatibility boundary and
Supabase Auth is canonical.

## Addendum — mobile copy and state-contract review (2026-07-21)

The documents, insurance-card, profile, settings, and renewal diff cluster was
reviewed end to end. Two contract issues were corrected: the device-data row
now says `Clear local data` rather than reusing the confirmation-dialog title,
and profile storage copy now describes a protected local cache while allowing
for securely synchronized account data. The renewal empty-state CTA remains
covered by its dedicated regression test.

Verification: Flutter analysis passed; focused profile/documents/renewal tests
passed 23 tests; `git diff --check` passed. The full Flutter suite is recorded
at 588 passed at that earlier checkpoint. The latest full run is 594 passed.
Remaining gaps are device-matrix/accessibility coverage and
authenticated deployed-runtime proof.

## Addendum — document-intelligence provenance hardening (2026-07-21)

The optional Docling branch had a concrete multi-page provenance defect: it
returned the complete document as page 1 and reported a one-page result. The
adapter now groups exposed page items into page text and derives the page count
from that grouping, with an explicit page-1 fallback only when grouping is not
available. The new CIR tests cover ordering, source/image hashes, and the
non-inference boundary for specialist capabilities.

Verification: 8 focused Python tests passed; Python compilation passed; and
`git diff --check` passed. Real Docling execution, durable CIR persistence, and
page-level UI citation resolution remain unverified Tier 3 gates.

## Addendum — family and Q&A surface pass (2026-07-21)

The family and Q&A screens were rechecked after the earlier localization and
trust-boundary changes. Family removal copy is now fully catalog-backed in the
changed paths. Q&A answer citations render explicit verified/rejected/unknown
states, and unknown citations display `Unknown` rather than leaving the user to
interpret an unlabelled help icon. The entitlement check and stale demo-answer
fence remain intact.

Verification: Flutter analysis passed; the Q&A, pack, profile, documents, and
renewal suites passed 65 tests; `git diff --check` passed. Real authenticated
API citation payloads and deployed runtime remain unverified.

## Addendum — billing, outbox, and retention execution review (2026-07-21)

The server operational cluster was audited end to end. RevenueCat webhooks are
accepted only after durable queue insertion in remote mode; reconciliation and
subscription writeback use the server ledger; retention deletes only objects
already fenced by lifecycle state and records the terminal transition. The
modern Supabase secret alias is normalized at runtime boundaries, preserving
one internal credential contract.

Verification: 44 focused Python tests passed; affected modules compiled; and
`git diff --check` passed. Live RevenueCat, remote retention, and production
operator-recovery behavior remain unverified.

## Addendum — full-suite revalidation (2026-07-21)

The full current pass exposed a real 2.7px overflow in the on-device OCR
language dropdown at the fixed mobile test viewport. The dropdown now expands
to its available width. The associated test also scrolls the switch into view
and uses a typed widget predicate, removing a false failure caused by hit-test
and generic-type assumptions.

Verification: backend full suite 350 passed, 1 intentional skip; Flutter full
suite 594 passed; upload-layout suite 19 passed; and `git diff --check` passed.
Provider-backed, device-matrix, and authenticated deployed-runtime behavior
remain unverified.
