# Parser capability inventory from local research catalog (2026-07-22)

Source: `document_parsers_extractors_catalog_2026_v2.xlsx` → `Master Catalog` (149 rows).

## Capability lane counts (raw catalog claims)

| Capability | Yes | Depends | Partial | Requires/Via/Requires OCR | Via semantic/model | No | Total with explicit status |
|---|---:|---:|---:|---:|---:|---:|---:|
| Text OCR / extraction | 121 | 3 | 2 | 10 | 0 | 13 | 149 |
| Layout awareness | 89 | 2 | 39 | 1 | 1 | 17 | 149 |
| Table extraction | 91 | 2 | 18 | 1 | 1 | 36 | 149 |
| Math / LaTeX | 34 | 3 | 37 | 0 | 0 | 75 | 149 |
| Header / section detection | 86 | 2 | 18 | 1 | 0 | 42 | 149 |
| Coordinates / reading order | 110 | 2 | 31 | 1 | 0 | 5 | 149 |

- Scope split: Broad 81 / Focused 44 / Primitive 24.

## Text OCR / extraction

| Scope | Yes count | Top score 12 examples (Tool | License | Category) |
|---|---:|---|
| Broad | 78 | openpyxl (Open source; XLSX parser); lxml (Open source; HTML/XML parser); Zerox (Open source; Vision-model OCR pipeline); Surya (Open source; OCR + layout toolkit); SmolDocling (Open weights; Vision document converter/model); ScholarPhi / PaperMage (Open source; Scientific document representation); Reducto (Commercial; Document ingestion API); Pix2Text (Open source; Scientific document parser) |
| Focused | 22 | pdf2json (Open source; PDF parser); iText Core (Open source (AGPL) + commercial; PDF SDK); Texify (Open source; Math OCR model); Science Parse (Open source / archived; Scientific paper parser); MMOCR (Open source; OCR toolbox); pdfminer.six (Open source; PDF text/layout extractor); borb (Open source + commercial; PDF library); MuPDF (Open source (AGPL) + commercial; PDF engine) |
| Primitive | 21 | unpdf (Open source; PDF utilities); textract (Python) (Open source; Multi-format text extraction); pypdf (Open source; PDF parser/manipulator); pix2tex / LaTeX-OCR (Open source; Equation OCR); Xpdf (Open source + commercial; PDF utilities); Tika-Python (Open source; Apache Tika wrapper); PoDoFo (Open source; PDF library); OCRopus (Open source / legacy; OCR system) |

## Layout awareness

| Scope | Yes count | Top score 12 examples (Tool | License | Category) |
|---|---:|---|
| Broad | 69 | openpyxl (Open source; XLSX parser); lxml (Open source; HTML/XML parser); Zerox (Open source; Vision-model OCR pipeline); Surya (Open source; OCR + layout toolkit); SmolDocling (Open weights; Vision document converter/model); ScholarPhi / PaperMage (Open source; Scientific document representation); Reducto (Commercial; Document ingestion API); Pix2Text (Open source; Scientific document parser) |
| Focused | 20 | pdf2json (Open source; PDF parser); iText Core (Open source (AGPL) + commercial; PDF SDK); StrucTexT (Open source / research; Structured text understanding); LiLT (Open weights; Language-independent layout transformer); LayoutXLM (Open weights; Multilingual document model); LayoutParser (Open source; Document layout toolkit); LayoutLMv3 (Open weights; Document understanding model); LayoutLMv2 (Open weights; Document understanding model) |
| Primitive | 0 | — |

## Table extraction

| Scope | Yes count | Top score 12 examples (Tool | License | Category) |
|---|---:|---|
| Broad | 72 | openpyxl (Open source; XLSX parser); lxml (Open source; HTML/XML parser); Zerox (Open source; Vision-model OCR pipeline); Surya (Open source; OCR + layout toolkit); SmolDocling (Open weights; Vision document converter/model); ScholarPhi / PaperMage (Open source; Scientific document representation); Reducto (Commercial; Document ingestion API); Pix2Text (Open source; Scientific document parser) |
| Focused | 19 | StrucTexT (Open source / research; Structured text understanding); LiLT (Open weights; Language-independent layout transformer); LayoutXLM (Open weights; Multilingual document model); LayoutLMv3 (Open weights; Document understanding model); LayoutLMv2 (Open weights; Document understanding model); LayoutLM (Open weights; Document understanding model); DocFormer (Research / open weights; Document transformer); img2table (Open source; Image/PDF table extractor) |
| Primitive | 0 | — |

## Math / LaTeX

| Scope | Yes count | Top score 12 examples (Tool | License | Category) |
|---|---:|---|
| Broad | 31 | openpyxl (Open source; XLSX parser); lxml (Open source; HTML/XML parser); Zerox (Open source; Vision-model OCR pipeline); Surya (Open source; OCR + layout toolkit); SmolDocling (Open weights; Vision document converter/model); ScholarPhi / PaperMage (Open source; Scientific document representation); Reducto (Commercial; Document ingestion API); Pix2Text (Open source; Scientific document parser) |
| Focused | 1 | Texify (Open source; Math OCR model) |
| Primitive | 2 | pix2tex / LaTeX-OCR (Open source; Equation OCR); Im2LaTeX models (Open source / research; Equation OCR model family) |

## Header / section detection

| Scope | Yes count | Top score 12 examples (Tool | License | Category) |
|---|---:|---|
| Broad | 75 | openpyxl (Open source; XLSX parser); lxml (Open source; HTML/XML parser); Zerox (Open source; Vision-model OCR pipeline); Surya (Open source; OCR + layout toolkit); SmolDocling (Open weights; Vision document converter/model); ScholarPhi / PaperMage (Open source; Scientific document representation); Reducto (Commercial; Document ingestion API); Pix2Text (Open source; Scientific document parser) |
| Focused | 11 | StrucTexT (Open source / research; Structured text understanding); Science Parse (Open source / archived; Scientific paper parser); LiLT (Open weights; Language-independent layout transformer); LayoutXLM (Open weights; Multilingual document model); LayoutParser (Open source; Document layout toolkit); LayoutLMv3 (Open weights; Document understanding model); LayoutLMv2 (Open weights; Document understanding model); LayoutLM (Open weights; Document understanding model) |
| Primitive | 0 | — |

## Coordinates / reading order

| Scope | Yes count | Top score 12 examples (Tool | License | Category) |
|---|---:|---|
| Broad | 80 | openpyxl (Open source; XLSX parser); lxml (Open source; HTML/XML parser); Zerox (Open source; Vision-model OCR pipeline); Surya (Open source; OCR + layout toolkit); SmolDocling (Open weights; Vision document converter/model); ScholarPhi / PaperMage (Open source; Scientific document representation); Reducto (Commercial; Document ingestion API); Pix2Text (Open source; Scientific document parser) |
| Focused | 29 | pdf2json (Open source; PDF parser); iText Core (Open source (AGPL) + commercial; PDF SDK); StrucTexT (Open source / research; Structured text understanding); Science Parse (Open source / archived; Scientific paper parser); MMOCR (Open source; OCR toolbox); LiLT (Open weights; Language-independent layout transformer); LayoutXLM (Open weights; Multilingual document model); LayoutParser (Open source; Document layout toolkit) |
| Primitive | 1 | Apple Vision Text Recognition (Proprietary platform API; Platform OCR API) |

## Coverage summary and action items

| Capability | What catalog says today | CoverWise required follow-up gate |
|---|---|---|
| Tables | Strong breadth for native layout/table extractors and OCR+layout suites (91 Yes) | Merge scanned-table, merged-cell, and cell-level provenance benchmarks into the versioned manifest; keep parser swap behind score+failure-state evidence. |
| Layout + reading order | Very high raw coverage (110 Yes in reading-order lane) | Enforce deterministic fallback order and cross-tool reading-order contract in CIR before using non-PyMuPDF lane. |
| Form/KVP & selection marks | Only partial catalog coverage and explicit candidate status in code | Maintain managed/form-specialist lane and never claim form completion without bbox-level evidence + schema audit. |
| Figures and charts | Many OCR/model providers support extraction or captions | Preserve original image artifacts and only add bounded annotations/derived text as non-source evidence. |
| Math / equations | Weak and mixed (34 Yes / 75 No) | Keep as specialist lane with license + corpus benchmark gate. |
| Handwriting | Not represented in this raw matrix file; absent from primary lanes | Keep as separate quality class in capability manifest until a handwriting benchmark is owned. |
| Sentences / language structure | Not represented as a dedicated catalog lane | Keep deterministic punctuation-based segmentation for now and benchmark language-aware sentence/sectioning separately when needed. |
| Image/figure semantics (non-caption metadata) | Supported as extracted artifacts, not as legal fact source | Keep image preservation and treat chart/diagram meaning as derived reviewer annotations under policy-safe confidence thresholds. |

### 2026-07-22 frontier lanes not represented in six fixed catalog columns

| Capability | What the local catalog implies | Current CoverWise runtime state | Hard close gate |
|---|---|---|---|
| Sentence-level fidelity and language boundaries | Broad parser coverage in text+layout families (Docling/Surya/Unstructured and many layout-aware profiles), but no dedicated sentence column | Native sentence splitting from exact offsets, punctuation-first, conservative fallback | Add language-stratified word/line boundary fixtures and multilingual sentence metrics |
| Heading/section hierarchy | Sparse catalog column signal; layout-oriented tools imply heading-level potential | Block geometry is preserved; heading hierarchy is not yet source-grounded | Add heading-depth fixtures with ground-truth nesting and confidence-aware hierarchy fallback |
| Figure/chart extraction and interpretation | Multiple families expose image/visual support (`figure`, `image`, `chart` in outputs/notes), especially Docling/MinerU/Marker/modern VLMs | Original image bytes/hashes are preserved and linked to documents | Add bounded crop→bbox→caption/claim mapping with anti-hallucination checks |
| KVP, forms, and selection marks | Strongly represented in forms-oriented and managed IDP classes (Document AI, Azure DI, Textract, PP-Structure KIE families) | Native AcroForm fields are implemented; scanned KVP/marks are candidate-only | Add schema-bound specialist KVP/mark adapters with review/retry states |
| Multilingual and handwriting | Limited explicit multilingual/handwriting lines in fixed lane columns; surfaced as script observations | Script class is observed and routed; no production handwriting lane | Add script- and script-mix benchmarks, handwritten corpus benchmarks, and manual-review fallback |
| Office/web structure (DOCX/PPTX/XLSX/HTML/EML) | Present across parser families and generic HTML/office tool stack | CIR emits native structure for DOCX/HTML/EML/XLSX/PPTX | Extend relationship-level tests for malformed containers and chart/image-field cross-links |
| Derived image understanding | Broad model families appear in docs as VLM/vision classes, not source-grounded structured evidence | Capability registry marks image understanding as candidate / configured-unverified | Add deterministic image-annotation schema, provider privacy review, and consented benchmark lane |

### 2026-07-22 live capability-state + execution gate ledger

This ledger merges:

- catalog signal from the workbook (`Master Catalog`),
- the strict runtime registry (`src/ocr/capability_registry.py`),
- and executable manifest gates (`docs/eval/document_intelligence/capability_manifest_v1.json`).

| Capability | Runtime status now | What this means for evidence | Next close action |
|---|---|---|---|
| Text/sentence extraction (native + OCR split) | `native_text: available`, `sentence_segmentation: available`, `scanned_ocr: available` (when doctr is installed) | Native text and conservative sentence offsets are source-linked in CIR; scanned text is explicitly classified as `scanned_ocr` | Add word/line boundary fixtures by language and confidence-aware fallback telemetry |
| Layout / reading order | `layout`, `reading_order` both `available` with native + optional profiles | Block order and geometry are emitted and persisted; quality is only baseline for non-legal pages | Add multi-column, rotated, nested-header fixtures before semantic hierarchy claims |
| Tables (structure + cells) | `table` is `available` for native PDF tables; manifest verifies 10 required native structure cases | Table/cell provenance is real for born-digital and office tables; scanned reconstruction is not production-closed | Add scanned-table and malformed-table benchmarks with merged-cell and borderless-cells fixture coverage |
| Figures/images/charts artifacts | `figures` `available` (artifact retention); `charts_and_diagrams` `candidate` | Embedded image bytes and hashes are preserved; chart/diagram meaning stays derived only | Add crop→bbox→caption trace and bounded annotation schema |
| Forms, key/value, selection marks | `forms` available for native AcroForm, `key_value_extraction` `candidate`, `selection_marks` `unavailable` | Native form widgets are evidence-safe; scanned KVP/marks still need specialist profile | Add schema-validated KIE lane with review/retry + uncertainty states before interpreting values |
| Formula/math extraction | `formulas` `candidate` in registry | No source-linked formula lane is wired in production yet | Add math/LaTeX lane with cell-level provenance and normalization checks |
| Office/web/email structure | `office_and_email_structure` is `available` | DOCX/HTML/EML/XLSX/PPTX structures flow into CIR-native nodes and are covered by synthetic executable cases | Add relationship-level tests for charts/images/forms and malformed containers |
| Multilingual routing | `multilingual` `routing_only` (script observation only) | Script family is observed from source text; accuracy is not closed by locale | Add script-stratified language accuracy gates for OCR and segmentation |
| Handwriting | `handwriting` `unavailable` (specialist candidate only) | No routing path produces a production-safe handwriting claim | Add handwriting-specific corpus lane and review-owned fallback policy |
| Image semantic understanding / VLM annotation | `image_understanding` and `vlm_annotation` are `candidate`/`configured_unverified` | Derived annotation is never source evidence and must remain non-citation unless independently verified | Add privacy, retention, failure, and hallucination policy before any semantic image claim |

### 2026-07-22 frontier completeness crosswalk (by capability family)

To avoid scope drift, each capability family keeps one canonical implementation decision:

- **Text / structure / tables / figures:** use native + specialist profiles behind benchmark gates.
- **Forms / KVP / marks / formulas:** keep separate governed lanes; native widget capture only.
- **Language + handwriting:** do not infer quality from script detection alone.
- **Images + charts:** preserve source artifact first, annotate later with bounded confidence.
- **Office/web:** preserve native structure, then map to policy-facing extraction with strict provenance.

The full lane decision remains:

1. `PyMuPDF` and native adapters stay as deterministic launch baseline.
2. `Docling` remains the broad local candidate for CIR completeness where dependencies are stable.
3. `Surya`, `PaddleOCR/PP-Structure`, and `MinerU` stay benchmark/lane candidates.
4. Managed form/document-intelligence providers stay governed cloud candidates with consent and residency gates.
5. VLM image understanding remains derived-only until a bounded annotation benchmark is passed.

### Capability-by-capability "ownership" map (2026-07-22)

This map is the practical routing result for your requested capability classes:
text, sentences, structures, layouts, tables, images/figures/charts, forms, formulas, office/web, multilingual, and image-aware understanding.

| Capability | Best-covered catalog families | CoverWise canonical lane | Proven in runtime code today | What still needs evidence |
|---|---|---|---|---|
| Text extraction | Docling, SmolDocling, MinerU, Surya, PDF-Extract-Kit, OpenParse, Unstructured | `native_text` + `scanned_ocr` in registry + synthetic manifest checks | Yes (`native_text: available`; `scanned_ocr` follows `doctr` profile when present) | Script-aware word/line boundary fixtures; OCR confidence/timeout and partial text recovery telemetry |
| Sentence fidelity / segmentation | (No dedicated catalog column) | `sentence_segmentation` (`conservative_source_segmenter`) + CIR node offsets | Yes (punctuation + exact-offset segmentation in parser output) | Language-aware sentence-boundary benchmarks and punctuation edge-case coverage |
| Layout / structure | Docling, MinerU, Surya, PP-Structure, DoclingDocument model family | `layout` + `reading_order` + `headings_and_sections(candidate)` | Yes (`layout`, `reading_order` available from native pages; heading hierarchy is not semantic source yet) | Nested sections, heading-depth fixtures, multi-column/rotated layout validation |
| Tables (born-digital) | Docling, MinerU, Surya, PP-Structure, pdfplumber, camelot, tabula | `tables: available` for born-digital nodes | Yes for CIR-native rows/cells, formulas included as cell text for `.xlsx` | Scanned-table, merged-cell, borderless-table, and malformed structure failure behavior |
| Images/figures/charts | Docling, MinerU, Marker, LlamaParse, PP-Structure, Mistral OCR, Gemini | `figures` available; `charts_and_diagrams` + `image_understanding` not production-closed | Yes (`figure`/`image` artifacts and hashes are persisted; no source-semantic captions) | Crop→bbox→caption lineage + anti-hallucination checks before image-derived claims |
| Forms / KVP / marks | Azure/Google/managed DI families, PP-Structure KIE, Docling/MinerU candidates | `forms` available (native AcroForm), `key_value_extraction` candidate, `selection_marks` unavailable | Partially (native widgets only for production-safe evidence) | KVP schema + mark detection with manual review and recovery states |
| Formula / math / LaTeX | Surya, PaddleOCR/PP-Structure, MinerU, Marker, Mathpix, Pix2Text | `formulas: candidate` | Not yet production-safe (`formulas` still candidate only) | Formula/Latex extraction benchmarks with source crop/region linkage and normalization checks |
| Office/web/email structure | Native adapters (`python-docx`, `python-pptx`, `openpyxl`, `trafilatura`, `mailparser`) + Docling/OpenParse | `office_and_email_structure: available` | Yes (DOCX/HTML/EML/XLSX/PPTX nodes in CIR, with synthetic coverage) | Relationship-level and malformed-container behavior across embedded images/charts/forms |
| Multilingual | Surya, PP-OCR, PaddleOCR, managed document intelligence | `multilingual: routing_only` | No accuracy closure yet (script signal recorded only) | Script- and language-stratified accuracy + fallback/unsupported-language policy |
| Handwriting | MinerU2.5 family (new), Handwritten OCR models in recent scan sheets | `handwriting: unavailable` | No routing to quality-safe production lane | Specialist handwriting fixtures + manual-review fallback |
| Image-aware semantic understanding | PaddleOCR-VL, Gemini, OpenAI vision, Mistral OCR, Claude/other VLMs | `vlm_annotation` / `image_understanding` configured_unverified | No source-grounded semantic truth in evidence layer | Privacy, retention, provider contract, and bounded annotation benchmark |

### 2026-07-22 web-scan complement to the local catalog (high-signal for frontier)

- Docling concept and `DoclingDocument` model: structured hierarchy, tables, and deterministic reading-order traversal.
- Surya: OCR + layout + reading order + table recognition in multi-language document inputs.
- PaddleOCR PP-Structure / PaddleOCR-VL: document layout, table/formula/image regions + OmniDocBench trajectory in 2026 series releases.
- Practical impact: these scans reinforce using Docling/Surya/PaddleOCR families as lane candidates while keeping managed VLMs in derived-review mode until bounded benchmarks are passed.

### 2026-07-22 frontier scan synthesis: what to treat as "owned" vs "not-owned yet"

Source-of-truth for the launch decision remains:

- `src/ocr/capability_registry.py` (runtime truth statuses),
- `docs/eval/document_intelligence/capability_manifest_v1.json` (hard gates),
- and the local workbook.

For each requested capability class, this is the current ownership boundary:

| Capability class | What covers it today | Current ownership state | Why this is not full completion yet |
|---|---|---|---|
| Text + sentence extraction | `native_text`, `sentence_segmentation`, `scanned_ocr` | **Owned partially** (Tier 2) | Sentence boundary quality is punctuation/offset based, not language-tuned; multilingual boundary fixtures are still missing. |
| Structures (headings, sections, nested hierarchy) | `layout`, `reading_order`, `headings_and_sections(candidate)` | **Candidate / partial** | Heading hierarchy is not yet source-grounded as semantic structure; requires nested-section benchmark + rotated/multicolumn recovery. |
| Layout + reading order | `layout`, `reading_order` | **Owned partially** | Multi-column and rotated layout order is still not benchmarked in production gate. |
| Tables (born-digital) | `tables` + native table/cell nodes | **Owned** | Scanned table reconstruction, merged cells, borderless cases, and OCR-dirty inputs remain open. |
| Images / figures / charts (artifact) | `figures`, `page_artifact_preservation` | **Owned (structural)** | Semantic image understanding and chart claims are still derived-only; crop→bbox→caption binding is missing. |
| Forms / key-value / marks | `forms`, `key_value_extraction`, `selection_marks` | **Partial** | AcroForm widgets are safe; scanned KVP/marks remain open. |
| Formula / math | `formulas` (candidate) | **Not owned** | No source-linked formula lane for production claims. |
| Office/web/email | `office_and_email_structure` + native adapters | **Owned (core)** | Cross-format relationship integrity and malformed-container behavior need dedicated tests. |
| Handwriting | `handwriting` (unavailable, specialist) | **Not owned** | No production-safe handwriting lane; manual-review policy only. |
| Image-aware semantic understanding | `image_understanding`, `vlm_annotation` (configured_unverified/candidate) | **Not owned** | VLM outputs remain unverified and provider/privacy-gated. |

### 2026-07-22 workbook coverage caveat

The workbook does not have dedicated dedicated columns for:

- sentence boundary quality,
- multilingual accuracy per language family,
- handwriting coverage,
- anti-hallucination image semantics.

That means a capability can be `Yes`-heavy in layout/text/table columns but still need explicit benchmark gates for those gaps.

- `Docling` scan: table semantics, formulas, image captions, multi-level headers are advertised as structured outputs in docs.
- `Surya` scan: explicit scope includes OCR, layout analysis, reading order, table recognition, and multilingual reach.
- `PaddleOCR PP-Structure` scan: explicit categories include layout/table/formula and chart parsing in v3-class docs.
- `MinerU` scan: explicit table/formula extraction positioning with post-processing claims.

## Notes
- “Yes” is catalog-reported, not CoverWise field-accuracy proof.
- The catalog is broad on tool diversity, which is useful for architecture planning, but production defaults remain bound to manifest + runtime gates.

### 2026-07-22 execution-ready capability atlas (requested lanes)

For your requested lanes (text/sentences, structures, layouts, tables, images/figures/charts, forms, formulas, language), this is the explicit ownership boundary used by routing:

| Lane | Live runtime status (`src/ocr/capability_registry.py`) | What is production-owned today | Remaining open gate |
|---|---|---|---|
| Text + sentence extraction | `native_text: available`, `sentence_segmentation: available`, `scanned_ocr: available` (when doctr profile enabled) | Native digital text + conservative sentence nodes with exact offsets; scanned OCR produces `scanned_ocr` with image artifact tracking | Language-aware word/line boundary fixtures, punctuation and script-edge regression behavior |
| Structures (sections/headings) | `headings_and_sections: candidate` | Native block geometry and structural nodes are emitted | Semantic heading hierarchy from source and heading-depth recall/precision |
| Layout + reading order | `layout: available`, `reading_order: available` | Native page geometry and stable block/page sequencing | nested sections, rotated pages, and multi-column ordering benchmarks |
| Tables (digital + scanned recovery) | `tables: available` (digital), scanned-table specialists pending | Digital table/cell nodes for PDF + DOCX/HTML/EML/XLSX/PPTX paths | Scanned-table reconstruction, merged-cell, borderless, and malformed-grid fixtures |
| Images/figures/charts | `figures: available`, `charts_and_diagrams: candidate`, `image_understanding: candidate`, `vlm_annotation: candidate` | Artifact preservation with page images and image hashes is guaranteed | bounded crop→bbox→caption mapping and derived-caption anti-hallucination policy |
| Forms / key-value / marks | `forms: available`, `key_value_extraction: candidate`, `selection_marks: unavailable` | AcroForm widgets are owned; scans and marks remain non-default | specialist form/KVP providers or managed IDP lanes with schema + review states |
| Formula / math | `formulas: candidate` | No production formula lane today | Formula pipeline with source-region lineage + normalization and domain validation |
| Multilingual + handwriting | `multilingual: routing_only`, `handwriting: unavailable` | Script-family observation only; no production handwriting lane | language-stratified OCR accuracy and handwriting corpus with manual-review fallback |

### 2026-07-22 execution matrix (single-row closure checklist)

Use this when selecting a parser lane for a requested class:

| Class | Discovery-backed frontier | Runtime anchor | Production proof status | Immediate next hard gate |
|---|---|---|---|---|
| Text + sentence extraction | Docling/MinerU/Surya + frontier OCR families | `native_text`, `sentence_segmentation`, `scanned_ocr` | Partial (native + synthetic) | Add language-aware sentence and word-boundary corpus gates; keep OCR uncertainty visible |
| Structures / sections / hierarchy | Docling/Surya/PP-Structure + specialist parsers | `layout`, `headings_and_sections(candidate)`, `reading_order` | Partial | Add hierarchy and nested-section ground-truth fixtures before semantic claims |
| Layout + reading order | Docling/Surya and layout families | `layout`, `reading_order` | Partial | Add rotated/multi-column/low-DPI ordering fixtures and failure telemetry |
| Tables (digital) | Docling/MinerU/Surya + many table engines | `tables`, native table/cell adapters | Owned for born-digital/office | Add scanned-table reconstruction + merged/borderless/malformed grid coverage |
| Images / figures / charts (structural) | Docling/Marker/LLM vision classes | `figures`, page-image artifact hashing | Owned structurally | Add crop-to-bbox-to-caption lineage + anti-hallucination checks |
| Charts (semantic understanding) | Mistral OCR, Gemini/OpenAI/Claude families | `charts_and_diagrams`, `image_understanding`, `vlm_annotation` | Candidate only | Add bounded benchmark + provider/privacy + derived-only policy |
| Forms / key-value / selection marks | Azure DI, Google DI, Textract, Paddle KIE + Docling/MinerU candidates | `forms`, `key_value_extraction`, `selection_marks` | Partial (AcroForm only) | Add schema-validated KVP + mark + review/retry lane before policy interpretation |
| Formula / math / LaTeX | MinerU/Surya/Paddle/Mathpix/Pix2Text | `formulas` (candidate) | Not owned | Add formula/LaTeX extraction with source region lineage and normalization |
| Office / web / email structure | python-docx/openpyxl/python-pptx/trafilatura/mailparser + docling stack | `office_and_email_structure` | Owned for core structures | Add malformed-container and cross-format relationship-preservation tests |
| Multilingual | Surya/PaddleOCR + managed DI | `multilingual` (routing only) | Not accuracy-closed | Add script- and locale-specific OCR accuracy gates |
| Handwriting | Frontier specialist families only | `handwriting` (unavailable) | Not owned | Add specialist handwriting corpus + review fallback before use |
