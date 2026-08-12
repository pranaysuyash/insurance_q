# ADR-2026-08-12-01 — Drop Redis; consolidate caching on Supabase Postgres

**Status:** Proposed (awaiting Pranay sign-off)
**Date:** 2026-08-12
**Owner:** Forge
**Supersedes:** any prior design that places a standalone Redis between the RAG service and the answer path (AWS `rag-service-config-mumbai-v6-public-redis.json`, Azure `deploy_full_backend_to_azure.sh`).

---

## 1. Context

We are removing the AWS deployment path (user-confirmed obsolete; nothing live as of 2026-08-12). The canonical path is **Cloud Run + Supabase Postgres + pgvector + private Storage** (per `README.md:39-48`).

The single worst defect in the audit (`docs/audit/rag_mobile_best_practices_audit_2026-08-12.md`, Finding #2) was a **public, unauthenticated Redis** caching full private policy answers. Investigation shows this was **not an AWS-specific mistake** — the Azure deploy script contains the identical anti-pattern: *"services are currently configured to connect to Redis without a password for simplicity"* (`scripts/deploy_full_backend_to_azure.sh:25`). Redis is used in two roles:

1. **RAG answer/query cache** (`src/rag/pipeline.py`: `_init_redis`, `_load/_store_cached_query_result`).
2. **Policy-summary overlay cache** (`src/services/policy_extraction_service.py`: `self._redis`, `policy_summary:*` keys; the primary store is the `document_policy_summaries` Postgres table, Redis is an optional overlay — *"Redis may have newer data"*, `:466`).

A further latent flaw: on a cache hit, `pipeline.py:1165-1167` returns the stored response **without re-running `_verify_citations`/`verify_answer`** (those run only on the live LLM path at `:1368`/`:1381`). Any poisoned cache entry would be served as "evidence-backed" unchallenged.

**Decision trigger:** before rebuilding on the canonical path, decide the caching substrate so we do not recreate the same failure class under a new provider.

---

## 2. Decision

**Remove Redis entirely from the new architecture.** Consolidate all state on **Supabase Postgres**, which already hosts the canonical datastore and (per README) pgvector:

- **Vectors** → `pgvector` (replaces Qdrant).
- **Answer cache** → a new `rag_query_cache` Postgres table, owner-scoped via Row-Level Security, with a `expires_at` TTL column and a version key for invalidation on ingest. **Optional at launch** — see Options D.
- **Policy summaries** → `document_policy_summaries` Postgres table (already exists); **delete the Redis overlay path** in `policy_extraction_service.py`.

No standalone cache service (Redis/Memcached) is introduced.

---

## 3. Options considered

| Option | Verdict | Rationale |
|---|---|---|
| **A. Managed Redis (Memorystore), private + IAM-auth** | Rejected for launch | Re-introduces a second datastore and the *exact* class of failure we just removed (it was the password-less habit, not the provider, that broke us). Premature; adds infra cost + a new attack surface to secure. Revisit only if metrics justify (Option B-later). |
| **B. Postgres-only (pgvector + `rag_query_cache` table)** ✅ | **Accepted** | Single canonical datastore; inherits Supabase auth/RLS so the cache is automatically owner-scoped and never publicly reachable; no new infra; satisfies `motto_v5 §0.1` (no parallel/shadow store) and `§0.8` (data layer is product). |
| **C. In-memory LRU (single instance)** | Rejected as primary | Cloud Run scales to multiple instances → caches are per-instance (low hit rate, stale divergence) and lost on restart. Could be a *later* cheap hot-layer, not a shared source of truth. |
| **D. No cache at launch** | Viable fallback | If traffic is low, skip caching entirely and add `rag_query_cache` when p99 latency / embedding cost crosses a threshold. The cache is an optimization, not a dependency. |

---

## 4. Why B (first-principles)

- **Single source of truth.** A separate shared cache of private answers was the root cause of the exposure. Consolidating on Postgres removes the "second untrusted surface" problem.
- **Security boundary is inherited, not reinvented.** Supabase RLS scopes rows per tenant; there is no public endpoint to misconfigure. The AWS/Azure mistakes were both "forgot the password / exposed the host." Postgres removes that footgun.
- **Small product, modest QPS.** Redis's speed advantage matters at high QPS; for an early insurance companion it is premature optimization. Postgres answers a cache lookup in single-digit ms — fine.
- **Kill the habit, not just the instance.** Removing Redis everywhere (AWS + Azure + docker-compose + scripts) deletes the "Redis without auth" pattern from the repo.

---

## 5. Security requirements for the new cache (must-haves)

1. **Owner-scoped (RLS).** Cache rows carry `owner_id`; cross-tenant reads impossible at the DB layer.
2. **Re-verify on read.** Cache hits MUST re-run `verify_citation` + `verify_answer` before returning (closes the `pipeline.py:1165` gap). Cache is treated as **untrusted**; verification is cheap (string match) and is the defense-in-depth against any write-path compromise.
3. **TTL + version invalidation.** `expires_at` column + global version key bumped on ingest (design already has the version concept).
4. **No public exposure.** Postgres is private; only the Cloud Run service + Supabase-bound clients reach it.
5. **Cache disabled by default flag.** `RAG_CACHE_ENABLED=false` at launch is acceptable; flip on after the faithfulness eval passes.

---

## 6. Migration / rollback

- **Remove Redis substrate:** delete `docker-compose.yml` redis service; drop `redis==5.0.1` from `requirements.txt` + prod lock; remove Redis env from `render.yaml`, any future Cloud Run config, and all deploy scripts.
- **Code changes:**
  - `src/rag/pipeline.py`: replace `_init_redis`/`_load/_store_cached_query_result` with a `PostgresCacheAdapter` (or a `NullCache` when disabled); add re-verify-on-read.
  - `src/services/policy_extraction_service.py`: drop `redis_client` param; read/write `document_policy_summaries` only.
  - `src/rag/config.py`: remove `redis_host/port` (deprecated block already raises `DeprecationWarning`).
- **Tests:** `tests/test_rag_pipeline.py:221` (MagicMock redis), `tests/test_production_container_contract.py:32` (asserts `redis==5.0.1` in requirements), `tests/test_policy_summary_storage.py` (redis_client=None path) — update to the Postgres/null adapter.
- **Rollback:** cache is opt-in behind `RAG_CACHE_ENABLED`; if Postgres cache underperforms, set it `false` and the system behaves as Option D with zero code rollback.

---

## 7. Affected files (removal scope — also advances the AWS teardown)

**Delete / neutralize (Redis-coupled, non-canonical):**
- `rag-service-config-mumbai-v6-public-redis.json` (AWS, dead)
- `scripts/deploy_full_backend_to_azure.sh` (Azure Redis no-password anti-pattern)
- `scripts/fix_services_config.sh` (Azure Redis key wiring)
- `scripts/validate_redis_cache.sh`, `utils/validate_redis_cache.py`
- `docker-compose.yml` redis service + `redis_data` volume
- `requirements.txt:45` + `requirements-production-ocr-linux-x86_64.lock:1966` (`redis==5.0.1`)
- `render.yaml` Redis key blocks (`:73-75`, `:118-120`)
- `install_deps.sh:30` (redis pin), `check_versions.py:12` (redis)

**Modify:**
- `src/rag/pipeline.py`, `src/services/policy_extraction_service.py`, `src/rag/config.py`
- `tests/test_rag_pipeline.py`, `tests/test_production_container_contract.py`, `tests/test_policy_summary_storage.py`

*(Full AWS-artifact removal list to be finalized in the fork-resolution ADR; this ADR covers the Redis portion.)*

---

## 8. Open items / verification still required

- [ ] Confirm `pgvector` schema + Supabase migrations exist and are applied (README lists "Supabase migrations" as a launch gate).
- [ ] Confirm Supabase is the active vector backend in the production config (`pipeline.py:125` defaults to `qdrant` when `ENVIRONMENT` unset — must be `production` + `RAG_VECTOR_BACKEND=supabase`).
- [ ] Add a `docs/launch_claims/` entry gating any "cached/optimized" performance claim.
- [ ] Re-run the faithfulness eval (`src/eval/ragas_eval.py`) on the new backend before enabling the cache.

---

## 9. Update log

- **2026-08-12** — Initial proposal. Context, decision (drop Redis, consolidate on Postgres), options, security requirements, and removal scope recorded. Awaiting Pranay sign-off.
