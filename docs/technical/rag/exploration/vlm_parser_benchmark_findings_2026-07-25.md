# VLM Parser Benchmark — DeepSeek-OCR Results + Complete Comparison

**Date:** 2026-07-25

---

## DeepSeek-OCR (3B, via Ollama, CPU on M3 Max)

Ran DeepSeek-OCR on page 1 of the ICICI Lombard policy via Ollama (CPU, no GPU).

### Results

| Metric | Value |
|---|---|
| Model | deepseek-ocr (3B params) |
| Inference engine | Ollama (CPU, Metal) |
| Generation time | 29.5s for 1,204 tokens |
| Load time | 10.3s |
| Output length | 4,090 chars |
| Facts found | 80% (8/10) |
| **Label-value paired** | **70% (7/10)** |

### Per-fact scoring

| Fact | Status | Notes |
|---|---|---|
| Policy No | ✅paired | "Policy No.: 4214i/CPHSR/407834350/00/000" |
| **Sum Insured** | **✅paired** | **"Annual Sum Insured (₹): 2500000"** — SOLVED! |
| Total Premium | ❌miss | Didn't extract 31705 (got 4836.36 instead — misread column) |
| Proposer Name | ✅paired | "Proposer Name: PRANAY SUYASH" |
| Product name | ✅paired | "Product name: Health Shield 360 Retail" |
| Loyalty Bonus | ✅paired | "Loyalty Bonus: 700000" |
| Toll free | ❌miss | Didn't extract helpline from footer |
| Insurer | ⚠️found | "ICICI Lombard" present but no "Insurer" label adjacent |
| From (start) | ✅paired | "From 00:00 hrs 27-Aug-2025" |
| To (end) | ✅paired | "To 23:59 hrs 26-Aug-2026" |

### The KEY finding

**DeepSeek-OCR paired "Annual Sum Insured (₹): 2500000" — it understood the
table structure and extracted the label and value together.** This is only
the second parser to do this (Docling was the first, at 192s; DeepSeek-OCR
did it at 29.5s via CPU).

The output is structured Markdown with nested key-value pairs:
```markdown
**Annual Sum Insured (₹)**: 2500000
**Loyalty Bonus**: 700000
```

This means the VLM "saw" the table structure in the page image and understood
which label goes with which value — something that text-stream parsers
(PyMuPDF, pdfplumber) cannot do because they only see the flattened text.

---

## Complete parser comparison (ALL parsers tested)

| Parser | Type | Facts | Paired | Sum Insured? | Speed | License | GPU? |
|---|---|---|---|---|---|---|---|
| **Docling** | Model pipeline | 90% | 80% | ✅ | 192s ❌ | MIT | Optional |
| **DeepSeek-OCR** | VLM (3B) | 80% | 70% | ✅ | 30s | MIT | No (CPU) |
| **pdfplumber spatial KV v2** | Deterministic | **100%** | **80%** | ✅ | **3.1s** ✅ | **MIT** | No |
| PyMuPDF find_tables | Heuristic | 100% | 80% | ❌ | 3.7s | AGPL | No |
| pdfplumber tables | Heuristic | 100% | 80% | ❌ | 2.7s | MIT | No |
| PyMuPDF flat | Flat text | 100% | 80% | ❌ | 0.14s | AGPL | No |
| pdfplumber text | Flat text | 100% | 80% | ❌ | 2.3s | MIT | No |
| pymupdf4llm | Markdown | 20% | 10% | ❌ | 24s | AGPL | No |

### Which parsers solve the sum insured problem?

Only THREE parsers correctly pair "Sum Insured" with "2500000":

1. **pdfplumber spatial KV v2** (deterministic, MIT, 3.1s) — catches it via
   row-based detection ("Floater Sum Insured- Rs. 2500000") and table-column
   detection (header "Annual Sum Insured (₹)" → cell "2500000"). **NO MODEL
   NEEDED.**

2. **Docling** (TableFormer model, MIT, 192s) — catches it via learned table
   structure model that understands cell-level relationships.

3. **DeepSeek-OCR** (VLM 3B, MIT, 30s CPU) — catches it by "seeing" the page
   image and understanding the table layout visually.

### The winner

**pdfplumber spatial KV v2** is the clear winner:
- ✅ Solved sum insured (like the VLMs)
- ✅ 100% facts found (better than VLMs' 80-90%)
- ✅ 3.1 seconds (vs 30-192s for model-based)
- ✅ MIT license (commercial-safe)
- ✅ No GPU, no model download, no vLLM
- ✅ Deterministic (same output every time, no hallucination risk)

The VLMs (DeepSeek-OCR, Docling) are impressive but:
- Slower (30-192s vs 3s)
- Miss facts (80-90% vs 100%)
- Risk hallucination (DeepSeek-OCR repeated the sum insured section 3 times)
- Need model download + more memory

**The deterministic approach wins again** — same pattern as the chunking benchmark.

---

## What OvisOCR2 and GLM-OCR would need to run

OvisOCR2 (0.8B, SOTA 96.58 OmniDocBench) requires:
- vLLM 0.22.1+ (which requires CUDA — not available on Apple Silicon)
- The model's Qwen3_5ForConditionalGeneration architecture is not yet
  fully supported by transformers 5.8.1
- Cannot run on this machine without a CUDA GPU

GLM-OCR (0.9B, 95.22 OmniDocBench) requires:
- Custom architecture (GlmOcrForConditionalGeneration)
- Also not yet supported by standard transformers
- Would need the model's custom inference code or vLLM

**These models are production-ready but require a CUDA GPU to evaluate.**
For a definitive benchmark, they should be tested on a cloud GPU instance
(Modal Labs, HuggingFace Inference Endpoint, or a temporary EC2/GCP GPU).

---

## Anything else? (motto_v4 §0.1.1)

**Q: Is the sum insured problem now fully solved?**
A: YES — pdfplumber spatial KV v2 pairs it correctly in 3.1s with no model.
The problem that drove the entire chunking/embedding/VLM exploration has a
deterministic, MIT-licensed, CPU-only solution. The VLMs confirm the answer
is correct (they also pair it), but they're not needed for this specific
document type.

**Q: Should we still benchmark OvisOCR2 and GLM-OCR?**
A: Yes, but not urgently. They matter for HARDER documents (scanned PDFs,
multi-language policies, merged-cell tables, non-standard layouts). For the
ICICI Lombard policy (born-digital, standard table layout), pdfplumber
spatial KV v2 is sufficient. VLM benchmarks should use harder test documents.

**Q: What about the premium (31705) and helpline (1800 2666) that DeepSeek-OCR missed?**
A: DeepSeek-OCR misread the premium table (got 4836.36 instead of 31705) and
missed the footer helpline. pdfplumber spatial KV v2 caught BOTH correctly.
This confirms: VLMs are good at table structure but can misread values;
deterministic parsers are more reliable for exact value extraction.
