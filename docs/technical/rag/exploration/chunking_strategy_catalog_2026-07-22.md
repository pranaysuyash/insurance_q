# Comprehensive Chunking Strategy Catalog & Evaluation

**Date:** 2026-07-22
**Purpose:** Research, evaluate, and document EVERY viable chunking strategy
for insurance policy RAG — not just the ones we've already tested. Each
strategy gets: definition, mechanism, strengths/weaknesses, expected behavior
on insurance PDFs, and a benchmark score.

**Source document:** ICICI Lombard Health Shield 360 Retail (16 pages, 45K chars,
23 tables, password-protected)

**Status:** Research + benchmark in progress. Results update as each strategy
is tested.

---

## The 14 chunking strategies under evaluation

### Group 1: Size-based (mechanical splitting)

#### 1. Token-based (fixed token count)
- **Mechanism:** Split text into chunks of exactly N tokens (e.g., 512 tokens)
  with optional overlap (e.g., 50 tokens). Most LLM frameworks default to this.
- **Implementation:** tiktoken or HuggingFace tokenizer to count tokens, split
  at boundaries.
- **Strength:** Deterministic, predictable chunk sizes, no ambiguity.
- **Weakness:** Splits mid-sentence, mid-table-row, mid-concept. Destroys
  semantic units. A 512-token chunk might cut "Annual Sum Insured" from
  "2500000" if they happen to straddle the boundary.
- **Expected on insurance PDF:** POOR for tables (will split label from value);
  acceptable for prose if overlap is sufficient.
- **Parameters:** chunk_size=512, overlap=50.
- **Status:** TO TEST

#### 2. Sentence-based
- **Mechanism:** Split on sentence boundaries (`.`, `!`, `?`, newline).
  Each sentence (or group of N sentences) is a chunk.
- **Implementation:** nltk.sent_tokenize or regex `(?<=[.!?])\s+`.
- **Strength:** Preserves clause-level semantics. No mid-sentence splits.
- **Weakness:** Insurance tables aren't sentences — "2500000" is not a sentence.
  Produces many tiny, context-free chunks for table-heavy pages.
- **Expected on insurance PDF:** POOR for schedule tables; GOOD for terms &
  conditions prose (pages 3-16).
- **Parameters:** max_sentences=5, min_chunk_size=100 chars.
- **Status:** TO TEST

#### 3. Character/token sliding window
- **Mechanism:** Fixed-size window that slides by (size - overlap) characters.
  Like token-based but character-level.
- **Implementation:** `text[i:i+window]` with stride.
- **Strength:** Guaranteed overlap between adjacent chunks (catches values
  that straddle boundaries).
- **Weakness:** Massive redundancy (same text appears in multiple chunks);
  still splits mid-concept.
- **Expected on insurance PDF:** MODERATE — overlap catches some label-value
  splits but adds noise.
- **Parameters:** window=1000 chars, stride=800 (20% overlap).
- **Status:** TO TEST

### Group 2: Structure-based (using document structure)

#### 4. Paragraph-based (CURRENT — tested as Strategy A)
- **Mechanism:** Split on `\n\n` (double newlines). Greedily pack paragraphs
  into ~1000-char blocks.
- **Strength:** Aligns with author intent (paragraphs are semantic units).
- **Weakness:** Insurance PDFs have no "paragraphs" in the traditional sense —
  the text is positional blocks from PyMuPDF, not authored paragraphs. Two
  adjacent blocks might be a label and its value.
- **Benchmark result:** 80% answer accuracy.
- **Status:** TESTED ✅

#### 5. Header/section-based (structural hierarchy)
- **Mechanism:** Detect heading patterns (font size, bold, position, or
  keywords like "SECTION", "COVERAGE", "EXCLUSIONS") and split at heading
  boundaries. Each chunk inherits its section path as metadata.
- **Implementation:** Heading detector (font-based or regex), section tree
  builder, per-section chunking.
- **Strength:** Chunks are topically coherent (everything under "Exclusions"
  stays together). Metadata enables filtered retrieval ("search only in
  Exclusions"). This is how human readers navigate policies.
- **Weakness:** Insurance PDFs from PyMuPDF don't have explicit heading
  hierarchy — you have to infer it from font size / position / keywords.
  False positives (text that looks like a heading but isn't).
- **Expected on insurance PDF:** GOOD for pages 3-16 (terms, conditions,
  exclusions — these DO have section headings). The schedule page (p1) has
  no traditional headings — it's one big table.
- **Parameters:** heading_font_ratio=1.3 (headings are 1.3x body font size),
  heading_keywords=["SECTION", "COVERAGE", "EXCLUSION", "DEFINITION",
  "SCHEDULE", "PREMIUM", "CLAIM", "BENEFIT", "WAITING PERIOD", "POLICY"].
- **Status:** TO TEST

#### 6. Page-based (tested as Strategy C)
- **Mechanism:** Each page's full text as one chunk.
- **Strength:** All page content stays together. For schedule pages (which are
  one big table), this is the natural unit. Page number metadata enables
  precise citation.
- **Weakness:** Very large chunks for dense pages (8K+ chars) reduce embedding
  precision. Small values (like loyalty bonus) get lost in the noise.
- **Benchmark result:** 80% answer accuracy, 90% retrieval.
- **Status:** TESTED ✅

### Group 3: Content-type-aware (different chunking for different content)

#### 7. Table-aware (tested as Strategy B)
- **Mechanism:** Detect tables via `find_tables()`, serialize as Markdown, treat
  each table as an atomic chunk. Non-table text chunked normally.
- **Strength:** Preserves table structure (label + value in same row).
- **Weakness:** Fragments the page by separating tables from surrounding text.
  When a table chunk competes with prose chunks, the table might not rank high
  enough.
- **Benchmark result:** 60% answer accuracy (WORSE than paragraph).
- **Status:** TESTED ✅

#### 8. Hybrid (table + page) (tested as Strategy D)
- **Mechanism:** Table-serialized chunks for tables + full-page chunks for
  prose. Both types coexist in the index.
- **Strength:** Gets precision of table chunks AND context of page chunks.
  The ONLY strategy that correctly answered Q2 (sum insured).
- **Benchmark result:** 80% answer accuracy (only strategy to solve Q2).
- **Status:** TESTED ✅ (winner so far)

#### 9. Image/figure-aware
- **Mechanism:** Detect images and figures in the PDF. If a figure contains
  information (chart, diagram, annotated form), render it and run OCR/VLM to
  extract text. Treat as a separate chunk with figure metadata.
- **Implementation:** PyMuPDF `page.get_images()`, render to image, OCR or VLM.
- **Strength:** Captures information that text extraction misses (annotated
  diagrams, charts, visual policy benefits).
- **Weakness:** Most insurance policy images are logos and signatures — not
  informative. OCR on images is slow and noisy. Adds cost.
- **Expected on insurance PDF:** LOW VALUE for typical Indian policies (they're
  text + tables, not image-heavy). Would matter for policies with embedded
  benefit charts or network hospital maps.
- **Status:** TO EVALUATE (may skip — low ROI for this document type)

#### 10. Keyword/entity-based (already implemented as "entity chunks")
- **Mechanism:** Extract named entities and key-value pairs from text
  (policy_number, sum_insured, premium, dates, names). Each entity becomes a
  standalone chunk: `"sum_insured: 2500000"`.
- **Strength:** Perfect for exact-match queries ("What is my sum insured?"
  matches `"sum_insured: 2500000"` directly).
- **Weakness:** Doesn't capture context. Only works for known entity types.
  Requires entity extractors to be defined upfront.
- **Status:** ALREADY IMPLEMENTED in pipeline as `_extract_entity_blocks`.
  Active in production.

### Group 4: Semantic (meaning-based splitting)

#### 11. Semantic chunking (embedding-based)
- **Mechanism:** Embed adjacent sentences. When the cosine similarity between
  consecutive sentences drops below a threshold, start a new chunk. This splits
  where the TOPIC changes, not at arbitrary boundaries.
- **Implementation:** Embed all sentences, compute adjacent similarity, split
  at dips. LangChain's `SemanticChunker` does this.
- **Strength:** Topic-coherent chunks. A chunk about "exclusions" won't contain
  text about "premium calculation." Better embedding quality because each chunk
  is about one thing.
- **Weakness:** EXPENSIVE — requires embedding every sentence at ingest time
  (100+ API calls for a 16-page policy). Threshold tuning is corpus-specific.
  For table-heavy pages, sentence boundaries are meaningless.
- **Expected on insurance PDF:** GOOD for prose pages (3-16); QUESTIONABLE
  for the schedule page (p1) where there are no real sentences.
- **Cost:** ~100 embedding API calls per document at ingest (vs 0 for
  deterministic strategies). At $0.02/M tokens, this is ~$0.001 per document
  — negligible at solo scale but adds latency.
- **Parameters:** similarity_threshold=0.5 (split when adjacent sentences
  are less than 50% similar).
- **Status:** TO TEST

#### 12. Late chunking (Jina AI)
- **Mechanism:** Feed the ENTIRE document through a long-context embedding
  model (8K-32K tokens) in one forward pass. Each token's representation is
  informed by full-document context. Then apply chunk boundaries to the
  token-level output and mean-pool per chunk.
- **Strength:** Every chunk "knows" about the rest of the document. A chunk
  containing "2500000" embeds with knowledge that this IS the sum insured
  because the model saw the whole schedule.
- **Weakness:** Requires a model that exposes token-level embeddings (Jina
  v2/v3). Document must fit in the context window. Not all embedding models
  support this.
- **Expected on insurance PDF:** PROMISING — the 45K-char policy is ~11K tokens.
  Jina v3 (32K context) can handle it in one pass.
- **Cost:** One full-document embedding call (vs N chunk-level calls). Actually
  CHEAPER than standard chunking for small documents.
- **Status:** TO RESEARCH (needs Jina API or local model)

#### 13. Contextual retrieval (Anthropic)
- **Mechanism:** Before embedding, prepend a short LLM-generated context to each
  chunk summarizing where it sits in the document. "This chunk is from the ICICI
  Lombard policy schedule page, showing the annual sum insured of ₹25 lakhs."
- **Strength:** 49% retrieval failure reduction per Anthropic (verified on their
  corpus). Each chunk is self-describing.
- **Weakness:** One LLM call per chunk at ingest time (43 calls for our policy).
  Currently DISABLED in CoverWise (trust audit P0-0.6) but the
  source_text/retrieval_text separation needed to safely re-enable exists.
- **Expected on insurance PDF:** HIGH IMPROVEMENT — would make every chunk
  self-describing, solving the label-value disconnection at the embedding layer.
- **Status:** TO TEST (the deterministic context header we already have is a
  cheaper approximation — need to measure the delta)

### Group 5: No context (control)

#### 14. No header (tested as Strategy E)
- **Mechanism:** Paragraph splitting WITHOUT any context enrichment.
- **Benchmark result:** 60% answer accuracy (proves context header adds +20%).
- **Status:** TESTED ✅ (control group)

---

## Strategy matrix (what to test next)

Already tested (5/14): A_paragraph, B_table_aware, C_page_level, D_hybrid,
E_no_header.

Still to test:
- 1. Token-based (fixed 512 tokens, 50 overlap)
- 2. Sentence-based (5 sentences per chunk)
- 3. Sliding window (1000 chars, 20% overlap)
- 5. Header/section-based (heading detection)
- 11. Semantic chunking (embedding-based splitting)
- 13. Contextual retrieval (LLM-enriched — the expensive one)

Skipped (low ROI for this document type):
- 9. Image-aware (Indian policies are text+table, not image-heavy)
- 12. Late chunking (requires Jina API — separate experiment)

Already in production:
- 10. Keyword/entity-based (active as entity chunks)
- 4. Paragraph-based (active as default)
- 8. Hybrid (recommended winner, needs implementation)

---

## Anything else? (motto_v4 §0.1.1)

**Q: Should we test combinations (e.g., header-based + table-aware)?**
A: Yes — the real production pipeline will likely use a ROUTER that applies
different strategies to different page types. The benchmark should test
individual strategies first to understand each one's contribution, then test
the best combinations.

**Q: What about chunk overlap?**
A: Overlap is a parameter within any strategy, not a strategy itself. We should
test overlap as a variable once we know the best base strategy. The sliding
window strategy (3) tests overlap directly.

**Q: Should we benchmark on more policies?**
A: The winning strategy should be validated on 3+ policy types (health, term,
auto). The harness is parameterized for this. For now, one real policy is
sufficient to rank strategies — the differentiator is table handling, which
is common across all insurance document types.
