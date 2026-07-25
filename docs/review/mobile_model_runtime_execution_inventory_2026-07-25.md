# Mobile model runtime execution inventory (2026-07-25)

This file is the single-file “evaluated vs not” sheet for the request in this pass.
It is intended to be the practical companion to:

- [`mobile_model_stage_truth_matrix_2026-07-25.md`](mobile_model_stage_truth_matrix_2026-07-25.md)
- [`mobile_model_full_evaluation_compendium_2026-07-25.md`](mobile_model_full_evaluation_compendium_2026-07-25.md)
- [`mobile_model_frontier_2024_plus_inventory_2026-07-25.md`](mobile_model_frontier_2024_plus_inventory_2026-07-25.md)

## 1) Evidence grade definitions

- **EVAL**: reproducible evidence in-repo with pass/fail + fixture/task outputs.
- **SCaffold**: code integration exists, but no Android/iOS install/load/ask proof.
- **Catalog-only**: researched/shortlisted, not executed as a mobile-runtime lane.
- **Hosted-only**: cloud API/inference lane, not local/offline Android/iOS execution.

## 2) Evaluated in this repository (with evidence)

### 2.1 Generation providers (policy / synthetic)

| Lane | Runtime target | Status | Evidence | Notes |
|---|---|---|---|---|
| OpenAI `gpt-5-nano` (`gpt-5-nano-2025-08-07`) | Hosted API | **EVAL** | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json` (+ continuation file) | 3/3 passes; median 1237 ms; continuation 3/3 median 1619 ms. |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted API | **EVAL (limited)** | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json` (+ continuation) | 2/3 passes; median 746 ms (continuation 1025 ms). |
| OpenRouter `google/gemma-3-4b-it` | Hosted API | **EVAL (limited)** | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | 1/3 pass (limited comparator). |
| HF Inference (`Qwen/Qwen3-4B-Instruct-2507`, HF Pro credits) | Hosted API | **EVAL (limited)** | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json` (+ continuation) | 2/3 passes; median 1173 ms (continuation 1026 ms). |
| Policy corpus + RAG quality (`52` questions) | Hosted pipeline | **EVAL** | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | Accuracy `0.5577`, citation rate `0.9615`, hallucination rate `0.3333`, faithfulness `0.8368`, context precision `0.4558`, relevancy `0.7148`. |

### 2.2 Mobile on-device seam + test harness

| Lane | Runtime target | Status | Evidence | Notes |
|---|---|---|---|---|
| `flutter_gemma` service + config gates (`ON_DEVICE_INFERENCE_ENABLED`, `ON_DEVICE_MODEL_URL`) | Android/iOS native bridge | **SCaffold** | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`, `mobile/lib/main.dart`, `mobile/test/on_device_inference_service_test.dart` | Guard test exists; no real install/load/ask run executed on device. |

### 2.3 Mobile/native non-LLM runtime proof

| Lane | Runtime target | Status | Notes |
|---|---|---|---|
| Android/iOS OCR/layout helpers (ML Kit/native/mobile OCR path) | Android/iOS | **Catalog-only / pipeline-in-progress** | No dedicated proof run in this decision pass. |

### 2.4 Latest verification attempts (2026-07-25)

| Command | Result | Evidence implication |
|---|---|---|
| `cd mobile && flutter pub get && flutter test test/on_device_inference_service_test.dart` | **3/3 pass** (host-only + control-path) | Guard behavior is verified and currently re-runnable without a fresh-space-related block in recent continuation. |
| `cd mobile && flutter devices --machine` | `iPhone 17` simulator, `macOS`, and `Chrome` entries are detected | Runtime endpoints are available for run-path targeting. |
| `cd mobile && flutter test -d F5AC13E5-FDAF-4877-B7FF-4265A3180931 --dart-define=ON_DEVICE_TEST_INSTALL_ATTEMPT=true --dart-define=ON_DEVICE_INFERENCE_ENABLED=true --dart-define=ON_DEVICE_MODEL_URL=https://example.com/model.task test/on_device_inference_service_test.dart` | **3/3 pass** | Confirms install-attempt path is reachable under configured device flags and fails fast when using synthetic URL, proving control-path and contract coverage under iOS simulator. This is **not** real `.task` download/load/ask success proof. |
| `df -h /var/folders /tmp` | `/` currently shows ~63GB free in this continuation; `/var/folders` and `/tmp` remain the paths most sensitive to Flutter temp usage | Storage appears healthy for short runs, but long matrix runs should still recheck these paths before large model-device experiments. |

## 3) Mobile/offline lanes: evaluated vs not

### 3.1 Flutter-native mobile candidates (Android + iOS)

| Candidate | Pipeline role | Status | Why this is only this status |
|---|---|---|---|
| `flutter_gemma` + MediaPipe `.task` seam | shared on-device generation path | **SCaffold** | Seam exists, no runnable `.task` artifact + install/load/ask evidence. |
| Gemma 3n E2B / E4B | primary local model lane | **Catalog-only** | No on-device artifact or run in-repo. |
| Gemma 3 270M / 1B | compact local lane | **Catalog-only** | No export/benchmark on Android/iOS yet. |
| Qwen3 0.6B / 1.7B / 4B | local compare lane | **Catalog-only** | No mobile export + no on-device benchmark. |
| Phi-4-mini / SmolLM3 / Ministral 3B | secondary local compare | **Catalog-only** | No mobile artifact + no run. |
| Qwen3-VL 2B / 4B and PaddleOCR-VL as visual recovery | visual recovery fallback | **Catalog-only** | No Android/iOS recovery branch with image-stage evidence. |
| Ollama desktop models (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`, etc.) | server/dev convenience | **Not mobile** | This is desktop/server execution only. |

### 3.2 Managed runtime candidates (platform native, not custom model bundle)

| Candidate | Platform | Status | Why not yet promoted |
|---|---|---|---|
| Android Gemini Nano / AICore | Android managed | **Catalog-only** | No in-app probe + no support matrix in this pass. |
| Apple Foundation Models | iOS managed | **Catalog-only** | No in-app probe + no OS-version/device matrix in this pass. |

### 3.3 Transformer.js / browser path

| Option | Runtime | Status | Why |
|---|---|---|---|
| Transformers.js / WebGPU / ONNX path | mobile-web/WebView | **Not Flutter-native mobile lane** | Useful as separate web/mobile-web experiment, not Android/iOS local product path in CoverWise Flutter app. |

## 4) Front-end parsing/OCR frontier (2024+) status against mobile decision

All frontier entries (including requested newer candidates such as **Unlimited-OCR**, **RT-DocLayout**, **Infinity-Parser2**, **Marker 1.10.1**, **MinerU* / DeepSeek-VLM / HunyuanOCR / PaddleOCR-VL / dots.ocr / GLM-OCR** etc.) are `Catalog-only` for CoverWise mobile execution in this pass.

- Full catalog list: [`mobile_model_catalog_2025_2026_2026-07-24.md`](mobile_model_catalog_2025_2026_2026-07-24.md)
- Shortlisted status list (2024+): [`mobile_model_frontier_2024_plus_inventory_2026-07-25.md`](mobile_model_frontier_2024_plus_inventory_2026-07-25.md)

## 5) Paid infra / key surface (what exists vs what is routed here)

### 5.1 Covered by this request context

| Project | Key names found | In-scope routing to CoverWise mobile |
|---|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OLLAMA_BASE_URL`, `GROQ_API_KEY`, `GROQ_CHAT_MODEL` | OpenAI and local-server lanes are active in backend logic; no active on-device model URL/flag for production on-device runtime in checked `.env` state. |
| `orbitcover-d2c` | `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`, `OPENROUTER_TIER` | OpenRouter compare lane only; not wired into CoverWise mobile route. |
| `comfy` | `HF_TOKEN`, `HF_HOME`, `HF_XET_HIGH_PERFORMANCE`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE` | HF/Modal benchmark infra; not CoverWise mobile routing. |
| `speech_experiments/model-lab` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `HF_HOME` | HF local bench/proxy route; not CoverWise mobile routing. |
| `learning_for_kids` | `GEMINI_API_KEY`, `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN` | Hosted benchmarks only. |
| `adshot`, `EchoPanel`, `edureka`, `bas5minute`, `invoice-intelligence`, influencer projects | hosted keys present | Hosted/benchmark projects; no CoverWise on-device mobile wiring in this pass. |

### 5.2 Important key-state correction

- There is **no active `ON_DEVICE_INFERENCE_ENABLED` / `ON_DEVICE_MODEL_URL` path in checked CoverWise app env files** that points to a shipped `.task` artifact. Without that, on-device execution remains scaffold-only even though code hooks exist.

## 6) Fine-tune / adapter/lora status

- **LoRA / QLoRA / PEFT / merged adapters**: `Not wired` in CoverWise mobile route.
- Reasons: no adapter manifest (tokenizer/model version/hash/quantization), no merge policy, no artifact packaging, no Android/iOS benchmark manifest.

## 7) Direct short-list (where to spend the next eval budget)

1. **Execute first real mobile lane**: `flutter_gemma` with signed `.task` artifact, Android + iOS install/load/ask proof.
2. Capture and log:
   - install success/failure class
   - load latency
   - ask latency p50/p95
   - memory/RSS trend
   - timeout/cancellation behavior
   - unsupported-device fallbacks
3. Then run compact local comparator (`Gemma 3 270M/1B` vs `Qwen3 1.7B`) on same matrix.
4. Add managed-native probes after local-lane gates (`Gemini Nano/AICore`, `Apple Foundation Models`).
5. Only then move frontier heavy parsers (`Unlimited-OCR`, `RT-DocLayout`, `MinerU*`, `PaddleOCR-VL`) into execution matrix if OCR failure thresholds justify.

## 8) "Why no Android/iOS users install Ollama / MLX / Transformers.js in this path"

- **Ollama/MLX**: workstation/server runtimes, not Flutter production mobile runtime in this product path.
- **Transformers.js/WebGPU**: browser/mobile-web experiments, not the same native Android/iOS product runtime.
- **HF Pro / OpenRouter / Modal / OpenAI keys**: paid infrastructure and comparison or fallback lanes, not phone-local model execution unless a separately packaged mobile artifact is added and executed.

### Runtime platform availability observed in this pass

- `flutter devices --machine` output shows iOS simulator + macOS + Chrome.
- `android` device entries = `0` in this pass (no physical Android target attached).
- Practical implication: full mobile completion still requires at least one `android` and one supported `ios` device run for install/load/ask telemetry.

## 9) Continuation refresh (2026-07-25 19:20 IST)

### What was actually done since the previous truth snapshot

- Re-ran the provider and policy-corpus smoke/eval checks; updated evidence pointers remain valid:
  - OpenAI and provider continuations in `docs/review/evidence/provider-smoke/*-2026-07-25.json`
  - Policy corpus RAGAS output in `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json`
- Re-checked mobile runtime reachability:
  - `cd mobile && flutter devices --machine`
  - Result: iPhone 17 simulator present (`F5AC13E5-FDAF-4877-B7FF-4265A3180931`) with `macOS` + `Chrome`; no physical Android/iOS local model run.
- Re-ran on-device service test in harness mode:
  - `cd mobile && flutter test -d F5AC13E5-FDAF-4877-B7FF-4265A3180931 --dart-define=ON_DEVICE_TEST_INSTALL_ATTEMPT=true --dart-define=ON_DEVICE_INFERENCE_ENABLED=true --dart-define=ON_DEVICE_MODEL_URL=https://example.com/model.task test/on_device_inference_service_test.dart`
  - Result: assertion path reached and install call flow is exercised under test, but **no production-like task artifact install/load/ask success trace exists yet**.

### What is and is not complete (as of latest run)

- `evaluated`: evidence-backed provider smoke, policy-corpus RAGAS, and on-device harness control-path test.
- `not evaluated`: artifact install/load/ask on-device, battery/thermal profile, and cross-device fallback matrix.

### Current hard gap (not reclassifiable as evaluated)

- No end-to-end Android/iOS local LLM run has been completed in this pass (no real `.task` download/install/load/ask success proof on device).
- `ON_DEVICE_*` is still not wired to a shipping artifact URL/manifest in active CoverWise app env files.
- Local runtime confidence for this lane remains `SCaffold` until we complete a signed `.task` install/load/ask matrix with memory/latency/cancel/retry evidence.

### Current disk/runtime constraint

- `/tmp`/workspace pressure can spike on long mobile runs; periodic recheck is still required before large model-device matrix execution.


## 10) Latest direct execution evidence (2026-07-25 19:44 IST)

- `cd mobile && flutter devices --machine` now shows `iPhone 17` simulator (`F5AC13E5-FDAF-4877-B7FF-4265A3180931`), `macOS`, `Chrome`.
- `cd mobile && flutter test -d F5AC13E5-FDAF-4877-B7FF-4265A3180931 --dart-define=ON_DEVICE_TEST_INSTALL_ATTEMPT=true --dart-define=ON_DEVICE_INFERENCE_ENABLED=true --dart-define=ON_DEVICE_MODEL_URL=https://example.com/model.task test/on_device_inference_service_test.dart`
  - Historical logs show the install path was reached and unsupported/non-production config was rejected in test runtime.
- Latest continuation is a **pass** on iPhone 17 simulator for control-path reachability; next target is real `.task` install/load/ask.
  - Result is still **not** a production `.task` install/load/ask success trace on device.
