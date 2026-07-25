# Mobile model truth addendum (2026-07-25)

## What this addendum fixes
- I checked live workspace evidence in `/Users/pranay/Projects` for provider-key surfaces.
- I re-ran `flutter devices` and `flutter test test/on_device_inference_service_test.dart`.
- This is a **clarification pass**: model names are now separated by true execution proof vs catalog/surface only.
- I also re-ran on-device-gating tests with `ON_DEVICE_TEST_INSTALL_ATTEMPT=true` and ran a broader provider-key sweep across `/Users/pranay/Projects` for `.env`/`.env.example` to remove stale cross-project assumptions.
- A fresh run in this continuation currently fails at Flutter test compilation due temporary filesystem space exhaustion, so no new real-device install/load/ask proof was produced just now.

## Android / iOS execution environment evidence (this repo)
- `flutter devices` (from `/Users/pranay/Projects/medpiper/insurance_app/mobile`):
  - iPhone 16e simulator, macOS, Chrome. No physical Android/iOS hardware was available.
- Harness evidence now includes:
  - `cd mobile && flutter test test/on_device_inference_service_test.dart`: **3/3 pass** (guard + config fallback behavior).
  - `cd mobile && flutter test -d F5AC13E5-FDAF-4877-B7FF-4265A3180931 --dart-define=ON_DEVICE_TEST_INSTALL_ATTEMPT=true --dart-define=ON_DEVICE_INFERENCE_ENABLED=true --dart-define=ON_DEVICE_MODEL_URL=https://example.com/model.task test/on_device_inference_service_test.dart`: **3/3 pass**.
  - `cd mobile && flutter test test/on_device_inference_service_test.dart --dart-define=ON_DEVICE_TEST_INSTALL_ATTEMPT=true --dart-define=ON_DEVICE_INFERENCE_ENABLED=true --dart-define=ON_DEVICE_MODEL_URL=https://example.com/model.task`: **3/3 pass**.
- implication: even when the harness passes, it remains control-path-only; no real `.task` model install/load/ask run exists in-repo yet.

Evidence file:
- `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26.json`

## Evaluated vs not (strict)
**Rule**: Evaluated = reproducible run output in this repository for that target runtime lane.

### A) Android/iOS-ready local/offline lanes

| Candidate / lane | Status | Why |
|---|---|---|
| `flutter_gemma` + MediaPipe seam | ✅ **Scaffold only** | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`; no real on-device inference run yet |
| `Gemma 3n` E2B / E4B (`.task`) | ❌ Not executed on-device | Candidate only in code/pipeline |
| Gemma 3 270M / 1B | ❌ Not executed on-device | Candidate only |
| Qwen3 0.6B / 1.7B / 4B | ❌ Not executed on-device | Candidate only |
| Phi-4-mini / SmolLM3 / Ministral 3 3B | ❌ Not executed on-device | Candidate only |
| Qwen3-VL 2B / 4B | ❌ Not executed on-device | Candidate as visual-stage fallback only |
| Managed Android (Gemini Nano / AICore) | ❌ Not executed in CoverWise app | Candidate only |
| Managed iOS (Apple Foundation Models) | ❌ Not executed in CoverWise app | Candidate only |
| Transformers.js (WebGPU/ONNX web) | ❌ Not a Flutter-native mobile runtime | No native mobile execution path in app |

### B) Hosted (not mobile/offline) lanes

| Provider / lane | Status | What it provides |
|---|---|---|
| OpenAI `gpt-5-nano` | ✅ Evaluated (synthetic + 52Q held-out) | Hosted grounding baseline for production-safe fallback |
| OpenRouter `google/gemini-2.5-flash-lite`, `google/gemma-3-4b-it` | ✅ Evaluated (synthetic only) | Hosted comparison lane |
| HF Inference (`Qwen/Qwen3-4B-Instruct-2507`) via HF Pro | ✅ Evaluated (synthetic) | Hosted API comparison |
| Ollama (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`, DeepSeek adapter) | ✅ Evaluated | Local desktop/server checks only |
| Modal Labs (`MODAL_*`) | ⚠️ Context only in this repo | Credentials/remote-capability context only; no CoverWise mobile endpoint integration |

### C) Fine-tune / adapter assets

| Lane | Status | Gate |
|---|---|---|
| LoRA/QLoRA/merged adapters | ❌ Not production-integrated | Must show token mapping + base model + tokenizer + quantization + export + mobile artifact hash before routing |

## Stage-wise truth (what has actual proof)
- Parse / text baseline in policy pipeline: tested in server/local evidence artifacts.
- OCR/layout: Surya/desktop checks are present (non-mobile).
- Chunking/reconstruction/retrieval/ hosted rerank: tested in pipeline and policy corpus runs.
- On-device/offline generation, mobile managed runtimes, mobile-local embeddings, and mobile visual-stage candidates: **not yet executed on Android/iOS devices**.

## Provider-key surface sweep (presence-only, no values)

### Keys present in Covered-related project set
- `medpiper/insurance_app`: `OPENAI_API_KEY`, `OLLAMA_BASE_URL` (+ `GROQ_API_KEY` in `.env.example`)
- `orbitcover-d2c`: `OPENROUTER_API_KEY`
- `comfy`: `HF_TOKEN`, `HF_HOME`, `HF_XET_HIGH_PERFORMANCE`, `MODAL_PROFILE`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`
- `speech_experiments/model-lab`: `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `HF_HOME`
- `invoice-intelligence`: `OPENAI_API_KEY`, `OPENROUTER_API_KEY`
- `invoice-intelligence`: `OPENROUTER_BASE_URL` in `.env.example`
- `edureka`: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY`, `HUGGINGFACE_API_KEY`
- `learning_for_kids`: `GEMINI_API_KEY`, `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`
- `adshot`: `HF_TOKEN`, `GEMINI_API_KEY`
- `EchoPanel`: `HF_TOKEN`
- `musicathon`: `HF_TOKEN`
- `bas5minute`: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`
- `SentinelTwin`: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TOGETHER_API_KEY`
- `notes`: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`
- `orbitcover-d2c`: `OPENROUTER_API_KEY`
- `oc-b2b`: `.env.example` includes `HF_TOKEN` and `HUGGINGFACE_HUB_TOKEN` in template form, but no project-local routed mobile model run key is active in `.env`
- `influencer-feature-app` (in `adhoc_projects/`): `OPENROUTER_API_KEY`, `OPENAI_API_KEY`, `HF_TOKEN`
- `LLM/` workspaces and most skill/template folders are API template/experimental envs only and not wired to this mobile decision path.

#### Cross-check for active-only entries

- Active (not commented) key-name presence was re-parsed from each project's `.env` and `.env.example` files before this update, so this list is intentionally strict.
- `orbitcover-d2c` is the concrete OpenRouter-bearing project in this pass.
- `oc-b2b` does not currently contribute usable key surfaces for this decision.

**Interpretation:** key presence in another project does not mean CoverWise can route mobile traffic there.
It only shows where lane testing/research can be run from workspace credentials.

## Why not Transformers.js / Ollama for Android/iOS users
- **Transformers.js**: JavaScript/WebGPU web route, not Flutter-native Android/iOS app runtime.
- **Ollama / desktop local runtimes**: daemon/developer host workflow. Android/iOS users do not install Ollama in this product context.

## Final shortlist (in order)
1. **Keep hosted baseline**: `gpt-5-nano` (currently the only production-grounded anchor with policy-corpus evidence).
2. **Add on-device foundation first**: single first run candidate = `Gemma 3n` through `flutter_gemma` seam + full manifest.
3. **Comparator only after baseline**: one of `Qwen3 1.7B` / `EmbeddingGemma` / `Qwen3-Embedding` after mobile artifact + manifest gates.
4. **Second-stage visual fallback only**: Qwen3-VL / vision candidates if OCR/layout fails.

## 2025–2026 frontier status against this decision pass (from `document_parsers_extractors_catalog_2026_v2.xlsx`)

The full catalog has 73 entries in the parsed frontier slice.

- **2026** (43 models): all are **Catalog-only** for CoverWise Android/iOS local execution in this pass.
- **2025** (30 models): all are **Catalog-only** for CoverWise Android/iOS local execution in this pass.

Priority frontier candidates to evaluate first on mobile once runtime contract is in place:

- `RT-DocLayout`
- `Unlimited-OCR`
- `PaddleOCR-VL-1.6` and `PP-OCRv6`
- `MinerU2.5-Pro`, `Marker`, `Docling`, `MinerU-Popo`, `MinerU-Diffusion`
- `Dolphin-2.0` / `Dolphin-1.5`
- `AgenticOCR`, `Qianfan-OCR`, `Logics-Parsing-Omni`, `GLM-OCR`, `MeDocVL`

## 2) Definitive evaluated vs not matrix (strict mobile decision, policy-RAG lane)

### 2.1 Evidence grade used here

- **EVAL**: reproducible evidence for the exact target runtime/stage.
- **SCaffold**: code integration exists, but no Android/iOS install/load/ask proof.
- **Catalog-only**: shortlisted/researched only.
- **Context-only**: credentials/tooling exists somewhere but no mobile routing evidence.

### 2.2 Model/lane-by-lane truth

| Stage | Model or lane | Runtime target | Status | Evidence / blocker |
|---|---|---|---|---|
| Parse / OCR / layout baseline | `PyMuPDF` + current parser chain | server/local | **EVAL** | Policy corpus runs in server pipeline + 52Q held-out benchmark; not mobile-native. |
| OCR/layout frontier (2025–2026) | `Unlimited-OCR`, `RT-DocLayout`, `Marker 1.10.1`, `MinerU 2.5`, `PaddleOCR-VL`, `Dolphin-2.0`, `Qwen3-VL` etc. | Android/iOS | **Catalog-only** | No on-device mobile execution in this repo in this decision pass. |
| Chunking / reconstruction | paragraph / entity / entity adjacency | server/local | **EVAL** | Existing chunking and pipeline refinements are active and tested on policy corpora. |
| Retrieval / rerank | Hybrid dense + FTS | server/local | **EVAL** | Evidence exists in pipeline docs and policy-corpus run; no mobile device retrieval-stress profile yet. |
| Hosted generation | `gpt-5-nano`, `gemini-2.5-flash-lite`, `google/gemma-3-4b-it`, `Qwen/Qwen3-4B-Instruct-2507` | cloud | **EVAL** | `openai/openrouter/hf` synthetic smoke + policy corpus metrics. |
| Flutter on-device bridge | `flutter_gemma` + MediaPipe | Android/iOS | **SCaffold** | `flutter_gemma` package, `ON_DEVICE_*` defines, and service test harness exist; no real `.task` install/load/ask run. |
| Gemini / Gemma mobile local candidates | `Gemma 3n E2B/E4B`, `Gemma 3 270M / 1B` | Android/iOS | **Catalog-only** | Candidate families only; no exported asset + no runtime execution artifact. |
| Qwen / compact local candidates | `Qwen3 0.6B / 1.7B / 4B`, `Phi-4-mini`, `SmolLM3`, `Ministral 3B` | Android/iOS | **Catalog-only** | No mobile export/runtime proof. |
| VLM visual fallback | `Qwen3-VL`, `PaddleOCR-VL`, `DeepSeek OCR` family | Android/iOS | **Catalog-only** | No visual-stage mobile branch with policy-failure corpus. |
| Managed platform routes | Android AICore / Gemini Nano, iOS Foundation Models | Android/iOS | **Catalog-only** | No in-app hardware capability probe matrix yet. |

### 2.3 Host and infra lane interpretation (for your question about Ollama / MLX / HF / Modal / OpenRouter)

- **OpenAI / OpenRouter / HF Pro**: comparison + fallback lanes for quality/throughput; they are cloud lanes.
- **Modal Labs**: benchmark infrastructure in separate workspace (`comfy`), not a mobile runtime lane.
- **Ollama / desktop local / MLX**: local-server or workstation lanes only; not Android/iOS user-phone runtime in this product path.
- **Transformers.js / web GPU**: browser/mobile-web bridge lane; no Flutter-native Android/iOS app execution path in this repo.

## 3) Android/iOS pipeline decision matrix (who runs where, now)

| Decision axis | Result for this repo (date-stamped 2026-07-25) |
|---|---|
| Can Android/iOS users run local inference today? | **No** (no `.task` install/load/ask evidence on-device). |
| Can we run Hosted `gpt-5-nano` policy queries with ground truth evidence? | **Yes** (`docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json`, `policy-corpus-ragas-2026-07-24.json`). |
| Is there a tested parser/runtime replacement on-device for KVP table/header failures? | **No**; still on server parser path + planned mobile candidates. |
| Is there a fine-tune/LoRA/adapter shipping path for mobile now? | **No**. |

## Evidence references used in this addendum
- `docs/review/mobile_model_execution_ledger_2026-07-24.md`
- `docs/review/mobile_model_exploration_map_2026-07-24.md`
- `docs/technical/mobile_local_model_evaluation_2026-07-24.md`
- `docs/review/mobile_model_decision_sheet_2026-07-24.md`
- `docs/review/mobile_model_full_truth_register_2026-07-24.md`
- `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md`
- `docs/review/mobile_model_general_vlm_frontier_2026-07-24.md`
- Evidence JSON files under `docs/review/evidence/` and `docs/review/evidence/provider-smoke/`

## 4) Concrete frontier shortlist for the next real-device run

This list is pulled from `document_parsers_extractors_catalog_2026_v2.xlsx` and ranked for this decision pass:

### Parse / layout (first to test on-device)
1. `RT-DocLayout`
2. `PaddleOCR-VL-1.6`
3. `PP-OCRv6`
4. `MinerU-Popo`
5. `Marker 1.10.1`
6. `MinerU2.5-Pro`

### Structured extraction recovery (second)
1. `Unlimited-OCR`
2. `AgenticOCR`
3. `Qianfan-OCR`
4. `Logics-Parsing-Omni`
5. `GLM-OCR`
6. `MeDocVL`

### Generation / LLM (run after parser lane stabilizes)
1. `Gemma 3n E2B` (targeted `flutter_gemma` seam first)
2. `Gemma 3 270M` / `1B`
3. `Qwen3 1.7B` (compact comparator)
4. `Qwen3-VL 2B` (visual recovery fallback only)
5. `EmbeddingGemma 308M` + `Qwen3-Embedding 0.6B` as candidate mobile-local retrieval stack

For the complete 73-entry frontier list and stage tags, use:
- `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md`
- `docs/review/mobile_model_frontier_2024_plus_inventory_2026-07-25.md`
