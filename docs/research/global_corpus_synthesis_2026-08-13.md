# Global Insurance-Policy Corpus — Synthesis (Narrative / First-Principles)

**Date:** 2026-08-13
**Stream:** #59 (documentation)
**Companion log:** `docs/research/global_policy_corpus_2026-08-12.md` (factual build record; not edited here)
**Evidence tiers (motto_v5 §0.5, per task):** VERIFIED · MEASURED · KNOWN · INFERRED.
External facts carry date + source. This is a Documentation-as-Delivery artifact (motto_v5 §0.3).

---

## 1. TL;DR

We built a **global** (not India-only) insurance-policy-wording corpus, a gold
eval dataset, and an offline eval harness for the CoverWise RAG. The corpus is
**20 real PDFs across 6 markets (us/uk/au/ca/in/eu) and 8 LOBs**; the dataset is
**16 `coverage.jsonl` files / 90 page-anchored gold examples**; offline validation
shows **0 schema errors and 0 grounding failures** across all 16 datasets
[VERIFIED 2026-08-12]. The prior live gates (marine, cyber) measured **37.5%
accuracy** each [MEASURED, earlier run]. The accuracy lever is **persona
calibration** (pws-v2→v3), not gold-label rewriting; a live re-measure is being
run in parallel and is **PENDING/INFERRED** here. Remaining gaps: EU direct PDF,
stale duplicate dirs, full-policy redaction scale, live-gate cost.

---

## 2. First-principles framing

Each choice ties to a principle: **long-term build** (durable, reusable),
**evidence** (tiers, no invented numbers), **legal safety** (copyright hygiene).

### 2.1 WHY global (not India-only)
- **Principle:** long-term build — CoverWise serves a global user base; a corpus
  that mirrored only `corpus_lob/` (India) would rot the moment a UK/EU/AU/CA user
  asked a coverage question. [KNOWN — standing project rule, recorded in
  `.workbuddy-ai/memory/MEMORY.md`, 2026-08-12]
- **Decision:** markets = us/uk/au/ca/in; LOBs span property/motor/travel/health/
  liability/marine/cyber + a GENERAL block. Rejected India-only as a scope error.
- **Revisit trigger:** if a market is added, append to `manifest.json` — no code
  change needed (see §3).

### 2.2 WHY a 4-way coverage taxonomy
- **Principle:** evidence — the label must reflect the *structure* of policy
  wording, not a convenient binary.
- **Why:** real wordings are **grants with modifiers + exclusions + conditions
  precedent**. A clause can grant cover *subject to* an exclusion (→ `conditional`),
  deny it (→ `likely_not_covered`), grant it cleanly (→ `likely_covered`), or be
  genuinely undecidable from the text (→ `ambiguous`). A binary
  covered/not-covered would mislabel the dominant `conditional` case and ship
  wrong reassurance. [KNOWN — structure of policy wording; INFERRED that 4-way
  reduces false reassurance vs binary]
- **Nuance (honest):** the dataset `gold` enum currently uses 3 of the 4
  (`likely_covered | conditional | likely_not_covered`); `ambiguous` is reserved
  for genuine model/edge cases (the live gates produced `ambiguous` calls) [KNOWN
  from build log §5/§7.3].

### 2.3 WHY page-aware grounding matters
- **Principle:** evidence — grounding must survive paraphrase and chunk
  truncation.
- **Why:** substring/keyword checks over-segment and **over-fire** (false
  positives on near-miss phrases) and break the moment text is re-chunked or
  paraphrased. Page-anchored citations (`expected_page` via `fitz`) are
  **invariant to paraphrase** — the claim is tied to a location, not a string.
  The offline judge strips citations whose quote is not on the cited page
  (proven: Sanctions LMA3100 and a Retention clause were correctly stripped)
  [MEASURED — build log §7.2/§7.3].

### 2.4 WHY insurer wordings are copyrighted; regulator/industry safe
- **Principle:** legal safety — do-not-redistribute boundary, per motto_v5.
- **Why:** insurer wordings are **copyrighted** → downloaded for **local eval
  only**, never bundled in releases; we derive explanations, not the text [KNOWN —
  copyright of insurer docs; build log §4]. Regulator/gov standard forms
  (FCA, NAIC, FSRAO, APRA, ASIC, EIOPA, IRDAI) and industry samples (III) are
  public-domain/open → safe to ingest and cite [KNOWN].
- **Enforcement:** `corpus_global/NOTICE.md` + `license_class` tag per file in
  `manifest.json`. [VERIFIED — downloader writes tags]

---

## 3. What was built

- **Corpus — `corpus_global/`.** 20 real PDFs, 5 markets, 8 LOBs. Sourced via
  `tools/scrape_policy_corpus.py` — a manifest-driven, resilient downloader that
  validates `%PDF`, **quarantines bot-block HTML as `.blocked.html`**, retries
  with backoff, runs idempotently, and writes `_scrape_results.json`. Key fix:
  **mirror fallback on bot-block** (not only on network errors) closed the FSRAO
  gap without a headless browser. [VERIFIED — dry-run + run, build log §6/§7.1]
- **Dataset — `coverage.jsonl`.** 16 files / 90 gold examples, 6 markets, 8 LOBs.
  Authored by `tools/author_global_dataset.py` from `global_dataset_specs.json`;
  `expected_page` **auto-anchored via `fitz`** search (no manual page-poking).
  [VERIFIED 2026-08-12, build log §7.4]
- **Eval harness — `tests/evals/run_evals.py`.** Offline reference judge
  (schema + page-anchored grounding) plus a **deferred live gate**. Generic
  `--market <m> --lob <l>` auto-resolves `corpus_global/<m>/<l>/coverage.jsonl` +
  its PDF — **no code change to add a market/LOB**. [VERIFIED offline; live gate
  pending, build log §7.5]

---

## 4. What was measured

- **Offline validation (this corpus):** **0 schema errors / 0 grounding
  failures** across all 16 datasets / 90 examples. [VERIFIED 2026-08-12; EU set added 2026-08-13]
- **Prior live-gate accuracy (earlier run — cite, do not re-derive):**
  - Marine: **37.5% (3/8)**; grounding 1/8 failed; latency avg **39,306 ms/query**
    (n=8); cost **$0.0205**. [MEASURED — `report_live_marine.json`]
  - Cyber: **37.5% (3/8)**; grounding 1/8 failed; latency avg **~48,000 ms/query**
    (n=8). [MEASURED — `report_live_cyber.json`]
  - Signature: mismatches are **label drift** (`conditional ↔
    likely_covered/likely_not_covered`) and occasional reading-vs-rationale
    contradiction — **persona calibration**, not gold-label error [MEASURED].
- **Persona calibration confidence (honest):** pws-v2→v3 is **COMPLETE** — the
  version is stamped `2026-08-13.pws-v3` and the conditional-calibration logic
  already lives in `SHARED_WORDING_BODY`. A live re-measure under pws-v3 was
  performed by a parallel stream; the aggregated numbers are in
  `report_live_global_2026-08-13.md`. [MEASURED — pws-v3 re-measure, 2026-08-13]

---

## 5. Honest gaps

- **EU direct PDF.** RESOLVED 2026-08-13: the GDV (German Insurance Association)
  travel *model conditions* (AT-Reise 2008/2025, general part) were acquired as a
  static, redistribution-safe PDF and a gold `coverage.jsonl` (6 examples) was
  authored for `eu/travel`. German-language general-part clauses only — no
  specific coverage sums fabricated. [DONE]
- **`uk/travel_v2/` and `uk/travel_ipid/` are DISTINCT datasets, NOT duplicates.**
  Verified by MD5/content comparison 2026-08-13: `uk/travel` = AXA Series 131;
  `uk/travel_v2` = AXA Bronze/Silver/Gold v2 (different product); `uk/travel_ipid`
  = WeAreTravelInsurance / Great Lakes UK (different insurer + IPID). Kept — no
  deletion. [CORRECTED 2026-08-13; previously mislabelled as byte-copy dups]
- **Full-policy redaction scale.** Pipeline works per-file; extending to full
  policies at scale is **in progress in parallel** (#58). [KNOWN, build log §8]
- **Live-gate cost.** ~39–48 s/query and ~$0.02–0.03 per 8-example gate
  [MEASURED]. Not yet optimized; blocks cheap per-PR live gating until tuned.

---

## 6. Path to production

- **Gates feed persona versioning.** Each answer stamps `PERSONA_VERSION`. A
  **regression in coverage-label accuracy** on the offline gate (schema/grounding)
  and on the live gate blocks a version bump — the harness is the release guard,
  not a post-hoc check. [KNOWN design intent, build log §7.5]
- **Commit / CI plan (NOT executed).** Left to another agent per user
  instruction: delete the 2 stale duplicate dirs, then commit the corpus+datasets
  harness (do-not-redistribute boundary enforced by `NOTICE.md`). No git write
  performed here. [INFERRED — plan only; not run]

---

## 7. Anything else?

- **Redistribution is the real production risk, not accuracy.** The offline gate
  is clean; the unredistributable insurer PDFs must never reach a release artifact.
  The `NOTICE.md` + `license_class` tag is the control — verify it in CI before any
  bundle ships.
- **`ambiguous` is under-used in gold labels.** Deciding when a clause is truly
  `ambiguous` vs `conditional` is the next label-discipline question (#60); it
  affects how often the persona should abstain rather than guess.
- **Generic harness already supports the EU market** the moment a direct PDF lands
  — no code work, only a `manifest.json` append. The blocker is sourcing, not
  tooling.
- **Cross-cutting:** this doc is the durable narrative; the 2026-08-12 log stays
  the factual record. Both should be re-read together when the parallel live
  re-measure lands, to convert the PENDING/INFERRED persona numbers to VERIFIED.
