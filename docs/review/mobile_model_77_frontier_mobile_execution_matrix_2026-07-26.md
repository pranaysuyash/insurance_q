# 77-model frontier mobile-execution matrix (explicit)

Generated from `mobile_model_shortlist_generated_2026-07-26.md` for direct per-model audit.

Interpretation: this is a **mobile execution** matrix for CoverWise (`Android/iOS`), not a capability or benchmark paper list.

Total rows: **77**. Status split: **{'Catalog-only': 77}**; Mobile-lane note split: **{'No': 77}**.

## Decision register (frontier-only)

### Selected / not selected at this stage

- **Selected:** `0 / 77` mobile-offline frontier families
- **Deferred:** `0 / 77` (all are blocked on telemetry and artifact presence)
- **Excluded:** `77 / 77` (all frontier families are catalog-only for this stage)

### Why these are excluded now

- No mobile artifact manifest (`.task` / equivalent) was present for any frontier model in-repo.
- No Android/iOS `install -> load -> ask` telemetry proof was produced for frontier families.
- No policy-answer schema validation on-device was completed for frontier families.
- This means the following are currently **not promotable** for mobile-offline execution:
  - `Unlimited-OCR`
  - `RT-DocLayout`
  - `PaddleOCR-VL` (and variants)
  - `MinerU` family (`MinerU`, `MinerU 2.5`, `MinerU2.0-2505-0.9B`, `MinerU2.5-Pro`, `MinerU-Diffusion`, `MinerU-Popo`)
  - `Dolphin`, `AgenticOCR`, `Logics-Parsing`, `GutenOCR`, `HunyuanOCR`, `Marker` variants
  - `qwen3-*`, `gemma-*`, `lora / adapter / fine-tune` lanes

### Deferred for next phase (required gates)

- `Gemma 3n` E2B/E4B candidate: signed artifact + Android/iOS `install/load/ask` + latency + memory + failure/retry telemetry.
- `Gemma 270M/1B` or `Qwen3 1.7B` compact lane: same gates after first candidate proves mobile viability.
- Managed runtime probes (`Gemini Nano`, `AICore`, `Apple Foundation Models`) after on-device gate passes.

| # | Model | Release | Artifact class | Stage | Mobile status | Transformers.js / web GPU | Android/iOS mobile runtime | Fine-tune/adapter | Why mobile status is this |
|---:|---|---|---|---|---|---|---|---|---|
| 1 | `GOT-OCR 2.0` | 2024-09 | Specialist unified OCR model | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 2 | `MarkItDown` | 2024-12 | Multi-format parser/converter | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 3 | `MinerU` | 2024-09 | Document parsing toolkit/pipeline | Parsing / OCR / reconstruction | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 4 | `open-parse` | 2024-03 | Document parser | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 5 | `Chandra v0.1.0` | 2025-10 | Specialist document OCR/parser | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 6 | `DOCR-Inspector` | 2025-12 | Evaluator | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 7 | `DeepSeek-OCR` | 2025-10 | Specialist OCR/document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 8 | `DianJin-OCR-R1` | 2025-09 | Reasoning/tool-interleaved OCR VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 9 | `Doc-Researcher` | 2025-10 | Document parsing/research system | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 10 | `Dolphin` | 2025-05 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 11 | `Dolphin-1.5` | 2025-10 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 12 | `GTR-VL` | 2025-05 | Domain-specific visual extractor | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 13 | `Granite-Docling-258M` | 2025-09 | Compact specialist document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 14 | `HunyuanOCR` | 2025-11 | Specialist OCR/document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 15 | `Infinity-Parser` | 2025-10 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 16 | `Logics-Parsing` | 2025-09 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 17 | `Marker 1.10.1` | 2025-09 | Document parsing toolkit/model pipeline | Parsing / OCR / reconstruction | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 18 | `MinerU 2.5` | 2025-09 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 19 | `MinerU2.0-2505-0.9B` | 2025-06 | Specialist document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 20 | `MonkeyOCR` | 2025-06 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 21 | `MonkeyOCR v1.5` | 2025-11 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 22 | `MonkeyOCR-Pro` | 2025-07 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 23 | `Nanonets-OCR 2` | 2025-10 | Specialist OCR/document model | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 24 | `OCRFlux` | 2025-06 | Specialist document parser | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 25 | `Ocean-OCR` | 2025-01 | Specialist OCR VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 26 | `PP-StructureV3` | 2025-02 | Document structure pipeline | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 27 | `PaddleOCR-VL` | 2025-10 | Specialist document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 28 | `SmolDocling-256M` | 2025-03 | Compact specialist document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 29 | `TRivia` | 2025-12 | Table-recognition model/method | Parsing-method / optimizer | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 30 | `Uni-Parser` | 2025-12 | Specialist document parser | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 31 | `UniRec-0.1B` | 2025-12 | Text/formula recognition model | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 32 | `dots.ocr` | 2025-07 | Specialist document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 33 | `olmOCR` | 2025-02 | Specialist OCR VLM/toolkit | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 34 | `olmOCR 2` | 2025-10 | Specialist OCR VLM/toolkit | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 35 | `ABot-OCR` | 2026-05 | Specialist OCR model | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 36 | `Agentar-Fin-OCR` | 2026-03 | Domain-specific financial OCR | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 37 | `AgenticOCR` | 2026-03 | Query-adaptive parser/agent | Parser orchestration / adjunct | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 38 | `Agents-K1` | 2026-06 | Document agent/model | Parser orchestration / adjunct | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 39 | `BabelDOC` | 2026-05 | PDF translation/parser pipeline | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 40 | `Beaver` | 2026-06 | Document agent/system | Parser orchestration / adjunct | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 41 | `Consensus Entropy` | 2026-05 | Verification/ensemble method | Parsing-method / optimizer | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 42 | `DODO` | 2026-02 | Specialist OCR research model | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 43 | `DeepSeek-OCR 2` | 2026-01 | Specialist OCR/document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 44 | `Dolphin-2.0` | 2026-02 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 45 | `Falcon OCR / Falcon Perception` | 2026-03 | Specialist OCR/document model | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 46 | `FastOCR` | 2026-05 | Inference optimization | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 47 | `FireRed-OCR` | 2026-03 | Specialist OCR model | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 48 | `GLM-OCR` | 2026-02 | Specialist OCR/document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 49 | `GutenOCR` | 2026-01 | Grounded document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 50 | `HSD` | 2026-02 | Inference acceleration | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 51 | `HunyuanOCR-1.5` | 2026-07 | Specialist OCR VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 52 | `Infinity-Parser2` | 2026-07 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 53 | `LightOnOCR` | 2026-01 | Specialist multilingual OCR VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 54 | `Logics-Parsing-Omni` | 2026-03 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 55 | `MeDocVL` | 2026-02 | Domain-specific medical document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 56 | `MinerU-Diffusion` | 2026-03 | Specialist OCR research model | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 57 | `MinerU-Popo` | 2026-05 | Post-processing model | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 58 | `MinerU2.5-Pro` | 2026-04 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 59 | `OCR-Agent` | 2026-02 | OCR agent/system | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 60 | `OCRVerse` | 2026-01 | Specialist holistic OCR VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 61 | `OmniOCR` | 2026-02 | Specialist multilingual OCR | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 62 | `P-MTP` | 2026-06 | Training/decoding method | Parsing-method / optimizer | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 63 | `PP-OCRv6` | 2026-06 | Classical/small OCR model family | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 64 | `PTP` | 2026-03 | Decoding/training method | Parsing-method / optimizer | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 65 | `PaddleOCR-VL (coarse-to-fine)` | 2026-03 | Specialist document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 66 | `PaddleOCR-VL-1.5` | 2026-01 | Specialist document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 67 | `PaddleOCR-VL-1.6` | 2026-06 | Specialist document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 68 | `PixelPrune` | 2026-04 | Inference optimization | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 69 | `Qianfan-OCR` | 2026-03 | Specialist OCR/document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 70 | `RT-DocLayout` | 2026-06 | Layout model | Parsing / OCR / layout | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 71 | `RTPrune` | 2026-05 | Inference optimization | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 72 | `SAYRE` | 2026-07 | Training/data method | Parsing-method / optimizer | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 73 | `TexOCR` | 2026-04 | Specialist scientific OCR VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 74 | `Typhoon-OCR` | 2026-01 | Language-specific document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 75 | `Unlimited-OCR` | 2026-06 | Specialist OCR/document VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 76 | `Youtu-Parsing` | 2026-01 | Specialist document parser/VLM | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |
| 77 | `dots.mocr` | 2026-03 | Specialist multimodal OCR | Parsing / OCR | Catalog-only | No (web/mobile-web only) | No | No | No mobile artifact/install-load-ask evidence in this repo; catalog-stage/runner evidence only. |

## Why this matters

- All 77 rows are `Catalog-only` for mobile execution in this run; no `Android/iOS` install/load/ask proof exists for frontier families.
- The only mobile-native, in-repo route with concrete integration evidence is the `flutter_gemma` scaffolding seam (not execution-telemetry-proven yet).
- Use this matrix alongside:
  - `mobile_model_execution_decision_sheet_2026-07-26.md`
  - `mobile_model_frontier_2026_plus_truth_matrix_2026-07-26.md`
  - `mobile_model_shortlist_truth_and_gaps_2026-07-26.md`
