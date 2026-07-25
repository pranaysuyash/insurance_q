# Mobile model key-surface + paid lane inventory (2026-07-26)

Scope: key names observed from project `.env` files under `/Users/pranay/Projects` (values redacted), limited to projects with explicit AI-provider/LMM-related keys and tied to CoverWise mobile model selection. Evidence is from live key-surface scans plus existing proof files in `docs/review`.

## 1) Key-surface scan (cleaned results, no values)

| Project | Keys observed | Mobile-runtime relevance for CoverWise |
|---|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OLLAMA_BASE_URL` (`.env`) ; `GROQ_API_KEY` (`.env.example`) | OpenAI hosted baseline only. `OLLAMA_BASE_URL` indicates desktop/local-server path. No `ON_DEVICE_*` model URL or manifest keys present. |
| `orbitcover-d2c` | `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`, `OPENROUTER_TIER` | OpenRouter paid lane present, but not wired into CoverWise mobile runtime path. |
| `comfy` | `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE` | Modal private-GPU bench lane and HF token infrastructure. Not CoverWise mobile execution lane. |
| `speech_experiments/model-lab` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` | HF infra/lab lane only. |
| `invoice-intelligence` | `OPENAI_API_KEY`; `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` | Hosted lane surface only. |
| `learning_for_kids` | `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`, `GEMINI_API_KEY` | Hosted/experimental lane. |
| `adshot` | `HF_TOKEN`, `HF_TOKEN` (also in `.env.local`), `GEMINI_API_KEY` | Hosted/experimental lane. |
| `bas5minute` | `OPENAI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`, `GEMINI_API_KEY` (example) | Hosted/experimental lane. |
| `edureka` | `OPENAI_API_KEY`, `GROQ_API_KEY`, `HUGGINGFACE_API_KEY`, `GEMINI_API_KEY` | Hosted/experimental lane. |
| `EchoPanel` | `HF_TOKEN` | Hosted/experimental lane. |
| `notes` | `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `OLLAMA_HOST`, `OLLAMA_MODEL` | Cloud + desktop/local-server lane only. |
| `SentinelTwin` | `OPENAI_API_KEY`, `GEMINI_API_KEY` | Hosted/experimental lane. |
| `musicathon` | `HF_TOKEN` | HF experiment lane. |

## 2) Explicit mobile-native model lanes status

- `ON_DEVICE_INFERENCE_ENABLED` / `ON_DEVICE_MODEL_URL` keys were **not found** in the checked project env surfaces.
- No project scan showed a signed `.task` / `.gguf` / `.onnx` / `.tflite` path that is directly bound to CoverWise app's Android/iOS runtime path.
- Therefore:
  - Hosted paid keys (OpenAI / OpenRouter / HF / Modal) are **comparison/computation** assets.
  - CoverWise mobile-native lane remains `flutter_gemma` **scaffold** until Android+iOS install/load/ask telemetry exists.

## 3) What this means for your shortlisted candidates

| Candidate class | Can run on-device Android/iOS today? | Why |
|---|---|---|
| `flutter_gemma` seam (MediaPipe task model path) | **Not yet proven in this repo pass** | Code and tests exist; no real `.task` install/load/ask device evidence. |
| Gemma 3n / Gemma 3/1B / Qwen / Phi / SmolLM / Ministral mobile families | **Catalog-only** | No exported mobile artifact + no install/load/ask proof. |
| Transformers.js web bridges | **No-path for Flutter native** | Browser runtime only in this codebase; no native Android/iOS bridge execution evidence. |
| OpenAI / OpenRouter / HF / Modal | **Hosted** | Active infra and smoke/eval evidence, but not mobile-offline. |

## 4) Evidence anchors tied to this file

- `docs/review/mobile_model_evaluated_vs_not_authority_2026-07-26.md`
- `docs/review/mobile_model_shortlist_truth_and_gaps_2026-07-26.md`
- `docs/review/mobile_model_exploration_map_2026-07-24.md`
- `docs/review/mobile_model_provider_key_inventory_2026-07-25.md`
- `docs/review/evidence/provider-smoke/*.json`
- `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26.json`
