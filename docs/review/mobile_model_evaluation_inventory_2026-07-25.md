# CoverWise mobile model execution inventory — 2026-07-25 (authoritative pass)

This is the most complete “what exists, what was run, what was not run” file for the
**CoverWise Android/iOS policy-RAG lane** as of 2026-07-25.

## Evidence convention

- **EVAL** = reproducible run output exists in this repo for that exact stage/runtime path.
- **SCaffold** = integration code exists, but no Android/iOS on-device run.
- **Catalog-only** = researched/shortlisted only.
- **Hosted-only** = cloud/API lane; not on-device mobile execution.
- **Not run** = no repo evidence in this lane yet.

For the full metrics + cross-project key inventory + rationale + closure gates, use:
[`mobile_model_full_evaluation_compendium_2026-07-25.md`](mobile_model_full_evaluation_compendium_2026-07-25.md).

## 0) What you asked directly

1. **Local Android/iOS options**  
   The only mobile-native runtime seam with code in app is `flutter_gemma` + `flutter_gemma_mediapipe` behind:
   - `ON_DEVICE_INFERENCE_ENABLED=true`
   - `ON_DEVICE_MODEL_URL=<https://...>.task`
2. **Evaluated vs not**  
   - Evaluated: hosted benchmarks + pipeline stages + guard tests (all listed below).
   - Not evaluated on-device: every candidate LLM and managed-runtime path except scaffolded seam.
3. **Transformers.js**  
   Not a Flutter-native Android/iOS model execution lane in this product today; web/mobile-web experiment track only.
4. **HF Pro / Modal / OpenRouter**  
   They are remote/hosted lanes. They are valid for comparison/fallback, not on-device evidence.
5. **Posters after 2024 (2025–2026)**  
   Frontier candidates are cataloged and staged, but none are executed on Android/iOS in this repo yet.

---

## 1) Pipeline-stage truth (policy workflow)

| Stage | Lane / candidate | Runtime class | Status | Evidence |
|---|---|---|---|---|
| Parse / text extraction | PyMuPDF canonical | server pipeline | **EVAL** | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` |
| OCR / layout baseline | Surya-2 (`docTR`-class pathways) | server/local fixture checks | **EVAL (limited)** | `docs/review/evidence/local-model-eval/gemma3-4b-recheck-2026-07-12.json` and related OCR diagnostics |
| Frontier parser candidates (2025–2026) | Docling / MinerU / Marker / RT-DocLayout / Unlimited-OCR / PaddleOCR-VL / Dolphin / Qianfan / etc. | catalog/investigation only | **Catalog-only** | `docs/review/mobile_model_frontier_2024_plus_inventory_2026-07-25.md`, `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md` |
| Chunking / reconstruction | paragraph/entity/entity+adjacent strategy | server pipeline | **EVAL (in use)** | `docs/technical/rag/exploration/chunking_parsing_embedding_exploration_2026-07-22.md`, `policy` corpus usage evidence |
| Embeddings / retrieval | `text-embedding-3-small` hosted | server | **EVAL** | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` |
| Local embedding candidates | EmbeddingGemma / Qwen3-Embedding | planned mobile-native | **Catalog-only** | `docs/review/mobile_model_strict_matrix_2026-07-24.md` |
| Hosted generation | OpenAI `gpt-5-nano` | cloud | **EVAL** | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`, `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json`, `.../policy-corpus-ragas-2026-07-24.json` |
| Hosted generation compare | OpenRouter `google/gemini-2.5-flash-lite` | cloud | **EVAL (comparison-only)** | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json`, `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json` |
| Hosted generation compare | OpenRouter `google/gemma-3-4b-it` | cloud | **EVAL (comparison-only)** | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` |
| Hosted generation compare | HF Pro `Qwen/Qwen3-4B-Instruct-2507` | cloud | **EVAL (comparison-only)** | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json`, `docs/review/evidence/provider-smoke/continuation-hf-2026-07-25.json` |
| Hosted desktop dev lane | Ollama `gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`; DeepSeek OCR adapter | workstation/dev | **EVAL (non-mobile)** | `docs/review/evidence/local-model-eval/*.json` |
| Local/offline mobile seam | `flutter_gemma` + `flutter_gemma_mediapipe` + `.task` hooks | Android/iOS bridge | **SCaffold** | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`, `mobile/test/on_device_inference_service_test.dart` |
| Managed native mobile | Android Gemini Nano/AICore | device-managed OS runtime | **Not integrated/run** | no in-app probe in CoverWise |
| Managed native mobile | Apple Foundation Models | device-managed OS runtime | **Not integrated/run** | no in-app probe in CoverWise |
| Visual fallback VLM candidates | Qwen3-VL / PaddleOCR-VL / other OCR-capable VLMs | candidate / second-stage | **Catalog-only** | `docs/review/mobile_model_general_vlm_frontier_2026-07-24.md`, `docs/review/mobile_model_frontier_2024_plus_inventory_2026-07-25.md` |

### Policy-doc evidence currently available

- `policy-corpus-ragas-2026-07-24.json`  
  - `total_questions`: 52  
  - `accuracy`: `0.5577` (29/52)  
  - `citation_rate`: `0.9615`  
  - `hallucination_rate`: `0.3333`

---

## 2) Exact “evaluated vs not” model/lane matrix (stage-aware)

### 2A. Hosted/paid lanes (comparison only)

| Lane | Stage | Status | Last result | Why not mobile-offline |
|---|---|---|---|---|
| OpenAI `gpt-5-nano` | hosted generation baseline | **EVAL** | 52Q policy + synthetic success path (`3/3` in `continuation-smoke-2026-07-25.json` and `openai-synthetic-2026-07-24-success.json`) | Cloud API |
| OpenRouter `google/gemini-2.5-flash-lite` | hosted generation compare | **EVAL (limited)** | `2/3` synthetic pass (`openrouter-synthetic-...json`, confirmed in `continuation-openrouter-2026-07-25.json`) | Cloud API |
| OpenRouter `google/gemma-3-4b-it` | hosted generation compare | **EVAL (limited)** | `1/3` synthetic pass (`openrouter-gemma3-4b-synthetic-...json`) | Cloud API |
| HF Pro / HF Inference (`Qwen/Qwen3-4B-Instruct-2507`) | hosted generation compare | **EVAL (limited)** | `2/3` synthetic pass (`hf-qwen3-synthetic-...json`) | API credits only; no local artifact install |
| Modal Labs (`MODAL_TOKEN_*`) | private GPU benchmark path | **Context only** in this pass | key-surface found; no CoverWise mobile execution endpoint evidence | private hosted infra |

### 2B. Mobile/offline candidates (status today)

| Candidate | Runtime path | Stage intent | Status | Why |
|---|---|---|---|---|
| `flutter_gemma` seam (`ON_DEVICE_*` feature flags) | Flutter bridge | all generation + retrieval-support experiments | **SCaffold** | runtime flags exist; no `.task` install/run on device |
| Gemma 3n E2B / E4B | `.task` + MediaPipe/LiteRT | first local generation lane | **Catalog-only** | no artifact/hash/install/telemetry evidence |
| Gemma 3 270M / 1B | `.task` / portable export | local classification/compact generation | **Catalog-only** | no export + mobile run |
| Qwen3 0.6B / 1.7B / 4B | `.task` / export | local generation compare | **Catalog-only** | no export + mobile run |
| Phi-4-mini / SmolLM3 / Ministral 3B | `.task` / export | compact local generation | **Catalog-only** | no export + mobile run |
| `Qwen3-VL` / `PaddleOCR-VL` / `Dolphin` / `Unlimited-OCR` / `RT-DocLayout` / `MeDocVL` / etc. | mobile local visual fallback | recovery for OCR/layout failures | **Catalog-only** | no mobile recovery implementation/runs |
| Fine-tuned/LoRA lanes | model asset + tokenizer + export | custom adapter route | **Catalog-only / not wired** | no artifact lineage + no mobile export |

---

## 3) 2025–2026 frontier (after 2024) status by subgroup

Source files:  
- `docs/review/mobile_model_frontier_2024_plus_inventory_2026-07-25.md`  
- `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md`  

### 3A. High-priority parser / layout frontier (not yet on-device in CoverWise)

- `Unlimited-OCR` (2026-06, Baidu)
- `RT-DocLayout` (2026-06, Baidu)
- `PaddleOCR-VL-1.6` (2026-06)
- `PP-OCRv6` (2026-06)
- `MinerU-Popo`, `MinerU2.5-Pro`, `MinerU-Diffusion` (2026-04/2025-09/2026-03)
- `Marker 1.10.1`, `Docling`-adjacent methods
- `AgenticOCR`, `Logics-Parsing`, `Logics-Parsing-Omni`
- `Qianfan-OCR`, `dots.mocr`/`dots.ocr`, `FireRed-OCR`, `GLM-OCR`, `Agentar-Fin-OCR`
- `Dolphin-1.5`, `Dolphin-2.0`  
- `DeepSeek-OCR`, `DeepSeek-OCR2`
- `MeDocVL`, `SmolDocling-256M`, `Granite-Docling-258M`, `Marker` family

### 3B. General frontier VLMs (for possible second-stage visual fallback)

Listed as candidates only. No runtime execution path is present in this repo:
- `Qwen3-VL 2B/4B`, `Qwen2-VL`, `GPT-5`, `GPT-4o`, `Gemma-VL`, `LLaVA`, `MiniCPM-V`, `Claude/Gemini/Grok` family comparators.

---

## 4) Android/iOS key-space and routing surface discovered in `.env` files

Presence only; no values were read.

- `medpiper/insurance_app`: `OPENAI_API_KEY`, `HF_TOKEN`, `OLLAMA_BASE_URL`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `GROQ_API_KEY`
- `orbitcover-d2c`: `OPENROUTER_API_KEY`
- `comfy`: `HF_TOKEN`, `HF_HOME`, `HF_XET_HIGH_PERFORMANCE`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`
- `speech_experiments/model-lab`: `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `HF_HOME`
- `invoice-intelligence`: `OPENAI_API_KEY`, `OPENROUTER_API_KEY`
- `edureka`: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY`, `HUGGINGFACE_API_KEY`
- `learning_for_kids`: `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`, `GEMINI_API_KEY`
- `adshot`: `HF_TOKEN`, `GEMINI_API_KEY`
- `bas5minute`: `OPENAI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`
- `SentinelTwin`: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TOGETHER_API_KEY`
- `notes`: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`
- `musicathon`: `HF_TOKEN`
- `EchoPanel`: `HF_TOKEN`

Interpretation: provider key presence means possible routing experiments, **not** active mobile execution contracts.

---

## 5) Why you do not install Ollama/MLX/Transformers.js/Modal/OpenRouter on mobile for this lane

- **Ollama/MLX**: desktop/client workstation runtime, not Android/iOS user runtime.
- **Transformers.js**: browser/WebGPU/ONNX runtime path; no Flutter-native execution contract documented for this production lane.
- **OpenRouter/HF Pro/Modal/OpenAI**: hosted endpoints with API credentials and quotas; not device-local execution.

---

## 6) What to run next (shortlist + reasons)

### Immediate next execution batch (single-source-of-truth order)

1. **Gate**: build/install readiness matrix for `ON_DEVICE_*` config and explicit artifact hash.
2. **T2A**: `Gemma 3n E2B` shared lane through `flutter_gemma` on iOS simulator + Android matrix.
3. **T2B**: benchmark manifest for warm/cold latency, memory/RSS, thermal drift, timeout/cancel/retry, output schema+refusal rate.
4. **T3**: if T2A passes, run one compact comparator (`Gemma 3 270M/1B` or `Qwen3 1.7B`) with same manifest.
5. **T4**: if parser failures remain high, add managed-native probes (Nano/AICore + Foundation Models) and visual-stage fallback candidates.
6. **Never treat** any hosted lane as mobile-offline until steps 2–3 pass in real device logs.

### Deployment decision rationale (today)

- **Keep as default today:** hosted `gpt-5-nano` (strongest available policy-grounded baseline evidence in repo, with hosted evidence gates).
- **Do not promote yet:** all local/offline candidates, including `Gemma 3n`, `Qwen3-*`, `Phi-4-mini`, `SmolLM3`, `Ministral`, `Qwen3-VL`.
- **Do not treat managed models as already active:** no managed-device probe integrated in app yet.

---

## 7) Evidence anchors

- `mobile/lib/services/on_device_inference_service.dart`
- `mobile/lib/config/app_config.dart`
- `mobile/test/on_device_inference_service_test.dart`
- `docs/technical/mobile_local_model_evaluation_2026-07-24.md`
- `docs/review/mobile_model_exploration_map_2026-07-24.md`
- `docs/review/mobile_model_strict_matrix_2026-07-24.md`
- `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`
- `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json`
- `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json`
- `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json`
- `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json` (OpenAI `gpt-5-nano`, `3/3`, median 1619ms)
- `docs/review/evidence/provider-smoke/continuation-openrouter-2026-07-25.json` (OpenRouter gemini-2.5-flash-lite, `2/3`, median 1025ms)
- `docs/review/evidence/provider-smoke/continuation-hf-2026-07-25.json` (HF Pro Qwen/Qwen3-4B-Instruct-2507, `2/3`, median 1026ms)
- `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json`

## 8) Environment-key surface relevance check (provider routing potential)

From project `.env/.env.example` surfaces (presence only, values redacted), current relevant capability context is:

| Project | Keys seen | What this means for this lane |
|---|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `HF_TOKEN`, `OLLAMA_BASE_URL` | Hosted OpenAI is the active policy routing lane; local `.task` on-device is only scaffolded by flags. |
| `orbitcover-d2c` | `OPENROUTER_API_KEY` | OpenRouter routing exists in another project; no CoverWise mobile runtime wiring. |
| `comfy` | `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` | HF/Modal experimentation surface present for benchmarking/private GPU. |
| `speech_experiments/model-lab` | `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` | HF experimentation surface; no CoverWise on-device wiring. |
| `invoice-intelligence` | `OPENAI_API_KEY`, `OPENROUTER_API_KEY` | Hosted provider lane only. |
| `adshot` | `HF_TOKEN`, `GEMINI_API_KEY` | Hosted/composable AI project context only. |
| `notes` | `OPENAI_API_KEY`, `OLLAMA_HOST` | Local desktop host routing only. |
| `EchoPanel` | `HF_TOKEN` | Hosted HF use only. |
| `bas5minute` | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `HF_TOKEN`/`HUGGINGFACE_API_KEY` | Multi-provider experimentation. |
| `SentinelTwin` | `OPENAI_API_KEY`, `GEMINI_API_KEY` | Hosted/computing only. |
| `edureka` | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `HF_TOKEN` (via `HUGGINGFACE_API_KEY`) | Hosted/composition. |
| `oc-b2b` | (no `.env/.env.example` key hits found in checked scan) | No routing evidence discovered in checked files. |
| `oc-mobile` | (no `.env/.env.example` key hits found in checked files) | No routing evidence discovered in checked files. |

Interpretation:

- Key presence in `.env` gives a capability or comparison lane, **not** a claim of mobile execution in CoverWise.
- For the user-facing mobile path, only `medpiper/insurance_app` contains in-product configuration hooks for local generation (`ON_DEVICE_*` flags), and those are still scaffold-only.

## 9) What’s actually been tested in this pass (and what remains blocked)

- `cd mobile && flutter pub get`  
  - Status: **passes**, dependencies now resolved in this worktree.
- `cd mobile && flutter test test/on_device_inference_service_test.dart`  
  - Status: **passes** (3/3 harness checks), both by default test host and target-device invocation.
- `cd mobile && flutter devices`  
  - Status: connected devices detected (`iPhone 17` simulator, macOS, Chrome).
- Real Android/iOS install/load/ask path for `.task` remains **not executed** (no `.task` artifact in-repo).

## 10) Practical selected/fallback shortlist (reasoned, now)

### Primary production-safe fallback (today)

1. `OpenAI gpt-5-nano` (hosted, reproducible policy corpus + smoke evidence)
   - Reason: strongest baseline evidence for policy-grounded answers.

### Paid/cloud compare lanes

2. `OpenRouter` (`gemini-2.5-flash-lite`, `gemma-3-4b-it`) and `HF Pro Qwen3-4B`  
   - Reason: useful comparator cost/quality signals, but **not** mobile-offline.

### Private benchmark infrastructure

3. `Modal Labs` tokens/surface + HF ecosystem tools (`speech_experiments`, `comfy`)  
   - Reason: high-throughput GPU compare/fine-tune lane for offline-lane design, not user-phone execution.

### Mobile/edge first milestone

4. `flutter_gemma` + Gemma-3n (E2B first, then E4B)
   - Reason: only first-class mobile-native route available in CoverWise code today; must complete: model artifact + install + Android/iOS matrix + telemetry + fallback proof.

### Secondary edge comparators after Gate 1

5. `Gemma 3 270M/1B`, `Qwen3 1.7B`, `Phi-4-mini`, `SmolLM3`, `Ministral 3B`
   - Reason: compact candidates only after Gemma-3n shared-lane proves runtime viability.

### Managed-OS / managed-runtime path (deferred)

6. `Gemini Nano/AICore` and `Apple Foundation Models`
   - Reason: requires explicit in-app probe matrix on supported/unsupported hardware; not implemented as product path yet.
