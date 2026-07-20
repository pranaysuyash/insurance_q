# CoverWise RAG Pipeline — Exploration Map
**Date:** 2026-07-20  
**Evidence Tier:** Tier 1 (full codebase inspection of all RAG-related files)  
**Status:** Pre-implementation analysis. Plan approved. Implementation in progress.  
**Author:** Antigravity AI (agent session e3d3b058)  

See companion docs:  
- [`rag_pipeline_discussion_2026-07-20.md`](rag_pipeline_discussion_2026-07-20.md) — full first-principles discussion and Q&A  
- [`ADR-2026-07-20-26-rag-pipeline-excellence.md`](../decisions/ADR-2026-07-20-26-rag-pipeline-excellence.md) — decision record for all architecture choices  

---

## 1. Files Inspected

| File | Role | Lines |
|------|------|-------|
| [`src/rag/pipeline.py`](../../src/rag/pipeline.py) | Main RAG orchestrator | 1,479 |
| [`src/rag/service.py`](../../src/rag/service.py) | FastAPI service layer | 231 |
| [`src/rag/config.py`](../../src/rag/config.py) | Legacy config (deprecated) | 62 |
| [`src/models/rag.py`](../../src/models/rag.py) | Pydantic output models | 60 |
| [`src/services/citation_verifier.py`](../../src/services/citation_verifier.py) | Post-generation citation grounding check | 101 |
| [`src/services/evidence_pipeline.py`](../../src/services/evidence_pipeline.py) | Field extraction from documents | 602 |
| [`src/services/evidence_substrate_service.py`](../../src/services/evidence_substrate_service.py) | Supabase evidence DB access layer | 399 |
| [`src/services/supabase_vector_store.py`](../../src/services/supabase_vector_store.py) | pgvector adapter | 97 |
| [`src/eval/ragas_eval.py`](../../src/eval/ragas_eval.py) | RAGAS eval (22 questions, fixture-only) | 141 |
| [`src/llm/client.py`](../../src/llm/client.py) | LLM client with cost tracking | 305 |
| [`src/ocr/pipeline.py`](../../src/ocr/pipeline.py) | doctr OCR (PDF → text + page images) | 616 |
| [`AUDIT_REMEDIATION_RECONCILIATION_2026-07-20.md`](../../AUDIT_REMEDIATION_RECONCILIATION_2026-07-20.md) | 103-item gap tracker | 360 |

---

## 2. What Is Already Implemented (Strengths)

### 2.1 Retrieval Techniques ✅
- **Dense retrieval** — OpenAI `text-embedding-3-small` (1536-D) via Qdrant or Supabase pgvector  
- **Sparse/lexical retrieval** — SQLite FTS5 with BM25 scoring (local hybrid index; Qdrant path only)  
- **RRF fusion** — Reciprocal Rank Fusion merging dense + sparse results (k=20)  
- **HyDE** — Hypothetical Document Embeddings: embeds a hypothetical answer, not raw query  
- **RAG Fusion** — Generates 2 query variants, searches all, merges via RRF  
- **Cross-encoder reranking** — `cross-encoder/ms-marco-MiniLM-L-6-v2` (optional, graceful fallback)  
- **Adaptive query classification** — `exact_lookup`, `multi_step`, `broad`, `single_step`  

### 2.2 Ingestion Pipeline ✅
- **Contextual Retrieval** — LLM context prepend to `retrieval_text` (disabled; `CONTEXTUAL_RETRIEVAL_ENABLED=false`)  
- **source_text / retrieval_text separation** — ADR-11 compliant; `source_text` is immutable OCR  
- **page_artifact_id per chunk** — every chunk carries page image UUID  
- **Multi-backend embedding fallback** — OpenAI → Ollama → local sentence-transformers  
- **Supabase/Qdrant dual backend** — env-driven  

### 2.3 Answer Generation ✅
- **Structured output** — `RAGAnswer`: answer + citations + confidence + missing_info + follow_up  
- **Context-only fallback** — graceful LLM-unavailable path  
- **Retrieval quality gate** — `_evaluate_retrieval_quality()` prevents hallucination on weak retrieval  

### 2.4 Trust / Grounding ✅
- **Citation verifier** — 6-check: quote_source=source_text, non-empty, in-bounds, document_id, page_number, substring match  
- **LLM honesty check in extractors** — `RoomRentCapExtractor` rejects when clause not found on any page  
- **Append-only evidence substrate** — 4 tables: page_artifacts, source_spans, extracted_fields, field_evidence  
- **v_field_citations view** — single Supabase view for UI; no app-code joins  

### 2.5 Caching ✅
- **Redis query cache** — keyed by query + top_k + filters + collection + models + version  
- **Cache version invalidation** — bumped on every ingest/delete  

### 2.6 Evaluation ✅ (partial)
- **RAGAS integration** — faithfulness, context_precision, response_relevancy (library integration exists)  
- **22 fixture questions** — hardcoded to one policy; not decision-grade  

---

## 3. Critical Gaps

### 3.1 Retrieval Gaps 🔴

| Gap | Severity | Audit Reference |
|-----|----------|-----------------|
| **P0-17: FTS broken on Supabase path** | CRITICAL | `supabase_vector_store.py` has no FTS. Production = dense-only. |
| **Citation verifier never called in query path** | CRITICAL | `citation_verifier.py` exists; `query_rag()` never invokes it |
| **`source_text` not in query response** | HIGH | `_format_source()` returns `retrieval_text`, not immutable OCR |
| **`page_artifact_id` not in query response** | HIGH | Mobile "open page" tap has no artifact ID |
| **No chunk adjacency / graph** | HIGH | No prev/next chunk, no section taxonomy, no clause dependency |
| **No parent-child chunking** | HIGH | Flat 2000-char chunks; `_split_into_sentences()` is dead code |
| **Embedding fallback unsafe (P0-16)** | HIGH | `recreate_collection` destroys vectors on dimension change |
| **Eval not decision-grade** | HIGH | 22 questions, 1 policy, no real baseline |
| **No cross-document comparison retrieval** | HIGH | `multi_step` classified but not implemented differently |
| **No per-query trace log** | HIGH | No retrieval scores, LLM call, or citation check stored |
| **No metadata-filtered search** | MEDIUM | Supabase search filters by owner_id + doc_ids only |
| **Chunk size hardcoded 2000 chars** | MEDIUM | No adaptive chunking by section type |
| **No document-level summary embedding** | MEDIUM | No summary-level index for cross-document queries |

### 3.2 Graph / Linkage Gaps 🔴

| Gap | Severity |
|-----|----------|
| No `prev_chunk_id` / `next_chunk_id` | HIGH |
| No `section_type` taxonomy | HIGH |
| No clause dependency graph | HIGH |
| No cross-document entity linking | MEDIUM |

---

## 4. Current Architecture Flow

```
User Query
    │
    ▼
query_rag()
    ├── Cache check (Redis)
    ├── _classify_query() → [exact_lookup | multi_step | broad | single_step]
    ├── _generate_query_variants() → RAG Fusion (2 variants)
    ├── _generate_hyde_query() → HyDE embedding
    │
    ├── [dense] OpenAI → Qdrant/pgvector
    ├── [sparse] _query_hybrid_index() → SQLite FTS5 ← BROKEN in Supabase path
    ├── RAG Fusion variant searches
    ├── _merge_hybrid_results() → RRF
    │
    ├── _rank_results() → CrossEncoder or lexical fallback
    ├── _evaluate_retrieval_quality() → gate
    │
    ├── llm.generate_structured(RAGAnswer)
    │    ← citations NOT verified post-generation  ← GAP
    │
    └── Response
         ← page_artifact_id not included  ← GAP
         ← source_text not included  ← GAP

Parallel: Evidence Pipeline
    OCR → page_artifact_id_map → EvidencePipeline → Substrate

Citation Verifier (exists, NEVER called from query path)
    verify_citation(): 6-check contract
```

---

## 5. Desired End-State

| Dimension | Current | Target |
|-----------|---------|--------|
| Searchability | Dense + BM25 (Qdrant only) | Dense + BM25 + pg_trgm + tsvector (both backends) |
| Grounding | Verifier exists, not wired | Every citation substring-checked before response |
| Traceability | No query trace | Full per-query trace with scores and check outcomes |
| Graph linkage | None | Chunk adjacency + section taxonomy + `chunk_links` table |
| Multi-granularity | Flat 2000-char | Sentence + paragraph + section + document embeddings |
| Evaluation | 22 fixture questions | 100+ grounded pairs, RAGAS CI gate |
| Contextual retrieval | Disabled | Re-enabled after backfill and eval gate |
| Span-level highlights | Not in response | bbox returned per citation |
| source_text | Not in response | Returned alongside retrieval_text for citation validation |

---

## 6. Implementation Commits

See [`ADR-2026-07-20-26-rag-pipeline-excellence.md`](../decisions/ADR-2026-07-20-26-rag-pipeline-excellence.md) for rationale.

| Commit | Scope | Risk |
|--------|-------|------|
| 1 | Wire citation verifier + add source_text/page_artifact_id to response | Low — no new infra |
| 2 | Supabase FTS: pg_trgm + tsvector + RPC + unified hybrid dispatch | Medium — DB migration |
| 3 | chunk_links table + section_type + context expansion in query | Medium — ingestion change |
| 4 | Multi-granularity embeddings: sentence + paragraph + section + doc | High — ingestion restructure |
| 5 | Real eval corpus (100+ Q&A) + RAGAS CI gate + per-query trace | Medium — data + CI |
| 6 | Contextual retrieval re-enable: feature flag + backfill + eval gate | High — gated on Commit 5 eval |

---

## 7. Anything Else? (motto_v4 §0.1.1 required prompt)

- **LLM room-rent extractor calls wrong contract** (audit item #12 of Top 20): calls `llm.complete()` instead of `generate_structured`. This is a separate fix from the RAG pipeline improvements but should be addressed in the same pass — it's the only LLM extractor and it's breaking structured output validation.
- **Embedding fallback unsafe (P0-16)**: `recreate_collection` at runtime on dimension change. Must be fixed in Commit 4 when multi-granularity embeddings are added, before adding more embedding configs.
- **Eval corpus is a data asset** (motto_v4 §0.8): must be versioned, in `docs/eval/corpus/`, not a throwaway script.
- **Citation verifier strictness**: exact-match as pass, fuzzy (≥70% token overlap) as warning state in UI, fail = citation stripped. This is the right trust boundary for an insurance product. Baked into Commit 1.
