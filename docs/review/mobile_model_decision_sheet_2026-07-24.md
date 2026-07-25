# CoverWise mobile model decision sheet (2026-07-24)

**Date:** 2026-07-24

This is the single-sheet decision artifact requested in the last pass: “what was evaluated vs not, what key wiring exists, and what is actually runnable on Android/iOS.”

## 1) Source-of-truth rule for this sheet

- **Evaluated** = reproducible run present in this repo’s evidence files (local/synthetic/corpus and/or documented device evidence).
- **Not evaluated** = cataloged, scaffolded, or documented as present, but no qualifying run in this repo yet.
- **Local/offline** means **Android/iOS-native runtime path**, not desktop/mobile-surface APIs.
- **Hosted cloud** means API call path (OpenAI/OpenRouter/HF/Modal/etc.), even if credits or auth keys exist.

## 2) Credential key presence from Projects env files (values intentionally omitted)

| Project | Env file(s) checked | Key names present |
|---|---|---|
| `medpiper/insurance_app` | `.env`, `.env.example` | `OPENAI_API_KEY`, `HF_TOKEN` |
| `orbitcover-d2c` | `.env`, `.env.example` | `OPENROUTER_API_KEY` |
| `oc-b2b` | `.env` | (no key names in scope found) |
| `comfy` | `.env`, `.env.example` | `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` |
| `speech_experiments/model-lab` | `.env`, `.env.example` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` |
| `edureka` | `.env` | `OPENAI_API_KEY`, `HF_TOKEN`(via `HUGGINGFACE_API_KEY`), `GROQ_API_KEY`, `GEMINI_API_KEY` |
| `learning_for_kids` | `.env` | `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`, `GEMINI_API_KEY` |
| `adshot` | `.env` | `HF_TOKEN`, `GEMINI_API_KEY` |
| `bas5minute` | `.env.example` | `OPENAI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` |
| `notes` | `.env`, `.env.example` | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY` |
| `sentineltwin` | `.env` | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TOGETHER_API_KEY` |

**What this does/does not imply**

- Key-name presence means that environment surface exists somewhere in project scope.
- It does **not** mean a key is wired into CoverWise mobile product traffic.
- For policy-sensitive data flow, this must still go through CoverWise data-handling and policy gates before reuse.

## 3) Model/runtime execution matrix for CoverWise mobile decision (current state)

| Candidate / lane | Bucket | Android/iOS feasible? | Evidence status | Result | Why |
|---|---|---|---|---|---|
| OpenAI `gpt-5-nano` (direct) | Hosted API | No (cloud) | Evaluated (synthetic + held-out corpus policy) | ✅ | Canonical backend fallback path: `3/3` synthetic, `29/52` held-out policy (`accuracy=0.5577`, `citation_rate=0.9615`, `ragas faithfulness=0.8368`) | Evidence in `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted API | No (cloud) | Evaluated (synthetic) | ⚠️ (limited) | `2/3` synthetic pass, failed one grounded-answer case | Evidence in `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json` |
| OpenRouter `google/gemma-3-4b-it` | Hosted API | No (cloud) | Evaluated (synthetic) | ⚠️ (limited) | `1/3` synthetic pass, structured Q/A weak | Evidence in `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` |
| HF Inference (`Qwen/Qwen3-4B-Instruct-2507`) via HF token | Hosted API (HF Pro/Inference) | No (cloud) | Evaluated (synthetic) | ⚠️ (limited) | `2/3` synthetic pass, not ready as production fallback | Evidence in `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json` |
| Groq (candidate) | Hosted API | No (cloud) | Not evaluated in CoverWise (for this decision pass) | ⚠️ | Available in related project env, not wired into CoverWise now | Not in this decision ledger as production path |
| Modal Labs | Private hosted GPU | No (server/private cloud) | Explored by smoke URL only | ⚠️ | Useful for heavier benchmark/training; not on-device | `Comfy` credentialed; current run not app-corpus evaluated |
| `flutter_gemma` + MediaPipe local seam | Mobile-local framework | Android/iOS | Scaffolded, not executed | ⚠️ | Service exists with `ON_DEVICE_INFERENCE_ENABLED` + `ON_DEVICE_MODEL_URL` flags, no Android/iOS run yet | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart` |
| Gemma 3n E2B/E4B (`.task`) | Shared on-device target | Android/iOS (candidate) | Not executed | ⛔ | Candidate only | Needs model artifact + Android/iOS device matrix |
| Gemma 3 270M/1B | On-device text | Android/iOS (candidate) | Not executed | ⛔ | Candidate only for compact classification/short text routing |
| Qwen3 0.6B/1.7B/4B | On-device text | Android/iOS (candidate) | Not executed | ⛔ | Candidate only; export/runtimes not validated |
| Phi-4-mini-instruct | On-device text | Android/iOS (candidate) | Not executed | ⛔ | Candidate only |
| SmolLM3 3B | On-device text | Android/iOS (candidate) | Not executed | ⛔ | Candidate only |
| Ministral 3 3B | On-device multimodal fallback | Android/iOS (candidate) | Not executed | ⛔ | Candidate only, second-stage visual lane |
| Qwen3-VL 2B/4B | On-device VLM fallback | Android/iOS (candidate) | Not executed | ⛔ | Candidate only; visual failure lane, not default parser |
| Gemini Nano / AICore (Android managed) | Managed runtime | Android only | Not evaluated in CoverWise | ⛔ | Platform-native path unavailable until capability probing + product integration |
| Apple Foundation Models | Managed runtime | iOS only | Not evaluated in CoverWise | ⛔ | OS-dependent; needs supported/unsupported matrix + prompt regression |
| Transformers.js (WebGPU/ONNX) | WebBridge/runtime experiment | Mobile web only | Not evaluated in CoverWise-native path | ⛔ | Helpful for separate experiment; not native Flutter inference layer |
| Unlimited-OCR / Docling / MinerU / Marker / RT-DocLayout / Qwen3-VL / PaddleOCR-VL / etc. | Parsing frontier candidates | Android/iOS (if exported) | Not evaluated | ⛔ | Cataloged as frontier parsing candidates only, no in-repo device run |
| OCR + parsing baseline (PyMuPDF, docTR, OCR) | Server pipeline (canonical) | None for mobile local | Evaluated server-side | ✅ | Canonical baseline proven in policy corpus |
| EmbeddingGemma / Qwen3-Embedding | Local embedding candidate | Android/iOS (candidate) | Not executed | ⛔ | Planned for local-RAG stage after capability contract |

## 4) Fine-tuning / adapter status

- **No CoverWise production-ready fine-tuned checkpoint is currently in this decision lane.**
- No exported LoRA/QLoRA/adapter assets with Android/iOS deployment metadata (`tokenizer`, `quantization`, `artifact hash`, and runtime format) are wired into production flows.
- Any future fine-tune path must include: dataset provenance, privacy consent/lineage, tokenizer lock, export format, on-device benchmark, and rollback plan.

## 4a) 2025–2026 model catalog intake (decision posture)

The following catalog slices were re-checked and integrated as candidate inventory:

- [`mobile_model_catalog_2025_2026_2026-07-24.md`](mobile_model_catalog_2025_2026_2026-07-24.md)  
  (2025–2026 parser/ocr frontier models from `Recent Models 2024+`)
- [`mobile_model_general_vlm_frontier_2026-07-24.md`](mobile_model_general_vlm_frontier_2026-07-24.md)  
  (general OCR-capable VLMs; suitable only as secondary/fallback visual-stage candidates)

Decision posture from that intake:

- `Eval-only` for all catalog entries in this pass: **no Android/iOS device execution yet**.
- Parser frontier should prioritize: `RT-DocLayout`, `Unlimited-OCR`, `PaddleOCR-VL`, `MinerU*`, `Logics-Parsing*`, `Docling/Marker`, `Dolphin*`, `AgenticOCR`, `Qianfan/OCR` families.
- VLMs with broad OCR capability from the general sheet (for example `Qwen3.5/3.6`, `Gemini 3 Pro/2.5 Pro`, `MiniCPM-V*`, `Claude/NVIDIA families`) are not first-stage parser replacements without strong mobile-specific corpus + grounding gates.

## 5) Decision shortlist (fall back plan)

### Primary fallback order (for now)

1. **Keep hosted canonical path as default**: OpenAI `gpt-5-nano` + server evidence gates.
2. **Add explicit comparison routing only (not automatic factual fallback)**: OpenRouter/HF as benchmark lanes with logged provider/model/latency.
3. **Prototype mobile-local first lane**: `flutter_gemma` + Gemma 3n family with strict contract (`download integrity`, `fallback`, `timeouts`, `cancellation`, `thermal/rss`, and `schema/citation refusal` gates).
4. **Only after above gates pass**: evaluate Qwen/Phi/SmolLM/Ministral variants and managed-platform candidates (Gemini Nano / Foundation Models) in a single device matrix.

## 6) Why this matters for the “sota + niche” question

- “SOTA 2025–2026” models do **not** automatically qualify for Android/iOS app decisions.
- For mobile product readiness, only models/runtimes with **real device evidence** and an **execution contract** (artifact, runtime format, failure modes, fallback, cancellation, telemetry) are promotable.
- At present, for this repo: **no Android/iOS local/on-device model evaluation has yet been completed.**

## 7) Evaluated vs. not-evaluated in this pass

### Evaluated in this repo evidence (strictly reproducible runs)

| Candidate / lane | Where it was run | Evidence file | Status |
|---|---|---|---|
| OpenAI `gpt-5-nano` | Hosted synthetic + held-out corpus | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json` ; `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | ✅ `3/3` synthetic; held-out `52Q`: `accuracy=0.5577`, `citation_rate=0.9615`, `hallucination_rate=0.3333` |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted synthetic | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json` | ⚠️ `2/3` synthetic |
| OpenRouter `google/gemma-3-4b-it` | Hosted synthetic | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | ⚠️ `1/3` synthetic |
| HF `Qwen/Qwen3-4B-Instruct-2507` | Hosted synthetic | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json` | ⚠️ `2/3` synthetic |
| Policy OCR + parsing baseline (server canonical) | Server/corpus | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | ✅ `accuracy=0.5577`, `citation_rate=0.9615` |
| Local desktop OCR/vision checks (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`, DeepSeek-OCR) | Local fixture page transcribe | `docs/review/evidence/local-model-eval/gemma3-12b-2026-07-12.json`, `docs/review/evidence/local-model-eval/gemma3-4b-recheck-2026-07-12.json`, `docs/review/evidence/local-model-eval/deepseek-ocr-diagnostic-2026-07-12.json` | ✅ adapter/runtime compatibility; **not Android/iOS** |
| `flutter_gemma` + MediaPipe seam | Mobile code path | `mobile/lib/services/on_device_inference_service.dart` | ⚠️ scaffold present, no Android/iOS execution |

### Explicitly not evaluated in target Android/iOS runtime (yet)

- `Gemma 3n E2B/E4B`, `Gemma 3`, `Qwen3` (0.6/1.7/4B), `Phi-4-mini`, `SmolLM3`, `Ministral`, `Qwen3-VL`
- `Gemini Nano` / `Apple Foundation Models` managed integration
- `Transformers.js` as Flutter-native inference layer
- Frontier parser OCR candidates (`Docling`, `MinerU`, `Marker`, `RT-DocLayout`, `Unlimited-OCR`, `PaddleOCR-VL`, `P-MTP`, `Dolphin`) without mobile exports

### Fine-tune / adapter status (explicitly)

- No production-ready CoverWise fine-tuned model is wired into mobile today.
- No exported LoRA/QLoRA/adapter artifact with Android/iOS runtime metadata (`tokenizer`, `artifact hash`, `quantization`, runtime format) is currently used.
- Any future finetune route must include corpus provenance, export lineage, governance approval, and device benchmark gates before mobile use.

## 8) Key-surface sweep used for route planning (project-level inventory only)

| Project | Key names observed (`.env`, `.env.example`) |
|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `HF_TOKEN` |
| `orbitcover-d2c` | `OPENROUTER_API_KEY` |
| `comfy` | `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` |
| `edureka` | `OPENAI_API_KEY`, `HF_TOKEN`(via `HUGGINGFACE_API_KEY`), `GROQ_API_KEY`, `GEMINI_API_KEY` |
| `learning_for_kids` | `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`, `GEMINI_API_KEY` |
| `adshot` | `HF_TOKEN`, `GEMINI_API_KEY` |
| `bas5minute` | `OPENAI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` |
| `notes` | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY` |
| `sentineltwin` | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TOGETHER_API_KEY` |
| `invoice-intelligence` | `OPENAI_API_KEY`, `OPENROUTER_API_KEY` |
| `musicathon` | `HF_TOKEN` |
| `EchoPanel` | `HF_TOKEN` |

### Why this list is separate

- Key surface presence is **not** a production claim.
- A key can exist without an in-app routing contract or model-readiness gates.

## 9) Cross-links

- [Mobile exploration matrix](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_exploration_map_2026-07-24.md)
- [Mobile decision one-pager](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_decision_onepager_2026-07-24.md)
- [Technical mobile evaluation](/Users/pranay/Projects/medpiper/insurance_app/docs/technical/mobile_local_model_evaluation_2026-07-24.md)
