# Mobile model truth matrix (2026-07-25)

This document consolidates the latest mobile-model exploration in one pass:

- what we can run on-device today,
- what we only have in catalog/planning,
- what is currently just hosted/provider comparison,
- and what is not done yet.

## Evidence rule

- **EVAL** = reproducible run output in this repository for that specific stage/runtime.
- **SCaffold** = integration code exists, but no Android/iOS run yet.
- **Catalog-only** = in exploration/candidate registers only.
- **Hosted-only** = cloud API lane (not on-device/offline).
- **Not applicable** = wrong model family/runtime for this product lane.

## 1) Stage-wise evaluation (CoverWise policy workflow)

| Stage | Candidate/lane | Mobile runtime type | Status | Evidence / comment |
|---|---|---|---|---|
| Parse / OCR / layout | PyMuPDF + native page OCR pipeline (canonical) | Server | **EVAL** | Canonical policy intake for current product path. See `policy-corpus-ragas-2026-07-24.json`. |
| Parse / OCR alternatives | Surya-2, docTR, Gemma/Qwen OCR experiments, DeepSeek-OCR adapter | Desktop/server | **Scaffold/Catalog** | Useful compatibility baseline; not Android/iOS device proof. |
| Parse / OCR frontier | Docling, Marker, MinerU, RT-DocLayout, Unlimited-OCR, PaddleOCR-VL, Dolphin, Qianfan, etc. | Candidate | **Catalog-only** | Listed in `mobile_model_catalog_2025_2026_2026-07-24.md` and linked frontier files. |
| Chunking / reconstruction | Paragraph/entity/adjacent reconstruction | Server + canonical pipeline | **EVAL** | Chunking changes in pipeline map and corpus execution; mobile-only tuning open. |
| Embedding / retrieval | Hosted text-embedding-3-small | Hosted | **EVAL** | 52Q policy baseline has retrieval-stage evidence. |
| Embedding local candidates | EmbeddingGemma, Qwen3-Embedding (0.6/4/8B), mobile-native embeddings | Planned | **Catalog-only** | No mobile-bound embedding execution evidence yet. |
| Hosted generation fallback | OpenAI `gpt-5-nano` | Hosted | **EVAL (limited)** | Policy corpus + provider smoke artifacts (pass + failures tracked). |
| Hosted generation compare | OpenRouter `google/gemini-2.5-flash-lite`, `google/gemma-3-4b-it` | Hosted | **EVAL (synthetic comparison only)** | Not mobile/offline. |
| Hosted generation compare | HF Pro (`Qwen/Qwen3-4B-Instruct-2507`) | Hosted | **EVAL (synthetic comparison only)** | HF credits enable API, not phone-side execution. |
| Local on-device generation | `flutter_gemma` seam + `.task` install/load/ask hooks | Android/iOS bridge | **Scaffold** | Service + config gate exists (`ON_DEVICE_INFERENCE_ENABLED`, `ON_DEVICE_MODEL_URL`), no model artifact + no live run in this pass. |
| Local candidates | Gemma 3n E2B/E4B; Gemma 3 270M/1B; Qwen3 0.6B/1.7B/4B; Phi-4-mini; SmolLM3; Ministral 3B; Qwen3-VL 2B/4B | Android/iOS candidates | **Catalog-only** | Candidate list for the first local lane. |
| Managed runtime candidates | Android Gemini Nano / AICore | Android only | **Catalog-only** | No in-app capability probe in CoverWise yet. |
| Managed runtime candidates | Apple Foundation Models | iOS only | **Catalog-only** | No in-app capability probe in CoverWise yet. |
| Transformers.js web/mobile-web lane | Browser/bridge route | Non-native mobile | **Not in Flutter-native lane** | Useful only as separate experiment. |

## 2) Why the “doesn’t run on phone” questions are true

- **Ollama / MLX / Ollama-base desktop lanes:** service-local dev/test tooling, not Android/iOS user runtime.
- **HF Pro / HF Inference API:** hosted execution; requires network/API quota, not install of a phone model binary.
- **Modal Labs:** private GPU or private remote execution for experimentation; not a mobile runtime.
- **OpenRouter:** provider router for hosted models; not on-device.

So for Android/iOS users, “present in repo or in env” is not equivalent to “can run locally on the phone.”

## 3) Mobile-runtime options by model family (decision matrix)

| Model family | 2025/2026 relevance | Android/iOS execution today | Practical routing | Evaluation status | When to promote |
|---|---|---|---|---|---|
| Gemma 3n E2B / E4B | high (2025) | candidate (MediaPipe/LiteRT path) | shared cross-platform route | **Catalog-only** | after `.task` export, install path, and device telemetry pass |
| Gemma 3 270M / 1B | medium | candidate (compact on-device) | local shared route | **Catalog-only** | after Gemma 3n lane proves quality/latency gain |
| Qwen3 0.6/1.7/4B | medium/high | candidate (portable export) | local shared route | **Catalog-only** | after export + Android/iOS matrix and held-out recall gate |
| Phi-4-mini / SmolLM3 / Ministral 3B | medium | candidate (portable export) | local shared route | **Catalog-only** | after Gemma/Qwen lane and failure policy are in place |
| Qwen3-VL 2B/4B | medium (visual recovery) | candidate (Vision lane) | stage-2 fallback only | **Catalog-only** | only after text path closed and OCR failure rates justify visual fallback |
| OpenAI / OpenRouter / HF / Groq / Gemini API | high | hosted fallback only | backend stage | **EVAL / comparison** | keep as comparison or fallback, not as mobile offline |
| Transformers.js (WebGPU/ONNX) | medium | web mobile only | separate web experiment | **Not in Flutter-native production lane** | only if Flutter-web path is deliberately split |
| Gemma/mini models via `.task` + `flutter_gemma` | high architecture fit | Android/iOS candidate | local lane | **Scaffold** | first target for real on-device proof |

## 4) Key-file evidence summary (tests and artifacts)

- `mobile/lib/services/on_device_inference_service.dart` (scaffold + install/load/ask, config-gated)
- `mobile/lib/config/app_config.dart` (`ON_DEVICE_INFERENCE_ENABLED`, `ON_DEVICE_MODEL_URL` + validation)
- `mobile/test/on_device_inference_service_test.dart` → **3/3 passed** (guard + install guard + install-attempt-path test)
- `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json` → OpenAI 3/3 synthetic
- `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json` → OpenAI `gpt-5-nano` 3/3 synthetic, median 1619 ms
- `.../provider-smoke/openrouter-synthetic-2026-07-24.json` → 2/3 synthetic
- `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json` → OpenRouter gemini-2.5-flash-lite 2/3 synthetic, median 1025 ms
- `.../provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` → 1/3 synthetic
- `.../provider-smoke/hf-qwen3-synthetic-2026-07-24.json` → 2/3 synthetic
- `docs/review/evidence/provider-smoke/continuation-hf-2026-07-25.json` → HF Pro Qwen3-4B 2/3 synthetic, median 1026 ms
- `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` → held-out policy metrics (hosted generation baseline)
- `docs/review/evidence/local-model-eval/gemma3-12b-2026-07-12.json`, `gemma3-4b-recheck-2026-07-12.json`, `deepseek-ocr-diagnostic-2026-07-12.json` → desktop/server-only lane

## 5) Live provider-key inventory (presence only, no values)

Checked in project `.env`/`.env.example` files:

- `medpiper/insurance_app`: `OPENAI_API_KEY`, `HF_TOKEN`, `OLLAMA_BASE_URL`, `GROQ_API_KEY` (present names)
- `orbitcover-d2c`: `OPENROUTER_API_KEY`
- `comfy`: `HF_TOKEN`, `HF_HOME`, `HF_XET_HIGH_PERFORMANCE`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`
- `speech_experiments/model-lab`: `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `HF_HOME`
- `oc-b2b`: `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` (`.env.example` includes hard-coded token value in template; that is discovery-only for this review)
- `invoice-intelligence`: `OPENAI_API_KEY`, `OPENROUTER_API_KEY`
- `edureka`: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY`, `HUGGINGFACE_API_KEY`
- `learning_for_kids`: `GEMINI_API_KEY`, `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`
- `adshot`: `GEMINI_API_KEY`, `HF_TOKEN`
- `SentinelTwin`: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TOGETHER_API_KEY`
- `notes`: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `OLLAMA_HOST`
- `musicathon`: `HF_TOKEN`
- `EchoPanel`: `HF_TOKEN`

CoverWise-specific control-plane note: in the repository `.env`/.`env.example` set checked here, there is no active `ON_DEVICE_INFERENCE_ENABLED`/`ON_DEVICE_MODEL_URL` configuration for a shipped model URL, so the on-device seam is intentionally off unless set explicitly at build time.

Presence-only interpretation:

- key presence in another project is **discovery/research capability**;
- it is **not** a routing proof that CoverWise mobile currently sends policy queries there.

## 6) Shortlisted fallback chain (practical, stage-aware)

1. **Primary production fallback (current)**: OpenAI hosted `gpt-5-nano` with schema/evidence gates in server flow.
2. **Comparison fallback lane**: OpenRouter/HF inference for controlled benchmark routing when policy context permits.
3. **Paid private infrastructure**: Modal remote for heavier model comparison only (not mobile-offline).
4. **Mobile-first experimental lane**: `flutter_gemma` + Gemma-family `.task` once artifact + install + iOS/Android matrix is done.
5. **Secondary local alternatives** after lane-1 passes: Qwen3-1.7B/4B, Phi-4-mini, SmolLM3, Ministral 3B.
6. **Visual recovery lane** (stage-3): Qwen3-VL, PaddleOCR-VL family only after OCR/layout default path is established.

## 7) Current run reality (as-of 2026-07-25)

- `cd mobile && flutter devices` reports:
  - `iPhone 17 (mobile)` (iOS simulator `F5AC13E5-FDAF-4877-B7FF-4265A3180931`)
  - `macOS` (desktop)
  - `Chrome` (web)
- `cd mobile && flutter test test/on_device_inference_service_test.dart` → **3/3 passed** (guard + install-path reachability checks).
- `cd mobile && flutter test -d F5AC13E5-FDAF-4877-B7FF-4265A3180931 --dart-define=ON_DEVICE_TEST_INSTALL_ATTEMPT=true --dart-define=ON_DEVICE_INFERENCE_ENABLED=true --dart-define=ON_DEVICE_MODEL_URL=https://example.com/model.task test/on_device_inference_service_test.dart` -> **3/3 passed** with controlled install-attempt throw path.
- Result: simulator/device availability and guard-path behavior are confirmed, but **no Android/iOS on-device model generation/execution (install/load/ask) has been completed in this pass**.

## 7a) Fine-tune / adapter lane status

- No production-ready fine-tune/adapter artifacts (LoRA/QLoRA/merged checkpoints + tokenizer + quantization hash) are wired into CoverWise mobile routing.
- Any adapter candidate currently remains `Catalog-only` until its export lineage, runtime format, and per-device fallback telemetry are added.

### 7b) Policy-corpus eval status (current continuation pass)

- A fresh 52-question policy corpus rerun was started from `src/eval/ragas_eval`, but the active pass was not completed in this continuation due long-running external LLM calls.
- During the continuation pass, live log trace showed 27/52 questions processed before the run was paused, with no runtime errors or policy failures; no completed JSON artifact was emitted for that pass.
- **Authoritative completed baseline used for decisions:** `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json`
  - `total_questions: 52`
  - `accuracy: 0.5577`
  - `source_coverage: 1.0`
  - `citation_rate: 0.9615`
  - `ragas_metrics` → `faithfulness: 0.8368`, `context_precision: 0.4558`, `answer_relevancy: 0.7148`
- Interpretation: policy corpus quality is measurable but still below production confidence for full migration to on-device/offline generation without additional recovery logic.

## 8) Why this is the right next move

The blocker is no longer “model shopping”; it is **execution contract completion**:

- artifact build and install chain,
- device capability matrix,
- latency/memory/thermal telemetry,
- cancellation + retry + timeout behavior,
- mobile failure policy and fallback routing.

No model can be considered promoted to mobile-offline production until this is complete.

## 9) Explored vs. selected vs. not yet run (single-sheet style)

### 9.1 Explored (reproducible run artifacts in-repo)

- **Hosted fallback/compare runs**
  - OpenAI `gpt-5-nano-2025-08-07`: policy corpus + smoke evidence (`3/3` synthetic in both July 24 + continuation July 25 runs, `52Q` policy corpus score `0.5577` accuracy).
  - OpenRouter Gemini 2.5-flash-lite: synthetic (`2/3` in both July 24 + continuation July 25 runs).
  - OpenRouter Gemma 3 4B: synthetic (`1/3`).
  - HF Pro `Qwen/Qwen3-4B-Instruct-2507`: synthetic (`2/3` in both July 24 + continuation July 25 runs).
- **Policy pipeline**
  - Parse/retrieve/score pipeline and chunking/reconstruction logic are covered in held-out policy workflow evidence.
  - Desktop/server OCR/vision checks exist (Gemma3/Qwen2.5VL/DeepSeek-OCR variants) but are **not** Android/iOS.
- **Code-scaffold-only checks**
- `on_device_inference_service` + `app_config` + harness tests (`3/3`) validate contract shape (`ON_DEVICE_*` feature-flagged path), not runtime execution.

### 9.2 Stage-aware shortlist (what to run next, by reason)

1. **Keep production anchor** — hosted `OpenAI gpt-5-nano` for grounded policy responses until on-device parity is proven.
2. **Add one paid benchmark plane** — continue OpenRouter/HF smoke as a controlled A/B plane when comparing cost/latency but do **not** treat as mobile-offline candidates.
3. **Run first real mobile lane** — `Gemma 3n` via existing `flutter_gemma` seam (requires `.task` artifact, install integrity, and iOS/Android matrix).
4. **Compare compact on-device candidate** after lane #3 passes telemetry gate: `Qwen3-1.7B` or `Gemma 3 270M/1B`.
5. **Add managed-device probes** only after local lane stability: Android Nano/AICore and iOS Foundation Models capability probes + fallback map.
6. **Visual fallback only if text stage stays failing**: `Qwen3-VL`/`PaddleOCR-VL` family with strict "OCR/layout fail rate > threshold" gate.

### 9.3 Not yet run on Android/iOS local model execution

- Gemma family lane beyond scaffold (`3n`, `3 270M/1B`).
- Qwen3 lane (`0.6B`, `1.7B`, `4B`) and compact siblings (`Phi-4-mini`, `SmolLM3`, `Ministral 3B`).
- Managed-native platform models (`Gemini Nano`/`AICore`, `Apple Foundation Models`).
- Transformers.js as Flutter-native offline lane.
- 2025–2026 frontier OCR/parser candidates from the catalog (`Docling`, `Marker`, `MinerU`, `RT-DocLayout`, `Unlimited-OCR`, `PaddleOCR-VL`, `Dolphin`, etc.).
