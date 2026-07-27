# Parsing Layer License Analysis — CRITICAL FINDING

**Date:** 2026-07-22
**Severity:** CRITICAL — this affects the entire commercial viability of the
product

---

## The problem: PyMuPDF is AGPL v3

**PyMuPDF** (the `fitz` / `PyMuPDF` package) is licensed under **GNU AGPL v3**
(GNU Affero General Public License version 3). This is confirmed by:
- The package METADATA: `License: GNU AFFERO GPL 3.0`
- The COPYING file: `GNU AFFERO GPL 3.0`
- The README: "available under open-source AGPL and commercial license
  agreements. If you determine you cannot meet the requirements of the AGPL,
  please contact Artifex for more information regarding a commercial license."

### What AGPL v3 means for CoverWise

AGPL v3 is the "network copyleft" license. It extends GPL's copyleft to
**network services** — meaning:

1. **Backend usage is affected.** CoverWise's backend is a network service (API).
   Using PyMuPDF in the backend means the **entire backend codebase** that
   interacts with PyMuPDF must be open-sourced under AGPL v3 if the service is
   offered to users over a network.

2. **Mobile app usage is affected.** PyMuPDF is used in the backend (for PDF
   text extraction during document processing). The backend is the network
   service. The AGPL requirement applies to the backend code.

3. **This is NOT just about the mobile app.** Even if the mobile app doesn't
   use PyMuPDF directly (it sends the PDF to the backend), the backend uses
   PyMuPDF, and the backend is the network service.

### Options

1. **Buy a commercial PyMuPDF license** from Artifex
   (https://artifex.com/contact/pymupdf-inquiry.php). Cost varies; typically
   starts around $1,000-$5,000/year for small businesses. This removes the
   AGPL requirement.

2. **Replace PyMuPDF** with a permissively-licensed alternative. This is the
   recommended path for a solo founder who doesn't want to pay or open-source.

3. **Open-source CoverWise under AGPL v3.** This makes the code free for
   anyone to use, modify, and distribute, including commercially — but anyone
   who uses it in a network service must also open-source their modifications.
   This is probably NOT what a solo founder wants for a commercial product.

---

## License comparison: all parsing alternatives

| Tool | License | Commercial-safe? | Notes |
|---|---|---|---|
| **PyMuPDF** | **AGPL v3** | **NO** ❌ | Current parser. Commercial license available from Artifex. |
| **pypdfium2** | BSD-3-Clause + Apache-2.0 | **YES** ✅ | PDFium bindings. Text + rendering. No table detection. |
| **pdfplumber** | MIT | **YES** ✅ | Built on pdfminer.six (MIT). Tables + char positions + font info. |
| **pdfminer.six** | MIT | **YES** ✅ | Lower-level text/layout extraction. |
| **pypdf** | BSD-3-Clause | **YES** ✅ | Pure Python, basic text extraction. |
| **Docling** | MIT | **YES** ✅ | Full parser, TableFormer, DocLayNet layout model. |
| **Marker** | **Unknown/CC-BY-NC-SA** ⚠️ | **NO** ❌ | GitHub API returns null license. The repo's business model is "open source + commercial" — the open source version likely has a non-commercial restriction. **Must verify before use.** |
| **GMFT** | MIT | **YES** ✅ | TATR wrapper, CPU-only table extraction. |
| **TATR (Table Transformer)** | MIT | **YES** ✅ | Microsoft, pretrained on PubTables-1M. |
| **SmolDocling-256M** | Apache 2.0 | **YES** ✅ | Compact VLM parser, OTSL tables. |
| **PaddleOCR / PaddleOCR-VL** | Apache 2.0 | **YES** ✅ | SOTA parser (96.34% OmniDocBench). |
| **MinerU** | Custom (Apache 2.0 based) | **Likely YES** ⚠️ | "MinerU Open Source License based on Apache 2.0" — need to verify exact terms. |
| **MonkeyOCR** | Apache 2.0 | **YES** ✅ | Table TEDS 81.5. |
| **DeepSeek-OCR** | MIT (model weights) | **YES** ✅ | 3.3B params, olmOCR-bench 75.7. |
| **DocLayNet** | Apache 2.0 | **YES** ✅ | Dataset (80K annotated pages), not a parser. |

### Banned for commercial use without license:
- **PyMuPDF** (AGPL v3) — current parser, needs replacement or commercial license
- **Marker** — license unclear, likely non-commercial restriction on the free version

### Safe for commercial use:
- **pdfplumber** (MIT) — best direct replacement for PyMuPDF's text + table extraction
- **pypdfium2** (BSD/Apache) — for rendering and basic text
- **Docling** (MIT) — for structure-preserving parsing
- **GMFT** (MIT) — for table structure recognition
- **SmolDocling-256M** (Apache 2.0) — for compact VLM parsing
- **PaddleOCR-VL** (Apache 2.0) — for SOTA VLM parsing

---

## The pdfplumber alternative — tested and works

**pdfplumber** (MIT license) is the best drop-in replacement for PyMuPDF for
CoverWise's use case. I tested it against the real policy:

### Text extraction: ✅ works
- 2,623 characters on page 1 (vs PyMuPDF's 2,836 — slight difference due to
  whitespace handling)
- Same content, same structure

### Table detection: ✅ works (5 tables found on page 1)
- Table 1: Proposer Name, Product Name, Policy No., Period of Insurance, etc.
- Tables include label-value pairs: `['Proposer Name', 'PRANAY SUYASH', 'Product name', 'Health Shield 360 Retail']`
- `['', '', 'Policy No.', '4214i/CPHSR/407834350/00/000']` — the policy
  number is in the table!

### Character positions: ✅ works (for spatial KV detection)
- Every character has `x0`, `top` (y), `fontname`, `size`
- "2500000" is at x=97, y=449
- This is the same bbox data PyMuPDF provides — spatial KV detection works
  identically

### Password support: ✅ works
- `pdfplumber.open('policy.pdf', password='pran1005')` — opens correctly

### What pdfplumber DOESN'T have vs PyMuPDF:
- No `get_pixmap()` (page rendering to image) — need pypdfium2 for that
- No `find_tables()` with the same flexibility — pdfplumber's table detection
  uses different algorithms (lines, text alignment, explicit)
- Slightly different API — code changes needed throughout the pipeline

---

## Migration path: PyMuPDF → pdfplumber

### Files that use PyMuPDF (fitz):
```
src/ocr/native_pdf.py          — extract_native_pdf_nodes
src/ocr/pipeline.py            — _process_pdf, page rendering
src/services/document_processing_service.py — _extract_text, _save_file
```

### What needs to change:
1. **Text extraction:** `fitz.open()` + `page.get_text()` →
   `pdfplumber.open()` + `page.extract_text()`
2. **Table extraction:** `page.find_tables()` → `page.find_tables()` (pdfplumber
   has the same method name, different algorithm)
3. **Character positions:** `page.get_text("dict")` → `page.chars` (list of
   dicts with x0, top, fontname, size — same data, different API)
4. **Page rendering:** `page.get_pixmap()` → use `pypdfium2` for rendering
   (BSD/Apache license)
5. **Password handling:** `doc.authenticate(password)` →
   `pdfplumber.open(path, password=password)`

### What stays the same:
- The spatial KV detection algorithm (works with any bbox data)
- The chunking strategies (work on extracted text)
- The context header (works on extracted text)
- The embedding pipeline (text → vectors, parser-independent)

---

## Recommendations

### Immediate (before any commercial deployment):
1. **Migrate from PyMuPDF to pdfplumber** for text extraction and table detection
2. **Add pypdfium2** for page rendering (BSD/Apache, already installed)
3. **The spatial KV detection algorithm** works identically — pdfplumber's
   `page.chars` provides the same bbox + font data

### After migration (enhancement):
4. **Add GMFT** (MIT) for better borderless table structure recognition
5. **Evaluate SmolDocling-256M** (Apache 2.0) for compact VLM parsing
6. **Evaluate Docling** (MIT) for full-pipeline parsing on hard pages

### Do NOT use without commercial license:
- **PyMuPDF** — AGPL v3, incompatible with closed-source commercial product
- **Marker** — license unclear, likely non-commercial restriction

---

## Anything else? (motto_v4 §0.1.1)

**Q: Is this urgent?**
A: YES. If CoverWise launches with PyMuPDF in the backend, the AGPL v3
requirement applies immediately. The founder would be legally obligated to
open-source the entire backend. This must be resolved BEFORE launch.

**Q: Can we just buy the commercial license?**
A: Yes, but the cost ($1,000-$5,000+/year) is significant for a solo founder.
pdfplumber (MIT, free) provides the same core functionality.

**Q: Does this affect the mobile app?**
A: The mobile app uses ML Kit for on-device OCR (not PyMuPDF). The backend
uses PyMuPDF for PDF processing. The AGPL requirement applies to the backend
(the network service).

**Q: What about the existing code in git that uses PyMuPDF?**
A: It's fine for local development (AGPL doesn't restrict personal use). The
issue is when the service is offered to users over a network (production).

**Q: Should other agents be informed?**
A: YES. This is a cross-cutting concern. Any agent touching the parsing pipeline
needs to know about the AGPL issue. Add to the exploration map and session context.
