# Mobile model evaluation truth map (2026-07-25, CoverWise policy-RAG)

This replaces “we looked at things” ambiguity with a single staged truth table.

## Evidence classes

- **EVAL** = reproducible repository evidence exists for that lane (actual run output in `docs/review/evidence/**` or device tests in `docs/review/evidence/local-model-eval/**`).
- **SCaffold** = code integration + guards/contract tests exist, but no successful Android/iOS inference execution has been observed.
- **Catalog-only** = tracked in catalogs/research notes but not run in this repo.
- **Hosted-only** = cloud API/paid provider lane; not device-local execution.

## 1) Environment/prod provider key surfaces (presence only, values omitted)

### CoverWise app (repo root)

- `OPENAI_API_KEY`, `OPENAI_EMBEDDING_MODEL`, `OPENAI_CHAT_MODEL` (active in `.env`)
- `OLLAMA_BASE_URL`, `GROQ_API_KEY` (present, not the default active mobile lane in this codepath)
- `HF_TOKEN` exists only in commented/example form in active `.env`/`.env.example`
- `ON_DEVICE_INFERENCE_ENABLED` / `ON_DEVICE_MODEL_URL` are not actively set to a mobile artifact URL

### Other project surfaces relevant to this decision

- OrbitCover: `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`, `OPENROUTER_TIER`
- Comfy: `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE`
- speech_experiments/model-lab: `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`
- invoice-intelligence: `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`
- travel/utility projects contain additional hosted provider keys for side experiments (Gemini/Groq/Antropic/etc.) but are not wired into CoverWise mobile local inference.

Presence does not imply execution proof. It only means provider route possibilities exist.

## 2) RAG pipeline stage truth map (CoverWise today)

| Stage | What is in repo | Evidence status | Why this status |
|---|---|---|---|
| Ingestion / parse | PyMuPDF baseline, OCR fallback routing exists in pipeline | **EVAL** (server-level behavior + corpus fixtures) | Existing parser path and extraction fixtures are exercised via RAG corpus and QA flows. |
| Parser frontier alternatives (2024–2026) | `Docling`, `Marker`, `MinerU`, `Surya`, etc. in catalog/tracking docs | **Catalog-only** | Tracked and shortlisted, not integrated as active on-device branches with measured runs. |
| Layout/structure recovery frontier (Baidu/LP etc.) | `Unlimited-OCR`, `RT-DocLayout`, `PaddleOCR-VL-1.6`, `Dolphin` family, `GLM-OCR`, `DODO`, etc. in catalog | **Catalog-only** | Stage-level candidates only; no on-device benchmark traces. |
| Chunking/reconstruction | Current hybrid route + entity/paragraph table-aware chunking experiments | **EVAL** (server fixture config and policy QA flow) | Document-level chunking and reconstruction behavior has been exercised in the policy flow and synthetic/corpus runs. |
| Embedding | `text-embedding-3-small` hosted | **EVAL** | Hosted embedding currently benchmarked as part of policy/RAG path. |
| Retrieval / rerank | Dense + rerank stack active | **EVAL (policy + held-out)** | Retrieval + rerank contributes to policy answers that are validated in held-out corpus. |
| Hosted generation | `gpt-5-nano` + OpenRouter comparators + HF endpoint smoke | **EVAL** | OpenAI/OpenRouter/HF synthetic + policy corpus runs exist. |
| On-device local generation | `flutter_gemma` / `flutter_gemma_mediapipe` + `.task` seam | **SCaffold** | Integrations, gates, and tests exist; no real `.task` install/load/ask production-like run. |
| Managed-device native | Gemini Nano/AICore, Apple Foundation Models | **Catalog-only** | No capability probe matrix in repo yet. |
| On-device/edge fallback path | policy `ask` fallback wiring exists | **SCaffold** | No confirmed Android/iOS telemetry or model artifact behavior yet. |

## 3) Stage-wise model list (evaluated vs not) by model class

### A) Android/iOS-local candidates (requires on-device runtime)

| Model family | Intended lane | Status | Missing proof |
|---|---|---|---|
| `flutter_gemma` + MediaPipe (`.task`) | Shared runtime seam for both Android/iOS | **SCaffold** | Signed `.task` artifact, install/load/ask traces, device matrix |
| Gemma 3n E2B / E4B `.task` | First native mobile lane candidate | **Catalog-only** | Export artifact + on-device benchmark |
| Gemma 3 270M / 1B `.task` | Fallback compact mobile lane | **Catalog-only** | Export + mobile test + latency/quality thresholding |
| Qwen3 0.6B / 1.7B / 4B | Retrieval and generation alternatives | **Catalog-only** | Mobile conversion/manifest + on-device validation |
| Phi-4-mini / SmolLM3 / Ministral 3B | Lightweight alternatives | **Catalog-only** | Export + pipeline binding + on-device benchmarks |
| Qwen3-VL / PaddleOCR-VL / MiniCPM-V | Visual recovery branch candidates | **Catalog-only** | Vision-stage branching + device tracing + refusal handling |

### B) Hosted/paid lanes (comparison or pipeline support lanes)

| Lane | Provider/model | Status | Why not mobile-offline |
|---|---|---|---|
| OpenAI cloud | `gpt-5-nano` (2025-08-07 evidence) | **EVAL** | Cloud API; no `.task` artifact execution |
| OpenRouter | `gemini-2.5-flash-lite`, `google/gemma-3-4b-it` | **EVAL (comparison)** | Cloud-only |
| Hugging Face Inference / HF Pro | `Qwen/Qwen3-4B-Instruct-2507` | **EVAL (comparison)** | Credit-backed endpoint, not Android/iOS runtime |
| Modal Labs | token-based GPU/private endpoint | **Catalog/optional context** | No CoverWise mobile in-repo on-device lane |

### C) Transformers.js / WebGPU

- `transformers.js`, WebGPU, ONNX-Web: **Catalog-only / web-specific** in this product framing; this repo’s native Flutter runtime is not built on this lane yet.

### D) Fine-tune / adapter status

- No production LoRA/QLoRA/merged adapter path is currently routed in CoverWise mobile.
- No adapter hash/versioned manifest + runtime format mapping exists (`.task/.gguf/.onnx/.tflite`) for phone routing.

## 4) Model candidates explicitly from catalog (2025–2026 frontier mention list)

From `/Users/pranay/Downloads/researches_lists/document_parsers_extractors_catalog_2026_v2.xlsx` (Master + Recent Models + General OCR VLMs), frontier entries relevant to this project were tagged as **Catalog-only** unless explicitly executed on-device:

- `Unlimited-OCR`, `RT-DocLayout`, `PaddleOCR-VL-1.6`, `PP-OCRv6`, `Qianfan-OCR`, `dots.mocr`, `FireRed-OCR`, `Dolphin-2.0`, `GLM-OCR`, `DeepSeek-OCR 2`, `MeDocVL`, `Marker 1.10.1`, `MinerU2.5`, `SmolDocling-256M`, `Granite-Docling-258M`, `AgenticOCR`, `Dolphin/AgenticOCR class`, `BabelDOC`, `BabelDOC-like parser pipelines`, etc.
- Additional broad OCR/vision candidates also logged: `KDL Frontier`, `GPT-5 family`, `Qwen3-VL/Omni`, `Ovis2.5`, `MiniCPM-V`, `LLaVA-OneVision`, etc. These are useful as structured fallback studies, not parsed as deterministic document parsers yet.

## 5) Why no Ollama/MLX/other desktop runtimes for Android/iOS users

- Android/iOS users do not install Ollama/MLX to run app inference; these are desktop/edge developer runtimes or macOS-focused local stacks.
- Phone inference in production requires mobile-native runtimes (MediaPipe/Task API path here), AppStore-managed runtimes, or device APIs (Gemini Nano/AICore / Foundation Models).
- For this repo, only the `flutter_gemma` seam maps to the mobile-native direction.

## 6) Actual measured status (today)

- `flutter test test/on_device_inference_service_test.dart` passes `3/3` (guard + attempt path in service layer).
- `flutter devices --machine` showed `iPhone 17` simulator, macOS, Chrome; no Android target in the tested run where evidence was collected.
- Real iOS/Android `.task` install/load/ask telemetry and memory/latency/cancel/retry behavior is still pending.

## 7) Concrete next moves (ordered)

1. Add a signed/shared `.task` artifact for one mobile candidate (Gemma 3n family first).
2. Run Android + iOS install/install-check + ask flow with telemetry (cold/warm latency, RSS/memory, timeout, cancel).
3. Promote first model to **EVAL** only after pass-rate + rejection/unsupported-device behavior is recorded.
4. Expand only to second local candidate (`Gemma 3 270M/1B` or `Qwen3 1.7B`) under same manifest.
5. Add managed-device probes separately (`Gemini Nano/AICore`, Apple Foundation Models) with explicit unsupported-device matrix.

## 8) Source anchors

- `mobile/lib/services/on_device_inference_service.dart`
- `mobile/lib/config/app_config.dart`
- `mobile/lib/screens/qa_screen.dart`
- `mobile/test/on_device_inference_service_test.dart`
- `docs/review/mobile_model_full_evaluation_compendium_2026-07-25.md`
- `docs/review/mobile_model_runtime_execution_inventory_2026-07-25.md`
- `docs/review/mobile_model_frontier_2024_plus_inventory_2026-07-25.md`
- `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-25.json`
- `docs/review/evidence/provider-smoke/*.json`
- `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json`
