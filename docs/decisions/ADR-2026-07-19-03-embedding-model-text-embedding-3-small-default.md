# ADR-2026-07-19-03: Embedding model = `text-embedding-3-small` (default), with a 30-day benchmark window for `voyage-3`

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** Default to `text-embedding-3-small` (OpenAI, 1536 dimensions) for CoverWise's embedding model. Run a benchmark against `voyage-3` (Voyage AI, 1024 dimensions) over 30 days from launch. Switch the default if and only if the benchmark shows `voyage-3` improves recall@3 by ≥5 percentage points.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** Accepted.
- **Related artifacts:** [embedding_model_benchmark_methodology_2026-07-19.md](../../architecture/embedding_model_benchmark_methodology_2026-07-19.md), [`tools/benchmark_embedding_models.py`](../../../tools/benchmark_embedding_models.py), [ADR-2026-07-19-01](./ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md) (the outbox contract; embeddings flow through `document_chunks` which is independent of the substrate).

---

## Context

The architecture audit flagged the embedding model choice as ADR-06. The decision shapes the retrieval quality of every Q&A path in CoverWise: the policy detail screen's RAG-backed Q&A, the claim verification (future), the renewal diff (future), the substrate's span-level search (v2). Get it right once; every retrieval path inherits it. Get it wrong; every retrieval path silently returns wrong results.

The launch playbook already defaults to `text-embedding-3-small` (`OPENAI_EMBEDDING_MODEL=text-embedding-3-small`). The question is whether to keep that default or change it.

The candidate models:

| Model | Provider | Dimensions | Cost / 1M tokens | MTEB avg |
|---|---|---|---|---|
| `text-embedding-3-small` | OpenAI | 1536 | $0.02 | ~62.3 |
| `voyage-3` | Voyage AI | 1024 | $0.06 | ~67.0 |
| `text-embedding-3-large` | OpenAI | 3072 | $0.13 | ~64.6 |

MTEB is a generic benchmark; insurance policy retrieval is a domain-specific problem. The architecture audit's recommendation is to benchmark on real CoverWise data. The benchmark is the empirical evidence that decides.

---

## Options considered

### Option A: `text-embedding-3-small` (1536d) — the existing default. CHOSEN.

- **How it works:** OpenAI's small embedding model. 1536 dimensions, supports Matryoshka (can store at 1536 and query at 512 or 256 with minimal quality loss).
- **Cost at CoverWise's scale:** ~$200 over 5 years for the projected 10B tokens of policy text. Negligible.
- **Storage cost:** 60 TB over 5 years for the projected 10B tokens. Best in class for OpenAI.
- **Vendor risk:** lowest. OpenAI is the largest, most-stable embedding vendor.
- **Domain evidence:** none yet. The launch playbook default is unverified for CoverWise's domain (Indian health insurance).

### Option B: `voyage-3` (1024d) — the highest-quality generalist per MTEB.

- **How it works:** Voyage AI's flagship embedding model. 1024 dimensions, no Matryoshka.
- **Cost at CoverWise's scale:** ~$600 over 5 years. 3x small.
- **Storage cost:** 40 TB over 5 years. Best in class overall.
- **Vendor risk:** higher. Voyage is a startup; pricing volatility and model deprecation are real risks.
- **Domain evidence:** none yet. MTEB leaderboard position suggests voyage may be better, but MTEB is not the right benchmark for this domain.

### Option C: `text-embedding-3-large` (3072d) — the OpenAI flagship.

- **How it works:** OpenAI's largest embedding model. 3072 dimensions, supports Matryoshka.
- **Cost at CoverWise's scale:** ~$1,300 over 5 years. 6.5x small.
- **Storage cost:** 120 TB over 5 years. 2x small.
- **Quality vs small:** marginal. MTEB delta is smaller than the voyage vs small delta.
- **Why not:** the marginal quality improvement does not justify the 6.5x cost premium. If voyage-3 does not beat small by 5pp, large-3 will not either; the MTEB delta is smaller.

### Option D: Open model (BGE-large, E5-large, instructor-xl).

- **How it works:** self-hosting. The pgvector index already requires a managed Postgres; self-hosting the embedding model is a second managed system.
- **Cost at CoverWise's scale:** zero per-token, but ~$50-200/month for the GPU instance.
- **Vendor risk:** zero (you own the model).
- **Why not:** the operational cost offsets the per-token savings at CoverWise's current scale (~10K documents projected). Self-hosting is a v3 follow-up when the volume justifies it.
- **Domain evidence:** none. The "BGE works for legal text" claim is not as well-validated as OpenAI / Voyage for English.

---

## Chosen path

**Option A: `text-embedding-3-small` (1536d) as the default, with a 30-day benchmark window for `voyage-3`.**

The structure:

1. **Default to `text-embedding-3-small`** (the existing launch playbook value, `OPENAI_EMBEDDING_MODEL=text-embedding-3-small`). This is what the launch playbook already says; the decision is to keep it.
2. **Run a benchmark on real CoverWise policy data** — 50 policies × 20 queries = 1000 (policy, query) pairs, recall@3 per model, decision rule with a 5pp threshold. The benchmark is [`tools/benchmark_embedding_models.py`](../../../tools/benchmark_embedding_models.py); the methodology is [`docs/architecture/embedding_model_benchmark_methodology_2026-07-19.md`](../../architecture/embedding_model_benchmark_methodology_2026-07-19.md).
3. **Switch if and only if the benchmark shows voyage-3 is meaningfully better (≥5pp recall@3 improvement).** The migration is `tools/reembed_all_documents.py` (to be built in the benchmark follow-up; not in this session).
4. **Re-evaluate every 6 months.** Embedding models improve; what is best today may not be best in 6 months.
5. **What does NOT change:** the substrate's `extracted_fields` table does NOT store embeddings (it stores the field text + value). Embeddings live in `document_chunks` (pgvector, created by `infra/supabase/001_coverwise_schema.sql`). The substrate is independent of the embedding model.

---

## Why this path

### 1st-principle argument

The decision is not "which model has the highest MTEB score" — it is "which model gives us the best quality-per-dollar-per-storage-per-vendor-risk tradeoff for insurance policy retrieval at our scale." At CoverWise's scale:

- Cost: 10B tokens × $0.02/M = $200 (small), $600 (voyage), $1,300 (large). All affordable; small is 3x cheapest.
- Storage: 60 TB (small), 40 TB (voyage), 120 TB (large). Voyage wins, small is second, large is 2x worse.
- Vendor risk: OpenAI is the lowest risk; Voyage is a startup.
- Quality: unknown for the domain. The benchmark answers this.

The honest answer is: **commit to the default now, measure over 30 days, switch if the measurement says so.** The decision is not "we know which is best" — it is "we will know which is best by date X."

### Anti-MTEB argument (motto v3 §0.7: AI output boundary)

MTEB is a generic benchmark; insurance policy retrieval is a domain-specific problem. "The model has a 5-point higher MTEB score, so it's better" is a lie for domain-specific problems. The benchmark on real CoverWise data is the evidence. Until the benchmark runs, the default stays.

### Anti-vibes argument (motto v3 §0.7)

"I read that voyage is better for legal text" is a lie unless measured. The benchmark measures. The recommendation comes from the data, not from the vendor's marketing.

### Cost argument

The benchmark costs less than $0.05 in API calls. The cost of NOT running the benchmark (a wrong model choice over 5 years, paid in confabulated answers and lost user trust) is orders of magnitude larger. The benchmark is cheap insurance.

### Vendor-risk argument

Switching to voyage is a vendor lock-in decision. Voyage is a startup; OpenAI is the largest embedding vendor. The 5pp threshold is the cutoff that says "the quality improvement is large enough to justify the vendor risk." Below 5pp, keep the lower-risk vendor.

### Anti-parallel-paths argument (motto v3 §0.1)

The outbox (ADR-2026-07-19-01) and the substrate (Trust Phase 1) are independent of the embedding model. The embedding model lives in `document_chunks`; the substrate lives in `page_artifacts` / `source_spans` / `extracted_fields` / `field_evidence`. The decision is isolated; switching the embedding model does not affect the substrate.

---

## Tradeoffs

- **The benchmark is on the current model lineup.** OpenAI and Voyage ship new models regularly. The benchmark is a snapshot; the operator re-runs it on the new lineup every 6 months.
- **The benchmark is in English.** CoverWise's users are Indian; some policies are in Hindi, Tamil, Bengali, etc. v2 of the benchmark may add non-English policies.
- **The benchmark is on retrieval, not on end-to-end answer quality.** A model that returns the right chunks may still produce a worse answer if the LLM is confused by the chunk ordering. v2 may add a downstream answer-quality evaluation.
- **The default is committed before measurement.** Per the architecture audit's "ship the contract, then measure" pattern: the launch playbook defaults to small; the benchmark measures; the operator decides. This is the same pattern as ADR-2026-07-19-01 (ship the outbox contract, defer the migration) and ADR-2026-07-19-02 (ship the contract, defer the consumer adoption).
- **The 5pp threshold is an opinion.** A 3pp improvement may be worth the migration cost in some scenarios. The 5pp threshold is the standard cutoff in the architecture audit; it is the right starting point. v2 may revisit.

---

## Assumptions

- **The 30-day benchmark window is enough time to gather 50 real policies and 20 queries per policy.** At CoverWise's launch volume, ~50 policies per month is the projected baseline. The window may be extended if the volume is lower.
- **The operator has the domain expertise to label the ground truth.** The ground truth is hand-labeled; the operator is the domain expert on Indian insurance policies.
- **The benchmark's pseudo-embedding dry-run path is a plumbing test, not a model evaluation.** The dry-run path uses hash-based pseudo-embeddings to verify the script works end-to-end without API keys. The dry-run's recall@3 numbers are not the decision; they are a sanity check.
- **The benchmark is reproducible.** Same policies, same queries, same ground truth, same model names → same recall@3 numbers (modulo API non-determinism, which is small for embedding models).

---

## Risks

- **The benchmark says voyage is better, but the operator doesn't switch.** The recommendation is not a mandate. The operator reviews the recommendation, the per-query results, the cost implications, and the vendor risk before acting.
- **The benchmark says small is fine, but small is actually wrong for a real-world case the benchmark doesn't cover.** The benchmark is on 50 policies × 20 queries = 1000 pairs. It may miss a niche case. v2 may add a larger sample size or a domain-expert review.
- **The benchmark takes longer than 30 days.** The window may be extended. The default stays small until the benchmark says otherwise.
- **The operator never runs the benchmark.** The default stays small forever. This is the acceptable failure mode; small is a reasonable default, and the operator can run the benchmark later.

---

## Validation plan

- **Dry-run path:** the script's `--dry-run` mode uses fixture data and pseudo-embeddings. The dry-run verifies the script's plumbing (data loading, embedding, top-k, recall computation, decision rule, results writing). The dry-run's recall@3 numbers are NOT used for the decision; they are a sanity check that the script works.
- **Live run:** the operator runs `python tools/benchmark_embedding_models.py` after the launch playbook's Step 1 (apply 7 migrations) and Step 8 (upload 50+ real policies). The script reads from `document_chunks` and writes to `tools/embedding_benchmark/results/<timestamp>/`.
- **Re-evaluate:** the operator re-runs the benchmark every 6 months, or whenever the model lineup changes. The `tools/embedding_benchmark/results/` directory is the historical record.
- **Switch:** if the benchmark says SWITCH_TO_VOYAGE_3, the operator updates the launch playbook's `OPENAI_EMBEDDING_MODEL` env var to `voyage-3`, runs `tools/reembed_all_documents.py` (to be built), and re-deploys. The migration is documented in the next ADR (`ADR-2026-07-19-04` if a switch is warranted).
- **Operational test:** the policy detail screen's Q&A path returns chunks from the embedding model. A real user query ("what is the room rent cap?") should return the relevant chunk in the top-3. This is the empirical test.

---

## Rollback or migration path

### Migration (small → voyage-3)

1. Update the launch playbook's `OPENAI_EMBEDDING_MODEL` to `voyage-3`.
2. Add `VOYAGE_API_KEY` to the GCP Secret Manager (Step 4 of the launch playbook).
3. Build `tools/reembed_all_documents.py` (a new script, not in this session).
4. Run the re-embed script: it reads all `document_chunks` and re-embeds with voyage-3. The script is idempotent (it re-embeds every chunk; the new embedding replaces the old).
5. Update the API's embedding call to use voyage-3.
6. Re-run the benchmark to confirm the new model is in production.
7. Update the launch playbook's `OPENAI_EMBEDDING_MODEL` documentation to `voyage-3` and the `OPENAI_API_KEY` reference to note "used for LLM only" (or remove if not used for anything else).

### Rollback (voyage-3 → small)

Same steps in reverse. The `document_chunks.embedding` column is re-populated with small's embeddings. The rollback is more expensive (re-embedding all documents) but is bounded.

---

## What would cause this decision to be revisited

- **The benchmark shows voyage-3 is ≥5pp better.** A new ADR (`ADR-2026-07-19-04`) captures the switch decision. The default becomes voyage-3.
- **The benchmark shows small is much better (≥5pp).** The default stays small; the ADR's "what would cause revisit" is updated to "models get worse, not better."
- **A new model ships with a 10pp+ improvement on the benchmark.** A new ADR captures the new model. The default updates; the operator re-runs the benchmark on the new model.
- **The vendor landscape changes.** OpenAI deprecates text-embedding-3-small; Voyage raises prices; a new vendor emerges. A new ADR captures the new landscape.
- **The benchmark's 50-policy sample is too small to be statistically reliable.** The operator increases the sample size to 200 policies × 20 queries = 4000 pairs. The benchmark's confidence interval drops from ±3pp to ±1.5pp.

---

## Links

- **Affected files (this commit):**
  - `tools/benchmark_embedding_models.py` (new, the empirical measurement)
  - `docs/architecture/embedding_model_benchmark_methodology_2026-07-19.md` (new, the methodology)
  - `docs/decisions/ADR-2026-07-19-03-embedding-model-text-embedding-3-small-default.md` (this file)
  - `docs/decisions/README.md` (updated index)
  - `docs/technical/deployment/launch_playbook_2026-07-18.md` (updated with the benchmark as Step 1.5)
  - `docs/planning/coverwise_audit_task_classification_2026-07-18.md` (updated; Bucket 5 #20 marked shipped)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-01](./ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md) (the outbox contract; embeddings flow through `document_chunks` which is independent of the substrate)
  - [ADR-2026-07-19-02](./ADR-2026-07-19-02-outbox-migration-deferred.md) (the same ship-then-measure pattern)
  - `coverwise_architecture_audit_2026-07-18.docx` (the source audit, ADR-06)
- **Related code:**
  - `infra/supabase/001_coverwise_schema.sql` (the `document_chunks` table with `pgvector` 1536d)
  - `src/rag/pipeline.py` (the embedding call; the model name is read from the `OPENAI_EMBEDDING_MODEL` env var)
- **Motto v3 alignment:** §0.4 (acceptance contract: the benchmark IS the contract), §0.5 (evidence tiers: T2 dry-run + T0 live), §0.7 (AI output boundary: the decision is a measurement, not a vendor recommendation), §0.10 (observability is delivery: the benchmark's results are written to disk and are auditable), §0.12 (this document).
