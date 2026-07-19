# Embedding Model Benchmark Methodology

**Date:** 2026-07-19
**Status:** Accepted
**Related ADR:** [ADR-2026-07-19-03-embedding-model-text-embedding-3-small-default](./ADR-2026-07-19-03-embedding-model-text-embedding-3-small-default.md)
**Script:** `tools/benchmark_embedding_models.py`

This document is the methodology behind the embedding model benchmark. It explains what is being measured, why, and the limits of the measurement. The benchmark is the empirical evidence the embedding model decision rests on; this document is what makes the benchmark reproducible and auditable.

---

## 1. The problem

CoverWise retrieves relevant chunks of policy text to answer user questions. The retrieval is powered by an embedding model: each chunk is embedded at upload time, the user's question is embedded at query time, and the top-k chunks by cosine similarity are returned. The embedding model is the contract between text and meaning.

Choosing the wrong model means the system returns the wrong chunks, and the LLM that reads the chunks confabulates an answer. The user sees a confident-sounding response based on the wrong text. This is the failure mode the architecture audit flagged as ADR-06.

A 1st-principle decision requires evidence, not a vendor recommendation. The benchmark is the evidence.

## 2. The metric: recall@3

The policy detail screen's Q&A path retrieves the top-3 chunks per query. If the relevant chunk is in the top-3, the user gets a correct answer. If not, they get a confabulation.

**recall@3 = (# of (policy, query) pairs where the top-3 contains at least 1 relevant chunk) / total pairs.**

This is the metric that matters for the user.

### Why not other metrics

- **MTEB scores** are a generic benchmark. Insurance policy retrieval is a domain-specific problem; the MTEB leaderboard is not predictive of domain performance.
- **nDCG@10** is the standard IR metric but assumes the user scrolls past rank 3. CoverWise shows 3; the user does not scroll.
- **precision@3** measures "of the top-3, how many are relevant?" — useful but not as user-impacting as recall@3. A low-precision model returns 3 chunks, one relevant, two off-topic; the LLM picks the relevant one and answers correctly. A low-recall model returns 3 chunks, all off-topic; the LLM confabulates.
- **MRR (mean reciprocal rank)** is a finer metric that distinguishes "rank 1" from "rank 3." For v1, the simpler recall@3 is the right metric. v2 may upgrade to MRR.

## 3. The models

The benchmark compares:

| Model | Provider | Dimensions | Cost / 1M tokens | MTEB avg |
|---|---|---|---|---|
| `text-embedding-3-small` | OpenAI | 1536 | $0.02 | ~62.3 |
| `voyage-3` | Voyage AI | 1024 | $0.06 | ~67.0 |

The MTEB column is reference; the decision is based on the benchmark, not MTEB. MTEB is the wrong benchmark for this domain; the benchmark IS the right benchmark.

### Why these two

- `text-embedding-3-small` is the current default per the launch playbook (`OPENAI_EMBEDDING_MODEL=text-embedding-3-small`). The benchmark's first job is to verify the default is correct.
- `voyage-3` is the highest-quality generalist embedding model per MTEB. It is the most likely switch candidate if the default is wrong.
- `text-embedding-3-large` is excluded from the benchmark because the quality-vs-cost tradeoff does not justify the 6.5x cost premium for CoverWise's volume. If `voyage-3` does not beat `text-embedding-3-small` by 5pp, `text-embedding-3-large` will not either; the MTEB delta is smaller.
- Open models (BGE, E5, instructor-xl) are excluded from the benchmark because self-hosting is operational cost that does not fit CoverWise's stage. v2 of the benchmark may add them.

## 4. The data

### Sample size

- 50 policies sampled from real CoverWise uploads.
- 20 queries per policy = 1000 (policy, query) pairs.

The numbers come from a 95% confidence interval calculation: with 1000 pairs, the recall@3 estimate has a margin of error of about ±3pp. A 5pp improvement is detectable with high confidence.

### The policies

The 50 policies are real CoverWise uploads (anonymized for benchmark purposes). They are diverse: health, motor, life, critical illness, personal accident. The benchmark's recall@3 numbers reflect this distribution.

### The queries

The 20 queries per policy are hand-written. They are the kinds of questions a real user asks:

- "what is the room rent cap?"
- "is maternity covered?"
- "what is the co-payment for senior citizens?"
- "is this worldwide coverage?"
- "what is the waiting period for pre-existing diseases?"
- "do I need a medical test?"
- "is there a family discount?"
- "what is the survival period?"
- "how much sum insured?"
- "is it a lump sum?"
- "what is the day care list?"
- ...

The queries are not the same across policies; they are tailored to the policy's content. The operator writes the queries; the benchmark does not synthesize them.

### The ground truth

For each (policy, query) pair, the operator labels which chunk indices contain the answer. The ground truth is a JSONL file:

```jsonl
{"policy_id": "uuid-of-the-policy", "query": "what is the room rent cap?", "relevant_chunk_indices": [1, 7, 12]}
```

`relevant_chunk_indices` is the list of indices (0-based, in the order they appear in `document_chunks` for that policy) of chunks that contain the answer.

The ground truth is the operator's expert judgment. It is not algorithmically generated. The operator is the only person who knows the policy well enough to label the ground truth.

## 5. The protocol

For each (policy, query) pair:

1. Embed the query with model A (`text-embedding-3-small`).
2. Compute the cosine similarity between the query embedding and each chunk's pre-computed embedding.
3. Take the top-3 indices by similarity.
4. Check if any of `relevant_chunk_indices` appear in the top-3.
5. Repeat for model B (`voyage-3`).
6. Aggregate over all (policy, query) pairs.

The chunk embeddings are pre-computed at the start of the benchmark run (one batch per model). The query embeddings are computed one at a time. The cosine similarity is computed in plain Python (the pgvector `<=>` operator would be equivalent; plain Python avoids the round-trip).

## 6. The decision rule

```
if voyage_3_recall_at_3 - small_recall_at_3 >= 0.05:
    recommend SWITCH_TO_VOYAGE_3
elif small_recall_at_3 - voyage_3_recall_at_3 >= 0.05:
    recommend STRONG_KEEP_SMALL
else:
    recommend KEEP_SMALL
```

The 5pp threshold is the same threshold the architecture audit recommended. A smaller improvement (1-2pp) is not worth the migration cost; a larger improvement (5pp+) is.

### What "recommend" means

The benchmark reports a recommendation. The decision is the operator's. The recommendation is the starting point; the operator reviews the recommendation, the per-query results, the cost implications, and the vendor risk before acting.

## 7. The cost

The benchmark's cost is:

- ~50 policies × 1000 tokens / chunk × 5 chunks / policy = 250K tokens of chunk text per model.
- ~1000 queries × 20 tokens / query = 20K tokens of query text per model.
- Total: 270K tokens per model.

At $0.02/M tokens (small) and $0.06/M tokens (voyage), the cost is:

- $0.0054 (small, negligible)
- $0.016 (voyage, negligible)

The benchmark costs less than $0.05 in API calls. The cost of NOT running the benchmark (a wrong model choice over 5 years) is the relevant comparison.

## 8. The limits

The benchmark is honest about what it is and is not:

- **1000 (policy, query) pairs is a strong signal but not a proof.** A 5pp improvement on 1000 pairs has a 95% confidence interval of about ±3pp. The recommendation is the operator's call.
- **The ground truth is one person's judgment.** The operator labels which chunks are relevant. A second reviewer would catch some of the operator's mistakes. v2 of the benchmark may add a second reviewer.
- **The benchmark is in English.** CoverWise's users are Indian; some policies are in Hindi, Tamil, Bengali, etc. The benchmark does not cover non-English policies. v2 may.
- **The benchmark is on chunk-level retrieval, not on end-to-end answer quality.** A model that returns the right chunks may still produce a worse answer if the LLM is confused by the chunk ordering. The benchmark measures retrieval, not answer quality. v2 may add a downstream answer-quality evaluation.
- **The benchmark is on the current model lineup.** OpenAI and Voyage ship new models regularly. The benchmark is a snapshot; re-running it on the new lineup is the operator's job (every 6 months per the ADR).

## 9. Reproducibility

The benchmark is deterministic given:

- The same 50 policies.
- The same 20 queries per policy.
- The same ground truth.
- The same model versions (the model name string is the key).

A re-run with the same inputs produces the same recall@3 numbers (modulo API response non-determinism, which is small for embedding models). The ground truth file is the source of truth; the benchmark script is the procedure.

## 10. Anti-patterns this benchmark rejects

- **MTEB-only decisions.** "The model has a 5-point higher MTEB score, so it's better" is a lie for domain-specific problems. MTEB is a generic benchmark; the domain is specific.
- **Vibes-based decisions.** "I read that voyage is better for legal text" is a lie unless measured. The benchmark measures.
- **One-shot decisions.** "I ran the benchmark once, the result was X, that's the answer forever" is a lie. Models improve. Re-run every 6 months.
- **Cost-blind decisions.** "Quality is all that matters" is a lie. The 3x cost premium for voyage must be worth the 5pp+ recall improvement.
- **Vendor-blind decisions.** "The model is good, so we'll use it" without considering vendor lock-in is a lie. OpenAI is the lowest vendor risk; Voyage is a startup. The decision must account for that.
- **Threshold-blind decisions.** "Switch on a 1pp improvement" is a lie. The 5pp threshold is the right cutoff because below that, the migration cost is not recovered over 5 years.
