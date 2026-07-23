# OCR / parser / VLM capability ledger (2026-07-22)

Source material:

- Local workbook: `/Users/pranay/Downloads/document_parsers_extractors_catalog_2026_v2.xlsx`
- Local summaries: `docs/review/evidence/local-model-eval/document_catalog_capability_summary_2026-07-22.json`,
  `docs/review/evidence/local-model-eval/workbook_class_summary_2026-07-22.json`
- Runtime truth: `src/ocr/capability_registry.py`
- Close gates: `docs/eval/document_intelligence/capability_manifest_v1.json`
- Frontier notes: `docs/review/evidence/local-model-eval/capability_frontier_candidates_2026-07-22.json`
- Class-by-class machine index: `docs/review/evidence/local-model-eval/capability_class_coverage_index_2026-07-22.json`
- Class coverage generation artifact: `docs/review/evidence/local-model-eval/workbook_class_coverage_generated_2026-07-22.json`

## How we treat evidence

- **Owned**: registry/manifest evidence exists today and is source-linked in runtime.
- **Candidate**: strong local or frontier signal exists but not production-safe yet.
- **Open**: no production-safe lane exists; must be treated as gated exploration.

## Requested class matrix (full per-capability coverage)

| Capability class | Local research signal | Runtime owner | Current evidence state | Close gate |
|---|---|---|---|---|
| **Text extraction** | `Master Catalog`: text OCR 121/149 Yes (high volume), plus multiple layout-aware stacks | `native_text` + `scanned_ocr` | `native_text` is owned; scanned OCR is available only as optional profile | Add locale/script-aware boundary validation and failure telemetry |
| **Sentences / sentence-level fidelity** | Not a dedicated workbook column; implied through text/layout family families | `sentence_segmentation` | Baseline offset-based segmentation exists (`quality_gate` present) | Add sentence-boundary benchmarks for punctuation edge cases and abbreviations |
| **Structures / headings / hierarchy** | `Master Catalog`: Header/section detection 86/149 Yes; frontier candidates (Docling, MinerU, Surya, PP-Structure) | `layout`, `reading_order`, `headings_and_sections` (candidate) | Geometry/order are source-grounded; hierarchy semantics are not yet | Add heading-depth and nested hierarchy fixtures, especially for multi-column/rotated pages |
| **Layout + reading order** | `Master Catalog`: Coordinates/reading-order 110/149 Yes; plus strong frontier candidates in Surya/Docling | `layout`, `reading_order` | Block geometry and block order are persisted for baseline | Add rotated/multi-column/low-DPI robustness closure |
| **Tables / rows / cells** | `Master Catalog`: Table extraction 91/149 Yes; frontier includes Surya, PP-StructureV3, MinerU, table-LLMs | `tables` + native table/cell adapters | Born-digital and office tables are source-linked and tested | Add scanned-table reconstruction, merged-cell/borderless, malformed-grid, and continuity fixtures |
| **Images / figures / charts** | Multiple catalog families and frontier models include image/figure/diagram primitives | `figures` owned, `charts_and_diagrams` candidate, `image_understanding` candidate | Image artifacts and hashes are preserved; semantic chart meaning is derived-only | Add crop → bbox → caption lineage and anti-hallucination policy before product claims |
| **Forms / KVP / marks** | Forms/KVP mostly in managed/late frontier lane and partial local catalog support | `forms` available (native AcroForm), `key_value_extraction` candidate, `selection_marks` unavailable | Native AcroForm evidence-safe; scanned KVP/marks open | Add schema-aware KIE/form/mark lane with review + retry + uncertainty states |
| **Formula / math / LaTeX** | `Master Catalog`: Math/LaTeX 34/149 Yes (weak), frontier has TexOCR, MinerU, PP-Structure, Pix2Text | `formulas` candidate | No production-safe formula source lane yet | Add formula-span mapping + normalization + domain safety checks |
| **Office/web/email structure** | Workbook `Typical outputs` + adapter stack covers DOCX/HTML/EML/XLSX/PPTX | `office_and_email_structure` available | Core formats currently owned in CIR | Add malformed-container and relationship-preservation benchmark lane |
| **Multilingual OCR / structure** | Frontier entries in `Recent Models 2024+` + multilingual-capable stacks (Surya/Paddle) | `multilingual` routing-only | Script signal only; no quality closure | Add script/locale-stratified OCR/structure gates |
| **Handwriting** | Frontier candidates only (no native workbook depth) | `handwriting` unavailable | No production-safe lane | Add specialist handwriting corpus and manual-review fallback before any claims |

## Frontier shortlist by class (non-default, gate-required)

### Text / layout / tables / structure
- **Docling**: structured document tree, key-value, tables, reading-order lineage
- **Surya**: OCR + layout + reading order + tables across many languages
- **PaddleOCR PP-StructureV3 / PaddleOCR-VL**: table/layout/formula/chart primitives
- **MinerU / Marker**: broad extraction with structure preservation posture
- **RT-DocLayout**: reading-order-aware layout reconstruction with distortion/rotation focus (frontier)
- **MDPBench**: multilingual document parsing benchmark signal for language-coverage risk testing
- **ParseBench**: end-to-end parser evaluation for text-order, semantic formatting, and multi-column behavior

### Images / figures / charts
- **PaddleOCR PP-StructureV3** (reading + chart-aware classes)
- **Docling** (document tree object models)
- **MMDocBench + OCRBench v2** for chart/table and multimodal grounding stress
- **ParseBench** (multi-column reading-order and structure-format evaluation with noisy-page examples)

### Forms / KVP / marks
- **Azure Document Intelligence**, **Google Document AI**, **Textract** as managed KIE candidates
- Keep as managed/review lanes until schema + review-policy gates are live

### Formula / math
- **TexOCR**, **GLM-OCR**, **PP-StructureV3**, **PaddleOCR-VL**, **Got-OCR 2.0** as frontier candidates

### Sentences / line fidelity
- **Sentence segmentation frontier is mostly native-offset and post-processing-based today**. Add fixture-grade sentence boundaries before any language-dependent production claims.

### Multilingual / handwriting
- **PaddleOCR-VL-1.6**, **HunyuanOCR-1.5**, **OmniOCR**, **Typhoon-OCR**, **dots.ocr** for multilingual frontier
- **Handwriting** currently remains specialist-lane only

### New frontiers added in this pass (2026-07-22)

- **RT-DocLayout**: explicit real-time layout + reading-order + table continuity lane for rotated/noisy scans.
- **MDPBench**: first-class multilingual document parsing benchmark for locale/strategy gap closure.
- **PulseBench-Tab**: multilingual table-reliability stress with language-specific structure/content scoring.
- **ParseBench**: parser-lane closure for reading-order, heading hierarchy, and structured markdown fidelity.

## Frontier scan and benchmark implications (2026-07-22)

Own web scan notes were done against latest public claims for:

- Docling feature set and document model (layout tables, reading order, OCR, key-value, images)
- PaddleOCR PP-StructureV3/PP-Structure documentation
- GROBID semantic structure and section-label caveats
- Azure Document Intelligence and Google Document AI managed KIE/Form APIs
- ParseBench, MPDocBench-Parse, Dr.DocBench benchmark families
- OCRBench v2 as a practical OCR/LM robustness pressure set

### Benchmark/closure implications

High-priority closure work from this scan:

1. **Reading-order + hierarchical structure:** close with explicit heading-depth fixtures before semantic structure claims.
2. **Table continuity:** close with merged-cell, borderless-grid, low-DPI, and rotated-page table fixtures.
3. **Formula/math region grounding:** close with LaTeX/MathML normalization fixtures and policy-safe uncertainty states.
4. **Image/figure annotations:** close with crop→bbox→caption provenance chain and anti-hallucination policy for derived chart understanding.
5. **Multilingual + handwriting:** close with script/locale matrix and specialist review fallback before user-facing interpretation.

Additional frontier additions from this pass:

- **Zero-Shot Table Extraction in Business Documents (WACV 2026):** strengthens stress coverage for borderless and irregular tables.
- **DTBench:** useful for doc-to-table reconstruction scoring and per-subtask diagnostics (headers/cells/structure).
- **socOCRbench:** useful mixed-signal pressure set for handwriting, degraded forms, and mixed-content table pages.
- **Dr.DocBench (May/Jun 2026):** multi-domain long-document parser stress (`~4,514` pages, `65k` layout/table/formula/figure annotations).

### Canonical owner-by-class closure lane (snapshot)

| Class | Preferred local owner | Candidate/managed fallback | Production-safe today? | Hard gate remaining |
|---|---|---|---|---|
| Text extraction | `native_text`, `sentence_segmentation`, `scanned_ocr` | `openai_vision`, managed OCR VLMs | **Partial** | locale/script sentence-boundary + confidence behavior |
| Layout / reading order | `layout`, `reading_order` | Docling, Surya, PP-StructureV3 | **Partial** | multi-column/rotated/low-DPI fixtures |
| Tables / cells | `tables`, native office/table adapters | Docling, MinerU, PP-StructureV3, TATR/TG families | **Partial** | scanned-table + merged/borderless/malformed-grid closure |
| Structures / headings | `headings_and_sections(candidate)` | Docling, Surya, GROBID | **Candidate** | heading-depth, hierarchy-depth, ambiguous nesting |
| Images / figures / charts | `figures` + artifact hash lineage | Docling, Marker, Mistral OCR, PP-StructureV3, Gemini/Claude vision | **Candidate-derived only** | crop→caption trace, bounded semantics, privacy/review policy |
| Forms / KVP / marks | `forms` + managed schema fallback | Azure DI / Google DI / Textract | **Partial** | KVP and marks schema + review/retry + uncertainty |
| Math / formula / LaTeX | `formulas(candidate)` | Docling, MinerU, Surya, Texify, Mathpix OCR | **Open (pending)** | span-grounded formula extraction and normalization |
| Office / web / email structure | `office_and_email_structure` | Docling, structured parsers | **Closed for core formats** | malformed-container and relationship-preservation tests |
| Multilingual | `multilingual` script observation | Surya/Paddle multilingual stacks + managed DI | **Candidate-only** | script/locale matrix and fallback policy |
| Handwriting | `handwriting(unavailable)` | Specialist handwriting OCR/VLM candidates | **Open** | handwriting corpus + specialist QA path |

## Current launch decision for this scope

For this requested lane set, the default posture remains:

- Owned today (source-linked): native text, sentence base offsets, layout/order, tables (digital), image artifacts, native form fields, office/web/email structure.
- Candidate only: headings/semantic sections, scanned/complex forms/KVP/marks, charts, formulas, image semantic understanding, multilingual-quality and handwriting.
- Decision consequence: do not treat any frontier model as default until explicit table/formula/figure sentence + locale gate runs are closed.
