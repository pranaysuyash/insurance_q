# CoverWise J02–J07 Deep Dive — 2026-07-21

Status: exploration and contract audit; no product code changed in this pass.

This dated artifact is evidence for the canonical journey map at
`docs/user_experience/coverwise_user_journey_map.md`. It is not a second
journey source of truth. The journey map owns the product journey; this file
records the implementation findings, risks, and closure paths discovered while
tracing onboarding through Q&A.

## Scope and method

The trace covered:

`J02 onboarding → J03 identity and account claim → J04 upload → J05 processing and recovery → J06 evidence review → J07 Q&A`.

Evidence sources were current Flutter and FastAPI code, migrations, tests,
architecture/ADR documents, and official Supabase security documentation. The
static findings below are Tier 1 unless a test or prior runtime audit is named.

## End-to-end contract findings

| Journey | What is structurally sound | Confirmed gap or risk | Tier | Closure path |
|---|---|---|---:|---|
| J02 onboarding | Three-step orientation; terms/analytics state is represented locally; onboarding completion is persisted | Consent is local-only in the onboarding path, local and server consent vocabularies differ, consent failures are swallowed, and Skip can complete without an explicit terms acceptance decision. Copy still includes product-boundary-sensitive renewal language | 1 | Define one server-auditable consent contract and purpose vocabulary; make completion semantics explicit; replace boundary-drifting copy; test accept, decline, skip, retry, offline, and replay |
| J03 identity | Anonymous and account sessions are both supported; account claim has owner transfer; account deletion has a visible result contract | Custom anonymous identity and Supabase identity are dual principals; claim visibly transfers server document ownership but local encrypted principal migration is not proven; deletion returns 202 while the route performs synchronous best-effort deletion and references a durable job that is not enqueued in the inspected route; explicit session revocation checking is not visible | 1 | Choose the canonical principal lifecycle; make claim migration cover every local/server representation; implement durable deletion job + receipt or change the contract; verify session revocation and two-user isolation |
| J04 upload | Size/content validation, owner-scoped source-hash dedupe, object rollback on metadata failure, rate limits, consent/version fields, and offline local save exist | Earlier snapshots recorded background-task enqueue in production; current compose now routes through durable `DOCUMENT_PROCESSING` when outbox is configured, but end-to-end delivery and dead-letter visibility remain unverified | 1–2 | Enforce one durable enqueue path as the only production path and prove queue delivery with terminal outcomes and operator visibility |
| J05 processing | Capability-aware state derivation includes partial, OCR-required, password-required, retryable, terminal, and QA states; processing lease and source-object rollback are present | Process loss after API termination remains possible when work is held by in-process background execution; real recovery/lease-expiry proof is missing | 1 | Enqueue transactionally with document receipt, run worker crash/retry/duplicate/timeout tests, expose state transitions and operator actions |
| J06 evidence | Append-only evidence substrate; page artifacts/source spans/field citations; owner check before evidence read; main RAG path verifies citations against immutable `source_text` and preserves approximate status | Typed structured extraction is stronger in the main RAG path than in the policy-field extractor; cross-document and fresh-runtime evidence proof is missing; service-role substrate access depends on API owner checks | 1–2 | Use typed schema validation for every model-backed extraction; run real-document citation acceptance tests; prove owner isolation and page/span navigation in the running stack |
| J07 Q&A | `/query` overwrites client filters with authenticated owner scope; retrieval quality gate can return honest not-found; structured answer schema, citation verification, missing-information and follow-up fields, context-only fallback, and query tracing exist | `/query` and `/documents/query` are parallel product actions with different transport contracts; mobile can use a local policy-demo answer only when an explicit compile-time demo flag is enabled, but the fallback must remain visibly non-production; fresh runtime proof of retrieval, citations, and failure recovery is absent | 1–2 | Inventory callers, select one canonical owner-scoped query route, deprecate/migrate the other, then verify answer/citation/fallback behavior against a real policy and two owners |

## J02–J07 journey state taxonomy (ideal/current/future)

Use this as the baseline before execution work:

- **Ideal**: desired contract and user trust outcomes.
- **Current**: observed implementation and gap-bearing behavior.
- **Future**: explicit roadmap target to converge behavior and claims.

| Journey | Ideal | Current | Future |
|---|---|---|---|
| J02 onboarding | Deterministic onboarding completion with server-auditable per-purpose consent receipts and explicit versioned outcomes | Local onboarding marker and consent tracking, but no guaranteed server-auditable contract for every failure path; term-vs-analytics boundaries drift | Single canonical consent ledger call path with typed purpose map and explicit failure classes for continue/decline/retry/offline |
| J03 identity | One canonical principal lifecycle with proven local encrypted migration, two-user isolation, and auditable claim receipts | Dual anonymous+account principals with partially observed migration; deletion responses promise async state more strongly than the route currently enforces | Canonical principal lifecycle with migration receipts, scoped revocation checks, and explicit deletion job/receipt contract |
| J04 upload | One production enqueue path through durable queue, immediate local durable intent, and authenticated outbox outcome visibility | Upload validates and persists, and can route to outbox in production, but durable-delivery evidence and non-production fallback behavior are not fully closed | Remove non-canonical enqueue forks, add idempotent enqueue receipts, DLQ contract, and operator visibility for every rejected/terminal enqueue outcome |
| J05 processing | Deterministic lease+retry state machine with bounded duplicate execution and transparent dead-letter transitions | In-process and outbox components both exist; crash/retry/duplicate/timeout behavior not yet proven end-to-end | Enforce lease-first processing contract as sole production behavior and complete recovery evidence for terminal outcomes |
| J06 evidence | Every extracted field and citation is provenance-typed, owner-verified, and stale or malformed mapping is shown as untrusted | Evidence is append-only and mostly structured, but typed schema coverage and cross-owner/source-staleness runtime proofs are incomplete | Full typed schema validation on all extractor paths, explicit stale/invalid provenance state, and two-owner replay proof |
| J07 Q&A | Single canonical owner-scoped retrieval route returning citationed answers with safe fallback states under missing/weak context | Two query transport contracts still active; live cross-owner and runtime fallback proof is incomplete | One canonical owner-scoped route, strict fallback grammar (not invented answers), and explicit safe-unknown path with audit context |

## J02–J07 end-to-end path ledger (2026-07-22)

This section keeps the decision topology explicit for planning and next-pass design.

| Stage | Happy movement | Non-happy movement | Optional / alternate movement | Open gate (evidence) |
|---|---|---|---|---|
| J02 onboarding | Cold launch reads cached onboarding/consent marker and transitions to workspace-ready with explicit server-visible consent intent | Consent errors are swallowed; incomplete onboarding continues with unclear provenance; repeated launch can re-show onboarding when terminal marker is not durable | Analytics-only opt-in, terms-only acceptance, later consent refresh, and accessibility fallback for reduced-touch flows | End-to-end test that onboarding contract is server-auditable with purpose/version receipts (Tier 3/4) |
| J03 identity | Anonymous user uploads and views while local workspace exists; sign-in claims document ownership and local migration is applied | Identity claim loses local encrypted principal mapping, second-user read pollution, token-refresh failures, or claim interruption across restart | Two-user device, password reset callback, and sign-out re-bootstrap routes | Owner transfer proven across local encrypted records + API-owned documents + entitlement state |
| J04 upload | Valid source enters validation, writes source metadata/object, persists status, and transitions to processing queue entry | Unsupported file/size/content, duplicate with rate limit, upload throw/reject, or offline pending never converges to server ack | Camera path (future), sample/demo workspace, delayed retry after reconnect | One durable enqueue path for production with terminal outcomes and explicit error class |
| J05 processing | Worker acquires lease, extracts artifacts/fields, and advances deterministic status | OCR-required / partial extraction, timeout, lease contention, duplicate attempts, dead-letter escalation, deletion during run | Reclaim by lease expiry, manual retry, replace document, and partial-result preserve-and-stop mode | Crash/retry/duplicate/timeout proof with operator-observable state transitions and cost/error logs |
| J06 evidence | Evidence pages/spans remain immutable, source-backed, and navigable from policy fields and citations | Source mismatch, stale spans, vector drift, malformed extraction, or unauthorized owner read attempts | Synthetic/native Office branch, offline source preview, user-triggered reprocessing | Typed schema validation for every extractor and two-owner proof for source/page navigation |
| J07 Q&A | Owner-scoped retrieval returns answer with citation status, confidence, and safe next action | Missing context, low confidence, malformed structured answer, model/provider fallback, 5xx/timeouts, or cross-owner leakage attempts | Follow-up narrowing, answer history, feedback path, local demo gate (blocked in release) | Live two-owner retrieval with citation verification and operator-readable failure class for every fallback |

### Path-level closure status

- Happy-chain evidence is now explicit across J02–J07; focused Tier 2 checks exist on core contracts and representative errors.
- Highest remaining risk clusters are identity migration, durable upload queue primacy, recovery semantics, and live cross-owner evidence/Q&A proof (Tier 3+).
- Next pass priority remains: keep one canonical route/queue, then close each non-happy branch with authenticated runtime evidence and operator visibility.

## Closure execution matrix (2026-07-22)

This matrix turns the open frontier into the next verification plan without
claiming closure until each branch has authenticated runtime evidence.

| Frontier branch | Scenario to execute | Expected observable state | Minimum evidence artifact |
|---|---|---|---|
| J02 consent mismatch | Simulate consent write failure and a second start without server receipt | UI enters limited mode, onboarding banner remains explicit, and no consent claim is stored server-side | API response logs + consent table rows keyed by `purpose` and `consent_version` |
| J02 consent mismatch | Simulate terms acceptance + analytics decline + later analytics success | Terms and analytics are independently tracked with immutable versions and separate status | Two consent rows, one per purpose, with consistent version ordering |
| J03 identity migration | Sign in with two local principals and restart during claim | Document list and local secure boxes are namespace-bound by principal, and each principal never reads the other | Rebuild + claim/relogin trace, local secure-box key migration log, document ownership readback |
| J03 deletion isolation | Start deletion while another account is active | Deleted principal’s resources stop resolving for that principal; remaining principal still respects its own scope | Deletion event receipt + failed owner mismatch checks |
| J04 upload path downgrade | Force production upload through legacy in-process branch | Compatibility branch is rejected from production path and only outbox job schema is emitted | Upload response type only from durable path and queue insert metrics |
| J04 offline convergence | Persist local pending document for 1+ network outages, then reconnect and sync | Pending row converts to `upload_accepted` or explicit terminal retry class | Sync audit row containing terminal state + retry reason |
| J05 processing recovery | Inject duplicate worker start and lease contention | One canonical lease owner continues; retries are bounded and classified; dead-letter events are inspectable | Worker lease table, delivery attempt counters, dead-letter table entries |
| J05 partial and OCR-required | Feed a scan-only document and a malformed document | Partial/required/failed states are not treated as success; policy detail displays recovery action | `partial`, `text_required`, `ocr_required`, `processing_failed` terminal evidence |
| J06 evidence fallback | Replace evidence source with stale span mapping and unauthorized owner chunk | UI shows not verified/stale class; source navigation does not cross owners | Evidence read query + citation verifier + owner-filter proof |
| J06 source typing | Force one malformed extractor payload through policy-field path | Structured field parser fails closed with explicit schema reason; no fallback to raw string in policy shape | Parser trace + typed schema validation error output |
| J07 Q&A retrieval fallback | Ask a question with missing doc pages, low-confidence model output, and timeout | Q&A returns explicit unavailable/uncertain branches with no invented recommendations | Query trace + `citation_status`, `confidence`, and operator-visible failure enum |
| J07 tenancy hardening | Query same policy with mismatched owner principal and cross-device token | Tenant-isolated result set is strict owner-filtered empty for mismatched context | HTTP 403/404-equivalent owner scope contract + empty set + audit event |

### Closure execution plan (no claims before evidence)

Each branch below should be executed with a real environment; local-only fixtures do not close Tier 3+/4 risk.

| Branch | Suggested command or probe | Primary acceptance output |
|---|---|---|
| J02 consent mismatch | 1) Start app with blocked `ServerConsentService` endpoint (offline/intercepted), 2) complete onboarding path and relaunch | Evidence of explicit limited-mode banner and absence of successful server row; no `terms_accepted` row without version in consent table |
| J02 consent versioning | 1) Consent path for analytics declines after terms accept; 2) retry analytics success; 3) read server consent rows | Two immutable rows with same client request id namespace and distinct `purpose` + `version` values |
| J03 principal migration | 1) Create anonymous docs, 2) sign in/restart/reopen, 3) claim ownership + resume | Storage keys and document owner ids change only through migration; no doc leaks across principal ids |
| J03 deletion/revoke | 1) Delete principal while another signed-in session exists | Deleted session fails owner checks; other principal’s docs remain readable under their own id |
| J04 upload path | 1) Trigger upload under production composition with outbox enabled, 2) inspect job envelope | Only durable `DOCUMENT_PROCESSING` outbox job observed; no non-queue in-process enqueue path for production route |
| J04 offline sync | 1) Queue pending uploads offline, 2) reconnect, 3) monitor transition event | Deterministic `upload_accepted` or terminal retry class with explicit reason code and user-visible sync status |
| J05 lease/retry | 1) Double-start worker on same payload and simulate lease contention, 2) force timeout | Single lease owner, bounded retry class in logs, bounded duplicate handling, optional dead-letter entry with reason |
| J05 malformed input | 1) Feed malformed + OCR-required files | Terminal states `partial`/`text_required`/`ocr_required`/`processing_failed` surfaced, not silently marked completed |
| J06 evidence staleness | 1) Inject stale span mapping, 2) cross-owner evidence query | UI marks stale/mismatch, no cross-owner source navigation; citation verification fails closed |
| J06 typed extraction | 1) Submit malformed model payload through policy-field extractor path | Structured parser emits schema reason; no silent coercion into display fields |
| J07 weak retrieval | 1) Ask out-of-scope question with restricted corpus + low confidence and timeout injection | `citation_status` and `confidence` show uncertain/unknown; follow-up path offered |
| J07 cross-owner Q&A | 1) Cross-token retrieval on mismatched owner | Empty or unauthorized result with explicit owner-scope failure; no answer leakage between users |

## J02–J07 evidence-by-branch command matrix (2026-07-22)

Each row below is the next concrete execution target. Commands are grouped by
backend and mobile ownership.

### Backend test probes

| Branch | Command(s) | Primary acceptance artifact |
|---|---|---|
| J02 consent mismatch | `source .venv/bin/activate && uv run pytest -q tests/test_consent_ledger_service.py tests/test_anonymous_auth.py` | No server-side `terms_accepted` write when consent sync fails; failure class recorded on client/server boundary |
| J02 consent versioning | `source .venv/bin/activate && uv run pytest -q tests/test_consent_ledger_service.py -k "get_current_consent or record_consent"` | Two immutable records for same request namespace, one per purpose and version |
| J03 principal migration | `source .venv/bin/activate && uv run pytest -q tests/test_identity_link_service.py tests/test_account_lifecycle_service.py tests/test_account_deletion_status.py` | Owner migration is auditable, encrypted workspace namespace changes are explicit, and deletion barriers prevent wrong-owner reads |
| J03 deletion isolation | `source .venv/bin/activate && uv run pytest -q tests/test_account_deletion_status.py tests/test_account_lifecycle_service.py tests/test_query_usage_gate.py` | Owner-scoped session checks and deletion visibility hold under concurrent session pressure |
| J04 upload path downgrade | `source .venv/bin/activate && uv run pytest -q tests/test_upload_validation.py tests/test_document_processing_job.py tests/test_job_outbox.py tests/test_job_outbox_lease_contract.py` | Upload responses in production path only emit durable `DOCUMENT_PROCESSING` jobs; no fallback enqueue contract |
| J04 offline sync convergence | `source .venv/bin/activate && uv run pytest -q tests/test_processing_temp_storage.py tests/test_substrate_outbox_wiring.py tests/test_document_state_derivation.py` | Deterministic local-to-server handoff and terminal retry classifications for offline backlog |
| J05 lease/recovery | `source .venv/bin/activate && uv run pytest -q tests/test_outbox_worker_health.py tests/test_job_outbox.py tests/test_job_outbox_lease_contract.py` | One lease owner per in-flight job, bounded retries, and inspectable dead-letter transitions |
| J05 malformed input classes | `source .venv/bin/activate && uv run pytest -q tests/test_document_processing_job.py tests/test_upload_validation.py` | Distinct terminal states (`partial`, `text_required`, `ocr_required`, `processing_failed`) are visible and never reported as completed |
| J06 evidence fallback safety | `source .venv/bin/activate && uv run pytest -q tests/test_evidence_pipeline.py tests/test_evidence_schema_contract.py tests/test_evidence_pipeline_integration.py` | Unverified/stale/unauthorized provenance is surfaced as not-verified and never shown as trusted fact |
| J06 typed extraction and rejection | `source .venv/bin/activate && uv run pytest -q tests/test_evidence_schema_contract.py tests/test_evidence_pipeline_integration.py` | Parser rejects malformed structured output with explicit schema reason and no silent fallback coercion |
| J06 stale span / owner leak | `source .venv/bin/activate && uv run pytest -q tests/test_document_owner_isolation.py tests/test_citation_verifier.py tests/test_citation_verifier_integration.py` | Unauthorized-owner read attempts fail closed; stale mapping cannot navigate to verified source cards |
| J07 retrieval fallback + timeout | `source .venv/bin/activate && uv run pytest -q tests/test_rag_pipeline.py tests/test_query_usage_gate.py tests/test_qa_usage_contract.py` | `citation_status`, `confidence`, and explicit safe fallback enum when retrieval quality is insufficient or timeout occurs |
| J07 tenancy hardening | `source .venv/bin/activate && uv run pytest -q tests/test_rag_pipeline.py tests/test_document_owner_isolation.py tests/test_query_usage_gate.py` | Strict owner filtering for retrieval and explicit cross-owner rejection for `/query`; compatibility route behavior stays bounded |

### Mobile test probes

- `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/consent_upload_flow_test.dart test/consent_ledger_test.dart test/server_consent_service_test.dart`
  → Consent lifecycle, local/remote consent sync path, and blocked-server fallback.
- `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/account_document_reconciliation_test.dart test/principal_key_service_test.dart test/hive_workspace_service_contract_test.dart test/local_storage_service_test.dart`
  → Identity migration continuity and encrypted local workspace scoping.
- `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/processing_status_test.dart test/processing_status_backend_test.dart test/processing_status_fallback_test.dart`
  → Processing status states, retry classes, and sync visibility behavior.
- `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/qa_screen_test.dart test/source_references_test.dart test/field_citations_card_test.dart`
  → Q&A in-flight gating, evidence card safety, and source navigation.
- `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/deletion_status_test.dart test/document_service_delete_test.dart`
  → Deletion status/readback and document delete lifecycle behavior.
- `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/migration_integrity_test.dart`
  → Principal migration claim-preserve semantics, local box open/restore correctness, and non-happy path cleanup behavior.

### Observed execution log (2026-07-22)

The following probes have been executed during this pass:

| Command | Result | Immediate evidence outcome |
|---|---|---|
| `source .venv/bin/activate && uv run pytest -q tests/test_consent_ledger_service.py tests/test_anonymous_auth.py` | PASS | 24 passed. Confirms base consent-ledger + anonymous-auth contract coverage, but not end-to-end blocked-server consent failure branch. |
| `source .venv/bin/activate && uv run pytest -q tests/test_identity_link_service.py tests/test_account_lifecycle_service.py tests/test_account_deletion_status.py` | PASS | 11 passed. Supports J03 principal migration and deletion-visibiity service behavior. |
| `source .venv/bin/activate && uv run pytest -q tests/test_upload_validation.py tests/test_document_processing_job.py tests/test_job_outbox.py tests/test_job_outbox_lease_contract.py` | PASS | 49 passed. Supports outbox/lease-path checks for J04. |
| `source .venv/bin/activate && uv run pytest -q tests/test_processing_temp_storage.py tests/test_substrate_outbox_wiring.py tests/test_document_state_derivation.py` | PASS | 15 passed. Confirms offline-to-server handoff, local pending state mapping, and deterministic retry-status derivation for J04 offline convergence frontier. |
| `source .venv/bin/activate && uv run pytest -q tests/test_outbox_worker_health.py tests/test_job_outbox.py tests/test_job_outbox_lease_contract.py` | PASS | 38 passed. Confirms lease-bound processing concurrency, bounded retries, and dead-letter visibility in job-control path. |
| `source .venv/bin/activate && uv run pytest -q tests/test_evidence_pipeline.py tests/test_evidence_schema_contract.py tests/test_evidence_pipeline_integration.py` | PASS | 31 passed. Supports J06 schema validation and evidence provenance failure handling in current pipeline tests. |
| `source .venv/bin/activate && uv run pytest -q tests/test_rag_pipeline.py tests/test_query_usage_gate.py tests/test_qa_usage_contract.py` | PASS | 13 passed. Supports J07 retrieval fallback and answer safety enum behavior in current tested surfaces. |
| `source .venv/bin/activate && uv run pytest -q tests/test_consent_ledger_service.py -k "get_current_consent or record_consent"` | PASS | 8 passed, 6 deselected. Confirms purpose/version-focused consent ledger contracts. |
| `source .venv/bin/activate && uv run pytest -q tests/test_consent_ledger_service.py tests/test_anonymous_auth.py tests/test_identity_link_service.py tests/test_account_lifecycle_service.py tests/test_account_deletion_status.py` | PASS | 35 passed. Extends the earlier J02/J03 command set with explicit joint coverage for anonymous identity, principal migration, and deletion status behavior. |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/account_document_reconciliation_test.dart` | PASS | 3 tests passed. Confirms local remote-account reconciliation paths and defensive handling when local malformed page data appears. |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/principal_key_service_test.dart` | PASS | 7 tests passed. Confirms encrypted principal-key migration and failure boundaries for principal-scoped local keys (J03 ownership). |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/processing_status_test.dart` | PASS | 28 tests passed. Confirms processing-stage mapping defaults, terminal-stage behavior, and resilient status interpretation for J05 recovery display. |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/qa_screen_test.dart` | PASS | 11 tests passed. Confirms in-flight question guards and Q&A UI safety boundaries. |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/source_references_test.dart` | PASS | 9 tests passed. Confirms citation/source navigation labeling and confidence badge visibility behavior in J06 evidence surfaces. |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/consent_ledger_test.dart` | PASS | 35 tests passed. Confirms local consent record model semantics, persistence behavior, and corrupted-state recovery handling for J02 storage path. |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/deletion_status_test.dart` | PASS | 3 tests passed. Confirms local deletion lifecycle status transitions and safe state representation. |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/consent_upload_flow_test.dart` | PASS | 8 tests passed. Repeated `DioException 400` responses are logged during mocked endpoint mismatch scenarios, while duplicate prevention and fallback behaviors are still validated. |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/migration_integrity_test.dart` | PASS | 12 tests passed. Confirms local principal migration preserve behavior and verifies Box generic compatibility across migration paths in this branch. |
| `source .venv/bin/activate && uv run pytest -q tests/test_query_usage_gate.py tests/test_document_owner_isolation.py tests/test_citation_verifier_integration.py` | PASS | 23 passed. Confirms owner-scoped query gating and citation-verifier exception behavior under unauthorized-owner scenarios. |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/processing_status_fallback_test.dart test/processing_status_backend_test.dart` | PASS | 49 tests passed. Confirms fallback-safe processing-status behavior and backend-stage mapping across local/document-not-found and transport-failure paths. |
| `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/account_document_reconciliation_test.dart test/hive_workspace_service_contract_test.dart test/local_storage_service_test.dart` | PASS | 7 tests passed across identity/document reconciliation and local storage contract transitions. |
| `COVERWISE_API_BASE_URL=http://127.0.0.1:8005 SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SECRET_KEY=... tools/verify_local_identity_claim.py` | BLOCKED | Local-only verifier exits with `Connection refused` because local API/Supabase services were not running on required local endpoints during this session. |

## Non-happy-path closure frontier (2026-07-22)

The next high-confidence closure pass should explicitly validate each branch below
against a real authenticated stack, not only a targeted fixture:

| Frontier branch | What must be proven | Minimum evidence target | Owner / actor |
|---|---|---|---|
| J02 consent and analytics mismatch | If consent fails, the user can only proceed in a clearly labeled limited state and no server-side consent claim is written | Server receipt contains explicit purpose map + version + success/failure class | Mobile + API + Supabase |
| J03 identity claim across restart | Anonymous-to-account claim preserves local encrypted artifacts and document entitlement without cross-user bleed | End-to-end identity migration test with two principals and signed restart recovery | Auth + local storage + API |
| J04 upload path downgrade | Production upload cannot silently route to in-process path when outbox is configured | Route-level assertion that the upload contract includes only the durable job outcome schema | API + worker dispatcher |
| J05 processing failure recovery | Duplicate, stale, timeout, and dead-letter states are distinguishable in the running state machine | Crash/retry/lease/duplicate simulation with deterministic operator-visible transitions | Worker + API |
| J06 evidence fallback / partial proof | Any field/citation result declares whether provenance is present, stale, rejected, or partial | Cross-owner retrieval attempt returns strict scope errors; stale-source evidence is not presented as verified | Evidence service + policy detail + query APIs |
| J07 Q&A fallback honesty | Missing/weak retrieval emits a safe state and cannot cross owners; structured answer never defaults to invented advice | Two-owner proof with malformed context, missing source page, low confidence, and model timeout scenarios | Q&A API + query service + UI |

### Frontier status update (2026-07-22)

Backend-targeted J04 offline-sync and J05 lease-recovery fronts now have direct
pytest evidence, and the corresponding mobile-focused status/claims/evidence
screen suites now execute cleanly in this environment. Remaining unclosed high-
risk branches are now narrowed to:

- blocked/partial-server-consent synchronization under real auth-bound transport failure,
- two-principal local migration invariants (now closed by migration-integrity test; still need active runtime replay with server auth context),
- cross-stack live retrieval/evidence-owner proof with real policy documents.
- full real-authenticated replay (anonymous upload → account claim → restart → processing status → evidence read → owner-scoped Q&A) is still open because local API and Supabase stacks were not available for this run.

## Important implementation evidence

### J02–J03: consent and principal lifecycle

- `mobile/lib/screens/onboarding_screen.dart` records through the local
  `ConsentLedger` and catches consent errors as best effort.
- `mobile/lib/services/server_consent_service.dart` exists, but the traced
  onboarding/upload paths do not call it.
- Mobile purposes include `document_processing`, `analytics`, `lead_capture`,
  and `terms_accepted`; the server migration accepts a different vocabulary
  (`privacy_policy`, `analytics`, `marketing_emails`, `camera_access`). This is
  a contract mismatch, not merely a naming difference, because it prevents a
  single auditable answer to “what did the person consent to?”
- `mobile/lib/services/auth_service.dart` claims anonymous data by calling the
  server owner-transfer endpoint. The inspected implementation does not prove
  migration of encrypted Hive records from the anonymous principal key to the
  account principal key.
- `src/api/user.py` reports account deletion as `202` and can return a partial
  result, but the inspected route deletes synchronously and does not enqueue the
  durable deletion job named in its response message. This is a user-facing
  contract/operability mismatch.

### J04–J05: upload and processing

- `src/api/document.py` performs validation, owner-scoped hash replay, object
  storage, metadata persistence, and cleanup if metadata creation fails.
- The current composition can route uploads through durable outbox enqueue for
  production while retaining a compatibility branch for non-production modes. The
  outbox migrations, `JobOutboxService`, dispatcher, and handlers describe the
  canonical path, but live queue delivery, duplicate delivery handling, and
  dead-letter recovery remain unverified.
- `src/services/document_processing_service.py` has a single `_save_file`
  implementation with one write in the current file; the earlier suspicion of a
  duplicate write is not confirmed and is not recorded as a defect.
- Mobile has an honest local pending/offline document state, but the inspected
  search did not establish a complete automatic pending-upload synchronization
  path. This remains an open Tier 1 question, not a claim that sync is absent.

### J06–J07: evidence and Q&A

- `src/rag/pipeline.py:1094-1099` calls `_verify_citations` on generated or
  context-only citations before returning them.
- `src/rag/pipeline.py:1046-1069` uses typed `RAGAnswer` structured generation,
  low temperature, and a fallback model; `src/services/evidence_pipeline.py`
  still has a weaker model-backed extraction path that should converge on typed
  validation.
- `src/app/main.py` and `mobile/lib/services/query_service.dart` provide safe
  unavailable/not-found states. The mobile local demo answer is gated by
  `BOOTSTRAP_POLICY_DEMO`, whose release validation rejects enabling it in a
  release build; it must not be used as evidence of production Q&A.
- `src/app/main.py` exposes JSON `POST /query`; `src/api/document.py` exposes
  form `POST /documents/query`. The existing audit already records the shape
  divergence. Under the canonical-route rule, this is a retirement decision,
  not a reason to add a third adapter route.

## Supabase security alignment to verify

The repository’s newer evidence, outbox, and consent migrations use RLS,
service-role-only grants, and `security_invoker` views. That is directionally
aligned with Supabase guidance, but it does not replace runtime proof of the
API owner checks and storage configuration.

- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security): exposed tables should have RLS; service-role access bypasses RLS and must remain server-only.
- [Storage access control](https://supabase.com/docs/guides/storage/security/access-control): private object access depends on Storage RLS policies and the required operation grants.
- [Bucket fundamentals](https://supabase.com/docs/guides/storage/buckets/fundamentals): the CoverWise bucket is configured private in the inspected migration.
- [Auth sessions](https://supabase.com/docs/guides/auth/sessions): deleting a user does not by itself prove that already-issued access tokens are unusable; sensitive paths need explicit revocation/session validation where required.

## Priority closure order

1. Establish one canonical consent contract and one canonical query route.
2. Replace upload-time in-process processing with the durable outbox path and
   prove retry, duplicate, crash, timeout, and dead-letter behavior.
3. Define anonymous-to-account migration across local encrypted state and every
   server representation.
4. Make deletion semantics truthful: durable job, idempotent stages, receipt,
   operator visibility, and explicit session-revocation posture.
5. Run a real-document Tier 3 evidence/Q&A acceptance pass with two principals,
   weak retrieval, missing pages, OCR-required input, and unavailable model/storage
   conditions.

## Verification notes from this pass

Focused command:

```text
source .venv/bin/activate && uv run pytest -q tests/test_anonymous_auth.py tests/test_document_state_derivation.py tests/test_citation_verifier.py tests/test_citation_verifier_integration.py tests/test_evidence_pipeline.py tests/test_supabase_fts.py
```

This pass now executes cleanly at fixture level in this environment:

The command passed **77 passed** (3 deprecation warnings), including:

- citation verifier contract stability and integration (tests `test_citation_verifier.py`,
  `test_citation_verifier_integration.py`);
- Supabase FTS adapter verification (`test_supabase_fts.py`) under current
  package bindings;
- document-state and evidence pipeline behavior (`test_document_state_derivation.py`,
  `test_evidence_pipeline.py`);
- anonymous-auth boundary checks (`test_anonymous_auth.py`).

What remains unverified at Tier 3+ is runtime replay and cross-stack behavior:

- no running local API/Supabase stack was available in this session for
  two-principal migration/restart replay;
- no authenticated cross-service end-to-end Q&A or evidence-owner proof was executed
  against a real policy in this pass.

## 2026-07-22 — live-stack J02–J07 pass (next strongest sweep: J02–J07 end-to-end)

This pass used the currently running API on `127.0.0.1:8000` and `8001` with
fresh anonymous tokens to add authenticated and contract-level evidence for the
already-traced journey chain.

### Tier-2/Tier-3+ runtime outcomes added

- **J02 onboarding / consent gate**
  - `POST /user/anonymous` returns anonymous bearer token on current stack (baseline).
  - `POST /documents/upload` with `processing_consent=false` is rejected with `422`
    and contract code `processing_consent_required`.
  - `POST /documents/upload` with bad/malformed token is `401 invalid or expired account token`.
  - Interpretation: consent gate and auth boundary are enforced at upload time; this is consistent with
    safe behavior for J02/J04.

- **J04 upload enqueue + rate-limit branch**
  - `POST /documents/upload` with a known previously-seen file returns `429`
    with detail `"Rate limit exceeded: Document has already been processed"` (document
    fingerprint replay protection is active).
  - `POST /documents/upload` with consent + version on a non-replayed variant returns `202`
    and `status=received`.
  - Interpretation: acceptance branch works; replay/rate-control branch is observable but needs stronger UX language review for low-ambiguity user outcomes (J04 non-happy path).

- **J05 processing state machine**
  - Immediate document status fetch for new uploads shows `status=processing`, `stage=processing`.
  - Polling observed transition to:
    - `status=failed`, `stage=failed`, `error="Document processing did not complete. Please retry the upload."`
  - `GET /documents/{id}/summary` for failed documents returns `404 No policy summary found...`
  - `GET /documents/{id}/evidence` and `GET /documents/{id}/sources` return `404 Not Found` for failed doc.
  - `/processing/status` currently reports active job and `stage=completed_summary_partial` for one job in earlier sample.
  - Interpretation: failure classification and non-happy outcome surfacing are present, but recovery UX/flow is still high-priority to prevent silent confusion.

- **J06 evidence review**
  - For failed docs, source/evidence endpoints are closed (`404`), which avoids false-verified claims.
  - This still does not prove positive source/page navigation with strong cross-owner invariants on successful docs in this run.

- **J07 Q&A / retrieval route topology**
  - `POST /documents/query` succeeds and returns answer + citations (legacy-form route still functional).
  - `POST /query` contract validation behavior is active:
    - empty JSON body → `422` missing `query` field
    - `{ "query": "" }` -> response with no relevant context and explicit `confidence=0.0`.
  - Returned sources from `/query` include document ids not guaranteed to be limited to
    a current user’s freshly uploaded artifact, so ownership and corpus scoping remain a required evidence gate.
  - Interpretation: route-level contract differences remain as recorded (JSON canonical vs form compatibility), and owner-scoped evidence quality still needs authenticated replay.

### Evidence-backed frontier update after this pass

- **Now closed (locally verifiable):**
  - consent required gate at upload,
  - auth-reject boundary for anonymous upload,
  - duplicate/retry rejection message branch,
  - processing failure state and summary/evidence-not-found behavior,
  - route-level shape validation for `/query`.
- **Still Tier 3+ open:**
  - two-principal authenticated migration/restart replay (requires account-side identity flows and server-local encrypted state proof),
  - durable processing success path for a specific upload in this same token session,
  - cross-owner evidence/Q&A isolation proof with real principals.

### Additional commands from this live pass

- `curl -s -X POST http://127.0.0.1:8000/user/anonymous`
- `curl -s -H \"Authorization: Bearer $TOK\" -F \"files=@/tmp/cw_sample.pdf\" -F \"processing_consent=false\" ... /documents/upload`
- `curl -s -H \"Authorization: Bearer bad\" ... /documents/upload`
- `curl -s -H \"Authorization: Bearer $TOK\" -F \"files=@tests/test_data/sample_insurance.pdf\" -F \"processing_consent=true\" -F \"processing_consent_version=2026-07-22\" ... /documents/upload`
- `curl -s -H \"Authorization: Bearer $TOK\" \"http://127.0.0.1:8000/documents/$DOC/status\"` (multiple polls)
- `curl -s -H \"Authorization: Bearer $TOK\" \"http://127.0.0.1:8000/documents/$DOC/summary|evidence|sources` (failed doc)
- `curl -s -H \"Authorization: Bearer $TOK\" -d \"query=What is this policy?\" -d \"document_ids=\" ... /documents/query`
- `curl -s -X POST -H \"Authorization: Bearer $TOK\" -H \"Content-Type: application/json\" -d '{\"query\":\"What is this policy?\"}' /query`
- `curl -s -H \"Authorization: Bearer $TOK\" http://127.0.0.1:8000/debug/services`

No test or dependency files were changed during this exploration pass.

## Exploration questions carried forward

- Is the person’s consent decision allowed to be recorded locally first, or must
  onboarding/upload block until the server ledger has acknowledged it?
- Should anonymous local documents remain device-only until account claim, or is
  cross-device ownership a product promise? The answer determines the principal
  migration design.
- Is Q&A one product action with JSON as the canonical contract, or is the form
  route an intentionally separate legacy/integration surface? If legacy, what is
  its deprecation trigger?
- What exact user-visible state distinguishes “uploaded,” “processing,” “partially
  understood,” “evidence unavailable,” and “answer unavailable”?

## Three review passes

### Pass 1 — Immediate correctness

Confirmed the findings against current call sites rather than relying on ADR
intent. Removed the suspected `_save_file` duplicate-write finding because the
current implementation contains one write.

### Pass 2 — Architecture and long-term viability

Identified consent vocabulary drift, dual principal ownership, in-process versus
durable async execution, and duplicate query routes as source-of-truth risks.
Closure is staged around canonical contracts, not new compatibility layers.

### Pass 3 — Rule compliance and supervision readiness

Marked static findings Tier 1/2, separated prior runtime evidence from fresh
verification, named operator and recovery requirements, and preserved unresolved
questions rather than converting them into assumptions.

## 2026-07-22 — proceed pack: J02–J07 trust-chain normalization

Proceeding from the current frontier with the same evidence rigor:

- **J02 onboarding:** local onboarding/consent marker and sync cache-first path are present; server ledger sync is explicit and retryable, but not yet a hard proof boundary.
- **J03 identity:** principal lifecycle and local encrypted migration are stronger across code/tests; authenticated two-principal replay + restart proof remains open.
- **J04 upload:** outbox durable path is now the production target with non-production compatibility branch bounded; offline pending sync now has test coverage.
- **J05 processing:** terminal stage mapping and recovery classes are implemented and tested, but live lease-duplication/reclaim and dead-letter closure are still Tier 3+ gates.
- **J06 evidence:** citation verification and source-span architecture are real; cross-owner/stale-source runtime proofs are not fully closed.
- **J07 Q&A:** `/query` remains canonical with `/documents/query` compat-bound behavior; cross-owner runtime and two-principal response proofs remain open.

### Continue pass (next concrete acceptance sequence)

1. `source .venv/bin/activate && uv run pytest -q tests/test_processing_status_test.py tests/test_outbox_worker_health.py tests/test_job_outbox_lease_contract.py`
2. `source .venv/bin/activate && uv run pytest -q tests/test_query_usage_gate.py tests/test_document_owner_isolation.py tests/test_citation_verifier_integration.py`
3. `cd /Users/pranay/Projects/medpiper/insurance_app/mobile && flutter test test/processing_status_fallback_test.dart test/migration_integrity_test.dart`
4. Real-authenticated two-principal replay run (anonymous upload → claim → restart → processing status → evidence read → owner-scoped Q&A) against the same policy.

### Anything else?

The blocker is not journey count; it is **contract closure under identity switches and runtime recovery**. We should not elevate journey confidence scores until we have authenticated two-principal replay and queue evidence on live stack.

## 2026-07-22 — continuation pass (same-session auth/replay + cross-owner) 

This continuation pass on `127.0.0.1:8010` captured deterministic J02–J07 behavior for the same runtime lane:

- **J02/J04 consent gating**: upload without `processing_consent=true` is rejected with `422 processing_consent_required`; malformed/invalid bearer token remains hard-failed.
- **J04 idempotency branch**: repeated upload of the same file with same owner produced the same document id and `documents[0].idempotent_replay=true`, confirming replay-dedup semantics are on the contract surface.
- **J05 processing branch**: newly uploaded sample documents currently return `status=received` immediately and stay read with no active `/processing/status` jobs in this short window (`active_processing_jobs=0`, `jobs={}`); `/summary` and `/field-citations` return `404` until richer extraction completes.
- **J06 evidence isolation branch**: owner A can read their own document status and gets `404` for summary/evidence for non-ready docs; owner B receives document-not-found on status/summary/evidence for owner A’s doc.
- **J07 query branch**:
  - `/query` with non-empty question + owner A doc id returns a non-empty answer scaffold with verified citation references and `confidence>0` (model fallback to raw context in this pass).
  - `/query` with cross-owner B for owner A document returns `No relevant information found in documents` (`confidence: 0.0`).
  - `/documents/query` form route remains functional and is currently owner-filtered in both positive and negative branches.

### Live evidence table (this pass)

| Assertion | API call | Outcome |
|---|---|---|
| Consent required | `POST /documents/upload` with `processing_consent=false` | `422`, `code=processing_consent_required` |
| Invalid auth rejection | `POST /documents/upload` with `Authorization: Bearer bad` | `401 invalid or expired account token` |
| Replay guard | Upload same file twice same owner | Same `document.id`, second response has `documents[0].idempotent_replay=true` |
| Cross-owner read isolation | Owner B reads Owner A doc status/summary/evidence | `404 Document not found` / `No policy summary found` |
| Canonical query behavior | `/query` with empty `query` value | No-context fallback + zero confidence |
| Canonical query behavior | `/query` with in-scope document + question | `answer + citations + missing_information`, no invented data, confidence visible |
| Compatibility query behavior | `/documents/query` with same input | same answer/citation payload shape with transport wrapper |
| Cross-owner fallback | Owner B `/query` and `/documents/query` on A doc | explicit no-relevant fallback, not cross-owner bleed |

### J02–J07 integrated runtime flow (contract branches observed)

```mermaid
flowchart TD
    A1[Start anonymous session] --> B1{processing_consent=true?}
    B1 -- No --> C1[422 processing_consent_required]
    B1 -- Yes --> C2[POST /documents/upload]
    C2 --> D1{auth token valid?}
    D1 -- No --> D2[401 upload denied]
    D1 -- Yes --> E1[Upload accepted?]
    E1 --> F1{Same source hash already tracked?}
    F1 -- Yes --> G1[Replay path: same doc id + idempotent_replay=true]
    F1 -- No --> H1[Create document row/status=received]
    G1 --> I1[Poll /documents/{id}/status]
    H1 --> I1
    I1 --> J1{status has extraction artifacts?}
    J1 -- No --> K1[summary/evidence endpoints return 404]
    J1 -- Yes --> L1[Evidence and sources visible]
    K1 --> M1[/query with owner scope and doc id]
    L1 --> M1
    M1 --> N1{result quality}
    N1 -- No context --> O1[Safe fallback + missing_information + confidence 0]
    N1 -- Context exists --> P1[Answer + citations + confidence]
    O1 --> Q1[Ask follow-up, retry, or change doc]
    P1 --> Q1
    M1 --> R1[/documents/query compatibility path]
    R1 --> Q1
    B3[Owner B session] --> S1[Try read/ query A doc]
    S1 --> T1[404 or no relevant + no bleed]
```

## Anything else?

Yes: J02–J07 are not six isolated screens. They are one trust chain. If consent,
principal ownership, durable processing, evidence provenance, and Q&A scope do
not share a single auditable contract, a polished answer can still be wrong,
unrecoverable, or impossible to explain after the fact.

## Addendum — current-state reconciliation and partial processing contract (2026-07-21)

The earlier static snapshot above must be read with the current implementation
reconciliation below. The upload route now enqueues a durable
`DOCUMENT_PROCESSING` outbox job when the production composition supplies the
outbox service, and only retains the in-process background-task path as an
explicit development compatibility branch. This removes the earlier claim
that production upload always schedules in-process work. Live queue delivery,
worker crash/reclaim, and deployed restart recovery remain unverified Tier 3/4
gates.

The processing state contract is now reflected in the mobile journey. Backend
terminal states such as `completed_no_summary`,
`completed_summary_partial`, `completed_text_partial`, `indexing_failed`, and
`partial` map to a terminal “Partially ready” state with an honest explanation
and a path to the available policy view. They no longer fall through to
“Received” until the polling timeout. A focused mapping suite and the complete
processing-stage suite passed after the change; `flutter analyze` is clean.

The document-type refresh path now resolves a local Hive ID to its remote ID
before issuing Q&A classification queries, matching the already-canonical
document query path. This closes a returning-user identity mismatch at static
and targeted-test evidence; real remote classification remains unverified.

The canonical remaining J05/J06/J07 gates are: live durable upload-to-worker
round trip, lease expiry and duplicate delivery, real-document evidence
readback, two-owner Q&A isolation, and one deliberate partial-processing run
through the deployed mobile/API stack.

## Addendum — Q&A owner fencing and local hybrid-index migration (2026-07-21)

The J07 trace found a concrete tenant-isolation gap in the non-Supabase
compatibility path: the local SQLite hybrid index stored document chunks
without `owner_id`, and its sparse search ignored the owner filter. The root
JSON query route and the form-compatible `/documents/query` route both derive
owner scope from the verified bearer principal, but that scope was lost when
local FTS results were merged with dense results. This was a Tier 1 finding in
a high-risk path and is now fixed in the canonical index implementation.

The local index now stores and filters `owner_id`. Existing indexes are
migrated additively at startup or first upsert; pre-migration ownerless rows
remain available only to explicitly unscoped local tooling and cannot satisfy
an owner-scoped query. The Supabase vector/FTS path already fails closed when
`owner_id` is missing. Regression coverage includes two owners sharing the
same query terms and verifies only the requested owner's chunk is returned.

Verification: `tests/test_rag_pipeline.py`,
`tests/test_document_owner_isolation.py`, and `tests/test_citation_verifier.py`
passed 29 tests with one existing HTTPX deprecation warning. This is Tier 2
evidence; a two-owner deployed Q&A run remains a Tier 3/4 gate.

The two query routes remain a documented contract-consolidation decision,
not an accidental third route: `/query` is the mobile JSON canonical surface,
while `/documents/query` remains a form-compatible integration surface. No
new route was added. The next decision is whether to deprecate the form
surface after caller inventory and contract tests, or formally retain it with
an explicit compatibility owner.

## Addendum — legacy query-surface deprecation boundary (2026-07-21)

Caller inventory found `/query` is the only repository mobile/frontend product
caller. `/documents/query` has no repository callers and is retained only as
a compatibility surface for unknown external integrations. It now emits a
bounded deprecation warning and its contract is frozen; no new product
behavior should be added there. Removal requires an external integration
inventory and one compatibility-window release decision.

## Addendum — Q&A duplicate suppression and citation navigation metadata (2026-07-21)

The J07 response trace found two coupled client-contract weaknesses. First,
keyboard submission could enter `_askQuestion` while another question was
still running, because the field handler bypassed the visual loading disable
and the method itself had no request boundary. The screen now owns an
in-flight guard shared by every entry point, including suggested questions,
keyboard submit, follow-ups, and the demo sequence. The follow-up widget no
longer writes loading state outside that boundary.

Second, the RAG pipeline knew the selected source's document and page, but
generated citations were returned with null lineage and the root JSON route
flattened source objects into strings. Verified and approximate citations now
inherit document/page metadata from the authoritative source index. `/query`
returns a backward-compatible mixture of legacy strings and sanitized source
objects containing only relevance/navigation fields; immutable source text and
generated retrieval context remain server-side verifier inputs.

Verification: the mobile Q&A widget suite passed 10 tests and `flutter
analyze` reported no issues. The focused backend RAG/owner/citation suite
passed 30 tests with one existing HTTPX deprecation warning. This is Tier 2
evidence. Remote page retrieval and an end-to-end tap from a real Q&A citation
to the source page remain Tier 3/4 gates.

## Addendum — evidence lineage enforcement (2026-07-21)

The next J06 substrate pass confirmed that independent foreign keys were not
enough: `field_evidence` could reference valid rows whose document/page
lineage did not agree. A new additive migration adds a database trigger that
rejects field-to-page cross-document links and field-to-span cross-page links.
The migration also preflights existing rows and aborts rather than silently
accepting already-corrupt lineage.

This is intentionally enforced below the Python service layer so future
workers, backfills, or service-role writers cannot bypass the evidence
contract. It does not yet solve append-only immutability or versioned page
replacement; those remain separate schema decisions requiring migration and
recovery design.

Verification: the evidence schema, substrate service, and owner-boundary
suite passed 31 tests with two existing HTTPX deprecation warnings. This is
Tier 1/2 evidence; the migration has not been applied to a remote Supabase
project in this session, so database execution remains a Tier 3 gate.

## Addendum — consent client authentication boundary (2026-07-21)

The J02 consent trace found that `ServerConsentService` constructed an
independent raw Dio client without the canonical auth interceptor. Its
documented calls to the protected `/consent` API could therefore return 401
even when the rest of the app had a valid session. The service now uses
`DocumentService.authenticatedDio`, with optional Dio injection preserved for
isolated tests.

Verification: the server-consent Flutter suite passed 7 tests and
`flutter analyze lib/services/server_consent_service.dart` reported no issues
(Tier 2). The broader consent flow is not closed: upload still uses the local
Hive ledger plus a versioned form flag, and the server ledger is not yet a
precondition for document processing. That requires explicit consent-type
alignment (`document_processing` versus the server v1 enum), server-first
sync semantics, and offline/retry design before implementation.

## Addendum — document-processing consent synchronization (2026-07-21)

The consent journey now aligns its purpose vocabulary across local and server
ledgers by adding `document_processing` to the server enum/check through an
additive migration. After the local consent gate resolves, the upload screen
attempts one authenticated server append for the consent version. A successful
record ID is cached per version; a failed or unavailable append is not marked
synced and is retried on a later upload. A five-second timeout bounds the
latency cost of an unavailable ledger.

The server-sync cache key is principal-scoped using the authenticated account
ID or current anonymous session ID, so a second account on the same device
cannot inherit another account's already-synced marker.

The local consent remains the immediate offline gate and the upload continues
when the server ledger is unavailable. This is an explicit cache-first fallback
and must not be described as server-acknowledged consent. A future hard-gate
decision still needs account/auth availability, offline policy, and operator
recovery requirements.

Verification: backend consent/API/schema/upload tests passed 24 tests; the
Flutter server-consent suite passed 7 tests and focused analysis was clean.
The migration has not been applied remotely, and a real upload plus ledger
readback remains Tier 3/4 evidence.

## Addendum — durable outbox lease fencing (2026-07-21)

The next J04/J05 reliability pass found that queue mutations were fenced only
by `job_id`. If a worker continued after lease expiry, it could renew or
complete a job already reclaimed by a successor. The new additive outbox
migration introduces a per-claim `lease_token`; the claim RPC rotates it, and
extend/complete/fail require the matching token. Reclaim and requeue also
rotate the token.

The dispatcher now stops a handler when renewal reports lost ownership and
does not issue stale-token failure or completion writes. At-least-once
delivery and handler idempotency remain required: cancellation can happen
after downstream side effects have started, but the durable queue state is no
longer mutable by the stale worker.

Verification: outbox, lease-contract, worker-health, substrate-wiring,
document-job, and owner-isolation tests passed 48 tests; Python compilation
and `git diff --check` passed. The new Supabase migration was not applied to a
remote project, so multi-worker reclaim behavior remains a Tier 3/4 gate.

## Addendum — document deletion fencing and artifact inventory (2026-07-21)

The J04/J07 deletion trace found two lifecycle gaps. First, the document
delete route removed derived data and the source object without changing the
canonical document state first, so a queued or recoverable processing job
could reclaim the same document while deletion was in progress. The route now
marks the owner-scoped metadata row `deleting` before cleanup, and the shared
processing runner refuses new claims and skips terminal persistence when it
observes that fence. Metadata remains during failed cleanup so the user can
retry rather than losing the recovery handle.

Second, successful single-document deletion did not transition the canonical
`document_artifacts` inventory. The route now records the inventory transition
after physical source deletion and before metadata removal; an inventory
failure returns 503 and retains metadata for retry.

Verification: document-processing, repository, and owner-isolation tests
passed 19 tests (Tier 2). This reduces, but does not fully eliminate, a
concurrent already-running pipeline race: a worker can have downstream side
effects in flight before it observes `deleting`. Remote transaction/worker
execution remains a Tier 3 gate. Account erasure now performs a separate
physical cleanup pass for registered derived artifact object references before
marking inventory rows and deleting document metadata. Remote retry and
object-store behavior remain Tier 3 gates.

## Addendum — anonymous-to-account local workspace continuity (2026-07-21)

The J03 trace found that the account auth-state listener closed and deleted
the anonymous principal's encrypted Hive boxes as soon as Supabase emitted the
account session. The subsequent `/user/claim-anonymous` call transferred
server document ownership, but could not restore local files, local metadata,
or navigation state that had already been deleted.

The account form now records explicit claim intent before sign-in. The
principal transition preserves the current workspace entries while reopening
the boxes under the account-scoped DEK only for that claim; ordinary
account-to-account transitions continue to discard the prior workspace. This
keeps server ownership transfer and local encrypted state on the same journey.

Verification: focused Flutter analysis over the four changed files reported
no issues (Tier 1/2). A real anonymous-upload → sign-in → claim → app-restart
run remains a Tier 3/4 gate, including crash recovery during encrypted-box
reopen.

## Addendum — J06/J07 focused-suite reconciliation (2026-07-21)

The earlier verification note recorded citation-verifier and Supabase FTS
collection failures. Re-running the current worktree found both paths load
correctly: the citation tests use the current three-value return contract,
and the installed Supabase package exposes the required client factory for
the injected FTS adapter tests.

The combined anonymous-auth, document-state, citation, evidence-pipeline, and
Supabase-FTS suite now passes **84 tests** with seven existing HTTPX
deprecation warnings. This is Tier 2 evidence; it does not prove a live
two-principal retrieval/citation run.

## Addendum — onboarding consent convergence (2026-07-21)

The J02 pass aligned onboarding with the consent contract. Optional analytics
is now explicit opt-in and an explicit local grant or denial is appended at
completion. Terms acceptance remains required and is stored locally under the
versioned policy contract. A single principal-scoped `ConsentSyncService`
maps local purposes to the server vocabulary (`terms_accepted` to
`privacy_policy`) and retries unsynced current decisions at startup,
onboarding completion, and upload. Successful signatures are cached per
principal and purpose, preventing duplicate server rows on every app launch.

This remains cache-first for offline use: onboarding does not block when the
server ledger is unavailable, and no server acknowledgement is implied by the
local decision. Verification: focused consent ledger/server-consent tests and
Flutter analysis passed; real anonymous/server ledger readback remains Tier
3/4 evidence.

## Addendum — production upload fail-closed rollback (2026-07-21)

The J04 re-trace found a composition failure path not covered by the earlier
durable-enqueue evidence: when production had a processing service but no
outbox, the route returned 503 after metadata and source persistence without
rolling either back. Upload now uses one rollback boundary for every path that
has no durable work record, including enqueue failure, missing production
outbox, and missing production processing composition. The artifact inventory
is marked deleted before metadata/source cleanup so the failure remains
auditable and retry-safe.

Verification: owner-isolation, document-processing, substrate-outbox, and
outbox tests passed 49 tests; Python compilation and `git diff --check` passed
(Tier 2). Production composition and remote object/inventory rollback remain
Tier 3 gates.

## Addendum — principal claim boundary and fail-closed reset (2026-07-21)

The J02/J03 transition audit found that anonymous-to-account workspace copying
was broader than the product contract. The claim path now allowlists user
workspace boxes, filters session identifiers from carried app state, and does
not copy analytics or entitlement mirrors. Workspace reset propagates physical
box deletion failures, so an uncleared old workspace cannot be silently treated
as a successful principal transition.

Evidence: the focused principal/workspace/consent set passes 15 tests and the
full Flutter suite passes 651 tests; Flutter analysis is clean (Tier 2).
Same-process account-A → sign-out → account-B isolation and crash/restart
transition recovery remain Tier 3/4 gates.

## Addendum — cross-caller pending-upload retry coalescing (2026-07-21)

The J04/J05 mobile retry audit found that the pending-upload guard lived on
each `DocumentService` instance, while startup, connectivity recovery, auth
transition, and the visible retry action can construct different instances.
The guard is now a shared in-process future: concurrent callers coalesce onto
one reconciliation pass and receive the same result, preventing duplicate
multipart submissions of the same local source.

Evidence: document deletion/retry and processing-state coverage passes 41
focused tests and Flutter analysis is clean (Tier 2). Cross-process replay,
server idempotency under crash, and offline-to-reconnect device behavior remain
Tier 3/4 gates.

## Addendum — durable processing retry state correction (2026-07-21)

The backend J04/J05 audit found that an exception in the durable document
worker was requeued by the outbox but persisted the document as `failed`.
`claim_processing` cannot lease a failed document, so the requeued job could
never actually retry. The canonical runner now returns retryable worker
failures to `received` with the lease cleared; the final outbox attempt marks
the document terminally failed. The development in-process compatibility path
retains terminal failure behavior.

Evidence: document-processing and owner-isolation coverage passes 19 tests;
full backend regression and a live worker retry/dead-letter traversal remain
Tier 2/3/4 evidence gates.

## Addendum — consumable webhook ordering fence (2026-07-21)

The J08 billing audit found that a valid Q&A pack purchase could be marked
`stale_ignored` when its provider timestamp was older than a separately
delivered subscription event. Pack grants are independent ledger facts, so the
canonical webhook RPC now processes known consumables before subscription-state
ordering; `provider_event_id` remains the duplicate-grant fence. Unknown
consumables remain explicitly unsupported.

Evidence: billing/webhook/ledger contract coverage passes 15 tests (Tier 2).
Live RevenueCat replay ordering, duplicate delivery, and cross-device pack
balance convergence remain Tier 3/4 gates.

## Addendum — inventory-driven physical artifact deletion (2026-07-21)

Account and single-document erasure now traverse the canonical
`document_artifacts` inventory across source, page, derived, and embedding
objects. Each storage delete is attempted before its row transitions to
`deleted`; failures retain retryable metadata. Focused artifact, lifecycle,
account-erasure, and document-owner tests passed 24/24 (Tier 2). Deployed
storage traversal, concurrent-worker proof, and scheduled retention execution
remain Tier 3/4 gates because retention is not yet registered as an outbox
handler or scheduler.

## Addendum — J04/J05 composition and remote schema recheck (2026-07-21)

The upload path was re-audited at the production composition boundary. When
the durable outbox is configured, uploads enqueue `document_processing`; the
FastAPI `BackgroundTasks` branch is retained only for development compatibility
and production fails closed if no durable queue is available. The worker reads
the canonical object reference and uses the shared owner-scoped processing
lease runner.

The read-only remote schema verifier now returns exit code 0 with all required
tables present, including `model_run_results`. The earlier missing-table note
is superseded; migration-ledger parity and live deployed upload/recovery remain
open evidence gates.

## Addendum — deployed verifier mutation boundary (2026-07-21)

The launch verifier previously created two anonymous identities by default
while describing itself as non-mutating. The default verifier is now read-only
with respect to identity creation; the two-owner profile/list probe requires
the explicit `--allow-identity-creation` flag. Focused verifier coverage passes
5/5 (Tier 2). A deployed run and cleanup/retention policy for authorized test
identities remain Tier 3/4 operational gates.

## Addendum — outbox lease renewal failure fence (2026-07-21)

The dispatcher previously continued a handler when lease renewal raised an
exception, even though ownership was no longer observable. It now cancels the
handler and leaves the durable row for lease expiry/reclaim; stale workers do
not call `fail` or `complete`. Worker/outbox regression coverage passes 36/36
(Tier 2). Multi-worker remote reclaim and downstream idempotency remain Tier
3 evidence gates.

## Addendum — governed dataset source-linkage consent fence (2026-07-21)

The evaluation/training registry now rejects any item linked to a source
document unless owner identity and a consent-record reference are both present;
source chunks also require their parent document identity. This closes a
customer-derived-material ambiguity at the registry boundary without affecting
operator-authored synthetic items. Dataset-registry, execution, and lineage
tests pass 18/18 (Tier 2). Real approved-release provider execution and
withdrawal propagation remain Tier 3/5 gates.

## Addendum — retention pass contract and upload boundary (2026-07-21)

The canonical `tools/run_data_retention.py` entry point now exposes one bounded
`run_retention_pass()` contract covering analytics purge, expired-artifact
fencing, and deletion of already-fenced objects. It validates retention days,
artifact batch bounds, and timezone-aware execution time, and returns a
structured operator report. Focused retention/worker/upload tests passed 28/28
across the affected suites. Scheduling and deployed observation remain
external Tier 3/4 gates.

## Addendum — production recovery ownership (2026-07-21)

The J05 trace found that production API startup still invoked the repository
recovery scan for `received` documents even after upload moved to the durable
outbox. That was a parallel worker path: repository claiming reduced duplicate
processing, but API recovery bypassed outbox retry/dead-letter visibility and
could process work outside the worker's operational boundary.

Production API startup now leaves recovery exclusively to the outbox worker;
the legacy repository scan remains development-only compatibility. Verification
includes a production-lifespan contract test and the existing processing/
outbox suite. A deployed restart/reclaim run remains Tier 3/4 evidence.

## Addendum — typed room-rent extraction contract (2026-07-21)

The J06 structured evidence extractor now uses `RoomRentCapExtraction` as its
canonical Pydantic response contract instead of parsing a free-form JSON
object. Bounded clause/display fields, typed validation, structured-call
failure handling, and the exact-text source check fail closed before an
unverified value can enter the evidence substrate.

Verification: `tests/test_evidence_pipeline.py` passes 24 tests, including
typed-output validation, structured failure, and hallucinated-clause rejection;
Python compilation and `git diff --check` pass (Tier 2). Live provider schema
enforcement, cost attribution, and corpus-level extraction quality remain open
Tier 3/4 gates.

## Addendum — OpenAI/httpx startup-contract re-audit (2026-07-21)

The older launch-audit note about an OpenAI/httpx `proxies` initialization
failure was rechecked against the current dependency contract. Production pins
`openai==1.3.0` and `httpx==0.27.2`; the OpenAI 1.3 client passes `proxies`, and
httpx 0.27.2 exposes that parameter. The active environment also initializes
successfully with `openai 1.109.1` and `httpx 0.27.2`, and the runtime/fallback
configuration tests pass.

Disposition: the local dependency-contract finding is closed, while a clean
production-image install and startup probe remain Tier 3 evidence. The local
provider fallback contract and real provider availability remain separate
runtime gates.

## Addendum — retrieval citation-status accounting (2026-07-21)

The J07 retrieval trace counter had drifted from the canonical answer contract:
`RAGCitation` and `answer_evidence` expose `citation_status`, while trace
accounting looked for the obsolete `verification_status` key. Verified and
approximate citations could therefore be returned correctly but recorded with
zeroed trace counters. Accounting now reads `citation_status`, retaining only
a bounded compatibility fallback for older injected objects.

Verification: RAG, citation-verifier, and retrieval-audit tests pass 25 tests
with one existing HTTPX deprecation warning; compilation and `git diff --check`
pass (Tier 2). Live Supabase trace-readback and operator dashboard validation
remain Tier 3 gates.

## Addendum — Supabase ingestion owner fence (2026-07-21)

The backend parity trace found that `SupabaseVectorStore.upsert()` accepted a
missing owner and stored an ownerless row (`owner_id = ""`). Such a row could
not be retrieved through the owner-required RPC, creating silent ingestion
success with an inaccessible artifact. Supabase ingestion now rejects missing
or blank owners before any write; Qdrant/local compatibility paths remain
separately scoped.

Verification: Supabase FTS, RAG, and document-owner tests pass 28 tests with
one existing HTTPX deprecation warning; compilation and `git diff --check`
pass (Tier 2). Remote cross-backend ingestion/retrieval/deletion parity remains
Tier 3/4 evidence.

## Addendum — upload contact-field boundary audit (2026-07-21)

The J02/J04 trace found a stale contract rather than a safe deletion: Flutter
accepts optional email/phone parameters but does not send them in upload,
while the backend still accepts and stores legacy lead-capture fields and
returns `lead_data` from document status. The active journey keeps contact
details local unless a future explicit share action is introduced.

No code was removed because external integrations may depend on the
compatibility fields. The next decision is to deprecate them after caller
inventory or map them to a distinct consent-ledger purpose and explicit sharing
journey. Until then, customer-facing copy must not imply active upload contact
capture.

## Addendum — account-erasure write fence (2026-07-21)

The account-lifecycle trace found a race between durable deletion inventory and
new writes: pending/running erasure did not prevent document inserts or
anonymous-to-account owner transfers from adding data after inventory. The new
`20260721150000_account_deletion_write_fence.sql` migration adds one Postgres
trigger boundary for document inserts and `owner_id` changes. The API handles
friendly errors; the database owns the race fence.

Verification: account-fence, lifecycle, account-deletion, owner-isolation, and
outbox tests pass 51 tests with six existing HTTPX deprecation warnings; Python
compilation and `git diff --check` pass (Tier 2). Remote concurrent upload /
claim-versus-erasure validation remains Tier 3 evidence.

## Addendum — erasure retry checkpoint (2026-07-21)

The erasure worker now carries forward persisted `stage_state` when restarting
a failed request. An auth-deletion checkpoint is honored, preventing a retry
after successful `delete_user` from calling auth deletion again. Storage
failure counters reset for the new attempt while prior progress remains
operator-visible.

Verification: lifecycle, write-fence, account-deletion, and worker tests pass
12 tests with six existing HTTPX deprecation warnings; compilation and
`git diff --check` pass (Tier 2). A fault-injected remote post-auth failure and
outbox replay remains Tier 3 evidence.

## Addendum — pending-deletion action boundary (2026-07-21)

The authenticated-surface inventory found that mobile signs out immediately
after a 202 deletion request, while the database fence blocks new document
inserts and ownership transfers during pending/running erasure. Read-only
query/export and individual document deletion remain available for recovery
and accelerated cleanup; no blanket route lock was added. Dedicated deletion
status readback and a deployed sign-in-again-while-pending journey remain open.

Verification: route/static inventory plus account lifecycle/write-fence tests
provide Tier 1/2 evidence; no deployed pending-state runtime was run.

## Addendum — rejected-citation trace preservation (2026-07-21)

The citation-status correction exposed a second observability gap: rejected
citations are intentionally removed from the customer response, so deriving
trace counts only from surviving citations always reported zero rejected
items. Query responses now carry private cache metadata for the verified,
approximate, and rejected counts; the metadata is stripped before returning to
the caller, while cache hits retain accurate audit accounting.

Verification: the focused RAG/citation/audit suite passes 25 tests, including
status-count coverage; compilation and `git diff --check` pass (Tier 2). Live
Supabase trace readback and dashboard validation remain Tier 3 gates.

## Addendum — adjacent-link producer gap (2026-07-21)

The retrieval trace found that Supabase adjacent expansion reads
`chunk_links`, but no active ingestion path writes `adjacent` links. A clean
deployment can therefore pass owner-fence tests while returning no adjacent
context. The next stage must select one canonical producer—deterministic
chunk-index adjacency or an explicit link-generation stage—with idempotency,
deletion behavior, and held-out context-quality verification before claiming
the feature is available.

Owner fencing is implemented; adjacent-context availability remains unverified
Tier 3/4 work.

## Addendum — deterministic adjacent-context stage (2026-07-21)

Supabase expansion now prefers explicit owner-scoped `chunk_links` and falls
back to neighboring `chunk_index` values within the same owner and document
when no materialized adjacent link exists. Adjacent hits preserve
`source_text` separately from `retrieval_text`, so contextualized retrieval
text cannot become citation evidence. Graph links remain the extension point
for semantic/structural relations.

Verification: Supabase FTS, RAG, and owner-isolation checks pass, including the
new fallback and source-lineage test; compilation and `git diff --check` pass
(Tier 2). Remote traversal/deletion and held-out context-quality verification
remain Tier 3/4 gates.

## Addendum — source/retrieval layer parity (2026-07-21)

The direct Qdrant path and local SQLite fallback now preserve the same lineage
contract as Supabase: `source_text` is immutable, citable evidence and
`retrieval_text` is the embedding/search representation that may contain
contextualization. The local index performs an additive migration for older
schemas and backfills legacy rows from `text_content`, explicitly acknowledging
that the prior distinction is unrecoverable for those rows.

Verification: `tests/test_rag_pipeline.py`, `tests/test_supabase_fts.py`, and
`tests/test_document_owner_isolation.py` pass 30 tests with one existing HTTPX
deprecation warning; `py_compile` and `git diff --check` pass (Tier 2). A clean
production-image migration, remote Qdrant/local parity, and held-out quality
run remain Tier 3/4 work.

## Addendum — offline upload reconciliation (2026-07-21)

J03/J04 now has a durable mobile reconciliation path. Offline records retain
their processing-consent version, are discovered from local storage, and are
retried on startup, connectivity restoration, or an explicit library action.
The retry updates the existing local record with the server ID, preserving one
local identity and avoiding duplicate local artifacts. Network/transport
failures stay retryable; missing local files become explicit terminal failures.

Verification: focused Flutter storage, retry/deletion, sorting, and processing
tests pass 57 tests and targeted Flutter analysis reports no issues (Tier 2).
Real-device reconnect behavior, account-principal transition, server-side
idempotency under repeated retry, and background delivery remain Tier 3/4 gates.

## Addendum — cross-backend entitlement authority (2026-07-21)

The server entitlement boundary is now consistent across local and remote
billing adapters. A client-provided RevenueCat sync is stored as telemetry but
cannot grant paid server capability; only a verified RevenueCat webhook state
is authoritative. Accounts without verified state resolve to the free tier for
server decisions, even if the local client displays a pending purchase state.

Verification: billing-ledger, subscription webhook, writeback, owner-isolation,
and runtime-config tests pass 37 tests with three existing HTTPX deprecation
warnings; compilation and `git diff --check` pass (Tier 2). Deployed entitlement
readback, real provider delivery, and the shared upload/Q&A usage reservation
ledger remain Tier 3 work.

## Addendum — server-authoritative Q&A usage and pack grants (2026-07-21)

Production Q&A consumption now has a transactional server contract. RevenueCat
webhook events grant consumable packs idempotently without overwriting active
subscription state; the usage RPC owner-locks consumption, applies verified
subscription quota first, then earliest-expiring packs, and uses a request UUID
to make transport retries non-charging. The root query reserves before RAG and
the mobile client carries the request ID and handles exhausted/unavailable
server budgets explicitly.

Verification: Q&A ledger, query-gate, billing, subscription, and runtime tests
pass 21 backend tests with three existing HTTPX deprecation warnings; targeted
Flutter analysis is clean and Q&A/pack/entitlement tests pass 63 tests (Tier 2).
Fresh migration/reset, real RevenueCat pack delivery, cross-device grant
reconciliation, and deployed retry/readback remain Tier 3/4 gates.

## Addendum — server-authoritative policy-slot reservation (2026-07-21)

Production uploads now reserve policy capacity through an owner-locked
Supabase RPC. The reservation counts committed documents and in-flight uploads,
uses only verified webhook entitlement state, and is finalized after durable
source/metadata persistence. Every rollback path releases the reservation;
stale pending reservations are reclaimable. This is the upload half of the
long-term shared entitlement boundary; Q&A consumption and purchased-pack
reconciliation remain separate work.

Verification: policy-slot adapter/contract, upload owner-isolation, processing,
document-intelligence, billing, and subscription tests pass 43 tests with
three existing HTTPX deprecation warnings; compilation and `git diff --check`
pass (Tier 2). Fresh migration/reset, concurrent remote upload, and deployed
rollback/reclaim replay remain Tier 3 evidence.

## Addendum — deletion status readback and pending re-entry (2026-07-21)

The account-deletion flow now has a durable user-facing re-entry boundary.
After the production API returns `deletion_requested` and the mobile client
signs out, a later authenticated session can read the latest owner-scoped
status through `GET /user/account/deletion-status`. The response deliberately
projects lifecycle state and timestamps only; raw stage state and internal
failure classes remain out of the customer contract. Profile re-entry shows
queued, running, or failed deletion state and gives the user a refresh action.

Verification: focused lifecycle/API tests pass 7 tests with three existing
HTTPX deprecation warnings; the mobile model tests pass 2 tests and targeted
Flutter analysis is clean (Tier 2). Live Supabase migration, worker completion,
re-login, and failed-deletion retry remain Tier 3/4 verification.

## Addendum — account re-entry document reconciliation (2026-07-21)

The J02/J03 identity trace found that principal-scoped local encryption was
correct but incomplete as a product journey: `getDocuments()` read only local
Hive, so a valid account session on a new device had no way to materialize the
account's remote policy list. The canonical document service now reconciles a
complete paginated `/documents` snapshot into local metadata. It keeps
`pending_upload` records, hydrates remote-only records without fabricating a
local source file, and removes stale local remote records only after the full
snapshot succeeds. A malformed later page leaves the previous local state
untouched.

Verification: two focused mobile reconciliation tests pass and targeted
Flutter analysis is clean (Tier 2). Live authenticated cross-device sync,
large-account pagination, and remote-only source retrieval remain Tier 3/4
gates.

The same pass removed a hidden J07 billing side effect: library hydration no
longer spends a Q&A request to infer an unknown type during ordinary rendering.
That work remains behind the explicit document-type refresh action, preserving
the user-visible and auditable quota boundary.

Verification: the no-hidden-query mobile regression passes and targeted
Flutter analysis remains clean (Tier 2).

Remote-only account records are now eligible for server-backed Q&A once they
have a stable remote identity; only local source preview remains unavailable.
The UI therefore does not conflate “not cached on this device” with “not
queryable from the account’s server evidence.”

Verification: the document-action contract tests pass and targeted Flutter
analysis remains clean (Tier 2).

The document-screen test harness was hardened as part of regression closure:
it no longer awaits recursive deletion of open Hive files, which had stalled
the full suite during teardown. The focused document-screen suite passes 11
tests, and the complete Flutter suite passes **646 tests** with clean full-app
analysis. This is local Tier 2 evidence; it does not replace authenticated
device or deployed cross-device runtime proof.

## Addendum — second-device source verification (2026-07-21)

The remaining J03/J06 trust break was that an account could reconcile a
remote policy and ask grounded questions on a second device, but could not
inspect the original source. The canonical owner-scoped document API now
issues a 15-minute signed source URL after repository ownership verification.
It returns no object reference and reports local-store/no-source limitations
explicitly. This extends the existing object-store abstraction rather than
creating a parallel export or preview pipeline.

Mobile downloads are bounded by the established 50 MB upload ceiling and
validated for non-empty content and expected server size before the source is
attached to the existing local metadata identity. The signed URL itself is
not persisted. The document library offers a source-download action for
remote-only records, then opens the existing local PDF/image verifier; a
failed download does not fabricate local availability.

Evidence: the new owner-isolation/source-access tests and existing owner
regression pass 14 tests; the focused Flutter account/library/screen suites
pass 16 tests; targeted Flutter analysis is clean (Tier 2). Authenticated
second-device download, object-store access-policy enforcement, URL expiry,
and production runtime behavior remain Tier 3/4 gates.

## Addendum — Q&A reservation lifecycle and failed-request fairness (2026-07-21)

The J07 usage ledger had a material failure-mode gap: it reserved and
decremented usage before RAG execution, but could not return the question when
the processing service or provider failed. The correction is a durable
reservation lifecycle. New usage rows are `reserved`; successful answer
delivery finalizes them as `consumed`; processing failures release them, and
released pack reservations restore the pack balance. The same request UUID
remains idempotent for transport retries and can be reopened only after a
release and only if budget remains.

The ledger also reclaims `reserved` rows older than 15 minutes under the
owner-scoped advisory lock, restoring stale pack reservations. This protects
against the compensating release itself being lost during a provider outage.

The API now releases on unavailable processing, explicit processing errors,
unexpected response shapes, and exceptions, and finalizes only before
returning a successful answer. Mobile already renders budget exhaustion and
usage-verification failures through explicit user-facing paths.

Evidence: Q&A gate/service/contract/owner tests pass 20 tests and Python
compilation/diff checks pass (Tier 2). Supabase transaction semantics,
concurrent reservation behavior, pack restoration, and deployed paid-query
replay remain Tier 3/4 verification gates.

The full backend regression after this correction completed with **444 passed,
1 intentionally skipped** in an isolated temporary directory. The remaining
44 warnings are existing dependency deprecations; no new test failure was
observed.

## Addendum — sensitive processing-input envelope (2026-07-21)

The J05 durable-processing trace identified a privacy boundary failure: PDF
passwords and optional on-device OCR text were being copied into the outbox
JSON payload even though the source bytes were correctly excluded. The upload
path now encrypts those request-scoped inputs with an AES-GCM envelope bound
to the document ID. The worker decrypts only in memory and rejects legacy
plaintext fields in production. The encryption key is now part of the
Secret Manager-backed API/worker launch contract.

Evidence: secure envelope round-trip/tamper tests, upload payload assertions,
runtime configuration, worker, outbox, and owner-isolation checks pass; the
isolated full backend regression completes with **450 passed, 1 intentionally
skipped**. Rotation, replay, and production queue-observation evidence remain
Tier 3/4 gates. Critical Ruff checks, Python compilation, and deployment shell
syntax also pass.

## Addendum — RevenueCat consumable/subscription separation (2026-07-21)

The billing and entitlement path was rechecked end to end: RevenueCat
authorization, webhook validation, outbox handoff, transactional ledger
processing, stale/duplicate event handling, client-sync non-authority, and
mobile offline mirrors. The canonical production path remains:

```text
RevenueCat -> authenticated webhook -> durable outbox -> server RPC
  -> webhook event fence + subscription/pack ledger -> server Q&A gate
  -> mobile UI mirror and explicit error/retry state
```

An unknown `NON_RENEWING_PURCHASE` product was a real failure mode: it could
be interpreted as a free subscription event and downgrade an existing verified
subscription. The development fallback now rejects it as
`unsupported_product`; migration
`20260721200000_revenuecat_unknown_consumable_fence.sql` applies the same rule
to the production RPC. Known pack products remain grant-only and never write
subscription state.

Evidence: targeted webhook tests pass, including the paid-subscription plus
unknown-consumable regression (Tier 2). A live Supabase migration/replay,
duplicate and stale delivery under concurrency, and operator visibility of
unsupported products remain Tier 3/4 gates while local Postgres is unavailable.

The remaining product/architecture gap is explicit: mobile adds a pack to its
local Hive mirror immediately after a successful store purchase, while the
server grant is created asynchronously by the webhook. This is acceptable only
as a provisional offline display; server Q&A authorization must remain the
authority. The long-term closure is an owner-scoped server pack-balance
readback plus reconciliation state for pending, granted, failed, and expired
pack purchases. It should be added as one canonical billing-read path, not a
second entitlement store.

## Addendum — offline upload retry classification (2026-07-21)

The current J04/J05 mobile path has a durable local pending-upload marker and
an actual reconciliation owner. Startup, connectivity recovery, foreground
resume, authenticated-principal transition, and a visible Documents retry
action invoke the same retry method; successful responses update the existing
local record with the remote identity rather than creating a second local
document.

The failure contract now keeps HTTP 408, 409 `upload_in_progress`, 429, and 5xx
responses pending. Missing source files and permanent server validation or
entitlement responses become explicit failures. The processing-status screen
also cancels only its own timer and leaves the shared authenticated client
alive.

Evidence: 69 focused Flutter document/reconciliation/status tests pass and
Flutter analysis is clean (Tier 2). Real offline-to-reconnect processing,
restart recovery, account-switch ownership, and production duplicate replay
remain Tier 3/4 gates.

## Addendum — principal workspace migration and bootstrap ordering (2026-07-21)

The J02/J03 local trust boundary now deletes legacy Hive box files through
`Hive.deleteBoxFromDisk` after closing the old-key handle, then reopens under
the stable principal DEK. Migration exceptions are fail-closed, protecting
legacy data from being hidden by a new unreadable workspace. The custom
anonymous API-token warm-up runs after the encrypted workspace and analytics
boxes exist, while remaining separate from the Supabase principal used for
account identity.

Evidence: 15 focused principal/workspace-adjacent tests pass and Flutter
analysis is clean (Tier 2). Real legacy-box migration, crash recovery, and
same-process account-A → sign-out → account-B isolation remain Tier 3/4 gates.

## Addendum — account-erasure owner binding and dead-letter retry (2026-07-21)

The J02/J03 deletion journey now binds the destructive worker to the durable
request owner before it can mark the request running, withdraw owner data,
delete artifacts, or delete the auth user. Every lifecycle update in the
attempt and retry path remains scoped to both request ID and account UID.

The account-deletion outbox lookup can ignore completed/dead-lettered history;
the forward index migration preserves those audit rows while permitting one
new active retry job. Active duplicate deletion submissions remain converged.

Evidence: 44 focused deletion/lifecycle/outbox/API tests pass (Tier 2).
Live Supabase owner/index behavior, worker retry after dead-letter, and full
physical erasure verification remain Tier 3/4 gates.

## Addendum — upload-slot identical-source concurrency (2026-07-21)

The J04 upload quota reservation was re-audited at the duplicate/retry race
boundary. A second identical source arriving while the first request still had
a pending reservation could previously reuse that reservation and compete at
finalization. The canonical RPC now returns `upload_in_progress`; the API
surfaces HTTP 409 so the caller can retry without creating a second document.

Committed replays remain handled by source-hash idempotency, and stale pending
reservations remain reclaimable after 30 minutes. Evidence: 18 focused
policy/upload tests plus compilation, critical Ruff, and diff checks pass
(Tier 2). Live concurrent Supabase/Postgres replay and crash recovery remain
Tier 3 gates.

## Addendum — server-authoritative Q&A pack readback (2026-07-21)

The J08 consumable path now has one canonical read contract: authenticated
`GET /subscription/qa-balance` reads active, unexpired `qa_pack_grants` through
the service-role-only Supabase RPC `get_qa_pack_balance`. The mobile client
reconciles its Hive pack mirror only after a verified response, including a
verified empty response. A completed store transaction with a still-pending
RevenueCat webhook no longer creates local questions; the UI says the purchase
will appear after server confirmation. Startup, account identification,
purchase, and restore all invoke the same readback path.

Evidence: backend ledger/migration coverage passes 9 tests for this focused
contract, focused Flutter pack-service coverage passes 34 tests, and touched
Flutter analysis is clean (Tier 2). Live authenticated two-device convergence,
webhook delay/replay, anonymous-to-account pack transfer, and production
entitlement/readback remain Tier 3/4 gates.

## Addendum — anonymous-to-account pack ownership (2026-07-21)

The identity-link sweep found that the existing anonymous workspace claim
transferred documents and chunks but left verified Q&A pack grants under the
anonymous owner. The canonical claim RPC is now extended, after the pack ledger
exists, to move those grants and their audit-visible ownership in the same
transfer boundary. This preserves a pack purchased before account creation
without allowing the client to self-assign it.

Evidence: migration contract coverage is included in the focused billing
checks. Live RevenueCat anonymous purchase, account conversion, retry, and
cross-device readback remain Tier 3/4 gates.

## Addendum — empty OCR success correction (2026-07-21)

The parser capability audit found that an OCR adapter could return
`status=completed` with an empty `full_text`; the document service also
overwrote adapter status during its fallback path. Both boundaries now reject
that result as `no_text_extracted` and expose `capability=scanned_ocr`, keeping
an unreadable scan out of policy extraction, evidence, and RAG as if it were a
valid document.

Evidence: focused OCR, mixed-page, CIR, and runtime-health coverage passes 23
tests, with compilation and diff checks clean (Tier 2). Accuracy benchmarks,
real scan corpus replay, and deployed operator recovery remain Tier 3/4 gates.

## Addendum — purpose-bound evaluation consent (2026-07-21)

The governed dataset audit found that owner and `granted=true` checks did not
prove secondary-use authority: a historical document-processing consent could
be reused after revocation or for an unrelated training/evaluation purpose.
Customer-derived items now require the current consent-view row to match the
referenced ID, owner, purpose-specific consent type, granted state, and the
release's pinned consent-policy version. The schema adds explicit
`evaluation_dataset` and `model_improvement` vocabulary; no customer-derived
item is admitted until a user-facing grant path exists.

Evidence: focused dataset/consent/execution coverage passes 33 tests (Tier 2).
Live Supabase current-view behavior, operator approval, and customer-facing
secondary-use consent UX remain Tier 3/4/legal-review gates.

## Addendum — explicit text-fallback boundary (2026-07-21)

The parser audit found that the service-level fallback accepted any unknown
extension as text with `errors="ignore"`, even though public upload validation
accepts only PDF and image formats. This could hide unsupported XLSX/PPTX/email
or arbitrary binary inputs behind a completed extraction. The fallback now
uses one explicit internal text-format allowlist, rejects unsupported
extensions, rejects NUL-containing binary content, and rejects invalid UTF-8.

Evidence: focused upload, document-intelligence, native-office, and mobile-OCR
coverage passes 28 tests (Tier 2). Real malformed-format corpus replay,
public upload UX for new formats, and deployed operator recovery remain open
Tier 3/4 gates.

## Addendum — on-device OCR evidence-artifact bridge (2026-07-21)

The processing-to-review trace found that image/PDF on-device OCR recovery
returned page text but no page image. The production path correctly avoided
putting raw OCR into the outbox, but the substrate worker can only reload page
OCR from persisted page artifacts; without an image, the queued job could
retry/dead-letter and leave the review surface indefinitely unverified. The
service now renders page one as a canonical PNG from the original image/PDF
source and carries it into the existing page-artifact persistence path.

Evidence: focused sidecar, evidence-pipeline, outbox-wiring, and state tests
pass 21 tests (Tier 2). Live worker replay, page-artifact readback, and
authenticated review traversal remain Tier 3/4 gates.

## Addendum — Q&A source attribution and submit-state correction (2026-07-22)

The Q&A review trace found that the custom-question button did not listen to
text edits and that source objects could lose the response-level document
identity. The UI now derives submit availability from the text controller, and
`QaAnswer` passes the top-level document identity into source parsing when a
source omits its own identifier. Source-reference coverage passes 8 tests (Tier
2). Live backend Q&A and authenticated source navigation remain unverified.
