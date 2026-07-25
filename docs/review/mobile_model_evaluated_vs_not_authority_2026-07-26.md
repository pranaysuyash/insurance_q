# Mobile model evaluated-vs-not authority map (2026-07-26)

**Purpose:** answer “what has actually been evaluated” vs “what is only catalog/plan,” for CoverWise mobile (Android/iOS) and its policy-RAG pipeline.

**Evidence rule used in this update**
- **EVAL:** reproducible evidence artifact exists for this stage/runtime in this repository.
- **SCaffold:** code/tests/config exist, but no real Android/iOS install/load/ask evidence.
- **Catalog-only:** shortlisted or mentioned, no repo run evidence in this mobile lane.
- **No-path:** not wired to CoverWise mobile route.

## 1) Mobile runtime lane truth (Android/iOS first)

### 1.1 Candidate families

| Candidate family | Runtime lane | Mobile status | Evidence basis |
|---|---|---|---|
| `flutter_gemma` + `flutter_gemma_mediapipe` | Native Flutter bridge (`ON_DEVICE_*` path) | **SCaffold** | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`, `mobile/test/on_device_inference_service_test.dart`, harness `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26.json` |
| Gemma 3n E2B / E4B `.task` | Native Android/iOS inference | **Catalog-only** | No `.task` artifact + no install/load/ask trace in repo run evidence |
| Gemma 3 270M / 1B | Native Android/iOS inference | **Catalog-only** | No exported/mobile artifact + no mobile-stage run |
| Qwen3 0.6B / 1.7B / 4B | Native Android/iOS inference (portable) | **Catalog-only** | No export + no mobile-stage run |
| Phi-4-mini / SmolLM3 / Ministral 3B | Native Android/iOS inference (compact) | **Catalog-only** | No mobile export/run evidence |
| Qwen3-VL 2B / 4B | Visual recovery/mobile VLM stage | **Catalog-only** | No on-device visual-stage benchmark in this pass |
| EmbeddingGemma / Qwen3-Embedding families | On-device embedding + retrieval | **Catalog-only** | No on-device embedding benchmark artifact in CoverWise lane |

### 1.2 Managed platform lanes

| Platform-managed lane | Mobile status | Evidence basis |
|---|---|---|
| Android managed (`Gemini Nano` / `AICore`) | **No-path in this repo pass** | No in-app capability probe traces in repo for supported/unsupported SKUs |
| iOS managed (`Apple Foundation Models`) | **No-path in this repo pass** | No iOS managed capability + fallback telemetry in repo pass |

## 2) Hosted/comparison lanes (paid or tokened)

| Lane | Status | Evidence basis | Mobile-offline claim |
|---|---|---|---|
| OpenAI (`gpt-5-nano`) | **EVAL** | `docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json` (3/3), `docs/review/evidence/provider-smoke/continuation-smoke-2026-07-25.json`, `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | No, cloud only |
| OpenRouter (`google/gemini-2.5-flash-lite`) | **EVAL (partial)** | `docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json` (2/3), earlier `openrouter-synthetic-2026-07-24.json` | No, cloud only |
| OpenRouter (`google/gemma-3-4b-it`) | **EVAL (partial)** | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` (1/3) | No, cloud only |
| HF Pro / HF Inference (`Qwen/Qwen3-4B-Instruct-2507`) | **EVAL (partial)** | `docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json` (2/3) | No, cloud only |
| Modal endpoint lane (`comfy` project) | **Context-only** | `comfy/.env` key surface, no CoverWise mobile endpoint wiring | No, no mobile bridge here |

## 3) Key-surface mapping by project (who has what, and what it means)

| Project surface | Keys found | Mobile inference meaning for CoverWise |
|---|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OLLAMA_BASE_URL` (`.env`); `OPENROUTER` / `HF` active keys are in other projects | Hosted baseline and local-server bench keys only; no active `ON_DEVICE_*` pair in active app env |
| `orbitcover-d2c` | `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` | Benchmark/integration lane only in another project |
| `comfy` | `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE` | Private GPU benchmark infra only |

Source: [mobile_model_key_surface_inventory_2026-07-25.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_key_surface_inventory_2026-07-25.md)

## 4) Transformers.js / web/mobile-web question

- **Status:** **No-path** for native Android/iOS production route.
- It is only in-browser/runtime experimentation context in this repo’s current path, not a Flutter-native mobile bridge that runs as Android/iOS on-device inference.

## 5) Frontier catalog (2025–2026) relevance for this pass

Source catalog ingested from `document_parsers_extractors_catalog_2026_v2.xlsx` and rendered as:
- `docs/review/evidence/local-model-eval/recent_models_2024_plus_inventory_2026-07-25.json` (77 entries)
- `docs/review/mobile_model_frontier_appendix_2026_07_25.md`

**Current status for frontier set in this repo pass:** **Catalog-only for mobile** unless it appears in “1.1” above.

Top parser/OCR frontier groups in the shortlist:
- `Docling`-adjacent / compact Docling variants (`Granite-Docling-258M`, `Marker`, `SmolDocling-256M`)
- `RT-DocLayout`, `Unlimited-OCR`, `PaddleOCR-VL` variants, `MinerU*`, `AgenticOCR`, `Logics-Parsing`, `Dolphin`, `Qwen3-VL`

## 6) Fine-tune / adapter lane reality

- No production-ready mobile-ready fine-tune (LoRA/adapter/merged checkpoint) has been executed in the CoverWise mobile path yet.
- Treat “fine-tuned” as asset-state, not a selectable local model lane, until: base model + tokenizer + merge format + quantization target + mobile artifact manifest are proven in mobile execution.

## 7) Why this matters for your shortlist decision now

- If your default target is Android/iOS local inference for policy workflows, the only lane that is currently beyond **catalog/scaffold** is still the hosted path.
- A model is promoted for mobile-local only after we have: 1) mobile artifact, 2) Android+iOS install/load/ask telemetry, 3) policy answer validation + fallback logs.

