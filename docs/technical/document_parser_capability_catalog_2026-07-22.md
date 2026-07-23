# Parser capability inventory from local research catalog (2026-07-22)

Source: `/Users/pranay/Downloads/document_parsers_extractors_catalog_2026_v2.xlsx` → `Master Catalog` (149 rows, 17 cols).

This document is explicitly a **discovery ledger**. Launch ownership still comes from runtime truth + evidence gates in:

- `src/ocr/capability_registry.py`
- `docs/eval/document_intelligence/capability_manifest_v1.json`
- `tests/test_document_capability_benchmark.py`

## 1) Raw fixed-lane counts from workbook

| Capability | Yes | Partial | Depends | No | Via OCR / model lanes | Total rows |
|---|---:|---:|---:|---:|---:|---:|
| Text OCR / extraction | 121 | 2 | 3 | 13 | 10 | 149 |
| Layout awareness | 89 | 39 | 2 | 17 | 3 | 149 |
| Table extraction | 91 | 18 | 2 | 36 | 2 | 149 |
| Math / LaTeX | 34 | 37 | 3 | 75 | 0 | 149 |
| Header / section detection | 86 | 18 | 2 | 42 | 1 | 149 |
| Coordinates / reading order | 110 | 31 | 2 | 5 | 1 | 149 |

Scope split in this workbook: `Broad / Focused / Primitive = 81 / 44 / 24`.

## 2) Requested-class closure ledger (cover + runtime + gate)

| Requested class | Workbook signal | Runtime owner | Production-safe today | Gate before default claims |
|---|---|---|---|---|
| Text extraction | Strong (text OCR, born-digital + scanned lanes) | `native_text`, `scanned_ocr` | Native text and conservative `sentence_segmentation` are available | Add locale/script-specific sentence-boundary benchmarks and OCR confidence handling |
| Sentences / line fidelity | No dedicated workbook column; implied by text pipelines | `sentence_segmentation`, `native_text`, `scanned_ocr` | Partial-owned: deterministic sentence spans from source | Add language-aware boundary fixtures for abbreviations and punctuation behavior |
| Structures / headings | `Header / section detection`: 86 Yes; `Layout awareness` strong | `layout`, `reading_order`, `headings_and_sections` (candidate) | Block geometry/order available; heading semantics are not yet fully benchmarked | Add heading-depth and semantic-hierarchy fixtures |
| Layout + reading order | `Coordinates / reading order`: 110 Yes | `layout`, `reading_order` | Native + optional profile block order is persisted | Add rotated/multi-column/low-DPI recovery gates |
| Tables / rows / cells | `Table extraction`: 91 Yes | `tables` (native digital/table-cell provenance) | Native tables are owned; scanned reconstruction is open | Add merged-cell, borderless-grid, malformed-grid, continuity fixtures |
| Images / figures / charts (structural) | Workbook strings show image/figure capability in outputs/notes for key stacks | `figures` owned, `charts_and_diagrams` candidate | Embedded image artifacts/hashes are preserved | Add crop→bbox→caption trace and anti-hallucination controls before chart semantic claims |
| Forms / KVP / marks | Limited direct workbook column coverage; strong managed-IDP frontier | `forms` available (native AcroForm), `key_value_extraction` candidate, `selection_marks` unavailable | Native widgets are evidence-safe; scanned KVP/marks remain open | Add schema-bound form/KVP + marks specialist lane with review state |
| Formula / math / LaTeX | Weak raw coverage (34 Yes) | `formulas` candidate | No production formula lane yet | Add formula-span and normalization benchmarks + domain safety checks |
| Office / web / email structure | Native-adapter presence is explicit in outputs | `office_and_email_structure` | Core formats now owned end-to-end | Add relationship-preservation and malformed-container tests |
| Multilingual quality | Frontier + runtime script observation only | `multilingual` routing-only | Script tagging exists; no closed multilingual quality gate | Add language/locale benchmark matrix |
| Handwriting | Frontier-only signal, no dedicated workbook depth | `handwriting` unavailable | No production lane | Add specialist handwriting corpus and review fallback |

## 3) Capability-by-capability top practical owners

### Top broad-Yes examples used for routing candidates

- **Text / OCR / layout / tables / order:** `Docling`, `SmolDocling`, `MinerU`, `Marker`, `LlamaParse`, `PDF-Extract-Kit`, `OpenParse`, `Docling Serve`, `PaddleOCR PP-Structure`, `Surya`, `Python-docx/pptx/openpyxl` stacks.
- **Headers / sections / structure:** `Docling`, `MinerU`, `Marker`, `LlamaParse`, `PaddleOCR PP-Structure`, `Surya`, plus heading-aware document models.
- **Math / LaTeX:** `Docling`, `MinerU`, `Marker`, `PaddleOCR PP-Structure`, `Surya`, `Pix2Text`, `Nougat`, `Mathpix`, `Tesseract`-family equation stacks.
- **Figures / charts (structural):** `Docling`, `Marker`, `Pix2Text`, `openpyxl`, `python-pptx`, `docx2python`, `Adobe PDF Extract API`, `Mistral OCR`.
- **Sentence-level fidelity:** explicit column is not present in the workbook; practical lane comes from `sentence_segmentation` + downstream language-agnostic boundaries.
- **Image understanding / captions:** strong image artifact support is owned by source adapters; semantic captioning/understanding is still derived and remains candidate-only.
- **Multilingual / handwriting:** no direct coverage column; only script observation + frontier specialists are currently represented.

## 4) Frontier-candidate lanes not in fixed columns

These are explicit additions from workbook frontier sheets and frontier notes:

- **Handwriting**: specialist handwritting OCR only; no default lane.
- **VLM image understanding**: `image_understanding` and `vlm_annotation` are candidate/configured-unverified only.
- **Managed forms/KVP**: Azure Document Intelligence / Google Document AI / AWS Textract considered policy gates via managed provider route.
- **Chart-level understanding**: derived annotation only; strict semantic claims require provenance chain and review policy.

## 4.a) Own web frontier + benchmark pass (2026-07-22)

Latest public scans were checked against upstream project docs/benchmark references for structure/table/math/image lanes:

- Docling claims explicit layout/table/reading-order + formula/image primitives in its document model.
- PaddleOCR PP-StructureV3 documents layout/table/formula/chart recognition and mentions multi-class layout element output.
- GROBID notes explicit section/figure/table labels but hierarchy depth quality still needs fixture-level closure.
- Microsoft Document Intelligence and Google Document AI are strong managed KIE lanes with required provider-policy controls.
- ParseBench (April 2026) formalizes multi-column reading-order and heading-style fidelity scoring in end-to-end document parsing.
- Emerging benchmark families (MPDocBench-Parse, Dr.DocBench, OCRBench v2) indicate real-world multi-page layout/table/heading stress still matters most for close-loop quality.
- OCRBench v2 tracks practical text/localization drift and LMM OCR boundary failures at scale, which is relevant for our multilingual and handwritten frontier lanes.
- ParseBench has a structured parser-quality benchmark and explicitly evaluates content-fidelity, order, and markdown-structure behavior over noisy pages.

These are not defaults; they are **candidate gates** until our manifest-level closures close:

- Multi-column/rotated/low-DPI reading-order recovery
- merged-cell and malformed-table continuity
- section-heading depth and hierarchy confidence
- caption-to-region provenance and anti-hallucination control for images/charts
- per-locale sentence boundaries and formula-normalization safety

Additional frontier validation items discovered in this web pass:

- **ParseBench** and **MPDocBench-Parse** (2026) were reinforced as highest-priority stress lanes for page-order, heading hierarchy, and table continuity.
- **Dr.DocBench** (2026) was added as the long-document complexity pressure lane for structural errors, formula/table/figure stress.
- **OCRBench v2** and **DTBench** remain mandatory pressure suites for multilingual/noisy and table reconstruction drift before semantic claims.

## 5) Requested-class full coverage map (text, sentences, structures, layout, tables, images, formulas, forms, multilingual, handwriting)

For every user-requested class, this is the practical "what we have / what is still open" map:

| Class | Local signal (workbook + frontier) | Owned today | Candidate frontier | Open gate |
|---|---|---|---|---|
| Text extraction | Strong `text` lane; native + OCR model ecosystems | `native_text` + `sentence_segmentation` + optional `scanned_ocr` | Docling, SmolDocling, Surya, Marker | script/locale boundary validation and confidence telemetry |
| Sentence fidelity / line recovery | Implied in text/layout pipelines only | Conservative offset-aware spans (`sentence_segmentation`) | Surya/GROBID-derived sentence-aware outputs | multilingual punctuation/abbrev edge tests and script-aware fallback |
| Structures / headings | `header / section` class has high-but-not-total workbook coverage | `layout`, `reading_order` for geometry + order | Docling, MinerU, Marker, GROBID | heading-depth + hierarchy-nesting fixtures before semantic defaults |
| Layout / reading order | `coordinates / reading order` has 110/149 yes in catalog | `layout`, `reading_order` baseline with native order persistence | RT-DocLayout, PP-StructureV3, Surya | rotated, multi-column, low-DPI adversarial fixtures |
| Tables / rows / cells | `table extraction` is mature for born-digital | `tables` + native table adapters for page tables | PP-StructureV3, Docling, MinerU, TATR/GMFT, DTBench/PulseBench-Tab | scanned-table reconstruction + merged/borderless/malformed-grid closure |
| Images / figures / charts | Multiple families signal image structure support | `figures`, image artifact hash lineage | Docling, Marker, Mistral OCR, MMDocBench, ParseBench | crop→bbox→caption lineage + anti-hallucination policy |
| Forms / KVP / marks | Frontier/managed-focused for scanned forms | `forms` for AcroForm; no native scanned KVP | Azure DI, Google DI, AWS Textract, Paddle KIE | schema-driven KVP + mark/checkbox validation + review/retry contract |
| Formula / math | Weak raw workbook score, strong specialized frontier list | `formulas` candidate only | TexOCR, MinerU, PP-StructureV3, GLM-OCR, PaddleOCR-VL | formula span mapping + normalization checks + uncertainty states |
| Office / web / email structure | Full stack present in runtime adapters | `office_and_email_structure` owned core outputs | Docling/Open source ETL + managed providers | malformed-container and relationship-preservation regression suite |
| Multilingual | Frontier and registry are script-routing today | `multilingual` routing only | PaddleOCR-VL-1.6, HunyuanOCR-1.5, OmniOCR, Typhoon-OCR, dots.ocr, MDPBench | locale matrix + unsupported-language policy |
| Handwriting | Frontier-only in local research corpus | `handwriting` unavailable | specialist handwriting candidates + socOCRbench/similar | dedicated handwriting corpus, confidence policy, manual-review fallback |

## 5.a) What each requested class has end-to-end for now

| Class | Extraction coverage today | Structure/semantics coverage today | Current production claim boundary | Closest practical candidate lane |
|---|---|---|---|---|
| Text / sentence | Native extraction from PyMuPDF is owned (`native_text`); scan OCR available (`scanned_ocr`) | Sentence segmentation is punctuation-offset based; no language-aware sentence model | Multilingual sentence boundaries and scanned-fallback confidence remain open | GROBID + language-aware sentence fixtures (frontier) |
| Structures / headings | Layout/reading-order blocks are emitted (`layout`, `reading_order`) | Heading semantics are not yet claim-safe (no robust hierarchy + depth score) | No production claim for hierarchical heading quality yet | Docling / MinerU / Surya / GROBID / PP-StructureV3 candidates |
| Layout + reading order | Native page order/geometry is owned; distortion cases are profile-driven | Reading-order semantics under stress (rotation, multi-column, low DPI) are frontier only | Do not claim perfect reading-order across degraded layouts | RT-DocLayout + Surya + docling profile gating |
| Tables / rows / cells | Born-digital tables and office tables are owned; formulas are preserved in context | Scanned-table reconstruction and merged/borderless continuity are open | Do not claim general table recovery without fixture closure | PP-StructureV3, TATR/TG, DTBench/PulseBench-Tab, MinerU frontier |
| Images / figures / charts | Image bytes and bboxes are preserved in evidence envelopes | Semantic chart/figure interpretation remains derived | No derived chart meaning claims before provenance chain + review policy | Docling + Marker + MMDocBench + ParseBench closure suite |
| Forms / KVP / marks | Native AcroForm fields are owned (`forms` + `key_value_extraction` candidate) | KVP extraction and selection-mark certainty are not yet production-safe | Selection-marks and checkbox parsing remain open | Azure DI, Google DI, AWS Textract, Paddle KIE + schema validation lane |
| Formula / math | Formula-friendly models listed in catalog and managed frontier | Region-linked formula spans / normalization states are not yet validated | No production formula claim until span+normalization gates pass | TexOCR, MinerU, PP-StructureV3, GLM-OCR, PaddleOCR-VL |
| Office / web / email | DOCX/HTML/EML/XLSX/PPTX structure is owned in runtime `office_and_email_structure` | Relationship preservation on malformed containers remains frontier | No production relationship-preservation claim without adversarial suite | Docling, native adapters + managed enterprise parsers |
| Multilingual / scripts | Script observation is available; routing is present (`multilingual`) | Locale-quality gates are open | No script-level closure for all families yet | OmniOCR, Typhoon-OCR, HunyuanOCR-1.5, PaddleOCR-VL, MDPBench |
| Handwriting | No native owner lane yet | Semantics, confidence and rejection states are frontier-only | No production lane | Chandra, dots.ocr, specialist handwriting corpus + review policy |


## 6) Immediate gates for next decision-unit closures

## 7) Evidence index (machine-readable)

- `docs/review/evidence/local-model-eval/capability_class_coverage_index_2026-07-22.json` (generated from workbook + runtime registry + capability gate posture)
- `docs/review/evidence/local-model-eval/capability_frontier_candidates_2026-07-22.json`
- `docs/review/evidence/local-model-eval/workbook_class_coverage_generated_2026-07-22.json`
- `docs/review/evidence/local-model-eval/workbook_class_summary_2026-07-22.json`

Current gates to execute now (each is one auditable decision-unit):

1. Add script- and locale-stratified sentence/layout/formula/table fixtures with timeout/partial-success telemetry.
2. Add chart/caption lineage and anti-hallucination checks before semantic chart claims.
3. Add merged-cell and malformed-grid table fixtures with failure-state evidence.
4. Add selection-mark specialist route with schema validation and explicit uncertainty/retry states.
5. Keep all chart/formula/handwriting image-based interpretation in **candidate** status until gates close.

## 6) Evidence sources used in this pass

- Local workbook: `/Users/pranay/Downloads/document_parsers_extractors_catalog_2026_v2.xlsx`.
- Local frontier notes + local summaries in:
- `docs/review/evidence/local-model-eval/capability_frontier_candidates_2026-07-22.json`
- `docs/review/evidence/local-model-eval/workbook_class_summary_2026-07-22.json`
- `docs/review/evidence/local-model-eval/workbook_class_coverage_generated_2026-07-22.json`
- Runtime truth:
  - `src/ocr/capability_registry.py`
  - `docs/eval/document_intelligence/capability_manifest_v1.json`
  - `tools/inspect_document_capabilities.py`

## 8) Per-class closure map (owned / candidate / open)

| Capability | Owned today (runtime truth) | Candidate / fallback frontier | Open gate |
|---|---|---|---|
| Text extraction | `native_text`, `sentence_segmentation` | Docling, Surya, PP-StructureV3, MinerU | script/locale sentence-boundary + confidence behavior |
| Sentences / line fidelity | conservative offset segmentation | GROBID, Surya-derived segmentation | punctuation/abbrev and multi-script sentence edge fixture |
| Structures / headings | `layout`, `reading_order`, `headings_and_sections(candidate)` | Docling, GROBID, Surya, Marker | hierarchy-depth + nested-heading correctness |
| Layout + reading order | `layout`, `reading_order` | RT-DocLayout, PP-StructureV3, MinerU | rotated/multi-column/low-DPI robustness |
| Tables / rows / cells | `tables` + native digital/office adapters | Docling, Surya, PaddleOCR PP-StructureV3, TATR/TG | scanned-table reconstruction + merged-cell/borderless/malformed-grid |
| Images / figures / charts | `figures` + image hash lineage | Docling, Marker, Mistral OCR, Gemini/OpenAI vision | crop→bbox→caption trace + anti-hallucination policy |
| Forms / KVP / marks | `forms` (`native` AcroForm), key-value candidate profile | Azure DI, Google DI, AWS Textract, Paddle KIE | schema-driven KVP + selection-marks + review/retry lane |
| Formula / math / LaTeX | `formulas` candidate only (no production lane yet) | TexOCR, MinerU, PP-StructureV3, Mathpix/Pix2Text | formula span grounding and normalization checks |
| Office / web / email structure | `office_and_email_structure` + native parsers | Docling/Open-source ETL/managed fallbacks | malformed-container and relationship-preservation tests |
| Multilingual | `multilingual` routing-only | HunyuanOCR-1.5, PaddleOCR-VL, OmniOCR, Typhoon-OCR, dots.ocr, MDPBench | per-locale accuracy closure + unsupported-language policy |
| Handwriting | `handwriting` unavailable | specialist OCR candidates (frontier) | dedicated corpus + manual review fallback |
