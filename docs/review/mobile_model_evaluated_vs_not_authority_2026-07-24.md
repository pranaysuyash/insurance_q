# Mobile model evaluation truth matrix — authoritative 2026-07-24

This is the one-file, execution-focused map for CoverWise mobile policy workflow.

## Source-of-truth rule

- **EVAL**: reproducible run output in this repo for that exact stage/runtime.
- **SCaffold**: integration exists, no Android/iOS execution.
- **Catalog-only**: present in strategy/capability documentation, no repo execution for that stage/runtime.
- **Hosted-only**: cloud API lane (not Android/iOS offline/local).

## 1) Android/iOS-ready model/runtime options (covered by this pass)

| Candidate / lane | Stage | Mobile runtime type | Repo status (2026-07-24) | Evidence |
|---|---|---|---|---|
| `flutter_gemma` + MediaPipe seam (`ON_DEVICE_INFERENCE_ENABLED`, `ON_DEVICE_MODEL_URL`) | Local/offline generation assist | Native Flutter mobile bridge (Android/iOS) | **SCaffold** | [on_device_inference_service.dart](file:///Users/pranay/Projects/medpiper/insurance_app/mobile/lib/services/on_device_inference_service.dart), [app_config.dart](file:///Users/pranay/Projects/medpiper/insurance_app/mobile/lib/config/app_config.dart), `flutter test test/on_device_inference_service_test.dart` |
| `Gemma 3n` E2B/E4B `.task` path | Local/offline generation | Native Flutter mobile bridge (planned) | **Catalog-only** | [mobile_model_decision_sheet_2026-07-24.md](mobile_model_decision_sheet_2026-07-24.md) |
| Gemma 3 270M / 1B | Local/offline generation/lookup-classification | Native Flutter mobile bridge (planned) | **Catalog-only** | [mobile_model_decision_sheet_2026-07-24.md](mobile_model_decision_sheet_2026-07-24.md) |
| Qwen3 0.6B / 1.7B / 4B | Local/offline generation | Native Flutter mobile bridge (planned) | **Catalog-only** | [mobile_model_decision_sheet_2026-07-24.md](mobile_model_decision_sheet_2026-07-24.md) |
| Phi-4-mini / SmolLM3 / Ministral 3B | Local/offline generation | Native Flutter mobile bridge (planned) | **Catalog-only** | [mobile_model_decision_sheet_2026-07-24.md](mobile_model_decision_sheet_2026-07-24.md) |
| Qwen3-VL 2B / 4B | Visual recovery (second-stage) | Native Flutter mobile bridge (planned) | **Catalog-only** | [mobile_model_general_vlm_frontier_2026-07-24.md](mobile_model_general_vlm_frontier_2026-07-24.md) |
| Gemini Nano / AICore | Managed Android native | Android platform managed | **Catalog-only for this repo** | No in-app capability probe logged in this pass |
| Apple Foundation Models | Managed iOS native | iOS platform managed | **Catalog-only for this repo** | No in-app capability probe logged in this pass |
| Transformers.js (WebGPU/ONNX) | Web/mobile-web path only | Flutter-web bridge only | **Not in Flutter-native mobile model route** | No mobile-native execution in this repo |
| EmbeddingGemma / Qwen3-Embedding (embedding lane) | Local embedding | Native Flutter bridge (planned) | **Catalog-only** | [mobile_model_strict_matrix_2026-07-24.md](mobile_model_strict_matrix_2026-07-24.md) |

## 2) Hosted lanes (paid/API, not mobile-offline)

| Provider lane | Stage | Repo status | Why it is not mobile-ready | Evidence |
|---|---|---|---|---|
| OpenAI `gpt-5-nano` | Hosted generation | **EVAL** | Cloud API fallback, not on-device | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`, `.../openai-synthetic-2026-07-24-final.json`, `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` |
| OpenRouter (`google/gemini-2.5-flash-lite`) | Hosted generation comparator | **EVAL (limited)** | Cloud API comparator only | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json` |
| OpenRouter (`google/gemma-3-4b-it`) | Hosted generation comparator | **EVAL (limited)** | Cloud API comparator only | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` |
| HF Inference `Qwen/Qwen3-4B-Instruct-2507` (HF Pro) | Hosted generation comparator | **EVAL (limited)** | Cloud-hosted inference; HF credits only enable API, not on-device | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json` |
| Modal Labs (`MODAL_TOKEN_*`) | Private hosted benchmark/GPU lane | **Context only** in this repo | No CoverWise mobile endpoint/runtime contract in repo | key-surface inventory in [mobile_model_full_truth_register_2026-07-24.md](mobile_model_full_truth_register_2026-07-24.md) |
| OpenRouter/OpenAI/Groq etc. in other projects | Hosted comparator lanes only | **Not part of CoverWise mobile routing today** | Key presence in env files is not runtime routing | cross-project key sweep in docs |

## 3) Desktop/local non-mobile lanes

| Candidate / lane | Stage | Repo status | Why not mobile-executed |
|---|---|---|---|
| Ollama `gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b` | OCR/generation local dev | **EVAL (desktop)** | Desktop host/runtime only; users do not install Ollama on Android/iOS |
| DeepSeek OCR adapter | OCR adapter check | **EVAL (nonproductive desktop signal)** | Not a mobile app runtime artifact |
| Surya-2/docTR | OCR/layout path | **EVAL (limited desktop/server)** | Not native mobile app benchmark |

## 4) Pipeline-stage truth (for CoverWise policy RAG)

| Stage | What is proven in-repo | Android/iOS execution status |
|---|---|---|
| Parse / OCR / layout (canonical path) | Surya-2/docTR and PyMuPDF chain evidence exists for policy pipeline | **No native mobile benchmark yet** |
| Chunking / reconstruction | Implemented and used in policy corpus run | Mobile-only tuning not run |
| Retrieval / rerank | Server hybrid stage evaluated in policy corpus run | No mobile-device stress/timeout/eviction tests |
| Hosted generation | OpenAI/OpenRouter/HF smoke + policy metrics present | No mobile/offline execution |
| Local/offline generation | Flutter seam + tests present | **No Android/iOS run yet** |
| Managed native generation | Gemini Nano / Foundation Models | No in-app probe or fallback contract run |

## 5) 2025–2026 frontier entries from `document_parsers_extractors_catalog_2026_v2.xlsx`

Current status for this entire frontier set in this repo: **Catalog-only / not executed on Android/iOS**.

Examples (not exhaustive):
- 2026: Infinity-Parser2, HunyuanOCR-1.5, RT-DocLayout, Unlimited-OCR, PaddleOCR-VL-1.6/1.5, ABot-OCR, MinerU-Popo/2.5-Pro/Diffusion, AgenticOCR, Logics-Parsing(-Omni), Qianfan-OCR, dots.mocr / dots.ocr, Dolphin variants, GLM-OCR, DeepSeek-OCR, Marker, Docling-adjacent methods, MeDocVL.
- 2025: Uni-Parser, `Doc-Researcher`, UniRec, HunyuanOCR, Chandra, Dolphin, Logics-Parsing, Marker, MinerU, SmolDocling, PP-StructureV3, PP-OCRv* and other parser/OCR families.

See full list: [mobile_model_catalog_2025_2026_2026-07-24.md](mobile_model_catalog_2025_2026_2026-07-24.md).

## 6) Fine-tune / adapter reality

- No production-ready LoRA/QLoRA/merged adapter checkpoint is wired into mobile CoverWise today.
- Any model-specific adapter path requires: dataset lineage, tokenizer, quantization, export hash, runtime format, and telemetry contract before it is candidate-ready.

## 7) Direct answers to your shortlist request

- **Keep hosted baseline:** `OpenAI gpt-5-nano` (strongest evidence for policy grounding in this repo).
- **Primary next mobile candidate:** Gemma-3n candidate through existing `flutter_gemma` seam (after model artifact + capability contract + device matrix).
- **Secondary comparator candidates (post-gate):** Gemma 3n E2B/E4B vs Gemma 3 1B vs Qwen3 1.7B/4B, then Phi-4-mini, SmolLM3, Ministral 3B.
- **Do not promote today:** Gemma 3n/3, Qwen3-VL, managed platform models, Transformers.js web path as primary production route.

## 8) Evidence gate for any mobile promotion

For any future "promoted" mobile model claim in CoverWise, we require:
1. Real Android/iOS device runs with manifested artifact hash.
2. Latency + warm/cold timing + memory + thermal telemetry.
3. Timeout/cancel/retry/eviction behavior.
4. Schema-valid/grounded output rate with rejection behavior.
5. Unsupported-device fallback proving non-target platforms do not silently fail.

Current run reality snapshot:
- `cd mobile && flutter devices` (this run): attached simulator detected: `iPhone 17` (iOS simulator), `macOS`, `Chrome`.
- `cd mobile && flutter test test/on_device_inference_service_test.dart` now passes; targeted runs on iPhone simulator and Android emulator also pass their guard-path tests (`2/2`), confirming:
  - `ON_DEVICE_*` disabled-by-default behavior,
  - installation refusal path when model URL/config is absent.
- Therefore: still **no `.task` install/load/ask generation evidence** was added because no mobile-ready model artifact exists in-repo and no install URL/asset path was provided in this pass.
