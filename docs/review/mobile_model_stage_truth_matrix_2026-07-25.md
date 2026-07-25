# Mobile model execution truth matrix — CoverWise (2026-07-25, policy-RAG lane)

This is a single-file, evidence-based map for your requested questions:

- Android/iOS local options vs hosted options
- transformers.js path vs Flutter-native path
- Hugging Face Pro / OpenRouter / Modal lanes
- Fine-tune / adapter readiness
- Stage-aware status for policy parsing, chunking, retrieval, and generation
- exact evaluated-vs-not for this repo

## Evaluation status legend

- **EVAL**: reproducible run output exists for the exact runtime stage in this repo.
- **SCaffold**: integration code exists, no Android/iOS on-device install/load/ask run.
- **Catalog-only**: discovered/shortlisted only; no runnable mobile evidence.
- **Context-only**: key/token or infra exists, no app-level mobile proof.

## Explicit model shortlist (requested: explored / selected / not yet run, with reasons)

| Lane | Runtime target | Eval status | Evidence in repo | Why it sits there today |
|---|---|---|---|---|
| OpenAI `gpt-5-nano` (`gpt-5-nano-2025-08-07`) | hosted cloud | **EVAL** | `openai-synthetic-2026-07-24-success.json`, `continuation-smoke-2026-07-25.json`, `policy-corpus-ragas-2026-07-24.json` | Policy-grounded baseline in production path; not offline/on-device |
| OpenRouter `google/gemini-2.5-flash-lite` | hosted cloud | **EVAL (limited)** | `openrouter-synthetic-2026-07-24.json`, `continuation-openrouter-2026-07-25.json` | Hosted compare lane only; no mobile artifact |
| OpenRouter `google/gemma-3-4b-it` | hosted cloud | **EVAL (limited)** | `openrouter-gemma3-4b-synthetic-2026-07-24.json` | Hosted compare lane only |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | hosted cloud | **EVAL (limited)** | `hf-qwen3-synthetic-2026-07-24.json`, `continuation-hf-2026-07-25.json` | Hosted compare lane only; no device artifact |
| Ollama (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`, `deepseek-ocr`) | workstation/server local | **EVAL (desktop-only)** | `docs/review/evidence/local-model-eval/*.json` | Desktop/runtime only, not user phone |
| `flutter_gemma` + MediaPipe seam | Android/iOS offline scaffold | **SCaffold** | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`, `mobile/test/on_device_inference_service_test.dart` | Config-gated contract + tests only; no `.task` install/load/ask on device run |
| Gemma 3n E2B / E4B (`.task`) | Android/iOS candidate shared route | **Catalog-only** | No `.task` artifact + no install/load/ask logs | Not available until approved `.task` + on-device run is added |
| Gemma 3 270M / 1B | Android/iOS candidate shared route | **Catalog-only** | no exported model artifact in repo | Needs export + install/load/ask proof |
| Qwen3 0.6B / 1.7B / 4B | Android/iOS candidate shared route | **Catalog-only** | no exported model artifact in repo | Needs export + install/load/ask proof |
| Phi-4-mini / SmolLM3 / Ministral 3B | Android/iOS candidate shared route | **Catalog-only** | no exported model artifact in repo | Need export + run matrix |
| Qwen3-VL 2B / 4B | Android/iOS visual-recovery candidate | **Catalog-only** | frontier list + no mobile execution | Need dedicated VLM visual stage and mobile evidence |
| Unlimited-OCR / RT-DocLayout / Marker / MinerU / PaddleOCR-VL / Dolphin / Qianfan / Dots / FireRed / etc. | parsing/layout candidate | **Catalog-only** | `mobile_model_frontier_2024_plus_inventory_2026-07-25.md` | No on-device integration or run for these in this pass |
| Transformers.js (WebGPU/ONNX) | web/mobile-web bridge | **Not in Flutter-native lane** | referenced docs links only | No Flutter-native Android/iOS runtime plumbing in app |
| Android managed runtime (Gemini Nano / AICore) | Android platform managed | **Not integrated/run** | no in-app probe evidence in this repo | Requires hardware probe + OS support matrix |
| Apple Foundation Models | iOS platform managed | **Not integrated/run** | no in-app probe evidence in this repo | Requires in-app capability matrix for supported/unsupported OS builds |
| Modal (private GPU infra) | benchmark/cloud | **Context-only** | `comfy` env scan + no mobile app routing evidence | Useful for benchmarking/fine-tune exploration only, not mobile runtime |

## Direct shortlist and reason ledger (requested format)

### A) Models **actually evidenced** in this repo (with reliable output)

| Model / lane | Provider | Runtime target | Eval source | Result | Decision for production today |
|---|---|---|---|---|---|
| OpenAI `gpt-5-nano` (`gpt-5-nano-2025-08-07`) | OpenAI API | Hosted | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`, `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json`, `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | `3/3` synthetic; held-out `52Q`: `accuracy=0.5577`, `citation_rate=0.9615`, `hallucination_rate=0.3333` | Keep as production-grounded fallback baseline |
| OpenRouter `google/gemini-2.5-flash-lite` | OpenRouter | Hosted | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json`, `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json` | `2/3` synthetic (latency trend stable) | Comparison lane only, not mobile default |
| OpenRouter `google/gemma-3-4b-it` | OpenRouter | Hosted | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | `1/3` synthetic | Comparison lane only |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | HF Inference | Hosted | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json`, `docs/review/evidence/provider-smoke/continuation-hf-2026-07-25.json` | `2/3` synthetic | Hosted comparison only |
| `flutter_gemma` seam | Flutter Gemma + MediaPipe | Android/iOS scaffold | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`, `mobile/test/on_device_inference_service_test.dart` | No install/load/ask run yet | Gate + artifacts missing; run now |

### B) Models explicitly in shortlist, currently **no mobile off-device proof yet**

| Model / family | Intended mobile role | Why shortlisted now | Blocking issue |
|---|---|---|---|
| Gemma 3n E2B / E4B (`.task`) | First mobile-native shared lane | Best native compatibility path with existing seam | No approved `.task` artifact, no Android/iOS install/load/ask run |
| Gemma 3 270M / 1B | Compact local classification/lookup and policy fallback | Needed before larger on-device comparators | No export + no phone run |
| Qwen3 0.6B / 1.7B / 4B | Compact and medium mobile comparator set | Portable alternatives if Gemma fails latency/quality gate | No exported mobile artifact + no run |
| Phi-4-mini / SmolLM3 / Ministral 3B | Additional compact compare candidates | Useful if memory/latency envelope requires alternatives | No exported artifact + no run |
| Qwen3-VL 2B / 4B | OCR/layout recovery stage | Second-stage visual recovery only | No on-device visual-stage implementation yet |
| Gemini Nano / AICore | Managed Android native path | Hardware-native alternative if available | No in-app probe/unsupported-device matrix |
| Apple Foundation Models | Managed iOS native path | Hardware-native alternative if available | No in-app probe/OS-version matrix |

### C) What is **not** mobile in this repo (despite presence as lanes)

- Ollama (`gpt models` under `docs/review/evidence/local-model-eval/*`) = desktop/server only.
- Transformers.js = web/mobile-web experiment path; not Flutter-native Android/iOS inference route.
- Modal/HF/OpenRouter/OpenAI paid lanes = cloud/hosted infrastructure; no local phone execution guarantees.

### D) Cross-project provider key surfaces (routing vs proof)

| Surface | Key types present | Routing to CoverWise mobile on-device? | Meaning |
|---|---|---|---|
| `medpiper/insurance_app/.env` | `OPENAI_*`, `OLLAMA_BASE_URL` (HF key commented), `GROQ_API_KEY` commented examples | `NO` | Backed cloud route + local-server options; does not activate mobile model runtime by itself |
| `orbitcover-d2c/.env` | `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` | `NO` | OpenRouter experiment surface; not wired to CoverWise mobile path |
| `comfy/.env` | `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` | `NO` | Private GPU/HF benchmark surface; separate from CoverWise mobile pipeline |

### E) Exact next-step recommendation to move from “shortlist” to “evidence-backed decision”

1. Get a signed `.task` artifact and run real device install/load/ask with manifest (`android` + `ios`) on `flutter_gemma` seam.
2. On the same run, capture latency, memory/RSS, thermal, failure class, cancellation/timeout behavior.
3. Only after this passes, execute compact comparator lanes (`Gemma 3 270M/1B` or `Qwen3 1.7B`) and managed-native probes.

## 1) Evidence-backed status by pipeline stage

### 1.1 Ingestion / parser / layout / OCR stage

| Stage | Candidate / lane | Runtime target | Status | Evidence | Why |
|---|---|---|---|---|---|
| Text parsing | PyMuPDF canonical path + layout utils | Server pipeline | **EVAL** | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | Canonical corpus path used in policy-run; not mobile-native. |
| OCR baseline | Pytesseract / docTR / Surya-2 (server fixture checks) | Server/local | **EVAL** | `docs/review/evidence/local-model-eval/gemma3-4b-recheck-2026-07-12.json` | Limited desktop/local checks; not Android/iOS device evidence. |
| Android/iOS managed OCR | ML Kit / core mobile OCR paths | Device native | **Not evaluated in this lane** | none | OCR capability exists in codebase context, but no dedicated model evidence for this model decision pass. |
| Parser frontier candidates | Docling, Marker, MinerU, RT-DocLayout, Unlimited-OCR, PaddleOCR-VL, MeDocVL, DeepSeek-OCR, etc. | Mobile candidate discovery | **Catalog-only** | `docs/review/mobile_model_frontier_2024_plus_inventory_2026-07-25.md`, `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md` | 2026 frontier entries are listed, but not device-run. |

### 1.2 Chunking / retrieval / rerank stage

| Stage | Candidate / lane | Runtime target | Status | Evidence | Why |
|---|---|---|---|---|---|
| Chunking strategy | paragraph / entity / reconstruction pipeline | Server pipeline | **EVAL** | `docs/technical/rag/exploration/chunking_parsing_embedding_exploration_2026-07-22.md` | In use for policy workflow. |
| Embeddings | `text-embedding-3-small` | Hosted | **EVAL** | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | Hosted pipeline only. |
| Mobile embedding candidates | EmbeddingGemma / Qwen3-Embedding family | Mobile/local | **Catalog-only** | `docs/review/mobile_model_strict_matrix_2026-07-24.md` | No Android/iOS export + benchmark yet. |
| Rerank / retrieval hybrids | Dense + lexical + (existing reranker config) | Server | **EVAL (in use)** | policy pipeline evidence, retrieval/grounding checks | Not yet mobile-executed. |

### 1.3 Generation stage

| Candidate / lane | Runtime class | Android | iOS | Status | Evidence | Why |
|---|---|---:|---:|---|---|---|
| OpenAI `gpt-5-nano` | Hosted API | N/A | N/A | **EVAL** | `openai-synthetic-2026-07-24-success.json`, `continuation-smoke-2026-07-25.json`, `policy-corpus-ragas-2026-07-24.json` | Baseline production-quality path in repo; `3/3` synthetic in both pass batches, held-out 52Q policy baseline exists (`accuracy=0.5577`, `citation_rate=0.9615`). |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted API | N/A | N/A | **EVAL (comparison-only)** | `openrouter-synthetic-2026-07-24.json`, `continuation-openrouter-2026-07-25.json` | `2/3` synthetic in this repo (`continuation` batch confirms `2/3`). |
| OpenRouter `google/gemma-3-4b-it` | Hosted API | N/A | N/A | **EVAL (comparison-only)** | `openrouter-gemma3-4b-synthetic-2026-07-24.json` | `1/3` synthetic in this repo. |
| HF Inference (`Qwen/Qwen3-4B-Instruct-2507`) | HF Pro hosted API | N/A | N/A | **EVAL (comparison-only)** | `hf-qwen3-synthetic-2026-07-24.json`, `continuation-hf-2026-07-25.json` | `2/3` synthetic in this repo (`continuation` batch confirms `2/3`). |
| Ollama `gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`, DeepSeek adapter | Server/desktop | N/A | N/A | **EVAL (non-mobile)** | `docs/review/evidence/local-model-eval/*.json` | Desktop checks only; users do not run Ollama/MLX in CoverWise mobile lane. |
| `flutter_gemma` + MediaPipe seam | Flutter mobile bridge | Android ✅ | iOS ✅ | **SCaffold** | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`, `mobile/lib/main.dart` | Feature exists behind `ON_DEVICE_INFERENCE_ENABLED` + `ON_DEVICE_MODEL_URL`; no install/load/ask on real device run in repo. |
| Gemma 3n E2B / E4B (`.task`) | Mobile-local first-party path | Android ✅ / iOS ✅ | Android ✅ / iOS ✅ | **Catalog-only** | Mobile catalog + lane docs | No `.task` artifact, no manifest, no on-device benchmark yet. |
| Gemma 3 270M / 1B | Mobile-local compact path | Android/iOS | Android/iOS | **Catalog-only** | frontier docs | Needs export + runtime validation and mobile benchmarks. |
| Qwen3 0.6B / 1.7B / 4B | Mobile-local compare family | Android/iOS | Android/iOS | **Catalog-only** | frontier docs | No on-device artifact/benchmark. |
| Phi-4-mini / SmolLM3 3B / Ministral 3B | Mobile-local compact compare | Android/iOS | Android/iOS | **Catalog-only** | frontier docs | No exported artifact/runtime evidence. |
| Android managed runtime | Gemini Nano / AICore | Android | — | **Not integrated/run** | no in-app probe | Candidate exists in platform docs but not covered in CoverWise app. |
| iOS managed runtime | Apple Foundation Models | — | iOS | **Not integrated/run** | no in-app probe | Candidate exists in platform docs but not covered in CoverWise app. |
| VLM fallback recovery (`Qwen3-VL`, `PaddleOCR-VL`, `LLaVA`, etc.) | Visual recovery | Android/iOS | Android/iOS | **Catalog-only** | frontier docs | No on-device visual-stage implementation or run yet. |

### 1.4 Transformers.js vs Flutter-native mobile

| Option | Runtime path | Status | Why |
|---|---|---|---|
| Transformers.js (WebGPU/ONNX in WebView/mobile-web) | Browser/mobile-web | **Catalog-only / architecture-separated** | Useful for a web/mobile-web experiment, not Flutter-native production mobile model path. |
| `flutter_gemma` MediaPipe path | Flutter mobile native | **Scaffold** | Only native mobile bridge currently coded, not yet executed on devices. |

## 2) Fine-tune / adapter lane

| Lane | Status | Evidence | Why this is blocked |
|---|---|---|---|
| LoRA / QLoRA / PEFT adapters (any family) | **Not wired** | no tokenizer+artifact+quantization+runtime manifest in mobile lane | No export lineage + no Android/iOS benchmark metadata in app. |
| Merged fine-tuned checkpoints | **Not wired** | none | Same as above; no run contract, no model hash, no model-card governance trace. |

## 3) Provider-key surface (route planning only; no values shown)

Presence in project env files indicates possible research/integration surfaces; not a production claim by itself.

| Project | Key names found | Interpretation for this decision |
|---|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OLLAMA_BASE_URL`, `GROQ_API_KEY` | Active backend model lane and local-server lanes. |
| `orbitcover-d2c` | `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` | OpenRouter comparison routing source (not wired into CoverWise app yet). |
| `comfy` | `HF_TOKEN`, `HF_HOME`, `HF_XET_HIGH_PERFORMANCE`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE` | HF/Modal benchmark lane. |
| `speech_experiments/model-lab` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `HF_HOME` | HF experimentation lane. |
| `invoice-intelligence` | `OPENAI_API_KEY`, `OPENROUTER_API_KEY` | Hosted comparison sources; not mobile-specific. |
| `edureka` | `OPENAI_API_KEY`, `HUGGINGFACE_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY` | Hosted comparison research lane. |
| `learning_for_kids` | `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`, `GEMINI_API_KEY` | Hosted comparison research lane. |
| `bas5minute` | `OPENAI_API_KEY`, `HUGGINGFACE_API_KEY`, `HF_TOKEN`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` | Hosted comparison research lane. |
| `adshot` / `EchoPanel` | `HF_TOKEN`, `GEMINI_API_KEY` (where present) | Hosted exploration only. |
| `SentinelTwin` | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TOGETHER_API_KEY` | Hosted comparison research lane. |

## 4) What has actually been executed in this repository (required by your request)

- `flutter test mobile/test/on_device_inference_service_test.dart`  
  - Result: **3/3 pass** for feature-flag guard behavior + install-attempt reachability (`AppConfig.onDeviceInferenceEnabled` false path and install-model path handling checks).  
  - Evidence file: `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-25.json`.
  - This verifies runtime guard + contract, not an Android/iOS model run.
- `flutter devices` (mobile root)  
  - Result: connected desktop/web/sim entries are detectable depending on current environment; no guaranteed attached Android/iOS physical run in this decision pass.
- `python` synthetic provider smoke evidence exists in committed JSON under:
  - `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`
  - `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json`
  - `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json`
  - `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json`
  - continuation run files from 2026-07-25:
    - `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json`
    - `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json`
    - `docs/review/evidence/provider-smoke/continuation-hf-2026-07-25.json`

## 5) Reasoned shortlist (what to run next, and why)

### Primary production fallback (today)
1. Keep hosted `OpenAI gpt-5-nano` as the only grounded policy-answer default until mobile-offline evidence arrives.

### Mobile/offline first milestone
1. **Run `flutter_gemma` scaffold to real-device lane first**  
   - Use a signed `.task` artifact and manifest with install/load/ask verification.
2. Collect strict manifest on both Android + iOS:
   - cold/warm latency, success/failure classes, timeout/retry behavior, RSS/memory, thermal trend, unsupported-device refusals.
3. Add source-aware validation to keep policy grounding standards intact.

### Comparison/expansion sequence after milestone passes
1. `Gemma 3 270M / 1B` or `Qwen3 1.7B` local compact comparator.
2. Visual recovery lane only if parser/tables fail after OCR improvements (`Qwen3-VL` / `PaddleOCR-VL` family).
3. Managed-device probes (`Gemini Nano/AICore`, `Apple Foundation Models`) only with capability matrices and fallback mapping.

## 6) Why Android/iOS users do not install Ollama/MLX/Transformers.js in this product path

- **Ollama / MLX** are desktop/workstation runtimes and are not user-facing mobile app runtimes.
- **Transformers.js** is browser / WebGPU route, not Flutter-native production Android/iOS product runtime.
- **HF Pro / OpenRouter / Modal / OpenAI API lanes** are hosted/cloud lanes; they are valid comparison/benchmark lanes, not off-device product execution lanes.

## 7) Explicitly open 2025–2026 frontier (parser/layout + OCR + VLM) from catalog file

From `document_parsers_extractors_catalog_2026_v2.xlsx`, the following are currently high-priority for policy parsing experiments (all marked **Catalog-only** for this pass):

- Infinity-Parser2
- RT-DocLayout
- Unlimited-OCR
- PaddleOCR-VL / PP-OCRv6
- Marker 1.10.1
- MinerU2.5-Pro / MinerU-Popo / MinerU-Diffusion
- Qianfan OCR / dots.ocr / FireRed-OCR
- AgenticOCR / Logics-Parsing / Logics-Parsing-Omni
- Dolphin-1.5 / Dolphin-2.0
- HunyuanOCR-1.5 / GLM-OCR / DeepSeek-OCR variants

These are in:
- `mobile_model_catalog_2025_2026_2026-07-24.md`
- `mobile_model_frontier_2024_plus_inventory_2026-07-25.md`

## 8) Canonical cross-document anchors

- `docs/review/mobile_model_exploration_map_2026-07-24.md`
- `docs/review/mobile_model_full_evaluation_compendium_2026-07-25.md`
- `docs/review/mobile_model_evaluation_inventory_2026-07-25.md`
- `docs/technical/mobile_local_model_evaluation_2026-07-24.md`
- `docs/review/mobile_model_truth_matrix_2026-07-25.md`
