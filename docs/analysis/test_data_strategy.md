# Test Data Strategy: policy.pdf and Ground Truth Data

> **Status:** Adopted
> **Date:** 2026-07-29
> **Source session:** Derived from multiple discussions about test data, synthetic documents, and the policy.pdf approach
> **Evidence tier:** Operational decision (Tier 0)
> **Related:** [Ground Truth Schema](../review/ground_truth/GROUND_TRUTH_SCHEMA.md), [Ground Truth Verification](../tools/verify_ground_truth.py)

---

## 1. What Was Discussed

During development, the question of test data arose multiple times:

1. **Should we use a synthetic/generated PDF or a real insurance policy for testing?**
2. **Should we create a demo policy for the onboarding flow?** (Rejected — see `ADR-2026-07-28-reject-demo-mode.md`)
3. **How do we verify that the extraction pipeline works correctly on real data?**
4. **Should non-insurance documents (travel itinerary, health card) be used for testing non-medical insurance types?**

## 2. The Decision: Use Real Policy Data

**Decision:** Use the actual `policy.pdf` file (a real ICICI Lombard health insurance policy) as the primary test document, not a synthetic/generated PDF.

### Rationale

When a synthetic PDF was initially generated (via PyMuPDF) for testing the tenant isolation verifier, it failed validation because:
- The generated PDF had `Count 0` pages (empty)
- PyMuPDF correctly validated it as `pdf_empty`
- This caused test failures that were not real — they were artifacts of bad test data

The fix was to use the **actual policy.pdf** file located at `mobile/assets/demo/policy.pdf` as the test document. This is a real ICICI Lombard health insurance policy with realistic structure, tables, and formatting.

**Advantages of the real PDF:**
- Tests the actual extraction pipeline against realistic document structures
- Catches formatting issues that synthetic PDFs would miss
- Verifies OCR accuracy against real text (including table layouts, merged cells, headers/footers)
- Provides realistic coverage data for screenshot generation and Play Store previews
- No risk of "garbage in, garbage out" test validation

### What policy.pdf Contains

| Attribute | Value |
|-----------|-------|
| **Insurer** | ICICI Lombard |
| **Type** | Health insurance (individual health insurance policy) |
| **Format** | PDF (scanned/digital, ~200-300 dpi equivalent) |
| **Location** | `mobile/assets/demo/policy.pdf` |
| **Verified fields** | Policy number, insured name, sum insured, premium, deductible, waiting period, exclusions, network hospitals, expiry date |
| **Validated by** | Policy extraction service in test suite + ground truth verification |

## 3. Ground Truth Data

In addition to the raw PDF, ground truth data was created to verify extraction accuracy:

- **`tools/verify_ground_truth.py`** — uploads the PDF, compares extracted fields + Q&A answers against expected values
- **`docs/review/ground_truth/`** — ground truth JSON files for each test document (named `{type}_{##}.json`)
- **Schema:** `docs/review/ground_truth/GROUND_TRUTH_SCHEMA.md`

### Current Ground Truth Documents

| File | Type | Source | Status |
|------|------|--------|--------|
| `health_01.json` | Health (ICICI Lombard) | `policy.pdf` | ✅ Skeleton created |
| (more to come) | Motor | Synthetic or real motor policy PDF | ⬜ |

## 4. What Was NOT Done

| Idea | Status | Reason |
|------|--------|--------|
| Synthetic/generated PDF for testing | **Rejected** | Real PDF catches real formatting issues. Synthetic PDFs pass validation but fail in production. |
| Demo policy for onboarding | **Rejected** | Outside the wedge (see `ADR-2026-07-28-reject-demo-mode.md`). Fake data doesn't help users understand their own policy. |
| Camera-captured test images | **Deferred** | Camera is an optional fallback, not the primary path. Test when camera flow is implemented. |

## 5. Adding More Test Documents

To add a new test document:
1. Place the PDF in `mobile/assets/demo/`
2. Create a ground truth JSON file in `docs/review/ground_truth/`
3. Add a test case in `tools/verify_ground_truth.py`
4. Generate screenshots from the running app for Play Store listing

**Preferred sources:** Real insurance policies (redacted as needed) > OCR'd physical copies > Synthetic documents

## 6. Relation to Other Documents

- [Ground Truth Schema](../review/ground_truth/GROUND_TRUTH_SCHEMA.md) — extraction QA format
- [Ground Truth Verifier](../tools/verify_ground_truth.py) — automated verification tool
- [Demo Mode ADR](../decisions/ADR-2026-07-28-reject-demo-mode.md) — why demo policies are rejected

## 7. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — test data strategy documented | Exhaustive documentation audit per §0.3.1 |
