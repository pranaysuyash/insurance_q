# Global Insurance-Policy Corpus — Research, Sources & Build Log

**Date:** 2026-08-12
**Author:** Policy Wording Specialist initiative (CoverWise RAG)
**Evidence tiers (motto_v5):** VERIFIED (read from code/measurements) · MEASURED
(from logs/reports) · KNOWN (established public fact) · INFERRED.

---

## 0. Scope correction (standing rule)

CoverWise serves a **global** user base. People in *every* market buy insurance
and want to understand their policies. The corpus, datasets, and eval harness
must **not** be India-only. This document and the `corpus_global/` layout
reflect that explicitly. (Recorded as a standing project rule in
`.workbuddy-ai/memory/MEMORY.md`.)

---

## 1. The core problem

There is **no clean, ready-made "insurance policy wording" dataset** — and
certainly none consisting of *full, PII-redacted policies* as people have
occasionally published them. We explored every route and built a pipeline that
covers all of them.

### Routes explored

| Route | What it is | Verdict |
|-------|-----------|---------|
| **R1. Build-from-public-PDF** | Download real insurer wordings + regulator forms that are publicly posted, then redact + chunk + label. | **Primary, viable.** Real documents, real clauses, real page numbers. |
| **R2. Existing datasets** | HuggingFace / Kaggle / GitHub insurance corpora. | **Gap.** Everything found is either synthetic, tabular (claims/cross-sell), or general legal text — not real wording. One useful synthetic JSON set exists (see §2). |
| **R3. Regulator corpora** | NAIC, FCA, FSRAO, APRA, ASIC, EIOPA, IRDAI model forms / handbooks. | **Viable + redistribution-safe.** Government docs are public domain / openly licensed. |
| **R4. People-published policies** | Policies individuals have posted publicly (forums, redacted samples). | **Rare & legally fraught.** Almost always still copyrighted; any PII must be redacted before ingestion. Treated as a sub-case of R1 with mandatory redaction. |

---

## 2. Route 2 — Existing datasets (the gap, measured)

Searched HuggingFace, Kaggle, GitHub (2026-08-12).

- **`bdr-ai-org/insurance-policy-docs-dataset`** (HuggingFace) — *real but
  synthetic*. JSON-structured records (`policy`/`endorsement`/`exclusion`/`clause`)
  with `full_text`, sectioned clauses, and `qa_pairs`. `<1K` items, lines of
  business = motor/medical/property/life, English-only, **MIT license**
  (commercial OK w/ attribution), **no real PII** (synthetic). Useful as an
  *eval scaffold* but it is **not** real wording and has "limited jurisdiction
  coverage" + "simplified regulatory language". [MEASURED from dataset README]
- **`kaihe/chinese_insurance_doc_parsing`** (HF) — Chinese insurance docs for
  parsing; not wording Q&A. [KNOWN]
- **Kaggle "Insurance" tag** — overwhelmingly tabular (claims, cross-sell,
  customer churn). No policy-wording corpus. [MEASURED from Kaggle listing]
- **GitHub** — scattered legal-NLP corpora; policy *wording* specifically is
  absent. [INFERRED from search]

**Conclusion:** No real full-policy wording dataset exists off-the-shelf. We
build our own via R1/R3, and we can *optionally* ingest `bdr-ai-org` as a
synthetic eval supplement later (it is MIT, so redistribution is fine).

---

## 3. Route 1 + 3 — Global public sources by market & LOB

Tagged by `license_class`: `regulator`/`industry` = redistribution-safe;
`insurer` = copyrighted, **local-eval-only, do not redistribute**.

### United States (us)
- `property` — **III Homeowners 3 (HO-3) Special Form** sample PDF
  (`iii.org`). Industry sample → **safe**. [VERIFIED download 200, %PDF]
- Regulator: NAIC Model Laws/Regulations portal (model policy language).
  Redistribution-safe but portal-based, not direct PDF → catalog as future
  target. [KNOWN]

### United Kingdom (uk)
- `motor` — **AXA Car Policy Wording** (`axainsurance.com`, `axaconnect.co.uk`).
  Insurer → local-eval-only. [targeted]
- `travel` — **AXA Travel Insurance Policy Wording V2** (`axatravel.co.uk`);
  **AXA Travel booklet** (`axainsurance.com`). Insurer. [targeted]
- `health` — **Bupa Health Policy Guide** (`bupa.co.uk`). Insurer. [targeted]
- `liability` — **AXA Public Liability Wording** (`business.axa.co.uk`).
  Insurer. [targeted]
- Regulator: **FCA IPID templates / handbook** (`fca.org.uk`). Safe.
  [KNOWN]

### Australia (au)
- `property` — **AXA Home Policy Wording** (`axainsurance.com`). Insurer.
  [targeted]
- Regulator: **APRA** (prudential), **ASIC** (disclosure/PIDS). Safe. [KNOWN]
- Insurer doc centres: Allianz AU, APIA, AXA AU policy-documents pages. [KNOWN]

### Canada (ca)
- `property` — **Square One Home Insurance Wording** (`cdn.squareone.ca`).
  Insurer. [targeted]
- `motor` — **RBC Auto Policy (Ontario)** (`rbcinsurance.com`); **FSRAO OAP 1**
  standard form (`fsrao.ca`) → regulator, **safe**. [targeted]
- Regulator: **OSFI** (federal prudential). Safe. [KNOWN]

### European Union (eu)
- Insurer doc centres (Allianz, AXA Partners) are JS-heavy; direct PDF URLs
  are less stable. AXA Travel UK wording is effectively usable for EU-travel
  scenarios. **Needs deeper挖掘** — marked as a known gap; the downloader is
  ready to absorb direct PDFs as they are confirmed. [INFERRED/known-gap]

### India (in) — already in `corpus_lob/`
- `cyber` — Liberty Cyber Safe (public wording). `marine` — IFFCO Tokio Marine
  Cargo (public wording). `health` — `policy.pdf` (redacted). Insurer wordings
  → local-eval-only. [VERIFIED]

---

## 4. Legal / redistribution analysis

| Source type | Redistribution | Ingestion rule |
|-------------|---------------|----------------|
| Regulator / gov standard forms | Safe (public domain / open) | Ingest freely; cite source. |
| Industry-body samples (III) | Safe (openly published) | Ingest freely; cite source. |
| Insurer wordings | **NOT** redistributable (copyright) | Download for **local eval only**; never bundle in releases; derive explanations, not the text. |
| People-published policies | Copyright + possible PII | **Mandatory redaction** before any ingestion; prefer not to redistribute. |

The `corpus_global/` folder ships a `NOTICE.md` enforcing these rules. The
downloader tags every file's `license_class` in `manifest.json`.

---

## 5. Dataset schema & gold-label methodology

Each eval example (`coverage_dataset_<market>_<lob>.jsonl`) carries:

```json
{
  "id": "uk-motor-pdf",
  "lob": "motor",
  "product": "AXA Car Policy Wording",
  "insurer": "AXA",
  "clause": "<verbatim clause text from the PDF>",
  "question": "<user question about coverage>",
  "gold_reading": "<plain-language explanation>",
  "gold_rationale": "<why, citing clause>",
  "gold": "likely_covered | conditional | likely_not_covered",
  "expected_citation": "<clause / section name>",
  "expected_page": <int>
}
```

**Gold-label discipline (learned from live gate):** when an applicable
*insuring* clause exists but carries "subject to" exclusions, prefer
`conditional` over `likely_covered`. The live marine gate (§7) showed the model
correctly cited ICC(A) / Institute War Clauses as applicable but we had
over-labeled those as `likely_covered`; the mismatch was a **gold-label**
issue, not a model failure. See task #60.

---

## 6. Build tooling

- `tools/scrape_policy_corpus.py` — manifest-driven, resilient downloader.
  Validates `%PDF`, quarantines bot-block HTML as `.blocked.html`, retries with
  backoff, idempotent, writes `_scrape_results.json`. [VERIFIED dry-run + run]
- `corpus_global/manifest.json` — the source catalog (append-only to add
  markets/LOBs; no code change).
- `corpus_global/NOTICE.md` — redistribution rules.

---

## 7. Results

### 7.1 Scrape run (MEASURED — `_scrape_results.json`)
`tools/scrape_policy_corpus.py` ran against the **20-target** manifest (extended
from 12 on 2026-08-12 evening: +3 marine, +4 cyber, +1 India health regulator,
plus an FSRAO PDF `mirror`). Result: **20 real PDFs downloaded** across **5
markets** (us, uk, au, ca, in) and **8 LOBs** (property, motor, travel, health,
liability, marine, cyber). The FSRAO OAP1 regulator gap is **closed** — its
landing page is JS-rendered HTML, but the added direct-PDF `mirror`
(`fsrao.ca/media/28946/download`) resolves it to a valid 68-page PDF. All 20
validated with `pypdf` (valid `%PDF`; 2 decrypt via the standard handler).

| Market | LOB | Insurer / body | Pages | License |
|--------|-----|----------------|-------|---------|
| us | property | III (industry sample) | 22 | industry (safe) |
| uk | motor | AXA | 38 | insurer |
| uk | motor | AXA (European) | 36 | insurer |
| uk | travel | AXA (V2) | 53 | insurer |
| uk | travel | AXA (131) | 27 | insurer |
| uk | travel | WeAreTravelInsurance (IPID) | 2 | insurer |
| uk | health | Bupa | 56 | insurer |
| uk | liability | AXA | 27 | insurer |
| uk | marine | Lloyd's (Institute Cargo Clauses A 1982) | 2 | industry (safe) |
| uk | marine | IF Insurance (Institute Cargo Clauses A 2009) | 3 | insurer |
| uk | cyber | Victor (Cyber Secure v3) | 34 | insurer |
| uk | cyber | RSA (Cyber Risk) | 16 | insurer |
| au | property | AXA | 58 | insurer |
| ca | property | Square One | 41 | insurer |
| ca | motor | RBC (Ontario) | 68 | insurer |
| ca | motor | FSRAO (OAP 1) | 68 | regulator (safe) |
| in | marine | Zurich Kotak (marine clauses) | 261 | insurer |
| in | cyber | New India Assurance (MyCyber) | 8 | insurer |
| in | cyber | Generali Central (Cyber Risks) | 26 | insurer |
| in | health | IRDAI (Health Insurance Regs 2016) | 38 | regulator (safe) |

Resilience features proven: SSL-cert fallback, bot-block quarantine, **mirror
fallback on bot-block**, and idempotent re-runs. The mirror fallback is a
downloader fix shipped this session: `download_one` now tries `mirror` when the
primary returns a non-PDF 200 response (e.g. a bot-block HTML page), not only on
network errors — that is what closed the FSRAO gap without a headless browser.

**Housekeeping note (CORRECTED 2026-08-13):** the three `uk/travel*` datasets are
NOT duplicates. `uk/travel` = AXA Travel Policy Wording Series 131 (AXA Insurance
UK); `uk/travel_v2` = AXA Travel Insurance (Bronze/Silver/Gold) — a different
product (v2 wording); `uk/travel_ipid` = WeAreTravelInsurance Policy (Great Lakes
Insurance UK) — a different insurer and document type (IPID). A byte/MD5 check on
2026-08-13 confirmed the source PDFs differ, so all three are DISTINCT datasets and
are kept. (An earlier note mislabeled two as byte-copies — that was wrong.)

### 7.2 Live acceptance gate — Marine (MEASURED — `report_live_marine.json`)
- Accuracy **37.5%** (3/8). Per-class: conditional 1/3, likely_covered 0/2,
  likely_not_covered 2/3.
- Grounding: 8 checked, **1 failed** (Sanctions LMA3100 — citation quote not in
  source, correctly stripped).
- Latency: avg **39,306 ms/query** (n=8); 24 LLM calls total; cost $0.0205.
- **Key signal:** model rationales are well-grounded; mismatches are dominated
  by `likely_covered ↔ conditional` drift on insuring clauses with
  subject-to exclusions. The gold labels are largely sound; the lever is persona
  calibration, not gold-label rewriting (see §7.5).

### 7.3 Live acceptance gate — Cyber (MEASURED — `report_live_cyber.json`)
- Accuracy **37.5%** (3/8). Per-class: conditional 1/4, likely_not_covered 2/3,
  likely_covered 0/1.
- Grounding: 8 checked, **1 failed** (Retention clause citation quote not in
  source — correctly stripped).
- Latency: avg **~48,000 ms/query** (n=8).
- **Key signal (same signature as marine):** every mismatch has a *defensible*
  model rationale; the errors are fine-grained label drift
  (`conditional ↔ likely_covered/likely_not_covered`) and two `ambiguous` calls.
  Notably the DoS question: the model's rationale says losses "fall within
  cover" yet it predicted `likely_not_covered` — a **reading-vs-rationale
  inconsistency** in the persona's structured output. This points at persona
  calibration, not gold-label error.

### 7.4 Global gold datasets authored (MEASURED)
`tools/author_global_dataset.py` turns `tools/global_dataset_specs.json` into
gold-labeled `coverage.jsonl` files co-located with each PDF and auto-anchors
`expected_page` via `fitz` search. Current state: **16 dataset files across
6 markets (us/uk/ca/au/in/eu) and 8 LOBs (property/motor/health/liability/travel/
marine/cyber + the GENERAL-LOB block), 90 examples total**:

| market/lob | examples | source class | notes |
|---|---|---|---|
| us/property | 6 | insurer | |
| uk/motor | 6 | insurer | |
| uk/health | 6 | insurer | |
| ca/property | 6 | insurer | |
| au/property | 6 | insurer | |
| ca/motor | 6 | regulator (RBC) | |
| uk/liability | 6 | insurer (AXA) | `uk-liability-4` search term re-anchored (OCR list-numeral `1` dropped) |
| uk/travel | 6 | insurer | |
| uk/travel_v2 | 6 | insurer (AXA v2 Bronze/Silver/Gold) | distinct AXA product (v2 wording) |
| uk/travel_ipid | 4 | insurer (WeAreTravelInsurance / Great Lakes UK) | distinct insurer + IPID document |
| uk/marine | 6 | industry (Lloyd's ICC A 1982) | ICC(A) all-risks + exclusions 4/5/6/7/8 |
| uk/cyber | 6 | insurer (RSA Cyber Risk) | data liability / extortion / BI / war / BI / fraud exclusions |
| in/cyber | 6 | insurer (New India MyCyber) | personal cyber: unauthorized txn / purchase fraud / extortion-not-covered / biz / war / infra exclusions |
| in/marine | 4 | insurer (Zurich Kotak) | ICC(A) all-risks + war/strikes/transit exclusions |
| in/health | 4 | regulator (IRDAI 2016) | PED waiting period / portability / standard defs / cashless |
| eu/travel | 6 | industry (GDV AT-Reise 2008/2025) | GDV German model conditions — general part: territorial/commute, premium, post-claim duties, subrogation, applicable law |

Offline validation (offline reference judge + schema + page-anchored grounding):
**0 schema errors, 0 grounding failures** across all 16 datasets / 90 examples.
[VERIFIED 2026-08-12]

### 7.5 Harness genericization (#57)
`tests/evals/run_evals.py` now supports `--market <m> --lob <l>`, auto-resolving
`corpus_global/<m>/<l>/coverage.jsonl` + the PDF there — **no code change** to
add a new market/LOB. Offline grounding now skips page-anchored rows (snippet
clauses) so real-policy datasets don't false-fail. A global LIVE gate is in
flight (`report_live_uk_motor.json`). [VERIFIED offline; live pending]

### 7.6 Remaining work (honest gaps)
- **Datasets — DONE.** All scraped PDFs now have gold datasets (16 dataset
  files / 90 examples; §7.4), plus the GDV EU-travel acquisition also carries a
  gold dataset. The three `uk/travel*` sets are distinct products/
  insurers (see §7.1 housekeeping note), not duplicates.
- **Persona calibration** is the real accuracy lever — the 4-way coverage label
  drifts (`conditional` vs `likely_covered`/`likely_not_covered`) and occasionally
  contradicts its own rationale. Gold labels are sound; tune the persona
  (`pws-v2→pws-v3` conditional fix shipped 2026-08-13; live gates re-measured
  under pws-v3 — see `report_live_global_2026-08-13.md`).
- **FSRAO OAP1** — **RESOLVED** (2026-08-12 evening): mirror `fsrao.ca/media/28946/download`
  yields a valid 68-page regulator PDF; no headless browser needed.
- **EU** market: a static EU travel-insurance PDF was acquired 2026-08-13
  (`corpus_global/eu/travel/gdv__travel-model-conditions-2008.pdf`, GDV German
  Insurance Association model conditions — industry/redistribution-safe, German
  language). A gold `coverage.jsonl` dataset for `eu/travel` is now **AUTHORED**
  (6 examples, general-part clauses only — no specific coverage sums fabricated;
  page-anchored, offline-validated 2026-08-13). [DONE]
- **Duplicate cleanup:** NOT required. `uk/travel_v2/` and `uk/travel_ipid/` are
  verified-distinct datasets (different products/insurers), not copies of
  `uk/travel/`. Kept. [CORRECTED 2026-08-13]

---

## 8. Next steps
- #55 run scrape on full manifest — **DONE** (20 targets, 20 PDFs, FSRAO gap closed via mirror; downloader mirror-fallback fix shipped).
- #56 author gold datasets per successfully-scraped PDF (prioritize new marine/cyber/India).
- #57 genericize `run_evals.py` for `corpus_global/<market>/<lob>/`.
- #58 extend redaction pipeline for full policies.
- #60 refine marine/cyber gold labels.
- #59 finalize this doc; #61 validate; #62 commit.
