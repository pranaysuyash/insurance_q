# Mobile model frontier evidence compendium (2024–2026, as of 2026-07-26)

Total models: **77** from `recent_models_2024_plus_inventory_2026-07-25.json`
Year split: 2024=4, 2025=30, 2026=43

## Pipeline-stage reality check

| Stage | Mobile (Android+iOS) status | Evidence-backed reason |
|---|---|---|
| Parsing/ingestion | **Catalog-only** | 77-model frontier only; no on-device parser artifacts/runtime in repo. |
| Embedding | **Catalog-only** | No mobile-quantized embedding artifacts validated on-device. |
| Retrieval/rerank | **Catalog-only** | No on-device reranker benchmark/artifact execution for catalog models. |
| Generation | **Scaffold** | `flutter_gemma` seam exists but no `.task` install/load/ask evidence on device. |
| Managed platform APIs | **No-path** | No platform-native capability matrix implemented in repo currently. |

## Mobile/offline execution status (all 77 catalog models)

| year | model | artifact_class | focus | status | reason |
|---|---|---|---|---|---|
| 2026 | Infinity-Parser2 | Specialist document parser/VLM | Long-form structured document parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | HunyuanOCR-1.5 | Specialist OCR VLM | Lightweight OCR VLM; faster and improved parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | SAYRE | Training/data method | Scene-aware document synthesis for KIE | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | P-MTP | Training/decoding method | Efficient document parsing with multi-token prediction | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | RT-DocLayout | Layout model | Real-time layout analysis and reading order | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Unlimited-OCR | Specialist OCR/document VLM | One-shot long-horizon OCR and document parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Beaver | Document agent/system | Scientific curation from multimodal sources | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Agents-K1 | Document agent/model | Agent-native knowledge orchestration | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | PaddleOCR-VL-1.6 | Specialist document VLM | Multilingual document parsing and region refinement | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | PP-OCRv6 | Classical/small OCR model family | Compact text recognition OCR models | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | MinerU-Popo | Post-processing model | Universal post-processing for structured parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | RTPrune | Inference optimization | Token pruning for DeepSeek-OCR inference | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | ABot-OCR | Specialist OCR model | End-to-end document OCR | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | BabelDOC | PDF translation/parser pipeline | Layout-preserving PDF translation via intermediate representation | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Consensus Entropy | Verification/ensemble method | Multi-VLM agreement for self-verifying OCR | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | FastOCR | Inference optimization | KV-cache pruning for efficient document parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | MinerU2.5-Pro | Specialist document parser/VLM | Data-centric high-accuracy structured parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | PixelPrune | Inference optimization | Adaptive visual-token reduction | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | TexOCR | Specialist scientific OCR VLM | Compilable page-to-LaTeX reconstruction | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Falcon OCR / Falcon Perception | Specialist OCR/document model | Document perception and OCR | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | MinerU-Diffusion | Specialist OCR research model | OCR as inverse rendering with diffusion decoding | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Qianfan-OCR | Specialist OCR/document VLM | Unified end-to-end document intelligence | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | dots.mocr | Specialist multimodal OCR | Multimodal OCR and broad document parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | FireRed-OCR | Specialist OCR model | Complex document OCR | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | AgenticOCR | Query-adaptive parser/agent | Selective parsing for retrieval and RAG | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | PTP | Decoding/training method | Parallel token prediction for document parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Logics-Parsing-Omni | Specialist document parser/VLM | Layout, reading order and structured parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Agentar-Fin-OCR | Domain-specific financial OCR | Financial document OCR and extraction | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | PaddleOCR-VL (coarse-to-fine) | Specialist document VLM | Efficient coarse-to-fine visual document parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | DODO | Specialist OCR research model | Discrete diffusion models for OCR | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | HSD | Inference acceleration | Hierarchical speculative decoding for document VLMs | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | MeDocVL | Domain-specific medical document VLM | Medical document understanding and parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Dolphin-2.0 | Specialist document parser/VLM | Universal document parsing with scalable anchor prompting | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | GLM-OCR | Specialist OCR/document VLM | Complex document OCR, tables, formulas and KIE | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | OCR-Agent | OCR agent/system | Agentic OCR with capability and memory reflection | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | OmniOCR | Specialist multilingual OCR | OCR for ethnic-minority languages | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | PaddleOCR-VL-1.5 | Specialist document VLM | Robust in-the-wild multi-task parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | OCRVerse | Specialist holistic OCR VLM | End-to-end OCR across multiple tasks | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | DeepSeek-OCR 2 | Specialist OCR/document VLM | Visual causal flow for OCR and structured parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Youtu-Parsing | Specialist document parser/VLM | Perception, structuring and recognition with parallel decoding | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | Typhoon-OCR | Language-specific document VLM | Thai document extraction | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | GutenOCR | Grounded document VLM | Grounded OCR front-end for documents | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2026 | LightOnOCR | Specialist multilingual OCR VLM | Compact 1B end-to-end OCR | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Uni-Parser | Specialist document parser | General structured document parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | TRivia | Table-recognition model/method | Self-supervised VLM fine-tuning for table recognition | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | DOCR-Inspector | Evaluator | Fine-grained automated evaluation of document parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | UniRec-0.1B | Text/formula recognition model | Unified text and formula recognition | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | HunyuanOCR | Specialist OCR/document VLM | End-to-end document OCR | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | MonkeyOCR v1.5 | Specialist document parser/VLM | Robust parsing for complex patterns | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Doc-Researcher | Document parsing/research system | Multimodal parsing plus deep document research | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | olmOCR 2 | Specialist OCR VLM/toolkit | PDF-to-clean-text parsing trained with unit-test rewards | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Chandra v0.1.0 | Specialist document OCR/parser | PDF/image to structured text and Markdown | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | DeepSeek-OCR | Specialist OCR/document VLM | OCR through optical-context compression | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Infinity-Parser | Specialist document parser/VLM | Layout-aware RL for scanned-document parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Nanonets-OCR 2 | Specialist OCR/document model | Documents to LLM-ready structured data | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | PaddleOCR-VL | Specialist document VLM | 0.9B multilingual parser for text, tables, formulas and charts | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Dolphin-1.5 | Specialist document parser/VLM | Heterogeneous-anchor document image parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Logics-Parsing | Specialist document parser/VLM | Layout and reading-order-aware parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Granite-Docling-258M | Compact specialist document VLM | Small document conversion model for Docling | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Marker 1.10.1 | Document parsing toolkit/model pipeline | PDF and document conversion to Markdown/JSON | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | MinerU 2.5 | Specialist document parser/VLM | Efficient high-resolution parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | DianJin-OCR-R1 | Reasoning/tool-interleaved OCR VLM | OCR with reasoning and tool use | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | dots.ocr | Specialist document VLM | Multilingual layout parsing in a single VLM | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | MonkeyOCR-Pro | Specialist document parser/VLM | Structure-recognition-relation triplet parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | OCRFlux | Specialist document parser | Complex layouts and cross-page merging | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | MinerU2.0-2505-0.9B | Specialist document VLM | Compact MinerU document parsing model | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | MonkeyOCR | Specialist document parser/VLM | Structure-recognition-relation triplet parsing | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Dolphin | Specialist document parser/VLM | Document image parsing via heterogeneous anchor prompting | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | GTR-VL | Domain-specific visual extractor | Molecular structure recognition | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | SmolDocling-256M | Compact specialist document VLM | End-to-end multimodal document conversion | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | olmOCR | Specialist OCR VLM/toolkit | PDF linearization into clean, naturally ordered text | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | PP-StructureV3 | Document structure pipeline | Layout, tables, formulas, OCR and document reconstruction | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2025 | Ocean-OCR | Specialist OCR VLM | General OCR applications using a VLM | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2024 | MarkItDown | Multi-format parser/converter | Office/PDF/media to Markdown conversion | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2024 | GOT-OCR 2.0 | Specialist unified OCR model | Unified end-to-end OCR for text, formulas and structured content | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2024 | MinerU | Document parsing toolkit/pipeline | Precise extraction of text, tables, formulas, images and reading order | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |
| 2024 | open-parse | Document parser | Visually aware PDF parsing and semantic chunking | Catalog-only | Catalog-only (frontier-only; no mobile artifact/runtime telemetry in this repo) |

## Hosted paid lanes (reference only)

| Lane | Status | Evidence file |
|---|---|---|
| OpenAI `gpt-5-nano` | EVAL | docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json |
| OpenRouter `google/gemini-2.5-flash-lite` | EVAL (partial) | docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json |
| OpenRouter `google/gemma-3-4b-it` | EVAL (partial) | docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | EVAL (partial) | docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json |
| Policy corpus held-out (52Q) | EVAL | docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json |
Generated automatically on 2026-07-26 from repository evidence; intended as evidence compendium only, not a production pipeline decision.
