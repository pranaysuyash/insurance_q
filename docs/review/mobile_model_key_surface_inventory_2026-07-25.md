# Mobile model key-surface inventory (active vs commented/template)

Date: 2026-07-25  
Scope: `.env` and `.env.example` files checked across selected projects under `/Users/pranay/Projects`.

Legend:
- **ACTIVE** = key assignment line is uncommented.
- **COMMENTED** = key appears only in comments/examples.
- **Routing impact** means whether the key contributes to the CoverWise mobile model decision path in this pass.

## 1) CoverWise project (`medpiper/insurance_app`)

### `medpiper/insurance_app/.env`

| Key | State |
|---|---|
| `OLLAMA_BASE_URL` | ACTIVE |
| `OPENAI_API_KEY` | ACTIVE |
| `OPENAI_CHAT_MODEL` | ACTIVE |
| `OPENAI_EMBEDDING_MODEL` | ACTIVE |
| `GROQ_API_KEY` | COMMENTED |
| `HF_TOKEN` | COMMENTED |
| `ON_DEVICE_INFERENCE_ENABLED` | COMMENTED |
| `ON_DEVICE_MODEL_URL` | COMMENTED |

### `medpiper/insurance_app/.env.example`

| Key | State |
|---|---|
| `GROQ_API_KEY` | ACTIVE |
| `GROQ_BASE_URL` | ACTIVE |
| `GROQ_CHAT_MODEL` | ACTIVE |
| `OLLAMA_BASE_URL` | ACTIVE |
| `OPENAI_API_KEY` | ACTIVE |
| `OPENAI_CHAT_MODEL` | ACTIVE |
| `OPENAI_EMBEDDING_MODEL` | ACTIVE |

### Routing impact (CoverWise mobile)

- Active OpenAI + local-server knobs are present.
- No active `ON_DEVICE_INFERENCE_ENABLED` + `ON_DEVICE_MODEL_URL` pair is present in checked files.
- On-device mobile inference therefore remains **scaffold-only** until a valid artifact URL and install/load runtime evidence are provided.

## 2) Cross-project hosted-compare surface (what can support benchmark lanes)

### `orbitcover-d2c/.env`, `orbitcover-d2c/.env.example`

| Key | State |
|---|---|
| `OPENROUTER_API_KEY` | ACTIVE |
| `OPENROUTER_BASE_URL` | ACTIVE |
| `OPENROUTER_TIER` | ACTIVE |

**Routing impact:** benchmark/fallback lane only; no CoverWise mobile bridge wiring in this pass.

### `comfy/.env`, `comfy/.env.example`

| Key | State | File(s) |
|---|---|---|
| `HF_HOME` | ACTIVE | both |
| `HF_TOKEN` | ACTIVE | both |
| `HF_XET_HIGH_PERFORMANCE` | ACTIVE | both |
| `MODAL_PROFILE` | ACTIVE | both |
| `MODAL_TOKEN_ID` | ACTIVE | both |
| `MODAL_TOKEN_SECRET` | ACTIVE | both |

**Routing impact:** Modal/HF infrastructure and private GPU benchmark lane; not an Android/iOS user runtime in this repo.

### `invoice-intelligence/.env`, `.env.example`

| Key | State |
|---|---|
| `LLAMA_CLOUD_API_KEY` | ACTIVE (example) |
| `OPENAI_API_KEY` | ACTIVE |
| `OPENROUTER_API_KEY` | ACTIVE (example) |
| `OPENROUTER_BASE_URL` | ACTIVE (example) |

**Routing impact:** hosted comparison / API exploration only.

### `speech_experiments/model-lab/.env`, `.env.example`

| Key | State |
|---|---|
| `HF_TOKEN` | ACTIVE |
| `HUGGINGFACE_HUB_TOKEN` | ACTIVE |
| `HF_HOME` | ACTIVE |

**Routing impact:** hosted/prototype lane; not CoverWise mobile routing.

### `edureka/.env`

| Key | State |
|---|---|
| `OPENAI_API_KEY` | ACTIVE |
| `GEMINI_API_KEY` | ACTIVE |
| `GROQ_API_KEY` | ACTIVE |
| `HUGGINGFACE_API_KEY` | ACTIVE |

## 3) Additional active provider/key surface found in this scan

### `learning_for_kids/.env`

| Key | State |
|---|---|
| `GEMINI_API_KEY` | ACTIVE |
| `HF_TOKEN` | ACTIVE |
| `HUGGINGFACEHUB_API_TOKEN` | ACTIVE |

### `adshot/.env`, `.env.local`

| Key | State |
|---|---|
| `GEMINI_API_KEY` | ACTIVE |
| `HF_TOKEN` | ACTIVE |

### `bas5minute/.env.local`, `.env.example`

| Key | State |
|---|---|
| `ANTHROPIC_API_KEY` | ACTIVE |
| `OPENAI_API_KEY` | ACTIVE |
| `HF_TOKEN` | ACTIVE |
| `GEMINI_API_KEY` | ACTIVE |
| `HUGGINGFACE_API_KEY` | ACTIVE |

### `SentinelTwin/.env`

| Key | State |
|---|---|
| `OPENAI_API_KEY` | ACTIVE |
| `GEMINI_API_KEY` | ACTIVE |
| `TOGETHER_API_KEY` | ACTIVE |

### `notes/.env`

| Key | State |
|---|---|
| `OPENAI_API_KEY` | ACTIVE |
| `ANTHROPIC_API_KEY` | ACTIVE |
| `GOOGLE_API_KEY` | ACTIVE |

### `musicathon/.env`, `.env.example`

| Key | State |
|---|---|
| `HF_TOKEN` | ACTIVE |

### `EchoPanel/.env`

| Key | State |
|---|---|
| `HF_TOKEN` | ACTIVE |

### `oc-b2b/.env.example`

| Key | State |
|---|---|
| `HF_TOKEN` | ACTIVE (template) |
| `HUGGINGFACE_HUB_TOKEN` | ACTIVE (template) |

### `influencer-feature-app` (in `adhoc_projects/`)

| Key | State |
|---|---|
| `HF_TOKEN` | ACTIVE |
| `OPENAI_API_KEY` | ACTIVE |
| `OPENROUTER_API_KEY` | ACTIVE |

## 4) What this inventory does and does not mean

- **Presence is not execution proof.** A key in `.env` means the lane can be used by that project’s environment, not that CoverWise users execute there.
- **Transformers.js / WebGPU / ONNX-Web** do not appear as active CoverWise mobile product paths in these files.
- **Ollama / local server keys** (e.g., `OLLAMA_BASE_URL`) represent local/desktop inference workflows, not Android/iOS user runtime paths.
- **Modal/HF/OpenAI/OpenRouter keys** here indicate hosted/infrastructure capability and benchmark flexibility, not phone-side model execution unless an on-device artifact contract is present.
- **Fine-tune / adapter lane:** no project key-surface block above contains a complete artifact lineage (base model + tokenizer + quantization + adapter merge metadata + platform `.task`/gguf/tflite manifest for mobile routing).

## 5) Current status to carry into execution planning

- **Scaffold-only mobile-native lane:** `flutter_gemma` + `ON_DEVICE_*` controls in CoverWise code.
- **Next hard gate to move to evaluated mobile lane:** provide a signed `.task` artifact and complete Android+iOS install/load/ask telemetry.
- **Immediate benchmark lanes (hosted, not mobile):** OpenAI, OpenRouter, HF Pro remain valid for comparison and fallback, not Android/iOS local inference by themselves.

