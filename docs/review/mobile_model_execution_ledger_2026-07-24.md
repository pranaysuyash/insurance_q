# Mobile model execution ledger (2026-07-24)

**Date:** 2026-07-24  
**Scope:** Android + iOS model options for CoverWise, mobile/offline readiness, and paid API/local runtime comparisons.  
**Source-of-truth rule:** “Evaluated” = reproducible run output in this repo for that specific stage/runtime path. “Open” = tracked but not yet executed in target runtime.
**Current execution reality:** as of the latest run in this pass, an iPhone simulator was attached (`iPhone 17`, iOS 26.2), plus macOS and Chrome; however no native on-device model execution was performed for any candidate model. So this run adds runtime availability evidence but does **not** add on-device model runtime proof.

## 1) Pipeline-stage truth map (current)

| Stage | Lane | Evaluated in repo? | What was run | Evidence | Why not “done” |
|---|---|---|---|---|---|
| Parse / text extraction | Canonical backend: PyMuPDF + document cleanup | ✅ | production corpus run path + policy fixture | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | No Android/iOS text-extractor benchmark |
| OCR / table / layout frontier | Surya-2 desktop path; docTR / OCR family references | ⚠️ (limited) | local synthetic-page OCR checks (`surya` style) | `docs/review/evidence/local-model-eval/gemma3-12b-2026-07-12.json` | Not Android/iOS mobile benchmark |
| OCR/layout parser candidates | Docling, MinerU, Marker, RT-DocLayout, Unlimited-OCR, Qwen3-VL etc. | ❌ | only catalog / architecture references | `docs/technical/rag/exploration/chunking_parsing_embedding_exploration_2026-07-22.md` | No device/mobile execution |
| Chunking / reconstruction | Paragraph + entity + adjacency chunking pipeline | ✅ | corpus-level experiments + implementation evidence | `docs/technical/rag/exploration/chunking_parsing_embedding_exploration_2026-07-22.md` | Mobile-only tuning not yet run |
| Retrieval / ranking | Dense + FTS + rerank (hybrid) | ✅ | server/local corpus checks | `docs/review/evidence/policy-corpus*` and service tests | Mobile-only retrieval pressure not yet run |
| Embeddings | OpenAI text-embedding-3-small (hosted) | ✅ | policy corpus metrics in 52Q benchmark | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | On-device embedding lane not yet in app |
| Hosted generation | OpenAI `gpt-5-nano` | ✅ (synthetic + held-out policy) | synthetic probe + 52Q corpus path | No mobile/offline claim |
| Hosted generation | OpenRouter (`google/gemini-2.5-flash-lite`, `google/gemma-3-4b-it`) | ✅ synthetic only | provider smoke probes | Not mobile/offline |
| Hosted generation | HF inference (`Qwen/Qwen3-4B-Instruct-2507`) | ✅ synthetic only | provider smoke probe | Not mobile/offline |
| Desktop local fallback | Ollama `gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`, DeepSeek OCR | ✅ synthetic fixture checks | desktop run logs | Desktop-only, no phone runtime |
| Mobile local seam | `flutter_gemma` + `.task` flag/service plumbing | ⚠️ scaffold present | code contract + service flags | No Android/iOS run |
| Mobile managed/offline lane | Android Gemini Nano / iOS Foundation Models | ❌ | no in-app probe | no device/device-matrix |
| Mobile cross-platform LLM lane | Gemma 3n / Gemma 3 / Qwen3 / Phi / SmolLM / Ministral | ❌ | catalog + plan only | no artifact/exports/devices |

### Contract-level verification run (in this repo pass)

- Ran: `flutter test test/on_device_inference_service_test.dart`
- Result: **3/3 pass** (current 2026-07-25 continuation includes install-attempt-path coverage)
  - Confirms `ON_DEVICE_INFERENCE_ENABLED` is false by default and `hasOnDeviceInferenceConfig` is false by default.
  - Confirms service installation path fails fast when no approved config is present.
- Scope: this is a **local runtime guard test only** and does **not** provide Android/iOS on-device model execution evidence.
- Environment check: `flutter devices` from `/mobile` during this pass reported `iPhone 17` (iOS simulator), `macOS`, and `Chrome`. The on-device tests were still **not executed** because the on-device inference artifacts/config (`.task` + install path) were not enabled in this run.

## 2) Provider lanes and what they currently are

| Provider lane | App route in CoverWise today | Evaluated for this decision | Notes |
|---|---|---|---|
| OpenAI direct | Hosted backend generation fallback | ✅ (policy + synthetic) | Not mobile/offline |
| OpenRouter | Hosted aggregator / benchmark candidate | ✅ synthetic only | Not directly wired to CoverWise mobile |
| HF Pro / HF inference provider | Hosted API lanes (token + hosted inference) | ✅ synthetic only | Does not imply local/offline |
| Modal Labs | Private GPU / hosted benchmark lane | ✅ endpoint context only | Not device-offline |
| Ollama / MLX | Desktop/local developer fallback | ✅ desktop checks for selected models | Not Android/iOS user lane |

## 3) Cross-project key-name inventory (presence-only, no values)

- `medpiper/insurance_app`: `OPENAI_API_KEY`, `HF_TOKEN`
- `orbitcover-d2c`: `OPENROUTER_API_KEY`
- `comfy`: `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`
- `invoice-intelligence`: `OPENAI_API_KEY`, `OPENROUTER_API_KEY`
- `edureka`: `OPENAI_API_KEY`, `HUGGINGFACE_API_KEY`, `GROQ_API_KEY`, `GEMINI_API_KEY`
- `speech_experiments/model-lab`: `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`
- `learning_for_kids`: `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`, `GEMINI_API_KEY`
- `musicathon`: `HF_TOKEN`
- `EchoPanel`: `HF_TOKEN`
- `bas5minute`: `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`, `OPENAI_API_KEY`
- `adshot`: `HF_TOKEN`, `GEMINI_API_KEY`
- `notes`: `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `OPENAI_API_KEY`
- `sentinelTwin`: `GEMINI_API_KEY`, `OPENAI_API_KEY`, `TOGETHER_API_KEY`

## 4) 2025–2026 catalog models reviewed for future mobile OCR/parsing (document parser catalog)

The catalog file at `/Users/pranay/Downloads/researches_lists/document_parsers_extractors_catalog_2026_v2.xlsx` is used as the frontier source for 2025–2026 parser/ocr candidates.

### 4A) Grounded status for this pass

- **No cataloged 2025–2026 parser model has Android/iOS device execution evidence in this pass.**
- This stage uses the table below for candidate inventory; actual execution is still open.

#### Full candidate inventories (not yet executed on-device)

- [`mobile_model_catalog_2025_2026_2026-07-24.md`](mobile_model_catalog_2025_2026_2026-07-24.md)  
  (78 rows from “Recent Models 2024+”, filtered for 2025–2026 and mapped to mobile-stage intent)
- [`mobile_model_general_vlm_frontier_2026-07-24.md`](mobile_model_general_vlm_frontier_2026-07-24.md)  
  (General VLM OCR-capable models; kept as second-stage visual fallback candidates, not first-stage parsers)

### 4B) Quick priority slice (newest relevant 2025–2026 parser frontier)

Priority now is intentionally narrow for a first mobile release because these directly map to CoverWise failure clusters (tables, headings/sections, forms/KVP, and scan recovery):

1. `RT-DocLayout` (reading order/layout routing)
2. `Unlimited-OCR` (one-shot structured document parsing)
3. `PaddleOCR-VL-1.6` + `PP-OCRv6` (compact multilingual OCR)
4. `MinerU2.5-Pro`, `Marker`, `Docling`, `MinerU-Popo`, `MinerU-Diffusion` (structure reconstruction)
5. `AgenticOCR`, `Logics-Parsing-Omni`, `Qianfan-OCR`, `Agentar-Fin-OCR`
6. `Dolphin` family (`Dolphin-1.5`, `Dolphin-2.0`)
7. `dots.mocr/dots.ocr`, `FireRed-OCR`, `GLM-OCR`, `DeepSeek-OCR`, `MeDocVL`
8. `SmolDocling-256M`, `Granite-Docling-258M` (compact docs-to-text alternatives)

All are currently candidate-only; none are promoted into Android/iOS runtime yet.

## 5) What is evaluated now vs not yet (for your exact “so which was explored?”)

### Evaluated (with repo evidence)
- Hosted generation: OpenAI `gpt-5-nano` (3/3 synthetic; 29/52 held-out accuracy path metrics)
- Hosted generation: OpenRouter Gemma/Gemini variants (2/3 and 1/3 synthetic)
- Hosted generation: HF Qwen3-4B smoke (2/3)
- Desktop local parsing/generation: Ollama Gemma 3/DeepSeek/Qwen2.5VL checks on synthetic page
- OCR baseline: Surya-2 local synthetic token checks

### Not evaluated yet in target mobile runtime
- Any native Android/iOS on-device LLM run (Gemma 3n, Gemma 3 family, Qwen3 0.6B/1.7B/4B, Phi-4-mini, SmolLM3, Ministral)
- Platform-managed mobile paths in-app (Nano/AICore, Apple Foundation Models)
- Transformers.js native Flutter runtime (only web/mobile-web route if pursued)
- All catalog frontier parsers above are not yet executed in-app on devices

## 6) Recommended fallback order (practical, not benchmark-only)

1. Keep hosted `OpenAI gpt-5-nano` + evidence gates as the production-safe default for policy-grounded responses.
2. Add benchmark router as explicit comparison lane via OpenRouter/HF/Modal keys (explicit provider/model/fallback logging), but keep as comparison only.
3. Run one mobile mobile-first local lane first: `Gemma 3n` candidate (if asset/runtime contract can be built) with capability, cancellation, timeout, download-resume, thermal/RSS telemetry.
4. After pass, compare one compact portable candidate (Qwen3 1.7B or EmbeddingGemma + Gemma 2-stage retrieval) before any larger 4B/8B mobile experiment.
5. Defer true fine-tune routing until artifact lineage, license, tokenizer, quantization, and on-device export verification are complete.

## 7) Test results that exist today (snapshot)

- OpenAI `gpt-5-nano` synthetic probe: **3/3**
- OpenRouter Gemini 2.5 flash probe: **2/3**
- OpenRouter Gemma 3 4B probe: **1/3**
- HF Qwen3-4B probe: **2/3**
- Policy held-out `52Q` (baseline corpus): **29/52**, `citation_rate=0.9615`, `source/context_coverage=1.0`, `hallucination_rate=0.3333`

- Source artifact roots:
  - `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`
  - `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json`
  - `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json`
  - `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json`
  - `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json`
