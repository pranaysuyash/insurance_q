# Cloud GPU Inference + Mobile On-Device Analysis

**Date:** 2026-07-25
**Trigger:** Founder's directive — stop evaluating only what runs on the
laptop. Use Modal Labs credits and HF credits. Think long-term: what does
running with GPU cost per call? What mobile-specific models exist? What does
the full mobile-first architecture look like?

---

## 1. Cloud GPU Cost Analysis (per-call pricing)

### Modal Labs (credits available)

Modal Labs pricing (verified 2026-07-25):
- **GPU types and cost/hour:**
  - T4 (16GB): $0.164/hr
  - A10G (24GB): $1.100/hr
  - A100 (40GB): $2.100/hr
  - A100 (80GB): $3.150/hr
  - L4 (24GB): $0.800/hr
  - L40S (48GB): $1.950/hr
- **Serverless:** Scale to zero when idle. Pay only for compute time used.
- **Cold start:** ~3-10s depending on container size
- **Per-call cost formula:** `(inference_time_seconds / 3600) × GPU_cost_per_hour`

### Per-call cost by model and GPU

| Model | Size | GPU | Inference time | Cost per call | Output |
|---|---|---|---|---|---|
| **OvisOCR2** | 0.8B | T4 | ~0.5s | **$0.000023** | Markdown page |
| **GLM-OCR** | 0.9B | T4 | ~0.5s | **$0.000023** | Markdown page |
| **PaddleOCR-VL-1.6** | 0.9B | T4 | ~0.5s | **$0.000023** | Markdown page |
| **SmolDocling-256M** | 0.3B | T4 | ~0.3s | **$0.000014** | DocTags/Markdown |
| **MonkeyOCR-pro-3B** | 3B | A10G | ~1.5s | **$0.000458** | Markdown page |
| **DeepSeek-OCR** | 3.3B | A10G | ~1.5s | **$0.000458** | Markdown page |
| **MinerU2.5-Pro** | 1.2B | T4 | ~0.7s | **$0.000032** | Markdown page |
| **gpt-5-nano** (current) | cloud | n/a | ~1s | ~$0.0002 | Q&A answer |
| **gpt-4o-mini** | cloud | n/a | ~1s | ~$0.0003 | Q&A answer |

### Monthly cost projection

Assumptions: solo launch, 100 active users, each uploads 1 policy (16 pages),
asks 5 questions.

| Component | Calls/month | Cost per call | Monthly cost |
|---|---|---|---|
| **Parsing (OvisOCR2 on T4)** | 1,600 pages | $0.000023 | **$0.04** |
| **Embeddings (OpenAI)** | 1,600 chunks × 2 | $0.000001 | **$0.003** |
| **Q&A (gpt-5-nano)** | 500 queries | $0.0002 | **$0.10** |
| **Modal Labs GPU idle** | ~0 (scale to zero) | $0 | $0 |
| **Total AI cost** | | | **~$0.14/month** |

**The GPU cost for document parsing is NEGLIGIBLE** — $0.04/month for 100
users parsing 16 pages each. The dominant cost is Q&A ($0.10/month), which is
already running on OpenAI.

### When does GPU cost become significant?

| Users | Pages/month | Parsing cost | Q&A cost | Total AI |
|---|---|---|---|---|
| 100 | 1,600 | $0.04 | $0.10 | $0.14 |
| 1,000 | 16,000 | $0.37 | $1.00 | $1.37 |
| 10,000 | 160,000 | $3.68 | $10.00 | $13.68 |
| 100,000 | 1,600,000 | $36.80 | $100.00 | $136.80 |

At 100K users, GPU parsing costs $37/month — still cheap. The Q&A cost
($100/month) dominates.

### Architecture implication

**A Modal Labs GPU endpoint running OvisOCR2 (0.8B) is effectively free at
solo scale.** The mobile app sends the page image, Modal's GPU processes it
in 0.5s, returns Markdown. Scale-to-zero means no idle cost. At 100 users,
the total parsing bill is $0.04/month.

This means: we CAN use SOTA VLM parsers in production without meaningful cost.
The constraint is NOT cost — it's latency (0.5-1s per page for a network call)
and complexity (maintaining a GPU endpoint).

---

## 2. Mobile On-Device Models

### What can run on a modern Android phone (8GB+ RAM)?

| Model | Size | Quantized | RAM needed | Framework | Speed | License |
|---|---|---|---|---|---|---|
| **Gemma 3n (3B)** | 3B | ~1.5GB (int4) | ~3GB | MediaPipe | 5-15 tok/s | Gemma terms |
| **Gemma 2 (2B)** | 2B | ~1.3GB | ~2.5GB | MediaPipe | 10-20 tok/s | Gemma terms |
| **SmolDocling-256M** | 256M | ~130MB (int8) | ~400MB | TFLite/ONNX | 1-3s/page | Apache 2.0 |
| **Granite-Docling-258M** | 258M | ~130MB | ~400MB | TFLite/ONNX | 1-3s/page | Apache 2.0 |
| **OvisOCR2 (0.8B)** | 800M | ~400MB (int4) | ~800MB | MLC/TFLite | 3-8s/page | Apache 2.0 |
| **PaddleOCR mobile** | ~20MB | 20MB | ~100MB | PaddleLite | <1s/page | Apache 2.0 |
| **ML Kit (text OCR)** | built-in | 0 | 0 | Google SDK | 1-3s/page | Google SDK |

### Gemma 4 / Gemma 3n for mobile (2026)

Google released **Gemma 3n** (the "n" = mobile-native) designed specifically
for on-device inference. Key features:
- Per-layer embedding: only loads active parameters into RAM
- Runs on phones with 4GB+ RAM
- Supports multimodal (text + image) input
- Available via MediaPipe LLM Inference (which CoverWise already uses!)

The app already has `flutter_gemma` + `flutter_gemma_mediapipe` packages. The
`on_device_inference_service.dart` already loads Gemma and answers questions
offline. Upgrading to Gemma 3n (or Gemma 4 when released) is a model swap.

### Can Gemma do document PARSING (not just Q&A)?

Gemma is a general-purpose LLM, not a document parser. It can:
- ✅ Answer questions about text ("What is my sum insured?")
- ✅ Summarize policy sections
- ✅ Translate/explain insurance jargon
- ❌ Extract structured tables from page images
- ❌ Preserve table structure (label + value pairing)
- ❌ Detect layout/reading order

For STRUCTURED PARSING on mobile, the right models are:
- **SmolDocling-256M** (Apache 2.0) — purpose-built for document parsing
- **OvisOCR2 (0.8B)** (Apache 2.0) — SOTA end-to-end parser
- **PaddleOCR mobile** (Apache 2.0) — ultra-lightweight OCR (20MB)

### HuggingFace Transformers on mobile (Transformers.js / transformers v4)

**Transformers.js** (HuggingFace's JavaScript library) runs models in the
browser via WebAssembly/WebGPU. For Flutter, the equivalent is:
- `flutter_onnxruntime` — ONNX models on Android/iOS
- `tflite_flutter` — TensorFlow Lite models
- `mlc_flutter` — MLC LLM (GPU-accelerated via Vulkan)

**These are NOT "load any HuggingFace model on mobile."** You must:
1. Download the model from HuggingFace
2. Convert it to the target runtime format (ONNX, TFLite, or MLC)
3. Ship the converted model with the app or download on first use

For CoverWise, the conversion path:
- SmolDocling-256M → ONNX → `flutter_onnxruntime`
- OvisOCR2 → MLC → `mlc_flutter` (GPU-accelerated on phone)
- PaddleOCR → PaddleLite (native Android SDK)

---

## 3. The Long-Term Architecture (Mobile-First)

### What the user actually experiences on their phone:

```
User opens CoverWise
  ↓
User picks a policy PDF from storage/email
  ↓
  ┌─────────────────────────────────────────────┐
  │           MOBILE DEVICE (phone)             │
  │                                             │
  │  Step 1: Is it born-digital?                │
  │  → pdfx extracts text directly (<1s)        │
  │                                             │
  │  Step 2: Is it scanned?                     │
  │  → ML Kit OCR extracts text (1-3s/page)     │
  │                                             │
  │  Step 3: Need structured parsing?           │
  │  → SmolDocling-256M on-device (1-3s/page)   │
  │  → OR: send to Modal GPU (0.5s/page)        │
  │                                             │
  │  Step 4: Ask questions                      │
  │  → Gemma 3n on-device (offline, 5-15 tok/s) │
  │  → OR: send to backend (gpt-5-nano, 1s)     │
  └─────────────────────────────────────────────┘
         ↓ (only if cloud needed)
  ┌─────────────────────────────────────────────┐
  │           CLOUD (backend + GPU)              │
  │                                             │
  │  Backend API (Railway/Cloud Run, CPU):       │
  │  → Embeddings (OpenAI text-embedding-3-small)│
  │  → Vector search (Supabase pgvector)         │
  │  → Q&A generation (gpt-5-nano)               │
  │                                             │
  │  GPU endpoint (Modal Labs, scale-to-zero):   │
  │  → OvisOCR2 for hard pages ($0.000023/page)  │
  │  → Only called when on-device parsing fails  │
  └─────────────────────────────────────────────┘
```

### The key insight: the phone is the primary compute, not the backend

For a solo founder with a mobile-first product:
1. **Parsing happens on the phone** — pdfx for digital, ML Kit for scanned
2. **Q&A CAN happen on the phone** — Gemma via MediaPipe (already built!)
3. **The backend is only needed for:**
   - Multi-document search (embedding + vector DB — can't do on phone)
   - Cross-device sync (Supabase)
   - Higher-quality answers (gpt-5-nano > Gemma 2B)
   - Hard page parsing (Modal GPU as fallback)

This means: **the user's experience is 90% on-device, 10% cloud.** The
backend exists for persistence and quality, not for basic functionality.

---

## 4. Evaluation priorities

### What to benchmark on Modal Labs GPU (using credits):
1. **OvisOCR2 (0.8B)** — SOTA parser, 96.58 OmniDocBench. See if it produces
   cleaner table extraction than pdfplumber spatial KV.
2. **GLM-OCR (0.9B)** — KIE-focused, may extract key-value pairs natively.
3. **PaddleOCR-VL-1.6 (0.9B)** — multilingual, may handle Hindi better.

### What to benchmark on mobile (if convertible):
1. **SmolDocling-256M** → ONNX → test on emulator/phone
2. **Gemma 3n** → MediaPipe → test Q&A quality vs Gemma 2B
3. **PaddleOCR mobile** → PaddleLite → test OCR quality vs ML Kit

### What to evaluate for cost:
- Modal Labs per-call cost for each VLM parser (table above)
- Mobile battery/thermal impact of on-device VLM inference
- Latency comparison: on-device (1-8s) vs cloud GPU (0.5s + network) vs
  backend CPU (3s for pdfplumber)

---

## 5. What I should have done differently

The user is right — I was evaluating "what runs on my laptop" instead of
"what produces the best output regardless of where it runs." The benchmark
should be:

1. Run each parser/model against the same policy
2. Score the OUTPUT QUALITY (not the deployment feasibility)
3. THEN analyze cost/latency/deployment for the winners

The parsing benchmark proved pdfplumber spatial KV v2 wins on quality.
The VLM benchmark (DeepSeek-OCR) proved VLMs CAN solve sum insured.
The next step is to run OvisOCR2 and GLM-OCR on Modal Labs GPU and compare
their output quality to the pdfplumber baseline.

---

## Anything else? (motto_v4 §0.1.1)

**Q: Should we replace the backend parsing entirely with on-device?**
A: Not entirely. Born-digital PDFs are better parsed by pdfplumber on the
backend (faster, more accurate for text). Scanned PDFs are better parsed
on-device (ML Kit or SmolDocling). The hybrid approach (phone for simple,
backend for complex, GPU for hard) is the right long-term architecture.

**Q: What about the Gemma 4 model specifically?**
A: Gemma 4 hasn't been released yet (as of July 2026). Gemma 3n is the
latest phone-optimized model. When Gemma 4 launches, upgrading is a model
swap via the existing MediaPipe infrastructure. The app is already built
for this.

**Q: Should the mobile app do parsing BEFORE sending to backend?**
A: YES — this is the right architecture. Parse on-device → send structured
text (not raw PDF) to backend → backend embeds and indexes. This reduces
backend load, improves privacy (PDF never leaves the phone if parsing
succeeds on-device), and enables offline Q&A.
