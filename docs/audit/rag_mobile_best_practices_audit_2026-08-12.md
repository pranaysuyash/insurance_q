# CoverWise RAG + Mobile Best-Practices Audit

**Date:** 2026-08-12
**Auditor:** Forge (engineering partner)
**Scope:** Backend RAG service (`src/`, `rag-service-config-mumbai-v6-public-redis.json`, `Dockerfile`, deploy scripts) + Flutter mobile client (`mobile/`), audited against `motto_v5.md` (canonical doctrine) and 2026 RAG/Flutter production best practices.
**Evidence basis:** Static inspection of live code + deploy config (Tier 1), cross-checked against `motto_v5` clauses. Runtime/production behavior (Tier 3+) was **not** executed in this session — flagged where it changes confidence.

---

## 1. Executive Summary

The engineering is **above average for its stage** in two specific dimensions: retrieval grounding/citation verification (backend) and encrypted-at-rest + fail-closed consent (mobile). However, the audit found **multiple production-blocking defects** and, more importantly, a **doctrine-level failure**: the deployed system does not match the documented "current launch path," and the live config ships in an effectively *development* mode.

| # | Finding | Severity | Area | Evidence |
|---|---------|----------|------|----------|
| 1 | `ENVIRONMENT` unset → live image runs in **development mode**: open CORS (wildcard + credentials), debug/ingest endpoints exposed, ephemeral local storage | 🔴 Critical | Backend / Config | `runtime_config.py:56`, `runtime_access.py:16`, `main.py:74`, `pipeline.py:125` |
| 2 | **Public, unauthenticated Redis** caching full private policy answers (cache poisoning + PII exposure) | 🔴 Critical | Backend / Security | `rag-service-config-…json:17,19`, `pipeline.py:222,232,302` |
| 3 | **Cross-region data flow**: Qdrant in GCP `us-east4` ↔ service in AWS `ap-south-1` (latency + data-residency) | 🔴 Critical | Backend / Data | `rag-service-config-…json:14,5` |
| 4 | **Reranking is silently disabled in production** (no `sentence_transformers` in prod lock → lexical fallback) | 🟡 Moderate | Backend / RAG | `pipeline.py:185-193,2095-2108`, prod lock grep=0 |
| 5 | **No CI-gated faithfulness / retrieval-quality test** on a live corpus (RAGAS is dev-only, ImportError-guarded) | 🟡 Moderate | Backend / Eval | `src/eval/ragas_eval.py:158-159`, prod lock grep=0 |
| 6 | **Embedding-model ambiguity** across configs/scripts (mpnet orphan var; `ada-002` vs `3-small`); Qdrant path has no dimension guard | 🟡 Moderate | Backend / Data | `settings.py:7` vs `rag-service-config-…json:21-22` vs `deploy_aws_multiarch.sh:239` |
| 7 | No explicit Qdrant `score_threshold`; quality gating is a heuristic on RRF/lexical scores | 🟡 Moderate | Backend / RAG | `pipeline.py:1723-1729` |
| 8 | No certificate pinning on mobile (token + PII transit over TLS only) | 🟡 Moderate | Mobile / Security | grep: no `SecurityContext`/`badCertificate` |
| 9 | On-device model SHA-256 declared in manifest but **not verified at download** (supply-chain risk) | 🟡 Moderate | Mobile / Security | `on_device_inference_service.dart:62-67` vs `app_config.dart:88-99` |
| 10 | Verification badge rendered **only if** `verificationStatus != null` → backend answer omitting it shows **no badge** | 🟡 Moderate | Mobile / Trust | `qa_screen.dart:1755` |
| 11 | Behavioral tests missing for `QueryService` retry/error, `AuthInterceptor` 401 refresh, verification-missing case | 🟡 Moderate | Mobile / Test | `test/` inventory |
| 12 | **Doctrine fork**: README "current launch path" (Cloud Run + Supabase + pgvector) contradicts live deploy (AWS + Qdrant + public Redis); README itself calls AWS section "historical" | 🔴 Critical | Doctrine / Docs | `README.md:39-69` vs `rag-service-config-…json` |
| 13 | **No launch-claim registry** gating public claims ("production-ready", "Vector Search: Qdrant", "100% operational") | 🟡 Moderate | Doctrine / §0.11.1 | `docs/launch_claims/` absent |

**Strengths (verified, keep):** grounding prompt + "say I don't know" (`pipeline.py:1320-1324`); citation verifier rejecting ungrounded quotes (`citation_verifier.py:65`); answer-face verifier (`answer_verifier.py:139`); hybrid dense+lexical RRF (`pipeline.py:2034`); prompt-injection guard; non-root container; secrets build-injected (mobile, no hardcoded keys); AES-256-GCM at rest with hardware-backed DEK; HTTPS-enforced base URL; version-pinned fail-closed consent; graceful error/offline states.

---

## 2. Scope, Method & Evidence Tiers

Per `motto_v5 §0.5`, claims are tiered:
- **Tier 1 (static inspection):** all 🔴/🟡 findings above are backed by file:line citations read directly this session.
- **Tier 3+ (runtime):** NOT performed — no live deploy was exercised. The single runtime-dependent risk (corpus embedding model vs serving model) is flagged as unverified, not asserted.

Per `motto_v5 §0.2` (confidence honesty), this audit does **not** claim the system is "production-ready." The README's "Ready for Play Store Deployment!" / "production-ready" language is **not** supported by the evidence gathered here.

---

## 3. Doctrine Compliance (`motto_v5.md`) — the central question

You asked whether the agents followed your first-principles motto. **Partially, and with one serious miss.** Mapping to specific clauses:

### 3.1 §0.1 Missed-Anything Sweep / "no parallel truth sources" — **VIOLATED**
The canonical-path re-check was not done. Two incompatible "source of truth" stories coexist:
- `README.md:39-69` declares the **current** launch path is **Cloud Run + Supabase Postgres + pgvector + private Storage**, and explicitly warns the AWS/Qdrant/Redis section is a "preserved June 2025 historical snapshot… Do not follow it for the July 2026 launch."
- The **live deploy config** `rag-service-config-mumbai-v6-public-redis.json` is exactly that "historical" AWS App Runner + Qdrant + Redis shape — and because `ENVIRONMENT` is unset, the code (`pipeline.py:125`, `document_object_store.py:222`, `document_repository.py:456`) defaults to **Qdrant + local SQLite + local object store**, i.e. the AWS path, not the documented Cloud Run/Supabase path.

This is precisely the "duplicate routes / parallel truth sources / shadow pipelines" the sweep forbids. The live system and the documented system are not the same system.

### 3.2 §1.1 Source-of-Truth / Snapshot Rule — **VIOLATED**
Docs and runtime conflict; the conflict was not resolved or dated. The README acknowledges staleness yet the deploy artifact still ships the stale shape.

### 3.3 §0.8 Data Layer & Config Rule — **PARTIALLY VIOLATED**
- Orphan/dead config: `EMBEDDING_MODEL=sentence-transformers/all-mpnet-base-v2` (`rag-service-config-…json:21`) is not a `Settings` field (`settings.py` has no such attribute; `extra="ignore"`) → silently ignored. Misleading config is a data-layer defect.
- Embedding-model drift across deploy scripts (`deploy_enhanced_rag.sh:127` = `ada-002`; `deploy_aws_multiarch.sh:239,301` = `3-small`). If the populated Qdrant collection `insurance_documents_v2` was built with one model and served with another, retrieval silently breaks; the Qdrant path has **no dimension guard** (only the Supabase path hard-codes 1536 — `pipeline.py:538`).
- `REDIS_PASSWORD=""` shipped as if it were a benign default, not a production security defect.

### 3.4 §0.9 Prompt / Model / Routing Rule — **PARTIALLY VIOLATED**
- Reranker: code supports cross-encoder reranking, but it is **absent in production** (no `sentence_transformers` in prod lock). This is a silent model/routing behavior change that is undocumented as a production characteristic. Every model-backed feature must document its routing/fallback chain; the "reranking" claim would need that caveat.
- Chat model: deploy uses `gpt-3.5-turbo` (`rag-service-config-…json:23`) while repo default is `gpt-5-nano` (`settings.py:8`). The production model selection lacks a recorded rationale/ADR.

### 3.5 §0.10 Observability Is Delivery — **PARTIALLY MET**
Structured logs/metrics/Prometheus exist (good). But there is **no operator-visible faithfulness/retrieval-quality signal**, and no alerting on the Redis exposure or cache-poisoning attempt. For a high-risk insurance-answer path, the operator cannot answer "what happened / was fallback used / was the answer grounded?" from available telemetry.

### 3.6 §0.11 Customer-Facing Claims + §0.11.1 Launch-Claim Registry — **NOT MET**
`README.md` ships claims ("Vector Search: Qdrant cloud", "Caching: Redis cloud", "100% operational", "production-ready") with **no `docs/launch_claims/` registry entry** tying each claim to a gating test. The registry is the mechanical enforcement of §0.11; its absence means claims are adjectives, not contracts.

### 3.7 §0.12 ADR-First / Decision Records — **GAP**
A load-bearing architecture pivot (Cloud Run+Supabase vs AWS+Qdrant) was either not recorded as an ADR or recorded but not followed. The live deploy contradicts the README's "current" path, implying an undecided or unenforced decision.

### 3.8 §0.4 Acceptance Contract / §0.5 Evidence Tiers — **NOT MET for release claims**
"Done" / "production-ready" language appears without the acceptance contract (verified scope, evidence tier, known gaps). No Tier 3+ evidence exists for retrieval quality on a real policy corpus.

**Net doctrine verdict:** Strong *engineering craft* in grounding/security primitives, but the agents **did not perform the canonical-path sweep, did not reconcile docs with the live deploy, and shipped unqualified "production-ready" claims** — three explicit `motto_v5` obligations.

---

## 4. Backend RAG Findings (detail)

### 4.1 🔴 Critical — Live image runs in development mode (Finding #1)
- `ENVIRONMENT` is absent from `rag-service-config-mumbai-v6-public-redis.json`.
- Every gate reads `os.getenv("ENVIRONMENT","development")` → defaults to dev.
- Consequences, all verified:
  - CORS = `["*"]` + `allow_credentials=True` (`runtime_config.py:56`, `main.py:74`) — the code's own comment (`main.py:63-64`) calls this a "browser-rejected combination and a security anti-pattern in production."
  - Debug/ingest endpoints exposed: `/process-and-ingest`, `/debug/services`, `/debug/test-processing`, `/rag/stats`, `/processing/status` (`main.py:768,820,837,851,861`) — `require_nonproduction` only 404s when `ENVIRONMENT==production` (`runtime_access.py:16`).
  - Durable stores downgrade to **local SQLite + local object store** (`document_object_store.py:222`, `document_repository.py:456`, `billing_ledger_service.py:19`) — uploaded policy docs and metadata are **ephemeral** (lost on container restart) in the "production" deploy.
- **Fix:** Set `ENVIRONMENT=production` in the deploy config; supply `ALLOWED_ORIGINS`, `ALLOWED_HOSTS`, `RAG_VECTOR_BACKEND=supabase`, `DOCUMENT_OBJECT_STORE_BACKEND=supabase`, `DOCUMENT_REPOSITORY_BACKEND=supabase`. Re-run the acceptance contract. (Commit-unit: 1 config + 1 smoke test.)

### 4.2 🔴 Critical — Public unauthenticated Redis (Finding #2)
- `REDIS_HOST=insurance-app-redis-mumbai-public.y6jsma.0001.aps1.cache.amazonaws.com` (name literally contains "public"), `REDIS_PASSWORD=""`.
- Code skips password when empty (`pipeline.py:222`) and caches the **full query response** — answer + sources + citations — for private policy questions (`pipeline.py:302`). The code comment at `:232` acknowledges these are private policy answers.
- Risk: internet-reachable, unauthenticated store of PII/PHI; **cache poisoning** (an attacker who reaches it can write a forged answer that the service will return as "evidence-backed").
- **Fix:** Move Redis inside the VPC (private subnet, security-group scoped), set a strong `REDIS_PASSWORD` (or use IAM/auth token), and scope cache keys per-tenant (owner-scoped caching already exists in code — `:234` — but is moot if the store is public). (Commit-unit: 1 infra + 1 config + 1 test.)

### 4.3 🔴 Critical — Cross-region Qdrant (Finding #3)
- Qdrant is GCP `us-east4` (`rag-service-config-…json:14`); service runs AWS `ap-south-1`. Every query pays cross-continent round-trips, and Indian users' policy documents sit in a US region — a data-residency concern for insurance PII.
- **Fix:** Co-locate the vector DB with the service region (AWS `ap-south-1` / Mumbai), or move the whole stack to one region. Document the residency decision in an ADR. (Commit-unit: 1 infra + 1 ADR.)

### 4.4 🟡 Moderate — Reranking disabled in prod (Finding #4)
- `_init_reranker` sets `self.reranker=None` then tries `from sentence_transformers import CrossEncoder`; on `ImportError` (not in prod lock) it logs and leaves reranking off. `_rank_results` then falls back to lexical+exact scoring (`pipeline.py:2095-2108`).
- The default 2026 pipeline is dense retrieval → **rerank top-20→5** → LLM (CallMissed 2026). CoverWise does RRF fusion but **no cross-encoder rerank** in production.
- **Fix (options):** (a) add `sentence-transformers` to the prod image (heavier image, CPU cost), or (b) use a managed reranker (Cohere/Voyage/BGE-reranker-v2) at request time. Either way, document the chosen reranker as a model-backed feature per §0.9. (Commit-unit: 1 dependency/pin + 1 config + eval.)

### 4.5 🟡 Moderate — No CI-gated faithfulness/retrieval-quality test (Finding #5)
- Offline eval exists (`ragas_eval.py`: faithfulness, context_precision, answer_relevancy; golden set `docs/eval/corpus/policy_qa_v1.json`, 52 Qs / 9 categories) but is **ImportError-guarded and absent from the prod lock** → dev-only.
- Tests cover verifier *units* and an E2E that checks citations exist — but **no threshold asserts answer faithfulness/retrieval quality on real queries**.
- Best practice (CallMissed 2026): run eval on every config change; recall@k / MRR on a ~100-query golden set; LLM-as-judge for answer quality; penalize hallucinated citations.
- **Fix:** Wire `ragas_eval` (or a lighter faithfulness check) into CI as a gate on the `policy_qa_v1` set with a minimum faithfulness threshold; store results as a benchmark JSON (§0.10 observability). (Commit-unit: 1 CI job + threshold + report artifact.)

### 4.6 🟡 Moderate — Embedding-model ambiguity (Finding #6)
- `ada-002` (deploy) vs `text-embedding-3-small` (other scripts / repo default) vs orphan `mpnet` var. Qdrant has no dimension guard.
- **Fix:** Pick one embedding model, record it in an ADR, pin it in `Settings`, add a Qdrant collection-dimension guard that fails closed on mismatch, and re-ingest the corpus with the chosen model. (Commit-unit: 1 ADR + 1 guard + 1 reingest run.)

### 4.7 🟡 Moderate — No Qdrant score threshold (Finding #7)
- `_search_qdrant` passes no `score_threshold`; quality gating is a heuristic (`top_score<0.01` → honest "not found", `pipeline.py:1286,1294`).
- **Fix:** Add an explicit `score_threshold` (tuned against the golden set) and log when the gate trips.

### 4.8 ✅ Strengths to preserve
- Grounding prompt + explicit "say I don't know" (`pipeline.py:1320-1324`).
- Citation verifier (`citation_verifier.py:65`): rejects quotes not in `source_text`, rejects `retrieval_text` quotes, checks doc/page bounds.
- Answer-face verifier (`answer_verifier.py:139`): `fully_backed`/`partially_backed`/`abstained`.
- Hybrid dense + lexical with RRF (`pipeline.py:2034`); prompt-injection fencing; non-root container; structured logging/metrics; retrieval-quality "not found" gate.

---

## 5. Mobile / Flutter Findings

### 5.1 ✅ Strengths (verified)
- **No hardcoded secrets** — all via `String.fromEnvironment` (`app_config.dart`); OpenAI key stays server-side.
- **Encrypted at rest**: AES-256-GCM with hardware-backed DEK in Keychain/Keystore (`principal_key_service.dart`, `encrypted_attachment_store.dart`); fails closed on encryption error.
- **HTTPS enforced** in prod (`baseUri` throws on non-HTTPS; no `usesCleartextTraffic`; ATS default).
- **Consent version-pinned + fail-closed** (`consent_ledger.dart`, `documents_screen.dart:616-655`) — no bytes leave without current-version grant.
- **Explicit verification states** (4-state badge) and **offline = "Not verified"** labeling (`answer_verification_badge.dart`, `qa_screen.dart:699-708,991-995`).
- **Graceful error/offline states** (`app_error.dart`, `global_error_boundary.dart`, `offline_banner.dart`).
- State management = **Riverpod 3.0** (Foresight 2026: the recommended 2026 default for most production Flutter apps).

### 5.2 🟡 Moderate — No certificate pinning (Finding #8)
- Token + policy PII transit over TLS without SPKI/cert pinning → MITM exposure on hostile networks.
- **Fix:** Add cert pinning for `api.coverwise.app` (and Supabase) via `SecurityContext` / `badCertificate` guard. (Commit-unit: 1 pinning module + test.)

### 5.3 🟡 Moderate — On-device model hash not enforced (Finding #9)
- `AppConfig.onDeviceModelManifest` declares `sha256`/`size` (`app_config.dart:88-99,243-267`), but `OnDeviceInferenceService.installModel` calls `fromNetwork(url)` **without verifying the downloaded hash** (`on_device_inference_service.dart:62-67`). Integrity contract declared, not enforced → supply-chain risk for the offline lane.
- **Fix:** Verify SHA-256 post-download; refuse install on mismatch. (Commit-unit: 1 verify + test.)

### 5.4 🟡 Moderate — Conditional verification badge (Finding #10)
- Badge renders `if (answer.verificationStatus != null)` (`qa_screen.dart:1755`). A backend answer omitting the field shows **no badge**, technically violating DESIGN.md's "every generated answer carries an explicit verification state."
- **Fix:** Default a missing value to `unverified` and always render the badge. (Commit-unit: 1 guard + test.)

### 5.5 🟡 Moderate — Behavioral test gaps (Finding #11)
- `QueryService` retry/error mapping, `AuthInterceptor` 401 single-flight refresh, and the verification-missing case are **not behaviorally tested** (only a static source-text grep exists for the contract).
- **Fix:** Add unit tests for transient-retry, 500/`missing_result_field`, `_buildUnavailableAnswer`, and the 401 refresh path. (Commit-unit: 3-4 test files.)

### 5.6 ⚪ Minor
- DESIGN.md assigns mint `#5EEAD4` as the offline/local signal, but `unverified` uses `colorScheme.tertiary` — confirm the "Not verified" state reads as the intended offline/local signal so users don't conflate it with evidence-backed.
- `mobile/README.md` and root `README.md` mobile section are effectively empty (0 bytes) — consent/security design exists in code but not in repo docs (§0.3).

---

## 6. Best-Practices Benchmark (2026 sources)

Grounded in: **CallMissed "RAG Best Practices 2026"** (chunking 512–1024 tokens, 10–15% overlap, hybrid dense+BM25+RRF, rerank top-20→5, eval on every config change, citation faithfulness) and **Foresight Mobile "Best Flutter State Management 2026"** (Riverpod 3.0 default; isolate logic for fast unit tests; offline persistence).

| Best practice | CoverWise status |
|---|---|
| Hybrid dense + lexical + RRF | ✅ Present |
| Cross-encoder rerank (top-20→5) | 🟡 Code present, **off in prod** |
| Structure/semantic chunking w/ overlap + metadata | 🟡 OCR-block + sentence split, no tuned size/overlap param, 2000-char truncation |
| Explicit Qdrant score threshold | 🟡 Heuristic only |
| Faithfulness/retrieval eval in CI | 🟡 Dev-only, not gated |
| "Answer only from context / abstain" | ✅ Present |
| Citation grounding verification | ✅ Present (strong) |
| Secrets build-injected (mobile) | ✅ Present |
| Encrypt PII at rest (mobile) | ✅ Present (strong) |
| HTTPS enforced (mobile) | ✅ Present |
| Cert pinning (mobile) | 🟡 Absent |
| On-device model integrity | 🟡 Hash declared, unverified |
| Riverpod 3.0 + testable logic | ✅ Present |
| Behavioral API/auth tests | 🟡 Partial |
| Single canonical deployment truth | 🔴 Forked (docs vs live) |
| Launch-claim registry | 🔴 Absent |

---

## 7. Prioritized Remediation (commit-units, not time)

**P0 — must fix before any customer-facing deploy**
1. Set `ENVIRONMENT=production` + supply `ALLOWED_ORIGINS/HOSTS`, Supabase backends in deploy config; re-run acceptance. (1 config + 1 smoke test)
2. Lock down Redis: private subnet + password/auth; per-tenant key scope already coded. (1 infra + 1 config + 1 test)
3. Co-locate Qdrant with service region; record residency ADR. (1 infra + 1 ADR)
4. Resolve the docs-vs-live fork: pick one canonical deployment (Cloud Run+Supabase *or* AWS+Qdrant), delete the other from the working tree, and write the reconciliation ADR. (1 ADR + doc edits)

**P1 — quality/trust hardening**
5. Enable reranking in prod (managed reranker recommended) + document per §0.9. (1 dep/pin + config + eval)
6. Wire faithfulness/retrieval-quality eval into CI with a threshold + benchmark JSON. (1 CI job)
7. Pin one embedding model + Qdrant dimension guard + re-ingest. (1 ADR + guard + reingest)
8. Add explicit Qdrant `score_threshold` tuned on golden set. (1 param + log)

**P2 — mobile hardening**
9. Cert pinning. (1 module + test)
10. Enforce on-device model SHA-256. (1 verify + test)
11. Default missing `verificationStatus` → `unverified`; always render badge. (1 guard + test)
12. Behavioral tests for `QueryService` retry/error + `AuthInterceptor` refresh. (3-4 test files)
13. Create `docs/launch_claims/` registry; map every public claim to a gating test (§0.11.1).

---

## 8. "Anything else?" (per `motto_v5 §0.1.1`)

- **The reingest script still points at the old AWS URL** (`reingest_documents.py:12` → `https://nrmmvtpyaf.ap-south-1.awsapprunner.com`). If that endpoint is the dev-mode image, re-ingestion may populate Qdrant with the wrong embedding model or fail silently — directly couples to Finding #6.
- **`gpt-3.5-turbo` in prod** is well below current capability and increases hallucination risk on insurance specifics; combined with no prod reranker and no faithfulness gate, the high-risk insurance-answer path has the least protection exactly where it needs the most.
- **No `docs/launch_claims/`** means the "production-ready" claim in the README is currently unenforceable — fixing #13 is what makes §0.11 mechanical rather than aspirational.
- **Mobile README is empty** — the strong consent/security design is invisible to the next agent; per §0.3 it should be documented.

---

## 9. Confidence & Acceptance

- **Verified (Tier 1, file:line):** all 🔴/🟡 findings in §1, §3, §4, §5.
- **Inferred but not runtime-verified:** the *actual* embedding model of the live `insurance_documents_v2` corpus (cannot be read from code) — if it differs from the serving model, retrieval is broken (Finding #6 risk).
- **Not performed this session:** live deploy execution, load test, real-corpus faithfulness run, penetration test of the public Redis.
- **Confidence on "production-ready" claim:** **Not supported.** The system as deployed violates `motto_v5 §0.1, §1.1, §0.4, §0.11.1` and carries three 🔴 security/data defects.
- **Confidence on engineering-craft quality (grounding, mobile crypto, consent):** High — these are genuinely well-built and should be preserved.

**This audit is a documentation deliverable (per `motto_v5 §0.3`); it changes no code.** Remediation requires explicit approval per §0.4/§3 git-safety before any change is made.
