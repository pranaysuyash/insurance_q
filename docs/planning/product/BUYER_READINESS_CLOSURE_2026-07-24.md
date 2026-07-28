# Buyer-readiness closure register

**Date:** 2026-07-24  
**Scope:** Turn the buyer-side diligence findings into one executable closure
register for CoverWise. This is a forward-looking control register; it does
not replace the historical launch audits, ADRs, or the launch-claim registry.

## Decision boundary

CoverWise may be represented as a **technical asset under active hardening**,
not as a production-ready operating business, until every public-launch gate
in this register has current Tier 3+ evidence. The canonical product boundary
remains: help a person understand and organise policies they already own. It
does not sell, quote, recommend, renew, adjudicate claims, or guarantee
eligibility/outcomes.

## How to use this register

- A checked item needs the evidence named in its acceptance column, not merely
  code that appears to implement it.
- `Code present` means Tier 1 only. It is never release evidence by itself.
- Every completion entry records date, command/runtime result, evidence tier,
  and any residual risk.
- External-account items remain explicitly blocked until the account holder
  executes the named proof; they are not engineering failures and must not be
  silently treated as passed.
- Existing uncommitted parallel work is preserved. This register does not
  imply that the corresponding code is ready to stage or commit.
- For the live, step-by-step execution state and current blocker inventory, see
  [BUYER_READINESS_LIVE_TODO_2026-07-24.md](BUYER_READINESS_LIVE_TODO_2026-07-24.md).

## Closure register

| ID | Gate | Current status | Acceptance evidence | Owner |
|---|---|---|---|---|
| BR-01 | Truthful public product boundary and launch claims | Tier 2 for reviewed active mobile surfaces; full registry and runtime review remain open | Every public claim mapped in `docs/launch_claims/`, gate tests green, marketing surfaces contain no prohibited insurance promise | Product + engineering |
| BR-02 | Evidence-backed policy detail and Q&A | Tier 2 four-face and mobile-envelope contracts; runtime/corpus proof pending | Authenticated upload → processing → cited detail → Q&A replay using representative corpus; unsupported fields visibly remain unverified | Engineering |
| BR-03 | Coverage, health and claims language is honest | Tier 2 for reviewed active mobile surfaces; full copy and device review remain open | No score/gap/claim label states an inference as a fact; widget and copy tests cover evidence-absent states | Product + engineering |
| BR-04 | Authentication and guest-to-account continuity | **✅ RESOLVED** — 11/11 verifier checks passed against remote Supabase (2026-07-28, Tier 2 evidence) | Identity verifier creates synthetic user, verifies anonymous-to-authenticated continuity, confirms cross-owner API denial, Storage denial, owner deletion, and post-delete absence. All checks pass against remote Supabase. | Engineering |
| BR-05 | Tenant isolation, storage and deletion | **✅ RESOLVED** — 11/11 verifier checks passed against remote Supabase (2026-07-28, Tier 2 evidence) | Two-principal access-denial test (API + Storage), owner deletion, post-delete artifact audit, user cleanup. Combined 11 checks pass against remote Supabase without Docker dependency. | Engineering |
| BR-06 | Consent, retention and legal surfaces | Tier 2 local controls; production proof (including hosted page/deployment parity) remains owner-run | Versioned hosted privacy/terms pages, consent-ledger proof, retention task execution, founder/operator sign-off | Founder/operator + engineering |
| BR-07 | Payments and entitlement authority | Tier 2 local contracts; provider proof pending | RevenueCat sandbox purchase, renewal, cancellation/refund, signed webhook replay/idempotency and server writeback | Engineering + RevenueCat account owner |
| BR-08 | Operational resilience | Tier 2 local UI/recovery contracts; runtime observability proof pending | Crash event reaches configured non-production project; offline and backend-unavailable UI verified; retry/recovery paths visible | Engineering + observability account owner |
| BR-09 | Durable work and operator recovery | Tier 2 queue/worker contract evidence; deployment proof pending | Deployed worker drains jobs, lease/retry/dead-letter paths observable, runbook gives operator recovery action | Engineering + cloud account owner |
| BR-10 | Reproducible verification baseline | Tier 2 local baseline complete; runtime/release proof remains separate | Clean documented environment installs all test dependencies; backend suite collects/runs; Flutter analyse has zero issues; complete mobile suite passes | Engineering |
| BR-11 | Release configuration and supply-chain hygiene | Tier 2 direct dependency/secret scans; release-account and remediation gates open | `validate_production_config.py`, dependency/license scan, secret scan, release build with real non-secret defines | Engineering + account owner |
| BR-12 | Store and distribution evidence | Blocked on external accounts | Signed Android bundle and iOS archive, store metadata/legal URLs, real-device smoke record | Account owner + engineering |
| BR-13 | Commercial asset proof | No verified evidence in repository | Cohort/retention, paid conversion, MRR/expense export, support and acquisition-channel evidence | Founder/operator |
| BR-14 | Transaction readiness | Open | IP/contractor assignment, asset/account transfer inventory, domains/app-store/cloud transfer plan, clean reproducible handover tag | Founder/operator |

## Dependency order

1. BR-10 creates trustworthy local proof.
2. BR-01 to BR-03 make the core product safe to describe and evaluate.
3. BR-04 to BR-09 close the high-risk customer, security and operating paths.
4. BR-11 and BR-12 produce release evidence.
5. BR-13 and BR-14 determine operating-business valuation and sale readiness.

## Current execution log

### Addendum (2026-07-24) — solo-founder operating model

CoverWise is being prepared as a solo-developer product, not an enterprise
programme. References in earlier entries to “legal” release wording are superseded as release gates: the founder owns the decisions on
Terms, Privacy wording, entity/jurisdiction placeholders, published support
commitments, and dependency-policy exceptions. External professional advice is
optional founder support, not an assumed prerequisite. The technical gates
remain unchanged: published text must be internally consistent, hosted pages
must match the approved source, and the app must not claim to be an insurer,
broker, adviser, or claims administrator.

### Addendum (2026-07-24) — current backend baseline is disk-blocked

The attempted current-worktree backend refresh collected **660 tests** with
**2 skipped**, then exhausted the macOS temporary volume with only **392 MB**
free. Its JUnit record contains **7 failures** and **105 errors**, whose
dominant cause is `OSError: [Errno 28] No space left on device`; this is not
evidence of product regressions and must not replace the earlier clean Tier 2
baseline. No repository or user data was removed. Restore sufficient capacity
through owner-approved cleanup, then re-run the full suite and triage any
non-`ENOSPC` failures before recording a new baseline.

### 2026-07-24 — baseline captured and repaired

- Created the documented Python 3.11 `.venv` and installed
  `requirements-local.txt`. The canonical `tools/run_backend_tests.sh tests/`
  result is **551 passed, 1 skipped** (Tier 2). The prior direct `pytest -q`
  collection failure was an absent local environment, not a failing backend
  assertion.
- Corrected twelve analyzer findings in mobile test-only code without changing
  product behavior. `flutter analyze` now reports **No issues found** (Tier 2).
- `flutter test --concurrency=1 test/feature_flags_test.dart
  test/migration_integrity_test.dart test/sync_integration_test.dart
  test/performance/app_startup_benchmark.dart` reports **32 passed** (Tier 2).
- The first parallel Flutter test attempt hit a full macOS volume. After
  stopping the test process started for this check, 30 inactive rebuildable
  Flutter compiler directories under `/private/var/folders/.../flutter_tools.*`
  were removed, reclaiming approximately 3.1 GB. This was cache-only cleanup;
  no repository or user files were removed.
- The complete mobile suite now succeeds from the documented environment:
  `flutter test --concurrency=1` reports **1,039 passed** (Tier 2). Together
  with the backend suite and clean analyzer run, BR-10's local acceptance
  evidence is complete. It is deliberately not evidence of a release build,
  authenticated production flow, or real-device behavior; those remain in
  BR-04 to BR-12.
- The complete suite initially caught an active Q&A-screen regression before
  runtime tests could start. The repaired retry path now retains the original
  policy document identifier, preventing a retry from silently switching to
  whichever document is currently selected. Focused Q&A and follow-up tests
  then passed (**22 passed**) before the complete suite was re-run.
- A claim-boundary scan found legacy sales/advice funnels in the active Q&A
  and policy-detail CTAs (plan/rate/offer comparisons and adviser referral),
  an unsupported what-if premium calculator in navigation, and dashboard tips
  that inferred benefits from a policy type. Active CTAs now only reopen an
  evidence-backed question about the user's own policy; the calculator route
  is withdrawn from navigation while its legacy implementation remains
  preserved for inventory; dashboard notes now state their evidence limits.
  Focused coverage, Q&A, CTA, policy-review and claim-tracking checks report
  **27 passed** and targeted analysis is clean (Tier 2). This is not a
  substitute for an authenticated corpus or device review.
- The complete mobile suite was rerun after these controls and exited cleanly
  (Tier 2). Its expected error-boundary and offline-path logs are test fixtures,
  not evidence of an unhandled production failure. The suite remains local
  evidence only.
- Static inspection of the account transition confirms that email and Google
  entry points both preserve an anonymous workspace claim before authentication,
  and the app-level auth listener reopens the principal workspace before it
  requests the server-side transfer. The automated test currently proves only
  the single-use local claim intent. BR-04 remains open until this is exercised
  with two real identities against the deployed Supabase/backend path.
- Static Storage/RLS review is aligned with the current Supabase guidance:
  the private bucket has owner-checked select/insert/update/delete policies,
  each constrained to the canonical `documents/{document-id}/...` path. The
  new migration-contract test and deletion lifecycle/write-fence checks report
  **19 passed**. This catches repository drift but cannot prove remote
  migration parity or deny a second real principal; BR-05 remains Tier 1 until
  that account-backed test runs. The durable deletion worker has targeted
  retry/failure tests (Tier 2), but BR-09 remains open until a deployed worker
  drains and exposes an actual deletion job.
- The claims surface is now fenced to a private self-reported log. New API
  requests cannot supply agent provenance; a compatibility-preserving database
  constraint rejects new agent-originated rows; historical agent fields are
  normalized out of API responses; and mobile labels say `Recorded as ...`.
  Focused backend checks report **13 passed**, focused mobile claim checks
  report **41 passed**, and targeted analysis is clean (Tier 2). The remaining
  risk is deployment and authenticated account sync, not a claim decision or
  insurer-status integration; those capabilities are intentionally out of
  scope under [ADR-2026-07-24-02](../../decisions/ADR-2026-07-24-02-personal-claim-log-boundary.md).
- Both complete local suites were rerun after the claims boundary changes and
  completed cleanly. This refreshes BR-10's Tier 2 baseline; it does not
  promote any remote Supabase, payment-provider, deployment, device, store, or
  commercial-evidence gate.
- The active worktree contains parallel, uncommitted changes covering
  Sentry/bootstrap, health/connectivity UI, policy-readiness wording, claims,
  auth and RAG. Those changes require focused tests and a current-state
  re-check before any status may be promoted.
- BR-06 privacy review found a customer-visible retention mismatch: the policy
  stated 30 days for analytics while the unattended retention command fell
  back to 365 days. The canonical fallback is now 30 days, with a focused
  regression test. An explicit environment override is documented as a
  policy-changing release decision requiring founder/operator approval (outside-domain support remains optional). The
  privacy/security screen also now exposes the bundled, versioned policy in
  development/review builds when no hosted URL is injected; previously the
  fallback existed but its entry point was hidden. Focused backend consent,
  retention, lifecycle and deletion checks report **37 passed**; legal/mobile
  checks report **23 passed**; targeted analysis is clean (Tier 2). The
  detailed boundary and external gates are in
  [the privacy readiness review](../../review/PRIVACY_READINESS_REVIEW_2026-07-24.md).
This is not founder-only sign-off, a hosted-page verification, a monitored-support
  proof, an authenticated consent flow, or a scheduled retention-run record.
- BR-04 identity continuity was rechecked against the current machine rather
  than relying on the historical local acceptance record. The canonical
  `tools/verify_local_identity_claim.py` verifier returns a hard guard
  (`FAIL configuration: Supabase publishable and server keys are required`) when
  run without injected `SUPABASE_*` credentials. It also cannot proceed while
  local Supabase, API at `127.0.0.1:8005`, and Docker are unavailable in this
  session. The verifier remains the correct local Tier 3 command after those
  services are started; it creates and cleans up a synthetic account and does
  not upload documents. Existing unit coverage proves link idempotency and
  one-shot claim-intent semantics, but it does not prove email/Google redirect,
  device restart, or deployed storage/evidence transfer. BR-04 therefore
  remains open.
- BR-07 focused billing checks confirm the local authority boundary: a client
  sync cannot grant paid status on its own; authenticated RevenueCat webhook
  events are idempotent and ordered; remote mode queues reconciliation through
  the canonical durable worker; and mobile copy does not call an unverified
  pack balance a completed grant. Backend checks report **53 passed** and
  mobile entitlement/copy checks report **21 passed**, with targeted analysis
  clean (Tier 2). This is still not a RevenueCat sandbox purchase, restore,
  renewal, cancellation/refund, signed real-webhook delivery, or deployed
  server-ledger proof. Those actions require the RevenueCat/store account
  owner, so BR-07 remains open.
- The local and remote billing paths had treated RevenueCat `REFUND_REVERSED`
  as a revocation. They now restore an entitlement only where the provider
  reports a current expiration, using the existing provider timestamp ordering;
  the remote change is a forward-only Supabase migration. Focused billing,
  ledger, outbox, QA usage, and migration-parity contracts report **30 passed**
  (Tier 2). This
  corrects a provider-contract defect but is not a real store refund reversal,
  webhook delivery, or deployed ledger verification; see
  [ADR-2026-07-24-07](../../decisions/ADR-2026-07-24-07-revenuecat-refund-reversal-semantics.md).
- BR-08 now has focused local coverage for the online-but-backend-down warning
  and the offline banner that keeps the local-document boundary clear. Existing
  Q&A and pending-upload retry paths were rerun with those checks: **24 mobile
  tests passed** and targeted analysis is clean. The simulated consent-sync
  timeout log is an intentional test transport failure that confirms retry is
  retained, not a production exception. Sentry startup wiring, health polling,
  and connectivity-triggered reconciliation are code-backed, but no configured
  non-production Sentry event, real device network transition, or deployed
  backend recovery has been observed in this session. BR-08 therefore remains
  below Tier 3.
- BR-09 durable-work checks now cover the canonical queue, worker health
  listener, retry/dead-letter transitions, billing reconciliation, account
  deletion retry, and retention cleanup: **43 backend checks passed**. The
  deployed-launch verifier and dedicated-worker deployment script also pass
  local syntax/interface validation. The worker registers the five job types
  with active production enqueue paths; `qa_response`, `claim_verification`,
  and `renewal_diff` are reserved enum/migration values with no enqueue call
  sites or handlers, so they are explicit inactive migration debt rather than
  a silently dropped active workflow. A real deployed queue round trip,
  deliberate retry/dead-letter recovery, worker health observation, and
  operator runbook execution are still required for Tier 3+ proof.
- BR-11 static release checks report **16 passed** for production configuration
  validation and container/release contracts; the mobile and Cloud Run release
  scripts parse cleanly and fail closed when required public configuration or
signing material is absent. A redacted Gitleaks history scan found historical
  OpenAI-key/JWT-pattern findings in legacy deployment/configuration files,
  while a current-tree shape scan found no OpenAI-key or JWT-shaped literal
  outside documentation/lockfile exclusions. No secret value was displayed or
  copied. This requires owner-led rotation of every possibly exposed credential
  and a deliberate history-retention/rewrite decision; it must not be treated
  as remediated by the current-tree scan. The repository also had no root
  `LICENSE` despite a README MIT claim; the unsupported claim is now removed.
  An actual dependency/license vulnerability scan, signed mobile artifact,
  secret-rotation evidence, and release build with real public defines remain
  open BR-11 acceptance gates.

### Addendum (2026-07-24) — credential-rotation evidence format

The repository now includes a non-secret
[`CREDENTIAL_ROTATION_ATTESTATION_TEMPLATE.md`](../../review/CREDENTIAL_ROTATION_ATTESTATION_TEMPLATE.md)
to turn the historical-scan finding into an auditable owner workflow. It
requires a redacted inventory, provider rotation/revocation evidence,
least-privilege review, post-rotation usage check, and an explicit
retain-versus-rewrite history decision. The template is not an attestation and
does not close BR-11 until the accountable owner completes and reviews it.
- BR-02 evidence-backed Q&A was re-traced through the current pipeline. The
  backend already verifies citations against immutable source text and computes
  the four-face `verification_status`, but the mobile query adapter had dropped
  that field before rendering. Direct and wrapped API envelopes now preserve
  it, so a genuinely `fully_backed` answer can render its evidence-backed
  badge rather than a false `Not verified` warning. Focused mobile adapter,
  model, and badge checks report **23 passed**; backend substrate/citation/
  answer/composite checks report **81 passed** (Tier 2). The token-streaming
  protocol returns only answer text and deliberately stays `unverified`; it
  must not be described as evidence-backed until it emits a final verified
  citation/status payload. No authenticated representative-corpus upload,
  extraction, citation, Q&A replay, or device review has run in this session,
  so BR-02 remains below Tier 3.
- BR-06 access/portability reachability is now closed at the local product
  layer: the signed-in Profile privacy section calls the owner-scoped account
  export endpoint and requires confirmation before handing account metadata
  and short-lived private-source links to the system share sheet. Mobile
  profile/export checks report **12 passed** with targeted analysis clean;
  backend deletion/export checks report **11 passed** (Tier 2). This improves
  the real user workflow without claiming a deployed authenticated export,
  owner validation, or actual deletion-worker completion. Those BR-06 gates remain
  open as described in the privacy readiness review.
- BR-01/BR-03 active-navigation review identified an unsupported legacy
  “advisor requests” route. Its reachable entry points implied a partner
  advisor workflow even though no verified advisor service, partner, or
  customer handoff exists. The route and More-menu entry are now withdrawn;
  legacy source remains preserved for inventory rather than being represented
  as an active capability. A dedicated navigation contract and the app smoke
  test report **2 passed**, and the affected dashboard surface analyzes clean
  (Tier 2). During that smoke check, current dashboard integration errors were
  repaired (missing shared error-view import, stale constructor arguments, and
  named status-tile arguments), and the dashboard analyzer is clean. This
  prevents an unsupported customer-facing claim and restores the current app
  build, but it is not a complete public-copy, device, or deployed-review gate.
- BR-03 review also found that the dashboard called an evidence-limited screen
  “Coverage gaps,” said “Check what's missing,” and passed a bare document ID
  to a route that requires a document-ID argument map. The active action now
  says “Coverage details,” asks the user to review cited policy fields, and
  passes the canonical route contract. The coverage contract, coverage-screen
  widget cases, and app smoke test report **8 passed**; the three affected
  files analyze cleanly (Tier 2). This removes a misleading inference and a
  deep-link/navigation failure, but does not turn limited cited fields into a
  complete coverage assessment.
- The full mobile suite initially exposed two stale dashboard test modules
  still importing a removed `recentQuestionsProvider` and asserting a retired
  dashboard layout. They are now aligned to the current first-policy,
  evidence-bound coverage, expiry-priority, and retryable-error contracts.
  The complete serial mobile suite reports **1,038 passed** (Tier 2). This is
  local regression evidence only; it does not promote BR-01, BR-03, or any
  external runtime/release gate beyond their stated scopes.
- The legacy product TODO contained historical `ALL DONE`, production-readiness,
  agent-connection, and coverage-gap completion wording that a buyer could
  misconstrue as current operating proof. A dated addendum now directs readers
  to this register, expressly withdraws the unsupported advisor workflow, and
  restates the evidence-limited coverage and personal-claim-log boundaries.
  This is a documentation correction (Tier 1), not evidence that any external
  gate has been closed.
- BR-06 now fails the Android release preflight when publishable legal sources
  drift from their packaged copies or contain known unresolved legal markers.
  The current `[Jurisdiction]` marker correctly blocks the release; legal
  parity/preflight tests report **3 passed** and shell syntax is valid (Tier
  2). This closes the silent-shipping risk, not the underlying legal decision:
  founder or the accountable owner must still supply and approve the governing
  law, entity/controller, hosted pages, and operating process before BR-06 can
  be promoted.
- BR-11 direct production-dependency and tracked release-source scans are now
  reproducible through `tools/run_supply_chain_audit.sh`. The first direct-pin
  audit identified 46 known vulnerability records across six packages; their
  pins were upgraded, including the OpenAI client needed to remain compatible
  with the already-pinned HTTPX transport. The remediated direct scan reports
  **0 known vulnerabilities across 31 declared production dependencies** and
  Gitleaks reports no leak in the tracked release-source scan (Tier 2). The
  affected fallback/RAG/runtime checks report **65 passed** and the complete
  backend suite reports **596 passed, 1 skipped**. This does not cover an
  independently hash-locked transitive graph, historical credential rotation,
  vendor-account proof, or a signed store artifact. After the reservation fix,
  a current full Ruff scan reports 146 repository-wide findings outside this
  supply-chain change;
  they remain an explicit engineering cleanup gate rather than being hidden by
  automated mass deletion.
- The initial Ruff classification also exposed one non-mechanical upload
  cleanup defect: the nested rollback function assigned the outer policy-slot
  reservation identifier without declaring it `nonlocal`, so an outbox failure
  could raise before releasing the reserved slot. The rollback now explicitly
  binds and clears the outer reservation, with a source-contract regression
  test. Focused upload/outbox/reservation checks report **11 passed** and the
  affected source is Ruff-clean (Tier 2). The wider Ruff backlog remains open.
- The declared production dependency audit is now a dedicated CI job and the
  Docker publication job waits for it. The workflow YAML parses and the same
  audit reports no known vulnerability for the current declared pins locally
  (Tier 2 configuration evidence). CI execution on the remote provider, a
  hash-locked transitive graph, historical secret rotation, and signed-artifact
  proof remain separate open BR-11/BR-12 gates.
- BR-04 was rechecked on the current workstation. The local identity verifier
  correctly refuses to run without exported local Supabase publishable/server
  keys; the Supabase CLI (v2.109.1) also reports that Docker is unavailable,
  and neither the local Supabase nor API listener is running. No remote
  credential, account, storage, or document was touched. The exact next proof
  remains: start Docker and the local stack/API, provide only local test keys,
  then run `tools/verify_local_identity_claim.py` to create and clean up its
  synthetic account. This is a current blocked runtime gate, not a failed
  product assertion.
- BR-11 CI configuration review found a deterministic stale build gate: the
  workflow installed Node 16 and ran `npm install`/`npm run build` at the
  repository root despite there being no `package.json`, lockfile, Tailwind
  input, or Node-owned frontend. The active web surface serves checked-in CSS
  from the Python application and the mobile client is built by Flutter. The
  dead Node steps are removed, and the developer guide now records this source
  of truth while preserving its older Compose guidance as historical
  compatibility material. The workflow YAML parses locally (Tier 2
  configuration evidence); a remote CI execution remains required before this
  is treated as a live-pipeline result.
- BR-01/BR-03 public-surface review found that the served web template still
  promised coverage-gap finding and claim filing, while the private mobile
  claim log still used a filing label and implied its stored photos could help
  an insurer. The public template now limits questions to cited policy steps
  and available policy details. The mobile entry is `Record a claim`, visibly
  states that it is an on-device note only, and describes photos as the user's
  own preparation material. The root-route/copy contract reports **3 passed**;
  claim-log widget checks report **30 passed** and affected Flutter analysis
  is clean (Tier 2). The unreferenced legacy `landing.html` template remains
  preserved for inventory but is not a public route. This is not a full device
  review, production copy approval, legal support review, or authenticated corpus
  proof, so BR-01/BR-03 remain open at their stated boundary.
- BR-11 resolver review found that the declared production OCR profile was
  internally unsatisfiable: `python-doctr==1.0.1` requires
  `huggingface-hub>=0.20.0`, while the shared requirements pinned 0.17.3.
  The profile also requested a non-existent docTR `torch` extra and used a
  yanked email-validator release. The direct pins now use
  `huggingface-hub==0.36.2`, `email-validator==2.3.0`, and the plain
  `python-doctr==1.0.1` package; Torch remains explicitly installed by the
  container. `uv pip compile --generate-hashes --python-platform
  x86_64-manylinux_2_17 requirements-production-ocr.txt` resolves **122
  packages**, and the direct vulnerability/secret audit remains clean (Tier
  2). macOS `pip check` still reports the expected non-Linux Torch 2.1
  compatibility warning, so the Linux resolver—not a local Torch import—is the
  relevant container evidence. A committed platform-aware hash lock, complete
  SBOM, container build, and remote CI run remain required before release
  provenance can be claimed.
- BR-11 now has a committed platform-specific transitive lock:
  `requirements-production-ocr-linux-x86_64.lock` resolves the actual Linux
  x86_64 CPU-Torch graph with hashes. The Dockerfile installs this lock with
  `--require-hashes` and the CPU Torch index, while CI recompiles the graph and
  rejects lock drift after normalizing the generated command header. The
  normalized lock comparison and container contract tests report **3 passed**
  (Tier 2). Docker is unavailable on this workstation, so no local image build
  or runtime import is claimed; CI execution, an immutable image/SBOM, image
  scan/signing, and deployment proof remain separate gates.
- The first full audit of that lock intentionally did **not** pass: it reports
  **15 known vulnerabilities across three transitive packages**. `starlette`
  0.46.2 is selected by the direct FastAPI pin; `pyasn1` 0.4.8 and `ecdsa`
  0.19.2 are selected by direct `python-jose`, used only by the anonymous JWT
  helper. The pyasn1 and Starlette advisories list upgrade paths, while the
  ecdsa advisory has no listed fixed release. This is an explicit BR-11
  remediation gate: upgrade the owning direct dependencies with auth and API
  regression coverage, or replace the JWT library after a recorded security
  decision. It must not be concealed by a transitive override. The audit also
  cannot query the CPU-suffixed Torch wheels on PyPI; their lock hashes and
  upstream CPU index remain the provenance evidence pending container scan.

### Addendum (2026-07-24) — anonymous JWT dependency remediation

The anonymous identity helper uses only server-issued HS256 tokens. The direct
JWT dependency was therefore migrated from `python-jose` to `PyJWT==2.13.0`
under ADR-2026-07-24-03, preserving issuer, audience, expiry, anonymous
subject fencing, and bounded key rotation. Production now rejects active or
previous HMAC keys shorter than 32 bytes. Focused anonymous-auth and container
profile contracts report **15 passed** and focused Ruff is clean (Tier 2).

The regenerated Linux x86_64 lock has **105 packages**. Its full audit is
improved from 15 findings across three packages to **9 findings in
`starlette==0.46.2` only**; `pyasn1` and `ecdsa` no longer occur. The current
FastAPI `0.115.14` contract and latest available `0.139.2` both constrain
Starlette below 0.47, while audit fixes require a newer Starlette release. No
incompatible transitive override was made. BR-11 remains open for a compatible
FastAPI/Starlette release or a separately reviewed framework migration. The
CPU-suffixed Torch wheels remain unauditable through PyPI and require a
container-image scan.

### Addendum (2026-07-24) — FastAPI and Starlette security baseline

Current upstream metadata made a compatible remediation path available. The
direct framework policy now pins FastAPI **0.139.2** and Starlette **1.3.1**;
the canonical Linux lock was regenerated under
ADR-2026-07-24-06. Its full `pip-audit` result reports **no known
vulnerabilities**. CPU-suffixed Torch and Torchvision wheels remain reported
as unavailable on PyPI, so their provenance and image scan remain open rather
than being represented as audited.

The complete backend runner completed under this pair after collecting **615
tests with 2 skips** (Tier 2). This replaces the dated constraint snapshot in
the preceding addendum; it is local dependency and contract evidence, not a
container build, remote CI, authenticated deployment, or production runtime
verification.

### Addendum (2026-07-24) — local identity verifier egress guard

The synthetic guest-to-account verifier now refuses both non-local Supabase
and non-local API URLs before it creates an account or sends any request. Its
previous guard covered only Supabase, despite the tool being documented as
local-only. Focused verifier, anonymous-auth, and production-configuration
contracts completed cleanly (Tier 2). Docker remains unavailable on the
current workstation, so the actual synthetic-account replay and the BR-04/05
runtime evidence remain open.

### Addendum (2026-07-24) — local two-principal isolation replay

`tools/verify_local_tenant_isolation.py` prepares the local BR-05 replay: it
creates two disposable users, uploads a generated PDF through the canonical
API as principal A, verifies that B is denied by both API and authenticated
Storage, deletes the document as A, checks post-delete absence, and removes
both accounts. It rejects non-local targets and absent local keys before any
request. Fourteen focused verifier, tenant-isolation, and Storage-policy tests
passed (Tier 2); this workstation correctly stopped at missing local keys and
Docker. The verifier is a prepared local runtime gate, not deployed RLS,
durable account-deletion, or production-erasure evidence.

### Control-chunk review (2026-07-24) — local two-principal isolation replay

**Pass 1 — immediate correctness:** Remote-target guard, multipart synthetic
PDF composition, owner-scope, and Storage-policy contracts completed (14
tests).

**Pass 2 — architecture and long-term viability:** The tool uses the
canonical document API and user bearer tokens for Storage; it does not use an
admin key to claim RLS behavior.

**Pass 3 — supervision readiness:** Account cleanup runs in `finally`; the
runbook names the command and its explicit deployed-worker limitation.

**Anything else?** Yes: a Storage denial from this local replay proves only
the local policy/runtime combination. The separate deployed two-principal and
durable account-deletion observations remain required before BR-05 can close.

### Addendum (2026-07-24) — current local evidence-contract baseline

The representative-corpus contract was reconciled with the canonical answer
verifier: an uncited material statement is `abstained`, rather than being
misrepresented as trivially fully backed. The BR-05 tenant-isolation contract
now uses the actual owner-scoped repository API and a correctly shaped
substrate mock, instead of obsolete repository methods and mock signatures.
The focused BR-02/BR-05 suites completed **16 tests** (Tier 2).

Starlette 1.3's test client requires `httpx2`; it is pinned only in
`requirements-local.txt`, leaving the production HTTPX client and production
lock unchanged. The current complete backend runner collected **645 tests
with 2 skips** and completed under this test transport (Tier 2). None of this
proves a remote RLS policy, real two-principal denial, storage deletion,
durable-worker execution, or a deployed runtime.

### Addendum (2026-07-24) — production Host boundary

ADR-2026-07-24-04 adds a second, application-side defence while the remaining
Starlette advisories are blocked on compatible upstream releases. The
canonical API now requires hostname-only `ALLOWED_HOSTS` in production and
binds that value to `TrustedHostMiddleware`; missing, wildcard, URL-shaped, or
malformed host values fail closed. Configuration and middleware contracts
report **43 passed** (Tier 2), including an isolated production import of the
canonical API that returns 200 for its configured Host and 400 for a malformed
one. The actual deployment host list and a real edge-to-container request
remain runtime/account-owner proof, so this does not close BR-11 or replace
the locked-graph audit.

### Control-chunk review (2026-07-24) — JWT and Host remediation

**Pass 1 — immediate correctness:** The direct JWT dependency changed only at
the canonical anonymous-token helper. Time claims were normalized to the
existing API response contract; issuer, audience, expiry, subject fencing,
rotation and generic invalid-token handling are covered. The production Host
parser rejects absence, wildcards and URL-shaped values.

**Pass 2 — architecture and long-term viability:** No new identity route,
token issuer, middleware path, or configuration truth source was introduced.
`PyJWT` replaces an unused asymmetric-capability surface, while
`ALLOWED_HOSTS` is a deployment input validated beside the existing CORS and
public-site settings. Both decisions have durable ADRs.

**Pass 3 — supervision readiness:** 58 focused tests passed; the changed
utility and focused test modules are Ruff-clean; `git diff --check` is clean.
The full lock audit still reports nine Starlette findings and CPU Torch wheels
remain outside PyPI audit coverage. The closure path is explicit: compatible
FastAPI/Starlette release (or reviewed migration), container image scan, and
deployed Host-header smoke test with the real allow-list.

### Addendum (2026-07-24) — reproducible production SBOM

`tools/generate_production_sbom.sh` now generates a CycloneDX inventory from
the canonical Linux x86_64 hash lock without overwriting prior evidence. A
real generation produced **103 components** (Tier 2) and deliberately reported
the same nine unresolved Starlette findings rather than calling the audit
clean. SBOM generation is complete as a local control; license-policy
approval, artifact publication, container SBOM/image scan, signing, and
release provenance remain BR-11/BR-12 gates.

License inspection of that generated inventory found **0 populated license
fields across 103 components**. This is a data-quality gap, not proof that
dependencies lack licenses. BR-11 requires an authoritative metadata source,
an exception review, and accountable legal/owner approval before an SBOM can
support a buyer or release claim.

### Addendum (2026-07-24) — mobile baseline refresh

The full mobile suite was rerun serially from the current worktree with
`flutter test --concurrency=1`, and `flutter analyze --no-fatal-infos` reported
no issues (Tier 2). This refreshes only BR-10's local reproducibility evidence;
it does not evidence a signed release build, real device, store review,
authenticated provider flow, or production deployment.

The backend suite was also rerun through `tools/run_backend_tests.sh tests/`:
it collected **608 tests with 2 skips** and completed cleanly (Tier 2). Its
scope remains local contracts and integrations; it does not replace a running
Supabase, provider, container, or deployment acceptance check.

### Addendum (2026-07-24) — safe Ruff cleanup, batch one

The full `src`/`tests` Ruff scan began at 144 findings. A reviewed,
semantic-no-op batch removed 14 extraneous f-string prefixes and statement
terminating semicolons, reducing the count to **130**. Forty-five affected
tests passed with one skip (Tier 2), and the diff is whitespace-clean. The
remaining import and structural findings are intentionally not mass-fixed:
legacy/optional-dependency modules and startup ordering need per-module
ownership review so lint cleanup does not remove compatibility behavior.

### Addendum (2026-07-24) — safe Ruff cleanup, batch two

A second module-by-module review removed **18** proven-unused standard-library,
typing, and Pydantic imports from active API, model, OCR, RAG, service, and
utility modules. Optional integrations and legacy imports with possible
initialization behavior were excluded. Targeted consent, evidence, repository,
OCR, outbox, anti-abuse, and fallback contracts completed cleanly; the changed
modules are Ruff-clean, `git diff --check` is clean, and the full count is now
**112**. This is Tier 2 cleanup evidence, not a claim that the full Ruff gate
has closed.

### Addendum (2026-07-24) — encrypted payload helper clarity

The authenticated-encryption envelope now uses a named URL-safe-base64 helper
instead of an inline lambda. Its wire format and cryptographic operations are
unchanged; 18 payload round-trip, tamper, and owner-isolation checks passed
(Tier 2). The module is Ruff-clean and the full scan is **111** findings.

### Addendum (2026-07-24) — import-layout cleanup boundary

Four active API/test multi-import layout findings were split without changing
the imported symbols; 34 evidence-substrate tests passed (Tier 2), leaving
**107** full-scan findings. The sole remaining E401 is in
`src/policy_rag_hybrid.py`, an optional legacy module whose broader unused
imports and dependencies need a compatibility decision rather than a
mechanical edit.

### Addendum (2026-07-24) — cryptographic key-length consistency

Anonymous JWT signing, encrypted processing inputs, and production
configuration preflight now all measure secrets as UTF-8 bytes, with consistent
32-byte wording. This removes a Unicode-character-count mismatch at the
security boundary; regression coverage includes multi-byte values and reports
**61 passed** across auth, encryption, configuration, and production-health
contracts (Tier 2). Production deployment still requires real secret-manager
values and runtime validation.

### Addendum (2026-07-24) — entrypoint import-order decision

ADR-2026-07-24-05 records the canonical API's intentional bootstrap-before-
service-import and API-before-frontend-mount ordering. A scoped Ruff E402
deviation makes that architectural contract explicit; the last unrelated test
E402 was fixed by moving its `asyncio` import. The full E402 class is clean,
47 targeted tests passed, and the full Ruff count is **81**. This is a reasoned
deviation, not a hidden lint suppression or a change to startup semantics.

### Addendum (2026-07-24) — integration-test clarity

The integration fixture now asserts that its declared policy number occurs in
the sample policy text before checking extracted entities; boolean expectations
use direct truth assertions, and two unused test imports are removed. Five
integration tests passed (Tier 2) and the full Ruff count is **75**. This run
used an explicitly created temporary directory because the workstation's
default Python temporary-directory selection was unavailable despite writable
disk space; that is recorded as local environment friction, not a product
assertion.

### Addendum (2026-07-24) — test import cleanup

Thirty-seven imports proven unused by Ruff were removed from test modules only;
no production or optional legacy module import was changed in this batch. The
full backend runner collected **610 tests with 2 skips** and completed cleanly
with an explicit temporary directory (Tier 2). The complete test F401 class is
clean; the full Ruff count is **38**, with remaining findings confined to
active-source imports and the reviewed legacy module.

### Addendum (2026-07-24) — active import cleanup

Twelve proven-unused pure imports were removed from the canonical API,
frontend, RAG service, and evidence modules; their targeted frontend,
configuration, health, pipeline, and substrate contracts completed under an
explicit temporary directory (Tier 2). Those modules are Ruff-clean and the
full count is **26**. The deprecated OCR service, optional legacy module, and
abandoned streaming-timing variable remain deliberately outside this batch
pending their own compatibility/observability decisions.

### Addendum (2026-07-24) — deprecated OCR import cleanup

Two imports (`Depends` and `List`) proven unused in the deprecated OCR
compatibility service were removed without changing its route or runtime
behavior. Its runtime-selection and mobile-sidecar contracts completed under
an isolated temporary directory (Tier 2); the full Ruff count is **24**. The
legacy prototype module and abandoned streaming-timing variable remain
separate decisions rather than being hidden by a blanket suppression.

### Addendum (2026-07-24) — streaming-timer cleanup

The stream generator contained an assigned `start_time` that was never
reported or connected to the canonical query-trace path. It was removed rather
than represented as a misleading latency control; adding meaningful streaming
observability requires a separate lifecycle design for success, early return,
failure, and client disconnect. The RAG pipeline suite passed (**9 tests**;
Tier 2), and the full Ruff count is **23**.

### Addendum (2026-07-24) — legacy prototype decision gate

`src/policy_rag_hybrid.py` compiles but is only a 25-line header/import shell:
it has no executable application structure or repository caller. It remains
preserved pending explicit owner approval to archive/remove it or fund a
supported rebuild. The decision, buyer impact, evidence, and closure criteria
are recorded in
`docs/review/policy_rag_hybrid_legacy_module_review_2026-07-24.md`. It is not
hidden behind a lint suppression or represented as a supported product surface.

### Addendum (2026-07-24) — transaction evidence preparation

The repository lacked a buyer-usable transaction pack. A non-secret
[`TRANSACTION_READINESS_EVIDENCE_PACK_TEMPLATE.md`](../../review/TRANSACTION_READINESS_EVIDENCE_PACK_TEMPLATE.md)
now inventories the proofs required for IP, source, cloud/Supabase/store
accounts, customer liabilities, security/privacy, commercial records, and a
controlled handover rehearsal. It explicitly distinguishes a transferable
software asset from an operating-business sale. This is Tier 1 preparation;
BR-13 and BR-14 remain open until owners supply current evidence and execute
the acceptance record.

### Addendum (2026-07-24) — locked licence-metadata evidence

`tools/extract_locked_license_metadata.py` now generates a deterministic
licence-review candidate from the canonical production lock and the package
metadata of the chosen interpreter. It refuses overwrites and explicitly
records package absence, version mismatch, empty metadata, and the absence of
legal approval. Focused tool contracts passed (**3 tests**, Tier 2). On the
current local interpreter, **99 of 105** locked components matched exactly and
declared metadata; **six** had interpreter-version mismatches. This is
engineering evidence preparation only: it does not certify the Linux release
artifacts, select a licence policy, approve exceptions, or close BR-11.

### Control-chunk review (2026-07-24) — SBOM generation

**Pass 1 — immediate correctness:** The generator reads the release lock with
hash enforcement, validates its CycloneDX JSON output, refuses overwrite, and
does not reinterpret an audit finding as success.

**Pass 2 — architecture and long-term viability:** One canonical Linux lock
is the input to Docker, CI drift detection, audit and SBOM generation. The
generator adds no second dependency graph or package inventory.

**Pass 3 — supervision readiness:** A real output contains 103 components;
the source contract reports 4 passed and is Ruff-clean. The artifact was
written outside the repository for inspection and not published or committed.
The owner must approve the license policy and attach a scanned, signed release
artifact before this becomes buyer-grade provenance.

### Addendum (2026-07-24) — public legal release fail-closed control

The public FastAPI frontend now invokes the same canonical legal-asset
preflight used by the mobile release command before it starts in production.
If the publishable and packaged sources drift or contain a known unresolved
marker, it refuses startup and records only the number of errors in structured
logs. The current Terms contain `[Jurisdiction]`, so a production frontend is
intentionally blocked until the founder/owner supplies and
approves the decision. The focused preflight/frontend contract passes (**3
tests**, Tier 2). This does not create hosted legal pages, provide legal
approval, prove a deployed startup, or close BR-06; it prevents the public web
surface from bypassing the same incomplete-legal release boundary.

### Addendum (2026-07-24) — bounded claims navigation restored

The More screen had retained a stale comment saying the claim guide and
personal claim log were not implemented, although both canonical routes and
their focused screens exist. The active navigation now exposes those two
surfaces with explicit limits: CoverWise does not file or manage a claim, and
log statuses are not verified by CoverWise. This restores a discoverable user
workflow without reintroducing the withdrawn advisor/partner path or implying
insurer authority. The focused mobile navigation contract reports **2 passed**
and the affected source/test analyze cleanly (Tier 2); this remains local
evidence, not insurer integration, a filed claim, or a device/runtime proof.

### Control-chunk review (2026-07-24) — claims navigation

**Pass 1 — immediate correctness:** Verified both target routes exist and the
navigation contract asserts the claim guide, personal-log route, and bounded
copy.

**Pass 2 — architecture and long-term viability:** Reused the existing
screen/routes and private claim-log model; no API, provider, status authority,
or parallel workflow was added.

**Pass 3 — supervision readiness:** The wording names the user action and its
limit. A reviewer can distinguish a local record/preparation aid from insurer
claim filing, management, adjudication, or verification.

### Addendum (2026-07-24) — active product-role copy alignment

The public API description and active onboarding/first-upload copy no longer
call CoverWise a broker or characterize its public page as “launch-ready
marketing.” They now use the canonical product role: a policy information
assistant, not an insurer, agent, or broker. Public frontend contracts report
**8 passed**; the mobile copy/navigation contracts report **3 passed** and the
four affected mobile files analyze cleanly (Tier 2). This corrects active local
copy but does not constitute a full device review, owner support-review, or a
complete inventory of preserved legacy artifacts.

### Control-chunk review (2026-07-24) — product-role copy alignment

**Pass 1 — immediate correctness:** Checked the served frontend source and
both active mobile entry points; focused tests assert the prohibited broker and
marketing wording is absent. The rendered OpenAPI contract also excludes the
non-API favicon endpoint, avoiding duplicate operation metadata.

**Pass 2 — architecture and long-term viability:** Reused the canonical
policy-information-assistant boundary already present in the legal source and
claim registry. No new domain role or service claim was introduced.

**Pass 3 — supervision readiness:** The wording gives a purchaser a clear
limit on product authority. Legacy advisor code remains preserved and
withdrawn, not relabeled as a supported offering.

### Addendum (2026-07-24) — canonical public legal-page delivery

The public frontend now exposes `/privacy` and `/terms`, rendering the exact
publishable Markdown source held in `docs/legal/` without a second legal-copy
format. Each response carries the source SHA-256 in the page and response
header and is `no-store`; the production Docker image now includes that
canonical directory, as do the generated AWS and Azure legacy images. The
sitemap includes both pages. Focused frontend, legal, and container contracts
report **19 passed** (Tier 2). This makes future
hosted-page comparison auditable, but does not resolve the Terms placeholder,
prove DNS/TLS deployment, or convert generic URLs into immutable, legally
approved endpoints.

### Control-chunk review (2026-07-24) — public legal-page delivery

**Pass 1 — immediate correctness:** Exercised both routes, source hashes,
no-store headers, footer links, sitemap entries, source parity, and the Docker
copy contract.

**Pass 2 — architecture and long-term viability:** The frontend reads the
same `docs/legal/` source that mobile parity and the release preflight validate;
the canonical and generated legacy containers explicitly ship that source
rather than an independently edited template. Those legacy scripts remain
separate deployment paths requiring their own owner-led production review.

**Pass 3 — supervision readiness:** A reviewer can compare a hosted response
to the approved source via its SHA-256. The current placeholder still stops a
production process before a public launch can occur.

### Addendum (2026-07-24) — hosted legal-page verification tool

`tools/verify_hosted_legal_documents.py` provides the BR-06 owner a
credential-free, repeatable deployment check. It refuses non-HTTPS endpoints,
then verifies status, `no-store`, page/header SHA-256, and the exact rendered
canonical source for `/privacy` and `/terms`. Its focused tool contract reports
**4 passed** (Tier 2), including a bounded-response check. It cannot provide a
URL, resolve the legal placeholder,
or make a hosted page immutable; the accountable owner must deploy approved
sources and retain the verifier output as part of the release evidence.

### Control-chunk review (2026-07-24) — hosted legal-page verifier

**Pass 1 — immediate correctness:** Tests cover matching pages, refusal of
non-HTTPS URLs before a network call, cache/hash/metadata/source drift, and a
bounded-response failure.

**Pass 2 — architecture and long-term viability:** The verifier reads the
canonical `docs/legal/` files and the public-page hash contract; it adds no
legal copy, credential, or second version registry.

**Pass 3 — supervision readiness:** The owner receives a precise pass/fail
record for a deployment, while unresolved legal and hosting authority remain
visible release gates.

### Addendum (2026-07-24) — mobile release requires hosted legal parity

`tools/build_mobile_release.sh` now runs the hosted-document verifier after
the canonical local legal preflight and before Flutter analysis or signing. It
passes the configured Privacy and Terms URLs directly, so a release build can
only proceed after those HTTPS responses match the approved sources. A static
release-gate contract plus the verifier checks report **8 passed** (Tier 2).
This does not manufacture a host, settle the unresolved Terms placeholder, or
constitute owner approval; it prevents a configured build from silently
skipping the hosted-parity check.

### Control-chunk review (2026-07-24) — mobile hosted-legal release gate

**Pass 1 — immediate correctness:** The release script calls the existing
verifier with both configured legal URLs after validating local assets; the
focused contract confirms that wiring.

**Pass 2 — architecture and long-term viability:** The gate reuses the single
canonical verifier and `docs/legal/` sources rather than copying content or
adding a parallel release check.

**Pass 3 — supervision readiness:** A failed hosted response stops the local
release before Flutter work begins. The accountable owner still must retain a
successful deployment result and complete founder/operator attestation.

### Addendum (2026-07-24) — legal-page markup-injection hardening

The public legal renderer now escapes the source before it enters the HTML
document and sends a page-specific CSP, `nosniff`, and no-referrer policy. A
focused regression substitutes hostile source markup and proves it remains
visible text, not executable HTML. Focused legal/frontend and verifier checks
report **16 passed** (Tier 2). This protects the render boundary but does not
approve the document text, replace a broader web security review, or promote
BR-06 beyond its current evidence tier.

### Control-chunk review (2026-07-24) — legal-page render boundary

**Pass 1 — immediate correctness:** Verified both normal legal pages retain
their canonical content and source hashes, while hostile markup is escaped.

**Pass 2 — architecture and long-term viability:** Preserved one legal source
and relied on Jinja's default escaping plus response headers; no sanitizer,
second renderer, or mutable user-content path was introduced.

**Pass 3 — supervision readiness:** The response policy narrows execution and
embedding exposure. The test gives reviewers repeatable proof of the precise
rendering guarantee and its limit.

### Addendum (2026-07-24) — Terms product-role contradiction guard

The canonical Terms called CoverWise an “information broker” while separately
stating it is not a broker. `tools/validate_legal_release_assets.py` now blocks
that phrase in the Terms as well as unresolved placeholders. The current
preflight intentionally fails with both findings, and **16** legal/frontend
contracts pass (Tier 2). The safeguard does not select replacement legal text
or constitute approval; founder or the accountable owner must resolve the
contradiction before production can start.

### Control-chunk review (2026-07-24) — Terms product-role contradiction

**Pass 1 — immediate correctness:** The preflight emits a precise terms-only
failure and the contract asserts both known current blockers.

**Pass 2 — architecture and long-term viability:** The check reuses the
canonical publishable/mobile parity source and production-startup guard; no
separate legal document or product-role definition was added.

**Pass 3 — supervision readiness:** The release cannot silently convert a
known contradiction into public wording, while the business/legal owner keeps
authority to choose the approved replacement.

### Addendum (2026-07-24) — support/data-rights execution record

The repository now includes
`docs/review/SUPPORT_AND_DATA_RIGHTS_OPERATIONS_ATTESTATION_TEMPLATE.md` for
the BR-06 operations owner. It requires named ownership, request intake,
identity verification, escalation, approved response targets, a synthetic
non-production exercise, and explicit exceptions without recording customer
data or credentials. This is Tier 1 preparation only; it does not prove a
monitored mailbox, legal compliance, or real customer response performance.

### Control-chunk review (2026-07-24) — support/data-rights operations record

**Pass 1 — immediate correctness:** Checked the template exists and every
privacy-review reference resolves to it. It names the request classes and
requires a synthetic exercise rather than a declaration alone.

**Pass 2 — architecture and long-term viability:** The template points to the
existing consent, export, deletion, and support boundaries; it introduces no
parallel case-management system or unapproved response commitment.

**Pass 3 — supervision readiness:** It assigns accountable owners and
reviewers, records evidence locations without sensitive data, and requires
open exceptions to have closure conditions.

### Addendum (2026-07-24) — provider-accurate billing evidence procedure

The canonical runtime-gate runbook now includes BIL-01 for BR-07. It requires
a store-test purchase, restore, cancellation, refund/expiry outcome where the
platform permits it, real provider webhook/outbox/ledger evidence, duplicate
delivery, ordering behavior, and a final server-entitlement read. The
procedure records unsupported store-test actions as exceptions rather than
passing them by simulation. This is Tier 1 preparation; RevenueCat/store
account-owner execution remains required for Tier 3+ evidence.

### Addendum (2026-07-24) — observability and worker-recovery procedure

The canonical runtime-gate runbook now adds OBS-01 for a non-production crash
arrival, sanitized event visibility, device/emulator offline/backend recovery,
and named triage ownership. Its existing ASYNC-01 section now also requires a
deployed worker health observation and a synthetic job restart/reclaim result.
Both procedures explicitly prohibit customer data and do not treat a local
unit test, DSN configuration, or console log as runtime proof. This is Tier 1
preparation; cloud and observability account-owner execution is required for
BR-08/BR-09 Tier 3+ evidence.

### Control-chunk review (2026-07-24) — observability and worker recovery

**Pass 1 — immediate correctness:** Checked OBS-01 names the crash-arrival,
device recovery, triage, and sanitized-evidence steps, while ASYNC-01 adds
health and restart/reclaim observations to the existing retry matrix.

**Pass 2 — architecture and long-term viability:** The procedure follows the
existing mobile error boundary, health endpoints, canonical outbox, and worker
lease/retry model. It does not introduce a second queue or reporting path.

**Pass 3 — supervision readiness:** It names a triage owner, prohibits
customer data, and requires observed runtime evidence rather than treating
configuration or local tests as closure.

### Addendum (2026-07-24) — deployed runtime verifier transport boundary

`tools/verify_deployed_launch.py` now rejects non-HTTPS API and worker URLs
before it makes any request. This prevents a release evidence run from silently
checking a plain-HTTP endpoint. Focused worker-health, outbox lease/retry/dead
letter, and deployed-verifier contracts report **45 passed** (Tier 2). It does
not prove a cloud service exists, that a worker drained a real job, or that an
operator observed restart/reclaim recovery.

### Control-chunk review (2026-07-24) — deployed runtime verifier transport

**Pass 1 — immediate correctness:** Added a no-request non-HTTPS regression
case and reran the worker health, dispatcher, lease, and dead-letter suites.

**Pass 2 — architecture and long-term viability:** Extended the existing
deployed verifier only; the canonical API, health listener, and outbox worker
contracts remain unchanged.

**Pass 3 — supervision readiness:** Operators get an explicit early failure
for an insecure evidence target, while the required deployed worker run and
recovery observation stay visible as owner-executed gates.

### Addendum (2026-07-24) — worker-required runtime evidence mode

The deployed verifier now supports `--require-worker`, which fails before any
network request unless a worker endpoint is supplied. ASYNC-01 in the canonical
runtime-gate runbook requires this mode, so a healthy API by itself cannot be
misrepresented as durable-worker evidence. The 45 focused worker/verifier
checks remain Tier 2; an actual internal worker URL, deployment revision, and
synthetic restart/reclaim observation are still external-owner evidence.

### Control-chunk review (2026-07-24) — billing evidence procedure

**Pass 1 — immediate correctness:** Checked the procedure against the current
webhook/event code and the provider's current primary documentation; it covers
the acceptance evidence named by BR-07.

**Pass 2 — architecture and long-term viability:** The runbook follows the
existing canonical flow—provider webhook, durable outbox, transactional ledger,
then server entitlement read—rather than trusting a client-side plan mirror.

**Pass 3 — supervision readiness:** It requires redacted evidence, names
unsupported platform actions as exceptions, and prevents a dashboard test or
synthetic payload from being represented as a real revenue lifecycle.

### Addendum (2026-07-24) — refund-reversal entitlement correction

RevenueCat's documented `REFUND_REVERSED` event was incorrectly interpreted
as a revocation in both the local webhook path and the remote ledger function.
The paths now agree: a reversal restores an entitlement only while the
provider-reported expiration is current; an expiration still revokes it. The
remote change is a new forward migration, not an edit to historical ledger
migrations. Focused billing, ledger, outbox, and QA usage contracts report
**30 passed** including migration-parity checks (Tier 2). A real provider event
and deployed ledger read remain
required; see [ADR-2026-07-24-07](../../decisions/ADR-2026-07-24-07-revenuecat-refund-reversal-semantics.md).

### Control-chunk review (2026-07-24) — refund-reversal entitlement semantics

**Pass 1 — immediate correctness:** Regression coverage verifies a
future-expiry reversal restores access and a past-expiry reversal does not.

**Pass 2 — architecture and long-term viability:** Both local compatibility
and production ledger paths apply the same provider-expiry and timestamp
authority; no client-side grant or parallel entitlement source was added.

**Pass 3 — supervision readiness:** The ADR documents the provider evidence,
forward-migration rollback path, and the still-required real event/ledger
observation.

### Addendum (2026-07-24) — standalone maintenance-tool lint review

An expanded full-Ruff scan surfaced 55 findings after it included standalone
diagnostic, migration-attestation, re-ingestion, benchmark, sign-off,
verification, and cache-maintenance helpers that were outside the earlier app
path review. A module-by-module review removed 30 semantic no-ops while
preserving behavior: unused imports and assignments, redundant f-string
prefixes, and broad exception handling were corrected only where the expected
failure type was known. The import diagnostic now uses explicit dynamic module
probes and filters non-addressable included routers before checking routes.
It completed successfully against the current app: seven imports and
`/debug/services`, `/processing/status`, and `/query` were present.

Focused Ruff and byte-compilation checks passed for all edited helpers. The
two repository-path bootstrap tools were then moved to explicit dynamic module
loading, preserving direct repository-root execution without a late static
import. Their command-level checks and 44 related runtime-config and production
health tests passed. The full scan is now **23 findings**, all in the retained,
unreferenced `src/policy_rag_hybrid.py` prototype, which is already subject to
a separate archive/removal versus rebuild decision. This is Tier 2 local
evidence for the reviewed helpers and Tier 1 static classification of the
residual full-repository gate; BR-11 remains open until the residual ownership
decision and the other supply-chain evidence are closed.

### Control-chunk review (2026-07-24) — standalone maintenance-tool lint review

**Pass 1 — immediate correctness:** Ran focused Ruff and Python byte
compilation on each changed helper. The diagnostic then ran successfully and
reported the expected import and endpoint probes.

**Pass 2 — architecture and long-term viability:** Preserved dependency-probe
semantics and direct-from-root bootstrap behavior; no optional dependency,
legacy prototype, or application pipeline was deleted merely to silence lint.

**Pass 3 — supervision readiness:** The remaining 23 findings are named by
file and decision type. They remain visible in BR-11 rather than being hidden
by a broad suppression or an unsupported claim of a clean full-Ruff gate.

## Three-pass control record

### Pass 1 — immediate correctness

The register separates code presence, test evidence, runtime proof and
external-account proof. No historical document is used as a substitute for a
current gate.

### Pass 2 — architecture and long-term viability

The register retains the canonical paths: FastAPI plus Supabase for durable
data, private storage, owner-scoped API access, evidence substrate and durable
outbox. It does not introduce a second queue, billing authority, identity
path, or claims/coverage truth source.

### Pass 3 — supervision readiness

Every open gate has a named evidence source and owner class. External account
actions are visibly blocked rather than silently deferred.

## Anything else?

Yes: sale value also depends on transferability. Even a technically green
release cannot be sold as an operating business without ownership documents,
transferable vendor accounts, production costs, user-consented data rights and
commercial traction. BR-13 and BR-14 stay open until that proof exists.
