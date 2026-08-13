# Tech Debt Register

**Last updated:** 2026-07-22

Register of known technical debt with remediation plans. Prioritised by revenue/security risk first, then developer velocity.

---

## Critical

### C-01 Client-side entitlement enforcement
Upload policy limits and Q&A budget gating are enforced client-side only. The server accepts any `/query` call and charges after the response; `/upload` has no server-side budget reservation. Billing sync accepts client-declared RevenueCat state.

**Impact:** Revenue integrity risk — a compromised client or API caller can bypass plan limits entirely.

**Remediation:** Implement server-enforced entitlement ledger: check entitlements on every Q&A call and upload, remove client-only plan gates.

**Estimate:** ~2 days

---

## High

### H-01 Outbox shipped but not adopted by 5 async paths
The Supabase outbox table + service + dispatcher + worker is shipped and tested, but 5 existing in-process async paths (document processing, evidence substrate extraction, Q&A, webhook reconciliation, subscription writeback) are NOT migrated. The outbox is dormant in production.

**Impact:** Lost work on crash/restart; no idempotency or retry guarantees for critical async paths.

**Remediation:** Migrate each path to use the outbox.

**Estimate:** ~5 hours

### H-02 Remote Supabase migration ledger mismatch
51 local migration files vs 16 rows in the remote `_supabase_migrations` table. Object parity is confirmed, but rollback and replay are compromised.

**Impact:** Cannot reliably rollback or replay migrations on the remote project.

**Remediation:** Reconcilation: either a checked-in baseline/squash or a fully replayable migration ledger with proven idempotence.

**Estimate:** ~1 day

### H-03 Offline upload has no reconciliation worker
`pending_upload` persists locally but has no mobile retry consumer, no connectivity trigger, and no explicit retry/cancel UI.

**Impact:** Documents uploaded while offline are silently lost if the app is killed before connectivity returns.

**Remediation:** Implement durable retry worker with idempotency, backoff, auth transitions, and operator visibility.

**Estimate:** ~1 day

### H-04 10 half-built features not actioned
ADR-2026-07-19-08 documents cut/keep/finish decisions for Health Score, What-If Calculator, Lead Capture, Literacy Quiz, Billing, Q&A packs, Family, Claim Tracker, Insurance Cards, and Upgrade screen. Decisions have not been executed.

**Impact:** Code entropy; dead features in the live app confuse users and increase maintenance surface.

**Remediation:** Execute cut (remove Health Score, What-If, Literacy Quiz), redesign (Lead Capture), finish (Billing, Q&A packs, Family, Claim Tracker, Insurance Cards).

**Estimate:** ~3 days

---

## Medium

### M-01 53 scattered `Hive.box()` calls
Hive boxes accessed directly from screens, providers, and services across 20+ files. No single repository pattern.

**Impact:** Brittle — changing box names or migration logic requires touching many files.

**Remediation:** Consolidate behind `HiveWorkspaceService` and `AppStateRepository`; remove direct `Hive.box()` calls from screens and providers.

### M-02 Deprecated OCR microservice still live
`src/ocr/service.py` is marked `@deprecated` — a standalone FastAPI OCR microservice superseded by in-process `/process-and-ingest`. Still present and importable.

**Impact:** Confusing for new developers; could be accidentally deployed.

**Remediation:** Remove after confirming no external consumers exist. Target: next major release.

### M-03 Deprecated `/documents/query` route still active
Old route logs a warning but returns success payloads. No deprecation deadline set.

**Impact:** Maintains a compatibility surface indefinitely.

**Remediation:** Set a deprecation deadline, add `Sunset` header, remove after window expires.

### M-04 Completer-based file picker fragile
`WebFilePickerHtml` uses static `Completer` fields — a second pick before the first completes would share state.

**Impact:** Bug surface for multi-file upload flows.

**Remediation:** Use proper async pattern or dedicated state machine.

### M-05 Principal key migration deferred
Per-box migration from device-key to principal-key has known gaps: two-principal authenticated restart/replay not proven.

**Impact:** Local data could become inaccessible on principal transition.

**Remediation:** Complete per-box migration verification, prove two-principal restart, close Tier 3/4 gates.

### M-06 Consent ledger cache-first pattern
Local Hive box is primary read path for consent decisions. Cache can drift from server.

**Impact:** Stale consent decisions could be presented to the user or enforced locally after server-side revocation.

**Remediation:** Implement server-first read path with cache fallback, add "last verified at" indicator and pull-to-refresh.

### M-07 Performance budgets not enforced in CI
60 MB APK budget and <3s cold start adopted but not enforced in CI; startup benchmark gated on manual device run.

**Impact:** Budgets are aspirational — no regression gate.

**Remediation:** Wire APK size step to fail CI on budget breach; integrate startup benchmark into CI pipeline.

### M-08 16 `as dynamic` / `.cast<>()` patterns
Weak typing at JSON deserialization boundaries across main.dart, services, and screens.

**Impact:** Runtime cast failures; hides type errors from the compiler.

**Remediation:** Introduce typed `fromJson` factories with `json_serializable`; eliminate raw `cast<>()` calls.

### M-09 Localization migration incomplete
Localization catalog adopted by Q&A only; most screens still hold direct literals. Shared snackbar helper is incremental; legacy flows render raw snackbars.

**Impact:** Inconsistent user experience across the app.

**Remediation:** Complete extraction across all screens, add locale/placeholder tests, consolidate raw snackbar callers.

### M-10 Analytics schema not enforced
Backend accepts arbitrary event properties — safety is caller-enforced rather than schema-enforced.

**Impact:** Analytics data quality degrades over time; no validation at the API boundary.

**Remediation:** Implement schema enforcement for analytics events with validation at the API boundary.

---

## Low

### L-01 50+ `debugPrint()` calls in production code
No structured logging framework in place.

### L-02 5 `Future.delayed` timing hacks
Artificial delays in production code paths (splash, QA screen, document preview).

### L-03 2 `.then()` chains instead of async/await
In main.dart — potential unhandled-rejection paths.

### L-04 Resolve "Restore tests" TODO in `global_error_boundary_test.dart:6`
TODO to restore recovery/error-persist tests with mocked AnalyticsService.

### L-05 5 debug test files checked in
`debug_tos*.dart` and `debug_hive_clear.dart` in the test directory.

### L-06 Hardcoded Hive box names in `hive_workspace_service.dart`
7 box names hardcoded — extract to constants file.

### L-07 `PROCESSING_TEMP_DIR` defaults to relative `"temp"`
Could resolve to unexpected path.

### L-08 `SPOOFING_ATTEMPT` log includes user-controlled data
User-controlled `claimed_plan` in plain-text log message.

### L-09 Route screen content not wrapped in `ScreenErrorBoundary`
Named routes (settings, help, documents, etc.) accessed via `Navigator.pushNamed` are not wrapped in per-screen error boundaries. Only the 5 main tabs are covered.

**Remediation:** Wrap each route builder in `main.dart` with `ScreenErrorBoundary`.

---

## 2026-08-12 Sweep Additions (from `docs/planning/backlog_missing_partial_work_and_expansion_2026-08-12.md`)

> Additive findings from a `motto_v5` missed-anything sweep. Items below are NEW and are **not** verified by a test run (evidence tiers are in the backlog doc). They extend — not replace — the register above.

### C-02 (CRITICAL) No tests on the Supabase auth boundary
`get_current_user` (the gate for nearly every protected endpoint) has **zero dedicated tests** — only `tests/test_anonymous_auth.py` exists; there is no `tests/test_supabase_auth.py`. JWT verification, expiry, revocation, and claim/role handling are untested.
- **Impact:** Security-critical path untested; an auth regression would ship unnoticed.
- **Remediation:** Add `tests/test_supabase_auth.py` (valid/invalid/expired/malformed JWT, missing `sub`, anonymous fallback; assert 401/403 boundaries).
- **Evidence:** T4-verified (direct read this pass).
- **Status:** **RESOLVED (2026-08-13)** — `tests/test_supabase_auth.py` added (10 tests) covering bearer-scheme rejection, anonymous→Supabase fallback, missing-`sub`→401, and a wire-level regression proving a 3-segment token + unconfigured Supabase returns 401 (not 500). Also hardened `src/api/user.py::get_current_user` to raise 401 (not KeyError→500) on a `sub`-less claim.

### H-05 (HIGH) Policy-extraction service cannot initialize in production
`src/services/policy_extraction_service.py:35-41` — on the prod branch a `raise RuntimeError` precedes the only `create_client` import (dead code); line 41 references `create_client`, which is never imported on this path → `NameError` when prod creds are present (or `RuntimeError` when absent). Swallowed at `document_processing_service.py:234` and `rag/pipeline.py:2252` → **policy extraction silently disabled in prod**.
- **Impact:** Core ingestion value (single-call structured summary) degraded in prod.
- **Remediation:** Move import to module top; remove dead line; unit-test constructing with `ENVIRONMENT=production`.
- **Evidence:** T4-verified.
- **Status:** **RESOLVED (2026-08-13)** — `from src.utils.supabase_client import create_client` moved to module top; prod `if/else` branch rewritten so `_supabase` is constructed when `ENVIRONMENT=production` (and `RuntimeError` only when creds are absent). `tests/test_policy_extraction_service.py` (3 tests) guards prod-construct, prod-missing-creds, and dev-local paths.

### H-06 (HIGH) Rate limiting silently degrades to per-process memory
`src/utils/anti_abuse.py:40-44` — on Redis-down, falls back to a module-global in-memory store. Behind multiple workers (gunicorn/uvicorn multiprocess) rate limits are not enforced across workers.
- **Impact:** Abuse protection defeated silently in multi-worker prod.
- **Remediation:** Fail loud / DB-backed counter; startup health check; 2-worker integration test.
- **Evidence:** T4-verified.
- **Status:** **RESOLVED (2026-08-13)** — `_check_redis_rate_limit` now **fails closed** (`return False` → caller surfaces 429) on Redis error instead of allowing the request; added `rate_limiter_backend()` helper for observability. `tests/test_anti_abuse_rate_limit.py` (3 tests) covers the fail-closed path and the backend-detection helper. NOTE: cross-worker memory fallback remains a known limitation (a Redis/DB-backed counter is the durable fix — tracked as follow-up, not closed by this change).

### H-07 (HIGH) Production pgvector path is never exercised by tests
Dev/QA uses Qdrant/local-SQLite; the canonical prod store (Supabase pgvector) is not covered by the suite.
- **Impact:** The path users actually hit is untested.
- **Remediation:** Add a pgvector (or pgvector-sqlite shim) test fixture; run the real pipeline.
- **Evidence:** T3 (agent-inspected).
- **Status:** **RESOLVED (2026-08-13)** — `tests/fixtures/pgvector_fake_supabase.py` provides an in-memory fake of the Supabase client surface (`rpc("match_document_chunks"|"match_document_chunks_fts")`, `table().upsert/select/delete`), and `tests/test_supabase_pgvector_integration.py` (10 tests) drives the **real** `SupabaseVectorStore` through it: contract guards (1536-dim, `embedding_model`, owner required), owner/tenant isolation, cosine ranking, FTS ranking, and the adjacent-chunk fallback. A true Postgres+pgvector round-trip (cosine via the `pgvector` type + the SQL match fn) still needs a disposable DB and is tracked separately.

### H-08 (HIGH) `/query` RAG latency ~37s
`src/rag/service.py:352` defaults `fast_path=False`; HyDE + RAG-Fusion + serial variant embeddings + serial answer generation dominate latency. README claims "<2s".
- **Impact:** Real usage blocked by latency; credibility gap vs docs.
- **Remediation:** Default `fast_path=True` + parallelize variant embeddings + set prompt-cache `extra_body`.
- **Evidence:** T3.
- **Status:** **RESOLVED (2026-08-13, code-only)** — Flipped `fast_path` default to `True` at all three `query_rag`/`query_rag_stream` entrypoints; batched the serial variant-embedding loops (HyDE/RAG-Fusion) into a single concurrent embed call. OpenAI prompt caching is automatic for `gpt-5-nano` (stable system prefix) — no `extra_body` plumbing needed (sending it returns 400). NOT yet backed by an automated latency test; `tests/bench_fast_path.py` + `tests/evals/fast_path_benchmark_2026-08-13.md` capture manual benchmarks. Effect expected to move the dominant ~37s serial path down substantially; a CI latency probe is a recommended follow-up.

### M-11 (MED) In-memory QA-report store lost on restart
`src/api/report_router.py:43-44` (`_REPORTS_STORE = []`). User reports of AI-generated content (Google Play policy requirement) are not durable.
- **Remediation:** Persist to evidence substrate / a `qa_reports` table.
- **Evidence:** T4-verified.

### M-12 (MED) Cost ledger permanently zero
`src/services/evidence_pipeline.py:537-541` — `cost = 0.0` for both LLM and deterministic extractors → cost dashboard always $0.
- **Remediation:** Plumb `CostTracker` token counts into the record.
- **Evidence:** T4-verified.

### M-13 (MED) Unmounted / retired routers (dead code + false capability)
`src/api/family.py` (zero `@router` decorators), `src/api/policy.py` — not mounted in `main.py`. Also `src/rag/service.py` (~540 lines) is a second, unmounted RAG microservice.
- **Remediation:** Implement + mount, or archive with ADR (motto §0.12). Do not leave half-wired.
- **Evidence:** T4-verified (mount check).

### M-14 (MED) Orphaned `JobType`s / commented-out outbox handler
`src/models/job_outbox.py:30,33,34` (`QA_RESPONSE`, `CLAIM_VERIFICATION`, `RENEWAL_DIFF`); `src/workers/outbox_worker.py:115-116` — `qa_handler` dispatch commented out → `QA_RESPONSE` never consumed.
- **Remediation:** Implement `qa_handler` + register, or remove enum values + enqueue sites.
- **Evidence:** T4-verified.

### M-15 (MED) Deployment-platform doc contradiction + launch_claims tier violation
README says Cloud Run; other docs say App Runner / Render. `docs/launch_claims/` #4–#10 marked active while the registry's own tier rule says Tier 0/1.
- **Remediation:** Single-source deployment target; fix registry tier labels to match reality.
- **Evidence:** T3 (README Cloud Run T4-verified).

### M-16 (MED) Settings/doc model drift
`src/config/settings.py:8` = `gpt-5-nano`; product/docs reference `gpt-4o-mini`.
- **Remediation:** Reconcile and document the actual default.
- **Evidence:** T4-verified.

### L-10 (LOW) Hardcoded fabricated documents in frontend
`src/frontend/app.py:419-445` — `/documents` returns hardcoded demo data; dangerous if shipped.
- **Remediation:** Gate behind explicit demo flag; never in prod builds.

### L-11 (LOW) Dead / deprecated modules cleanup
`src/simple_app.py` ("Hello from Azure!"), `src/utils/firebase_auth.py`, `src/rag/config.py` (deprecated e5-large-v2/Qdrant/Redis), `src/services/dataset_registry.py` + `dataset_execution_service.py` + `model_lineage_service.py` (orphaned governance subsystem, never invoked).
- **Remediation:** Schedule dead-code sweep; archive (do not delete history) with ADR.

---

## Tracking

| Item | Status | Target | Owner |
|------|--------|--------|-------|
| C-01 | open | — | — |
| H-01 | open | — | — |
| H-02 | open | — | — |
| H-03 | open | — | — |
| H-04 | open | — | — |
| M-01 | open | — | — |
| M-02 | open | next major | — |
| M-03 | open | — | — |
| M-04 | open | — | — |
| M-05 | open | — | — |
| M-06 | open | — | — |
| M-07 | open | — | — |
| M-08 | open | — | — |
| M-09 | open | — | — |
| M-10 | open | — | — |
| L-09 | open | — | — |
| C-02 | resolved (2026-08-13) | tests/test_supabase_auth.py | — |
| H-05 | resolved (2026-08-13) | src/services/policy_extraction_service.py + tests/test_policy_extraction_service.py | — |
| H-06 | resolved (2026-08-13, fail-closed only) | src/utils/anti_abuse.py + tests/test_anti_abuse_rate_limit.py | cross-worker backend follow-up |
| H-07 | resolved (2026-08-13, fake-client) | tests/fixtures/pgvector_fake_supabase.py + tests/test_supabase_pgvector_integration.py | real-DB round-trip follow-up |
| H-08 | resolved (2026-08-13, code-only) | src/rag/pipeline.py | CI latency probe follow-up |
| M-11 | open (2026-08-12) | — | — |
| M-12 | open (2026-08-12) | — | — |
| M-13 | open (2026-08-12) | — | — |
| M-14 | open (2026-08-12) | — | — |
| M-15 | open (2026-08-12) | — | — |
| M-16 | open (2026-08-12) | — | — |
| L-10 | open (2026-08-12) | — | — |
| L-11 | open (2026-08-12) | — | — |
