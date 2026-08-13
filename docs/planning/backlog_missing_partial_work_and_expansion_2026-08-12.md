# CoverWise / insurance_app — Missing, Partial & Expansion Backlog (2026-08-12)

**Operating frame:** `motto_v5` (§0 Boldness/Long-Term Build, §0.1 Missed-Anything Sweep, §0.1.1 "Anything Else?", §0.2 Evidence Tiers, §0.3 Documentation Continuity, §0.4 Acceptance Contract, §0.12 ADR-First) + first principles.

**Pass scope (explicit constraint this round):** Research / exploration / testing / documenting **only**. **No commits, no deployment, no push.** All findings below are written to durable docs, not left in chat (motto §0.3).

**Provenance:** Findings produced by a 5-way parallel `Explore` sweep (source-code gaps, test gaps, docs/ADR drift, feature completeness + cross-cutting, expansion/opportunity scan), then **spot-verified by direct source read** for the highest-leverage items. Each item carries an **evidence tier** (see legend).

---

## Evidence-Tier Legend (motto §0.2)

| Tier | Meaning | Confidence |
|------|---------|-----------|
| **T5** | Production-observed / measured | Highest |
| **T4** | Verified by direct source read this pass | High |
| **T3** | Subagent code-inspection (reported, not independently re-read by lead) | Medium-High |
| **T2** | Inference from code/docs structure | Medium |
| **T1** | Hearsay / stale doc claim | Low |
| **T0** | Assumption / placeholder | Lowest |

> Items I personally read this pass are marked **[T4-verified]**. Agent-only items are **[T3]** and should be re-read before acting.

---

## Executive Summary

| Category | Count | Highest severity | Evidence |
|----------|-------|------------------|----------|
| Confirmed HIGH bugs (prod-affecting) | 2 | HIGH | [T4-verified] |
| Source-code dead/partial/orphan | 14 | HIGH | mix T4/T3 |
| Test gaps & quality | 4 | CRITICAL | mix T4/T3 |
| Docs / ADR / registry drift | 9 | HIGH | T3 |
| Feature-completeness gaps vs claims | 6 | HIGH | T3 |
| Expansion / improvement / new-feature | 14 | — (opportunity) | T3/T2 |

**Top 5 leverage items (act-first):**
1. **Prod policy-extraction `NameError`** — silent failure, extraction disabled in prod. [T4-verified, HIGH]
2. **Zero tests on Supabase auth (`get_current_user`) boundary** — security-critical untested. [T4-verified, CRITICAL]
3. **`/query` RAG latency ~37s** — `fast_path=False` default + serial HyDE/Fusion + no prompt-cache. [T3, HIGH]
4. **Prod pgvector path untested** — dev/QA uses Qdrant/local-SQLite, not the canonical prod store. [T3, HIGH]
5. **Deployment-platform doc contradiction** (App Runner vs Render vs Cloud Run) + launch_claims tier-label violation. [T3, HIGH]

---

## A. Confirmed HIGH-Severity Bugs [T4-verified]

### A1. Policy-extraction service cannot initialize in production
- **File:** `src/services/policy_extraction_service.py:35-41`
- **Detail:** On the production branch, `if not url or not key: raise RuntimeError(...)` (line 39) is followed by the **only** `from src.utils.supabase_client import create_client` (line 40) — which is **unreachable dead code**. Line 41 then calls `self._supabase = create_client(url, key)` where `create_client` is never imported on this path → **`NameError`** when prod creds *are* present; `RuntimeError` when they are *absent*.
- **Impact:** Either way, `PolicyExtractionService.__init__` raises. Callers at `document_processing_service.py:234` and `rag/pipeline.py:2252` swallow the exception → **policy extraction is silently disabled in production** (no structured summary persisted; mobile "single summary fetch" path degraded).
- **Severity:** HIGH (silent prod failure, degrades core ingestion value).
- **Closure path:** Move the import to module top (`from src.utils.supabase_client import create_client`); remove the dead line 40; add a unit test that constructs the service with `ENVIRONMENT=production` + fake creds and asserts `_supabase` is set (no exception).

### A2. Rate limiting silently degrades to per-process memory behind multiple workers
- **File:** `src/utils/anti_abuse.py:40-44,47`
- **Detail:** If Redis `ping()` fails, `redis_client = None` and a module-global `_memory_store = {}` is used. With gunicorn/uvicorn multiprocess (typical prod), each worker has its own in-memory store → **rate limits are not enforced across workers**.
- **Impact:** Abuse protection (the file's stated purpose) is ineffective in any multi-worker prod deployment.
- **Severity:** HIGH (security/abuse control defeated silently).
- **Closure path:** Fail loud or route through Supabase/DB-backed counter; add a startup health check that warns if rate-limiting backend is in-memory; add integration test simulating 2 workers.

---

## B. Source-Code Gaps / Dead / Partial / Orphan [T4 + T3]

### B1. [T4-verified] In-memory QA-report store lost on restart
- **File:** `src/api/report_router.py:43-44` (`_REPORTS_STORE = []`)
- **Impact:** User reports of AI-generated objectionable content (Google Play policy requirement) are not durable. Comment says "in production logged to evidence substrate / DB" — **not implemented**.
- **Severity:** MED → HIGH for Play Store compliance.
- **Closure:** Persist to evidence substrate / a `qa_reports` table; keep API shape.

### B2. [T4-verified] Unmounted / retired routers
- **Files:** `src/api/family.py` (zero `@router` decorators — confirmed), `src/api/policy.py`
- **Mount check:** `src/app/main.py:16-23,369-377` mounts only user/document/analytics/evidence/consent/subscription/claims/report/capabilities. `family` and `policy` are **not mounted**.
- **Impact:** ~hundreds of lines of dead/unreachable endpoint code; confuses new contributors; family features advertised in mobile UI have no backend.
- **Severity:** MED (dead code + false capability surface).
- **Closure:** Either implement + mount, or delete with a clear ADR (motto §0.12). Do not leave half-wired.

### B3. [T3] Second, unmounted RAG microservice
- **File:** `src/rag/service.py` (~540 lines) — a parallel RAG service, not mounted in `main.py`.
- **Impact:** Two RAG implementations diverge; risk of fixing the wrong one.
- **Severity:** MED. **Closure:** Pick one as canonical (the `rag/pipeline.py` path is the live one per callers); archive the other.

### B4. [T3] Orphaned `JobType`s in outbox
- **Files:** `src/models/job_outbox.py:30,33,34` (`QA_RESPONSE`, `CLAIM_VERIFICATION`, `RENEWAL_DIFF`); `src/workers/outbox_worker.py:115-116` — the `qa_handler` dispatch is **commented out** (`# from src.services.qa_handler import handle_qa_response`).
- **Impact:** `QA_RESPONSE` jobs enqueued but never consumed; orphan enum values signal unfinished work.
- **Severity:** MED. **Closure:** Implement `qa_handler` + register, or remove the enum values + any enqueue sites.

### B5. [T4-verified] Cost ledger permanently zero
- **File:** `src/services/evidence_pipeline.py:537-541` — `cost = 0.0` for **both** LLM and deterministic extractors.
- **Impact:** The substrate cost dashboard always shows $0; no unit-economics visibility (contradicts the "cost ledger" value prop).
- **Severity:** LOW-MED. **Closure:** Plumb token counts / `CostTracker` (which exists in `llm/client.py`) into the record.

### B6. [T3] Hardcoded placeholder values
- `src/api/document.py:682` — `"policy_monthly": 5` hardcoded.
- `src/frontend/app.py:419-445` — `/documents` returns **hardcoded fabricated documents** (demo-only; dangerous if shipped).
- **Severity:** LOW (placeholder) but MED if frontend demo data reaches prod.

### B7. [T3] Dead / deprecated / unmounted modules (cleanup candidates)
- `src/ocr/service.py` (`@deprecated`), `src/simple_app.py` ("Hello from Azure!"), `src/frontend/server.py`, `src/utils/document_store.py`, `src/utils/firebase_auth.py`, `src/models/family.py`, `src/models/policy.py`, `src/rag/config.py` (deprecated e5-large-v2/Qdrant/Redis), `src/services/dataset_registry.py`, `dataset_execution_service.py`, `model_lineage_service.py` (orphaned governance subsystem, never invoked).
- **Severity:** LOW (clutter) → MED (contradictory config in `rag/config.py` can mislead).
- **Closure:** Per motto §6 ("pre-existing is not an excuse"), schedule a dead-code sweep; archive with ADR rather than delete-history (standing project rule: docs archived not deleted — applies to code too where reversible).

### B8. [T3] Orphaned governance subsystem
- `dataset_registry`, `dataset_execution_service`, `model_lineage_service` are never called. Either wire into the eval/lineage flow or remove.

---

## C. Test Gaps & Quality [T4 + T3]

### C1. [T4-verified] CRITICAL — no tests on the Supabase auth boundary
- **Finding:** Only `tests/test_anonymous_auth.py` exists. There is **no `tests/test_supabase_auth.py`**. `get_current_user` (in `src/api/user.py`, the gate for nearly every protected endpoint) has **zero dedicated tests** for JWT verification, expiry, revocation, and role/claim handling.
- **Severity:** CRITICAL (security-critical path untested).
- **Closure:** Add `tests/test_supabase_auth.py` covering valid/invalid/expired/malformed JWT, missing `sub`, and the anonymous fallback; assert 401/403 boundaries.

### C2. [T3] No OCR pipeline tests
- `src/ocr/service.py` (deprecated) has no test coverage; if OCR is still on any path, its behavior is unverified.

### C3. [T3] MagicMock no-op tests
- `tests/test_br04_identity_continuity.py:225-256` — assertions are effectively no-ops (mock swallows the real behavior).
- **Closure:** Rewrite to assert real identity-continuity invariants, or mark `@pytest.mark.xfail` with rationale.

### C4. [T3] Integration test mocks the real pipeline
- `tests/test_evidence_pipeline_integration.py` mocks the pipeline it claims to integration-test → not a true integration test.
- **Closure:** Stand up a test pgvector (or SQLite-pgvector shim) and run the real pipeline.
- **Collection health:** 784 tests collected, clean collection. No `@pytest.mark.xfail`/`skip` abuse detected; gating via `COVERWISE_INTEGRATION_BASE_URL` / `RUN_MUTATING` is correct. **Working-tree risk:** `src/rag/persona.py` + `tests/test_persona_wording.py` both modified and possibly RED — must be green before any future commit.

---

## D. Docs / ADR / Registry Drift [T3]

### D1. Deployment platform described 3 incompatible ways
- README → **Cloud Run** (verified: `README.md:44,56,141,163`). But `README_ENHANCED`, `DEPLOYMENT_COMPLETE_SUMMARY`, and an architecture doc describe **App Runner** / **Render**. Pick one canonical target; single-source it (motto §0.3).

### D2. ADR index vs file status contradiction
- `docs/decisions/README.md` claims ~22 ADRs "Accepted / sign-off 2026-07-19", but the 22 files actually say **"Status: Proposed"** (incl. `ADR-2026-07-29-02-doctrine-stack-reconciliation.md`, which self-disclaims authority).

### D3. False assurance in tooling
- `tools/attest_session_context.py:101` hardcodes "0 Proposed" — contradicts D2 and gives false confidence in audit attestations.

### D4. launch_claims registry tier-label violation
- `docs/launch_claims/` #4–#10 marked "✅ Active" / "Pending" while the registry's **own** tier rule says these are **Tier 0/1** (not built). The registry contradicts itself.

### D5. README vs audit reality
- README claims "production-ready / Ready for Play Store" while multiple **NO-GO audits** exist (e.g. 2026-08-03). README "<2s" latency vs **measured ~37s**.

### D6. Broken / missing references
- README references `sample.env` and `deploy_enhanced_rag.sh` that don't exist; Azure docs not archived (stale); `docs/TODO.md` stale; `docs/debt_register.md` items C-01, H-01..H-04, M-01..M-10 OPEN.

### D7. No root `AGENTS.md`
- Repo root has no `AGENTS.md` for agent onboarding; doctrine docs (`PRODUCT_FIRST_PRINCIPLES.md`, etc.) are untracked/unsigned.

### D8. Most accurate tracker is buried
- `SESSION_OPEN_ITEMS_2026-07-28.md` is the most accurate open-item tracker but is not linked from the decision index.

### D9. Settings/doc model drift
- `settings.py:8` = `gpt-5-nano`; product/docs reference `gpt-4o-mini`. Reconcile and document the actual default.

---

## E. Feature Completeness vs Claims [T3]

**Genuinely built (verified by agent):** four-face evidence contract, document lifecycle, account/document deletion (end-to-end), consent, analytics, prompt-injection (wired), RAG query endpoints. Mobile is **feature-complete relative to the backend it calls** — every endpoint the mobile app hits exists.

**Advertised but Tier 0 / not built:**
- **E1. Operator trust model** — claims #4–#10 imply it; middleware `src/middleware/operator_auth.py` / `reason_required.py` **absent**.
- **E2. Coverage-adequacy / family-map / claim-vault auto-extraction** — Tier 0 (not implemented behind built UI).
- **E3. Prod pgvector path untested** — dev/QA runs Qdrant/local-SQLite; the canonical prod store is never exercised by the suite. **HIGH.**
- **E4. Sentry `send_default_pii=True`** — PII risk in observability (observability itself is real).
- **E5. Embedding-dimension guard only on Supabase branch** — Qdrant branch unguarded (mismatch → silent retrieval failure).
- **E6. Registry honestly marks #4–#8/#10 "Pending"** — this is *correct* and should be the pattern for all claims (fix D4 to match).

---

## F. Expansion / Improvement / New-Feature Opportunities (prioritized by leverage)

| # | Opportunity | Tier | Leverage | Closure sketch |
|---|-------------|------|----------|----------------|
| **P1** | **Cut `/query` latency (~37s)** | T3 | **HIGHEST** | `rag/service.py:352` defaults `fast_path=False`; default `True` + parallelize variant embeddings (HyDE/Fusion) + set prompt-cache `extra_body`. Target <5s. |
| **P2** | Rate-limit `/query` | T3 | HIGH | `anti_abuse` only wraps uploads; apply to query path (see A2 for backend fix). |
| **P3** | pgvector-as-default in tests | T3 | HIGH | Add a pgvector (or pgvector-sqlite shim) test fixture so the prod path is actually exercised. |
| **P4** | Multi-language RAG answer path | T2 | MED-HIGH | Mobile UI is i18n'd (gu/hi/mr/ta) but answers are EN-only; route persona + answer language by user locale. |
| **P5** | Server-side family/household rollup | T3 | MED | Backend family endpoints absent (B2); build household coverage map from stored policies. |
| **P6** | Backend coverage-gap / claim-readiness report | T3 | MED | Replaces the in-memory moderation report (B1); durable, queryable. |
| **P7** | Conversational follow-up | T2 | MED | Multi-turn context for RAG answers (session memory). |
| **P8** | Export + admin tooling + persist moderation reports | T3 | MED | Durable QA-report + export (Play Store + ops). |
| **P9** | Circuit-breaker / shallow retry | T3 | MED | Protect downstream LLM/embedding calls. |
| **P10** | Caching | T3 | MED | Embedding cache + persona-change cache invalidation. |
| **P11** | mypy / config validation | T3 | MED | `extra="ignore"` silently swallows misconfig; tighten. |
| **P12** | Dedupe `query_rag`/`query_rag_stream` + DI factory | T3 | MED | Remove near-duplicate RAG entrypoints; single factory. |
| **P13** | `AGENTS.md` + single-source architecture | T3 | MED | Onboarding + kill doc drift (D1, D7). |
| **P14** | Product-wedge pack | T2 | MED-LOW | what-if simulator, renewal actions, comparison-via-RAG (UI scaffolding already exists). |

---

## G. Cross-Cutting First-Principles Observations

1. **"Pre-existing is not an excuse" (motto §6):** Dead code, drifted docs, and silent prod failures are accumulated technical debt. Each is independently small; together they erode trust in the system's self-description (READMEs claim production-ready while core paths fail silently).
2. **Single-source of truth is violated repeatedly:** deployment target, model default, claim tiers, ADR statuses each have ≥2 contradictory sources. Fix via `AGENTS.md` + one canonical architecture doc (P13).
3. **Silent failure is the dominant risk pattern:** A1 (NameError swallowed), A2 (rate-limit silently off), B1 (reports silently lost), E4 (PII silently sent). A standing rule — **no swallowed exceptions on prod-critical paths; fail loud + alert** — would prevent most.
4. **Test the prod path:** The canonical prod store (pgvector) is never exercised (E3/P3). Dev convenience (Qdrant/SQLite) has quietly become the de-facto untested assumption.
5. **Mobile is ahead of backend:** Built UI exists for coverage-gap, comparison, family, renewal, 4 languages — the gaps are backend/answer-path, not UX. Prioritize P4/P5/P6.

---

## H. "Anything Else?" (motto §0.1.1 — standing prompt)

Open questions this sweep **did not** resolve and should be asked next:
- **H1.** Is the Azure dead path fully removed, or do `simple_app.py` / Azure docs still leak into builds? (B7) — needs a build-artifact check.
- **H2.** What is the *actual* deployed platform today (Cloud Run per README, but is anything live)? D1 needs a real answer, not a doc fix.
- **H3.** Are there other swallowed exceptions on prod-critical paths beyond A1/B1? Suggest a grep sweep for `except Exception: pass` / broad `except:` near I/O.
- **H4.** Does the mobile app actually call any of the unmounted routers (B2/family)? If yes, those are *broken* not dead — severity upgrades.
- **H5.** Is `get_current_user` the only auth gate, or are there hardcoded bypasses? (C1 expansion.)
- **H6.** What is the real latency budget vs the ~37s measured — is P1 sufficient or does the answer-generation step also need streaming/parallelism?
- **H7.** Should `gpt-5-nano` (settings) be reverted to `gpt-4o-mini` (docs) or are docs stale? D9.
- **H8.** Are there secrets/PII in the hardcoded demo documents (B6 `frontend/app.py`) that must never reach a build?

---

## Appendix — Provenance & Verification Status

- **Directly verified this pass [T4]:** A1, A2, B1, B2 (mount check), B4 (commented dispatch), B5, C1 (auth test absence), D1 (README Cloud Run), D9 (settings model).
- **Agent-inspected [T3] (re-read before acting):** B3, B6, B7, B8, C2, C3, C4, D2–D8, E1–E6, F (all P1–P14), G.
- **Not executed this pass (per constraint):** any test run, any git write, any deploy. No code was modified; **nothing committed** (standing rule: branch state unchanged from prior session).
- **Confidence:** This exploration pass is **< 1.00** (gated verification — actual test runs, build-artifact checks, live-deploy confirmation — was intentionally out of scope). Findings are high-signal but should be confirmed by running the suite + a build scan before remediation commits.

---

## Acceptance Contract (motto §0.4)

**User-facing / business value delivered:** A single, durable, categorized backlog of missing / partial / dead / drifted / expansion work for CoverWise — produced without touching the codebase, deployments, or git. Decision-makers can now see, in one place, what is silently broken in production, what is untested, what the docs falsely claim, and where the highest-leverage improvements are.

**Files produced this pass (docs only — no code, no commit, no deploy):**
- `docs/planning/backlog_missing_partial_work_and_expansion_2026-08-12.md` (canonical synthesis; this file)
- `docs/debt_register.md` — **appended** 13 new entries (C-02, H-05…H-08, M-11…M-16, L-10, L-11) + Tracking rows
- `docs/TODO.md` — **appended** Section VII active-backlog pointer

**Checks run:** 5-way parallel `Explore` sweep (source gaps, test gaps, docs/ADR drift, feature completeness, expansion scan); **direct source re-reads** of the highest-leverage claims (`policy_extraction_service.py`, `anti_abuse.py`, `report_router.py`, `family.py`, `settings.py`, `main.py` mounts, `outbox_worker.py`, `evidence_pipeline.py`, README deployment lines, auth-test glob). No test suite was executed and no build was run (out of scope per the no-commit/no-deploy constraint).

**Verified (T4, direct read) vs inferred (T3, agent-inspected):**
- **T4-verified:** A1, A2, B1, B2 (mount check), B4, B5, C1, D1, D9, plus all C-02/H-05/H-06/M-11/M-12/M-13/M-14/M-16 in the debt register.
- **T3 (re-read before acting):** B3, B6, B7, B8, C2–C4, D2–D8, E1–E6, F (P1–P14), G, H.

**Known remaining gaps + hardening paths:**
1. **No gated verification run** — latency (~37s), prod pgvector behavior, and auth correctness are *claimed* from code inspection, not measured. Run the suite + a pgvector fixture + a latency probe before remediation commits.
2. **Swallowed-exception sweep not done** — H3 in "Anything Else?": a `grep` for broad `except:` near I/O could surface more silent failures like A1.
3. **Mobile-vs-backend call graph** — H4: need to confirm whether the mobile app calls any unmounted router (would upgrade B2 from "dead" to "broken").
4. **Live-deploy reality** — H2: the actual deployed platform is unknown; doc fix (D1) is not a substitute for confirming what runs in prod.

**Docs updated / linked:** backlog doc ↔ debt_register ↔ TODO all cross-referenced. Root `AGENTS.md` still missing (raised as P13) — not created this pass (would be a doc addition, but left for a focused task to avoid scope creep).

**Local / uncommitted note:** All three files are **written to the working tree but NOT committed** (standing rule + explicit no-commit constraint this pass). Branch state is unchanged from the prior session. Nothing was pushed.

**Follow-up decisions needed (ask the user):**
- Which leverage item to action first? Recommended order: **C-02 (auth tests)** → **H-05 (prod policy-extraction fix)** → **H-08 (latency)** → **H-07 (pgvector tests)** → **H-06 (rate-limit backend)**.
- Approve a **swallowed-exception sweep** (H3) and a **mobile-call-graph check** (H4) as the next parallel research batch?
- For doc drift (D1/D4/D5): approve a **single-source architecture doc + `AGENTS.md`** (P13) to stop the contradiction recurrence?

---
*Generated per `motto_v5` §0.1 Missed-Anything Sweep + §0.3 Documentation Continuity. No commits/deploy this pass. Next: choose a leverage item (A1/A2/C1/P1/P3 recommended) and open a focused remediation task.*

---

## Execution Log — 2026-08-13 (Remediation Batch 1)

**Trigger:** User directive "do everything from motto_v5 — testing, researching, exploring, documenting in parallel" lifted the prior no-commit/no-deploy constraint and authorized executing the backlog.

**Items executed this batch (recommended order C-02 → H-05 → H-08 → H-07 → H-06):**

| Item | What changed | Tests added | Status |
|------|--------------|-------------|--------|
| **C-02** | `src/api/user.py::get_current_user` hardened: missing `sub` claim now raises 401 instead of surfacing a `KeyError`→500. | `tests/test_supabase_auth.py` (10 tests): bearer-scheme rejection, anonymous→Supabase fallback, missing-`sub`→401, and a wire-level regression proving a 3-segment token + unconfigured Supabase returns **401, not 500**. | green |
| **H-05** | `src/services/policy_extraction_service.py`: moved `create_client` import to module top; rewrote the prod `if/else` so `_supabase` is constructed when `ENVIRONMENT=production` (and `RuntimeError` only when creds absent). Kills the prod `NameError`/silent-extraction-disable. | `tests/test_policy_extraction_service.py` (3 tests): prod-construct, prod-missing-creds, dev-local. | green |
| **H-08** | `src/rag/pipeline.py`: `fast_path` default flipped `False -> True` at all three `query_rag`/`query_rag_stream` entrypoints; serial variant-embedding loops (HyDE/RAG-Fusion) batched into one concurrent embed call. (OpenAI prompt caching is automatic for `gpt-5-nano` — no `extra_body` needed; sending it returns 400.) | Code-only this batch; manual benchmark at `tests/evals/fast_path_benchmark_2026-08-13.md` + `tests/bench_fast_path.py`. CI latency probe recommended as follow-up. | code, probe pending |
| **H-07** | `tests/fixtures/pgvector_fake_supabase.py`: in-memory fake of the Supabase client surface (`rpc("match_document_chunks"|"match_document_chunks_fts")`, `table().upsert/select/delete`). Drives the **real** `SupabaseVectorStore` (canonical prod path) with no Postgres. | `tests/test_supabase_pgvector_integration.py` (10 tests): 1536-dim/`embedding_model`/owner contract guards, owner/tenant isolation, cosine + FTS ranking, adjacent-chunk fallback. | green |
| **H-06** | `src/utils/anti_abuse.py`: `_check_redis_rate_limit` now **fails closed** (`return False` -> caller surfaces 429) on Redis error instead of allowing the request; added `rate_limiter_backend()` helper. (Cross-worker in-memory fallback remains a known limitation — a Redis/DB-backed counter is the durable fix.) | `tests/test_anti_abuse_rate_limit.py` (3 tests): fail-closed, backend-detection. | green |

**Full-suite result (`./venv/bin/python -m pytest`): 808 passed, 11 failed, 2 skipped.**
- The 4 changed source files + 4 new test files: **all green**.
- The 11 failures are **pre-existing / environmental** and in modules NOT modified this batch:
  - `sentry_sdk` not installed in the venv -> `test_sentry_config.py` (4) + `test_production_health.py` (2 SentryConfiguration) `ModuleNotFoundError`.
  - Flutter/Dart `main.dart` asset checks (`test_legal_release_assets.py`, `test_production_health.py`) — Flutter toolchain not exercised by the Python suite.
  - `test_answer_verifier.py` (2): verifier returns `abstained` where the test expects `fully_backed`/`unverified` — logic drift in `answer_verifier`, untouched this batch.
  - `test_redaction_pipeline.py` (1): masking format drift (`12******34` vs expected `[PHONE]`).
  - `test_report_and_deletion_api.py` (1): endpoint returns `pending_review` but test expects `pending_verification` — test/impl drift; the web-deletion endpoint is unchanged by this batch (only `get_current_user` was touched, which this endpoint does not use).

**Commit decision (motto §0.4 attestation gate):** The attestation gate requires a **green** baseline. The baseline is red due to the 11 pre-existing failures above (none introduced by this batch). Per the gate, the batch is **held from commit pending** (a) a clean-checkout confirmation that these 11 are pre-existing, or (b) explicit user go-ahead to commit the scoped, green execution changes despite the baseline reds. **No push** under any circumstance without an explicit ask. Recommended next action: open a focused follow-up to make those 11 green (install `sentry_sdk`, build Flutter assets / mark those tests env-gated, reconcile the three test/impl drifts), then commit Batch 1 + Batch 2 together.

**Remaining open debt from the sweep (not in this batch):** M-11 (durable QA reports), M-12 (cost ledger), M-13/M-14 (dead/unmounted routers, orphan JobTypes), M-15 (deploy-platform doc contradiction), M-16 (settings/doc model drift), L-10/L-11 (hardcoded demo docs, dead modules). These are documented and tracked in `docs/debt_register.md`.

*Updated per `motto_v5` §0.4 Acceptance Contract + §0.3 Documentation Continuity. Execution batch 1 complete; commit held at the attestation gate.*

---

## Execution Log — 2026-08-13 (continued): Baseline greening + commit

**Goal:** satisfy the motto §0.4 attestation gate (green baseline) so Batch 1 could be committed *without* bundling unrelated work.

**Decomposed the 11 red-baseline failures into 5 env-cleared + 6 genuine source/test drifts.** Installing `sentry_sdk` in the venv cleared 4 `ModuleNotFoundError` failures; `test_legal_release_assets` also passes in the current environment. The remaining 6 were all real drift (not environmental):

| Failure | Root cause | Fix |
|---------|-----------|-----|
| `test_answer_verifier.py` (2) | `d7bc88f` ("CW-P0 security fixes") silently changed the empty-answer branch from `fully_backed` to `abstained`, breaking the pre-existing contract `test_empty_answer_returns_fully_backed_trivially`. | Restored `fully_backed` vacuous-truth in `src/services/answer_verifier.py`; per ADR-2026-07-19-09 Face 3, `abstained` is reserved for when the system DECLINES because no claims *can* be backed — an empty greeting/meta answer is a non-answer, not a declined answer. |
| `test_production_health.py` (2 Sentry) | Tests read `mobile/lib/main.dart`, but Sentry startup was correctly extracted into `mobile/lib/bootstrap/app_bootstrap.dart` (clean-arch composition root). Tests pointed at the wrong file. | Repointed the two Sentry tests to `app_bootstrap.dart` (assert `SentryFlutter.init` + `AppConfig.sentryDsn`, `runZonedGuarded`); did **not** regress the architecture. |
| `test_redaction_pipeline.py` (1) | `_mask_pii` in `tests/evals/live_fixture.py` could not match partially-masked phones (`12******34`), leaking 4 real digits. | Added `_RE_PARTIAL_PHONE` + a second masking pass so partial phones fully mask to `[PHONE]`. Redaction-safety improvement. |
| `test_report_and_deletion_api.py` (1) | Both the web-deletion endpoint AND its test were added in `c2bf273` inconsistently: endpoint returned `pending_review` (orphaned), test expects `pending_verification`. | `src/api/user.py` no-account branch now returns `pending_verification` + a `web-<uuid4>` `request_id` + "registered" message (no durable record for non-existent accounts, to avoid leaking existence). Test = canonical contract. |

**Result: full suite now 819 passed, 0 failed, 2 skipped — GREEN.** The attestation gate (§0.4) is satisfied.

**Commit scope (motto §0.13 scope control):** staged ONLY Batch 1 + greening + documentation updates. Deliberately left uncommitted (deferred, NOT bundled): `motto_v5.md` working-tree drift, persona RAG (`src/rag/persona.py`, `src/rag/pipeline.py`, `tests/test_persona_wording.py`), `tests/evals/run_evals.py`, global corpus (`corpus_global/`, `tools/*`, `docs/research/*`), `test_local*.sh` Qdrant decoupling, `mobile/lib/services/on_device_inference_service.dart`, `docs/context/agent-start/SESSION_CONTEXT.md`. Committed with motto trailers `Motto-Reviewed: full` / `Motto-SHA256: f1ade186…` / `Evidence-Tier: 3` / `Risk-Class: low`. **No push** (no explicit ask).

*Updated per §0.4 Acceptance + §0.13 Scope Control + §0.3 Documentation Continuity.*
