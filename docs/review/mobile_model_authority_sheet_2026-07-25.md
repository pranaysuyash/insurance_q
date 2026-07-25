# CoverWise mobile model authority sheet (2026-07-25)

Status target: Android/iOS users, policy-RAG workflow, post-2024 frontier coverage.

## 0) What “evaluated” means in this repo

- **EVAL:** reproducible run output exists in this repo for that lane and stage.
- **SCaffold:** mobile integration code exists, but no real Android/iOS `install → load → ask` proof.
- **Catalog-only:** identified in docs/inventory or frontier scans, no execution output in this repo.
- **Context-only:** key/infra exists in some project(s), no CoverWise mobile execution path.
- **Hosted-only:** cloud API/remote service, not on-device phone execution.

## 1) Requested lane-by-lane answers

### 1A) Local/offline mobile options (Android/iOS capable path)

| Candidate / lane | Mobile runtime target | Eval status | Why this status |
|---|---|---:|---|
| `flutter_gemma` + `flutter_gemma_mediapipe` (`ON_DEVICE_INFERENCE_ENABLED`, `ON_DEVICE_MODEL_URL`) | Android + iOS | **SCaffold** | Service + config gate exists in app code. No real `.task` install/load/ask proof yet. |
| Gemma 3n E2B / E4B (`.task`) | Android + iOS | **Catalog-only** | No signed/approved artifact hash and no device execution trace yet. |
| Gemma 3 270M / 1B | Android + iOS | **Catalog-only** | No mobile export, no install/load/ask benchmark yet. |
| Qwen3 0.6B / 1.7B / 4B | Android + iOS | **Catalog-only** | No mobile export, no device execution yet. |
| Phi-4-mini / SmolLM3 3B / Ministral 3B | Android + iOS | **Catalog-only** | No mobile export/manifest, no benchmark yet. |
| Qwen3-VL 2B / 4B, PaddleOCR-VL, Dolphin, etc. | Android + iOS fallback stage | **Catalog-only** | Candidate visual-recovery lanes, no app-level implementation/evidence yet. |
| Managed Android runtime (`Gemini Nano`/`AICore`) | Android only | **Catalog-only / not integrated** | No in-app OS capability matrix run in CoverWise. |
| Apple Foundation Models | iOS only | **Catalog-only / not integrated** | No in-app OS capability matrix run in CoverWise. |

### 1B) Hosted provider lanes (paid/managed comparison/fallback)

| Candidate / provider | Eval status | Result in repo | Why it is not mobile-offline |
|---|---|---|---|
| OpenAI `gpt-5-nano` | **EVAL** | `openai-synthetic-2026-07-24-success.json`, `continuation-smoke-2026-07-25.json`, `realitycheck-openai-2026-07-25.json`, `realitycheck-openai-2026-07-26.json`, `policy-corpus-ragas-2026-07-24.json` | Cloud API. |
| OpenRouter (`google/gemini-2.5-flash-lite`, `google/gemma-3-4b-it`) | **EVAL (limited)** | `openrouter-synthetic-2026-07-24.json`, `continuation-openrouter-2026-07-25.json`, `realitycheck-openrouter-2026-07-25.json` | Cloud API only; latest cross-project run using `orbitcover-d2c/.env` passed `2/3` (grounded-answer miss on one task), median `678ms`. |
| HF Pro / HF Inference (`Qwen/Qwen3-4B-Instruct-2507`) | **EVAL (limited)** | `hf-qwen3-synthetic-2026-07-24.json`, `continuation-hf-2026-07-25.json`, `realitycheck-hf-2026-07-25.json` | Cloud API, no device runtime contract. Latest cross-project run using `speech_experiments/model-lab/.env` passed `2/3` (grounded-answer miss), median `894ms`. |
| Modal Labs (`comfy` token flow) | **Context-only** | `comfy` env-key inventory only | Private hosted GPU/benchmark lane only; no CoverWise mobile endpoint in this repo. |
| OpenAI/Groq/Others in other projects | **Context-only** (this pass) | cross-project key inventories only | Project environment evidence does not imply CoverWise mobile routing. |

### 1C) Desktop/local non-mobile lanes (helpful for comparison, not Android/iOS)

| Candidate | Eval status | Reason |
|---|---|---|
| Ollama (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`) | **EVAL (desktop-only)** | Local workstation inference only. |
| DeepSeek OCR adapter / Surya-2 / docTR checks | **EVAL (desktop/local)** | Local/desktop checks only; not phone execution. |
| Transformers.js (`WebGPU/ONNX`) | **Not in Flutter-native lane** | Browser/web-mobile experiment lane, separate from Flutter-native Android/iOS route. |

## 2) What was actually explored, selected, and why (shortlist)

### 2A) Explored/evaluated with run evidence

- **Keep baseline:** OpenAI `gpt-5-nano` as primary policy-grounded fallback.
- **Comparators:** OpenRouter Flash Lite, OpenRouter Gemma 3 4B, HF Pro Qwen3 4B (comparison-only in policy workflow).
- **Scaffolded on-device path:** `flutter_gemma` seam exists with guard-path tests.

### 2B) Not yet selected (needs gates)

- All other mobile-offline candidate families (Gemma/Qwen compacts, Phi/SmolLM/Ministral, VLM recovery, managed OS-native lanes) remain at Catalog-only until:
  1. A valid `.task`/runtime artifact is available,
  2. Android+iOS install/load/ask telemetry is captured,
  3. Retry/timeouts/cancel/security fallback behavior is validated.

## 3) Why Android/iOS users do not install Ollama/MLX/local desktop stacks

- Those are workstation/server runtimes and cannot replace in-app mobile inference without a separate mobile runtime pipeline and packaged/compatible artifact.
- Android/iOS users should expect:
  - local seam via app runtime (`ON_DEVICE_*` + supported format),
  - or hosted APIs (OpenAI/OpenRouter/HF/Modal-like remote inference),
  - or managed native runtimes where OS integration is shipped with the app.

## 4) Pipeline truth by stage

### Ingestion / parse / OCR
- Canonical in-repo baseline: PyMuPDF + existing chunking/retrieval pipeline (repo-verified for policy pipeline).
- 2025–2026 parser/OCR frontier models are inventoried from catalog as **candidate** lanes, no on-device run yet.

### Embedding / retrieval
- Baseline embedding/retrieval remains hosted/text-embedding pipeline in policy evidence path (`52Q` corpus currently measured on that path).
- Mobile embedding candidates (EmbeddingGemma / Qwen3-Embedding family) are **Catalog-only** until export + on-device benchmark.

### Generation / grounding
- Hosted generation evidence exists for OpenAI / OpenRouter / HF Pro.
- On-device generation evidence does **not** yet include Android/iOS install/load/ask success.

## 5) Policy-doc evaluation status (the “not just top-of-mind” point)

- Authoritative corpus file currently used for this decision lane: `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json`.
- Current measured scores in that file:
  - `total_questions: 52`
  - `accuracy: 0.5577`
  - `citation_rate: 0.9615`
  - `hallucination_rate: 0.3333`
  - `ragas_metrics`:
    - `faithfulness: 0.8368`
    - `context_precision: 0.4558`
    - `answer_relevancy: 0.7148`
- Interpretation: measurable corpus signal exists; quality still below production confidence for full replacement by mobile-offline lanes without additional safeguards.

## 6) Current run reality check (2026-07-25, this pass)

- `cd mobile && flutter test test/on_device_inference_service_test.dart` → **3/3 pass** (guard + install-attempt reachability logic).
- Fresh provider smoke executed with local `.env`:
  - `python tools/evaluate_provider_smoke.py --provider openai --dotenv .env --output docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-25.json`
  - Result: **3/3 pass**, `gpt-5-nano-2025-08-07`, median ~`1115ms`.
- OpenRouter/HF smoke was then executed using cross-project key surfaces (not by values):  
  - `OPENROUTER_API_KEY` from `orbitcover-d2c/.env` → `realitycheck-openrouter-2026-07-25.json` (**2/3**, median `678ms`) and `realitycheck-openrouter-2026-07-26.json` (**2/3**, median `829ms`)  
  - `HF_TOKEN` from `speech_experiments/model-lab/.env` → `realitycheck-hf-2026-07-25.json` (**2/3**, median `894ms`) and `realitycheck-hf-2026-07-26.json` (**2/3**, median `955ms`).

## 7) 2025–2026 frontier candidates from `document_parsers_extractors_catalog_2026_v2.xlsx` (catalog-only today)

- Total frontier entries in active inventory: **77** (`recent_models_2024_plus_inventory_2026-07-25.json`).
- High-priority examples from 2026+ frontiers:
  - `Unlimited-OCR`, `RT-DocLayout`, `Infinity-Parser2`, `HunyuanOCR-1.5`, `Qianfan-OCR`, `GLM-OCR`, `DeepSeek-OCR 2`, `PaddleOCR-VL 1.5/1.6`, `Marker`, `MinerU-Popo`, `AgenticOCR`, `Dolphin-2.0`, `MeDocVL`, `dots.mocr`.
- Representative 2025 examples:
  - `Uni-Parser`, `Marker 1.10.1`, `PaddleOCR-VL`, `MonkeyOCR`, `Dolphin`, `Chandra`, `Doc-Researcher`, `MinerU`, `PP-StructureV3`, `open-parse`.
- Full frontier file: `mobile_model_frontier_2024_plus_inventory_2026-07-25.md`.

## 8) Fine-tune / adapter status

- No production-ready LoRA / QLoRA / merged adapter path is currently wired into mobile routing.
- No tokenizer+quantization+manifest set is present for offline Android/iOS execution of adapters.

## 9) Next concrete action shortlist (with reason)

1. **Run real mobile lane first:** provide a signed `.task` artifact compatible with `flutter_gemma` and execute Android+iOS `install → load → ask` with telemetry.
2. **Then compare compact on-device lane:** one of `Gemma 3 1B`, `Qwen3 1.7B/4B`, `SmolLM3/Phi-4-mini` under same telemetry contract.
3. **Then manage compare/fallback:** keep OpenAI as default policy anchor until offline lanes pass parity, grounding, and stability gates.
4. **Then add managed-device matrix:** Android `Gemini Nano/AICore`, iOS `Foundation Models` only after OS capability/failure probes are added.

## 10) Canonical references for this decision

- `docs/review/mobile_model_stage_truth_matrix_2026-07-25.md`
- `docs/review/mobile_model_execution_ledger_2026-07-25.md`
- `docs/review/mobile_model_decision_shortlist_2026-07-25.md`
- `docs/review/mobile_model_frontier_2024_plus_inventory_2026-07-25.md`
- `docs/technical/mobile_local_model_evaluation_2026-07-24.md`
