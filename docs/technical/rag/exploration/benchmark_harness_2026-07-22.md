# CoverWise Chunking/Parsing Benchmark Harness

**Date:** 2026-07-22
**Purpose:** Empirically test multiple chunking and parsing strategies against
the same set of questions on a real Indian insurance policy, to get evidence
(not theory) for which approach produces the best retrieval and answer quality.

**Source document:** ICICI Lombard Health Shield 360 Retail policy (real,
password-protected, 16 pages, 45,115 chars)

---

## Ground truth (known answers from the policy)

These are the facts the benchmark questions target. A strategy "passes" a
question if the retrieved chunks contain the information needed to answer it,
AND the generated answer matches the ground truth.

| # | Question | Ground truth answer | Key text in document |
|---|---|---|---|
| Q1 | What is my policy number? | 4214i/CPHSR/407834350/00/000 | "Policy No." label + value (table, p1) |
| Q2 | What is my sum insured? | ₹25,00,000 (2500000) | "Annual Sum Insured (₹)" label + 2500000 (table, p1) |
| Q3 | What is my premium amount? | ₹31,705 | "Total Premium" label + 31705 (table, p1) |
| Q4 | Who is the proposer? | Pranay Suyash | "Proposer Name" label + value (table, p1) |
| Q5 | What is the policy period? | 27-Aug-2025 to 26-Aug-2026 | "Period of Insurance" label + dates (table, p1) |
| Q6 | What is the insurer name? | ICICI Lombard General Insurance | Header/footer text (all pages) |
| Q7 | What is the product name? | Health Shield 360 Retail | "Product name" label + value (table, p1) |
| Q8 | What is the loyalty bonus? | ₹7,00,000 (700000) | "Loyalty Bonus" label + 700000 (table, p1) |
| Q9 | Who are the insured members? | Pranay Suyash (SELF), Diksha Sinha (SPOUSE), Advay Sinha (SON) | Insured table rows (p1) |
| Q10 | What is the toll-free helpline? | 1800 2666 | Footer text (p1) |

**Why these questions:** Q1-Q5 and Q8 are the hardest — they require
connecting a table label to a table value across separate PyMuPDF text blocks.
Q6-Q7 and Q10 are easier (single text block). Q9 requires matching multiple
table rows.

---

## Strategies under test

### Strategy A: Current (paragraph + context header)
- **Chunking:** Split on `\n\n` + section headers, 1000-char blocks
- **Context:** `_build_doc_context_header` prepends key fields to every chunk
- **Tables:** NOT serialized as tables — flattened into text blocks
- **This is what's running in production right now**

### Strategy B: Table-aware chunking
- **Chunking:** Same paragraph splitting for prose
- **Tables:** `find_tables()` output serialized as Markdown tables, each table
  becomes an atomic chunk: `| Annual Sum Insured (₹) | 2500000 |`
- **Context:** Same doc context header
- **Expected improvement:** Q1, Q2, Q3, Q5, Q8 should improve (label+value in
  same chunk)

### Strategy C: Page-level chunking
- **Chunking:** Each page's full text as a single chunk (no splitting within
  page)
- **Context:** Same doc context header
- **Expected behavior:** Larger chunks = more context per chunk, but lower
  precision. Q1-Q10 should all work since page 1 contains everything, but
  retrieval precision may drop for questions about later pages.

### Strategy D: Table-aware + page-level hybrid
- **Chunking:** Page-level for prose pages, table-serialized for table pages
- **Context:** Same doc context header + section path metadata
- **Expected improvement:** Best of both worlds — precision for table
  questions, recall for prose questions

### Strategy E: Contextual retrieval (LLM-enriched)
- **Chunking:** Strategy A chunks
- **Context:** LLM generates a 1-2 sentence context for each chunk ("This is
  from the ICICI Lombard Health Shield 360 schedule page, showing a sum insured
  of ₹25 lakhs")
- **Expected improvement:** ~49% retrieval failure reduction per Anthropic data
  (verify against this corpus)

---

## Scoring methodology

For each question × strategy combination:

1. **Retrieval score (0-1):** Did the top-K retrieved chunks contain the
   information needed? 1 = clearly present, 0.5 = partially, 0 = absent
2. **Answer accuracy (0-1):** Did the LLM-generated answer match ground truth?
   1 = exact match, 0.5 = partially correct, 0 = wrong/not found
3. **Source quality (0-1):** Were the cited sources the right page/section?
   1 = correct source, 0 = wrong or no source

**Overall strategy score = average across all 10 questions.**

---

## Execution plan

1. Build the benchmark script (`tools/benchmark_chunking.py`)
2. For each strategy:
   a. Parse the policy PDF with password
   b. Chunk using the strategy
   c. Index chunks into a temporary in-memory vector store
   d. Run all 10 questions
   e. Score retrieval + answer + source
3. Output results as a comparison table
4. Document findings and update the exploration map

---

## Anything else? (motto_v4 §0.1.1)

**Q: Should we test different embedding models too?**
A: Yes, but separately. The chunking benchmark isolates the parsing/chunking
layer by holding the embedding model constant (text-embedding-3-small). Once
we know the best chunking strategy, we can A/B embedding models on top of it.

**Q: Should we test different rerankers?**
A: Same — hold the reranker constant (ms-marco-MiniLM-L-6-v2) during the
chunking benchmark. Reranker comparison is a separate experiment.

**Q: What about the evidence substrate?**
A: The substrate is a deterministic key-value extraction layer that runs in
parallel to RAG. It's not a chunking strategy — it's a different system
entirely. We should benchmark it too ("can regex extractors find the sum
insured?") but it doesn't compete with chunking — it complements it.

**Q: Why not use the full policy text (all 16 pages) for the benchmark?**
A: We are. The policy is 16 pages, 45K chars. The 10 questions target page 1
(the schedule table) and footer text because that's where the structured data
lives. Questions about later pages (exclusions, terms) would test prose
retrieval, which all strategies handle similarly. The differentiator is table
extraction, which is concentrated on page 1.
