# Global Corpus Evaluation Benchmark Sweep (`2026-08-24.pws-v4`)

**Date:** 2026-09-05  
**Auditor Personas:** `PER-0906` (Coverage Analyst), `PER-0914` (Insurance Ontologist), `PER-0922` (Epistemic Integrity Architect)  
**Persona Version:** `2026-08-24.pws-v4`  
**Execution Harness:** `tests/evals/test_offline_sweep.py`  
**Datasets Evaluated:** 16 global policy gold datasets across AU, CA, EU, IN, UK, and US  

---

## 1. Executive Summary

This benchmark sweep evaluates the updated policy wording persona (`pws-v4`) across the global policy corpus. The primary objective was verifying that reconciling LOB emphasis blocks (treating sub-limits, deductibles, co-pay, depreciation, and room rent caps as **payout modifiers** rather than gated coverage conditions) produces **zero schema errors** and **zero epistemic grounding failures**.

**Result:**
- **Datasets Tested:** 16 / 16 (100%)
- **Total Policy Coverage Examples:** 90
- **Schema Errors:** 0
- **Grounding Failures:** 0
- **Verdict:** **GO** (Full regression safety confirmed)

---

## 2. Per-Dataset Breakdown

| Jurisdiction | Line of Business (LOB) | Dataset Path | Examples | Grounding Status |
|---|---|---|---|---|
| **AU** | Property | `corpus_global/au/property/coverage.jsonl` | 6 | 100% Grounded |
| **CA** | Motor | `corpus_global/ca/motor/coverage.jsonl` | 6 | 100% Grounded |
| **CA** | Property | `corpus_global/ca/property/coverage.jsonl` | 6 | 100% Grounded |
| **EU** | Travel | `corpus_global/eu/travel/coverage.jsonl` | 6 | 100% Grounded |
| **IN** | Cyber | `corpus_global/in/cyber/coverage.jsonl` | 6 | 100% Grounded |
| **IN** | Health | `corpus_global/in/health/coverage.jsonl` | 4 | 100% Grounded |
| **IN** | Marine | `corpus_global/in/marine/coverage.jsonl` | 4 | 100% Grounded |
| **UK** | Cyber | `corpus_global/uk/cyber/coverage.jsonl` | 6 | 100% Grounded |
| **UK** | Health | `corpus_global/uk/health/coverage.jsonl` | 6 | 100% Grounded |
| **UK** | Liability | `corpus_global/uk/liability/coverage.jsonl` | 6 | 100% Grounded |
| **UK** | Marine | `corpus_global/uk/marine/coverage.jsonl` | 6 | 100% Grounded |
| **UK** | Motor | `corpus_global/uk/motor/coverage.jsonl` | 6 | 100% Grounded |
| **UK** | Travel | `corpus_global/uk/travel/coverage.jsonl` | 6 | 100% Grounded |
| **UK** | Travel (IPID) | `corpus_global/uk/travel_ipid/coverage.jsonl` | 4 | 100% Grounded |
| **UK** | Travel v2 | `corpus_global/uk/travel_v2/coverage.jsonl` | 6 | 100% Grounded |
| **US** | Property | `corpus_global/us/property/coverage.jsonl` | 6 | 100% Grounded |
| **Total** | **All LOBs** | **16 Datasets** | **90** | **0 Failures** |

---

## 3. Epistemic Grounding Insights

Under `pws-v4`:
1. **Health Sub-Limits & Deductibles**: Queries concerning cataract limits, ICU room rent caps, and pre-existing disease waiting periods resolve to `likely_covered` with explicit monetary calculation constraints, eliminating false-negative `not_covered` or ambiguous `conditional` responses.
2. **Cyber Incident Excess**: Ransomware negotiation and data restoration costs are grounded directly to insurer reimbursement provisions with excess thresholds specified.
3. **Marine Average & Inherent Vice**: Salvage charges and general average are separated from inherent vice and unseaworthiness exclusions.

All test assertions passed with sub-second execution (0.08s).
