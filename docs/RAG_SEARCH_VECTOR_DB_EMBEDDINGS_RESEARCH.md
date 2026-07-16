# CoverWise — RAG, Search, Vector DB & Embeddings Research

**Date:** 2026-07-16
**Purpose:** Comprehensive reference for RAG/search/vector DB/embeddings — methods, models, architectures, and what applies to CoverWise
**Evidence Tier:** Tier 1 (codebase inspection) + Tier 2 (web research)
**Author:** Buffy (AI Agent)

---

## 0. What CoverWise Currently Implements

Before diving into the landscape, here's what our codebase already has (from `src/rag/pipeline.py`):

| Component | Current Implementation | Status |
|---|---|---|
| **Embedding Models** | OpenAI text-embedding-3-small (1536d), fallback to Ollama, fallback to local sentence-transformers | ✅ Production |
| **Vector Backend** | Qdrant (dev) / Supabase pgvector (prod) | ✅ Production |
| **Hybrid Search** | Dense vectors + SQLite FTS5 (BM25) via Reciprocal Rank Fusion | ✅ Production |
| **Query Classification** | Adaptive RAG: exact_lookup, multi_step, broad, single_step | ✅ Production |
| **HyDE** | Hypothetical Document Embeddings for query expansion | ✅ Production |
| **RAG Fusion** | Multi-query variant generation for broader retrieval | ✅ Production |
| **Contextual Retrieval** | LLM-generated context prepended to chunks (Anthropic technique) | ✅ Production |
| **Cross-Encoder Reranking** | cross-encoder/ms-marco-MiniLM-L-6-v2 | ✅ Production |
| **Retrieval Quality Evaluator** | Prevents hallucination when retrieval quality is too low | ✅ Production |
| **Redis Caching** | Query result caching with version-based invalidation | ✅ Production |
| **Structured Output** | Pydantic models (RAGAnswer, RAGCitation) via LLM | ✅ Production |
| **Multi-view Indexing** | Entity chunks for exact-match retrieval | ✅ Production |
| **Embedding Fallback Chain** | OpenAI → Ollama → local sentence-transformers | ✅ Production |
| **Owner-scoped Retrieval** | Supabase RLS + owner_id filter | ✅ Production |

**CoverWise already implements most of the state-of-the-art RAG techniques.** The pipeline is production-grade with 7 advanced techniques active simultaneously.

---

## 1. Advanced RAG Architectures (2024–2026)

### 1.1 Architecture Evolution

| Architecture | Description | CoverWise Status |
|---|---|---|
| **Naive RAG** | Simple vector search + LLM | ❌ We've moved past this |
| **Advanced RAG** | Layer-by-layer improvements (hybrid, reranking, query transforms) | ✅ **We are here** |
| **Modular RAG** | Decoupled components for independent testing/upgrades | ✅ Our pipeline is modular |
| **Graph RAG** | Knowledge graphs + vector search for complex reasoning | 🔲 Future enhancement |
| **Agentic RAG** | Agents decide when/how to retrieve, self-correct | 🔲 Future enhancement |

### 1.2 What Advanced RAG Adds Over Naive

| Technique | What It Solves | CoverWise Implementation |
|---|---|---|
| Hybrid search | Pure semantic misses exact keywords/IDs | ✅ Dense + FTS5 BM25 |
| Reranking | Initial retrieval is noisy | ✅ Cross-encoder reranker |
| Query transformation | User queries don't match document vocabulary | ✅ HyDE + RAG Fusion |
| Retrieval quality gating | Hallucination when nothing relevant is found | ✅ `_evaluate_retrieval_quality()` |
| Contextual retrieval | Chunks lose document context | ✅ `_contextualize_chunks()` |

---

## 2. Embedding Models — Comprehensive Comparison

### 2.1 OpenAI Models

| Model | Dimensions | MTEB Score | Cost (per 1M tokens) | Notes |
|---|---|---|---|---|
| `text-embedding-3-small` | 1536 (Matryoshka: down to 256) | ~62.3 | $0.02 | **Current CoverWise default.** Best cost/performance ratio. |
| `text-embedding-3-large` | 3072 (Matryoshka: down to 256) | ~64.6 | $0.13 | Highest accuracy, 5x more expensive |
| `text-embedding-ada-002` | 1536 | ~61.0 | $0.10 | Legacy, outperformed by v3 models |

**Key innovation:** Matryoshka Representation Learning — can truncate dimensions without retraining. A 256d vector from text-embedding-3-small still performs well.

### 2.2 Open-Source Models (MTEB Leaders)

| Model | Dimensions | MTEB Rank | Best For | CoverWise Status |
|---|---|---|---|---|
| `BAAI/bge-m3` | 1024 | Top 5 | Multilingual, multi-function | ✅ Available via Ollama |
| `intfloat/e5-large-v2` | 1024 | Top 10 | English, high accuracy | ✅ Available via sentence-transformers |
| `sentence-transformers/all-mpnet-base-v2` | 768 | Top 15 | General purpose | ✅ Available via sentence-transformers |
| `nomic-embed-text` | 768 | Top 20 | Edge/local deployment | ✅ Available via Ollama |
| `mxbai-embed-large` | 1024 | Top 15 | Performance/size ratio | ✅ Available via Ollama |
| `NV-embed-v2` | 4096 | #1 MTEB | Maximum accuracy | 🔲 Future consideration |

### 2.3 Late-Interaction Models (ColBERT)

| Model | Approach | Advantage | CoverWise Status |
|---|---|---|---|
| `ColBERTv2` | Token-level embeddings + MaxSim | Higher precision than bi-encoders | 🔲 Future consideration |
| `ColPali` | Vision + late-interaction | PDF-as-image understanding | 🔲 Future consideration |

**How ColBERT works:** Instead of compressing a document into one vector, it keeps token-level embeddings. At query time, it computes MaxSim between query tokens and document tokens — much more precise than single-vector cosine similarity.

### 2.4 Embedding Best Practices

| Practice | Recommendation | CoverWise Status |
|---|---|---|
| **Dimension selection** | Use Matryoshka models to dynamically scale | ✅ We support multiple dims |
| **Normalization** | Always normalize to unit length for cosine similarity | ✅ Qdrant uses COSINE distance |
| **Batching** | Batch embedding requests for throughput | ✅ We batch in `ingest_document_data()` |
| **Caching** | Cache embeddings for repeated content | 🔲 Could add embedding cache |
| **Hybrid search** | Dense + sparse for best recall | ✅ We do this |

---

## 3. Vector Databases — Comprehensive Comparison

### 3.1 Database Comparison

| Database | Type | Best For | Latency | CoverWise Status |
|---|---|---|---|---|
| **Qdrant** | Self-hosted/Cloud | Advanced filtering, cost-effective | ~10ms | ✅ **Dev backend** |
| **Supabase pgvector** | PostgreSQL extension | Teams already on Postgres | ~15ms | ✅ **Prod backend** |
| **Pinecone** | Managed cloud | Easy setup, serverless | ~20ms | 🔲 Alternative |
| **Weaviate** | Self-hosted/Cloud | Rich ecosystem, ColBERT support | ~12ms | 🔲 Alternative |
| **Milvus/Zilliz** | Self-hosted/Cloud | Massive scale, enterprise | ~8ms | 🔲 Alternative |
| **Chroma** | Local/Embedded | Prototyping, simplicity | ~5ms | 🔲 Local dev |
| **FAISS** | Library (not DB) | Raw speed, clustering | ~2ms | 🔲 Internal use |

### 3.2 pgvector (Supabase) — Our Production Choice

**Why pgvector works for CoverWise:**
- No separate infrastructure — vector search lives alongside relational data
- Row Level Security (RLS) provides owner-scoped retrieval natively
- `match_document_chunks` RPC function handles similarity search
- Index types: IVFFlat (small datasets) or HNSW (large datasets)
- Supports hybrid queries (vector + SQL filters in one query)

**pgvector limitations:**
- Slower than dedicated vector DBs at scale (>1M vectors)
- Limited advanced filtering compared to Qdrant
- No native multi-tenancy (we handle via owner_id filter)

### 3.3 Qdrant — Our Dev Backend

**Why Qdrant works for CoverWise:**
- Written in Rust — very fast
- Advanced filtering (nested conditions, range queries)
- Collection recreation when embedding dimensions change
- In-memory fallback when server is unavailable
- Good for local development and testing

---

## 4. Retrieval Strategies — Deep Dive

### 4.1 Hybrid Search (Dense + Sparse)

**Why hybrid outperforms pure semantic:**
- Dense (embeddings) captures conceptual meaning
- Sparse (BM25/FTS5) captures exact keywords, IDs, acronyms
- Insurance queries often mix both: "What's my policy number for health insurance with Star Health?"

**CoverWise implementation:**
- Dense: Qdrant/Supabase vector search
- Sparse: SQLite FTS5 with BM25 ranking
- Fusion: Reciprocal Rank Fusion (k=20, tuned for small corpus)

### 4.2 Reciprocal Rank Fusion (RRF)

```
RRF_score(d) = Σ 1/(k + rank_i(d))  for each retrieval method i
```

- k=60 is standard for large corpora
- k=20 is what we use (tuned for <200 documents)
- Rank-based, not score-based — more robust than score interpolation
- Prevents one strong method from dominating

### 4.3 Contextual Retrieval (Anthropic Technique)

**What it does:** Prepends LLM-generated context to each chunk before embedding.

**Example:**
- Original chunk: "The deductible is ₹10,000 per claim"
- Contextualized: "This is from a health insurance policy by Star Health. The deductible is ₹10,000 per claim"

**Impact:** 35% reduction in retrieval failures (Anthropic's published results)

**CoverWise implementation:** `_contextualize_chunks()` method — generates 1-2 sentence context per chunk using LLM

### 4.4 Adaptive RAG (Query Classification)

**CoverWise query types:**

| Type | Trigger | Strategy |
|---|---|---|
| `exact_lookup` | Policy numbers, IDs, specific names | FTS only, no embedding (faster) |
| `multi_step` | Compare, versus, difference, across all | Multiple queries + merge |
| `broad` | Summarize, overview, list all | Wider retrieval |
| `single_step` | Default semantic queries | Standard dense + sparse |

### 4.5 HyDE (Hypothetical Document Embeddings)

**How it works:**
1. User asks: "What's the waiting period for pre-existing diseases?"
2. LLM generates hypothetical answer: "The waiting period for pre-existing diseases is 24 months from the policy start date..."
3. The hypothetical answer is embedded and used for search
4. Retrieved documents are more semantically aligned with the answer than the question

**Why it works:** Closes the vocabulary gap between short user queries and long insurance documents.

### 4.6 RAG Fusion (Multi-Query)

**How it works:**
1. User asks: "What's covered under my health policy?"
2. LLM generates 2 variants:
   - "What medical treatments and procedures are included in the health insurance coverage?"
   - "List all covered benefits and inclusions for the health insurance plan"
3. Each variant is embedded and searched independently
4. Results merged via RRF

**Impact:** Broader retrieval coverage, captures different facets of the same question.

---

## 5. Re-ranking Methods

### 5.1 Cross-Encoder vs Bi-Encoder

| Aspect | Bi-Encoder (Retrieval) | Cross-Encoder (Reranking) |
|---|---|---|
| **Speed** | Fast (sub-ms per query) | Slow (10-100ms per pair) |
| **Accuracy** | Good for broad retrieval | Excellent for precision |
| **Use case** | Retrieve top 50-100 candidates | Select final top 3-5 |
| **CoverWise** | ✅ OpenAI/HF embeddings | ✅ ms-marco-MiniLM-L-6-v2 |

### 5.2 Cross-Encoder Reranking in CoverWise

**Model:** `cross-encoder/ms-marco-MiniLM-L-6-v2`
- 6-layer MiniLM architecture
- Trained on MS MARCO passage ranking dataset
- Computes query-document relevance score jointly
- Falls back to lexical scoring if unavailable

### 5.3 ColBERT (Late-Interaction) — Future Consideration

- Token-level embeddings instead of single vector
- MaxSim between query tokens and document tokens
- Higher precision than bi-encoders, faster than cross-encoders
- ColBERTv2 uses residual compression (6-10x storage reduction)
- Could improve retrieval precision for complex insurance queries

---

## 6. Chunking Strategies

### 6.1 Strategy Comparison

| Strategy | Description | Best For | CoverWise Status |
|---|---|---|---|
| **Fixed-size** | Split by character/token count | Simple documents | ✅ Used in OCR pipeline |
| **Recursive** | Split by hierarchy (paragraphs → sentences → words) | Structured documents | ✅ Available |
| **Semantic** | Merge conceptually similar sentences | Complex documents | 🔲 Future |
| **Agentic/Adaptive** | LLM determines chunk boundaries | Dense, structured docs | ✅ Via contextual retrieval |

### 6.2 Insurance-Specific Chunking

Insurance documents have unique structures:
- Policy schedules (tables with coverage amounts)
- Exclusions lists (bullet points)
- Terms and conditions (dense legal text)
- Claim forms (structured fields)

**Recommendation:** Table-aware chunking that preserves tabular structure as Markdown or JSON before embedding.

---

## 7. Evaluation Frameworks

### 7.1 Framework Comparison

| Framework | Focus | Best For | CoverWise Status |
|---|---|---|---|
| **RAGAS** | Reference-free metrics | Rapid prototyping | ✅ `src/eval/ragas_eval.py` |
| **DeepEval** | CI/CD gates | Production regression testing | 🔲 Future |
| **TruLens** | Observability | Production debugging | 🔲 Future |
| **Custom eval** | Domain-specific | Insurance accuracy | ✅ `src/eval/runner.py` |

### 7.2 Core RAG Metrics

| Metric | What It Measures | Target |
|---|---|---|
| **Faithfulness** | Is the answer grounded in retrieved context? | >0.8 |
| **Answer Relevance** | Does the answer address the query? | >0.7 |
| **Context Precision** | Are retrieved chunks relevant? | >0.6 |
| **Context Recall** | Does context contain all needed info? | >0.7 |

### 7.3 CoverWise Evaluation

Our `src/eval/runner.py` evaluates:
- Answer correctness (substring matching against expected)
- Citation accuracy (correct source indices)
- Retrieval quality (does the retriever find the right chunks?)

**Gap:** We don't yet have automated RAGAS scoring in CI — only manual eval.

---

## 8. Production Best Practices

### 8.1 Cost Optimization

| Technique | Description | CoverWise Status |
|---|---|---|
| **Embedding caching** | Cache embeddings for repeated content | 🔲 Could add |
| **Query result caching** | Redis TTL-based caching | ✅ Implemented |
| **Model routing** | Cheap models for simple queries | ✅ Fallback chain |
| **Prompt compression** | Summarize chunks before LLM | 🔲 Future |
| **Dimension reduction** | Use smaller vectors for faster search | ✅ Matryoshka support |

### 8.2 Failure Modes & Mitigations

| Failure Mode | Description | CoverWise Mitigation |
|---|---|---|
| **Retrieval drift** | Index becomes outdated | ✅ Cache version bumping on ingest |
| **Hallucination** | LLM makes up facts | ✅ Retrieval quality evaluator |
| **Context noise** | Too many irrelevant chunks | ✅ Cross-encoder reranking |
| **Chunking failures** | Chunks lose context | ✅ Contextual retrieval |
| **Embedding failure** | API quota/errors | ✅ 3-level fallback chain |

### 8.3 Monitoring

| What to Monitor | How | CoverWise Status |
|---|---|---|
| Retrieval latency | Per-query timing | 🔲 Could add |
| Embedding failures | Counter per backend | ✅ `openai_failure_count` |
| Cache hit rate | Redis stats | 🔲 Could add |
| Answer quality | User feedback (thumbs up/down) | ✅ Feedback mechanism |
| Cost per query | LLM cost tracking | ✅ `get_cost_summary()` |

---

## 9. Emerging Innovations (2025–2026)

### 9.1 Graph RAG

**What:** Knowledge graphs + vector search for complex reasoning.

**Why it matters for insurance:**
- Multi-hop reasoning: Customer → Policy → Coverage → Claim → Event
- Entity relationships: "Which policies cover the same hospital network?"
- Regulatory compliance: Linking policy clauses to regulatory requirements

**CoverWise applicability:** HIGH — insurance is inherently relational. A knowledge graph of policies, insurers, coverage types, and family members would enable queries like "Which of my family members are covered for dental?"

**Implementation path:**
1. Start with entity extraction from policy summaries
2. Build a lightweight knowledge graph (Neo4j or in-memory)
3. Combine with existing vector search via hybrid routing

### 9.2 Agentic RAG

**What:** Agents that decide when/how to retrieve, self-correct, and loop.

**Example flow:**
1. Agent receives: "Compare my health and motor policy coverage"
2. Agent decides: This needs multi-step retrieval
3. Agent retrieves health policy chunks
4. Agent retrieves motor policy chunks
5. Agent cross-references and synthesizes
6. Agent validates answer against source documents

**CoverWise applicability:** MEDIUM — our Adaptive RAG already does query classification. Full agentic RAG would be valuable for cross-document Q&A (B5 from brainstorm).

### 9.3 Multi-Modal RAG

**What:** Text + images + tables + audio in retrieval.

**Why it matters for insurance:**
- Policy schedules are often tables (not plain text)
- Claim forms have structured fields
- Medical reports include images/charts

**CoverWise applicability:** MEDIUM — our OCR already extracts text from PDFs/images. Table-aware chunking would be the first step.

### 9.4 Long-Context LLMs vs RAG

| Factor | Long-Context LLM | RAG |
|---|---|---|
| **Best for** | Static, small document sets | Dynamic, massive datasets |
| **Cost** | Expensive (all tokens billed) | Cheaper (only relevant chunks) |
| **Auditability** | Hard to trace sources | Easy (source citations) |
| **Freshness** | Requires re-processing | Real-time via index updates |
| **CoverWise** | Not suitable (dynamic policies) | ✅ Our chosen approach |

**Emerging pattern:** Hybrid — RAG retrieves relevant snippets, long-context model synthesizes.

### 9.5 RAG Security

| Threat | Mitigation | CoverWise Status |
|---|---|---|
| Prompt injection via documents | Input sanitization, guardrails | 🔲 Future |
| Data leakage across users | Owner-scoped retrieval (RLS) | ✅ Implemented |
| Unauthorized access | RBAC at retrieval level | ✅ Owner-scoped |
| Malicious document ingestion | Validation, sanitization | ✅ Upload validation |

---

## 10. Recommendations for CoverWise

### 10.1 What to Keep (Already Excellent)

| Technique | Why Keep |
|---|---|
| Hybrid search (dense + FTS5) | Best of both worlds for insurance queries |
| Cross-encoder reranking | Significant precision improvement |
| Contextual retrieval | 35% retrieval improvement |
| HyDE | Bridges query-document vocabulary gap |
| RAG Fusion | Broader retrieval coverage |
| Adaptive RAG query classification | Routes queries to optimal strategy |
| Retrieval quality evaluator | Prevents hallucination |
| Redis caching | Reduces latency and cost |
| Embedding fallback chain | Resilience against API failures |

### 10.2 What to Add Next (High Impact)

| Enhancement | Effort | Impact | Priority |
|---|---|---|---|
| **Embedding cache** | Small | Medium | P2 — avoid re-embedding unchanged text |
| **Table-aware chunking** | Medium | High | P2 — insurance docs are table-heavy |
| **RAGAS in CI** | Small | Medium | P2 — automated quality gates |
| **ColBERT reranking** | Medium | Medium | P3 — better precision than cross-encoder |
| **Semantic caching** | Medium | High | P3 — cache similar queries |
| **Streaming responses** | Medium | Medium | P3 — better perceived latency |

### 10.3 What to Explore Long-Term

| Enhancement | Effort | Impact | When |
|---|---|---|---|
| **Graph RAG** | Large | Very High | Post-MVP — enables complex cross-policy reasoning |
| **Agentic RAG** | Large | High | Post-MVP — for cross-document Q&A (B5) |
| **Multi-modal RAG** | Large | Medium | Post-launch — table/chart understanding |
| **Knowledge graph of policies** | Medium | High | Post-launch — family coverage mapping |

---

## 11. Decision Record

| Decision | Date | Context | Rationale |
|---|---|---|---|
| Use pgvector (Supabase) for production | 2026-07-16 | Need vector search alongside relational data | No separate infrastructure, RLS for owner scoping |
| Use Qdrant for development | 2026-07-16 | Need fast local vector search | Fast, advanced filtering, in-memory fallback |
| Implement hybrid search (dense + BM25) | 2026-07-16 | Insurance queries mix semantic and exact | Best recall for policy numbers + concepts |
| Use RRF for fusion (k=20) | 2026-07-16 | Small corpus (<200 docs) | Standard k=60 is for large corpora |
| Implement contextual retrieval | 2026-07-16 | Chunks lose document context | 35% retrieval improvement (Anthropic research) |
| Use cross-encoder for reranking | 2026-07-16 | Need precision after broad retrieval | Gold standard for accuracy |
| Implement HyDE | 2026-07-16 | Short queries vs long documents | Bridges vocabulary gap |
| Defer Graph RAG to post-MVP | 2026-07-16 | High effort, high impact | Not blocking for solo launch |
| Defer ColBERT to post-launch | 2026-07-16 | Medium effort, medium impact | Cross-encoder is sufficient for now |

---

## 12. Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-07-16 | Initial comprehensive research document created | Buffy |
