# CoverWise mobile model decision — one-pager (2026-07-24)

This is the quick read for your exact asks: **model list, evaluated vs not, local vs hosted, stage-wise mapping, and fallback shortlist**.

## Quick reality check (non-negotiable)

- We have a local-on-device seam in Flutter (`flutter_gemma` + `flutter_gemma_mediapipe`) with explicit config gating.
- We **do not yet have** Android/iOS device execution evidence for local/offline model inference in this repo pass.
- Evidence of mobile-local runtime comes from tests and code, not from phone runs.
- `flutter test test/on_device_inference_service_test.dart`: **3/3 pass** (off-by-default guard + install guard + install-attempt-path check).  
- `flutter devices` during this pass had **iPhone 17 (simulator), macOS, and Chrome**.  
  There was **no physical Android device** in this run.

## What exists and what was evaluated

### Hosted lanes (used for comparison / benchmark, not mobile-offline)

- `OpenAI gpt-5-nano` (hosted): policy/corpus + synthetic runs present  
- OpenRouter `google/gemini-2.5-flash-lite` (hosted smoke): evaluated  
- OpenRouter `google/gemma-3-4b-it` (hosted smoke): evaluated  
- HF inference (`Qwen/Qwen3-4B-Instruct-2507`) via HF token/credits: evaluated (synthetic smoke)  
- Modal Labs: key surface exists in other projects; no CoverWise mobile on-device execution yet  

### Desktop/local lanes (not Android/iOS app runtime)

- Ollama (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`): tested on synthetic fixture  
- MLX: present in broader codebase for Mac/iOS-style local inference, not shipped as phone model path  
- `DeepSeek-OCR` adapter check: returned empty output (integration incompatibility signal), not production evidence  

### Mobile-native path currently in product code (scaffold only)

- `flutter_gemma` + MediaPipe seam exists in:
  - `mobile/lib/services/on_device_inference_service.dart`
  - `mobile/lib/config/app_config.dart`
- Config requires `ON_DEVICE_INFERENCE_ENABLED=true` + `ON_DEVICE_MODEL_URL=https://...`
- No Android/iOS `.task` artifact run exists yet in this repo session.

## Why this is not a local model list problem

- Android/iOS users do **not** install Ollama.
- Mobile-offline decision = runtime + bridge + export + telemetry + failure policy + fallback logic.
- Hosted APIs (OpenAI/OpenRouter/HF/Modal) are valid comparison lanes but are not local/offline user execution paths.
- `Transformers.js` is a browser/web-stack option only, not Flutter-native Android/iOS inference.

## Pipeline-stage map (what is done vs open)

| Stage | Done | Status | Still open for mobile |
|---|---|---|---|
| Parse / text extraction | PyMuPDF baseline + OCR candidates referenced | ✅ Evaluated in server/local fixtures | Android/iOS parser replacement benchmarking |
| Chunking/reconstruction | Current hybrid chunking route implemented | ✅ Evaluated in policy corpus | Mobile-only tuning |
| Embedding | `text-embedding-3-small` | ✅ Hosted baseline | On-device embedding candidates not yet run |
| Retrieval/rerank | Hybrid dense + rerank tested | ✅ Policy-corpus baseline | Mobile pressure/eviction tests open |
| Hosted generation | OpenAI/OpenRouter/HF smoke + policy 52Q | ✅ Baseline present | On-device generation + local citation drift unknown |
| Local/offline generation | `flutter_gemma` seam exists | ⚠️ Scaffold + guards only | Android/iOS run + telemetry + quality gates |
| Managed native | Gemini Nano / Foundation Models | ❌ Not integrated | Device capability + capability-probe matrix needed |

## 2025–2026 models and status (for mobile decision)

### Shortlist to test first (explicitly mobile-relevant, not SOTA-by-name)

1. **Gemma 3n E2B/E4B** (MediaPipe/LiteRT) — first shared cross-platform lane  
2. **Gemma 3 270M / 1B** — compact text baseline  
3. **Qwen3 1.7B / 4B** — portable alternative with good multilingual structure coverage  
4. **EmbeddingGemma / Qwen3-Embedding family** — local-RAG retrieval stage, then generated text  
5. **Gemma 3n + EmbeddingGemma pair** — first real mobile-RAG experiment (retrieval + grounded answer)

### Phone-architecture fit (what can *actually* run on-device path)

| Candidate / lane | Android | iOS | Execution class | Run evidence in this repo |
|---|---|---|---|---|
| `flutter_gemma` seam (`.task` models) | ⚠️ candidate | ⚠️ candidate | Native runtime bridge (MediaPipe/LiteRT) | **Scaffold + contract tests only** |
| Gemma 3n E2B/E4B | ⚠️ candidate | ⚠️ candidate | Shared native run target | Not run |
| Gemma 3 270M / 1B | ⚠️ candidate | ⚠️ candidate | Shared native run target | Not run |
| Qwen3 0.6B / 1.7B / 4B | ⚠️ candidate | ⚠️ candidate | Portable native export target | Not run |
| Phi-4-mini / SmolLM3 / Ministral 3B | ⚠️ candidate | ⚠️ candidate | Portable native export target | Not run |
| Qwen3-VL 2B / 4B | ⚠️ candidate | ⚠️ candidate | Visual-stage fallback target | Not run |
| Gemini Nano / AICore | ✅ (supported devices only) | ❌ | Android managed native | Not probed |
| Apple Foundation Models | ❌ | ✅ (supported devices only) | iOS managed native | Not probed |
| Transformers.js (WebView/web) | ⚠️ web-only | ⚠️ web-only | Browser runtime, non-Flutter-native | Not run |
| OpenAI / OpenRouter / HF / Modal | N/A | N/A | Hosted API / private GPU | Run, comparison-only |

### Not yet evaluated on device (currently catalog/planned)

- Gemma 3n E2B/E4B  
- Gemma 3 270M/1B  
- Qwen3 0.6B/1.7B/4B  
- Phi-4-mini, SmolLM3 3B, Ministral 3 3B  
- Qwen3-VL 2B/4B (visual stage only)  
- Android Gemini Nano / Apple Foundation Models (no capability probe yet)  
- Docling/MinerU/Marker/RT-DocLayout/Unlimited-OCR/PaddleOCR-VL/Dolphin/AgenticOCR/frontier parser candidates  

## Fallback shortlist right now (practical, not theoretical)

1. **Primary production fallback:** hosted OpenAI path (`gpt-5-nano`) with schema + citation gates  
2. **Comparison lane:** OpenRouter/HF synthetic + held-out comparator runs (routing by provider/fallback policy, with telemetry)  
3. **Local-mobile first lane:** Gemma 3n via `flutter_gemma` (only after signed artifact + device contract + telemetry in place)  
4. **Second stage:** Qwen3-1.7B/4B or managed-native managed-path probes (Nano/Foundation) only after lane-1 passes  

## Provider key surface found (names only, values omitted)

- CoverWise: `OPENAI_API_KEY`, `HF_TOKEN`
- OrbitCover D2C: `OPENROUTER_API_KEY`
- Comfy: `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`
- speech_experiments/model-lab: `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`
- edureka/learning_for_kids/bas5minute/others: additional `OPENAI/HF/GROQ/GEMINI/ANTHROPIC/TOGETHER` keys for research routing, not CoverWise wiring
- `invoice-intelligence`: `OPENAI_API_KEY`, `OPENROUTER_API_KEY`

## Decision you can trust right now

- The explored model shortlist exists.
- The real blocker is **evidence on-device**, not missing ideas.
- Current correct production posture: keep hosted path as default, run a strictly controlled mobile lane in this order:
  1) capability contract, 2) Gemma 3n local lane, 3) citation + schema + telemetry gates, 4) limited comparative lane expansion.

## Source anchors (primary files)

- `docs/review/mobile_model_status_now_2026-07-24.md`
- `docs/review/mobile_model_strict_matrix_2026-07-24.md`
- `docs/review/mobile_model_execution_ledger_2026-07-24.md`
- `docs/review/mobile_model_decision_sheet_2026-07-24.md`
- `docs/review/mobile_model_exploration_map_2026-07-24.md`
- `docs/technical/mobile_local_model_evaluation_2026-07-24.md`
