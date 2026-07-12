# Advanced RAG Methods Research

**Date:** 2026-07-11
**Scope:** Comprehensive research on advanced RAG techniques, retrieval strategies, chunking approaches, and architectural patterns. Evaluated against CoverWise's current pipeline and long-term product direction.

---

## 1. CoverWise Current RAG Architecture

```
Document → OCR (PyMuPDF/doctr) → Structure-aware chunking → Embed (OpenAI/Ollama/local) 
  → Qdrant upsert + SQLite FTS5 index → Query: embed query → Qdrant dense search + FTS5 
  → Hybrid merge (0.7 dense + 0.3 FTS) → Rerank (lexical + exact match) → LLM answer
```

**Current state assessment:**
- Already has hybrid retrieval (dense + FTS) — better than naive RAG
- Has reranking (lexical overlap + exact match boost) — not cross-encoder
- Has structure-aware chunking (section headers, paragraphs) — better than fixed-size
- Has cache (Redis, versioned) — good
- Has embedding fallback (3-tier) — resilient
- Has LLM fallback (3-tier) — resilient
- Missing: contextual retrieval, HyDE, cross-encoder reranking, query routing, self-reflection, GraphRAG

---

## 2. Advanced RAG Techniques (12 Patterns)

### Comparison Matrix

| Technique | What It Does | Accuracy Gain | Complexity | Relevant to CoverWise? |
|-----------|-------------|---------------|------------|------------------------|
| **Hybrid Retrieval** | Dense + sparse + RRF merge | Significant (de facto standard) | Medium | **Already implemented** (Qdrant + FTS5) |
| **Cross-Encoder Reranking** | Second-pass (query, doc) pair scoring | Consistent NDCG/MRR lift | Low-Medium | **Yes — highest ROI upgrade** |
| **Contextual Retrieval** | LLM-prepended chunk context | 67% fewer retrieval failures | Medium | **Yes — insurance docs lose context in chunks** |
| **HyDE** | Generate hypothetical answer, embed that | nDCG@10: 61.3 vs 44.5 baseline | Low-Medium | **Yes — short insurance queries benefit** |
| **Self-RAG** | LLM decides when to retrieve + self-critique | ICLR 2024 Oral, beats standard RAG | High | **No — requires fine-tuning, too complex for now** |
| **CRAG** | Evaluator grades retrieval, web fallback | Significant on 4 datasets | Medium | **Maybe — web fallback is risky for insurance** |
| **Adaptive RAG** | Classifier routes to no/single/multi retrieval | Efficiency + accuracy | Medium | **Yes — mixed query complexity (policy # vs coverage analysis)** |
| **GraphRAG** | Knowledge graph + community summaries | Substantial (Microsoft) | High | **No — overkill for 5 documents, expensive construction** |
| **RAPTOR** | Recursive tree of summaries | +20% on QuALITY | High | **Maybe — long insurance policies benefit from multi-level** |
| **RAG Fusion** | Multi-query + RRF | Broader coverage | Low-Medium | **Yes — insurance queries are ambiguous** |
| **Sentence Window** | Index small, retrieve surrounding window | #1 precision in ARAGOG | Low-Medium | **Yes — low complexity, high precision** |
| **Modular RAG** | Swappable pipeline modules | Architecture-level | Medium-High | **Already partially done** (modular services) |

---

## 3. Retrieval Methods Deep Dive

### 3.1 Dense Retrieval (Current: OpenAI text-embedding-3-small)
- **Strength:** Semantic similarity, paraphrasing, synonyms
- **Weakness:** Misses exact identifiers (policy numbers, error codes, insurer names)
- **CoverWise status:** Implemented with 3-tier fallback (OpenAI → Ollama → local sentence-transformers)

### 3.2 Sparse Retrieval (Current: SQLite FTS5)
- **Strength:** Exact term matching, high IDF for rare tokens (policy numbers!)
- **Weakness:** No semantic understanding, misses paraphrases
- **CoverWise status:** Implemented as SQLite FTS5 with BM25 scoring, fallback to LIKE

**BM25 vs SPLADE comparison:**

| Aspect | BM25 | SPLADE |
|--------|------|--------|
| Semantic awareness | None (pure keyword) | Learned (query expansion) |
| Latency | ~1-5ms (inverted index) | ~100-300ms (transformer inference) |
| Out-of-vocabulary handling | Excellent (exact match) | Poor (no learned expansion for new tokens) |
| Implementation | Trivial (rank_bm25, SQLite FTS5) | Medium (transformer model needed) |
| Best for | Small corpora, exact IDs, product codes | Large corpora, natural language, synonyms |

**Recommendation:** Keep BM25 (SQLite FTS5). For CoverWise's use case (5 documents, exact policy numbers, insurer names), BM25 is better than SPLADE. SPLADE's query expansion adds latency without meaningful benefit for a small corpus with precise identifiers.

### 3.3 ColBERT / Late Interaction
- **What:** Token-level matching with per-token embeddings + MaxSim scoring
- **Strength:** Finer-grained matching than dense embeddings, better than BM25 on semantics
- **Weakness:** Multi-vector storage (expensive), higher compute
- **CoverWise relevance:** Low — the corpus is too small to justify multi-vector overhead

### 3.4 Hybrid Search + RRF (Current implementation)

CoverWise already has hybrid search:
```
Qdrant dense search (limit = top_k * 3) + SQLite FTS5 search → 
  merge: dense_score * 0.7 + FTS_score * 0.3 → 
  rerank: lexical_overlap * 0.7 + exact_match * 0.2 + lexical * 0.1
```

**Assessment:** The merge weights (0.7/0.3) and reranking formula are custom. Standard RRF (`1/(k+rank)`, k=60) is more robust because it's rank-based, not score-based. For small corpora (<200 docs), k=10-20 is better.

**Recommendation:** Switch from score-based merge to RRF with k=20 (small corpus). This is a one-line change that improves robustness.

---

## 4. Chunking Strategies

### 4.1 Current State
CoverWise uses structure-aware chunking:
- Splits on section headers (COVERAGE, EXCLUSIONS, DEDUCTIBLE, etc.)
- Falls back to paragraph splitting
- Max block size: 1000 chars

### 4.2 Chunking Strategy Comparison

| Strategy | What It Does | Best For | Complexity |
|----------|-------------|----------|------------|
| **Fixed-size** | Split at N tokens | Simplicity, baseline | Trivial |
| **Recursive** | Split by hierarchy (paragraph → sentence → word) | General purpose | Low |
| **Structure-aware** (current) | Split on headers, sections | Documents with clear structure | Medium |
| **Semantic chunking** | Embed sentences, group by similarity | Preserves semantic coherence | Medium |
| **Agentic chunking** | LLM decides chunk boundaries | Complex documents | High |
| **Sentence window** | Index sentences, retrieve window | Precision retrieval + rich context | Low-Medium |
| **Parent-child** | Index small chunks, return parent | Precision + context | Low-Medium |
| **Contextual chunking** | LLM prepends context to each chunk | Chunks losing document context | Medium |

**Recommendation:** 
1. **Immediate:** Add **contextual retrieval** — prepend a 1-2 sentence LLM-generated context to each chunk before embedding. This is a one-time indexing cost with permanent accuracy gains. For insurance docs, chunks like "Section 3.2: Pre-existing Conditions" lose meaning when isolated. Contextual retrieval fixes this.
2. **Next:** Consider **sentence window** retrieval — index at sentence level for precise matching, but return the surrounding 3-5 sentences for generation. This was #1 in ARAGOG precision benchmarks.

---

## 5. Architectural RAG Patterns

### 5.1 Self-RAG
- LLM fine-tuned with reflection tokens: IsREL (relevance), IsSUP (supported), IsUSE (useful)
- On-demand retrieval (not always-on)
- **Verdict:** Too complex for CoverWise. Requires fine-tuning. The accuracy gain doesn't justify the engineering cost for a 5-document app.

### 5.2 CRAG (Corrective RAG)
- Evaluator grades retrieved docs → if low confidence, fall back to web search
- **Verdict:** Web search fallback is risky for insurance — web results may contain incorrect insurance advice. The retrieval evaluator itself is worth adding (grade retrieval quality before sending to LLM).

### 5.3 Adaptive RAG
- Small classifier routes queries: no retrieval / single-step / multi-step
- **Verdict:** Good fit. "What is my policy number?" needs single-step. "Compare my health and auto coverage gaps" needs multi-step. "What is insurance?" needs no retrieval. A simple keyword classifier would work for CoverWise's 21 standard questions.

### 5.4 GraphRAG
- Knowledge graph from documents, community detection, multi-hop traversal
- **Verdict:** Overkill. Building a knowledge graph from 5 insurance PDFs is expensive and unnecessary. The relationships are simple (person → policy → coverage → exclusion). A structured `PolicySummary` model captures this better.

### 5.5 RAPTOR
- Recursive clustering + abstractive summaries → tree of increasing abstraction
- **Verdict:** Interesting for long insurance policies (50+ pages). The tree structure would enable queries like "summarize all exclusions across all policies" at the high level, while still supporting "what's my deductible?" at the leaf level. Medium priority — only worth it if users upload very long policies.

### 5.6 RAG Fusion
- Generate multiple query variants, retrieve for each, merge with RRF
- **Verdict:** Easy win. Insurance queries are ambiguous — "What is my premium?" could mean health premium or auto premium. Multi-query expansion would retrieve from both. Low complexity, one extra LLM call.

### 5.7 Agentic RAG
- LLM as agent: decides what to retrieve, when, and how to use results
- **Verdict:** Future direction. The claims assistant feature already has a basic version of this (incident type → guide selection). Full agentic RAG (LLM decides retrieval strategy per query) is the long-term architecture but requires LangGraph-style orchestration.

---

## 6. Recommended Upgrade Path for CoverWise

### Priority-ordered implementation plan:

| # | Technique | Effort | Impact | When |
|---|-----------|--------|--------|------|
| 1 | **Switch merge to RRF (k=20)** | 1 hour | Robustness | Immediate |
| 2 | **Cross-encoder reranking** | 1 day | NDCG/MRR lift | Next sprint |
| 3 | **Contextual retrieval** | 2 days | 67% fewer retrieval failures | Next sprint |
| 4 | **HyDE** | 1 day | Better short queries | Next sprint |
| 5 | **RAG Fusion** (multi-query) | 1 day | Broader coverage | Next sprint |
| 6 | **Adaptive RAG** (query routing) | 2 days | Cost + latency optimization | Medium-term |
| 7 | **Sentence window retrieval** | 2 days | Precision improvement | Medium-term |
| 8 | **Retrieval evaluator** (from CRAG) | 1 day | Quality gate | Medium-term |
| 9 | **RAPTOR** (for long docs) | 1 week | Multi-level reasoning | Long-term |
| 10 | **Agentic RAG** | 2+ weeks | Full autonomy | Long-term |

### Concrete changes for items 1-5:

**1. RRF merge (immediate):**
```python
# Current: dense_score * 0.7 + fts_score * 0.3
# Change to: RRF with k=20 (small corpus)
def rrf_merge(dense_results, fts_results, k=20):
    scores = {}
    for rank, r in enumerate(dense_results, 1):
        scores[r.doc_id] = scores.get(r.doc_id, 0) + 1/(k + rank)
    for rank, r in enumerate(fts_results, 1):
        scores[r.doc_id] = scores.get(r.doc_id, 0) + 1/(k + rank)
    return sorted(scores.items(), key=lambda x: -x[1])
```

**2. Cross-encoder reranking:**
```python
from sentence_transformers import CrossEncoder
reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")
pairs = [(query, doc.text) for doc in merged_results[:top_k*3]]
scores = reranker.predict(pairs)
reranked = [doc for _, doc in sorted(zip(scores, merged_results), key=lambda x: -x[0])][:top_k]
```

**3. Contextual retrieval:**
```python
# At ingestion time (one-time cost per document):
for chunk in chunks:
    context = await llm.generate(
        f"Given this document about {filename}, provide a 1-2 sentence context "
        f"for this chunk: {chunk[:200]}..."
    )
    enriched_chunk = f"{context}\n\n{chunk}"
    # Embed and store enriched_chunk instead of chunk
```

**4. HyDE:**
```python
# Before retrieval:
hypothetical_doc = await llm.generate(
    f"Provide a brief answer to this insurance question: {query}"
)
query_embedding = embed(hypothetical_doc)  # embed the answer, not the question
```

**5. RAG Fusion:**
```python
# Generate query variants:
variants = await llm.generate(
    f"Generate 3 alternative phrasings of this insurance question: {query}"
)
# Retrieve for each variant, merge all results with RRF
all_results = []
for v in variants + [query]:
    all_results.append(dense_search(v))
    all_results.append(fts_search(v))
merged = rrf_merge(*all_results, k=20)
```

---

## 7. Sources

### Advanced RAG Techniques
- [12 Advanced RAG Techniques: Beyond Naive Retrieval](https://atlan.com/know/advanced-rag-techniques/) — comprehensive comparison with benchmarks
- [Self-RAG (arXiv:2310.11511)](https://arxiv.org/abs/2310.11511) — ICLR 2024 Oral
- [RAPTOR (arXiv:2401.18059)](https://arxiv.org/abs/2401.18059) — recursive tree indexing
- [HyDE (arXiv:2212.10496)](https://arxiv.org/abs/2212.10496) — hypothetical document embeddings
- [CRAG (arXiv:2401.15884)](https://arxiv.org/abs/2401.15884) — corrective RAG
- [Adaptive RAG (NAACL 2024)](https://arxiv.org/abs/2403.14401) — query routing
- [GraphRAG (Microsoft)](https://arxiv.org/abs/2404.16130) — knowledge graph RAG
- [Contextual Retrieval (Anthropic)](https://www.anthropic.com/news/contextual-retrieval) — 67% fewer retrieval failures
- [ARAGOG Benchmark](https://arxiv.org/abs/2407.13491) — advanced RAG output grading

### Retrieval Methods
- [Hybrid Search in RAG (GoPenAI)](https://blog.gopenai.com/hybrid-search-in-rag-dense-sparse-bm25-splade-reciprocal-rank-fusion-and-when-to-use-which-fafe4fd6156e) — BM25 vs SPLADE vs Dense, RRF implementation
- [Qdrant: Modern Sparse Neural Retrieval](https://qdrant.tech/articles/modern-sparse-neural-retrieval/) — SPLADE, COIL, TILDEv2
- [Weaviate: Late Interaction Overview](https://weaviate.io/blog/late-interaction-overview) — ColBERT, ColPali
- [Qdrant: Late Interaction Models](https://qdrant.tech/articles/late-interaction-models/) — multi-vector retrieval
- [Denser.ai: Hybrid Search for RAG](https://denser.ai/blog/hybrid-search-for-rag/) — BM25 + embeddings + RRF

### Chunking Strategies
- [Weaviate: Chunking Strategies for RAG](https://weaviate.io/blog/chunking-strategies-for-rag)
- [NVIDIA: Finding the Best Chunking Strategy](https://developer.nvidia.com/blog/finding-the-best-chunking-strategy-for-accurate-ai-responses/)
- [IBM: What Is Agentic Chunking?](https://www.ibm.com/think/topics/agentic-chunking)
- [Databricks: Mastering Chunking Strategies](https://community.databricks.com/t5/technical-blog/the-ultimate-guide-to-chunking-strategies-for-rag-applications/ba-p/113089)
- [PMC: Comparative Evaluation of Advanced Chunking](https://pmc.ncbi.nlm.nih.gov/articles/PMC12649634/)

---

## 8. Multi-View Indexing: Multiple Representations Per Document

### The Core Insight

A PDF is not "text." A PDF is a container with layout, visual hierarchy, tables, images, captions, headers, footers, page numbers, forms, signatures, stamps, charts, and sometimes scanned text. One chunking strategy cannot preserve all of that.

**The correct mental model:** treat a document as multiple retrievable views over the same source, not as one stream of text.

```
PDF
 ↓
Parsing layer (PyMuPDF / MinerU / Docling / doctr)
 ↓
Canonical document model (structured intermediate representation)
 ↓
Multiple derived representations:
  1. Section chunks (heading + text)
  2. Table chunks (headers + rows + text summary)
  3. OCR/image chunks (ocr_text + visual_description + bbox)
  4. Entity chunks (NER: names, dates, amounts, IDs)
  5. Layout chunks (header/footer/sidebar regions with bbox)
  6. Page-level chunks (full page text + summary)
  7. Structured records (extracted fields: policy_number, coverage, premium)
 ↓
Retrieval layer routes by query intent to the right view
 ↓
LLM synthesizes answer with citations
```

### Why This Matters for Insurance Documents

Insurance PDFs contain:
- **Headers:** Insurer name, policy number, dates
- **Tables:** Coverage limits, premium breakdowns, benefit schedules
- **Sections:** Exclusions, waiting periods, claim procedures
- **Images:** Signatures, stamps, QR codes, company logos
- **Layout:** Multi-column text, footnotes, page numbers

If you chunk this as plain text every 500 tokens, you destroy useful structure. Tables become unreadable strings. Entity values lose their context. Visual elements are invisible.

### Chunk Types and When to Use Them

| Chunk Type | What It Stores | Best For | Where It Breaks |
|-----------|---------------|----------|----------------|
| **Section** | Heading + body text | Policy sections, clauses, explanations | Exact numbers in tables, scanned images |
| **Table** | Headers + rows + text summary | Coverage amounts, premium breakdowns, benefit schedules | Narrative explanations, split tables |
| **OCR/Image** | OCR text + visual description + bbox | Signatures, stamps, QR codes, charts | OCR noise, handwriting, small stamps |
| **Entity** | Normalized field (name, date, amount, ID) | Exact lookups, filtering, linking | Conceptual questions, long-form answers |
| **Page** | Full page text + summary | Page-level citations, broad context | Too much noise, weak precision |
| **Layout** | Physical region (header/footer/sidebar) with bbox | Form extraction, signature blocks | Narrative content |
| **Structured record** | Extracted fields (policy_number, coverage, premium) | SQL-style queries ("which policies expire soon?") | Narrative questions |

### Canonical Document Model

Before chunking, create a structured intermediate representation:

```python
{
  "document_id": "policy_001",
  "source_file": "policy.pdf",
  "pages": [
    {
      "page_number": 1,
      "text_blocks": [...],
      "tables": [...],
      "images": [...],
      "ocr_blocks": [...],
      "layout_regions": [...],
      "entities": [...]
    }
  ]
}
```

Then derive different chunk types from this canonical model.

### Chunk Schema (Production-Grade)

Every chunk should answer three questions:
1. **What is this content?** (text, table, image, entity)
2. **Where did it come from?** (source file, page, bbox)
3. **When should it be retrieved?** (retrieval purpose, chunk_type)

```json
{
  "chunk_id": "doc123:p2:table:1",
  "document_id": "doc123",
  "source_file": "policy.pdf",
  "page_start": 2,
  "page_end": 2,
  "chunk_type": "table",
  "content_format": "table",
  "title": "Coverage Limits",
  "text_for_embedding": "Coverage limits table: hospitalization ₹25L, maternity ₹40K, daycare up to sum insured.",
  "raw_content": {
    "headers": ["Benefit", "Limit"],
    "rows": [
      ["Hospitalization", "₹25,00,000"],
      ["Maternity", "₹40,000"],
      ["Daycare", "Up to sum insured"]
    ]
  },
  "metadata": {
    "heading_path": ["Schedule of Benefits", "Coverage Limits"],
    "bbox": [40, 220, 560, 500],
    "parser": "pymupdf",
    "confidence": 0.86
  }
}
```

### Different Embedding Strategies Per Chunk Type

| Content Type | Good Representation | Retrieval Method |
|-------------|---------------------|-----------------|
| Narrative sections | Clean text chunk | Vector + BM25 |
| Tables | Markdown/JSON + text summary | Keyword + vector + SQL |
| Entities | Normalized field records | Exact lookup / filter |
| Images | OCR text + caption + image embedding | OCR search + multimodal |
| Forms | Key-value pairs | Structured query |
| Code | Symbols/functions/classes | Keyword + graph + vector |
| Charts | Extracted data + caption | Structured + semantic |
| Pages | Page summary | Vector fallback |

**The mistake:** forcing all content into one embedding model and one vector index.

**The fix:** one chunks table that supports multiple chunk types, with `text_for_embedding` optimized per type.

### CoverWise Current State vs Multi-View

**Current:** Single chunk type (text blocks from structure-aware chunking). All chunks are text, stored in Qdrant + FTS5.

**Gap:** No table chunks, no entity chunks, no image/OCR chunks, no structured records. A policy number query searches text semantically instead of doing an exact entity lookup.

**Recommendation:** Add multi-view indexing in this order:
1. **Entity chunks** — extract policy numbers, dates, amounts, insurer names as separate retrievable records. Enables exact lookup ("Find policy 4214i/CPHSR/...") instead of semantic search.
2. **Table chunks** — extract coverage tables, premium breakdowns as structured JSON + text summary. Enables "What is my maternity limit?" to find the table row directly.
3. **Structured records** — the `PolicySummary` model already captures this. Store as a separate retrievable record alongside text chunks.
4. **OCR/image chunks** — only needed when supporting scanned documents with stamps/signatures.

---

## 9. Query Routing by Intent

### The Problem

Different questions need different retrieval strategies:

| Query | Best Retrieval Path |
|-------|-------------------|
| "What is my policy number?" | Entity lookup → structured record |
| "What is the refund policy?" | Section chunks → semantic search |
| "What is my maternity limit?" | Table chunks → keyword + structured |
| "Is there a signature on this document?" | Image/OCR chunks → visual search |
| "Which policies expire soon?" | Structured DB → SQL query on end_date |
| "Compare my health and auto coverage" | Multi-document: structured records + section chunks |

### Query Router Architecture

```
User Question
    ↓
Query Classifier (keyword/LLM-based)
    ↓
Route to appropriate retrieval path:
    - exact_lookup → entity index / structured DB
    - semantic_search → section chunks (vector + BM25)
    - table_query → table chunks (keyword + structured)
    - visual_query → OCR/image chunks
    - cross_document → structured DB + multi-doc retrieval
    - summary → page/section chunks (broader retrieval)
    ↓
Merge results if multiple paths
    ↓
Rerank
    ↓
Generate answer with citations
```

### CoverWise Application

CoverWise already has a basic version of this: the 21 standard questions are categorized (Policy Basics, Coverage Details, Premiums, Claims, etc.). A simple keyword classifier could route:
- "policy number" → entity lookup
- "coverage amount" → table lookup
- "how do I file a claim" → section lookup
- "compare" → cross-document structured query

This is the **Adaptive RAG** pattern (Section 5.3) applied with domain-specific routing.

---

## 10. Structured RAG: Beyond Text Retrieval

### The Insight

For business products (insurance, invoicing, healthcare), structured retrieval is often more important than vector RAG.

**Pattern:**
```
SQL/structured query → get matching records → 
  vector retrieval for context → LLM synthesis
```

### Example for CoverWise

```sql
-- "Which policies expire in the next 30 days?"
SELECT * FROM policy_summaries 
WHERE end_date BETWEEN NOW() AND DATEADD(day, 30, NOW());

-- "What is my total coverage across all policies?"
SELECT SUM(coverage_amount) FROM policy_summaries 
WHERE document_type = 'Health Insurance';

-- "Which documents mention ICICI Lombard?"
SELECT * FROM entities 
WHERE entity_type = 'insurer' AND value LIKE '%ICICI%';
```

Then use LLM to explain the results in natural language.

### CoverWise Current State

The mobile app's `PolicySummary` model and `PolicyExtractionService` already extract structured data. The `coverageGapsProvider` and `claimGuideProvider` already do structured queries. This is structured RAG in practice — just not formalized as an architecture.

**Recommendation:** Formalize the structured RAG pattern in the backend. When the mobile app sends a query, first check if it can be answered from structured `PolicySummary` records before falling back to vector retrieval. This is faster, cheaper, and more accurate for field-level queries.

---

## 11. The Formalized RAG Pipeline

### Six Subsystems

| Subsystem | What It Does | CoverWise Status |
|-----------|-------------|-----------------|
| **Ingestion** | Convert raw files to clean text + metadata | PyMuPDF + doctr + optional Docling |
| **Chunking** | Split into retrievable units | Structure-aware (section headers) — **needs multi-view** |
| **Embedding** | Convert chunks to vectors | OpenAI → Ollama → local (3-tier fallback) |
| **Indexing** | Store vectors + keyword index + structured records | Qdrant + SQLite FTS5 — **needs entity/table index** |
| **Retrieval** | Find relevant chunks for a query | Hybrid (dense + FTS) + rerank — **needs query routing** |
| **Generation** | LLM answer with citations + confidence | LLM with structured output — **needs faithfulness check** |

### The Clean Pipeline

```
Files → Parse → Normalize → Extract → Chunk (multi-view) → Index (multi-type) → 
  Query → Route → Retrieve (appropriate path) → Rerank → Generate → Evaluate
```

### Separation of Concerns

| Stage | Input | Output |
|-------|-------|--------|
| **Parsing** | Raw file (PDF, image, text) | Text blocks, tables, images, layout regions |
| **Extraction** | Parsed content | Named entities, fields, structured records |
| **Chunking** | Parsed content + extracted entities | Multiple chunk types (section, table, entity, image) |
| **Indexing** | Chunks | Vector index + keyword index + entity index + structured DB |
| **Retrieval** | User query | Ranked list of relevant chunks from appropriate index |
| **Generation** | Query + retrieved chunks | Answer + citations + confidence + missing info |

**Key principle:** Do not mix these stages mentally. Parsing is not extraction. Extraction is not chunking. Chunking is not indexing.

---

## 12. RAG Architecture Patterns Summary

| Architecture | What It Is | CoverWise Relevance |
|-------------|-----------|---------------------|
| **Naive RAG** | PDF → chunks → embed → vector search → LLM | Toy version — already surpassed |
| **Metadata-aware RAG** | Filter by document type, user, date before retrieval | Partially implemented (document_id filters) |
| **Hybrid Search RAG** | Dense + sparse + RRF + rerank | **Already implemented** (Qdrant + FTS5) |
| **Multi-view RAG** | Multiple chunk types per document + query routing | **Next major upgrade** |
| **Structured RAG** | SQL/DB retrieval + vector retrieval + LLM synthesis | **Partially done** (PolicySummary) |
| **Agentic RAG** | LLM decides what tools to call, multi-hop | Future direction |
| **Multimodal RAG** | Images + OCR + visual citations | Needed for scanned documents |
| **Contextual RAG** | LLM-prepended context per chunk | **Recommended next step** |
| **Self-reflective RAG** | Self-RAG / CRAG — critique retrieval and output | High-stakes only (insurance advice) |

---

## 13. Evaluation Framework (Formalized)

### Four-Layer Eval

| Layer | What It Measures | Metrics | Tool |
|-------|-----------------|---------|------|
| **Retrieval** | Did we fetch the right evidence? | recall@k, precision@k, MRR, NDCG | RAGAS context precision/recall |
| **Generation** | Did the model answer correctly? | Answer correctness, factual accuracy | RAGAS factual correctness |
| **Grounding** | Did the answer stay faithful? | Faithfulness, unsupported claim rate | RAGAS faithfulness |
| **Product** | Did the answer help the user? | Task completion, latency, cost/₹query | Custom + TruLens |

### CoverWise Current Eval State

7 test samples, all from one document, checking:
- Field extraction matches
- Answer contains expected substrings
- Retrieved sources contain required substrings
- Citations include expected source indices

**Missing:** No retrieval-specific metrics (recall@k, precision@k), no faithfulness scoring, no latency/cost tracking, no CI integration.

### Recommended Eval Implementation

```python
# eval/ragas_eval.py
from ragas import evaluate
from ragas.metrics import (
    context_precision, context_recall, faithfulness,
    response_relevancy, noise_sensitivity
)

# eval_questions.json — 20+ questions across document types
[
  {
    "question": "What is my policy number?",
    "expected_answer": "4214i/CPHSR/407834350/00/000",
    "required_source_contains": "4214i/CPHSR",
    "answer_type": "exact_field"
  },
  {
    "question": "What is the maternity coverage limit?",
    "expected_answer": "₹40,000",
    "required_source_contains": "maternity",
    "answer_type": "exact_field"
  },
  {
    "question": "Summarize the exclusions in this policy.",
    "expected_answer_contains": ["pre-existing", "cosmetic"],
    "answer_type": "summary"
  }
]
```

Run RAGAS metrics on each query, track over time, alert on faithfulness drops.

---

## 14. Updated Implementation Priority

Combining all research findings, the recommended implementation order for CoverWise:

| # | Change | Effort | Impact | Section |
|---|--------|--------|--------|---------|
| 1 | Switch merge to RRF (k=20) | 1 hour | Robustness | §3.4 |
| 2 | Add cross-encoder reranking | 1 day | NDCG/MRR lift | §2, §5 |
| 3 | Add contextual retrieval | 2 days | 67% fewer failures | §2, §4.2 |
| 4 | Add HyDE | 1 day | Better short queries | §2 |
| 5 | Add RAG Fusion (multi-query) | 1 day | Broader coverage | §2 |
| 6 | Add entity chunks (multi-view) | 2 days | Exact lookup | §8 |
| 7 | Add table chunks (multi-view) | 2 days | Structured table retrieval | §8 |
| 8 | Add query routing by intent | 2 days | Precision + cost | §9 |
| 9 | Formalize structured RAG | 2 days | Field-level queries | §10 |
| 10 | Add RAGAS eval harness | 2 days | Systematic quality measurement | §13 |
| 11 | Add retrieval evaluator (from CRAG) | 1 day | Quality gate | §5.2 |
| 12 | Add Adaptive RAG (query classifier) | 2 days | Cost optimization | §5.3 |
| 13 | Add sentence window retrieval | 2 days | Precision | §4.2 |
| 14 | Add RAPTOR (for long docs) | 1 week | Multi-level reasoning | §5.5 |
| 15 | Add agentic RAG | 2+ weeks | Full autonomy | §5.7 |

**Items 1-5** are retrieval quality improvements (existing pipeline, no new indexes).
**Items 6-9** are architectural upgrades (multi-view indexing, structured retrieval, query routing).
**Items 10-13** are quality and evaluation infrastructure.
**Items 14-15** are long-term architectural evolution.