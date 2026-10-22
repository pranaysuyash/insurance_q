# EU-market corpus gap — direct/static insurance-PDF source hunt (stream #17)

**Date:** 2026-08-13
**Author:** Forge (research/exploration stream — no code changes, one PDF downloaded)
**Builds on:** `docs/research/global_policy_corpus_2026-08-12.md` §3 (EU) and §7.6 (gap)
**Evidence tiers (motto_v5 §0.5):** VERIFIED (download + `%PDF` + fitz page count) · KNOWN (established public fact) · INFERRED (flagged).

---

## 0. The gap (from prior work)

`global_policy_corpus_2026-08-12.md` §7.6 records: *"EU market still lacks a direct PDF (Allianz/AXA EU doc centres are JS-heavy). Pending deeper挖掘."* The manifest (`corpus_global/manifest.json`) lists `eu` as a market but **no `eu/` PDF existed** (only `us/uk/au/ca/in`). This note closes that gap with at least one real, redistribution-safe EU policy PDF.

## 1. Method

1. Enumerate EU source classes: EU regulators (EIOPA, BaFin, ACPR, IVASS, AFM), national-insurer static PDFs, and known static URLs.
2. Prefer **regulator/industry** license class (redistribution-safe per the corpus rules) over insurer copyright.
3. Attempt a **direct, non-JS** download via `urllib` (same logic as `tools/scrape_policy_corpus.py` `_fetch`/`_classify`) into `corpus_global/eu/<lob>/`.
4. Validate `%PDF` magic + record page count with `fitz` (venv python 3.11, PyMuPDF 1.28).
5. Register the win in `manifest.json` so the existing downloader can re-run it idempotently.

## 2. Candidate sources investigated

| Source | Type | Static? | Outcome |
|---|---|---|---|
| **GDV** (German Insurance Association) model conditions | industry body | **Yes — direct `resource/blob/...pdf`** | **DOWNLOADED** (see §3) |
| EIOPA (eiopa.europa.eu) reports/consumer docs | regulator | Mixed — many are JS landing pages with `/system/files/*.pdf` assets | Not needed (GDV closed the gap); EIOPA publishes *reports*, not policy wording |
| BaFin (Germany) consumer info sheets | regulator | Mostly linked from JS pages | Not pursued once GDV succeeded |
| ACPR (France) / IVASS (Italy) / AFM (NL) | regulator | JS-heavy doc centres | Deferred — German/Italian docs also non-English; GDV is cleaner |
| Allianz / AXA Partners EU doc centres | insurer | **JS-heavy** (confirmed in prior doc §3) | Blocked — would need headless browser; avoid |
| National insurer static PDFs (e.g. ERGO, HUK) | insurer | Some exist but copyright + JS-wrapped | Lower priority than industry/regulator |

**Why GDV over a regulator:** the corpus needs *policy wording*, and EU regulators (EIOPA et al.) publish handbooks/reports, not model wordings. GDV — the German Insurance Association — publishes **non-binding model policy conditions** ("Musterbedingungen") as openly-hosted static PDFs. These ARE real insurance wording and are an **industry body** publication → `license_class: industry` = redistribution-safe under the project's own rules (`global_policy_corpus_2026-08-12.md` §4). It is the EU analogue of the US III sample form already in the corpus.

## 3. Download result — SUCCESS

- **URL:** `https://www.gdv.de/resource/blob/6156/3a3aa579d1d3b9184add3a6f02167bc3/01-allgemeiner-teil-der-versicherungsbedingungen-fuer-die-reiseversicherung-2008-at-reise-2008--data.pdf`
- **Discovery:** WebSearch `GDV Musterbedingungen Reiseversicherung PDF` (2026-08-13) returned the direct blob URL (result #2).
- **HTTP:** `200`, `Content-Type: application/pdf;charset=UTF-8`, **59,020 bytes**.
- **Magic:** `%PDF` (first 4 bytes) → real PDF, not a bot-block HTML page. [VERIFIED]
- **Path:** `corpus_global/eu/travel/gdv__travel-model-conditions-2008.pdf`
- **Page count:** **4** (fitz `page_count`). [VERIFIED]
- **Content check (fitz text extract):** page 1 — *"Unverbindliche Bekanntgabe des Gesamtverbandes der Deutschen Versicherungswirtschaft e. V. (GDV) … AT-Reise 2008/2025, März 2025 … Allgemeiner Teil der Versicherungsbedingungen für die Reiseversicherung"*; genuine clauses (e.g. premium-unpaid claims exclusion §3.1.2). Real policy wording. [VERIFIED]
- **Market / LOB / class:** `eu` / `travel` / `industry` (redistribution-safe).
- **Language:** German. An asset for the *global* corpus (covers a non-English EU market); note it for eval harness i18n.
- **Manifest:** entry appended to `corpus_global/manifest.json` (`market=eu, lob=travel, insurer=GDV, license_class=industry`) so the existing `tools/scrape_policy_corpus.py` can re-fetch idempotently. [TIER 1 edit to data file, not code]

## 4. What I did NOT need to do (honest scope)

- No headless browser was required — the GDV blob URL is a direct static PDF (the exact thing the task asked for). The Allianz/AXA JS-heavy centres were correctly avoided.
- EIOPA/BaFin/ACPR/IVASS/AFM were scoped but not exhausted once GDV succeeded; they remain **future candidates** for additional EU LOBs (see §6).

## 5. Evidence / confidence

| Claim | Tier | Confidence |
|---|---|---|
| GDV PDF is a real, valid PDF (59KB, %PDF, 4pp, real wording) | VERIFIED (download+fitz) | High |
| GDV = industry body, redistribution-safe | KNOWN + project rule | High |
| EU regulators publish reports not wordings (so GDV preferred) | INFERRED from prior doc + search | Medium |
| Allianz/AXA EU centres JS-heavy (avoid) | KNOWN (prior doc §3) | High |

## 6. Recommended next EU sources (to broaden LOB coverage)

1. **GDV other LOBs** — GDV publishes model conditions for motor (`Kraftfahrt`), liability (`Haftpflicht`), property (`Hausrat`/`Wohngebäude`), cyber. Same static `resource/blob/*.pdf` pattern → easy to add. (INFERRED pattern from the one success.)
2. **EIOPA** — for EU-level consumer-protection / IDD context (regulator, safe) if a report PDF is wanted.
3. **IVASS (Italy) / ACPR (France)** IPID-style static PDFs — insurer copyright, local-eval-only, but real EU wording.
4. If an **English** EU doc is preferred for the English eval harness, hunt EIOPA English reports or a UK-style IPID already present (`uk/travel` AXA) — but that is `uk`, not `eu`.

## 7. Anything else?

- **Manifest consistency:** the new entry uses `insurer: "GDV"` though GDV is an association, not an insurer. The downloader's slug becomes `gdv__travel-model-conditions-2008.pdf` — consistent with the `<insurer>__<product>` convention; fine, but worth a note if a strict "insurer-only" consumer is added later.
- **Duplicate-PDF cleanup** from prior work (`uk/travel_ipid`, `uk/travel_v2`) is unrelated to this gap and remains a commit-agent task.
- **i18n:** adding a German document means the eval harness (`run_evals.py --market eu --lob travel`) should either use a German gold dataset or an English summary; the page-anchor logic is language-agnostic. Not done here.
- **Re-run safety:** `tools/scrape_policy_corpus.py` will now `skip_existing` this PDF (valid `%PDF` present) — no re-download on the next batch.
