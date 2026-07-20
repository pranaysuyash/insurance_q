# ADR-2026-07-20-26: RAG Pipeline Excellence

**Date:** 2026-07-20  
**Status:** Accepted (operator sign-off via session e3d3b058)  
**Author:** Antigravity AI  
**Operator:** Pranay  

---

## Context

A full codebase inspection of `src/rag/pipeline.py` (1479 lines), `src/rag/service.py`, `src/models/rag.py`, `src/services/citation_verifier.py`, `src/services/evidence_pipeline.py`, `src/services/evidence_substrate_service.py`, `src/services/supabase_vector_store.py`, and `src/eval/ragas_eval.py` was performed on 2026-07-20. The audit reconciliation (AUDIT_REMEDIATION_RECONCILIATION_2026-07-20.md) and all 25 existing ADRs were reviewed.

The RAG pipeline has strong advanced techniques (HyDE, RAG Fusion, RRF, cross-encoder reranking, retrieval quality gating, structured citations, contextual retrieval infrastructure) but several critical wires are disconnected. The citation verifier exists but is never called. The Supabase FTS path is absent. source_text and page_artifact_id are never returned in query responses. The eval corpus is not decision-grade.

## Decision

Execute all 6 commits to bring the RAG pipeline to excellence across: searchability, grounding, traceability, graph linkage, multi-granularity embeddings, and evaluation.

Five architecture decisions were made from first principles and approved by operator:

### Decision 1: FTS Strategy — Both tsvector AND pg_trgm

Insurance documents contain two irreconcilable search patterns: natural language clauses (tsvector) and structured identifiers like policy numbers (pg_trgm). These are not alternatives. Both indexes are added to `document_chunks`. The RPC function queries both and merges. This decision is permanent.

### Decision 2: Graph Backend — Normalized `chunk_links` table

JSON adjacency columns have no referential integrity, no index on target IDs, and are not composable with type filters. A normalized `chunk_links (source_chunk_id, target_chunk_id, link_type, weight)` table with FK constraints is the correct permanent structure. `section_type` is a column on `document_chunks` (intrinsic attribute, not a relationship).

### Decision 3: Contextual Retrieval — Feature Flag + Backfill + Eval Gate

`CONTEXTUAL_RETRIEVAL_ENABLED` is exposed as an operator-controllable API feature flag (not env-only). Global enable is gated on: (a) complete `retrieval_text` backfill for all existing chunks, (b) eval corpus baseline (Commit 5), (c) re-run showing context_recall improvement without faithfulness regression.

### Decision 4: Eval Corpus — Phase A (policy.pdf, 80-100 Q&As) then Phase B (3+ policies)

The eval corpus is a versioned data asset in `docs/eval/corpus/`. Questions are document-anchored (generated from source text, not assumed from memory). Negative examples (answer not in document) are included. CI fails when RAGAS scores regress below threshold.

### Decision 5: Citation Verifier Strictness — Three-Tier Model

- **Tier 1 (exact match, normalized whitespace):** pass. Citation shown with page link.
- **Tier 2 (exact fails, fuzzy ≥ 70% token overlap):** warning. Citation shown in distinct UI state ("approximate match"), no page link.
- **Tier 3 (fuzzy fails):** fail. Citation stripped. Answer still shown.

This is the correct trust boundary for an insurance product where users tap citations to view policy pages.

## Options Considered

### FTS
- tsvector only — rejected: policy numbers fail tokenization
- pg_trgm only — rejected: IDF weighting and stemming needed for clauses
- Both — accepted

### Graph backend
- JSON adjacency column — rejected: no FK integrity, poor query composability
- Separate graph DB — rejected: no new infra needed, Postgres is sufficient
- Normalized `chunk_links` table — accepted

### Citation strictness
- Fuzzy match as pass — rejected: trust-destroying UX when user taps "open page" and quote isn't there
- Exact only, no warning tier — rejected: throws away useful paraphrased citations without informing user
- Three-tier model — accepted: honest, informative, auditable

## Tradeoffs

- The `chunk_links` table adds a DB migration and ingestion-time writes. Cost is one INSERT per adjacent chunk pair at ingest time (~2N writes per document). This is negligible vs. the correctness gain.
- Multi-granularity embeddings (Commit 4) increase vector storage by ~3x (sentence + paragraph + doc levels). Acceptable given Supabase pgvector scales by row count.
- The eval corpus (Commit 5) requires manual review of 15-20 semantic questions. This is a one-time cost for a permanent quality gate.

## Risks

| Risk | Mitigation |
|------|------------|
| DB migration breaks existing chunks | Migration is additive — new columns + new table; no existing rows modified |
| FTS RPC changes response shape | RPC is a new function; existing `match_document_chunks` RPC unchanged |
| Multi-granularity doubles ingestion time | Sentence + paragraph computed in same pass; no extra LLM calls |
| Contextual retrieval re-enable breaks faithfulness | Gated on eval evidence; old chunks not re-embedded until backfill passes |

## Validation Plan

- Commit 1: unit tests for citation verifier integration; manual Q&A test to confirm source_text in response
- Commit 2: SQL migration tested in Supabase dev environment; integration test for FTS RPC
- Commit 3: ingestion test verifying chunk_links rows created; context expansion test
- Commit 4: embedding counts verified per document; no vector dimension mismatch
- Commit 5: RAGAS scores reported; CI gate active; baseline documented
- Commit 6: eval re-run post-backfill; faithfulness must not regress vs. Commit 5 baseline

## Rollback / Migration Path

- Commits 1-3: fully additive; no existing behavior removed
- Commit 4: new `chunk_type` field; old chunks receive `chunk_type='paragraph'` default
- Commit 5: eval corpus is data-only; no code rollback needed
- Commit 6: feature flag can be set back to `false` to revert contextual retrieval

## What Would Cause This Decision to Be Revisited

- Contextual retrieval causes faithfulness regression in eval — Commit 6 gates on this explicitly
- `chunk_links` table causes unacceptable ingestion latency — benchmark at Commit 3, adjust if needed
- RAGAS thresholds proven too strict/loose after real-world usage — update corpus and thresholds

## Update Log

- 2026-07-20: Initial ADR written and accepted. Operator: "write the plan with these baked in [...] do all."
