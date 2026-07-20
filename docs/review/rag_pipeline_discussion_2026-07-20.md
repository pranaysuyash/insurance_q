# RAG Pipeline Discussion — 2026-07-20
**Session:** e3d3b058 (Antigravity)  
**Participants:** Pranay (operator), Antigravity AI (agent)  
**Companion docs:**  
- [`rag_pipeline_exploration_map_2026-07-20.md`](rag_pipeline_exploration_map_2026-07-20.md) — system findings  
- [`ADR-2026-07-20-26-rag-pipeline-excellence.md`](../decisions/ADR-2026-07-20-26-rag-pipeline-excellence.md) — decision record  

---

## Context

Operator requested: "look at the rag pipeline and make it the best in terms of everything a RAG is supposed to be — searchable, referenceable, traceable, grounded, embedded, linkages/nodes/graphs and more. First explore RAG and related areas, document, update exploration maps, then discuss before proceeding."

Full codebase exploration was performed across all RAG-related files (see exploration map). Five open questions were identified. Operator asked for first-principles answers from motto_v4 before approving the plan.

---

## Q1: Supabase FTS — `tsvector` vs `pg_trgm`?

**Agent position:** Both. They are not alternatives. They serve fundamentally different retrieval patterns.

**Reasoning:**
Insurance policy documents have two irreconcilable search patterns:
1. Natural language queries ("what is not covered for dental") — tokenized-text problems. Postgres `tsvector` with GIN index handles this correctly: stemming, IDF weighting, stopwords, native to Postgres, zero operational overhead.
2. Identifier/structured-string lookups ("policy number 4214i/CPHSR/407834350") — `tsvector` tokenizes by word boundary and will split the policy number into `4214i`, `cphsr`, `407834350`. A query for the full string fails. `pg_trgm` with GIN on raw `content` matches overlapping 3-character sequences regardless of delimiters — correct for identifiers, policy numbers, codes, rupee amounts.

**Motto v4 §0.15 (Third-Layer Rule):** "The data/configuration layer determines normalization, lookup, interpretation, product rules." FTS strategy is a data layer decision. It must match the shape of the data.

**Decision:** Add both to `document_chunks`. `tsvector` generated column for clause/semantic text. `pg_trgm` GIN index on `content` for identifier lookup. RPC function runs both and merges. 40 lines of SQL migration. This decision will not be revisited.

---

## Q2: Graph Backend — JSON adjacency column vs. `chunk_links` table?

**Agent position:** Normalized `chunk_links` table. JSON adjacency is a dead end.

**Reasoning:**
A JSON adjacency column (`adjacent_ids JSONB`) on `document_chunks` appears simpler but violates three things:

1. **Referential integrity** — JSON columns have no FK constraints. Chunk deletion or re-indexing leaves the adjacency silently dangling. A `chunk_links` table with FK + ON DELETE CASCADE cannot go stale.

2. **Query expressiveness** — Graph traversal is a JOIN. `SELECT * FROM chunk_links WHERE source_chunk_id = $1` is one indexed join. The JSON path requires `jsonb_array_elements_text()` + lateral join — slower, unindexable on the target ID, not composable with type filters ("adjacent chunks of type `exclusion`").

3. **Motto v4 §0.12.4 (Cut/Keep/Finish):** "A feature that is part of the long-term shape is finished properly even when expensive." Graph linkage is in the long-term shape. Using a JSON blob because it "looks simpler" is the small-patch anti-pattern motto v4 explicitly rejects.

The table is 4 columns: `(source_chunk_id UUID, target_chunk_id UUID, link_type TEXT, weight FLOAT)`. Not expensive. The JSON path creates an upgrade migration later that is.

**Addendum:** `section_type` (definition/exclusion/benefit/etc.) is a column on `document_chunks`, not in `chunk_links`. It's an intrinsic attribute of a chunk, not a relationship.

**Decision:** `chunk_links` normalized table with FK constraints and both-direction indexes.

---

## Q3: Contextual Retrieval — Enable in this pass?

**Agent position:** Yes, but as a feature flag with explicit operator control. Not a silent code change. Gated on eval evidence (Commit 5 must run first).

**Reasoning:**
Contextual retrieval was disabled after the trust audit (`CONTEXTUAL_RETRIEVAL_ENABLED=false`) because `source_text` / `retrieval_text` separation was unverified. The 2026-07-20 audit shows this is still PARTIAL: "ADR-11 Layer 1-2 shipped; `retrieval_text` field exists but backfill not complete."

Motto v4 §0.5 (Evidence Tiers): extraction and normalization pipelines are explicitly high-risk paths requiring Tier 3+ before calling done. Flipping contextual retrieval on while backfill is incomplete creates two embedding contracts in the same collection — old chunks with `retrieval_text == source_text`, new chunks with LLM-contextualized `retrieval_text`. The query path cannot distinguish them. The embedding space becomes inconsistent.

**Correct path:**
- This pass: expose `CONTEXTUAL_RETRIEVAL_ENABLED` as an operator-controllable feature flag (not just env var) — toggleable per-collection without a redeploy.
- Commit 5: build eval corpus and run RAGAS baseline.
- Commit 6: complete backfill + flip flag + re-run eval to confirm faithfulness doesn't degrade. Gate the global enable on eval evidence showing improvement in context_recall without faithfulness regression.

Motto v4 §0.12.2 (ADR-first): An ADR is written for "contextual retrieval re-enable conditions" before implementation. See ADR-26.

---

## Q4: Eval Corpus — Generate from `policy.pdf` or use real documents?

**Agent position:** Both, in sequence. Start with `policy.pdf` (ground-truth verifiable), then extend to 3+ real policies.

**Reasoning:**
The existing 22-question fixture has a critical flaw: expected answers are hardcoded strings (`"4214i/CPHSR/407834350/00/000"`) correct for exactly one document. This is Tier 1 evidence. The audit explicitly classifies it as "NOT DONE — benchmark is 12-fixture-query dry run, not decision-grade."

Motto v4 §0.5: "For high-risk paths, require Tier 3 or higher before calling done." RAG evaluation is a high-risk path — it gates every claim about retrieval quality.

A proper eval corpus needs:
1. **Document-anchored ground truth** — expected answers must quote or reference actual source text in the actual document. Q&A pairs generated from the document, not assumed from memory.
2. **Category coverage** — exact field lookup, numeric, date, clause semantic, exclusion, cross-reference, comparison, negative examples.
3. **Negative examples** — "not mentioned in this policy" questions are as important as positive ones. They test hallucination resistance.
4. **Multiple documents** — minimum 3 policies from different insurers.

The eval corpus is a **data asset** (motto_v4 §0.8): versioned, reviewed, in `docs/eval/corpus/`, not a throwaway script. CI must fail when scores regress.

**Decision:** Phase A: 80-100 Q&A pairs from `policy.pdf` using the evidence substrate (extracted fields are ground truth) + manual review of 15-20 semantic questions. Phase B: 2 more real policies, 30-40 questions each.

---

## Q5: Citation Verifier Strictness — Exact substring or fuzzy?

**Agent position:** Exact as the pass gate. Fuzzy as a warning tier in UI. Fail = citation stripped entirely.

**Reasoning:**
This looks like a practical tradeoff but is actually a trust boundary decision. The citation verifier's purpose (ADR-2026-07-19-09) is: "no customer-visible quote can originate from generated context." The domain is insurance. A user reads a quote and taps "see on page." They see the actual policy PDF. If the displayed quote doesn't appear verbatim, they know the system hallucinated. That is a trust-destroying UX event.

Motto v4 §0.11 (Customer-Facing Claims Rule): "Any customer-facing claim must be checked for... whether the UI implies a stronger guarantee than the system can provide." A fuzzy-matched citation that passes verification but doesn't appear verbatim is a claim the system cannot operationally support.

**The correct model is three tiers, not a softer check:**
- **Tier 1 (exact match, normalized whitespace):** `is_valid = True`. Citation shown with page link, highlighted text.
- **Tier 2 (exact fails, fuzzy ≥ 70% token overlap):** `is_valid = False`, `warning = "paraphrase_detected"`. Citation shown in visually distinct state (gray, no page link, "approximate match"). User can read it; system is honest it's paraphrased.
- **Tier 3 (fuzzy fails too):** `is_valid = False`, `rejection_reason = "quote_not_in_source"`. Citation stripped from response. Answer still shown, minus the citation.

This preserves information, is honest, and is auditable. Directly satisfies motto_v4 §0.10 (Observability Is Delivery): the operator can see why a citation was stripped.

---

## Summary of Decisions

| Question | Decision |
|----------|----------|
| FTS strategy | Both: `tsvector` (clauses) + `pg_trgm` (identifiers) |
| Graph backend | Normalized `chunk_links` table with FK constraints + `section_type` column on chunks |
| Contextual retrieval | Feature flag + backfill + eval gate (Commit 6, gated on Commit 5) |
| Eval corpus | Phase A: `policy.pdf` 80-100 Q&As; Phase B: 3+ policies |
| Citation strictness | Exact = pass, fuzzy = UI warning, fail = citation stripped |

---

## Operator Sign-off

Operator instruction: "write the plan with these baked in, document the discussion overall including the findings and suggestions, opinions etc. [...] do all"

This constitutes operator sign-off on the five decisions above and approval to execute all 6 commits.
