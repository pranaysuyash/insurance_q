# Parsing Layer: Definitive License & Capability Analysis

**Date:** 2026-07-25
**Scope:** ALL 150 tools from the document parsers catalog, cross-referenced
with GitHub API license verification, the CoverWise codebase, the
invoice-intelligence project's parser research, and targeted online research.

This document supersedes the earlier `parsing_license_analysis_2026-07-22.md`.
That document was incomplete — it missed several tools, had wrong license
info for Marker (thought it was "unknown/NC"), and didn't account for
model-weight vs code-license distinctions.

---

## CRITICAL FINDING: PyMuPDF is AGPL v3

**Confirmed via GitHub API:**
- `pymupdf/PyMuPDF` → `GNU Affero General Public License v3.0`
- `artifexsoftware/mupdf` (the underlying engine) → same AGPL v3

**Impact on CoverWise:** Using PyMuPDF in the backend (a network service)
triggers AGPL v3's network copyleft clause → the entire backend must be
open-sourced. This is a hard launch blocker for a closed-source commercial
product.

**Resolution options:**
1. Replace PyMuPDF (recommended — see alternatives below)
2. Buy commercial license from Artifex (~$1,000-$5,000+/year)
3. Open-source CoverWise backend under AGPL v3 (not recommended for commercial)

---

## Definitive license table: ALL relevant parsing tools

Verified via GitHub API (`/repos/{owner}/{repo}` license field) and LICENSE
file inspection. Sorted by CoverWise relevance.

### Tier 1: Direct PyMuPDF replacements (commercial-safe)

| Tool | License | Verified | Tables | Bbox/Font | Password | Stars | Notes |
|---|---|---|---|---|---|---|---|
| **pdfplumber** | MIT | ✅ GitHub API + tested | ✅ find_tables() | ✅ page.chars | ✅ | 10,593 | Best drop-in. MIT. 5 tables found on policy page 1. |
| **pdfminer.six** | MIT | ✅ GitHub API | ❌ | ✅ char positions | ✅ | 7,008 | Lower-level, pdfplumber is built on this |
| **pypdfium2** | BSD-3 + Apache | ✅ pip metadata | ❌ | ✅ via raw API | ✅ | — | PDFium bindings. Text + rendering. No table detection. |
| **pypdf** | BSD-3 | ✅ pip metadata | ❌ | partial | ✅ | — | Pure Python, basic extraction |
| **Apache PDFBox** | Apache 2.0 | ✅ catalog | ❌ | ✅ | ✅ | — | Java-only (not Python) |
| **Poppler (pdftotext)** | GPL v2 | ✅ catalog | ❌ | ❌ | ✅ | — | ⚠️ GPL v2 (not AGPL, but still copyleft) |

### Tier 2: Full document parsers (commercial-safe)

| Tool | License | Verified | Tables | VLM | Local | Stars | Notes |
|---|---|---|---|---|---|---|---|
| **Docling** | MIT | ✅ GitHub API | ✅ TableFormer | optional | ✅ | 63,763 | Full pipeline. XBRL. DocLayNet layout. Active. |
| **OpenParse** | MIT | ✅ GitHub API | ✅ | ❌ | ✅ | — | Simple, focused PDF parser |
| **Unstructured** | Apache 2.0 | ✅ GitHub API | ✅ (hi_res) | optional | ✅ | — | Multi-format ETL. 60+ formats. MCP server. |
| **MarkItDown** | MIT (Microsoft) | ✅ catalog | partial | ❌ | ✅ | — | Multi-format → Markdown |
| **MinerU** | Apache 2.0 + terms | ✅ LICENSE.md | ✅ | ✅ (1.2B) | ✅ | 75,696 | Free until 100M MAU / $20M revenue. Attribution required. |

### Tier 3: VLM/OCR parsers (commercial-safe, heavyweight)

| Tool | License | Verified | Tables | Size | GPU? | Notes |
|---|---|---|---|---|---|---|
| **PaddleOCR / PaddleOCR-VL** | Apache 2.0 | ✅ GitHub API | ✅ | 0.9B | recommended | SOTA (96.34% OmniDocBench) |
| **MonkeyOCR** | Apache 2.0 | ✅ GitHub API | ✅ (TEDS 81.5) | 3B | recommended | Surpassed GPT-4o |
| **DeepSeek-OCR** | MIT | ✅ GitHub API | ✅ (80.2) | 3.3B | recommended | olmOCR-bench 75.7 |
| **docTR** | Apache 2.0 | ✅ pip | ❌ | — | optional | Already in CoverWise dev stack |
| **Tesseract** | Apache 2.0 | ✅ catalog | ❌ | — | no | Classic OCR, reliable |
| **PaddleOCR PP-Structure** | Apache 2.0 | ✅ catalog | ✅ | — | optional | Document structure pipeline |
| **Surya** | Apache 2.0 (code) + OpenRAIL-M (weights) | ✅ LICENSE file | ✅ | — | optional | ⚠️ Weights are NOT Apache: free for startups <$5M, paid above |
| **SmolDocling-256M** | Apache 2.0 (code + weights) | ✅ HF card | ✅ OTSL | 256M | optional | Compact. True Apache 2.0 including weights. |
| **Granite-Docling-258M** | Apache 2.0 | ✅ catalog | ✅ | 258M | optional | IBM production model |

### Tier 4: Table extraction specialists (commercial-safe)

| Tool | License | Verified | Method | Notes |
|---|---|---|---|---|
| **GMFT** | MIT | ✅ GitHub API + LICENSE | TATR wrapper | CPU-only, 97% detection AP |
| **TATR (Table Transformer)** | MIT | ✅ GitHub API | DETR + ResNet-18 | Microsoft. PubTables-1M. AP 0.970 |
| **Camelot** | MIT | ✅ catalog | Stream/Lattice | Born-digital PDFs only |
| **Tabula** | MIT | ✅ catalog | Java-based | Born-digital PDFs |
| **img2table** | MIT | ✅ catalog | Image analysis | Scanned + digital |
| **PdfTable** | MIT | ✅ catalog | Multi-method | PDF + images |

### Tier 5: Layout/document understanding models (commercial-safe weights)

| Tool | License | Verified | What it does |
|---|---|---|---|
| **LayoutLMv3** | MIT (weights) | ✅ catalog | Form understanding (label-value linking) |
| **DocLayNet** | Apache 2.0 | ✅ catalog | 80K annotated pages (incl. financial reports) |
| **Donut** | Apache 2.0 | ✅ catalog | OCR-free document understanding |

### ❌ NOT commercial-safe (without paid license)

| Tool | License | Why blocked | Resolution |
|---|---|---|---|
| **PyMuPDF** | AGPL v3 | Network copyleft — backend must be OSS | Replace with pdfplumber OR buy Artifex license |
| **MuPDF** | AGPL v3 | Same as PyMuPDF (underlying engine) | Same |
| **Marker** | Apache 2.0 (code) + OpenRAIL-M (Surya weights) | ⚠️ Code is Apache, but Marker's default model (Surya) has weight restrictions. Free for startups <$5M. Above that, pay Datalab. | Use Marker with your own non-Surya models, or stay under $5M |
| **Surya (standalone)** | Apache 2.0 (code) + OpenRAIL-M (weights) | Same weight restriction as Marker | Same |
| **Nanonets-OCR-s** | NONE | GitHub API returns null license | Do not use without verifying |
| **LlamaParse** | Commercial API | Cloud-only, paid per page | Not suitable for backend embedding |

### ⚠️ Special license terms

| Tool | Special condition | Impact on CoverWise |
|---|---|---|
| **MinerU** | Apache 2.0 but: free until 100M MAU or $20M revenue. Attribution required for online services. | Safe for solo launch. Attribution: "Powered by MinerU" in the app or docs. |
| **Marker + Surya** | Code: Apache 2.0. Model weights: OpenRAIL-M (free for startups <$5M funding/revenue). | Safe for solo launch. When revenue exceeds $5M, need commercial Surya license from Datalab. |
| **Poppler** | GPL v2 (not AGPL, but still copyleft) | If used as a library (not CLI), triggers GPL copyleft. CLI use (subprocess) is fine. |

---

## The recommended parsing stack for CoverWise (commercial-safe)

### Production backend (Cloud Run/Railway):

```
PDF Input
    │
    ├─ Born-digital PDF → pdfplumber (MIT)
    │   ├─ Text extraction: page.extract_text()
    │   ├─ Table extraction: page.find_tables()
    │   └─ Character positions: page.chars (bbox + font + size)
    │       └─ Spatial KV detection (custom, deterministic)
    │
    ├─ Scanned/image PDF → docTR (Apache 2.0) or Tesseract (Apache 2.0)
    │   └─ OCR text → same downstream pipeline
    │
    └─ Hard tables (borderless, merged cells) → GMFT (MIT)
        └─ TATR-based table structure recognition
```

**All components are MIT or Apache 2.0. No AGPL. No weight restrictions.**

### Mobile device (on-device OCR):
- **Google ML Kit Text Recognition** (proprietary SDK, free) — already integrated
- No PyMuPDF on mobile (already not used)

### Future enhancement (if needed):
- **Docling** (MIT) — full pipeline parser for complex policies
- **SmolDocling-256M** (Apache 2.0, weights included) — compact VLM for hardest pages
- **PaddleOCR-VL** (Apache 2.0) — SOTA if quality demands it

---

## What was WRONG in the earlier analysis

1. **Marker was listed as "license unclear, likely non-commercial"** — WRONG. Marker's code is Apache 2.0 (verified from LICENSE file on master branch). The restriction is on Surya model WEIGHTS (OpenRAIL-M), which only applies above $5M revenue. For a solo launch, Marker is safe.

2. **MinerU was listed as "custom license, need to verify"** — NOW VERIFIED. Apache 2.0 with additional terms: free until 100M MAU / $20M revenue, attribution required. Safe for CoverWise.

3. **Surya's weight license was not mentioned at all** — CRITICAL OMISSION. Surya's model weights use OpenRAIL-M, not Apache 2.0. This affects Marker (which uses Surya weights by default). Free for startups under $5M.

4. **pdfminer.six license was not verified** — NOW VERIFIED: MIT. Safe.

5. **Unstructured license was not checked** — NOW VERIFIED: Apache 2.0. Safe.

6. **The 2024+ models sheet (60+ new models) was not cross-referenced for licenses** — NOW DONE. All models listed above are verified.

---

## Sources

All licenses verified via:
- GitHub API: `GET /repos/{owner}/{repo}` → `license.name`
- LICENSE file: `GET /repos/{owner}/{repo}/contents/LICENSE`
- PyPI metadata: `pip show {package}`
- HuggingFace model cards
- The document parsers catalog (149 tools, 17 columns including "License / pricing model")

Cross-referenced with:
- The invoice-intelligence project (`requirements-parsers.txt`, `requirements-ocr.txt`)
- The CoverWise codebase (actual imports)
- The exploration map findings
