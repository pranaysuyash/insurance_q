# Mobile model decision compendium (2026-07-25, CoverWise policy-RAG lane)

This is the consolidated record for the request: **which models/layers are evaluated, which are only
candidates, what exists for Android/iOS today, and what remains to be run.**

## 0) Evidence rule used here

- **EVAL** = reproducible run output exists in this repository for that exact lane/runtime.
- **SCaffold** = code integration exists, no Android/iOS device generation run exists yet.
- **Catalog-only** = researched/shortlisted only; no qualifying run in-repo for that lane.
- **Hosted-only** = API lane only; not Android/iOS local/offline model runtime.

## 1) What was actually evaluated (with metrics)

### 1.1 Hosted model lanes (policy corpus + synthetic)

| Provider/lane | Evidence file | Pass rate | Latency (median ms) | Why this matters |
|---|---|---:|---:|---|
| OpenAI `gpt-5-nano` | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json` | `3/3` | `1237` | Most stable hosted baseline in current evidence; reported model `gpt-5-nano-2025-08-07`. |
| OpenAI `gpt-5-nano` | `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json` | `3/3` | `1619` | Continuation check confirms pass-rate stability on same synthetic fixture. |
| OpenAI `gpt-5-nano` | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-final.json` | `0/3` | `2231` | Earlier retry artifact; kept as drift evidence only. |
| OpenRouter `google/gemini-2.5-flash-lite` | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json` | `2/3` | `746` | Comparison lane only (cloud). |
| OpenRouter `google/gemini-2.5-flash-lite` | `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json` | `2/3` | `1025` | Continuation check confirms comparison stability on same synthetic fixture. |
| OpenRouter `google/gemma-3-4b-it` | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | `1/3` | `582` | Comparison lane only (cloud). |
| HF Inference (`HF_TOKEN` / HF Pro) `Qwen/Qwen3-4B-Instruct-2507` | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json` | `2/3` | `1173` | Hosted-only comparison lane; API credits/availability does not imply on-device. |
| HF Inference (`HF_TOKEN` / HF Pro) `Qwen/Qwen3-4B-Instruct-2507` | `docs/review/evidence/provider-smoke/continuation-hf-2026-07-25.json` | `2/3` | `1026` | Continuation check confirms comparison stability on same synthetic fixture. |

### 1.2 Policy-doc baseline (RAG end-to-end) and what it proves

- `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json`
  - `total_questions`: `52`
  - `accuracy`: `0.5577` (29/52)
  - `citation_rate`: `0.9615`
  - `hallucination_rate`: `0.3333`
  - `ragas_metrics`: `faithfulness=0.8368`, `context_precision=0.4558`, `answer_relevancy=0.7148`
  - Stage ownership: this validates **server pipeline + hosted generation behavior** for this held-out corpus, not Android/iOS on-device inference.

### 1.3 Desktop/local non-mobile model checks (policy fixture)

- `docs/review/evidence/local-model-eval/gemma3-12b-2026-07-12.json`  
- `docs/review/evidence/local-model-eval/gemma3-4b-recheck-2026-07-12.json`  
- `docs/review/evidence/local-model-eval/deepseek-ocr-diagnostic-2026-07-12.json`  
These are OCR/compatibility checks and token-retrieval checks on local/server tools. They are **not** Android/iOS app runtime evidence.

## 2) Pipeline-stage truth for CoverWise policy flow

| Stage | What was evaluated | Stage status |
|---|---|---|
| Parse / layout intake | `PyMuPDF` + current OCR/layout path (baseline corpus) | **EVAL (server/corpus)** |
| OCR/layout frontier alternatives | Surya2/docTR variants; other parser candidates | **Catalog-only / scaffold** |
| Chunking / reconstruction | paragraph+entity chunking experiments in corpus path | **EVAL (server config)** |
| Embedding | `text-embedding-3-small` hosted | **EVAL (hosted)** |
| Hosted generation + grounding | `gpt-5-nano`, `gemini-2.5-flash-lite`, `gemma-3-4b-it`, HF Qwen3-4B | **EVAL (hosted)** |
| On-device local generation | `flutter_gemma` + MediaPipe `.task` seam | **SCaffold-only (no install/load/ask run)** |
| Managed-device platform runtime | Android Gemini Nano / Apple Foundation Models | **Catalog-only (no in-app probe)** |
| Visual recovery candidates | Qwen3-VL / PaddleOCR-VL family | **Catalog-only** |

## 3) Model/runtime lane matrix by priority and mobile feasibility

### 3.1 Models/libraries directly relevant to phone execution

| Candidate | Android feasibility | iOS feasibility | Lane status | Evidence / blocker |
|---|---|---|---|---|
| `flutter_gemma` + MediaPipe seam | yes (requires export + `.task`) | yes (requires export + `.task`) | **SCaffold** | Integration is present via `ON_DEVICE_INFERENCE_ENABLED` + `ON_DEVICE_MODEL_URL` and service contract, but no mobile `.task` install/load/ask run in this pass. |
| Gemma 3n E2B/E4B | strong first mobile candidate | strong first mobile candidate | **Catalog-only** | No artifact/hash + no device run yet. |
| Gemma 3 270M/1B | compact local candidate | compact local candidate | **Catalog-only** | No mobile artifact/benchmark yet. |
| Qwen3 0.6B/1.7B/4B | candidate | candidate | **Catalog-only** | No mobile export/benchmark yet. |
| Phi-4-mini / SmolLM3 / Ministral 3B | candidate | candidate | **Catalog-only** | No mobile export/benchmark yet. |
| `Qwen3-VL` / PaddleOCR-VL | fallback for visual recovery only | fallback | **Catalog-only** | No on-device visual recovery pipeline. |
| Transformers.js / WebGPU | browser mobile-web only | browser mobile-web only | **Not Flutter-native** | Useful only for separate web/mobile-web experiment, not current production mobile route. |

### 3.2 Hosted and private cloud lanes (not local/offline)

| Lane | Status | Role in this repo |
|---|---|---|
| OpenAI API (`gpt-5-nano`) | EVAL | Baseline hosted quality lane (policy-level). |
| OpenRouter (`gemini-2.5-flash-lite`, `google/gemma-3-4b-it`) | EVAL (comparison only) | Bench/fallback comparator, not on-device. |
| HF Pro / HF Inference | EVAL (comparison only) | API lane; credits help evaluation throughput, not phone execution. |
| Modal Labs (`MODAL_TOKEN_*`) | Context + potential benchmark lane | Keys exist in other project, no CoverWise mobile endpoint run. |

### 3.3 Fine-tune / adapter lane status

- No production-ready LoRA/QLoRA/merged checkpoint is routed in CoverWise mobile.
- No adapter lineage exists in-repo with:
  - tokenizer + tokenizer version,
  - quantization/weight type,
  - export hash,
  - runtime format mapping (`.task/.gguf/.onnx/.tflite`),
  - Android/iOS benchmark manifest.

## 3.4 Mobile-ready model/options matrix requested in this pass

This is the explicit answer to "what can we run where today vs only evaluate vs catalog-only":

### A) Flutter-native mobile runtime candidates

- **`flutter_gemma` + MediaPipe (.task) seam**  
  - **Status:** `SCaffold`  
  - **Use:** Android/iOS shared local inference
  - **Why:** feature flags and service contract exist, but no `.task` artifact has been installed/loaded/queried on a real device in this repo.

- **Gemma 3n E2B / E4B**  
  - **Status:** `Catalog-only` (pipeline-ready candidate)  
  - **Use:** first-generation local candidate if we can ship a valid `.task` artifact.
  - **Why not yet:** no mobile artifact + no Android/iOS benchmark trace.

- **Gemma 3 270M / 1B**  
  - **Status:** `Catalog-only`  
  - **Use:** compact local fallback/reroute model class.
  - **Why not yet:** no export/quantization/benchmark in-repo.

- **Qwen3 0.6B / 1.7B / 4B**  
  - **Status:** `Catalog-only`  
  - **Use:** comparison class for mobile export quality/latency.
  - **Why not yet:** no mobile artifact, no device trace.

- **Phi-4-mini / SmolLM3 / Ministral 3B**  
  - **Status:** `Catalog-only`  
  - **Use:** compact alternatives if Gemma lane fails first gate.
  - **Why not yet:** no pipeline+artifact proof.

- **Qwen3-VL / PaddleOCR-VL / other VLM visual fallbacks**  
  - **Status:** `Catalog-only`  
  - **Use:** only visual-recovery after OCR/layout failure.
  - **Why not yet:** no visual recovery branch in runnable Android/iOS app path.

- **Transformers.js / WebGPU / ONNX-Web**  
  - **Status:** `Not Flutter-native mobile`  
  - **Use:** separate web/mobile-web experiment only.
  - **Why not yet:** not the current production Flutter mobile lane in this app.

### B) Hosted paid lanes (comparison / benchmark only, not local-offline)

- **OpenAI API (gpt-5-nano)**  
  - **Status:** `EVAL`  
  - **Use:** production-safe factual baseline for hosted generation.
  - **Why not local:** API/cloud-only.

- **OpenRouter (`google/gemini-2.5-flash-lite`, `google/gemma-3-4b-it`)**  
  - **Status:** `EVAL (comparison only)`  
  - **Use:** benchmark/sanity comparison across cloud models.
  - **Why not local:** API/cloud-only.

- **HF Pro / HF Inference (`Qwen/Qwen3-4B-Instruct-2507`)**  
  - **Status:** `EVAL (comparison only)`  
  - **Use:** low-cost comparison lane if budget/credits permit.
  - **Why not local:** credits do not imply phone-executable artifact.

- **Modal Labs (`MODAL_TOKEN_*`)**  
  - **Status:** `Context / remote benchmark option`  
  - **Use:** private GPU or heavy-model benchmark/benchmark preprocessing candidate.
  - **Why not local:** no CoverWise mobile endpoint in this repo.

### C) Managed-device native platform lanes

- **Android Gemini Nano / AICore**  
  - **Status:** `Catalog-only in-repo`  
  - **Use:** device-managed managed inference for eligible devices.
  - **Why not claimed yet:** no in-app hardware probe with supported/unsupported matrix.

- **Apple Foundation Models**  
  - **Status:** `Catalog-only in-repo`  
  - **Use:** iOS managed inference where Apple Intelligence support exists.  
  - **Why not claimed yet:** no in-app iOS capability probe or regression matrix.

### D) Fine-tune / adapter status (explicit)

- **LoRA/QLoRA/PEFT adapters (any model family)**  
  - **Status:** `Not wired`
  - **Reason:** no export hash, tokenizer/version lock, adapter merge config, or on-device benchmark manifest currently available.

### E) 2025-2026 frontier parsers / OCR models from catalog (shortlist, currently non-executed on device)

From `document_parsers_extractors_catalog_2026_v2.xlsx`, the relevant frontier entries are in discovery posture only:

- 2026: `Infinity-Parser2`, `RT-DocLayout`, `Unlimited-OCR`, `PaddleOCR-VL 1.6`, `PP-OCRv6`, `MinerU-Popo`, `MinerU2.5-Pro`, `MinerU-Diffusion`, `ABot-OCR`, `Logics-Parsing(-Omni)`, `Qianfan-OCR`, `dots.mocr/dots.ocr`, `FireRed-OCR`, `AgenticOCR`, `Dolphin 1.5/2.0`, `GLM-OCR`, `DeepSeek-OCR 2`, `MeDocVL`.
- 2025: `Marker 1.10.1`, `MinerU 2.5`, `SmolDocling-256M`, `Granite-Docling-258M`, `PaddleOCR-VL`, `MonkeyOCR*`, `DINOCR*`.
- General OCR/VLM families (e.g., `Qwen3-VL`, `MiniCPM-V`, `LLaVA-OneVision`, `Gemma-VL`, `GPT-5(GPT-4o-family)`) remain `Catalog-only` for this release until image-stage error-rate, coordinate accuracy, and page provenance are run on-device.

## 3.5 Practical shortlist (what to run next, stage-gated)

1. **Keep production anchor today:** hosted `OpenAI gpt-5-nano` for policy grounding.
2. **Run first mobile lane now:** `Gemma 3n E2B` through existing `flutter_gemma` seam (requires `.task` artifact + Android/iOS manifest + model capability table).
3. **Then compare one compact local comparator:** `Gemma 3 270M/1B` vs `Qwen3 1.7B` in the same device manifest.
4. **Then benchmark managed-native:** `Gemini Nano/AICore` and `Apple Foundation Models` with supported/unsupported-device matrix.
5. **Then parser/VLM specialists:** run only if text/layout failures remain dominant; start with `Unlimited-OCR`, `RT-DocLayout`, `PaddleOCR-VL`, `MinerU*` families.

## 3.6 Evidence gate for any model promoted to mobile-offline

No model status can be upgraded beyond `Catalog-only` until each of these are present in `docs/review/evidence/`:

- `.task/.gguf/.onnx/.tflite` artifact hash + model metadata
- Android + iOS install/load/ask proof at least once
- warm/cold latency + RSS/memory + timeout + retry + cancellation telemetry
- grounded output + schema validity + unsupported-field refusal rate
- unsupported-device/unsupported-OS fallback behavior with operator-visible error class

## 4) Android/iOS-aware provider-key inventory (presence only, values redacted)

From project env surfaces under `/Users/pranay/Projects`, present provider key names were found in:

### 4.1 Relevant to this decision

- `medpiper/insurance_app`:
  `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OLLAMA_BASE_URL`, `GROQ_API_KEY`, `GROQ_BASE_URL`, `GROQ_CHAT_MODEL`.
  (`HF_TOKEN` and related HF identifiers are present only in commented template lines in `.env`/`.env.example`.)
- `orbitcover-d2c`:
  `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`, `OPENROUTER_TIER`.
- `comfy`:
  `HF_TOKEN`, `HF_HOME`, `HF_XET_HIGH_PERFORMANCE`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE`.
- `speech_experiments/model-lab`:
  `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `HF_HOME`.
- `invoice-intelligence`:
  `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`.
- `edureka`:
  `OPENAI_API_KEY`, `GROQ_API_KEY`, `GEMINI_API_KEY`, `HUGGINGFACE_API_KEY`.
- `learning_for_kids`:
  `GEMINI_API_KEY`, `HF_TOKEN`, `ECHOPANEL_HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`.
- `adshot`:
  `GEMINI_API_KEY`, `HF_TOKEN`, `REPLICATE_API_TOKEN`.
- `bas5minute`:
  `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`.
- `SentinelTwin`:
  `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TOGETHER_API_KEY`.
- `notes`:
  `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `OLLAMA_HOST`, `OLLAMA_MODEL`.
- `musicathon`:
  `HF_TOKEN`.
- `EchoPanel`:
  `HF_TOKEN`, `ECHOPANEL_HF_TOKEN`.

### 4.2 Noted caveat

Other projects may contain additional provider keys (for example Cohere, AWS, Azure, replicate, etc.), but the list above is the relevant set for model-routing decisions in this pass.

Presence of a key does **not** imply mobile execution wiring.

## 5) Why the shortlist is what it is (reasoning)

### Primary production-safe fallback (today)
1. Keep hosted `OpenAI gpt-5-nano` as the canonical baseline because:
   - it is the only lane with stable policy-grammar/synthetic pass evidence,
   - it already aligns with existing server data-contracts and citation checks,
   - and it is currently the least ambiguous path for release control.

### Paid/comparison lanes (not promoted to mobile-offline)
2. Keep OpenRouter and HF Pro lanes as **evaluation/comparison**:
   - useful for quality/cost routing experiments,
   - but should not be framed as Android/iOS local inference.
3. Keep Modal/HF token infrastructure as **private benchmark/training options**:
   - useful for pre-export/adapter exploration,
   - not Android/iOS-ready by itself.

### Mobile/offline-first sequence
4. Run `Gemma 3n` family first through existing `flutter_gemma` seam once an Android/iOS `.task` artifact and signed manifest exist.
5. Only after that passes, run one small comparator (`Gemma 1B/270M`, `Qwen3 1.7B`, etc.) under the same device matrix and telemetry contract.
6. Delay managed-device paths (`Gemini Nano/AICore`, `Apple Foundation Models`) until dedicated capability probes are added and failures are mapped as supported/unsupported.

## 6) Current execution status from this pass

- `cd mobile && flutter test test/on_device_inference_service_test.dart`  
  ✅ **3/3 pass** (`config compile-path`, `install guard`, install-attempt path guard).
- `cd mobile && flutter test -d F5AC13E5-FDAF-4877-B7FF-4265A3180931 --dart-define=ON_DEVICE_TEST_INSTALL_ATTEMPT=true --dart-define=ON_DEVICE_INFERENCE_ENABLED=true --dart-define=ON_DEVICE_MODEL_URL=https://example.com/model.task test/on_device_inference_service_test.dart`  
  ✅ **passes** by reaching install-path code and capturing a controlled throw in test runtime, which still does **not** equal real `.task` download/load/ask production proof.
- `cd mobile && flutter devices --machine`  
  shows Android emulator and iPhone 17 simulator endpoints, but **no successful `.task` generation run** exists yet.

## 7) What is still missing for "mobile local truth" closure

Before any on-device mobile claim:
- artifact + URL + SHA/size manifest,
- Android + iOS install/download integrity on a real app target,
- warm/cold latency, memory/RSS, thermal, and timeout/cancel behavior,
- cancellation + retry + fallback telemetry,
- schema-valid grounded output pass-rate and unsupported-device map.

Current state summary: **there is strong hosted evidence and strong scaffolding, but no completed Android/iOS local model execution proof path yet.**
