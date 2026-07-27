# RAG Pipeline Layer Exploration Analysis

**Date:** 2026-07-22
**Purpose:** Map the entire RAG pipeline, identify which layers have the most
unexplored surface area, and prioritize deep-dive exploration for each layer.
This is the meta-document that guides the next round of benchmarks and research.

**Context:** We completed a comprehensive chunking benchmark (11 strategies × 10
questions). The surprising finding was that "smart" strategies (semantic,
contextual, LLM-enriched) scored WORSE than deterministic approaches. This
raised the question: what other layers have we only tested one approach on,
and where is the real improvement surface?

---

## The 8 pipeline layers

```
Document → [1. Parse] → [2. Chunk] → [3. Enrich] → [4. Embed]
                                                        ↓
Answer ← [8. Generate] ← [7. Route] ← [6. Rerank] ← [5. Retrieve]
```

---

## Layer-by-layer exploration state

### Layer 1: Parsing (PDF → text/tables/structure)

**What it does:** Extracts text, tables, images, and structural metadata from
the source PDF. This is where data is either captured or lost forever —
everything downstream can only work with what parsing produces.

**Current approach:** PyMuPDF `get_text()` (flat text blocks) + `find_tables()`
(Markdown tables when detected). OCR fallback via docTR/ML Kit for scanned pages.

**What we tested:**
- PyMuPDF `get_text()` — flat text extraction
- PyMuPDF `find_tables()` — table detection (23 tables on the real policy)
- PyMuPDF `get_text("blocks")` — positional blocks with bbox

**What we have NOT tested:**
| Method | What it does | Why it matters | Effort |
|---|---|---|---|
| **Spatial key-value detection** | Use bbox positions to pair labels with adjacent values (left block = label, right block = value, same y-band) | Directly solves the sum-insured problem at the parsing layer — "Annual Sum Insured (₹)" and "2500000" get paired before chunking | Medium |
| **Docling** (IBM) | AI-powered structure-preserving parser; produces Markdown with tables, headings, reading order | Handles borderless tables that `find_tables` misses; cell-level structure | Medium (new dep) |
| **Marker** | Fast Surya-based parser; clean Markdown tables | Alternative to Docling, lighter weight | Medium |
| **Table cell extraction** | Extract individual cells with row/column metadata from `find_tables` output | Enables per-cell key-value pairing (row 5, column 2 = "2500000") | Low |
| **VLM table reading** | Render table region to image, use vision model to read label-value pairs | Highest accuracy for complex/merged-cell tables; highest cost | High |
| **Font-based heading detection** | Use PyMuPDF font size/weight to detect headings | Enables section-path metadata; more reliable than regex | Low |
| **PyMuPDF `get_text("dict")`** | Rich extraction with font, size, color, flags per span | Enables heading detection and visual hierarchy | Low |
| **Apache Tika** | Multi-format content extraction | If we add DOCX/PPTX policy formats | Low |

**Exploration value: HIGH** — this is the #1 gap. We proved chunking matters
less than expected, but PARSING is where data gets lost. The context header
compensates for parsing loss, but fixing the parsing loss itself would be
strictly better.

**Recommended next exploration:** Spatial KV detection (highest ROI — uses
existing bbox data, no new deps, directly targets root cause).

---

### Layer 2: Chunking (text → retrievable units)

**What it does:** Splits parsed text into chunks that will be embedded and
retrieved.

**Current approach:** Paragraph-based splitting with deterministic context
header. Winner: Strategy D (hybrid: table-serialized + page-level).

**What we tested (COMPLETE — 11 strategies):**
| Strategy | Accuracy | Chunks | Verdict |
|---|---|---|---|
| D_hybrid (table+page) | 80% | 39 | 🥇 Winner |
| A_paragraph+header | 80% | 43 | 🥇 Current |
| C_page_level | 80% | 16 | 🥇 Most efficient |
| B_table_aware alone | 60% | 66 | Fragments |
| E_no_header (control) | 60% | 43 | Proves header = +20% |
| 1_token-based | 50% | 35 | Lucky on Q8 |
| 3_sliding window | 50% | 64 | Overlap noise |
| 13_contextual (LLM) | 40% | 43 | Worse than deterministic |
| 2_sentence-based | 30% | 320 | Tables aren't sentences |
| 5_header/section | 30% | 195 | Over-segmentation |
| 11_semantic | 30% | 44 | Expensive, ineffective |

**What we have NOT tested:**
| Method | Why not yet | Priority |
|---|---|---|
| Late chunking (Jina v3) | Needs Jina API/key; 32K context model | Low (deterministic won) |
| Recursive character (LangChain) | Subsumed by token-based test | Skip |
| Markdown-header splitting | Subsumed by header-based test (5) | Skip |

**Exploration value: DONE** — this layer is thoroughly explored. The winner is
Strategy D (hybrid). Remaining work is implementation, not exploration.

---

### Layer 3: Context enrichment (metadata prepended to chunks)

**What it does:** Adds metadata or generated context to each chunk before
embedding, improving retrieval by making each chunk self-describing.

**Current approach:** Deterministic `_build_doc_context_header` — prepends
`[Policy Context] Insurer: X | Policy Number: Y | Sum Insured: ₹Z` to every
chunk. This added +20% accuracy vs no header.

**What we tested:**
- Deterministic header (active) — 80% accuracy
- No header (control) — 60% accuracy
- LLM-enriched contextual retrieval — 40% accuracy (WORSE)

**What we have NOT tested:**
| Method | What it does | Expected impact |
|---|---|---|
| **Section-path metadata** | Tag each chunk with its heading hierarchy: `["Schedule", "Coverage Details"]`. Enables filtered retrieval ("search only in Exclusions") | Medium — improves source quality (currently 50-65%), not answer accuracy |
| **Multi-vector metadata** | Separate vector for metadata fields (policy number, dates) vs prose text | Medium — exact-match for structured fields |
| **Page-position embedding** | Add page number as a metadata field for retrieval filtering | Low — already partially done via payload |
| **Neighbor context** | Prepend previous chunk's last sentence + next chunk's first sentence | Medium — bridges concept gaps at chunk boundaries |

**Exploration value: MEDIUM** — the deterministic header works well. Section
paths would improve source citation quality (which scores 50-65%), but won't
change answer accuracy. Lower priority than parsing/embedding/reranking.

---

### Layer 4: Embedding (text → vectors)

**What it does:** Converts chunk text into a vector representation for
similarity search.

**Current approach:** OpenAI `text-embedding-3-small` (1536 dimensions).
This is the ONLY model we've tested.

**What we have NOT tested:**
| Model | Dimensions | Cost | Why test it | Expected impact |
|---|---|---|---|---|
| **bge-m3** (BAAI) | 1024 | Free (local) | Multilingual — handles Hindi/regional policy text. Strong on MTEB. | Could help if policies have Hindi sections |
| **e5-large-v2** (intfloat) | 1024 | Free (local) | Strong general-purpose; different training data than OpenAI | Different retrieval profile — may catch what OpenAI misses |
| **text-embedding-3-large** (OpenAI) | 3072 | $0.13/M | Higher dimensionality, stronger model | Marginal improvement at 6.5x cost |
| **ColBERT** (late interaction) | Per-token | Free (RAGatouille) | Token-level matching; catches negation ("covered unless...") | Could be a game-changer for insurance conditionals |
| **Fine-tuned on insurance corpus** | 1536 | Training cost | Custom model trained on (query, chunk, label) triples from real usage | Highest long-term potential; needs usage data first |
| **nomic-embed-text** (Ollama) | 768 | Free (local) | Currently used as fallback only | Lower quality than OpenAI; dev-only |
| **arctic-embed** (Snowflake) | 1024 | Free | Optimized for retrieval; strong on BEIR | Alternative open-source option |

**Exploration value: HIGH** — we tested exactly ONE model. Different embedding
models have fundamentally different retrieval profiles (what they consider
"similar"). A model trained on financial/legal text might match "sum insured"
to "2500000" better than a general-purpose model.

**Recommended next exploration:** bge-m3 (multilingual, free, strong on
structured data) and ColBERT (token-level, catches conditionals). The benchmark
harness already supports swapping the model — just change the `EMBEDDING_MODEL`
parameter.

---

### Layer 5: Retrieval (query → candidate chunks)

**What it does:** Finds the most similar chunks to the query using vector
similarity.

**Current approach:** Cosine similarity, top-5 results. Hybrid: dense (OpenAI
embeddings) + sparse (BM25 via FTS5) fused with RRF (k=20). Plus multi-view
entity chunks for exact-match queries.

**What we have NOT tested:**
| Method | What it does | Expected impact |
|---|---|---|
| **K sweep** (top-3, 5, 8, 10, 15) | How many chunks to retrieve | Precision/recall tradeoff — more chunks = more context but more noise |
| **RRF k sweep** (k=10, 20, 40, 60) | Tune the fusion parameter | Standard k=60 (Cormack 2009); CoverWise uses k=20 (tuned for small corpus but never validated) |
| **Multi-query retrieval** | Generate 3 paraphrases of the question, retrieve for each, merge results | Catches different phrasings ("sum insured" vs "coverage amount" vs "sum assured") |
| **HyDE variants** | Generate hypothetical answer, embed that instead of the query | Different HyDE prompts produce different results |
| **Filtered retrieval** | Pre-filter by section/page before vector search | Improves precision for section-specific queries |
| **Parent document retrieval** | Retrieve small chunks but return the parent (page or section) | Gives the LLM more context per hit |

**Exploration value: HIGH** — the K value and RRF k were never empirically
tuned. Multi-query and HyDE variants are implemented but never A/B tested.

**Recommended next exploration:** K sweep (fastest — just change a parameter)
and multi-query retrieval (already implemented in the pipeline as HyDE + RAG
Fusion, but never benchmarked in isolation).

---

### Layer 6: Reranking (reorder candidates by relevance)

**What it does:** Takes the top-K retrieved chunks and re-scores them with a
more expensive but more accurate model.

**Current approach:** `cross-encoder/ms-marco-MiniLM-L-6-v2` (6-layer MiniLM,
trained on MS MARCO). This is the ONLY reranker tested.

**What we have NOT tested:**
| Model/Method | What it does | Why test it | Expected impact |
|---|---|---|---|
| **bge-reranker-v2-m3** (BAAI) | Multilingual cross-encoder | Stronger than MiniLM; handles Hindi | Higher precision, especially for bilingual policies |
| **bge-reranker-large** | Larger model | More capacity for nuanced matching | Marginal improvement, higher latency |
| **Cohere Rerank** | Cloud API | Industry-leading accuracy | Paid, but highest quality |
| **LLM-based rerank** | Ask gpt-5-nano to score 0-10 for each (query, chunk) pair | Catches semantic mismatches cross-encoders miss | More flexible, more expensive per query |
| **ColBERT MaxSim** | Token-level late interaction | Per-token matching with audit trail | Could catch "covered" vs "excluded" |
| **No reranker (control)** | Skip reranking entirely | Measures the reranker's contribution | Baseline |

**Exploration value: HIGH** — only tested one reranker. Reranking is the
precision layer; a better reranker directly improves which chunks the LLM sees.

**Recommended next exploration:** bge-reranker-v2-m3 (multilingual, same API
pattern as MiniLM, free) and LLM-based rerank (flexible, catches semantic
nuances). Also: test "no reranker" as a control.

---

### Layer 7: Query routing (classify question → strategy)

**What it does:** Classifies the user's question type and routes to the
appropriate retrieval strategy.

**Current approach:** Regex classifier with 4 routes:
- `exact_lookup` (policy number, ID) → FTS-only
- `single_step` (default) → standard hybrid
- `multi_step` (compare, difference) → sub-query decomposition
- `broad` (summarize, overview) → wider retrieval

**What we have NOT tested:**
| Method | What it does | Expected impact |
|---|---|---|
| **LLM classifier** | Use a cheap LLM call to classify question type | Catches paraphrases the regex misses ("how do my plans differ" → multi_step) |
| **Query decomposition** | Split complex questions into sub-questions | Better for multi-hop ("Is my mother covered for dental under my family floater?") |
| **Agentic retry** | If retrieval score is low, reformulate query and retry once | Catches retrieval failures before giving up |
| **Query expansion** | Add synonyms/related terms ("sum insured" → "coverage amount", "sum assured", "limit") | Catches vocabulary mismatches between user and policy |
| **Intent detection** | Is this a factual lookup, comparison, or procedural question? | Different intents need different retrieval depth |

**Exploration value: MEDIUM** — the regex classifier works but misses
paraphrases. The highest-impact addition is agentic retry (reformulate on low
score), which is cheap and directly improves the failure mode we've observed.

---

### Layer 8: Answer generation (context + question → answer)

**What it does:** Takes the retrieved chunks and generates a natural-language
answer.

**Current approach:** Basic prompt: "Answer the question based ONLY on the
context. If not found, say so. Be concise." Using gpt-5-nano with
`max_completion_tokens=500`.

**What we have NOT tested:**
| Method | What it does | Expected impact |
|---|---|---|
| **Chain-of-thought prompt** | "First identify the relevant section. Then extract the value. Then cite the page." | More accurate for multi-step reasoning |
| **Self-citation prompt** | "Always cite the page number and section for every claim" | Improves trust and verifiability |
| **Structured output** | Force JSON output with `{answer, confidence, sources, page_numbers}` | Better for the mobile app to render |
| **Verification prompt** | "After answering, verify: does the answer directly address the question? Is the value from the right field?" | Reduces hallucination on similar-looking values |
| **Confidence calibration** | Ask the LLM to rate its own confidence (0-100%) | Enables UI to show "low confidence — verify with insurer" |
| **Disclaimer injection** | Automatically append "This is AI-generated; verify with your insurer" | Legal protection, user trust |
| **Multi-model ensemble** | Generate answers with 2-3 models, pick the one with highest agreement | Reduces single-model errors |
| **Different models** | Test gpt-4o-mini, Groq llama-3.3-70b, Ollama gemma3:12b | Different models may handle insurance language differently |

**Exploration value: HIGH** — the prompt is basic. Insurance answers have
legal implications; prompt quality directly affects trust and accuracy.
Chain-of-thought and self-citation are untested and could materially improve
answer quality and verifiability.

---

## Exploration priority matrix

| Priority | Layer | What to explore | Impact | Effort | Dependencies |
|---|---|---|---|---|---|
| **P0** | Parsing | Spatial KV detection | HIGH (fixes root cause) | Medium | None |
| **P0** | Embedding | bge-m3, e5-large-v2 | HIGH (only tested 1 model) | Low | Install models |
| **P0** | Reranking | bge-reranker-v2-m3, no-reranker control | HIGH (precision layer) | Low | Install model |
| **P1** | Answer gen | Chain-of-thought, self-citation | HIGH (legal/trust) | Low | None |
| **P1** | Retrieval | K sweep, RRF k sweep | MEDIUM (parameter tuning) | Low | None |
| **P1** | Parsing | Docling as table-page specialist | HIGH (structure-preserving) | Medium | Install Docling |
| **P2** | Retrieval | Multi-query, HyDE variants | MEDIUM | Medium | None |
| **P2** | Context | Section-path metadata | MEDIUM (source quality) | Medium | Font-based heading detection |
| **P2** | Routing | Agentic retry on low score | MEDIUM | Medium | None |
| **P3** | Embedding | ColBERT | UNKNOWN (token-level) | High | RAGatouille install |
| **P3** | Embedding | Fine-tuned insurance model | HIGH long-term | High | Usage data first |
| **P3** | Answer gen | Multi-model ensemble | MEDIUM | High | Multiple model APIs |

---

## What "deep exploration" looks like for each priority layer

### Parsing (P0)
1. Implement spatial KV detection (bbox-based label-value pairing)
2. Benchmark: does it solve Q2 (sum insured) without needing table serialization?
3. Test Docling on the same policy — compare table extraction quality
4. Test font-based heading detection — compare vs regex heading detection
5. Measure: how much text is lost at each parsing stage?

### Embedding (P0)
1. Swap `text-embedding-3-small` for `bge-m3` in the benchmark harness
2. Rerun all 10 questions
3. Swap for `e5-large-v2`, rerun
4. Compare accuracy across all 3 models
5. Test: does a different model solve Q2 (sum insured) without table serialization?

### Reranking (P0)
1. Swap `ms-marco-MiniLM-L-6-v2` for `bge-reranker-v2-m3`
2. Rerun all 10 questions
3. Test "no reranker" (control) — measures reranker contribution
4. Test LLM-based rerank (gpt-5-nano scores each chunk 0-10)
5. Compare: which reranker produces the best final answer accuracy?

### Answer generation (P1)
1. Test chain-of-thought prompt ("identify section → extract value → cite page")
2. Test self-citation prompt ("always cite page numbers")
3. Test structured output (JSON with confidence + sources)
4. Test verification prompt ("verify the answer before responding")
5. Compare answer accuracy + source citation quality across prompts

---

## Anything else? (motto_v4 §0.1.1)

**Q: Should we explore all layers simultaneously or sequentially?**
A: Sequentially, varying one layer at a time. Otherwise we can't attribute
improvements. The order should be: parsing (fixes root cause) → embedding
(different retrieval profile) → reranking (precision layer) → answer
generation (trust/quality).

**Q: What about the evidence substrate?**
A: The substrate is a parallel system, not a pipeline layer. It extracts
structured facts deterministically (regex/LLM) and stores them separately from
RAG. It should be benchmarked too ("can deterministic extractors find the sum
insured?") but it's a different system, not a layer in the RAG pipeline.

**Q: What about the LLM model itself for answer generation?**
A: We tested gpt-5-nano. Testing gpt-4o-mini, Groq llama-3.3-70b, and Ollama
gemma3:12b would show whether the model choice matters for insurance Q&A. But
this is a variable we already control (fallback chain), so it's lower priority
than prompt engineering.

**Q: Is there value in testing on more policies?**
A: Yes — the findings should be validated on 3+ policy types. The benchmark
harness is parameterized for this. But the ranking of strategies within a layer
should be stable across policy types for the same reason: the differentiator
for insurance documents is table handling, which is universal.

**Q: What about GraphRAG?**
A: GraphRAG (knowledge graph for relational insurance questions) is a different
architecture, not a layer optimization. It's post-MVP. The current pipeline
already handles most questions well; GraphRAG would help with multi-hop
relational queries ("which family member has the lowest coverage?") that
require cross-document reasoning.
