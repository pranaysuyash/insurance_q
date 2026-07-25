# Mobile model truth sheet (CoverWise, 2026-07-26)

Date: 2026-07-26

This is the current execution truth for your request: **what was explored**, **what is actually evaluated**, **what is still catalog/scaffold**, and **what’s missing for Android/iOS**.

## 1) Evidence-first status rule

- **EVAL** = reproducible evidence file for that runtime/stage in this repo.
- **SCaffold** = code/config/tests exist but no Android/iOS install/load/ask model telemetry.
- **Catalog-only** = listed/imported candidate without mobile execution evidence.
- **No-path** = not wired into CoverWise mobile route.

## 2) Pipeline-stage status for Android/iOS

| Stage | Android/iOS status | What is available | Evidence
|---|---|---|---|
| Parse / OCR / layout stage | **Catalog-only** for frontier parsers | Docling/Marker/MinerU/RT-DocLayout/Unlimited-OCR/PaddleOCR-VL/MonkeyOCR/Dolphin/etc. are shortlisted from catalog | `docs/review/mobile_model_full_evaluation_compendium_2026-07-26.md` and `docs/review/mobile_model_frontier_2026_plus_truth_matrix_2026-07-26.md` |
| Embedding / rerank | **No-path on-device** | Hosted `text-embedding-3-small` + cross-encoder used in server pipeline | `docs/review/mobile_model_truth_matrix_2026-07-25.md`, server pipeline evidence |
| Generation (policy QA) | **SCaffold + hosted fallback** | Hosted `openai`, `openrouter`, `hf` are compared; local seam exists via `flutter_gemma` | `docs/review/mobile_model_shortlist_truth_and_gaps_2026-07-26.md` and `mobile/lib/services/on_device_inference_service.dart` |

### 2.1 Execution truth by frontier set (2026-07-26)

- Frontier source parsed: `docs/review/mobile_model_frontier_2026_plus_truth_matrix_2026-07-26.md` (77 entries).
- Mobile execution status by model:
  - **Catalog-only**: **77/77**
  - **SCaffold**: `flutter_gemma` seam (no model manifest telemetry on-device)
  - **EVAL**: `0` mobile-native model proofs
- Hosted lane eval results are real and evidence-backed, but are not mobile-offline proofs:
  - OpenAI `gpt-5-nano`: `3/3`
  - OpenRouter `google/gemini-2.5-flash-lite`: `2/3`
  - OpenRouter `google/gemma-3-4b-it`: `1/3`
  - HF Pro `Qwen/Qwen3-4B-Instruct-2507`: `2/3`

## 3) Hosted lanes evaluated (paid API / credit usage)

| Lane | Provider | Status | Evidence | Why it matters |
|---|---|---|---|---|
| `gpt-5-nano` | OpenAI | **EVAL** | `docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json` | Stable comparison/fallback lane for now |
| `google/gemini-2.5-flash-lite` | OpenRouter | **EVAL (partial)** | `docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json` | Cost/latency benchmark lane only |
| `google/gemma-3-4b-it` | OpenRouter | **EVAL (partial)** | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | Weak pass rate; comparison only |
| `Qwen/Qwen3-4B-Instruct-2507` | HF Pro / HF Inference | **EVAL (partial)** | `docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json` | Comparison lane only |
| `policy` held-out corpus baseline | Hosted OpenAI policy flow | **EVAL** | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` (`52Q`, `accuracy=0.5577`, `citation_rate=0.9615`) | Useful for model comparison and quality baselining |

### 3.1 Latest continuation evidence (2026-07-26)

- `docs/review/evidence/provider-smoke/continuation-combined-2026-07-26c.json`  
  - OpenAI: `3/3`
  - OpenRouter `gemini-2.5-flash-lite`: `2/3`
  - HF Pro Qwen3: `2/3`
- `docs/review/evidence/provider-smoke/continuation-combined-gemma3-2026-07-26c.json`
  - OpenRouter `google/gemma-3-4b-it`: `1/3`

## 4) Android/iOS local inference truth

### 4.1 Current contract in app

- `flutter_gemma` path exists and is guarded by:
  - `ON_DEVICE_INFERENCE_ENABLED`
  - `ON_DEVICE_MODEL_URL`
  - HTTPS validation in `mobile/lib/config/app_config.dart`
- Service/test code exists:
  - `mobile/lib/services/on_device_inference_service.dart`
  - `mobile/test/on_device_inference_service_test.dart`
- Harness result: install-attempt path is reachable, but no real model install/load/ask telemetry.

Evidence:
- `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26.json` (and 26/25 variants)
- `flutter test test/on_device_inference_service_test.dart` run in this turn confirms:
  - config-flag compile checks pass,
  - install-attempt path is reachable under the same flags,
  - **no real model install/load/ask telemetry was produced** (flag-gated control path only).

### 4.2 Runtime model artifacts on disk

Scan result in repo for phone-exec artifacts (`.task/.gguf/.onnx/.safetensors/.tflite`):
- Only MLKit OCR pod resources found (not CoverWise model lane):
  - `mobile/ios/Pods/MLKitTextRecognition/Resources/LatinOCRResources/tflite_langid.tflite`
  - `mobile/ios/Pods/MLKitTextRecognition/Resources/LatinOCRResources/rpn_text_detector_mobile_space_to_depth_quantized_v2.tflite`

Conclusion: **no CoverWise mobile inference `.task/.gguf/.onnx/.safetensors` artifact is present**.

## 5) Models in your request scope (2025–2026) and status

From `document_parsers_extractors_catalog_2026_v2.xlsx` (`Recent Models 2024+`) → 77 entries re-exported in:
- `docs/review/evidence/local-model-eval/recent_models_2024_plus_inventory_2026-07-25.json`

Status for these 77:
- **Catalog-only for mobile execution**: all entries not yet installed/loaded/asked on Android/iOS in this repo.

Notable frontier groups retained for evaluation planning:
- **Parser/layout frontier:** `Docling`, `SmolDocling`, `Marker`, `MinerU`, `RT-DocLayout`, `PaddleOCR-VL`, `Dolphin`, `Unlimited-OCR`, `Qwen3-VL`, `P-MTP`, etc.
- **SOTA compact/local candidates to prove first:** `Gemma 3n` task family → then `Gemma 3 270M/1B`, `Qwen3 1.7B/4B`, `Phi-4-mini`, `SmolLM3`, `Ministral 3B`.
- **Managed-native checks:** Android `Gemini Nano`/AICore and iOS `Foundation Models` remain **No-path** until capability probes and latency/fail-safe telemetry are run on real devices.

## 6) Transformers.js and web-only confusion (explicit)

- **Transformers.js web/mobile-web**: treated as **No-path for Flutter-native Android/iOS inference** in this repo.
- Any “existence in web/webgl path” does **not** mean Android/iOS on-device execution.
- This is reflected in:
  - `docs/review/mobile_model_truth_matrix_2026-07-25.md`
  - `docs/review/exploration_map.md`

## 7) Fine-tune / adapter lane

- No production-ready mobile fine-tuned/LoRA/adapter pipeline is currently wired for Android/iOS.
- This includes missing bundle elements: tokenizer/quantization metadata + mobile export format + artifact hash + install/load/ask proof.
- Status: **Catalog-only / planning only**.

## 8) Cross-project key inventory used for routing decisions

- `medpiper/insurance_app`: `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OLLAMA_BASE_URL`, optional `GROQ_API_KEY`; no active `ON_DEVICE_*` in default checked set.
- `orbitcover-d2c`: `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` (not wired into this mobile route)
- `comfy`: HF/Modal keys present for benchmark infrastructure (`HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`)
- `speech_experiments/model-lab`: HF tokens present

Detailed map (values redacted): `docs/review/mobile_model_provider_key_inventory_2026-07-25.md`

## 9) What this means for your shortlist now

1. **Keep hosted `gpt-5-nano` as production-verified fallback** (stable evidence path).
2. **Use OpenRouter/HF only as controlled comparison planes** unless and until mobile artifact telemetry exists.
3. **First execution task to unlock real local path:** provide `.task` artifact + Android/iOS install/load/ask proof for Gemma-family route.
4. **Only after Gate 3:** run one mobile matrix for 2025–2026 compact candidates and promote with fallback/latency/thermal/timeout evidence.
