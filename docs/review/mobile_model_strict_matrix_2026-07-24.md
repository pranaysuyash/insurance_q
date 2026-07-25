# CoverWise mobile model strict matrix — 2026-07-24

This file is the short, auditable matrix for your latest request:  
**Which model/runtime options were evaluated, what was not, and why.**

Definition used here:

- **EVAL** = reproducible evidence file in this repo for the stated stage/runtime lane.
- **SCaffold-only** = integration code exists but no Android/iOS execution evidence.
- **Catalog-only** = listed for exploration, no execution evidence in repo yet.
- **Hosted-only** = valid API lane but not mobile/offline/local execution.

For a short, operational summary with stage + fallback + key-lane alignment, see:
`mobile_model_decision_onepager_2026-07-24.md`.

## 1) Model/runtimes vs stages (CoverWise-relevant)

| Candidate / lane | Stage in RAG | Runtime type | Android/iOS evidence | Status | Evidence / proof |
|---|---|---|---|---|---|
| OpenAI `gpt-5-nano` (direct) | Hosted generation (grounded QA fallback) | Cloud API | Not mobile-local | **EVAL** | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json`, `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json` |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted generation comparator | Cloud API | Not mobile-local | **EVAL** | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json` |
| OpenRouter `google/gemma-3-4b-it` | Hosted generation comparator | Cloud API | Not mobile-local | **EVAL** | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` |
| HF Inference `Qwen/Qwen3-4B-Instruct-2507` (HF Pro) | Hosted generation comparator | Cloud API (HF token) | Not mobile-local | **EVAL** | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json` |
| Modal Labs (via `MODAL_TOKEN_ID/SECRET`) | Private benchmark/training lane | Private GPU service | No mobile path | **SCaffold/Context only** | `docs/review/mobile_model_decision_sheet_2026-07-24.md` notes Comfy key presence; no in-repo mobile execution |
| Ollama `gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b` | OCR/desktop local fallback checks | Desktop host | No mobile path | **EVAL** (desktop), **catalog-only for mobile** | `docs/review/evidence/local-model-eval/gemma3-12b-2026-07-12.json`; `docs/review/evidence/local-model-eval/gemma3-4b-recheck-2026-07-12.json`; `docs/review/evidence/local-model-eval/deepseek-ocr-diagnostic-2026-07-12.json` |
| `flutter_gemma` + MediaPipe seam (`ON_DEVICE_INFERENCE_ENABLED`, `ON_DEVICE_MODEL_URL`) | Generation local/offline and assisted parse/summary | Mobile Flutter bridge | No runtime execution on-device | **SCaffold-only** | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart` |
| Gemma 3n E2B / E4B (`.task`) | Mobile generation/local assist + recovery | Planned shared mobile export | No runtime execution | **Catalog-only** (candidate) | `docs/review/mobile_model_decision_sheet_2026-07-24.md` |
| Gemma 3 270M / 1B | Mobile generation/classification candidate | Planned mobile export | No runtime execution | **Catalog-only** | same above |
| Qwen3 0.6B / 1.7B / 4B | Mobile generation candidate | Planned portable export | No runtime execution | **Catalog-only** | same above |
| Phi-4-mini / SmolLM3 / Ministral 3 3B | Mobile generation/classification candidates | Planned portable export | No runtime execution | **Catalog-only** | same above |
| Qwen3-VL 2B / 4B | Visual-stage candidate/fallback | Planned mobile export | No runtime execution | **Catalog-only** | `docs/review/mobile_model_general_vlm_frontier_2026-07-24.md` |
| Gemini Nano / AICore | Managed Android native path | OS-managed | No capability/device probe yet | **Not executed in CoverWise** | No in-app probe artifacts in this repo |
| Apple Foundation Models | Managed iOS native path | OS-managed | No capability/device probe yet | **Not executed in CoverWise** | No in-app probe artifacts in this repo |
| Transformers.js (WebGPU/ONNX) | Browser/native web assist lane | Flutter web / JS bridge path | Not Flutter-native Android/iOS runtime path | **Not executed for this decision** | Not implemented in `mobile/` runtime path |
| PyMuPDF + canonical parser/chunking pipeline | Parse + chunking baseline for policy corpus | Server baseline | N/A (not mobile-only) | **EVAL (server)** | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` |
| Docling / Marker / MinerU / RT-DocLayout / Unlimited-OCR / PaddleOCR-VL / Qwen3-VL | Frontline parser candidates | Host/device execution depends on mobile exports | No mobile execution | **Catalog-only** | `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md` |
| EmbeddingGemma / Qwen3-Embedding | Mobile embedding lane | Planned mobile/mobile-like export | No mobile execution | **Catalog-only** | `docs/review/mobile_model_decision_sheet_2026-07-24.md`; `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md` |
| Fine-tuned LoRA/QLoRA/adapter assets | Any stage (if provided) | Would require adapter lineage + tokenizer + export metadata | Not wired | **Not present / not wired** | `docs/review/mobile_model_status_now_2026-07-24.md` |

## 2) Stage-wise execution truth (source-grounded)

| Stage | What has **been evaluated** in repo | What is still open for Android/iOS |
|---|---|---|
| Parse / OCR / layout | PyMuPDF baseline, Surya/docTR local checks | Mobile-native parser/runtime benchmark is open (Docling/Marker/MinerU/Unlimited-OCR family) |
| Chunking / reconstruction | Paragraph/entity/adjacent chunking in pipeline | Mobile-only chunk tuning and memory/latency profiling is open |
| Embeddings | `text-embedding-3-small` hosted retrieval baseline | On-device embedding lane (EmbeddingGemma/Qwen3-Embedding) is open |
| Retrieval / rerank | Hybrid dense+FTS+rerank path exercised in policy run | On-device retrieval pressure, cancellation, and failure-mode telemetry is open |
| Generation (hosted) | OpenAI, OpenRouter, HF smoke + corpus policy checks | Cost/latency/robustness comparison for mobile fallback logic not yet done |
| Generation (local/offline) | Flutter seam verified by tests only | No Android/iOS local execution yet; this is the largest open gap |

## 3) Policy corpus / test outputs (why this impacts model choice)

- `flutter test test/on_device_inference_service_test.dart`: **3/3 pass** (off by default guard, install guard, and install-attempt-path check with continuation flags).
- `flutter devices` (latest run in this pass): `iPhone 17` (simulator), `macOS`, and `Chrome` were connected.
- Despite simulator connectivity, no Android/iOS on-device model benchmark was executed in this session because no approved model artifact/config (`.task` or mobile model install path) was provided.
- `policy-corpus-ragas-2026-07-24.json`: held-out 52Q policy baseline includes generation path evidence and citation coverage; generation quality remains canonical-path dependent (`accuracy=0.5577`, `citation_rate=0.9615` for hosted baseline).
- Provider smoke files are synthetic and not mobile/offline proof:
  - `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`
  - `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json`
  - `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json`
  - `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json`
  - `docs/review/evidence/local-model-eval/gemma3-12b-2026-07-12.json`
  - `docs/review/evidence/local-model-eval/gemma3-4b-recheck-2026-07-12.json`
  - `docs/review/evidence/local-model-eval/deepseek-ocr-diagnostic-2026-07-12.json`

## 3a) Direct run-metric snapshot (latest)

| Evidence file | Provider | Model | Task count | Passed | Median latency (ms) | Synthetic only |
|---|---|---|---:|---:|---:|---:|
| `openai-synthetic-2026-07-24-success.json` | openai | gpt-5-nano-2025-08-07 | 3 | 3 | 1237 | true |
| `openai-synthetic-2026-07-24-final.json` | openai | gpt-5-nano | 3 | 0 | 2231 | true |
| `openai-synthetic-2026-07-24-json-mode.json` | openai | gpt-5-nano | 3 | 0 | 2229 | true |
| `openai-synthetic-2026-07-24-rerun.json` | openai | gpt-5-nano | 3 | 0 | 622 | true |
| `openrouter-synthetic-2026-07-24.json` | openrouter | google/gemini-2.5-flash-lite | 3 | 2 | 746 | true |
| `openrouter-gemma3-4b-synthetic-2026-07-24.json` | openrouter | google/gemma-3-4b-it | 3 | 1 | 582 | true |
| `hf-qwen3-synthetic-2026-07-24.json` | hf | Qwen/Qwen3-4B-Instruct-2507 | 3 | 2 | 1173 | true |
| `gemma3-12b-2026-07-12.json` | ollama | gemma3:12b | 1 (fixture match) | 1 | 40217 | false |
| `gemma3-4b-recheck-2026-07-12.json` | ollama | gemma3:4b | 1 (fixture match) | 1 | 27183 | false |
| `deepseek-ocr-diagnostic-2026-07-12.json` | ollama | deepseek-ocr:latest | 1 (fixture match) | 0 | 65321 | false |

## 4) Project-level provider-key presence (names only, values omitted)

Observed from `/Users/pranay/Projects/*/.env` and `.env.example`:

| Project | Keys seen |
|---|---|
| AIMLGlossary | OPENAI_API_KEY |
| EchoPanel | HF_TOKEN |
| LLM | OPENAI_API_KEY |
| SentinelTwin | GEMINI_API_KEY, OPENAI_API_KEY, TOGETHER_API_KEY |
| _bounties | OPENAI_API_KEY |
| adhoc_projects | HF_TOKEN, OPENAI_API_KEY, OPENROUTER_API_KEY |
| adshot | GEMINI_API_KEY, HF_TOKEN |
| bas5minute | ANTHROPIC_API_KEY, GEMINI_API_KEY, HF_TOKEN, HUGGINGFACE_API_KEY, OPENAI_API_KEY |
| caption-art | OPENAI_API_KEY |
| comfy | HF_TOKEN, MODAL_TOKEN_ID, MODAL_TOKEN_SECRET |
| edureka | GEMINI_API_KEY, GROQ_API_KEY, HUGGINGFACE_API_KEY, OPENAI_API_KEY |
| external-skills | GOOGLE_API_KEY |
| family-dinner-os | OPENAI_API_KEY |
| gstack | ANTHROPIC_API_KEY |
| icml-2026-agent-repro | GOOGLE_API_KEY, HF_TOKEN, OPENAI_API_KEY, OPENROUTER_API_KEY |
| interior_photo | OPENAI_API_KEY |
| invoice-intelligence | OPENAI_API_KEY, OPENROUTER_API_KEY |
| learning_for_kids | GEMINI_API_KEY, HF_TOKEN, HUGGINGFACEHUB_API_TOKEN |
| media_exp | GEMINI_API_KEY, GOOGLE_API_KEY, OPENAI_API_KEY |
| medpiper | HF_TOKEN, OPENAI_API_KEY |
| mirofish-local | OPENAI_API_KEY |
| musicathon | HF_TOKEN |
| notes | ANTHROPIC_API_KEY, GOOGLE_API_KEY, OPENAI_API_KEY |
| orbitcover-d2c | OPENROUTER_API_KEY |
| robonomics | GEMINI_API_KEY |
| shopstack | HF_TOKEN |
| speech_experiments | HF_TOKEN, HUGGINGFACE_HUB_TOKEN |
| travel_agency_agent | GEMINI_API_KEY, OPENAI_API_KEY |

> Note: only a subset (medpiper, orbitcover-d2c, comfy, speech_experiments, etc.) is directly relevant to current CoverWise mobile model routing; the rest shows broader workspace-key surface.

## 5) What should be shortlisted now (practical order)

1. Keep hosted path (`gpt-5-nano`) as production default because it has held-out policy evidence.
2. Keep hosted smoke lanes (OpenRouter/HF) as **comparison-only** until mobile runtime is proven.
3. Run one mobile-first local lane next (`Gemma 3n` path) with:
   device tier matrix + download/eviction telemetry + cancellation + citation checks.
4. Only after pass, test one compact comparator (`Qwen3 1.7B` or `EmbeddingGemma+Gemma 3n`) and managed fallback (`Gemini Nano`, Foundation Models) if capability probes are positive.
5. Keep all catalog/specialist parsers and VLM frontiers as **stage candidates** until exports + on-device benchmarks exist.

## 6) Why this is explicit (directly answering your ask)

- For Android/iOS users, **Ollama and desktop-hosted runtimes are not app-local installs**. They are desktop/admin tools, not mobile runtime dependencies.
- "SOTA 2025–2026" names are captured in catalog files, but they are **not interchangeable with mobile-ready lanes** unless there is actual artifact + on-device evidence.
- The current open gap is not "model ideas missing"; it is **evidence gap for Android/iOS runtime** and the required operational contracts (timeout/fallback/eviction/telemetry/failed-device handling).
