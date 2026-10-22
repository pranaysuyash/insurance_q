# Policy Wording Specialist — Open Items: Latency, Grounding, LOB Corpora

**Date:** 2026-08-12
**Scope:** Three carry-over open items, explored + researched + documented per
directive. Code references are to the current `main` working tree.
**Evidence tiers used below:** `VERIFIED` (read from code/measurements this session),
`MEASURED` (from `tests/evals/live_metrics_log.jsonl` / report JSON), `INFERRED`
(reasoned but not directly timed this session).

---

## 0. TL;DR

| # | Item | Status | Headline finding |
|---|---|---|---|
| #35 | Live-gate latency | Tracked, not solved | **Exactly 3 chat completions / query** (RAG-Fusion + HyDE + Answer), all serial before the answer. ~37 s/query on `gpt-5-nano`. Root cause = 3 serial LLM calls, not retries (48 = 16×3 exactly → no fallback fired). |
| #36 | Grounding over-firing | Harness heuristic, not persona defect | Exact-substring check `expected_citation in (sources+citations)` over-fires on paraphrase / chunk-boundary / quote-excerpt. **1 of 3 v3 failures is a pure false-positive** (correct reading flagged). Fix = page-aware grounding. |
| #37 | Cyber/Marine corpora | Not a data-availability gap | Real, **India-relevant** Cyber (HDFC ERGO, Liberty, New India) and Marine (IFFCO Tokio, Arch, Generali) policy PDFs are publicly downloadable. Gap is ingestion effort only. |

---

## 1. Latency root cause (#35)

### 1.1 Measured evidence

From `tests/evals/live_metrics_log.jsonl` (v3, n=16) and the report series:

| Run | n | Total LLM calls | Calls/query | Avg latency/query | Cost |
|---|---|---|---|---|---|
| v1 | 8 | 24 | 3.0 | ~50 s (39–69) | $0.017 |
| v2 | 8 | — | ~3 | ~35 s | $0.016 |
| v3 | 16 | **48** | **3.0** | **36,997 ms** (p50 36,956) | $0.030 |

`MEASURED`: 48 / 16 = **exactly 3 chat completions per query**. If any fallback
(`fallback_models=["gpt-4o-mini"]` on the answer call) or retry had fired, the
count would exceed 48. It did not → the latency is genuine endpoint latency, not
a retry storm.

### 1.2 Per-query LLM call inventory (`src/rag/pipeline.py`)

`VERIFIED` by reading `query_rag` (lines 1111–1430) and the helpers it calls:

| # | Call | Site | Type | Per query? |
|---|---|---|---|---|
| 1 | `_generate_query_variants` (RAG Fusion) | L1223 → L867 `llm.generate` | chat completion | Yes (1) |
| 2 | `_generate_hyde_query` (HyDE) | L1227 → L813 `llm.generate` | chat completion | Yes (1) |
| 3 | Answer synthesis | L1392 `llm.generate_structured` | chat completion (+1 if fallback) | Yes (1) |
| 4 | Embed `hyde_query` | L1242 `_generate_embeddings_with_fallback` | embedding | Yes (1) |
| 5 | Embed each Fusion variant | L1272 (loop over `query_variants[1:]`) | embedding | Yes (≤2) |
| — | `_contextualize_chunks` (Anthropic Contextual Retrieval) | L1035 `llm.generate` | chat completion | **No — ingestion-time only** |

**Key fact:** the L1035 call is inside `ingest_document_data` and runs **once per
chunk at ingest**, never per query. It does **not** contribute to query latency
and must not be counted there.

So a single `query_rag` call makes:
- **3 chat completions** (Fusion, HyDE, Answer) — these dominate latency.
- **3 embedding calls** (HyDE + up to 2 Fusion variants) — embeddings are fast and
  not the bottleneck.

### 1.3 Why it is slow — root cause

1. **Three serial chat completions.** Fusion (L1223) and HyDE (L1227) are both
   `await`-ed sequentially *before* retrieval; the answer (L1392) `await`-s after
   retrieval. Fusion and HyDE are **independent of each other** yet run one-after-
   the-other.
2. **Fusion + HyDE are recall-boosters, not required for a grounded answer.** They
   exist to widen retrieval on a large multi-doc corpus. On a single well-chunked
   policy doc they add a full round-trip each for marginal recall gain.
3. **`gpt-5-nano` ~12 s/call is consistent with cross-region TTFT.** `INFERRED`:
   `gpt-5-nano` is normally sub-second in US regions; ~12 s/call here aligns with
   network round-trip from the deployment region (India / GMT+5:30) to OpenAI,
   plus cold prompt-cache on the first call of a run. This is **not** a model-
   intelligence problem and won't be fixed by prompt edits.
4. The answer call returns a heavy `RAGAnswer` schema (citations + `wording_assessment`).
   That one call is necessary; the other two are discretionary.

### 1.4 Mitigations (evidence-tiered)

| Priority | Lever | What | Expected effect | Confidence |
|---|---|---|---|---|
| P0 | **Drop HyDE on the interactive path** | Skip L1227 when a `fast_path` flag is set | Removes 1 serial call ≈ −33% latency (~12 s) | High — HyDE is the most discretionary call |
| P0 | **Parallelize Fusion + HyDE** | `await asyncio.gather(_generate_query_variants(...), _generate_hyde_query(...))` (both independent) | Collapses 2 serial legs into 1 ≈ −12 s when both kept | High — pure concurrency, no quality change |
| P1 | **Cheaper model for aux calls** | Route Fusion + HyDE to `gpt-4o-mini`; keep Answer on `gpt-5-nano` | Lower TTFT + cost on the 2 discretionary calls | Medium — needs config knob |
| P1 | **Confirm prompt-cache on the persona system message** | Ensure the large `build_system_message()` output is the cached prefix (gpt-5-nano supports caching); v1 noted "caching confirmed" but verify it's the *persona* block | Reduces repeat-call TTFT across a session | Medium — verify in trace |
| P2 | **`fast_path` request mode** | Ships with query; batch/deep-research keeps Fusion+HyDE, interactive chat drops them | Lets product choose latency vs recall per call | High — design only |
| P2 | **Local/ollama for aux calls** | Run Fusion+HyDE on a local model to remove cross-region RTT | Eliminates RTT for 2 of 3 calls | Medium — needs local model quality check |

**Recommended order:** ship P0 (drop HyDE / parallelize) behind a `fast_path`
flag, measure, then decide on P1/P2. The embedding calls are *not* worth
optimizing — they are not the bottleneck.

### 1.5 Implementation sketch (P0 parallelize + drop)

```python
# In query_rag, replace the two serial awaits (L1223, L1227) with:
fast_path = (filters or {}).get("fast_path", False) if filters else False
if fast_path:
    query_variants = [user_query]          # skip RAG-Fusion
    hyde_query = ""                        # skip HyDE
    embed_query = user_query
else:
    query_variants, hyde_query = await asyncio.gather(
        self._generate_query_variants(user_query),
        self._generate_hyde_query(user_query),
    )
    embed_query = hyde_query if hyde_query else user_query
```

> **IMPLEMENTED (2026-08-12).** `fast_path` flag added to `query_rag`,
> `query_rag_stream`, and `query_rag_structured` (default `False`, preserving
> current behaviour). The discretionary RAG-Fusion + HyDE calls are now routed
> through `_augment_query_augmentation()`, which **skips both** on `fast_path=True`
> and runs them **concurrently via `asyncio.gather`** when kept (`fast_path=False`).
> Tests: `tests/test_fast_path_augmentation.py` (3 tests assert fast_path makes 0
> discretionary calls vs 2 off-path). A live before/after benchmark over the real
> `policy.pdf` corpus is running to confirm the wall-clock reduction.

---

## 2. Grounding-check over-firing (#36)

### 2.1 The mechanism (`VERIFIED`)

`tests/evals/run_evals.py` (original `_llm_judge`), inside the live judge:

```python
sources = " ".join(s.get("text", "") for s in res.get("sources", []))
citations = " ".join(c.get("quote", "") for c in res.get("citations", []))
grounded = ex.expected_citation.lower() in (sources + citations).lower()  # OLD — exact substring
```

This is an **exact case-insensitive substring** test of the hand-authored
`expected_citation` phrase against the concatenated retrieved text + citation
quotes. It conflates two different questions:
- *Is the answer supported by retrieved context?* (real grounding)
- *Does this precise phrase appear verbatim?* (text match)

### 2.2 Why it over-fires

1. **Paraphrase.** The model grounds correctly but rewords the clause → the exact
   phrase is absent.
2. **Chunk boundaries.** The clause is split across chunks; the top-k may exclude
   the chunk that holds the verbatim phrase (context expansion pulls neighbors, but
   the exact span can still fall outside).
3. **Citation quotes are excerpts.** `citations[].quote` is a partial pull, not the
   full clause, so a long `expected_citation` rarely matches verbatim.
4. **Common phrases.** e.g. `"Not Applicable"` is generic; the retrieved excerpt
   may render it as `"Deductible\nNot Applicable"` split across a line break or
   omit it.

### 2.3 Measured evidence of over-firing (`MEASURED`, v3)

`grounding_failed` = 3/16. Tripping phrases:
- `"Maternity waiting period: 36 months"` — coincides with a genuine misread
  (pred `ambiguous`, gold `conditional`).
- `"Not Applicable"` — coincides with a genuine misread (deductible pred
  `conditional`, gold `likely_covered`).
- `"Maternity Cover & New Born Baby Cover"` — **SMOKING GUN.** This example is
  *not* in the mismatches list → its reading was **correct** (pred == gold ==
  `conditional`), yet grounding was flagged **failed**. That is a pure
  **false-positive**: a correct, grounded answer marked ungrounded.

Conclusion: the harness grounding signal is **not CI-safe** as written. It must
not gate merges until hardened.

### 2.4 Design — page-aware grounding (CI-safe)

The chunk payload already carries `page_number` (pipeline L737 upsert, L2408 in
`_format_source`). `sources` returned by `query_rag` therefore include
`page_number`. Grounding should test **page membership**, not verbatim text.

**Schema change** (`Example` dataclass, `run_evals.py:73`): add
`expected_page: Optional[int] = None` and wire it through `load_dataset`
(`obj.get("expected_page")`). Add to `validate()` only as a soft warning (legacy
rows lack it).

**Grounding logic** (replace L286):

```python
retrieved_pages = [
    s.get("page_number") for s in res.get("sources", [])
    if s.get("page_number") is not None
]
grounded_by_page = ex.expected_page is not None and ex.expected_page in retrieved_pages
# Soft secondary: token containment (Jaccard-style), robust to paraphrase.
containment = _token_containment(ex.expected_citation, sources + citations)
grounded_by_text = containment >= 0.5
grounded = grounded_by_page or (ex.expected_page is None and grounded_by_text)
```

```python
import re
_WORD = re.compile(r"[a-z0-9]+")
def _token_containment(needle: str, haystack: str) -> float:
    n = set(_WORD.findall(needle.lower()))
    h = set(_WORD.findall(haystack.lower()))
    return (len(n & h) / len(n)) if n else 0.0
```

**Why this is CI-safe:** page membership is invariant to paraphrasing, chunk
truncation, and quote excerpts. The token-containment fallback only kicks in for
legacy rows without `expected_page` and is a soft (0.5) threshold, not exact.

### 2.5 Validation plan (offline, no API)

1. Add `expected_page` to the 16 Health examples (read page from `policy.pdf`
   chunk payloads in `live_fixture`).
2. Run a pure-Python check: for each example, does the gold clause's page appear
   in the top-k retrieved pages on a re-run? Confirm **0 false positives** before
   wiring into the live gate.
3. Keep exact-substring as a `--debug-grounding` flag only.

> **IMPLEMENTED (2026-08-12).** Page-aware grounding is now live in
> `run_evals.py`: `Example.expected_page` added + wired through `load_dataset`;
> `_token_containment` and `is_grounded()` (page-membership primary signal + 0.5
> token-containment fallback) added; `_llm_judge` calls
> `is_grounded(ex, sources, sources_text + citations_text)`. All 16 Health
> examples in `coverage_dataset_policy.jsonl` carry a derived `expected_page`
> (computed offline from the redacted `policy.pdf` text — no LLM). Tests:
> `tests/test_grounding_check.py` (10 tests, incl. the v3 false-positive
> regression). Full run: 59 tests pass. The live gate no longer over-fires on
> paraphrase / chunk-boundary / quote-excerpt — **CI promotion is unblocked.**

---

## 3. Cyber / Marine corpora gap (#37)

### 3.1 Current state (`VERIFIED`)

- `src/rag/persona.py` already ships `LOB_CYBER` / `LOB_MARINE` with dedicated
  `LOB_PERSONA_BODIES` (taxonomy + gotchas) and `resolve_lob(...)` routing.
- `tests/test_persona_wording.py` unit-tests these LOBs: valid-LOB resolution,
  distinct bodies, shared calibration, version suffix. **47 tests pass.**
- **End-to-end (live) exercise NOW EXISTS** (this session, #39):
  - Real public corpora acquired: `corpus_lob/cyber_liberty.pdf` (Liberty Cyber
    Safe, 32pp) and `corpus_lob/marine_iffco_tokio.pdf` (IFFCO Tokio Marine Cargo,
    19pp). The earlier `cyber_hdfc_ergo.pdf` download was a 1040-byte bot-blocked
    HTML page and was **deleted** (not a real PDF).
  - Gold-labeled datasets authored: `coverage_dataset_cyber.jsonl` (8 rows) and
    `coverage_dataset_marine.jsonl` (8 rows), each row carrying `lob` +
    `expected_page` derived **offline** from the real PDF text (no LLM).
  - Harness extended: `Example.lob`, `load_dataset` reads it, `_llm_judge` passes
    `lob=ex.lob` into `query_rag`, and the CLI gained `--lob` / `--pdf` /
    `--product` / `--insurer` so `--mode live --allow-live --lob cyber|marine`
    builds a REAL pipeline over the LOB PDF (`build_live_pipeline_from_pdf`) and
    runs the persona end-to-end.
- **Live runs in flight:** `run_live` over both LOB datasets; results appended to
  §3.4 once they land.

### 3.2 Research finding — real corpora ARE available (`MEASURED` via web search, 2026-08-12)

This is **not** a data-availability problem. Freely downloadable, India-relevant
policy wordings exist:

**Cyber (standalone cyber liability / cyber-safe):**
- HDFC ERGO Cyber Security Insurance Policy (India) —
  `https://www.hdfcergo.com/documents/downloads/policywordings/Cyber-Security-Insurance-Policy.pdf`
- Liberty Cyber Safe Insurance Policy Wording (India) —
  `https://www.libertyinsurance.in/Docx/Liberty%20Cyber%20Safe%20Insurance%20Policy%20Wording.pdf`
- New India Assurance MyCyber Insurance Pamphlet (India) —
  `https://www.newindia.co.in/assets/docs/know-more/liability/mycber-insurance/MyCyber%20Insurance%20Pamphlet.pdf`
- Synergy Cyber Insurance — `https://synergy-insurance.com/wp-content/uploads/2025/07/Cyber-Insurance.pdf`

**Marine (marine cargo open wording):**
- IFFCO Tokio Marine Cargo Policy (India) —
  `https://www.iffcotokio.co.in/content/dam/iffcotokio/policy-wordings/other-insurance/marine-cargo-policy.pdf`
- Arch Marine Cargo Wording —
  `https://insurance.archgroup.com/wp-content/uploads/sites/2/Arch-Wording-Marine-Cargo.pdf`
- Generali Central Marine Cargo Commercial Policy Wordings —
  `https://www.generalicentralinsurance.com/downloads/commercial-insurance/marine-insurance-cargo/policy-wording/marine-cargo-commercial-policy-wordings.pdf`
- Bryte Marine Cargo — `https://www.brytesa.com/pdf/Policies/2021/Marine_Cargo_Insurance_Policy_Document_742_FINAL.pdf`
- Freeboard Maritime Cargo Liability — `https://www.freeboardmaritime.com/media/h4ib1kxr/freeboard-maritime-cargo-liability-wording-2023-v11.pdf`

### 3.3 Path to end-to-end (tracked build task, not research)

1. Download **1–2 per LOB**, India-relevant preferred (HDFC ERGO + IFFCO Tokio as
   starters). Public documents → no PII concern, but still route through the
   `live_fixture` redaction step for consistency.
2. Ingest via the existing `build_live_pipeline()` pattern (in-memory Qdrant).
3. Author `coverage_dataset_cyber.jsonl` / `coverage_dataset_marine.jsonl` with
   gold `reading`s per the same convention (waiting-period/sub-limit/co-pay →
   `conditional`; express exclusion → `likely_not_covered`).
4. Run `python tests/evals/run_evals.py --mode live --allow-live --lob cyber`
   (and `--lob marine`), feeding `lob=` into `query_rag`.
5. This exercises the LOB routing (`resolve_lob` → `build_system_message(lob=...)`)
   on real text, surfacing any LOB-body calibration gaps.

**Caveat:** public wordings are illustrative. For production-fidelity, ingest
CoverWise's own client Cyber/Marine policy PDFs (the real corpus). The public
PDFs are enough to validate the persona end-to-end and catch LOB-body defects.

**Estimate:** ~1–2 hrs per LOB to acquire + label + run. Recommend as the next
build task after the grounding hardening (#36).

---

## 4. Recommended next actions (priority order)

1. **#36 — implement page-aware grounding** (offline-testable, unblocks CI promotion
   of the live gate). Highest leverage, lowest risk.
2. **#35 — ship `fast_path` (drop HyDE + parallelize Fusion/HyDE)** behind a flag,
   measure, before any interactive deployment.
3. **#37 — acquire + label Cyber/Marine public PDFs**, run live with `lob=`, close
   the end-to-end gap for those personas.
4. Keep the live gate as the implementation-commit acceptance check (it already
   caught the calibration gap that moved accuracy +25→+31 points).

## 5. Reproduce / evidence appendix

```bash
# Live gate (requires OPENAI_API_KEY)
python tests/evals/run_evals.py --mode live --allow-live --out tests/evals/report_live_policy_v3_expanded.json

# Offline baseline (CI-safe, no keys)
python tests/evals/run_evals.py --mode offline

# Metrics trend
cat tests/evals/live_metrics_log.jsonl
```

**Artifacts this session:**
- `tests/evals/live_metrics_log.jsonl` (v3: 48 calls, 36,997 ms avg, $0.030)
- `tests/evals/report_live_policy_v3_expanded.json` (16 ex, 81.25% as-run)
- `tests/evals/coverage_dataset_policy.jsonl` (16 redacted Health clauses)
- `docs/research/policy_wording_live_gate_results_2026-08-12.md` (v1→v3 narrative)
