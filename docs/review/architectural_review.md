# Architectural Review — Insurance App

> Date: 2026-07-09
> Scope: RAG pipeline, evaluation, model calls, extraction, overall architecture

---

## 1. RAG Pipeline (`src/rag/pipeline.py`)

### 1.1 Embedding Dimensions Baked at Init

`pipeline.py:71-77` — Dimensions for OpenAI and HF embedding models are computed in `__init__` and baked into `self.embedding_dimensions`. If the Qdrant collection already exists with 1536d vectors and you switch models (e.g., to `text-embedding-3-small` with 512d), `_ensure_collection_exists` returns early on `get_collection` success — no dimension mismatch detection. At query time, this produces a silent vector dimension error from Qdrant.

**Fix**: Add runtime dimension validation before search; detect mismatch and either recreate collection or raise clear error.

### 1.2 Hugging Face Fallback Is Dead Code

`pipeline.py:255-271` — `_generate_embeddings_with_fallback` only calls OpenAI. The HF client (`pipeline.py:58-66`) is initialized but never used. This inflates `__init__` complexity (~30 lines for setup + error handling that never runs). The method name is misleading.

**Fix**: Remove HF code entirely, or implement actual fallback with automatic failover.

### 1.3 Blocking OpenAI Calls

`pipeline.py:231` — `self.openai_client.embeddings.create()` is synchronous, called from an `async` method. The event loop blocks during embedding generation (typically 0.5-3s). Under concurrent requests, this serializes all embedding work.

**Fix**: Use `openai.AsyncOpenAI` or wrap in `asyncio.to_thread`.

### 1.4 No Structured Output

`pipeline.py:416-424` — Chat completion uses raw `messages` with a plain-text system prompt. No response_format, no response model (Pydantic). The answer is unstructured text. Downstream consumers can't reliably parse structured fields from it.

**Fix**: Use `response_format=ResponseModel(...)` with Pydantic to get typed JSON responses.

### 1.5 No Hybrid Search

`pipeline.py:374-383` — Only dense vector search (COSINE distance). Qdrant supports hybrid (dense + sparse/BM25) natively, which significantly improves precision for exact-match queries like policy numbers, names, and IDs common in insurance documents.

**Fix**: Enable Qdrant's hybrid search with sparse vectors.

### 1.6 No Reranking

Top-K results are directly fed to the LLM with no cross-encoder reranking. Relevance depends entirely on cosine similarity from the embedding model.

**Fix**: Add a cross-encoder reranker (e.g., `BAAI/bge-reranker-v2-m3`) between retrieval and generation.

### 1.7 Weak System Prompt

`pipeline.py:412` — Single-sentence prompt with no citation instruction, no confidence threshold, no "I don't know" guardrail, and no output format specification.

**Fix**: Strengthen prompt with citation requirements, explicit refusal language, and confidence levels.

### 1.8 No Chat Completion Retries

`pipeline.py:416` — Unlike embeddings (which have retry logic in `_generate_openai_embeddings`), the chat completion call has zero retry handling. A transient API error fails the entire query.

**Fix**: Add retry wrapper with exponential backoff to the chat completion call.

---

## 2. Evaluation Infrastructure — Missing

**There is no evaluation infrastructure** in the entire codebase.

- No eval harness, test set, or benchmark
- No groundedness / relevance / hallucination scoring
- No prompt versioning or A/B testing
- No answer quality regression tests
- No chunking strategy experiments
- No embedding model comparison

### Existing Tests

| File | Type | What It Covers |
|------|------|----------------|
| `tests/test_frontend.py` | Unit (mocked) | 4 tests — HTTP status codes and JSON shape only |
| `tests/test_azure_api.py` | Integration (live) | 6 tests — health, upload, query, error handling |

Tests verify connectivity and shape, never answer quality. No fixtures for known-answer testing.

**Fix**: Build minimal eval set (20-30 insurance Q&A pairs with ground truth). Add answer scoring (ROUGE, BERTScore, LLM-as-judge). Parameterize chunk size, overlap, top_k, embedding model for experimentation.

---

## 3. Model Calls

### 3.1 No Unified LLM Client

Every OpenAI call is ad-hoc. No shared wrapper for retry, cost tracking, token counting, or structured output.

### 3.2 No Token or Cost Tracking

Zero observability into per-query token usage or cost. `tiktoken` is not used despite being a free dependency.

### 3.3 No Chat Model Fallback

If `gpt-4.1-nano` returns a 429 or 500, the query fails immediately. No fallback chain to a cheaper/slower model.

### 3.4 Embedding Model Choice

Uses `text-embedding-ada-002` (1536d, $0.13/1M tokens). `text-embedding-3-small` (512-1536d, $0.02/1M tokens) is cheaper and generally better quality. The config file defaults to a different model than what's actually used at runtime.

### Summary of Model Call Issues

| Issue | Severity |
|-------|----------|
| No unified client/wrapper | Medium |
| No retry on chat completions | Medium |
| No token/cost tracking | Medium |
| No chat model fallback | Low |
| Blocking sync calls | Medium |

---

## 4. Extraction / OCR Pipeline (`src/ocr/pipeline.py`)

### 4.1 DocQA Completely Disabled

`pipeline.py:185-188` — `_get_layout_elements_for_image` returns `[]` immediately. The layout questions defined in `ocr/service.py:140-148` (policy holder, policy number, provider, effective date, expiration date, premium, coverage type) are never answered.

The system relies entirely on full-text search + LLM generation for field extraction. No structured data is extracted at ingest time.

### 4.2 No Document-Type-Specific Extraction

The same set of generic questions is sent for every document type. A health insurance policy and an auto policy need different fields extracted. This isn't supported.

### 4.3 Blocking OCR

`doctr_ocr_predictor` (`pipeline.py:68-74`) runs synchronous PyTorch inference. Large documents block the event loop during OCR processing.

### 4.4 Redundant PDF Processing

`_process_pdf` always extracts direct text AND renders page images (for OCR fallback) on every page, even when direct text extraction produces clean results. Wasted compute.

---

## 5. Document Processing Service — Split Brain (`src/services/document_processing_service.py`)

### 5.1 Two Parallel Processing Paths

1. **In-process path**: `DocumentProcessingService` calls `RAGPipeline.ingest_document_data()` directly
2. **HTTP path**: `src/ocr/service.py` POSTs to `rag_service:8000/ingest`

Both exist and handle the same flow differently. Deployment-dependent behavior.

### 5.2 Processing Status In-Memory Only

`self.processing_status` is a Python dict — lost on restart. No persistence for long-running jobs.

### 5.3 Naive Text Chunking

`document_processing_service.py:227-248` — Splits on `. ` with a 1000-char max. No overlap, no semantic boundary detection, no paragraph awareness. Compare with `RAGConfig.chunk_overlap=50` which isn't used.

---

## 6. Configuration — Dead Code (`src/rag/config.py`)

`RAGConfig` dataclass is entirely unused by the runtime pipeline:

| Setting | `config.py` | `pipeline.py` default | Actual (from env) |
|---------|-------------|----------------------|-------------------|
| Embedding model | `intfloat/e5-large-v2` | `sentence-transformers/all-mpnet-base-v2` | `text-embedding-ada-002` |
| LLM model | `mistralai/Mixtral-8x7B-v0.1` | `gpt-3.5-turbo` | `gpt-4.1-nano` |
| Chunk size | 500 | 2000 (hardcoded) | N/A |
| Collection name | `insurance_policies` | `insurance_documents_v2` | `insurance_documents_v2` |

Three layers of defaults, none matching the one actually used. Config has no integration with the code that needs it.

**Fix**: Use `pydantic-settings` `BaseSettings` as the single source of truth.

---

## 7. Architecture — Microservice vs Monolith Drift

`docker-compose.yml` defines 4 services: qdrant, redis, ocr_service, rag_service, frontend.

The production `Dockerfile` + `src/app/main.py` bundles everything into a single service.

The single-service path uses an entirely different code path than the microservice path. API routes are duplicated:
- `src/app/main.py:199` — root `/query` POST
- `src/api/document.py:375` — `/documents/query` POST

---

## 8. Anti-Abuse System (`src/utils/anti_abuse.py`)

Well-designed multi-layer protection with IP-based rate limiting, session-based rate limiting, document hash deduplication, disposable email detection, and email format validation. Redis-backed with in-memory fallback and SQLite persistence. This is the strongest subsystem in the codebase.

**Minor issue**: Redis fallback to in-memory dict is race-condition-prone under concurrent requests.

---

## Priority Summary

| Priority | Issue | Area |
|----------|-------|------|
| P0 | DocQA disabled — no structured field extraction at ingest | OCR |
| P0 | No eval infrastructure — can't measure answer quality | Eval |
| P1 | Dual deployment paths with divergent behavior | Architecture |
| P1 | Sync OpenAI calls blocking event loop | RAG/Model |
| P1 | No hybrid search — exact matches miss | RAG |
| P1 | No structured output — unstructured LLM responses | RAG/Model |
| P2 | Dead code (HF fallback, RAGConfig, DocQA stub) | Cross-cutting |
| P2 | No retry on chat completions | Model |
| P2 | Three layers of config defaults, none matching | Config |
| P2 | Naive chunking — no overlap, no semantics | Processing |
| P2 | In-memory-only processing status | Processing |
| P3 | No token/cost tracking | Model |
| P3 | No cross-encoder reranking | RAG |
