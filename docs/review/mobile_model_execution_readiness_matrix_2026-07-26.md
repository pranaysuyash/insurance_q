# Mobile model execution readiness matrix (2026-07-26)

This is the consolidated "I actually did something now" artifact for model/lane status.

**Scope checked:** `medpiper/insurance_app` + mobile docs under `docs/review/` + key-surface scan across `/Users/pranay/Projects` `.env*` files.

## 1) Truth rule used

- **EVAL:** reproducible run output exists for that exact stage/runtime in this repo.
- **SCaffold:** integration exists in code/tests/config, but no Android/iOS install/load/ask model execution trace.
- **Catalog-only:** listed in the frontier/research set, not yet executed on Android/iOS.
- **Context-only:** key/token/project infra exists, not routed into CoverWise mobile runtime.

## 2) Provider + model status (what has been evaluated today)

### 2.1 Hosted lanes (cloud, not mobile-offline)

| Lane | Stage | Evidence | Result |
|---|---|---|---|
| OpenAI `gpt-5-nano` | Hosted generation + policy grounding | `docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json` | `3/3` |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted generation comparator | `docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json` | `2/3` |
| OpenRouter `google/gemma-3-4b-it` | Hosted generation comparator | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | `1/3` |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | Hosted generation comparator | `docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json` | `2/3` |
| Hosted policy-corpus QA | End-to-end pipeline QA | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | `accuracy=0.5577`, `citation_rate=0.9615`, `hallucination_rate=0.3333` |

### 2.2 Desktop/local non-mobile checks

| Lane | Stage | Evidence | Result |
|---|---|---|---|
| Ollama / DeepSeek-ocr local checks | Desktop local/off-path server | `docs/review/evidence/local-model-eval/*.json` | Real values from these files are useful for local compatibility only; no Android/iOS runtime claim |

### 2.3 Mobile runtime lanes

| Lane | Stage | Status | Evidence |
|---|---|---|---|
| `flutter_gemma` (`ON_DEVICE_*` flags + service) | Android/iOS generation seam + local control path | **SCaffold** | `mobile/lib/config/app_config.dart`, `mobile/lib/services/on_device_inference_service.dart`, `mobile/test/on_device_inference_service_test.dart`, `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26.json` |
| Gemma 3n E2B/E4B `.task` | Android/iOS shared inference execution | **Catalog-only** | candidate only, no `.task` install/load/ask evidence |
| Gemma 3 270M / 1B | Android/iOS shared/local inference | **Catalog-only** | no exported artifact + no mobile run |
| Qwen3 0.6B / 1.7B / 4B | Android/iOS shared/local inference | **Catalog-only** | no exported artifact + no mobile run |
| Phi-4-mini / SmolLM3 / Ministral 3B | Android/iOS shared/local inference | **Catalog-only** | no exported artifact + no mobile run |
| Android managed (`Gemini Nano`/AICore) | managed OS-native managed generation | **No-path** | no in-app device probe in this repo |
| iOS managed (`Apple Foundation Models`) | managed OS-native managed generation | **No-path** | no in-app device probe in this repo |
| Transformers.js / WebGPU / ONNX Web path | Browser/mobile-web experiment | **No-path (for Flutter native)** | not used as Flutter-native Android/iOS model execution in this product lane |

## 3) 2025–2026 frontier models/status by stage (from `document_parsers_extractors_catalog_2026_v2.xlsx`)

I treated all parsed frontier models as pipeline-stage candidates from the catalog; none are Android/iOS-evaluated yet unless stated in section 2.

### 3.1 Ingestion / layout / OCR candidates (most relevant this pass)

- **2026 selection:** `Infinity-Parser2`, `RT-DocLayout`, `Unlimited-OCR`, `PaddleOCR-VL-1.6`, `PP-OCRv6`, `MinerU-Popo`, `Qianfan-OCR`, `dots.mocr`, `AgenticOCR`, `Logics-Parsing(-Omni)`, `PaddleOCR-VL (coarse-to-fine)`, `Dolphin-2.0`, `GLM-OCR`, `DeepSeek-OCR 2`, `PaddleOCR-VL-1.5`, `OCRVerse`, `GutenOCR`, `Typhoon-OCR`, `LightOnOCR`, `MeDocVL`, etc.
- **2025 selection:** `Marker 1.10.1`, `SmolDocling-256M`, `Granite-Docling-258M`, `MinerU 2.5`, `MonkeyOCR*`, `Dolphin-1.5`, `DianJin-OCR-R1`, `PP-StructureV3`.
- **General OCR/VLM frontier (not parsed above):** `GPT-5 (2025-08-07)`, `Gemma 4 12B`, `LLaVA-OneVision 2`, `MiniCPM-V-4.6`, etc.

**Status for all above:** `Catalog-only` in this repo pass, no on-device execution proof yet.

### 3.2 Why this does not become a mobile shortlist by default

- They are parser/vision improvements for stage-level extraction quality and must still pass the same Android/iOS on-device artifact, install, and runtime telemetry gates.
- For this release, they are not production shortcuts for mobile inference by default.

### 3.3 Full frontier list (all 77 entries, status unchanged until mobile device evidence exists)

All 77 entries from `/Users/pranay/Downloads/researches_lists/document_parsers_extractors_catalog_2026_v2.xlsx` that were ingested into
`docs/review/evidence/local-model-eval/recent_models_2024_plus_inventory_2026-07-25.json` remain `Catalog-only` for mobile execution in this lane.

### 3.3a Full frontier ledger (all 77 entries, mobile status = catalog-only unless proven)

| Year | Model | Focus | Artifact class | Mobile status | Why |
|---|---|---|---|---|---|
| 2026 | Infinity-Parser2 | Long-form structured document parsing | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | HunyuanOCR-1.5 | Lightweight OCR VLM; faster and improved parsing | Specialist OCR VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | SAYRE | Scene-aware document synthesis for KIE | Training/data method | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | P-MTP | Efficient document parsing with multi-token prediction | Training/decoding method | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | RT-DocLayout | Real-time layout analysis and reading order | Layout model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Unlimited-OCR | One-shot long-horizon OCR and document parsing | Specialist OCR/document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Beaver | Scientific curation from multimodal sources | Document agent/system | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Agents-K1 | Agent-native knowledge orchestration | Document agent/model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | PaddleOCR-VL-1.6 | Multilingual document parsing and region refinement | Specialist document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | PP-OCRv6 | Compact text recognition OCR models | Classical/small OCR model family | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | MinerU-Popo | Universal post-processing for structured parsing | Post-processing model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | RTPrune | Token pruning for DeepSeek-OCR inference | Inference optimization | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | ABot-OCR | End-to-end document OCR | Specialist OCR model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | BabelDOC | Layout-preserving PDF translation via intermediate representation | PDF translation/parser pipeline | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Consensus Entropy | Multi-VLM agreement for self-verifying OCR | Verification/ensemble method | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | FastOCR | KV-cache pruning for efficient document parsing | Inference optimization | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | MinerU2.5-Pro | Data-centric high-accuracy structured parsing | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | PixelPrune | Adaptive visual-token reduction | Inference optimization | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | TexOCR | Compilable page-to-LaTeX reconstruction | Specialist scientific OCR VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Falcon OCR / Falcon Perception | Document perception and OCR | Specialist OCR/document model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | MinerU-Diffusion | OCR as inverse rendering with diffusion decoding | Specialist OCR research model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Qianfan-OCR | Unified end-to-end document intelligence | Specialist OCR/document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | dots.mocr | Multimodal OCR and broad document parsing | Specialist multimodal OCR | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | FireRed-OCR | Complex document OCR | Specialist OCR model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | AgenticOCR | Selective parsing for retrieval and RAG | Query-adaptive parser/agent | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | PTP | Parallel token prediction for document parsing | Decoding/training method | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Logics-Parsing-Omni | Layout, reading order and structured parsing | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Agentar-Fin-OCR | Financial document OCR and extraction | Domain-specific financial OCR | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | PaddleOCR-VL (coarse-to-fine) | Efficient coarse-to-fine visual document parsing | Specialist document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | DODO | Discrete diffusion models for OCR | Specialist OCR research model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | HSD | Hierarchical speculative decoding for document VLMs | Inference acceleration | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | MeDocVL | Medical document understanding and parsing | Domain-specific medical document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Dolphin-2.0 | Universal document parsing with scalable anchor prompting | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | GLM-OCR | Complex document OCR, tables, formulas and KIE | Specialist OCR/document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | OCR-Agent | Agentic OCR with capability and memory reflection | OCR agent/system | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | OmniOCR | OCR for ethnic-minority languages | Specialist multilingual OCR | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | PaddleOCR-VL-1.5 | Robust in-the-wild multi-task parsing | Specialist document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | OCRVerse | End-to-end OCR across multiple tasks | Specialist holistic OCR VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | DeepSeek-OCR 2 | Visual causal flow for OCR and structured parsing | Specialist OCR/document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Youtu-Parsing | Perception, structuring and recognition with parallel decoding | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | Typhoon-OCR | Thai document extraction | Language-specific document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | GutenOCR | Grounded OCR front-end for documents | Grounded document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2026 | LightOnOCR | Compact 1B end-to-end OCR | Specialist multilingual OCR VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Uni-Parser | General structured document parsing | Specialist document parser | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | TRivia | Self-supervised VLM fine-tuning for table recognition | Table-recognition model/method | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | DOCR-Inspector | Fine-grained automated evaluation of document parsing | Evaluator | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | UniRec-0.1B | Unified text and formula recognition | Text/formula recognition model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | HunyuanOCR | End-to-end document OCR | Specialist OCR/document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | MonkeyOCR v1.5 | Robust parsing for complex patterns | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Doc-Researcher | Multimodal parsing plus deep document research | Document parsing/research system | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | olmOCR 2 | PDF-to-clean-text parsing trained with unit-test rewards | Specialist OCR VLM/toolkit | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Chandra v0.1.0 | PDF/image to structured text and Markdown | Specialist document OCR/parser | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | DeepSeek-OCR | OCR through optical-context compression | Specialist OCR/document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Infinity-Parser | Layout-aware RL for scanned-document parsing | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Nanonets-OCR 2 | Documents to LLM-ready structured data | Specialist OCR/document model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | PaddleOCR-VL | 0.9B multilingual parser for text, tables, formulas and charts | Specialist document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Dolphin-1.5 | Heterogeneous-anchor document image parsing | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Logics-Parsing | Layout and reading-order-aware parsing | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Granite-Docling-258M | Small document conversion model for Docling | Compact specialist document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Marker 1.10.1 | PDF and document conversion to Markdown/JSON | Document parsing toolkit/model pipeline | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | MinerU 2.5 | Efficient high-resolution parsing | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | DianJin-OCR-R1 | OCR with reasoning and tool use | Reasoning/tool-interleaved OCR VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | dots.ocr | Multilingual layout parsing in a single VLM | Specialist document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | MonkeyOCR-Pro | Structure-recognition-relation triplet parsing | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | OCRFlux | Complex layouts and cross-page merging | Specialist document parser | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | MinerU2.0-2505-0.9B | Compact MinerU document parsing model | Specialist document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | MonkeyOCR | Structure-recognition-relation triplet parsing | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Dolphin | Document image parsing via heterogeneous anchor prompting | Specialist document parser/VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | GTR-VL | Molecular structure recognition | Domain-specific visual extractor | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | SmolDocling-256M | End-to-end multimodal document conversion | Compact specialist document VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | olmOCR | PDF linearization into clean, naturally ordered text | Specialist OCR VLM/toolkit | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | PP-StructureV3 | Layout, tables, formulas, OCR and document reconstruction | Document structure pipeline | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2025 | Ocean-OCR | General OCR applications using a VLM | Specialist OCR VLM | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2024 | MarkItDown | Office/PDF/media to Markdown conversion | Multi-format parser/converter | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2024 | GOT-OCR 2.0 | Unified end-to-end OCR for text, formulas and structured content | Specialist unified OCR model | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2024 | MinerU | Precise extraction of text, tables, formulas, images and reading order | Document parsing toolkit/pipeline | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |
| 2024 | open-parse | Visually aware PDF parsing and semantic chunking | Document parser | Catalog-only | no `.task`/`.gguf`/`.onnx`/`.safetensors` artifact or install/ask trace in this repo |

- 2026 models: `ABot-OCR`, `Agentar-Fin-OCR`, `AgenticOCR`, `Agents-K1`, `BabelDOC`, `Beaver`, `Consensus Entropy`, `DODO`, `DeepSeek-OCR 2`, `Dolphin-2.0`, `Falcon OCR / Falcon Perception`, `FastOCR`, `FireRed-OCR`, `GLM-OCR`, `GutenOCR`, `HSD`, `HunyuanOCR-1.5`, `Infinity-Parser2`, `LightOnOCR`, `Logics-Parsing-Omni`, `MeDocVL`, `MinerU-Diffusion`, `MinerU-Popo`, `MinerU2.5-Pro`, `OCR-Agent`, `OCRVerse`, `OmniOCR`, `P-MTP`, `PP-OCRv6`, `PTP`, `PaddleOCR-VL (coarse-to-fine)`, `PaddleOCR-VL-1.5`, `PaddleOCR-VL-1.6`, `PixelPrune`, `Qianfan-OCR`, `RT-DocLayout`, `RTPrune`, `SAYRE`, `TexOCR`, `Typhoon-OCR`, `Unlimited-OCR`, `Youtu-Parsing`, `dots.mocr`
- 2025 models: `Chandra v0.1.0`, `DOCR-Inspector`, `DeepSeek-OCR`, `DianJin-OCR-R1`, `Doc-Researcher`, `Dolphin`, `Dolphin-1.5`, `GTR-VL`, `Granite-Docling-258M`, `HunyuanOCR`, `Infinity-Parser`, `Logics-Parsing`, `Marker 1.10.1`, `MinerU 2.5`, `MinerU2.0-2505-0.9B`, `MonkeyOCR`, `MonkeyOCR v1.5`, `MonkeyOCR-Pro`, `Nanonets-OCR 2`, `OCRFlux`, `Ocean-OCR`, `PP-StructureV3`, `PaddleOCR-VL`, `SmolDocling-256M`, `TRivia`, `Uni-Parser`, `UniRec-0.1B`, `dots.ocr`, `olmOCR`, `olmOCR 2`
- 2024 models: `GOT-OCR 2.0`, `MarkItDown`, `MinerU`, `open-parse`

## 4) Cross-project key surface inventory (values redacted)

Relevant keys present in local project env files:

- `medpiper/insurance_app`: `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL`, `OPENAI_EMBEDDING_MODEL`, `OLLAMA_BASE_URL`, `GROQ_API_KEY` (example)
- `orbitcover-d2c`: `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`, `OPENROUTER_TIER`
- `comfy`: `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `MODAL_PROFILE`
- `speech_experiments/model-lab`: `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`
- `invoice-intelligence`: `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`
- `learning_for_kids`: `HF_TOKEN`, `GEMINI_API_KEY`
- `edureka`: `OPENAI_API_KEY`, `GROQ_API_KEY`, `HUGGINGFACE_API_KEY`, `GEMINI_API_KEY`
- `adshot`: `HF_TOKEN`, `GEMINI_API_KEY`
- `bas5minute`: `OPENAI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`
- `SentinelTwin`: `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TOGETHER_API_KEY`
- plus several non-model helper `.env` files where only local research keys exist.

No `.env` scan in this pass surfaced a mobile-ready `.task`/`.gguf`/`.onnx` artifact binding for CoverWise Android/iOS inference.

### 4.1 Runtime asset scan in repo (authoritative check)

- Searched repo for mobile inference assets: `.task`, `.gguf`, `.onnx`, `.safetensors`, `.tflite`.
- Result: no `.task` or `.gguf` files; no model-ready `.onnx`/`.safetensors` model artifacts in app/product source.
- The only relevant `.tflite` files are MLKit OCR resources inside iOS pods (not CoverWise model-execution artifacts):
  - `mobile/ios/Pods/MLKitTextRecognition/Resources/LatinOCRResources/tflite_langid.tflite`
  - `mobile/ios/Pods/MLKitTextRecognition/Resources/LatinOCRResources/rpn_text_detector_mobile_space_to_depth_quantized_v2.tflite`

## 5) Shortlisted for next execution cycle (reasoned)

### Primary selected now

1. **`flutter_gemma` + Gemma 3n task candidate (A/B route)**
   - Reason: direct alignment with current Flutter seam and existing local capability contract.
   - Blocking gate: signed mobile artifact + install/load/ask telemetry on Android + iOS.

2. **Hosted `gpt-5-nano` keeps the production safe path**
   - Reason: currently the only hosted lane with stable reproducible policy QA + provider smoke continuity.

### Deferred with explicit block

1. `Transformers.js`, `Ollama`, `MLX` as "mobile-offline defaults" for CoverWise.
   - Reason: they are desktop/server/web paths, not Android/iOS app-native model runtime in this lane.
2. `OpenRouter` / `HF Pro` / `Modal Labs` as mobile-offline by default.
   - Reason: paid cloud/private GPU lanes help exploration and comparison; they are not on-device runtime claims without exported assets and device telemetry.
3. `Qwen3-VL`, `PaddleOCR-VL`, etc.
   - Reason: these are second-stage visual recovery lanes; they should be staged only after parser baseline and on-device generation baseline are proven.

## 6) What changed/what this file adds vs previous status

- Adds an explicit single source of truth for which lanes are evaluated now vs catalog-only.
- Confirms no evidence of Android/iOS `.task` install/load/ask has been completed in the repo so far.
- Confirms provider keys are abundant across projects, but routing evidence for mobile runtime remains limited to scaffold-only `flutter_gemma`.
- Confirms 2025–2026 frontier is rich for parser/OCR exploration, but still **all catalog-only** for this mobile run.
