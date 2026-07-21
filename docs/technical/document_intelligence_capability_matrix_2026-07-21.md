# CoverWise document-intelligence capability matrix — 2026-07-21

## Purpose and evidence boundary

This is the current research and architecture record for OCR, document
parsing, layout understanding, table extraction, image/figure handling, and
vision-language models (VLMs) in CoverWise. It was assembled from:

- `/Users/pranay/Downloads/document_parsers_extractors_catalog_2026_v2.xlsx`,
  inspected locally. The workbook contains 149 catalog entries in `Master
  Catalog`, plus a capability guide, research notes, coverage audit, recent
  models, and a separate general-VLM sheet.
- Existing local research:
  `docs/technical/ocr_pipeline_research_2026-07-11.md` and
  `docs/technical/local_document_intelligence_evaluation_2026-07-12.md`.
- Current code, especially `src/ocr/pipeline.py`,
  `src/services/document_processing_service.py`,
  `src/workers/substrate_extraction_handler.py`,
  `src/models/extraction.py`, and the evidence-substrate services.
- Primary project sources and vendor documentation linked below.

The workbook is a discovery catalog, not proof that any tool is accurate on
CoverWise policies. A tool is “available” in this document only as a research
candidate unless the local corpus benchmark, license review, privacy review,
and runtime integration gate are all passed.

## First-principles decision

CoverWise needs capability coverage, not a universal parser. The durable shape
is one capability-routed, source-preserving pipeline:

```text
upload -> validate/quarantine -> classify -> native extraction when possible
       -> quality gate -> specialist OCR/layout/table/formula route
       -> canonical intermediate representation (CIR)
       -> source-grounded policy fields/evidence -> retrieval/indexing -> UI
```

There is one canonical processing flow and one canonical evidence contract.
Parsers and models are replaceable workers behind that flow. VLM output is a
derived proposal; it is never the source of truth and never overwrites a
source value without page/block evidence and deterministic validation.

This preserves the product promise: a user can inspect what was found, where it
was found, how confident the system is, and what remains unknown. It also lets
the operator improve one capability without coupling every document to the
most expensive model.

## Current code truth

| Area | What the code does now | Evidence | Gap or consequence |
| --- | --- | --- | --- |
| Born-digital PDF text | Uses PyMuPDF before OCR | `src/ocr/pipeline.py` and the 2026-07-12 local evaluation | Correct default for embedded text; preserve page provenance through the CIR. |
| Scanned/image OCR | Uses doctr in `OCRPipeline`; mobile has an ML Kit sidecar | `src/ocr/pipeline.py`, `src/services/document_processing_service.py` | Surya, PaddleOCR, and Docling are not production dependencies; benchmark before replacement. |
| Image preprocessing | `_preprocess_image` performs preprocessing | `src/ocr/pipeline.py` | Older research text saying preprocessing is absent is stale; keep it as historical and use this record as the correction. |
| Layout | Current page-level results and optional Docling layout elements exist | `src/ocr/pipeline.py` | The representation is not yet a complete typed layout tree with reading order and parser provenance. |
| Tables | MinerU branch can return simple table payloads; the main path has no canonical table model | `src/ocr/pipeline.py`, `src/models/extraction.py` | Table cells, spans, merged cells, and table evidence need a first-class CIR contract. |
| Figures/images/charts | Original pages are available; no durable figure/crop/caption contract is exposed | `src/ocr/pipeline.py` and evidence paths | Preserve the original artifact and crop/bbox; VLM descriptions remain derived annotations. |
| Formulas | No first-class formula output in the extraction models | `src/models/extraction.py` | Route scientific/formula-heavy inputs to a specialist only when corpus evidence justifies it. |
| Policy extraction | Summary-centric Pydantic models and a single structured extraction call | `src/models/extraction.py`, `src/services/policy_extraction_service.py` | Add source span, page, confidence, and validation links; do not make summary JSON the evidence substrate. |
| Evidence | Durable page artifacts/source spans/extracted fields/field evidence exist | `src/workers/substrate_extraction_handler.py` and evidence services | Extend the substrate/CIR rather than creating a parallel parser output store. |
| Optional parser imports | `DOCLING_ENABLED` and `MINERU_ENABLED` are false by default; doctr is imported when `OCRPipeline` is constructed | `src/config/settings.py`, `src/ocr/pipeline.py` | Slim API imports are resilient; scan execution still needs an observable OCR-unavailable state and local dependency/runtime verification. |

## Capability matrix and routing recommendation

“Default” means the canonical path can use it after the existing validation and
evidence gates. “Candidate” means it belongs in the benchmark lane. “Cloud
candidate” means it requires a data-handling, residency, cost, and consent
decision before use on customer documents.

| Capability | Default first choice | Candidate specialists | Required output/evidence |
| --- | --- | --- | --- |
| Embedded PDF text | PyMuPDF | pdfminer.six, pdfplumber, pypdfium2 | Exact page text, character spans, page hash, extraction method. |
| Office/web/email structure | Native OOXML/HTML/CSV parsers; MarkItDown/Tika for conversion | Unstructured, python-docx, Apache POI, mailparser, Trafilatura | Source format, paragraph/list/table structure, relationship to original file. |
| Scanned plain text | Existing doctr until benchmarked | Surya, PaddleOCR/PP-OCR, Tesseract, OCRmyPDF | Words/lines, confidence, coordinates, language, page image hash. |
| Mixed PDF layout and reading order | Docling as the first broad local benchmark candidate | MinerU, Marker, PaddleOCR PP-Structure/VL, Unstructured, LlamaParse/Reducto | Typed blocks, reading order, hierarchy, bounding boxes, parser/model/version. |
| Born-digital tables | Native PDF geometry plus pdfplumber/Camelot where needed | Tabula, PyMuPDF table tools | Cell text, row/column indexes, merged-cell spans, table bbox, source spans. |
| Scanned tables | Layout/table specialist, beginning with PP-Structure/table models | TATR, GMFT, img2table, RapidTable, MinerU | Cell coordinates, row/column structure, HTML/CSV rendering, cell confidence. |
| Forms and key/value pairs | Evidence-backed layout + schema extraction | Azure Document Intelligence, Google Document AI Form Parser, AWS Textract, Paddle KIE, Mindee/Rossum | Key/value geometry, checkbox state, confidence, schema validation, provider audit. |
| Selection marks/signatures | Specialist form route | Textract, Azure DI, Google Form Parser, Paddle KIE | Mark/signature bbox and confidence; never infer legal validity from detection. |
| Equations/formulas | Preserve source crop and text first | MinerU, Paddle formula recognition, Nougat, GROBID, Mathpix/Pix2Text | LaTeX/MathML plus source bbox and normalization status. |
| Figures/images | Preserve original image/crop as the source artifact | Docling, Azure DI, Mistral OCR, layout models | Artifact hash, page/bbox, MIME/type, caption relation; no generated caption as source evidence. |
| Charts/diagrams | Preserve image and bounded derived annotation | Mistral annotations, Gemini image understanding, general VLM reviewer | Original crop, annotation schema, confidence, “derived description” label. |
| Handwriting | Treat as a separate quality class | Managed DI/Textract/Azure/Google or specialized OCR | Word/line confidence, uncertainty, manual review state. |
| Multilingual / Hindi-English | Route by detected language/script | PaddleOCR, Surya, Docling/OCR engines, managed providers | Language/script per block, confidence, normalization without losing source text. |
| Semantic insurance fields | Structured extraction after CIR | Existing policy extractor, bounded VLM/LLM reviewer | Field value, source span/page, confidence, validation result, unknown reason. |
| RAG and citations | Index source text separately from retrieval text | Table-row/cell and figure-caption views | Source text immutable; retrieval text derived; citation resolves to page/block/cell. |

## Tool selection by product role

| Role | Current recommendation | Why |
| --- | --- | --- |
| Fast deterministic baseline | PyMuPDF and native format parsers | Lowest latency, strongest provenance, no model hallucination. |
| Broad local document representation | Docling | Its `DoclingDocument` models text, tables, pictures, hierarchy, layout, and provenance in one representation. It is the best first candidate for a CIR adapter, not yet an installed production dependency. |
| Local scan/layout benchmark | Surya and PaddleOCR/PP-Structure | They cover OCR, layout, reading order, and tables with different deployment tradeoffs. Existing local Surya evidence is only a targeted synthetic test. |
| Complex parser benchmark | MinerU | Strong broad coverage, but current license wording and dependency/runtime profile require a fresh legal and operational review. Do not retain the old blanket “AGPL” statement as fact. |
| Managed high-recall forms | Azure DI, Google Document AI, AWS Textract | Strong form/table/selection-mark primitives, but cloud data handling and cost are product decisions, not implementation details. |
| VLM reviewer/annotation | Gemini, Mistral OCR annotations, Qwen/Gemma class local reviewers | Useful for derived descriptions, ambiguous structure, and bounded review; JSON schema does not prove semantic correctness. |

## Canonical intermediate representation (CIR)

The next implementation unit should extend the existing evidence substrate with
a versioned representation, not add a second parser-specific table. At minimum
each node needs:

```text
document_id, page_id, node_id, node_type
source_artifact_hash, source_uri/reference, page_number
text/source_text, retrieval_text (derived and separate)
bbox/ polygon, reading_order, parent_id, language
table_id/row_index/column_index/merged_span when applicable
confidence, quality_flags, parser_name, parser_version, model_version
run_id, created_at, validation_status, evidence_reference
```

Node types are `page`, `text_block`, `line`, `word`, `heading`, `list`,
`table`, `table_cell`, `figure`, `chart`, `formula`, `form_field`,
`selection_mark`, `signature`, `caption`, and `annotation`. Original uploaded
bytes remain the source artifact; OCR text, captions, normalized values, and
embeddings are derived artifacts with lineage.

## Benchmark and release gates

The workbook’s proposed benchmark dimensions are adopted and expanded for the
insurance domain. The benchmark manifest must include digital PDFs, scans,
rotated/low-quality pages, multi-column schedules, nested tables,
Hindi-English pages, forms, figures, and blank pages. For each parser profile,
record:

- character/word fidelity and sentence/paragraph segmentation;
- reading-order and layout-block accuracy;
- table cell, merged-cell, row/column, and HTML/CSV fidelity;
- formula fidelity where present;
- policy-field exact match and canonical normalization;
- page/block/cell provenance accuracy and unsupported-claim rate;
- p50/p95 latency, memory, timeout, retry, and partial-success behavior;
- package/model/license terms, platform requirements, cost, residency, and
  retention behavior.

No parser becomes a production default from a vendor score alone. The release
gate is a versioned CoverWise corpus result with source-preserving evidence and
operator-visible failures. The existing local contract in
`local_document_intelligence_evaluation_2026-07-12.md` remains the governing
minimum for field accuracy and provenance.

## Privacy, licensing, and operational boundaries

- Customer policy bytes and source text stay in the existing storage/evidence
  contract. Benchmark reports contain hashes and labels, not customer text.
- Cloud routes require explicit provider, residency, retention, consent, and
  cost decisions. “Supports PDFs” is not a data-handling approval.
- Code license and model/weight license are separate checks. Docling’s code,
  Surya’s repository, MinerU’s current repository terms, and bundled model
  weights must each be reviewed before commercial deployment.
- OCR/parser failure is a first-class state. The UI must show unknown or
  review-needed evidence instead of silently falling back to a guessed field.
- VLMs may describe a chart or propose a field, but a generated description is
  never proof that an insurance benefit or exclusion exists.

## Decision units and implementation sequence

1. Define and test the CIR/evidence adapter against existing page artifacts and
   source spans.
2. Add a capability classifier and quality gate to the existing document
   processing service; keep one route and one durable job path.
3. Benchmark PyMuPDF, doctr, Surya, PaddleOCR/PP-Structure, and Docling on the
   versioned corpus; add MinerU and managed providers only in isolated profiles.
4. Add table/figure/formula fixtures and field-level evidence validation before
   any new parser becomes a launch default.
5. Add operator-visible parser profile, model version, confidence, and failure
   telemetry to the existing processing/evidence views.

## Anything else?

Yes: the attached catalog is broad enough to prevent capability blind spots,
but it should not become a dependency list. The highest-leverage missing piece
is not another model; it is the CIR plus benchmark harness that makes parsers
replaceable and every user-visible field inspectable. The current eager doctr
import and the incomplete optional Docling/MinerU output are the first code
hardening items because they affect whether the documented fallback architecture
is actually true at runtime.

## Implementation addendum (2026-07-21)

The first implementation slice now exists in `src/models/document_intelligence.py`:
`DocumentCIR`, `CIRNode`, deterministic capability classification, source
hashing, and a builder for page/text/artifact lineage. Existing OCR and
document-processing results carry the CIR while retaining their legacy fields;
`src/ocr/pipeline.py` no longer imports doctr until an OCR pipeline is actually
constructed. The existing `rag_only` orchestration path also now initializes
its optional OCR result explicitly, avoiding an unbound-variable failure.

This is a foundation, not a claim that tables/forms/formulas are solved. Those
node types remain deliberately absent until a specialist adapter can prove
them. The next code gate is to connect CIR nodes to the existing page-artifact
and source-span persistence without introducing a second evidence store.

## Primary sources

- [DoclingDocument](https://docling-project.github.io/docling/concepts/docling_document/)
- [Docling architecture](https://docling-project.github.io/docling/concepts/architecture/)
- [Docling confidence scores](https://docling-project.github.io/docling/concepts/confidence_scores/)
- [MinerU repository](https://github.com/opendatalab/MinerU)
- [PaddleOCR and PP-Structure](https://github.com/PaddlePaddle/PaddleOCR)
- [Surya repository](https://github.com/datalab-to/surya)
- [Azure Document Intelligence layout](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/prebuilt/layout?view=doc-intel-3.1.0)
- [Google Document AI layout parser](https://docs.cloud.google.com/document-ai/docs/layout-parse-chunk)
- [AWS Textract tables and layout](https://docs.aws.amazon.com/textract/latest/dg/how-it-works-tables.html)
- [Mistral OCR](https://docs.mistral.ai/api/endpoint/ocr)
- [Gemini document understanding](https://ai.google.dev/gemini-api/docs/document-processing)
- [Gemini structured output](https://ai.google.dev/gemini-api/docs/structured-output)
- [OmniDocBench](https://github.com/opendatalab/OmniDocBench)
- [DocLayNet](https://github.com/DS4SD/DocLayNet)
- [PubTables-1M](https://arxiv.org/abs/2110.00061)
