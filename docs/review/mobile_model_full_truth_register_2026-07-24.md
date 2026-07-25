# Mobile model truth register (what was explored vs not explored)

## Scope and evidence rule

- Date: **2026-07-24**
- Scope: Android/iOS execution posture for CoverWise policy Q&A/document handling plus paid/API benchmark lanes used for comparison.
- **Evaluated** = reproducible run output in repo evidence for that stage/runtime path.
- **Catalog-only** = considered + documented, no execution in repo for that stage/runtime.
- **Scaffold-only** = integration/capability code exists, no Android/iOS run.
- **Hosted-only** = API path (OpenAI/OpenRouter/HF/Modal), no local/offline user execution.

## 1) What exists in this repo for each lane

| Lane / model family | Type | Android/iOS execution status (this repo) | Evidence in repo | Why this matters |
|---|---|---|---|---|
| OpenAI `gpt-5-nano` direct | Hosted API (cloud) | ❌ not local/offline | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json` (3/3), `.../openai-synthetic-2026-07-24-final.json`, `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | Strongest backend baseline for grounded policy answers in production contract |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted API | ❌ not local/offline | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json` (2/3) | Useful comparison route, not mobile runtime default |
| OpenRouter `google/gemma-3-4b-it` | Hosted API | ❌ not local/offline | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` (1/3) | Useful comparison route, not mobile runtime default |
| HF Inference (`Qwen/Qwen3-4B-Instruct-2507`) via HF Pro | Hosted API | ❌ not local/offline | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json` (2/3) | Useful benchmark lane when HF credits are available |
| Modal Labs (`MODAL_TOKEN_*`) | Private cloud/private GPU | ❌ not local/offline in CoverWise mobile path | Key surface discovered in Comfy; no CoverWise app lane evidence | Good for benchmark/offline research, not Android/iOS runtime |
| `flutter_gemma` + `flutter_gemma_mediapipe` | Mobile local seam | ⚠️ scaffold-only | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`, `flutter test test/on_device_inference_service_test.dart` | Integration exists; no on-device model execution yet |
| Gemma 3n E2B/E4B (`.task`) | Mobile/offline candidate | ❌ not run | Catalog + lane doc references | Candidate only until artifact export + phone runs |
| Gemma 3 270M / 1B | Mobile/offline candidate | ❌ not run | Architecture notes and candidate register | Candidate only |
| Qwen3 0.6B / 1.7B / 4B | Mobile/offline candidate | ❌ not run | Candidate register + hosted smoke context for Qwen3-4B | Candidate only |
| Phi-4-mini / SmolLM3 3B / Ministral 3B | Mobile/offline candidate | ❌ not run | Candidate register | Candidate only |
| Qwen3-VL 2B/4B (visual stage) | Mobile/offline candidate | ❌ not run | VLM frontier register + general doc | Candidate only; second-stage visual recovery only |
| Gemini Nano / AICore | Platform managed Android | ❌ not probed in CoverWise | Not implemented/integrated in app | Managed path exists in ecosystem; needs device capability matrix + fallback policy |
| Apple Foundation Models | Platform managed iOS | ❌ not probed in CoverWise | Not implemented/integrated in app | Managed path exists in ecosystem; needs iOS support + prompt regression |
| Transformers.js (WebGPU/ONNX) | Web/mobile-web | ⚠️ not in Flutter-native path | No mobile-web bridge execution evidence in CoverWise | Valid separate research lane, not Flutter native mobile model path |
| Ollama (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`) | Desktop local | ❌ no Android/iOS app runtime | `docs/review/evidence/local-model-eval/gemma3-12b-2026-07-12.json`; `.../gemma3-4b-recheck-2026-07-12.json`; `.../deepseek-ocr-diagnostic-2026-07-12.json` | Desktop benchmark evidence only; user does not install Ollama on phone |
| Docling / Marker / MinerU / RT-DocLayout / Unlimited-OCR / PaddleOCR-VL / Dolphin / AgenticOCR / Logics-Parsing / Qianfan / etc. | Parser frontier | ❌ | `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md` | Very relevant to OCR/layout failures but not executed on device in this repo |
| Fine-tuned / adapter assets (LoRA/QLoRA/merged checkpoints) | Data-layer and asset readiness | ⚠️ no production-ready asset lineage wired | Not present in model-run lane | Must include tokenizer, rank, quantization, export hash, and device validation before routing |

## 2) Pipeline-stage truth (what is proven)

| Pipeline stage | What is evaluated in repo evidence | Open gaps |
|---|---|---|
| Parse / text extraction | Canonical server text path used in policy runs (PyMuPDF + text layout utilities) | No native Android/iOS parser benchmark in app |
| OCR / layout | Surya-2 + docTR server/local checks; limited synthetic checks | No Android/iOS OCR/layout model execution claims |
| Reconstruction / chunking | Hosted corpus chunking pipeline evaluated in policy run | Mobile-only reconstruction tuning and memory behavior not run |
| Embeddings | Hosted `text-embedding-3-small` path evaluated on corpus | On-device embedding lanes not run (`EmbeddingGemma`, `Qwen3-Embedding`) |
| Retrieval + rerank | Hybrid dense+rerank with evidence-backed corpus path | Mobile-only stress on cancellation/eviction/timeouts not run |
| Hosted generation | OpenAI/OpenRouter/HF synthetic + held-out policy metrics available | Mobile/offline generation behavior not yet measured |
| Local/offline generation | `flutter_gemma` seam + guards verified by test only | No Android/iOS model run; no latency/thermal/battery/citation telemetry yet |
| Managed platform generation | Native OS models not integrated | No capability probes, unsupported-device fallback map absent |

## 3) Provider/key surface relevant to this decision

| Project | Relevant key names (present in env files) | What it means in this lane |
|---|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `HF_TOKEN` | OpenAI is existing backend lane; HF token is not local model execution on-device by itself |
| `orbitcover-d2c` | `OPENROUTER_API_KEY` | Useful for OpenRouter benchmarking comparison lane |
| `comfy` | `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` | Useful for Modal/benchmark research, not direct CoverWise policy routing yet |
| `speech_experiments/model-lab` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` | Useful for HF research workflows, not CoverWise mobile lane |
| Other projects (`edureka`, `learning_for_kids`, `adshot`, `bas5minute`, etc.) | mixed `HF_*`, `GEMINI`, `OPENAI`, `GROQ`, `ANTHROPIC` | Relevant for future research candidates, not active CoverWise routing |

## 4) Shortlist now (shortlist rationale, not final production claims)

1. **Keep hosted baseline**: OpenAI gpt-5-nano as the canonical, production-safe grounding lane (existing citation/schema controls + policy evidence).
2. **Run one true mobile-native lane first**: Gemma 3n family through the existing `flutter_gemma` seam, after:
   - model artifact + tokenizer + conversion hash,
   - capability contract + feature gating,
   - Android/iOS device benchmarks (download integrity, cold/warm latency, RSS, thermal, timeout/cancel/retry behavior).
3. **Only after pass**, evaluate compact comparators:
   - Gemma 3 270M/1B and Qwen3 1.7B/4B for task quality/latency tradeoff,
   - managed native probes (Gemma Nano/AICore, Foundation Models) with supported/unsupported-device matrix.
4. **Second-stage visual fallback (if needed)**: Qwen3-VL / docVLM candidates only on OCR/layout recovery failure pages.

## 5) Why some requests are valid but not final yet

- **Android/iOS users do not install Ollama**: it is a desktop/workstation runtime.
- **Transformers.js is not Flutter-native Android/iOS local runtime**: browser/WebView scope.
- **HF Pro / Modal / OpenRouter keys are not mobile-local guarantees**: these are evaluation or hosted comparison lanes unless explicitly converted to device-ready assets and exported executables.

## 6) Latest run artifacts captured now (and prior run delta)

- `cd mobile && flutter test test/on_device_inference_service_test.dart`  
  **3/3 pass** (guard + install guard + install-attempt-path check with continuation flag).
- `cd mobile && flutter devices`  
  Latest run evidence: iPhone 17 simulator (`iOS`), `macOS`, and `Chrome` were discovered.
  Prior line about macOS+Chrome only is superseded by this 2026-07-25 evidence.

## 7) Cross-project provider-key inventory (as discovered from `.env` surfaces)

| Project | Provider/model keys found | Impact on model decision |
|---|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `HF_TOKEN`, `OLLAMA_BASE_URL`, `GROQ_API_KEY` | Confirms backend-hosted evaluation lanes + local Ollama endpoints exist as code paths. No OpenRouter/Gemini/AICore/Foundation model key for CoverWise runtime. |
| `orbitcover-d2c` | `OPENROUTER_API_KEY` | Relevant for hosted OpenRouter comparison only, unless explicitly integrated into CoverWise mobile. |
| `comfy` | `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE` | Modal/HF key surface exists for benchmark/offline research lanes. Not wired into CoverWise mobile runtime path. |
| `speech_experiments/model-lab` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` | Useful for HF experimentation/packaging. Not a CoverWise model runtime contract. |
| `invoice-intelligence` | `OPENAI_API_KEY`, `OPENROUTER_API_KEY` | Hosted comparison lane evidence only. |
| `edureka` | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY` | Hosted comparison lane, outside mobile model decision scope. |

**Key rule:** presence in an env surface is not equivalent to evaluated mobile inference.

## 8) 2025–2026 candidate families from catalog/research (status: not run on-device)

All entries below are currently categorized as **Catalog-only / not evaluated on Android/iOS phone runtime** in this repo.

- **Gemma family:** Gemma 3n E2B/E4B, Gemma 3 270M/1B, Gemma 3 4B/12B (desktop Ollama checks only).
- **Qwen family:** Qwen3 0.6B/1.7B/4B and Qwen3-VL 2B/4B; Omni/related variants noted in frontier notes.
- **Newer parser/VLM families:** Unlimited-OCR, HunyuanOCR-1.5, RT-DocLayout, Typhoon-OCR, dots.ocr, OmniOCR, Qianfan-OCR, PaddleOCR-VL, ABot-OCR, Logics-Parsing, AgenticOCR, MeDocVL, GLM-OCR, MinerU variants, Dolphin/Marker, and similar 2025–2026 specialist entries in [mobile_model_catalog_2025_2026_2026-07-24.md](mobile_model_catalog_2025_2026_2026-07-24.md).
- **Managed platform candidates:** Gemini Nano/AICore and Apple Foundation Models are listed as potential managed-native follow-up probes but not implemented/benchmarked here.

## 9) Sources

## 10) Latest cross-project key sweep (re-run evidence)

| Project | `.env` files scanned | Key names detected |
|---|---|---|
| `medpiper/insurance_app` | `.env`, `.env.example` | `OPENAI_API_KEY`, `HF_TOKEN`, `OLLAMA_BASE_URL`, `GROQ_API_KEY` |
| `orbitcover-d2c` | `.env`, `.env.example` | `OPENROUTER_API_KEY` |
| `comfy` | `.env`, `.env.example` | `HF_TOKEN`, `HF_XET_HIGH_PERFORMANCE`, `HF_HOME`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE` |
| `speech_experiments/model-lab` | `.env`, `.env.example` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `HF_HOME` |
| `edureka` | `.env` | `GEMINI_API_KEY`, `GROQ_API_KEY`, `HUGGINGFACE_API_KEY`, `OPENAI_API_KEY` |
| `learning_for_kids` | `.env` | `GEMINI_API_KEY`, `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN` |
| `adshot` | `.env`, `.env.local`, `.open-next/.../.env` | `GEMINI_API_KEY`, `HF_TOKEN` |
| `bas5minute` | `.env.local`, `.env.example` | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `HF_TOKEN`, `GEMINI_API_KEY`, `HUGGINGFACE_API_KEY`, related caption/model ids |
| `notes` | `.env`, `.env.example` | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY` |
| `sentineltwin` | `.env`, `.env.local` | `TOGETHER_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY` |
| `invoice-intelligence` | `.env`, `.env.example` | `OPENAI_API_KEY`, `OPENROUTER_API_KEY` |
| `musicathon` | `.env`, `.env.example` | `HF_TOKEN` |
| `EchoPanel` | `.env` | `HF_TOKEN` |

- `docs/review/mobile_model_exploration_map_2026-07-24.md`
- `docs/review/mobile_model_decision_sheet_2026-07-24.md`
- `docs/review/mobile_model_strict_matrix_2026-07-24.md`
- `docs/technical/mobile_local_model_evaluation_2026-07-24.md`
- `docs/review/mobile_model_execution_ledger_2026-07-24.md`
- `docs/review/mobile_model_status_now_2026-07-24.md`
- `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md`
- `docs/review/mobile_model_evaluated_vs_not_authority_2026-07-24.md`
- Evidence JSONs under `docs/review/evidence/` and `docs/review/evidence/provider-smoke/`
