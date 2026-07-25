# Mobile model execution ledger (CoverWise, 2026-07-25)

Date: 2026-07-25  
Scope: Android/iOS local/offline posture, hosted comparison lanes, and 2025–2026 parser/visual frontier candidates from `document_parsers_extractors_catalog_2026_v2.xlsx`.

Evidence source rule:

- **EVAL** = reproducible run output exists in this repo for the exact lane.
- **SCaffold** = integration code exists, no Android/iOS device install/load/ask in this repo.
- **Catalog-only** = research only (not executed in this repo).
- **Hosted-only** = cloud API lane only.

## 1) Direct answer to “what did we evaluate”

### 1A) Policy-RAG pipeline stages (CoverWise)

| Stage | What was run | Route status | Evidence |
|---|---|---|---|
| Parse / text extraction | PyMuPDF + canonical ingestion path | EVAL | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` |
| OCR/layout frontier checks | Surya2/docTR-family server checks | EVAL (limited) | `docs/review/evidence/local-model-eval/gemma3-4b-recheck-2026-07-12.json`, `deepseek-ocr-diagnostic-2026-07-12.json` |
| Chunking / retrieval / rerank | Existing policy corpus config | EVAL | `docs/technical/rag/exploration/chunking_parsing_embedding_exploration_2026-07-22.md` |
| Hosted generation (cloud) | OpenAI/OpenRouter/HF smoke + policy holdout | EVAL | `docs/review/evidence/provider-smoke/*`, `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` |
| On-device mobile bridge | `flutter_gemma` + MediaPipe seam | Scaffold | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`, `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-25.json` |
| Device execution for `.task` models | Android/iOS install/load/ask | Not yet executed | No manifest artifact + no device `install/load/ask` trace |

### 1B) Exact hosted lane metrics (last observed)

| Provider lane | Requested model | Run | Pass | Median latency |
|---|---|---|---:|---:|
| OpenAI | `gpt-5-nano` | `openai-synthetic-2026-07-24-success.json` | `3/3` | `1237ms` |
| OpenAI | `gpt-5-nano` | `continuation-smoke-2026-07-25.json` | `3/3` | `1619ms` |
| OpenAI | `gpt-5-nano` | `realitycheck-openai-2026-07-26.json` | `3/3` | `1169ms` |
| OpenRouter | `google/gemini-2.5-flash-lite` | `openrouter-synthetic-2026-07-24.json` | `2/3` | `746ms` |
| OpenRouter | `google/gemini-2.5-flash-lite` | `continuation-openrouter-2026-07-25.json` | `2/3` | `1025ms` |
| OpenRouter | `google/gemini-2.5-flash-lite` | `realitycheck-openrouter-2026-07-26.json` | `2/3` | `829ms` |
| OpenRouter | `google/gemma-3-4b-it` | `openrouter-gemma3-4b-synthetic-2026-07-24.json` | `1/3` | `582ms` |
| HF Pro / HF Inference | `Qwen/Qwen3-4B-Instruct-2507` | `hf-qwen3-synthetic-2026-07-24.json` | `2/3` | `1173ms` |
| HF Pro / HF Inference | `Qwen/Qwen3-4B-Instruct-2507` | `continuation-hf-2026-07-25.json` | `2/3` | `1026ms` |
| HF Pro / HF Inference | `Qwen/Qwen3-4B-Instruct-2507` | `realitycheck-hf-2026-07-26.json` | `2/3` | `955ms` |

### 1C) Policy-accuracy snapshot (server pipeline)

- `policy-corpus-ragas-2026-07-24.json`:  
  - `total_questions`: `52`  
  - `accuracy`: `0.5577` (29/52)  
  - `citation_rate`: `0.9615`  
  - `hallucination_rate`: `0.3333`  
  - `ragas_metrics`: `faithfulness=0.8368`, `context_precision=0.4558`, `answer_relevancy=0.7148`

## 2) Android/iOS option matrix (what’s today: candidate vs executed)

### 2A) Mobile-native execution candidates

| Lane | Android | iOS | Stage | Status | Why |
|---|---:|---:|---|---|---|
| `flutter_gemma` + `ON_DEVICE_*` + `.task` | ✅ | ✅ | shared generation assist | Scaffold | Service/seam exists; no real model artifact run yet |
| Gemma 3n E2B/E4B | candidate | candidate | generation/local fallback | Catalog-only | No signed `.task` artifact or install/run telemetry |
| Gemma 3 270M / 1B | candidate | candidate | classification/local compact generation | Catalog-only | No export and no mobile evidence |
| Qwen3 0.6B / 1.7B / 4B | candidate | candidate | compact compare | Catalog-only | No export and no mobile evidence |
| Phi-4-mini / SmolLM3 / Ministral 3B | candidate | candidate | compact compare | Catalog-only | No export and no mobile evidence |
| Qwen3-VL / PaddleOCR-VL / Dolphin / etc. | candidate | candidate | visual recovery stage | Catalog-only | No mobile recovery pipeline implementation/evidence |
| Android managed | platform-managed | — | managed generation | Catalog-only | No managed runtime probe in CoverWise |
| Apple Foundation Models | — | iOS managed | managed generation | Catalog-only | No managed runtime probe in CoverWise |

### 2B) Desktop/local/offsite “local” runtime lanes (not Android/iOS model runtime)

| Lane | Status | Why |
|---|---:|---|
| Ollama (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`) | EVAL (desktop) | desktop/local model check only |
| DeepSeek OCR adapter checks | EVAL (desktop) | desktop artifact compatibility signal only |
| MLX (where present in other surfaces) | Context-only | not integrated with Android/iOS app packaging |

## 3) Why Android/iOS users do not install Ollama/MLX/Transformers.js for this product lane

- **Ollama/MLX:** workstation/runtime tools, not user-facing Android/iOS product runtimes for CoverWise.
- **Transformers.js:** browser/WebGPU/ONNX path only; not the Flutter-native mobile runtime used by CoverWise.
- **HF Pro / OpenAI / OpenRouter / Modal keys:** hosted inference or infra lanes. They are valid comparison/fallback lanes, but not on-device/offline execution inside the app without `.task`-class mobile assets and Flutter device tests.

## 4) Model-lane key/capability surfaces (relevant projects, names only)

Values intentionally omitted.

| Project | Key surface | Interpretation |
|---|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OLLAMA_BASE_URL`, `GROQ_API_KEY` (example), `ON_DEVICE_*` runtime flags in code only | Cloud baseline + local Flutter bridge controls; no shipped local model hash |
| `orbitcover-d2c` | `OPENROUTER_API_KEY` | openrouter comparison surface (not CoverWise mobile route) |
| `comfy` | `HF_TOKEN`, `HF_HOME`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` | HF/Modal benchmark lane |
| `speech_experiments/model-lab` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` | model-workbench lane |
| `edureka`, `bas5minute`, `learning_for_kids`, `EchoPanel`, `SentinelTwin`, `notes` | mixed OpenAI/Gemini/GHF/Groq keys | adjacent research/hosting surfaces |

No value is read or propagated here; this is a routing/architecture inventory only.

## 5) 2025–2026 frontier status (from catalog) — **all are Catalog-only in this decision pass**

### 2026 (selected from `document_parsers_extractors_catalog_2026_v2.xlsx`)

- `Infinity-Parser2`, `HunyuanOCR-1.5`, `RT-DocLayout`, `Unlimited-OCR`, `PaddleOCR-VL-1.6`, `PP-OCRv6`, `MinerU-Popo`, `RTPrune`, `ABot-OCR`, `MinerU2.5-Pro`, `MeDocVL`, `Qianfan-OCR`, `dots.mocr`, `FireRed-OCR`, `AgenticOCR`, `Logics-Parsing-Omni`, `PaddleOCR-VL (coarse-to-fine)`, `Dodo`, `Dolphin-2.0`, `GLM-OCR`, `DeepSeek-OCR 2`, `PaddleOCR-VL-1.5`, `OCRVerse`, `GutenOCR`, `LightOnOCR`, and adjacent agents/optimizers (SAYRE, P-MTP, Beaver, Agents-K1, etc.).

### 2025 (selected from `document_parsers_extractors_catalog_2026_v2.xlsx`)

- `Uni-Parser`, `HunyuanOCR`, `MonkeyOCR`/`v1.5`/`Pro`, `Marker 1.10.1`, `MinerU 2.5`, `MinerU2.0-2505-0.9B`, `PaddleOCR-VL`, `Dolphin`/`Dolphin-1.5`/`Dolphin-2.0`, `DianJin-OCR-R1`, `SmolDocling-256M`, `PP-StructureV3`, `Ocean-OCR`, and related adjacent methods (`TRivia`, `DOCR-Inspector`, `Doc-Researcher`, `Chandra`, etc.).

For the full machine-generated 2025–2026 model list by artifact class, see `docs/review/evidence/local-model-eval/recent_models_2024_plus_inventory_2026-07-25.json` and `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md`.

## 6) Actual mobile-only execution status to date

- `flutter devices` found iPhone 17 simulator (`iOS 26.2`) , macOS, Chrome.
- On-device control harness passes:
  - `flutter test test/on_device_inference_service_test.dart`
  - pass summary `3/3` (contract guard + install-attempt reachability path only)
- Latest captured control artifact: `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26.json` (`3/3`, no `.task` install/load/ask execution).
- No successful Android/iOS `.task` model install/load/ask evidence exists yet in this repo.
- No real Android and no real iPhone iOS on-device benchmark run exists for any model.

## 7) Shortlist to run next (with reasons)

1. **Now**: get a signed `.task` artifact for first shared local lane (`Gemma 3n E2B` preferred), run install → load → ask on Android + iOS, and collect latency/memory/thermal/cancel/retry/fallback telemetry.
2. **Then**: run one comparator (`Gemma 3 1B` or `Qwen3 1.7B`) under the same manifest.
3. **Then**: if parser coverage is still weak, test second-stage visual recovery candidates (`Qwen3-VL`, `PaddleOCR-VL`, etc.) only on the failure set.
4. **Hold**: managed OS-native lanes (`Gemini Nano`, Apple Foundation Models), large VLMs, and Transformer.js web path until native-device capability and refusal behavior are measured.

Rationale:

- This keeps the first production-safe mobile decision to one measurable baseline.
- It prevents unsupported promises from remaining in the shortlist as “done.”
- It keeps the model catalog useful as **planned candidates** while preserving truth about what has actually been executed.
