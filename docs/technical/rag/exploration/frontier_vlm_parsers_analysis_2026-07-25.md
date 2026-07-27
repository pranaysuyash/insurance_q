# Frontier VLM Document Parsers — Deep Exploration (2026-07-25)

**Date:** 2026-07-25
**Scope:** Deep evaluation of the 18 frontier VLM-based document parsers
requested by the founder, plus 3 general VLMs. All verified via GitHub API,
HuggingFace model cards, and LICENSE file inspection.

---

## Complete model evaluation table

### Specialist document parser VLMs (18 models)

| Model | Org | Release | Size | License | Commercial-safe? | OmniDocBench | Key strength |
|---|---|---|---|---|---|---|---|
| **OvisOCR2** | AIDC-AI | 2026-07 | **0.8B** | **Apache 2.0** ✅ | **YES** | **96.58** | **NEW SOTA. Smallest model to top OmniDocBench. End-to-end, no pipeline.** |
| **PaddleOCR-VL-1.6** | Baidu | 2026-06 | 0.9B | **Apache 2.0** ✅ | **YES** | **96.34** | Previous SOTA. Multilingual. Region refinement. |
| **MinerU2.5-Pro** | OpenDataLab | 2026-04 | 1.2B | Apache 2.0 + terms ⚠️ | YES (<$20M rev) | **95.39** | Data-centric high-accuracy. Cross-page table merging. Attribution required. |
| **GLM-OCR** | Z.ai | 2026-02 | 0.9B | **Apache 2.0** ✅ | **YES** | **95.22** | Complex docs, tables, formulas, KIE. 7,206 stars. |
| **PaddleOCR-VL-1.5** | Baidu | 2026-01 | 0.9B | **Apache 2.0** ✅ | **YES** | 94.93 | Robust in-the-wild multi-task parsing. |
| **HunyuanOCR-1.5** | Tencent | 2026-07 | ? | **Tencent Community** ⚠️ | **NO (EU excluded)** | ? | Lightweight, fast. **NOT for EU/UK/South Korea use.** |
| **PaddleOCR-VL** | Baidu | 2025-10 | 0.9B | **Apache 2.0** ✅ | **YES** | — | Original 0.9B multilingual parser. |
| **Unlimited-OCR** | Baidu | 2026-06 | ? | **MIT** ✅ | **YES** | — | One-shot long-horizon OCR. 18,918 stars. |
| **Youtu-Parsing** | Tencent | 2026-01 | ? | **Tencent custom** ⚠️ | **NO (EU excluded)** | — | Parallel decoding. **NOT for EU use.** Only 69 stars. |
| **Logics-Parsing-Omni** | Alibaba | 2026-03 | ? | **Apache 2.0** ✅ | **YES** | — | Layout, reading order, structured parsing. |
| **MinerU 2.5** | OpenDataLab | 2025-09 | 1.2B | Apache 2.0 + terms ⚠️ | YES (<$20M rev) | — | Efficient high-resolution parsing. |
| **dots.ocr** | Xiaohongshu | 2025-07 | ? | **NONE** ❌ | **UNKNOWN** | — | Multilingual layout in single VLM. **No license file found.** |
| **DeepSeek-OCR 2** | DeepSeek | 2026-01 | 3.3B | **Apache 2.0** ✅ | **YES** | — | Visual causal flow. Table TEDS 80.2. |
| **DeepSeek-OCR** | DeepSeek | 2025-10 | 3.3B | **MIT** ✅ | **YES** | 75.7 | olmOCR-bench 75.7. Table tests 80.2. 23,675 stars. |
| **MonkeyOCR-pro-3B** | HUST | 2025-07 | 3B | **Apache 2.0** ✅ | **YES** | — | Table TEDS 81.5 (EN). "Surpassed GPT-4o." |
| **Dolphin-2.0** | ByteDance | 2026-02 | ? | **ByteDance custom** ⚠️ | **UNKNOWN** | — | Universal parsing, anchor prompting. License file 404. |
| **Dolphin-1.5** | ByteDance | 2025-10 | ? | **ByteDance custom** ⚠️ | **UNKNOWN** | — | Heterogeneous-anchor parsing. |
| **Dolphin** | ByteDance | 2025-05 | ? | **ByteDance custom** ⚠️ | **UNKNOWN** | — | Original anchor-prompting parser. 9,039 stars. |

### General VLMs with strong OCR (3 models)

| Model | Provider | Open weights | Size | License | Commercial? | OCRBench v2 | Parsing |
|---|---|---|---|---|---|---|---|
| **Qwen3-VL-235B-A22B** | Alibaba | Yes | 235B (A22B active) | **Apache 2.0** ✅ | **YES** | — | — |
| **Qwen3-VL-30B-A3B** | Alibaba | Yes | 30B (A3B active) | **Apache 2.0** ✅ | **YES** | — | — |
| **Gemini 3 Pro** | Google | No | undisclosed | **Proprietary API** | Pay per use | 63.4 | **93.9** |

### Ovis2.6-30B-A3B (general VLM)

| Model | Org | Size | License | Notes |
|---|---|---|---|---|
| **Ovis2.6-30B-A3B** | AIDC-AI | 30B (A3B) | **NONE on GitHub** ❌ | Need to verify. OvisOCR2 (same org) is Apache 2.0, but the base Ovis2.6 repo shows no license. |

---

## Key findings

### Finding 1: OvisOCR2 is the NEW SOTA — and it's tiny

**OvisOCR2** (AIDC-AI, released 2026-07-13) achieves **96.58 on OmniDocBench v1.6** — beating PaddleOCR-VL-1.6 (96.34) and ALL pipeline methods. It's only **0.8B parameters** — smaller than every other top model. It's the first end-to-end model to top a leaderboard previously dominated by multi-stage pipelines.

**License: Apache 2.0** (verified from HuggingFace model card). Commercial-safe. No weight restrictions.

**Relevance to CoverWise:** At 0.8B, it can run locally on the M3 Max (96GB RAM). It produces Markdown in natural reading order, covering text, formulas, tables, and visual regions. This could be the single model that replaces PyMuPDF + pdfplumber + GMFT + docTR — if it handles Indian insurance PDFs well.

### Finding 2: Three "Tencent Community License" models are NOT EU-safe

**HunyuanOCR-1.5** and **Youtu-Parsing** both use the Tencent Community License Agreement which **explicitly excludes the European Union, United Kingdom, and South Korea**. If CoverWise ever serves users in those regions, these models cannot be used.

**For India-only launch:** technically usable, but the restrictive license terms (Tencent retains broad rights, including to terminate) make them risky for a commercial product. **Recommend avoiding Tencent-licensed models.**

### Finding 3: ByteDance Dolphin license is unverifiable

All three Dolphin versions (1.0, 1.5, 2.0) have "Other" license on GitHub, and the LICENSE file returns 404 on the main branch. This means either:
- The license is in a non-standard location
- The repo uses a custom license not detectable by GitHub
- The license file was removed

**Until verified: treat as NOT commercial-safe.** Do not use without confirming the actual license terms.

### Finding 4: dots.ocr has NO license

GitHub returns null for the license field. No LICENSE file in the repo. This means the code is **"all rights reserved"** by default under copyright law. **Do not use without explicit permission from Xiaohongshu/RedNote HiLab.**

### Finding 5: Qwen3-VL-235B is Apache 2.0 — including weights

Qwen3-VL-235B-A22B-Instruct (235B params, 22B active MoE) is confirmed Apache 2.0 from HuggingFace tags. This is a general-purpose VLM (not a specialist parser), but its OCRBench v2 performance and document understanding make it relevant. The 30B-A3B variant is also Apache 2.0.

However, 235B parameters requires ~470GB VRAM — not runnable locally. The 30B-A3B variant needs ~60GB — feasible on the M3 Max (96GB) via MLX/Ollama.

### Finding 6: Commercial-safe frontier parsers (ranked by CoverWise fit)

| Rank | Model | Size | License | OmniDocBench | Why for CoverWise |
|---|---|---|---|---|---|
| 1 | **OvisOCR2** | 0.8B | Apache 2.0 | **96.58** | Tiny, SOTA, end-to-end. Runs locally. |
| 2 | **PaddleOCR-VL-1.6** | 0.9B | Apache 2.0 | 96.34 | Previous SOTA. Multilingual. |
| 3 | **GLM-OCR** | 0.9B | Apache 2.0 | 95.22 | KIE (key info extraction) — directly targets label-value. |
| 4 | **MinerU2.5-Pro** | 1.2B | Apache 2.0 + terms | 95.39 | Cross-page tables. Attribution required. |
| 5 | **MonkeyOCR-pro-3B** | 3B | Apache 2.0 | — | Table TEDS 81.5. Beat GPT-4o. |
| 6 | **DeepSeek-OCR 2** | 3.3B | Apache 2.0 | — | Causal flow. MIT models (v1) also safe. |
| 7 | **Logics-Parsing-Omni** | ? | Apache 2.0 | — | Layout + reading order. |
| 8 | **Unlimited-OCR** | ? | MIT | — | Long-horizon OCR. |

### Finding 7: The right comparison for CoverWise

These are ALL VLM-based parsers — they take page images as input and output structured text/Markdown. This is fundamentally different from PyMuPDF/pdfplumber (which extract from the PDF's embedded text stream).

**VLM parsers are the right approach when:**
- The PDF is scanned (no embedded text)
- Tables are borderless/complex (PyMuPDF can't detect them)
- The layout is non-standard (forms, certificates, schedules)

**PyMuPDF/pdfplumber are better when:**
- The PDF is born-digital (embedded text is lossless)
- Speed matters (PyMuPDF: <0.5s/page; VLMs: 0.3-5s/page)
- No GPU is available (most VLMs need one)

**The hybrid approach for CoverWise:**
1. Born-digital PDF → pdfplumber (MIT) for text + tables
2. Scanned/hard PDF → VLM parser (OvisOCR2 or GLM-OCR) for structured extraction
3. The VLM runs locally on the M3 Max during development; on a GPU instance in production

---

## Anything else? (motto_v4 §0.1.1)

**Q: Should we benchmark OvisOCR2 against the real ICICI Lombard policy?**
A: YES — if it can parse the schedule page with tables correctly (keeping labels and values together), it would solve the root cause problem at the parsing layer, making chunking strategy irrelevant. This is the highest-value benchmark to run next.

**Q: Can OvisOCR2 (0.8B) run without a GPU?**
A: At 0.8B parameters, it needs ~1.6GB VRAM (bf16). The M3 Max has 96GB unified memory — it will run easily. On CPU-only (Cloud Run free tier), inference might be slow (~5-10s/page) but feasible. With vLLM on GPU: 0.35s/page (A100).

**Q: What about the base model for OvisOCR2?**
A: It's built on Qwen3.5-0.8B — a very small language model fine-tuned specifically for document parsing. The fine-tuning used SFT + RL + OPD (Online Policy Distillation). The model generates Markdown directly from page images.

**Q: Are these models available on Ollama for local dev?**
A: Some are. DeepSeek-OCR and MonkeyOCR have Ollama-compatible versions. OvisOCR2 uses vLLM (not Ollama) but could potentially be converted. For development on the M3 Max, any model ≤3B will run via vLLM or MLX.
