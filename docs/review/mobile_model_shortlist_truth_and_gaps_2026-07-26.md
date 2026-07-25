# Mobile model shortlist: evaluated vs not, by stage (CoverWise, as of 2026-07-26)

This file is the concise execution ledger you asked for: **what was explored, what was run, what is still scaffold-only, and what remains a catalog/prospection item**.

For the full 77-model machine-joined frontier list with stage/status columns, use:

- [mobile_model_shortlist_generated_2026-07-26.md](mobile_model_shortlist_generated_2026-07-26.md)

## 0) Evidence-first decision rule

- **EVAL**: evidence file exists for the exact stage/runtime used in this repo.
- **SCaffold**: integration exists (contracts/tests/gates), but no Android/iOS install/load/ask execution.
- **Catalog-only**: present in catalogs/notes but not run in this repo.

## 1) Provider and model status (what is truly evaluated)

### 1.1 Hosted/cloud lanes (paid or token-based, not on-device)

| Lane | Status | Evidence | Why it matters |
|---|---|---|---|
| OpenAI `gpt-5-nano` | **EVAL** | `docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json` | 3/3 pass, grounded output path passes in synthetic tests. |
| OpenRouter `google/gemini-2.5-flash-lite` | **EVAL (limited)** | `docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json` | 2/3 pass; grounded-answer synthetic fails 1/3; useful for cost/latency comparison only. |
| OpenRouter `google/gemma-3-4b-it` | **EVAL (limited)** | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | 1/3 pass in synthetic; comparison-only. |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | **EVAL (limited)** | `docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json` | 2/3 pass synthetic; useful as hosted benchmark lane. |
| policy corpus held-out baseline | **EVAL (repo policy QA)** | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | 52Q: `accuracy=0.5577`, `citation_rate=0.9615`, `hallucination_rate=0.3333` (historical) for policy QA behavior. |
| Ollama desktop (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`) | **EVAL (desktop-only)** | `docs/review/evidence/local-model-eval/*.json` | Desktop/server lane, not Android/iOS app runtime. |

### 1.2 Paid keys / project surfaces checked

Live `.env` presence scan (values omitted):

| Project surface | File checked | Keys present |
|---|---|---|
| `medpiper/insurance_app` | `.env` | `OPENAI_API_KEY`, `OLLAMA_BASE_URL` |
| `orbitcover-d2c` | `.env` | `OPENROUTER_API_KEY` |
| `comfy` | `.env` | `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE` |
| `invoice-intelligence` | `.env` | `OPENAI_API_KEY` |
| `speech_experiments/model-lab` | `.env` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` |
| `learning_for_kids` | `.env` | `HF_TOKEN`, `GEMINI_API_KEY` |
| `bas5minute` | `.env.example` | `OPENAI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`, `GEMINI_API_KEY` |
| `adshot` | `.env` | `HF_TOKEN`, `GEMINI_API_KEY` |
| `SentinelTwin` | `.env` | `OPENAI_API_KEY`, `GEMINI_API_KEY` |

These are **key-presence checks only**; key presence does not imply Android/iOS model execution.

## 2) Mobile-native generation/offline lane status (your explicit mobile question)

| Candidate | Stage | Status | Evidence |
|---|---|---|---|
| `flutter_gemma` + MediaPipe seam (`flutter_gemma`, `flutter_gemma_mediapipe`) | On-device generation contract | **SCaffold** | `mobile/lib/services/on_device_inference_service.dart` + `mobile/lib/config/app_config.dart` + `mobile/test/on_device_inference_service_test.dart` |
| Gemma 3n `.task` (E2B/E4B) | Mobile-native execution | **Catalog-only** | No `.task` install/load/ask artifact + no signed manifest proof run in repo yet |
| Gemma 3 270M / 1B | Mobile-native execution | **Catalog-only** | No exported artifact / no device execution trace in repo |
| Qwen3 0.6B / 1.7B / 4B | Mobile-native execution | **Catalog-only** | No exported artifact / no device execution trace in repo |
| Phi-4-mini / SmolLM3 / Ministral3B | Mobile-native execution | **Catalog-only** | No exported artifact / no device execution trace in repo |
| Qwen3-VL / PaddleOCR-VL / LLaVA families | Visual recovery stage | **Catalog-only** | Parser/layout candidates only, not implemented on-device in this pass |
| Android managed `Gemini Nano` / `AICore` | Platform-native managed runtime | **Not integrated/run** | No in-app mobile capability matrix in this repo pass |
| iOS managed Foundation Models | Platform-native managed runtime | **Not integrated/run** | No in-app mobile capability matrix in this repo pass |

### 2.1 Explicit shortlist by your requested lane

| Lane | In-scope model family | Status | Why selected / skipped now |
|---|---|---|---|
| Hosted paid/commercial | OpenAI, OpenRouter, HF Pro (`Qwen/Qwen3-4B-Instruct-2507`) | **Selected for benchmark/comparison** | Reproducible evidence exists for synthetic + policy-pipeline checks; these remain hosted lanes, not Android/iOS local runtime. |
| Modal Pro benchmark lane | `HF` + `MODAL_*` infra | **Context only** | Project-level token access exists in `comfy`, but no CoverWise mobile bridge to on-device pipeline. |
| Flutter on-device seam | `flutter_gemma` + `flutter_gemma_mediapipe` | **Scaffold** | Core service/tests exist, but no real `install → load → ask` phone artifact telemetry. |
| Fine-tuned/adapter path | LoRA/PEFT/QLoRA family | **Excluded this pass** | No complete mobile artifact manifest + telemetry for Android/iOS promotion. |
| Parsers / OCR frontier (2024–2026 catalog) | `Unlimited-OCR`, `RT-DocLayout`, `PaddleOCR-VL`, `MinerU`, `Marker`, `Dolphin`, `Docling`-adjacent | **Catalog-only** | Important to pipeline quality, but still not mobile-device executed in-repo. |
| `Transformers.js` / WebGPU lane | Browser JS execution path | **Not in app lane** | Not wired into Flutter Android/iOS app runtime path in this repo. |

## 3) Transformers.js / web GPU lane

- **Not active for Flutter native app runtime in this repo.**
- Present as research direction only, not an Android/iOS-in-app inference path currently.

## 4) Stage-wise truth map (what affects RAG pipeline)

### Ingestion / parsing
- PyMuPDF canonical path and local OCR route: **EVAL** for server-side policy flow.
- Docling/Marker/MinerU/RT-DocLayout/Unlimited-OCR/etc.: **Catalog-only** for now.

### Chunking / structure reconstruction
- Current chunking/reconstruction passes used by policy flow: **EVAL**.
- table/section reconstruction upgrades still tracked as pipeline experiments and are not yet all mobile-proven.

### Embedding / retrieval / rerank
- Hosted embedding (`text-embedding-3-small`) + retrieval/rerank in production path: **EVAL**.
- Embedding alternatives (EmbeddingGemma/Qwen embedding families on device): **Catalog-only**.

### Generation / answer
- Hosted provider generation: **EVAL** (as per table above).
- Mobile generation seam: **SCaffold** only.
- Managed platform generation lanes: **Not integrated/run**.

## 5) Practical shortlist for execution (why each is at this rank)

1. **Finish Gemma 3n mobile-lane evidence first**  
   - Requires signed `.task`, install/load/ask flow on Android + iOS, and telemetry (latency/RSS/thermal/failure class/cancel/retry).
2. **Run second-wave compact comparator only after step 1**  
   - Candidate: Gemma 3 270M / 1B or Qwen3 1.7B (mobile export + run parity).
3. **Then decide managed-runtime fallback path**  
   - Android (`Gemini Nano`/AICore) and iOS (Foundation Models) only after hardware probing and refusal matrix.
4. **Keep hosted lanes as fallback, not local-offline claim**  
   - OpenAI/OpenRouter/HF remain high-value paid/benchmark lanes.
5. **Parser/OCR frontier** (2025–2026 frontier from catalog) remains research-only until on-device binding is proven.

## 6) What is still missing to mark mobile-offline as production-available

- `ON_DEVICE_MODEL_URL` + signed `.task` artifact present and verified.
- Android/iOS install/load/ask evidence in CI/runtime with pass/fail telemetry.
- Schema/citation validation in the mobile answer path matching server policy checks.
- Fallback behavior proofs for unsupported hardware and timeout/cancel/retry conditions.

## 7) Concrete evaluation + key-surface inventory used in this pass (what was looked at)

### 7.1 Evaluated model/provider lanes with runnable evidence

| Lane | Why it was evaluated | Evidence file | Evidence outcome |
|---|---|---|---|
| OpenAI `gpt-5-nano` | baseline hosted JSON/grounded smoke and policy-stack compatibility probe | `docs/review/evidence/provider-smoke/continuation-combined-2026-07-26c.json`, `docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json` | `3/3` pass, grounded-answer synthetic pass; latency ~1.1s |
| OpenRouter `google/gemini-2.5-flash-lite` | alternate hosted benchmark/fallback candidate | `docs/review/evidence/provider-smoke/continuation-combined-2026-07-26c.json`, `docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json` | `2/3` pass; grounded-answer synthetic fail in both runs |
| OpenRouter `google/gemma-3-4b-it` | alternative hosted quality check and token mix | `docs/review/evidence/provider-smoke/continuation-combined-gemma3-2026-07-26c.json` | `1/3` pass |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | paid HF tokened inference lane benchmark | `docs/review/evidence/provider-smoke/continuation-combined-2026-07-26c.json`, `docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json` | `2/3` pass |
| On-device Flutter seam (`flutter_gemma`) | prove platform wiring and control-path execution | `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26b.json` | `3/3` control-path (no real `.task` install/load/ask) |

### 7.2 Not-evaluated for this request (intentional scope)

All parser/OCR frontier models from `document_parsers_extractors_catalog_2026_v2.xlsx` are still **Catalog-only** for this pass, including:

- `Unlimited-OCR`, `RT-DocLayout`, `PaddleOCR-VL`, `PaddleOCR-VL-1.5`, `PaddleOCR-VL-1.6`, `MinerU` family, `Marker 1.10.1`, `Dolphin`, `qwen3-vl`/visual-recovery candidates, `MonkeyOCR`, `Open-Parse`, `Docling`-adjacent families, `Gemma`/`Qwen3` mobile-form compact families.

These appear in:

- [`mobile_model_full_evaluation_compendium_2026-07-26.md`](mobile_model_full_evaluation_compendium_2026-07-26.md)
- [`mobile_model_shortlist_generated_2026-07-26.md`](mobile_model_shortlist_generated_2026-07-26.md)
- [`mobile_model_frontier_2026_plus_truth_matrix_2026-07-26.md`](mobile_model_frontier_2026_plus_truth_matrix_2026-07-26.md)

### 7.3 Project key surfaces checked (paid / paid-like lanes)

| Project / surface | Keys found (values redacted) | Lane meaning for CoverWise mobile |
|---|---|---|
| `medpiper/insurance_app/.env` | `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OLLAMA_BASE_URL` | Hosted baseline + local-server lane; no active on-device manifest |
| `orbitcover-d2c/.env` | `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`, `OPENROUTER_TIER` | Hosted comparison lane only |
| `comfy/.env` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `HF_HOME`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE` | HF Pro + Modal GPU infra, no in-app mobile bridge |
| `speech_experiments/model-lab/.env` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `HF_HOME` | HF model-lab benchmark lane |
| `invoice-intelligence/.env` / `.env.example` | `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` | Hosted comparison only |
| `learning_for_kids/.env` | `HF_TOKEN`, `GEMINI_API_KEY` | Hosted/experiment lane only |
| `adshot/.env` | `HF_TOKEN`, `GEMINI_API_KEY` | Hosted/prototype lane |
| `EchoPanel/.env` | `HF_TOKEN` | hosted/prototype lane |
| `oc-b2b/.env.example` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` (template) | template surface only |
| `ad`-named/`orbitcover`-named helper projects | key-surface only in separate projects; not wired into this mobile runtime |

### 7.4 Why no Android/iOS local install for Ollama/Transformers.js etc

- `Ollama` = desktop/local-server runtime path in this repo; no phone-side artifact/runtime wiring in CoverWise.
- `MLX` = Mac-focused/desktop lane, not Flutter Android/iOS shipping path.
- `Transformers.js` / WebGPU / ONNX Web = web/mobile-web lane only; no Flutter-native bridge used in production route.

### 7.5 Fine-tune / adapter lane truth for this request

- Fine-tune/adapters exist as research artifacts in other projects, but **none** are promoted to Android/iOS mobile execution lane because there is no shipped artifact manifest (`.task`, `.gguf`, `.onnx`, `.tflite`) plus no install/load/ask telemetry.
