# Mobile On-Device Parsing & Inference — Research & Evaluation

**Date:** 2026-07-25
**Context:** Phase 1 is mobile-only. The user's phone does ALL document
processing before sending to the backend. Understanding what can run on-device
is critical — it determines whether we need a backend GPU at all.

---

## Current mobile ML stack (already in pubspec.yaml)

The app ALREADY has two on-device ML capabilities:

### 1. ML Kit Text Recognition (`google_mlkit_text_recognition: ^0.16.0`)
- **What it does:** OCR on page images — extracts text from scanned PDFs
- **Where it runs:** On the Android device, using Google's on-device models
- **Speed:** ~1-3s per page (depending on device)
- **Languages:** Latin + Devanagari (Hindi) scripts supported
- **License:** Google proprietary SDK (free, commercially usable)
- **Used in:** `ml_ocr_service.dart` — renders PDF pages to images, runs OCR
- **Limitation:** Text-only extraction. No table structure. No layout. No
  reading order. No key-value pairing.

### 2. Gemma via MediaPipe (`flutter_gemma: ^1.3.1` + `flutter_gemma_mediapipe: ^1.0.4`)
- **What it does:** On-device LLM for offline Q&A
- **Where it runs:** On the Android device via Google MediaPipe LLM Inference
- **Model:** Gemma (2B quantized, downloaded on first use)
- **Used in:** `on_device_inference_service.dart` — loads policy text as
  context, answers questions offline WITHOUT the backend
- **License:** Gemma terms (commercial use allowed with restrictions)
- **Status:** Implemented but requires `onDeviceInferenceEnabled` config flag
- **Key insight:** This means the app can ALREADY do on-device document Q&A
  without any backend — it's an offline mode that runs entirely on the phone

---

## The question: can we do document PARSING (not just OCR) on mobile?

ML Kit does OCR (text extraction from images). But it doesn't do:
- Table structure detection
- Key-value pair extraction
- Layout/reading order preservation
- Markdown generation

Can a VLM document parser run on the phone?

---

## Mobile inference frameworks (2026)

| Framework | Platform | Models supported | Quantization | Performance |
|---|---|---|---|---|
| **Google MediaPipe LLM** | Android + iOS | Gemma 2B/7B, Phi-2/3, Falcon, Mistral | int4/int8 | 3-15 tok/s on modern phones |
| **TensorFlow Lite** | Android + iOS | Any TFLite-converted model | int8/float16 | Fast for small models |
| **ONNX Runtime Mobile** | Android + iOS | ONNX-converted models | int8/float16 | Good for vision models |
| **llama.cpp (Android)** | Android | GGUF models (any LLaMA/Mistral/Qwen) | int4/int8 | 5-20 tok/s depending on model |
| **MLC LLM** | Android + iOS | Any LLM compiled via MLC | int4 | GPU acceleration via Vulkan/Metal |
| **ExecuTorch (PyTorch)** | Android + iOS | PyTorch models exported via ExecuTorch | int8 | Early stage, improving |
| **Apple MLX** | iOS/macOS only | MLX-format models | int4/float16 | Excellent on Apple Silicon |

---

## VLM document parsers that CAN run on mobile

### Tier 1: Proven mobile-ready (sub-1B, quantizable)

| Model | Size | Mobile framework | Quantized size | Speed (est.) | License | Tables? |
|---|---|---|---|---|---|---|
| **SmolDocling-256M** | 256M | TFLite / ONNX / MLC | ~130MB (int8) | ~1-3s/page | Apache 2.0 | ✅ OTSL |
| **Granite-Docling-258M** | 258M | TFLite / ONNX | ~130MB (int8) | ~1-3s/page | Apache 2.0 | ✅ |
| **OvisOCR2** | 800M | MediaPipe / MLC / llama.cpp | ~400MB (int4) | ~3-8s/page | Apache 2.0 | ✅ |
| **PaddleOCR-VL** | 900M | PaddleLite (native Android) | ~450MB (int4) | ~3-8s/page | Apache 2.0 | ✅ |
| **GLM-OCR** | 900M | MLC / llama.cpp | ~450MB (int4) | ~3-8s/page | Apache 2.0 | ✅ |

### Tier 2: Feasible but heavy (1-3B)

| Model | Size | Mobile framework | Quantized size | Speed (est.) | License |
|---|---|---|---|---|---|
| **MinerU2.5-Pro** | 1.2B | MLC / llama.cpp | ~600MB (int4) | ~5-15s/page | Apache 2.0 + terms |
| **MonkeyOCR-pro-3B** | 3B | MLC / llama.cpp | ~1.5GB (int4) | ~10-30s/page | Apache 2.0 |
| **DeepSeek-OCR** | 3.3B | MLC / llama.cpp | ~1.7GB (int4) | ~10-30s/page | MIT |

### Tier 3: Too large for mobile (>5B)

| Model | Size | Why not mobile |
|---|---|---|
| Qwen3-VL-235B | 235B | Needs data center |
| Gemini 3 Pro | undisclosed | Cloud API only |
| MonkeyOCR-pro-3B | 3B | Marginal — only on flagship phones |

---

## The key insight: SmolDocling-256M is the mobile parsing answer

**SmolDocling-256M** (IBM, Apache 2.0):
- **256M parameters** — smaller than the Gemma 2B model the app already runs
- **~130MB quantized (int8)** — smaller than a typical policy PDF
- **Output: DocTags → Markdown** — preserves layout, tables, reading order
- **OTSL table format** — keeps table cell structure (label + value together)
- **Trained on DocLayNet** — which includes financial reports
- **Apache 2.0** including model weights — fully commercial-safe

**This solves the label-value disconnection problem ON THE PHONE, before
anything is sent to the backend.** If SmolDocling can parse the ICICI Lombard
schedule page and keep "Annual Sum Insured (₹)" and "2500000" in the same
table cell, the chunking/embedding problem disappears entirely.

### Deployment path for SmolDocling on Android:
1. Convert model to TFLite or ONNX format
2. Package as a Flutter plugin or use platform channels
3. Render PDF page to image (via pdfx, already in the app)
4. Feed image to SmolDocling → get Markdown with tables
5. Send Markdown to backend for embedding/RAG (or run Gemma on-device)

### Alternative: OvisOCR2 on mobile via MediaPipe
- 0.8B, ~400MB quantized
- Already compatible with MediaPipe (which the app uses for Gemma)
- SOTA accuracy (96.58 OmniDocBench)
- Outputs Markdown with tables directly

---

## Modal Labs / cloud inference alternatives

If on-device VLM parsing is too slow or heavy, serverless GPU is the
alternative — the mobile app sends the page image, gets back structured text:

| Platform | Model | Cost | Latency | Cold start |
|---|---|---|---|---|
| **Modal Labs** | Any HF model | $0.0001-0.001/request | 1-3s | ~1s (keep warm) |
| **Replicate** | OvisOCR2, GLM-OCR | $0.001-0.01/image | 2-5s | ~5s |
| **Fireworks AI** | Hosted VLMs | $0.001-0.01/image | 1-3s | ~1s |
| **HuggingFace Inference Endpoints** | Any HF model | $0.05-0.50/hour (dedicated) | <1s | none (dedicated) |

**For Phase 1 solo launch:** HuggingFace Inference Endpoints (dedicated,
no cold start) is the cheapest serverless GPU option — ~$0.05-0.10/hour for
a small GPU. Scale to zero when not in use = near-zero cost at low volume.

---

## Recommended mobile-first parsing architecture

### Phase 1 (launch): ML Kit + backend pdfplumber
```
User picks PDF
    ↓
Mobile: try direct text (pdfx) ← works for born-digital
    ↓ if no text (scanned)
Mobile: ML Kit OCR ← works on-device, free
    ↓
Mobile: send text to backend
    ↓
Backend: pdfplumber for tables + spatial KV
    ↓
Backend: embed + index + RAG
```

### Phase 1.5 (quality upgrade): SmolDocling on mobile
```
User picks PDF
    ↓
Mobile: render pages to images (pdfx)
    ↓
Mobile: SmolDocling-256M (on-device, ~130MB)
    → Markdown with tables, reading order, cell structure
    ↓
Mobile: send structured Markdown to backend
    ↓
Backend: embed (cleaner text → better embeddings) + RAG
```

### Phase 2 (scale): Modal Labs GPU for hard pages
```
User picks PDF
    ↓
Mobile: try direct text + ML Kit OCR
    ↓ if table extraction fails
Mobile: send page image to Modal Labs endpoint
    → OvisOCR2 (SOTA) on GPU
    → returns Markdown
    ↓
Backend: embed + RAG
```

---

## What's already built and how it fits

The app already has:
1. **ML Kit OCR** (`ml_ocr_service.dart`) — on-device OCR, Latin + Devanagari
2. **Gemma on-device** (`on_device_inference_service.dart`) — offline Q&A via
   MediaPipe, with untrusted-content fencing and session management
3. **flutter_gemma_mediapipe** — MediaPipe inference engine for Gemma

The infrastructure for on-device VLM inference EXISTS. Adding SmolDocling or
OvisOCR2 would use the same MediaPipe/TFLite path. The key work:
1. Convert the model to a mobile-compatible format (TFLite/MediaPipe)
2. Add a Flutter plugin or platform channel
3. Wire it into the upload flow (before backend submission)

---

## Anything else? (motto_v4 §0.1.1)

**Q: Can SmolDocling run via the existing flutter_gemma_mediapipe setup?**
A: Not directly — flutter_gemma is built for Gemma models specifically.
SmolDocling uses Idefics3 architecture. Would need a separate TFLite/ONNX
plugin. However, the MediaPipe inference engine itself is model-agnostic —
the flutter_gemma package just wraps it for Gemma.

**Q: What about running parsing models via HuggingFace Transformers on mobile?**
A: HF Transformers is Python-only. On mobile, you need a compiled inference
engine (TFLite, ONNX, MediaPipe, MLC). The model must be converted to the
target format. SmolDocling has a HuggingFace checkpoint that can be converted.

**Q: Is there a Flutter package for on-device transformers?**
A: `flutter_onnxruntime` (ONNX Runtime for Flutter) and `tflite_flutter`
are the main options. Neither has a "load any HF model" capability — you
convert the model offline and ship the compiled artifact.

**Q: Should we replace Gemma with a document parser model for on-device use?**
A: They serve different purposes. Gemma is for Q&A (answering questions from
text). SmolDocling is for parsing (extracting structured text from images).
Both could coexist: SmolDocling parses the PDF → Gemma answers questions
about the parsed text. This would be a fully offline CoverWise — no backend
needed for Q&A (only for embedding/indexing if multi-document search is needed).
