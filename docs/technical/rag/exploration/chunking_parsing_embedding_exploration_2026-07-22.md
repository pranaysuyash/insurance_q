# Exploration: Chunking, Parsing, Extraction & Embedding Strategies

**Date:** 2026-07-22
**Status:** EXPLORATION (documented for review; no implementation decisions made yet)
**Trigger:** Founder's directive to explore "different ways, chains, fallbacks, routing" for parsing and chunking, and the document parsers catalog (149 tools, attached).

This document supersedes the parsing/chunking sections of `docs/technical/rag_methods_research_2026-07-11.md`. Per motto_v4 §0.3 (documentation continuity), this is the canonical exploration artifact for these topics.

---

## 1. The problem statement

CoverWise ingests Indian insurance policy PDFs and answers questions via RAG.
The core failure mode: **table-heavy policies where PyMuPDF extracts text as
positional blocks, separating labels from values.** "Annual Sum Insured (₹)"
lands in block A, "2500000" lands in block B — disconnected. The chunker
inherits this disconnection, and embeddings can't bridge it.

This exploration evaluates every layer of the pipeline — parsing, chunking,
extraction, embedding, retrieval routing — and proposes multiple approaches
(fallbacks, chains, routing) at each layer.

---

## 2. What CoverWise already implements

The codebase already has significant RAG infrastructure. Understanding what
exists is critical before proposing changes.

| Capability | Implementation | Status |
|---|---|---|
| Dense retrieval | OpenAI text-embedding-3-small (1536d) | Active |
| Sparse retrieval | SQLite FTS5 (local), pgvector (Supabase) | Active |
| Hybrid fusion | RRF (k=20, tuned for small corpus) | Active |
| Cross-encoder reranking | ms-marco-MiniLM-L-6-v2 | Active |
| Query routing | Regex classifier: exact_lookup / single_step / multi_step / broad | Active |
| HyDE + RAG Fusion | Multi-query generation | Active |
| Multi-view indexing | Entity chunks (sum_insured: 2500000) + paragraph + sentence chunks | Active |
| Contextual retrieval | _contextualize_chunks() | **DISABLED** (trust audit P0-0.6) |
| Doc context header | _build_doc_context_header() (deterministic, non-LLM) | Active (our recent fix) |
| Evidence substrate | SumInsuredExtractor, key-value extraction | In progress (parallel agent) |
| Embedding fallback | OpenAI → Ollama nomic-embed-text → sentence-transformers | Active |
| LLM fallback | OpenAI gpt-5-nano → Groq llama-3.3-70b → Ollama qwen2.5:7b | Active |

---

## 3. The multi-layer pipeline (proposed architecture)

The current pipeline is essentially: `PyMuPDF text → split into blocks → embed → search`. This is a single-path pipeline with no routing or fallbacks at the parsing layer. A first-principles redesign should have **multiple paths** at each stage, with intelligent routing:

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                    DOCUMENT INPUT                        │
                    │              (PDF, image, DOCX, text)                    │
                    └─────────────────────┬───────────────────────────────────┘
                                          │
                    ┌─────────────────────▼───────────────────────────────────┐
                    │              LAYER 1: PARSING                           │
                    │  Route by document type/quality:                        │
                    │  ┌────────────┐  ┌────────────┐  ┌────────────┐       │
                    │  │ Path A:    │  │ Path B:    │  │ Path C:    │       │
                    │  │ Digital    │  │ Table-heavy│  │ Scanned    │       │
                    │  │ PyMuPDF    │  │ Docling/   │  │ OCR +      │       │
                    │  │ get_text   │  │ Marker/    │  │ ML Kit     │       │
                    │  │            │  │ find_tables│  │             │       │
                    │  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘       │
                    └────────┼──────────────┼───────────────┼───────────────┘
                             │              │               │
                    ┌────────▼──────────────▼───────────────▼───────────────┐
                    │              LAYER 2: STRUCTURE RECONSTRUCTION         │
                    │  Reconstruct key-value pairs, tables, sections         │
                    │  ┌─────────────────────────────────────────────────┐  │
                    │  │ Spatial KV detection: label block + adjacent    │  │
                    │  │ value block → "Label: Value" pair              │  │
                    │  │ Table serialization: find_tables → Markdown     │  │
                    │  │ Section tagging: heading hierarchy → metadata   │  │
                    │  └─────────────────────────────────────────────────┘  │
                    └─────────────────────────┬─────────────────────────────┘
                                              │
                    ┌─────────────────────────▼─────────────────────────────┐
                    │              LAYER 3: CHUNKING                         │
                    │  Multiple strategies, combined:                        │
                    │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐│
                    │  │ Paragraph│ │ Table-   │ │ Sentence │ │ Entity   ││
                    │  │ chunks   │ │ aware    │ │ chunks   │ │ KV pairs ││
                    │  │ (prose)  │ │ (tables) │ │ (fine)   │ │ (exact)  ││
                    │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘│
                    └───────┼────────────┼──────────┼────────────┼───────┘
                            │            │          │            │
                    ┌───────▼────────────▼──────────▼────────────▼───────┐
                    │              LAYER 4: CONTEXT ENRICHMENT              │
                    │  Prepend to each chunk:                                │
                    │  1. Doc context header (deterministic, already active)│
                    │  2. Section path metadata (new — heading hierarchy)   │
                    │  3. Contextual retrieval (LLM-generated, currently    │
                    │     disabled — safe to re-enable after source/retrieval│
                    │     text separation, which exists)                    │
                    └─────────────────────────┬─────────────────────────────┘
                                              │
                    ┌─────────────────────────▼─────────────────────────────┐
                    │              LAYER 5: EMBEDDING                        │
                    │  Multi-strategy:                                       │
                    │  ┌──────────┐ ┌──────────┐ ┌──────────────────────┐  │
                    │  │ Dense    │ │ BM25     │ │ Entity vector         │  │
                    │  │ (semantic│ │ (keyword)│ │ (structured fields)   │  │
                    │  │  search) │ │          │ │                       │  │
                    │  └────┬─────┘ └────┬─────┘ └──────────┬───────────┘  │
                    └───────┼────────────┼─────────────────┼──────────────┘
                            │            │                 │
                    ┌───────▼────────────▼─────────────────▼──────────────┐
                    │              LAYER 6: RETRIEVAL FUSION + RERANKING   │
                    │  1. RRF fuse dense + sparse + entity (k=20)          │
                    │  2. Cross-encoder rerank top-K                       │
                    │  3. Adjacent chunk expansion (parent context)         │
                    └─────────────────────────┬─────────────────────────────┘
                                              │
                    ┌─────────────────────────▼─────────────────────────────┐
                    │              LAYER 7: QUERY ROUTING                    │
                    │  Classify → route:                                     │
                    │  • exact_lookup → FTS only (policy number)             │
                    │  • single_step → standard hybrid                       │
                    │  • multi_step → decompose + multi-query                │
                    │  • broad → wider retrieval + summarization             │
                    │  • agentic (future) → iterate until satisfied          │
                    └─────────────────────────┬─────────────────────────────┘
                                              │
                    ┌─────────────────────────▼─────────────────────────────┐
                    │              LAYER 8: ANSWER GENERATION               │
                    │  LLM fallback chain:                                  │
                    │  OpenAI gpt-5-nano → Groq → Ollama → raw context      │
                    └───────────────────────────────────────────────────────┘
```

---

## 4. Layer-by-layer options analysis

### Layer 1: Parsing

#### Path A — PyMuPDF `get_text` (current default)
- **What:** Flat text extraction from born-digital PDFs
- **Cost:** Free, fast, no deps
- **Strength:** Lossless for digital text; works for prose sections
- **Weakness:** **No structure awareness** — table labels and values land in separate blocks with no parent-child relationship. This is the root cause of the "sum insured" problem
- **When to use:** Prose-heavy pages (exclusions, terms, conditions)
- **Catalog reference:** PyMuPDF (capability score 5/12), pdfplumber, pdfminer.six

#### Path B — Structure-preserving parsers (Docling, Marker, MinerU)
- **What:** AI-powered document parsing that produces structured Markdown/JSON with tables, headings, reading order
- **Cost:** Open source (Docling, Marker, MinerU) — free to run locally; LlamaParse is cloud-only paid
- **Strength:** Preserves table structure (`| Annual Sum Insured (₹) | 2500000 |`); handles merged cells, borderless tables, formulas
- **Weakness:** Heavier than PyMuPDF (Docling needs torch + models); slower; sometimes hallucinates structure
- **When to use:** Table-heavy pages (schedule of benefits, coverage matrix, premium breakdown)
- **Catalog reference:** Docling (score 12/12), Marker (12/12), MinerU (12/12), SmolDocling (12/12)

**From the catalog (149 tools):** The top parsers for insurance schedule tables are:
1. **Docling** (IBM) — open source, cell-level table model, produces Markdown + JSON, reading order. Best open-source option for structured insurance PDFs.
2. **Marker** — fast, clean Markdown tables, Surya-based layout. Good middle ground.
3. **MinerU** — strongest on complex/academic tables but heavy (GPU recommended).
4. **PyMuPDF `find_tables`** — built-in, no deps, but only works on ruled tables with visible borders.
5. **LlamaParse** — cloud API, RAG-tuned, but paid and cloud-only.

**Recommendation for CoverWise:** Route to Docling for schedule pages (detected via table density heuristic), keep PyMuPDF for prose pages. This is a parser-routing pipeline, not a single-parser replacement.

#### Path C — OCR (for scanned/image-only PDFs)
- **What:** On-device ML Kit (mobile), doctr (backend dev), or cloud OCR (HF Inference API)
- **Cost:** ML Kit is free + on-device; doctr needs torch; HF API is near-free
- **Catalog reference:** 40+ OCR tools cataloged. Best for CoverWise: ML Kit (mobile, already implemented), docTR (backend dev, already implemented), PaddleOCR (open source, strong on Indian scripts)

#### Proposed: Parser Router
```
IF digital PDF:
    IF table_density(page) > threshold:
        → Docling/Marker for structured table extraction
    ELSE:
        → PyMuPDF get_text for prose
IF scanned/image PDF:
    → OCR (ML Kit mobile / doctr backend / HF API prod)
```

### Layer 2: Structure Reconstruction (NEW — the key gap)

This layer doesn't exist in the current pipeline. It's where label-value pairs are reconnected.

#### Approach A: Spatial Key-Value Detection
PyMuPDF gives us `bbox` for each text block. Two blocks in the same vertical band (similar y-coordinates) where the left block is a known label ("Annual Sum Insured", "Policy No.", "Premium") and the right block contains a value → reconstruct as `"Label: Value"`. This handles borderless key-value layouts that `find_tables` misses.

#### Approach B: Table Serialization
When `find_tables` DOES detect a table, serialize it as Markdown: `| Annual Sum Insured (₹) | 2500000 |`. The existing code extracts table cell nodes but doesn't feed them into chunking. Wire them in.

#### Approach C: Section/Heading Tagging
Detect heading patterns (font size, bold, position) and attach `section_path` metadata to each chunk: `["Schedule of Benefits", "Coverage Details"]`. Enables filtered retrieval ("search only in Exclusions").

#### Approach D: Evidence Substrate (already in progress)
A separate deterministic key-value extraction layer with regex extractors (`SumInsuredExtractor`, `PolicyNumberExtractor`) that produces cited structured facts. This is the parallel agent's work. It's the strategically correct home for structured facts.

### Layer 3: Chunking

#### Strategy 1: Paragraph chunks (current default)
Split on `\n\n` + section headers. Good for prose. Bad for tables.

#### Strategy 2: Table-aware chunks (NEW)
Serialize each detected table as Markdown and treat it as an atomic chunk. Never split inside a table row. Every row chunk includes the table header row.

#### Strategy 3: Sentence chunks (already active)
Split paragraphs into sentences for fine-grained matching. Already implemented in `_split_into_sentences`.

#### Strategy 4: Entity/KV chunks (already active)
Extract structured entities (`"sum_insured: 2500000"`, `"policy_number: 4214i/..."`) as standalone chunks for exact-match retrieval. Already implemented in `_extract_entity_blocks`.

#### Strategy 5: Late chunking (Jina AI, 2024)
Feed entire document through a long-context embedding model in one pass. Each token sees the full document context. Then apply chunk boundaries to the token-level output and mean-pool. Eliminates the "orphan value" problem because the model KNOWS "2500000" is the sum insured from full-doc context.
- **When to use:** Documents ≤8K tokens (small policies). For 16-page policies (45K chars ≈ 11K tokens), may need a longer-context model.
- **Models:** jina-embeddings-v2-base (8K context), jina-embeddings-v3 (32K context)

#### Strategy 6: Contextual retrieval (Anthropic, 2024)
Prepend LLM-generated context to each chunk before embedding: "From the ICICI Lombard Health Shield 360 policy schedule. The sum insured is..." Reduces retrieval failure by ~49% alone, ~67% with BM25, ~67% further with reranking.
- **Status in CoverWise:** Implemented but DISABLED (trust audit P0-0.6). The `source_text`/`retrieval_text` separation needed to safely re-enable it already exists. Should be re-enabled.
- **Source:** https://www.anthropic.com/news/contextual-retrieval

### Layer 4: Context Enrichment

| Method | Type | Status | Effect |
|---|---|---|---|
| Doc context header | Deterministic (non-LLM) | **Active** (our fix) | Every chunk carries "Policy Number: X \| Sum Insured: ₹Y" |
| Section path metadata | Deterministic | **Not implemented** | Enables filtered retrieval by section |
| Contextual retrieval | LLM-generated | **Disabled** (safe to re-enable) | 49-67% retrieval failure reduction |

### Layer 5: Embedding

| Model | Dimensions | Cost | Strength | Notes |
|---|---|---|---|---|
| OpenAI text-embedding-3-small | 1536 | $0.02/M tokens | General semantic | Current default |
| OpenAI text-embedding-3-large | 3072 | $0.13/M tokens | Stronger | Higher cost/storage |
| BAAI/bge-m3 | 1024 | Free (local) | Multilingual, strong on MTEB | Good for Hindi/regional policies |
| intfloat/e5-large-v2 | 1024 | Free (local) | Strong general | |
| nomic-embed-text (Ollama) | 768 | Free (local) | Dev fallback | Already wired |
| ColBERT / late-interaction | Per-token | Free (RAGatouille) | Token-level matching | For negation/conditional queries |

**Domain-specific embeddings:** No widely-adopted insurance-specific embedding model exists. Practical path: fine-tune text-embedding-3-small on (query, positive-chunk, negative-chunk) triples harvested from real usage. The benchmark tooling exists (`tools/benchmark_embedding_models.py`).

### Layer 6: Retrieval Fusion

| Method | Status | Notes |
|---|---|---|
| Dense + BM25 RRF (k=20) | Active | Standard hybrid |
| + Entity vector | Multi-view (active) | Exact-match for structured fields |
| Cross-encoder rerank | Active | ms-marco-MiniLM-L-6-v2 |
| Adjacent chunk expansion | Active | Parent context for top hits |
| ColBERT as stage-1.5 | Future | For precision-critical queries |

### Layer 7: Query Routing

| Route | Trigger | Current | Proposed |
|---|---|---|---|
| exact_lookup | "policy number", long alphanumeric | FTS-only | Keep |
| single_step | Default | Dense + sparse hybrid | Keep |
| multi_step | "compare", "difference between" | Sub-query decomposition | Keep |
| broad | "summarize", "overview" | Wider retrieval | Keep |
| agentic_reformulation | Low retrieval score | Not implemented | **Add: if retrieval score < threshold, reformulate query once via HyDE, retry** |
| GraphRAG | Relational questions | Not implemented | Future (post-MVP) |

---

## 5. The 149-tool catalog: what matters for CoverWise

From the document parsers catalog (149 tools across 30+ categories), the ones that matter for CoverWise:

### Must-have (already in the stack)
- **PyMuPDF** — text extraction (already used)
- **docTR** — OCR for scanned PDFs (already used in dev)
- **Google ML Kit** — on-device OCR for mobile (already used)
- **OpenAI text-embedding-3-small** — embeddings (already used)
- **ms-marco-MiniLM-L-6-v2** — cross-encoder reranking (already used)

### High-value additions (not yet in the stack)
- **Docling** — structure-preserving parser for table-heavy pages. The single highest-value addition for the sum-insured problem.
- **Marker** — alternative to Docling, faster, produces clean Markdown tables. Lighter weight.
- **bge-reranker-v2-m3** — upgrade from MiniLM reranker, multilingual, stronger.
- **jina-embeddings-v3** — long-context embeddings for late chunking experiments.

### Interesting but deferred
- **ColBERT/ColPali** — token-level matching; complex to deploy, high accuracy
- **MinerU** — strongest table extraction but heavy (GPU recommended)
- **LlamaParse** — convenient cloud API but paid + cloud-only
- **LayoutLMv3** — document understanding model; research-grade
- **GraphRAG** — knowledge graph for relational insurance questions; post-MVP

### Not relevant for CoverWise
- Scientific paper parsers (Nougat, GROBID, ScienceParse)
- Invoice/form parsers (Textract, Document AI) — insurance policies aren't invoices
- Java-only tools (PDFBox, iText, Tabula) — the stack is Python

---

## 6. Proposed implementation priorities

Ranked by impact on the CoverWise sum-insured problem vs effort:

| Priority | Change | Impact | Effort |
|---|---|---|---|
| P0 | Wire `find_tables` output into chunking (serialize tables as Markdown chunks) | High | Low (code exists) |
| P0 | Spatial key-value detection for borderless tables | High | Medium |
| P1 | Re-enable contextual retrieval (source_text/retrieval_text separation exists) | High | Low |
| P1 | Add section-path metadata to chunks (heading hierarchy tagging) | Medium | Medium |
| P2 | Add Docling as specialist parser for schedule pages | High | Medium (new dep) |
| P2 | Upgrade reranker to bge-reranker-v2-m3 | Medium | Low |
| P3 | Agentic reformulation when retrieval score is low | Medium | Medium |
| P3 | Late chunking experiment (jina-embeddings-v3) | Unknown | High |
| P3 | ColBERT as stage-1.5 retriever | Unknown | High |

---

## 7. Anything else? (motto_v4 §0.1.1)

**Q: Should we benchmark these approaches on real Indian insurance PDFs?**
A: Yes. The catalog says "Benchmark on your own document mix. No parser dominates all categories." The codebase has benchmark tooling (`tools/benchmark_embedding_models.py`, `tools/verification/supabase_retrieval_benchmark.py`). A concrete benchmark set of 5-10 real Indian policies (health, term, auto, home) with known Q&A pairs would let us measure which combination of parsing+chunking+embedding produces the best answers. This is the single highest-leverage research investment.

**Q: What about the evidence substrate?**
A: A parallel agent is building the evidence substrate (deterministic key-value extractors). This is the strategically correct home for structured facts (sum insured, policy number, premium, dates). RAG chunks should carry prose context; the substrate carries verified structured facts. The two are complementary, not competing.

**Q: Does late chunking work for 16-page policies?**
A: jina-embeddings-v2-base supports 8K tokens. A 16-page policy is ~11K tokens — exceeds the window. jina-embeddings-v3 supports 32K tokens — fits. But late chunking requires a model that exposes token-level embeddings, which not all models do. Worth experimenting with but not the primary fix.

**Q: Should we use a VLM (vision model) to read table images directly?**
A: For the hardest cases (scanned, borderless, merged-cell tables), a VLM like GPT-4o or Claude reading a cropped table image produces the most accurate key-value extraction. But the cost per page is high ($0.01-0.03 per image). Reserve for pages where text+table extraction both fail (detect via low text yield + no detected tables).

---

## Sources

- Document parsers catalog: `document_parsers_extractors_catalog_2026_v2.xlsx` (149 tools)
- Anthropic, "Contextual Retrieval" (Sept 2024): https://www.anthropic.com/news/contextual-retrieval
- Jina AI, "Late Chunking": https://jina.ai/news/late-chunking-in-long-context-embedding-models/
- ColBERT: https://arxiv.org/abs/2004.12832
- RRF: https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf
- Docling: https://github.com/docling-project/docling
- Marker: https://github.com/VikParuchuri/marker
- MinerU: https://github.com/opendatalab/MinerU
- OmniDocBench (parser benchmark): https://github.com/opendatalab/OmniDocBench
- PyMuPDF find_tables: https://pymupdf.readthedocs.io/en/latest/page.html#Page.find_tables
- RAGatouille (ColBERT library): https://github.com/AnswerDotAI/RAGatouille
