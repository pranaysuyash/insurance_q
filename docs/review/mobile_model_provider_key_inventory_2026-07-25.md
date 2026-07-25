# CoverWise mobile-model provider and key-surface inventory (2026-07-25)

Scope:
- Selected local and adjacent projects that contain provider-key surfaces relevant to model execution strategy.
- Evidence-only inventory: presence of configuration keys does not imply that model/path is active in `medpiper/insurance_app` mobile runtime.
- Dates and status are from an evidence-only pass executed during this continuation.

## 1) Env-surface matrix (relevant projects)

| Project | OpenAI | OpenRouter | Hugging Face | Modal | Groq | Gemini | Ollama/Local | Transformers.js / web runtime | Flutter-device flags | Fine-tune / adapter markers |
|---|---|---|---|---|---|---|---|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL` | — | — (no set HF token key in active file set) | — | `GROQ_API_KEY` (example/commented; `GROQ_BASE_URL`, `GROQ_CHAT_MODEL`) | — | `OLLAMA_BASE_URL` | — | `ON_DEVICE_*` not present in scanned `.env` files | none found |
| `orbitcover-d2c` | — | `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` | — | — | — | — | — | — | — | none found |
| `comfy` | — | — | `HF_TOKEN` | `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` | — | — | — | — | — | none found |
| `speech_experiments/model-lab` | — | — | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` | — | — | — | — | — | — | none found |
| `invoice-intelligence` | `OPENAI_API_KEY` | `OPENROUTER_API_KEY` | — | — | — | — | — | — | — | none found |
| `learning_for_kids` | — | — | `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN` | — | — | `GEMINI_API_KEY` | — | `VITE_AI_LLM_PROVIDER` family appears in project-level example file set | — | none found |
| `adshot` | — | — | `HF_TOKEN` | — | — | `GEMINI_API_KEY` | — | — | — | none found |
| `notes` | `OPENAI_API_KEY` | — | — | — | — | `GOOGLE_API_KEY` (SDK-style) | `OLLAMA_HOST`, `OLLAMA_MODEL` | — | — | none found |
| `EchoPanel` | — | — | `HF_TOKEN` | — | — | — | — | — | — | none found |
| `bas5minute` | `OPENAI_API_KEY` | — | `HF_TOKEN`, `HUGGINGFACE_API_KEY` | — | — | `GEMINI_API_KEY` | — | — | — | none found |
| `edureka` | `OPENAI_API_KEY` | — | `HUGGINGFACE_API_KEY` | — | `GROQ_API_KEY` | `GEMINI_API_KEY` | — | — | — | none found |
| `SentinelTwin` | `OPENAI_API_KEY` | — | — | — | — | `GEMINI_API_KEY` | — | — | — | none found |

## 2) What this means for Android/iOS decisioning

- **Host/proxy keys are broad and cross-project.** They indicate possible lanes, not mobile product execution in CoverWise.
- **Confirmed mobile-native code seam in CoverWise** remains `flutter_gemma` + `flutter_gemma_mediapipe` behind `ON_DEVICE_INFERENCE_ENABLED` and HTTPS `.task` URL. This is present in code but still scaffold until a device install/load/ask run exists.
- **No fine-tuned / LoRA / adapter checkpoints** were found in scanned env surfaces for this lane.
- **Transformers.js** flags are not present in CoverWise app env and are effectively in the web-frontier space for this codebase.

## 3) Cross-project paid API lane reality (present now vs active in CoverWise)

| Lane | Capability observed | Presence in CoverWise mobile runtime | Evidence file |
|---|---|---|---|
| OpenAI `gpt-5-nano` | present (api key + models in app settings) | Indirect via backend/hosted flow | `src/config/settings.py`, `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`, `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json` |
| OpenRouter | present in other project (`orbitcover-d2c`) only | Not wired in CoverWise app config or service layer | `orbitcover-d2c/.env`, `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json` |
| HF Inference (HF Pro route) | HF token exists in separate projects; one active run uses `comfy` token |
| Modal Labs | tokens present in `comfy` | Not part of CoverWise app path yet | `comfy/.env`, no CoverWise mobile endpoint evidence |
| Ollama / MLX | present as local fallback models in backend settings | Not Android/iOS user-phone runtime | `src/config/settings.py` |

## 4) Fresh run outputs recorded in this continuation

- `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json`
  - OpenAI (`gpt-5-nano`) `3/3` pass (`1.0` schema+grounding), median 1619 ms
- `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json`
  - OpenRouter (`google/gemini-2.5-flash-lite`) `2/3` pass (`0.667`), median 1025 ms
- `docs/review/evidence/provider-smoke/continuation-hf-2026-07-25.json`
  - HF Pro (`Qwen/Qwen3-4B-Instruct-2507`) `2/3` pass (`0.667`), median 1026 ms

## 5) Required interpretation for the architecture decision set

- These are **comparison or infrastructure lanes** unless paired with a concrete on-device artifact + install/load/ask instrumentation for Android/iOS.
- The phone-lane shortlist remains: `flutter_gemma` seam first (`ON_DEVICE_*` + `.task`), then compact comparative checkpoints (`Gemma 3 270M /1B`, `Qwen3 1.7B`, etc.) once artifact and device telemetry are in place.

## 6) Focused cross-project env key scan (this continuation)

Observed from `.env` / `.env.example` / `.env.local` files (active project list):

- `medpiper/insurance_app`: `OPENAI_KEY` family active, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL` active; `ON_DEVICE_*` only absent/commented; `OLLAMA_BASE_URL` present.
- `orbitcover-d2c`: `OPENROUTER_API_KEY` + `OPENROUTER_BASE_URL` active.
- `comfy`: `HF_TOKEN` + `HF_HOME` active, `MODAL_TOKEN_ID`/`MODAL_TOKEN_SECRET` active.
- `invoice-intelligence`: `OPENAI_API_KEY` and `OPENROUTER_API_KEY`/`OPENROUTER_BASE_URL` active.
- `edureka`: `OPENAI_API_KEY`, `GROGG?` no, `GROQ_API_KEY`, `HUGGINGFACE_API_KEY`, `GEMINI_API_KEY` active.
- `learning_for_kids`: `GEMINI_API_KEY`, `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN` active.
- `adshot`: `HF_TOKEN`, `GEMINI_API_KEY` active.
- `EchoPanel`: `HF_TOKEN` active.
- `bas5minute`: `OPENAI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`, `GEMINI_API_KEY` active.
- `SentinelTwin`: `OPENAI_API_KEY`, `GEMINI_API_KEY` active.
- `notes`: `OPENAI_API_KEY`, `OLLAMA_HOST`, `OLLAMA_MODEL` active.

Notes:
- This confirms the cross-project key surface is **broader** than in CoverWise but still does not include any shipped on-device model artifact references.
- `ON_DEVICE_*` in this key-surface pass is effectively absent in active app envs, so any on-device execution still requires build-time defines to be explicitly supplied in runtime launch.
