# Mobile model truth inventory for CoverWise (2026-07-25)

## Scope and date
- Scope: Android/iOS policy-RAG lane only, plus paid hosted lanes used for comparison.
- Date: 2026-07-25 (local repo scan + evidence re-checked before writing).

## A. What has reproducible evidence (EVAL) vs what is catalog-only

### EVAL (reproducible outputs in this repo)

| Stage | Candidate / lane | Evidence file | Result | Why this is accepted as evidence |
|---|---|---|---|---|
| Hosted generation | OpenAI `gpt-5-nano` | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json` | 3/3 synthetic pass; median 1237 ms | Reproducible cloud smoke + fixed fixture |
| Hosted generation (continuation) | OpenAI `gpt-5-nano` | `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json` | 3/3 synthetic pass; median 1619 ms | Reproducible continuation smoke on same fixed fixture |
| Hosted generation | OpenRouter `google/gemini-2.5-flash-lite` | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json` | 2/3 synthetic pass; median 746 ms | Reproducible comparison output |
| Hosted generation (continuation) | OpenRouter `google/gemini-2.5-flash-lite` | `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json` | 2/3 synthetic pass; median 1025 ms | Reproducible continuation smoke on same fixed fixture |
| Hosted generation | OpenRouter `google/gemma-3-4b-it` | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | 1/3 synthetic pass; median 582 ms | Reproducible comparison output |
| Hosted generation | HF Pro inference (`Qwen/Qwen3-4B-Instruct-2507`) | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json` | 2/3 synthetic pass; median 1173 ms | Reproducible HF API lane with key/token surface |
| Hosted generation (continuation) | HF Pro (`Qwen/Qwen3-4B-Instruct-2507`) | `docs/review/evidence/provider-smoke/continuation-hf-2026-07-25.json` | 2/3 synthetic pass; median 1026 ms | Reproducible continuation smoke on same fixed fixture |
| Policy retrieval + grounding | RAG corpus baseline | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | accuracy 0.5577, citation_rate 0.9615, hallucination_rate 0.3333 | End-to-end policy corpus evaluation artifact |
| Flutter local seam wiring | on-device scaffold tests | `mobile/test/on_device_inference_service_test.dart` | 3/3 checks pass, app-level guard behavior plus install-attempt path handling validated in suite with `flutter test` | Confirms gating/path code compiles and handles configured install-attempt path under test. |

### Scaffold-only (code/integration, no on-device model run yet)

| Stage | Candidate / lane | Why scaffold-only |
|---|---|---|
| Device generation/grounding | `flutter_gemma` + `flutter_gemma_mediapipe` behind `ON_DEVICE_*` flags | Service methods exist and are wired, but no `.task` model artifact installed/executed on Android/iOS |
| Device parser/retrieval experiments | `Gemma 3n`, `Gemma 3 1B/270M`, `Qwen3` local families, `Phi-4-mini`, `SmolLM3`, `Ministral` | Not in-repo as mobile-ready artifacts (`.task/.gguf/.tflite/.onnx`) and no on-device benchmark logs |
| Visual recovery lane | `Qwen3-VL`, `PaddleOCR-VL`, `Dolphin`, etc. | Listed in frontier registers but no in-product mobile execution contract |
| Managed-device path | Gemini Nano/AICore, Apple Foundation Models | No in-app probe integrations in this repo yet |

### Desktop/local non-mobile (not Android/iOS)

| Candidate / lane | Evidence file | Why not mobile proof |
|---|---|---|
| Ollama variants (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`) | `docs/review/evidence/local-model-eval/*.json` | Desktop/local server runtime, user-facing mobile app execution not present |
| DeepSeek OCR adapter / docTR / Surya checks | `docs/review/evidence/local-model-eval/*.json` and related local evidence | Server/device-hosted only |

## B. 2025–2026 frontier candidates in repo context (not executed on Android/iOS yet)

- Parser/layout: `Docling`, `MinerU` (`PoP`, `2.5-Pro`, `Diffusion`), `Marker 1.10.1`, `RT-DocLayout`, `Unlimited-OCR`, `PaddleOCR-VL` family, `Dolphin` (`1.5/2.0`), `AgenticOCR`, `Logics-Parsing`, `Qianfan-OCR`, `dots.ocr`, `GLM-OCR`, `DeepSeek-OCR`, `MeDocVL`, `SmolDocling`, and `Granite-Docling-258M`.
- VLM recovery: `Qwen3-VL 2B/4B`, `Qwen2-VL`, `Gemma-VL`, `LLaVA`, `MiniCPM-V`, etc.
- Reason for status: curated in frontier and catalog files, but no mobile execution manifest yet.

## C. Provider and key-surface scan across selected projects (proof of availability, not active routing)

This proves *capability potential* from local project env surfaces. Presence of keys is **not** equivalent to shipped on-device support.

| Project | Provider keys found in `.env` / `.env.example` | Meaning |
|---|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OLLAMA_BASE_URL`, `GROQ_API_KEY`/`GROQ_BASE_URL`/`GROQ_CHAT_MODEL` (example-only), `HF_TOKEN` (example comments) | Primary app lane today is OpenAI-hosted plus local/offline fallback scaffolding |
| `orbitcover-d2c` | `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` | Hosted comparator lane only |
| `comfy` | `HF_TOKEN`, `HF_HOME`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` | HF/Modal research and benchmark potential |
| `speech_experiments/model-lab` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` | HF experimentation surface |
| `invoice-intelligence` | `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`, `LLAMA_CLOUD_API_KEY` | Hosted models + LLamaCloud route |
| `adshot` | `HF_TOKEN`, `GEMINI_API_KEY`, `FAL_KEY`, `REPLICATE_API_TOKEN`, plus model vars (`FAL_HERO_MODEL*`) | Mixed multimodal/composer lane; not CoverWise mobile offload |
| `EchoPanel` | `HF_TOKEN`, `ECHOPANEL_HF_TOKEN`, whisper model selector | HF runtime surface for local ASR workflows |
| `musicathon` | `HF_TOKEN` | HF model lookup surface |
| `learning_for_kids` | `HF_TOKEN`, `GEMINI_API_KEY`, `HUGGINGFACEHUB_API_TOKEN` | Transformers/AI experimentation surface |
| `bas5minute` | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_*`, `HF_TOKEN`, `HUGGINGFACE_API_KEY` + model IDs (`HF_CAPTION_MODEL_ID`, etc.) | Broad hosted + multimodal captioning route |
| `SentinelTwin` | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TOGETHER_API_KEY` | Hosted model providers |
| `edureka` | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY`, `HUGGINGFACE_API_KEY` | Hosted/provider comparison surface |
| `notes` | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `OLLAMA_HOST`, `OLLAMA_MODEL` | Local + hosted LLM workflow |

## D. Why some lanes are not valid for Android/iOS in this repo

- **Ollama / MLX**: local workstation runtime; not equivalent to Android/iOS device-native execution.
- **Transformers.js / WebLLM paths**: browser-first execution contract, not a Flutter-native Android/iOS runtime bridge in CoverWise today.
- **HF Pro / Modal / OpenRouter / OpenAI**: API-hosted lanes. These are valid paid comparison or production-hosted paths but not offline phone execution unless converted to device artifacts and integrated with runtime contracts.
- **Managed OS models (Nano/Foundation Models)**: platform-specific managed runtime pathways exist, but no in-app capability probes + fallback contracts are present in this repo.

## E. What to run next (shortlist)

1. **Gate first**: add/log a structured `MobileModelCapability` contract for supported/unsupported devices and artifact metadata (hash, format, quantization).
2. **Run first offline comparator**: `Gemma 3n E2B` through existing `flutter_gemma` seam on one Android + one iOS target.
3. **Benchmark manifest**: collect cold/warm latency, token throughput, RSS/memory trend, timeout/cancel behavior, and grounded-output pass-rate on policy probes.
4. **Fallback comparator only after step 3 success**: `Gemma 3 1B/270M` and `Qwen3 1.7B`.
5. **Visual fallback evaluation**: only if OCR/layout failures persist, evaluate `Qwen3-VL` or `PaddleOCR-VL` on failure pages.

## F. Practical shortlist for now (no hand-waving)

- **Keep this shipped path for policy accuracy reliability:** hosted `OpenAI gpt-5-nano` for now (policy evidence exists).
- **Do not claim mobile-offline readiness yet for any model family** until the benchmark manifest is attached to real device runs.
- **Do not route paid API models (OpenRouter / HF Pro / Modal / OpenAI) as local/offline in product docs** without explicit artifact/manifest proof.
