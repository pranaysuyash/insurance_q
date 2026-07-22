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
| Sentence structure | CIR derives conservative sentence nodes from page text with exact source offsets and parent linkage | `src/models/document_intelligence.py`, `tests/test_document_intelligence_contract.py` | Structural segmentation is not language-specific sentence accuracy; specialist multilingual segmentation remains a benchmark gate. |
| Multilingual signal | CIR observes Unicode script families and records a `multilingual` capability when multiple families are present | `src/models/document_intelligence.py`, `tests/test_document_intelligence_contract.py` | This is routing metadata only; script-level OCR accuracy, language identification, and translation quality still require corpus gates. |
| Scanned/image OCR | Uses doctr in `OCRPipeline`; mobile has an ML Kit sidecar; the canonical production image now installs the same pinned doctr profile | `src/ocr/pipeline.py`, `src/services/document_processing_service.py`, `requirements-production-ocr.txt`, `Dockerfile` | Surya, PaddleOCR, and Docling remain optional specialist candidates; benchmark before replacement. |
| Image preprocessing | `_preprocess_image` performs preprocessing | `src/ocr/pipeline.py` | Older research text saying preprocessing is absent is stale; keep it as historical and use this record as the correction. |
| Layout | Current page-level results and optional Docling layout elements exist | `src/ocr/pipeline.py` | The representation is not yet a complete typed layout tree with reading order and parser provenance. |
| Tables | Native PDF path now emits table/table-cell nodes through PyMuPDF; optional MinerU remains separate | `src/ocr/native_pdf.py`, `src/services/document_processing_service.py` | Native born-digital tables are measured; scanned/nested/merged-cell coverage still needs specialist corpus gates. |
| Native PDF forms | PyMuPDF AcroForm widgets emit source-linked `form_field` nodes with name, type, value, flags, and geometry | `src/ocr/native_pdf.py`, `tests/test_native_pdf_adapter.py` | Native widget structure is measured; scanned key/value forms and selection marks still require specialist corpus gates. |
| Figures/images/charts | Original pages are available; no durable figure/crop/caption contract is exposed | `src/ocr/pipeline.py` and evidence paths | Preserve the original artifact and crop/bbox; VLM descriptions remain derived annotations. |
| Formulas | No first-class formula output in the extraction models | `src/models/extraction.py` | Route scientific/formula-heavy inputs to a specialist only when corpus evidence justifies it. |
| Policy extraction | Summary-centric Pydantic models and a single structured extraction call | `src/models/extraction.py`, `src/services/policy_extraction_service.py` | Add source span, page, confidence, and validation links; do not make summary JSON the evidence substrate. |
| Evidence | Durable page artifacts/source spans/extracted fields/field evidence exist | `src/services/document_processing_service.py`, `src/services/evidence_substrate_service.py` | CIR nodes with text and geometry now persist as source spans; extend the substrate/CIR rather than creating a parallel parser output store. |
| Optional parser imports | `DOCLING_ENABLED` and `MINERU_ENABLED` are false by default; doctr is imported when `OCRPipeline` is constructed | `src/config/settings.py`, `src/ocr/pipeline.py` | The canonical production image includes doctr; the slim dependency profile must not be used for customer deployment. |

### Addendum — local catalog inventory snapshot (2026-07-22)

We ingested `/Users/pranay/Downloads/document_parsers_extractors_catalog_2026_v2.xlsx`
in-code and persisted a derived artifact at
`docs/technical/document_parser_capability_catalog_2026-07-22.md`.

Key counts from the `Master Catalog` (149 rows):

- Text OCR: Yes 121, Partial 2, Depends 3, No 13, OCR-dependent 10
- Layout awareness: Yes 89, Partial 39, Depends 2, No 17
- Table extraction: Yes 91, Partial 18, Depends 2, No 36
- Math / LaTeX: Yes 34, Partial 37, Depends 3, No 75
- Header / section detection: Yes 86, Partial 18, Depends 2, No 42
- Coordinates / reading order: Yes 110, Partial 31, Depends 2, No 5

This is capability breadth evidence, not runtime accuracy proof. The capability
status used by production pathing still comes from:

- `docs/technical/local_document_intelligence_evaluation_2026-07-12.md`
- `docs/technical/local_document_intelligence_evaluation_2026-07-22.md`
- `docs/eval/document_intelligence/capability_manifest_v1.json`
- `src/ocr/capability_registry.py`

Interpretation for route design:

- **Strong lanes already represented in the catalog:** raw text, tables, layout,
  reading order, sentence-level text nodes when format allows it.
- **Weak or specialist lanes by evidence depth:** formulas, handwriting,
  chart/diagram interpretation, and selection-mark semantics.
- **High-leverage next gap:** no capability gains without a typed CIR adapter and
  manifested benchmark gates for scan tables, forms, and formulas.

### Addendum — mixed-page extraction truthfulness (2026-07-21)

The canonical `DocumentProcessingService` now preserves mixed-PDF capability
boundaries. Native-text pages are recorded separately from image-only pages;
image-only pages use the shared doctr OCR predictor when available, and the CIR
emits both `native_text` and `scanned_ocr` when both are observed. Unrecoverable
image-only pages produce an explicit `partial` OCR stage/document state rather
than being silently omitted. This is a routing and provenance correction, not
evidence of corpus-level OCR accuracy.

The local doctr adapter also retries the untouched page image when the
preprocessed prediction is empty or trivially small. This handles a concrete
preprocessing failure mode without replacing the source artifact or claiming
that the fallback improves corpus accuracy; the evaluator records the same
runtime path.

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

This is a foundation, not a claim that every document capability is solved.
Native born-digital table and figure nodes now exist; forms, formulas,
handwriting, and scan/table recovery remain absent until specialist adapters
prove them. The next code gate is to connect CIR nodes to the existing
page-artifact and source-span persistence without introducing a second evidence
store.

The deterministic native-PDF adapter is now implemented in
`src/ocr/native_pdf.py`. It emits observable layout blocks, table/table-cell
coordinates, source-linked AcroForm fields, and hashed embedded-image figure nodes using the project’s
PyMuPDF dependency. The versioned benchmark is
`docs/eval/document_intelligence/capability_manifest_v1.json`, executed by
`tools/evaluate_document_capabilities.py`. Its native text/table/figure/form
cases pass;
OCR, forms, formulas, multilingual/handwriting, and VLM figure annotation
remain explicit benchmark gates.

The local generated-scan doctr case was then executed with the project venv:
all three expected tokens were recovered in 2.314 seconds, producing
`scanned_ocr` and `image_artifact` capabilities. This is Tier 2 synthetic
evidence only; it does not establish field accuracy or justify a production
default without the versioned consented corpus gate.

### Addendum — standalone OCR runner parity (2026-07-21)

The evaluator now calls `src.utils.native_runtime.configure_native_library_paths`
before constructing the optional doctr pipeline, matching the API entrypoint.
This closes a reproducibility gap on macOS: the project venv had doctr and all
Python dependencies installed, but a direct evaluator invocation could still
fail to load Homebrew GLib/Pango libraries. The strict evaluator now passes the
synthetic native and doctr cases through `uv` using `.venv/bin/python`.

### Addendum — native form structure (2026-07-21)

The native adapter and capability manifest now include a generated AcroForm
case. It verifies that field name, type, value, flags, and bounding box are
preserved as `form_field` evidence. This closes the born-digital form-structure
layer while keeping scanned key/value extraction, selection marks, and semantic
form interpretation behind specialist corpus and privacy gates.

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

## Addendum — live primary-source recheck and environment-contract hardening (2026-07-21)

The attached workbook was re-read directly from its seven sheets using the
project Python environment's standard-library XLSX reader. It contains 149
master-catalog entries, a capability guide, research notes, a coverage audit,
77 recent-model rows, and a separate 34-row general-VLM/OCR sheet. The catalog
therefore remains a research inventory, not a dependency manifest or accuracy
claim.

A fresh first-party source recheck confirms the important capability boundaries:
Docling's current `DoclingDocument` represents text, tables, pictures,
key-value items, hierarchy, layout, and provenance; Surya exposes OCR,
line-level detection, layout, reading order, table recognition, and LaTeX OCR
but documents limitations around handwriting and non-document photos; MinerU
currently advertises structured Markdown/JSON, formulas, tables, images,
scanned-document OCR, and 109-language support; PaddleOCR's current release
line includes PP-Structure and PaddleOCR-VL document parsing. These are
capability claims from primary project sources, not CoverWise benchmark results.

The earlier note saying CIR persistence was still the next code gate is now
superseded: `DocumentProcessingService._ingest_into_rag()` writes page artifacts
and geometry-bearing source spans through `EvidenceSubstrateService`, while
non-highlightable nodes remain in page `layout_json` without fabricated spans.
The remaining gap is coverage and quality of specialist adapters, not a second
storage path.

The runtime configuration audit also found and fixed a real source-of-truth
drift. The canonical services now use `supabase_server_key()` and accept both
the internal compatibility name `SUPABASE_SERVICE_ROLE_KEY` and the current
project name `SUPABASE_SECRET_KEY` when instantiated directly. This covers the
evidence substrate, processing events, model/dataset lineage, artifact
registry, document repository/object store, auth, RAG vector store, consent,
policy domain/extraction, account lifecycle, anti-abuse, and document
processing paths. This is configuration correctness; it does not prove remote
schema or production deployment state.

## Addendum — source-span capability vocabulary (2026-07-21)

The evidence substrate now accepts explicit source-bearing span types for text
blocks, sentences, headings, lines, words, tables/table cells, formulas, form
fields, captions, and annotations. The ingestion adapter maps CIR node types to
these values rather than collapsing every non-table node into `paragraph`.
Image-only figures remain page-artifact/layout evidence because inserting a
generated caption as `span_text` would turn a derived description into source
proof. The local migration is applied and schema lint is the release check for
this contract.

## Addendum — runtime capability registry (2026-07-21)

`src/ocr/capability_registry.py` now exposes a side-effect-free runtime
snapshot consumed by `/health` and `tools/inspect_document_capabilities.py`.
It distinguishes active profiles from disabled optional packages, benchmark
candidates, and unavailable capabilities. This is operational truth about
what the current process can route to; it is not a claim that an available
profile has passed the consented corpus quality gate. The registry deliberately
does not import heavyweight model runtimes or contact external providers.

The registry also reports `vlm_annotation` explicitly. OpenAI and local Ollama
profiles may be `configured_unverified`, while Mistral/Gemini profiles remain
candidates until an image fixture, structured-output, privacy, and provider
failure benchmark passes. A configured chat model is never treated as proof of
image understanding.

## Addendum — live VLM registry and final local regression (2026-07-21)

Current-code API port 8007 returned a healthy `/health` response with the VLM
profiles visible at runtime. The local regression completed with 432 backend
tests passed and 639 Flutter tests passed; Flutter analysis and static checks
are clean. These results establish implementation/runtime readiness locally,
not specialist image-quality or remote production readiness.

The strict document-capability evaluator was rerun with the project `.venv` and
`--ocr-profile doctr`. All five manifest cases passed with zero unrun cases:
native text/layout, native table/figure, scanned OCR, mixed native/scanned OCR,
and native forms. This is synthetic Tier 2 evidence; the manifest still
correctly leaves specialist scanned-table, formula, handwriting, multilingual,
and VLM quality gates open.

## Addendum — production OCR dependency parity (2026-07-21)

The deployment audit found that `Dockerfile` previously installed the slim
`requirements.txt` profile while local verification used `requirements-local.txt`.
That made scanned-document behavior diverge by environment. The canonical
customer-facing image now installs `requirements-production-ocr.txt`, which
pins the same PyTorch/doctr OCR runtime used by the strict benchmark. The
Cloud Run deploy default is increased to 4Gi for this model-bearing image.

This closes dependency parity, not specialist quality: the five-case benchmark
is synthetic Tier 2 evidence, and real-corpus accuracy, latency, and failure
recovery still gate release decisions.

The first Linux container smoke also found a missing WeasyPrint dependency;
`libpangoft2-1.0-0` is now included in the Docker image. The corrected image
has not yet been runtime-verified because Docker Desktop stopped responding
during the rebuild. Host `.venv` verification remains healthy only after the
project native-library bootstrap is applied.

The deployment-contract tests pass, and the full backend suite passes **442
tests with 1 intentional skip** when its temporary files are directed to
`/tmp`. Container runtime verification remains separate because Docker Desktop
is currently unavailable.

## Addendum — x86_64 container execution verified (2026-07-21)

The production OCR image is now architecture-explicit: `linux/amd64` with
CPU-only Torch/torchvision. Linux ARM64 was rejected as a container target
after direct evidence showed torchvision model-forward segmentation faults,
even though basic Torch imports worked. The rebuilt x86_64 image passed doctr
predictor initialization and a generated scanned-page OCR smoke containing a
policy title, policy number, and effective date. `/healthz` also returned 200
from the running container. `redis==5.0.1` was promoted into the production
dependency profile after the first app-start smoke found it missing.

The complete `/health` contract still requires a valid embedding provider: the
credentialed smoke returned 503 because the current local OpenAI key returned
401 and the production image intentionally has no sentence-transformers local
fallback. This is provider readiness evidence, not evidence against OCR.

## Addendum — catalog coverage audit and capability-complete research map (2026-07-21)

The supplied workbook was inspected directly rather than treated as a dependency manifest. Its seven sheets contain 149 master-catalog records, 77 recent-model records, and 34 general-VLM/OCR records. The catalog marks text extraction present for 121 records, layout for 89, tables for 91, headers/sections for 86, coordinates/reading order for 110, and math/LaTeX for 34. These are catalog labels, not CoverWise accuracy results.

The runtime registry now mirrors the actual product vocabulary: sentence segmentation, reading order, headings/sections, tables, key/value extraction, selection marks, figures, charts/diagrams, image understanding, formulas, handwriting, multilingual routing, and office/email structure. `available` means a callable local path with targeted evidence; `routing_only` means observation without quality proof; `candidate` means benchmark-only; `unavailable` means no safe canonical profile; and `configured_unverified` means configuration exists without provider/image-contract proof.

| Capability family | Current CoverWise truth | Closure path |
| --- | --- | --- |
| Text, words, lines, sentences | Native PDF text and exact-offset conservative sentence nodes are implemented; doctr provides the proven scan OCR path. | Add language-specific boundary and word/line alignment fixtures. |
| Layout, hierarchy, reading order, headers | Native block geometry/order exists; semantic heading hierarchy does not. | Benchmark Docling, Surya, and PP-Structure on multi-column, rotated, header/footer, and nested-section fixtures. |
| Born-digital tables | PyMuPDF table/cell nodes with coordinates are implemented and measured. | Add merged-cell, spanning-header, borderless, and malformed-table fixtures. |
| Scanned tables | Not production-available. | Isolate PP-Structure, Surya, TATR/GMFT/img2table, and MinerU; require cell provenance plus HTML/CSV fidelity. |
| Forms, key/value, marks | Native AcroForm widget evidence is implemented; semantic scanned form extraction is not. | Benchmark managed form parsers and Paddle KIE with schema validation and manual-review states. |
| Figures, images, charts, diagrams | Embedded-image bytes are hash-preserved; semantic interpretation is not source evidence. | Add crop/bbox/caption relations and a bounded derived-annotation schema. |
| Formulas, handwriting, multilingual accuracy | No production formula/handwriting profile; Unicode script observation is routing metadata only. | Benchmark specialist profiles on consented fixtures and default uncertainty to review. |
| DOCX/PPTX/XLSX/HTML/email | Native DOCX, HTML, EML, XLSX/XLSM, and PPTX structure now enters the CIR; formula semantics and visual interpretation remain open. | Add format-specific relationship fixtures and specialist quality benchmarks. |
| VLM/LLM semantic extraction | Downstream of source evidence; image/VLM annotation remains candidate/unverified. | Require schema validation, source references, unsupported-claim checks, privacy/retention approval, and cost/latency metrics. |

Docling is the strongest broad local CIR candidate because its first-party representation includes text, tables, pictures, hierarchy, layout, provenance, key/value items, and reading order. Surya is the strongest local specialist comparison for OCR, layout, reading order, tables, and LaTeX OCR, with its own printed-document and non-handwriting limits respected. PaddleOCR PP-Structure/PaddleOCR-VL is the strongest specialist comparison for layout, tables, KIE, and document-VLM parsing. MinerU remains isolated until current code/weights licensing, resources, and CoverWise corpus results are reviewed together.

We will not install every catalog entry into the customer image: conflicting weights, platform constraints, licensing obligations, and unmeasured fallback behavior would make the system less trustworthy. Each candidate must earn promotion through fixture, provenance, privacy, license, latency, and recovery gates. Inspect the current runtime state with `.venv/bin/python tools/inspect_document_capabilities.py`. The strict ten-case manifest now covers native text/layout, native table/figure, scanned OCR, mixed native/scanned OCR, native forms, DOCX, HTML, EML, XLSX, and PPTX structure. It still does not close scanned tables, semantic form interpretation, formula fidelity, handwriting, multilingual accuracy, or VLM image understanding; those remain explicit launch-gated work.

## Addendum — native XLSX/PPTX structure closure (2026-07-22)

The canonical service now routes `.xlsx`/`.xlsm` through `openpyxl-native` and
`.pptx` through `python-pptx-native`, both into the existing CIR rather than a
parallel text store. XLSX preserves worksheet identity, cell coordinates,
data types, formula text, and embedded-image hashes when present. PPTX
preserves slide identity, title/text-shape order, table/cell coordinates, and
embedded-picture hashes when present. The project `.venv` contains
`openpyxl==3.1.5` and `python-pptx==1.0.2`, and both are pinned in
`requirements.txt`.

The manifest now has ten executable cases and all ten pass with the local
`doctr` OCR profile (synthetic Tier 2 evidence). This closes deterministic
Office structure, not formula semantics, scanned-table recognition, chart
interpretation, handwriting, multilingual accuracy, VLM understanding, or
specialist corpus quality.

## Addendum — capability-by-capability inventory and frontier comparison (2026-07-22)

The local workbook was re-read from the exact file path:
`/Users/pranay/Downloads/document_parsers_extractors_catalog_2026_v2.xlsx`.
Its `Master Catalog` has 149 entries across OCR, layout, tables, math, and
image-aware parsers; `Coverage Audit` confirms it is a discovery map and not a
benchmark verdict or a deployment manifest.

| Capability lane | Catalog-level candidates (ranked for coverage breadth) | CoverWise status today | What closes the lane |
| --- | --- | --- | --- |
| Document text + sentence structure | Docling, SmolDocling, MinerU, Marker, LlamaParse, Docling Serve, PDF-Extract-Kit | Native PDF text, conservative sentence nodes with exact offsets; doctr for scan OCR when available | Word/line boundaries, language-aware boundary tests, and low-confidence fallback review metrics |
| Layout, hierarchy, reading order | Docling, SmolDocling, MinerU, Marker, LlamaParse, Docling Serve, PDF-Extract-Kit, PP-Structure | Native page geometry + emitted order for born-digital pages; image OCR pages emit OCR blocks but no full semantic heading tree | Reading-order and heading hierarchy fixtures for nested sections, multi-column, rotated/low-DPI scans |
| Tables (born-digital + scanned) | Docling, MinerU, Marker, LlamaParse, Docling Serve, PDF-Extract-Kit, PP-Structure | Born-digital table/cell nodes exist; scanned-table/table-structure reconstruction is not yet production-available | PP-Structure, Surya, TATR/GMFT/img2table, or MinerU specialist adapters with cell provenance + schema fidelity and failure telemetry |
| Figures/images, charts, diagrams | Docling, MinerU, Marker, LlamaParse, PP-Structure, PaddleOCR-VL, Mistral OCR, Gemini, OpenAI vision | Canonical artifact retention (page image + hashes) is in place; semantic image/figure meaning remains derived-only | Bounded image-to-source mapping (crop/bbox/caption), annotation schema, and non-citation mode for derived text |
| Form/fill fields + selection marks | Docling, MinerU, PP-Structure, managed form APIs (Azure DI, Google Document AI, Textract), Paddle KIE | Native AcroForm widgets are implemented; scanned key/value and marks are not yet production-available | Structured KVP fixtures with schema/owner contracts, review states, and confidence calibration |
| Formula/math extraction | Docling, MinerU, Marker, LlamaParse, Mathpix OCR, Pix2Text, Nougat, TexOCR | No production formula lane; formula text and LaTeX are not currently parsed into source spans | Specialist formula pipeline with cell-level/region-level lineage, latex normalization, and policy-domain validation |
| Office/web/email structure | Open-source parsers for DOCX/PPTX/XLSX/HTML/EML (`python-docx`, `openpyxl`, `python-pptx`, `trafilatura`, `mailparser` family) plus Docling/Open-source ETL | DOCX, HTML, EML, XLSX, XLSM, PPTX now emit CIR-native structure through the same evidence path | Relationship-level fixtures and format-specific relationship constraints where spreadsheets/charts/forms overlap |
| Multilingual + handwriting + low-resource scripts | Surya, PP-OCR, PaddleOCR families, Docling, multilingual VLM paths | Unicode script observation is implemented; no production multilingual handwriting lane | Script-specific OCR accuracy benchmarks and handwriting routing with manual review fallback |

Web reconfirmation from 2026-07-22 did not replace this router design; it only
strengthened the shortlist. Docling v2 introduced explicit unified `DoclingDocument`
and structured provenance in its canonical docs, and PaddleOCR-VL 1.6 reports
state-of-the-art OmniDocBench results for document parsing, while Surya remains the
strongest local competitor for OCR+layout+tables+LaTeX in one stack. This is
model strength signal only, not production readiness.

### Capability-by-capability evidence tiers (2026-07-22)

For each capability lane below, the catalog claim is treated as a discovery
signal, while `docs/eval/document_intelligence/capability_manifest_v1.json` and
`src/ocr/capability_registry.py` are treated as the only production
evidence boundary.

| Capability lane | Catalog shortlist (examples) | Live proof now | Evidence tier now | Hard gate to close |
| --- | --- | --- | --- | --- |
| Text / sentence extraction | Docling, SmolDocling, MinerU, Marker, Surya, Unstructured, LlamaParse, Zerox, Textract APIs | Native PDF text + conservative sentence nodes + OCR fallback in `scanned_ocr` | 2 | Add multilingual word/line boundary fixtures and low-confidence sentence-boundary telemetry against a consented corpus. |
| Layout, hierarchy, reading order | Docling, SmolDocling, MinerU, Marker, Surya, PP-Structure, Unstructured, LlamaParse | Page geometry, block order persistence, and C-I-R emission | 2 | Add nested sections, multi-column, rotated, and low-DPI fixture suite before semantic heading assertions are treated as source-grounded. |
| Tables (born-digital and scanned) | Docling, SmolDocling, MinerU, Marker, LlamaParse, Surya, PP-Structure, PDF-Extract-Kit, TATR/GMFT/img2table | Born-digital tables/cells currently emitted through native parsers and PDF path | 2 | Scanned-table lane requires merged-cell and borderless-table fixtures with source-to-cell span mapping and partial-success telemetry. |
| Figure/image/charts understanding | Docling, MinerU, Marker, LlamaParse, PaddleOCR-VL, Mistral OCR, Gemini, Donut/Mathpix-class VLMs for figure context | Canonical page-image retention + hash references | 2 | Add bounded image crop/prompt schema and anti-hallucination policy: derived annotations can never substitute source text. |
| Forms, key-value, marks | Azure DI, Google Document AI, Textract, Paddle KIE, MinerU, PP-Structure | Native AcroForm only is production-safe | 1 | Add specialist KVP/mark profiles with schema validation, uncertainty banding, and review state transitions before policy fields are surfaced. |
| Formula/math lane | MinerU, Surya, Marker, LlamaParse, Mathpix OCR, Pix2Text, TexOCR, Nougat, Donut | No production formula lane yet | 0 | Add source-linked LaTeX/MathML extraction with cell-level provenance before any formula-derived policy reasoning. |
| Office/web/email structural extraction | Docx/PPTX/XLSX parse stacks (`python-docx`, `python-pptx`, `openpyxl`, `trafilatura`, `mailparser`) + Docling-native ETL | DOCX/HTML/EML/XLSX/XLSM/PPTX CIR-native structure now live | 2 | Add relationship-level fixture closure for charts/images/forms and malformed container behavior. |
| Multilingual + handwriting + low-resource scripts | Surya, PP-Structure, PaddleOCR family, managed document IDPs, multilingual VLM paths | Script observation only; routing by script family | 1 | Add corpus-stratified language accuracy metrics, unsupported-language routing, and explicit manual-review fallback for handwritten/misreadable content. |

Frontier references checked:

- [Docling v2](https://docling-project.github.io/docling/v2/)
- [Docling concepts: DoclingDocument](https://docling-project.github.io/docling/concepts/docling_document/)
- [PaddleOCR-VL-1.6](https://www.paddleocr.ai/main/en/version3.x/algorithm/PaddleOCR-VL/PaddleOCR-VL-1.6.html)
- [Surya OCR/layout repo](https://github.com/datalab-to/surya)
- [HunyuanOCR-1.5 paper](https://arxiv.org/abs/2607.04884)

### 2026-07-22 requested-capability matrix (text/sentences/structure/layout/tables/images)

This matrix is explicit for the capability classes you listed and maps catalog lane →
runtime ownership → remaining gate.

| Capability class | Current catalog evidence signal | CoverWise runtime owner today | Launch gate to mark as "owned" |
|---|---|---|---|
| Text + sentence extraction | Fixed columns show high text coverage (`121/149 Yes` text, strong OCR/parser pool) | `native_text` + `sentence_segmentation` implemented; `scanned_ocr` available with doctr profile | language-specific word/line/sentence fixture suite, failure telemetry, confidence calibration |
| Document structure / sections | `Header / section detection` shows `86/149 Yes`; fixed `coordinates / reading order` strong (`110/149`) | `layout` + `reading_order` available; `headings_and_sections` remains candidate | heading hierarchy + nesting fixtures, rotated/multi-column/low-DPI structural recovery |
| Layouts + ordering | Broad fixed-column signal (`89/149 Yes` layout awareness, `110/149` coordinates) | page geometry + block sequence are present in CIR; native artifact ordering preserved | cross-tool ordering stability and nested structure evidence for complex layouts |
| Tables (digital + scanned recovery) | `91/149 Yes` in fixed table column plus paper/table specialist families in `Typical outputs` | native table/table-cell nodes available; scanned-table recovery lane is not production-closed | scanned-table, merged-cell, borderless, and malformed-table benchmark lane with source-level cell spans |
| Images / figures / charts (semantic) | No dedicated catalog column; inferred from outputs and VLM sheets (image crop/figure outputs in candidates) | `figures` structural artifact retention is owned; `charts_and_diagrams`, `image_understanding`, `vlm_annotation` candidates | crop/bbox/caption lineage, bounded derived-annotation schema, anti-hallucination rule for captions |
| Forms + key/value + marks | No explicit fixed column for forms; specialist form API families dominate research notes | `forms` owned for native widgets only; key/value candidate; marks unavailable | specialist KVP/marks specialist profiles with schema and review state closure |
| Formula / equations | `34/149 Yes` math/LaTeX and multiple formula families in notes | `formulas` candidate only | source-linked formula lane with region lineage, normalization, and policy-domain validation |
| Office/web/email structure | Structured outputs in native adapters and catalog research notes | `office_and_email_structure` available through CIR | relationship-level integrity across embedded content/relationships and error-mode fixtures |
| Multilingual + handwriting | No dedicated fixed language-accuracy column; script-level signal absent from fixed lane | `multilingual` routing-only; `handwriting` unavailable | script/language-stratified OCR, unsupported-language and handwritten fallback policy with explicit manual-review |

### 2026-07-22 frontier ownership matrix (requested capability classes)

This is the practical go/no-go matrix for your specific capability classes:

| Capability class | Strongest catalog-supported families (what to benchmark first) | Current CoverWise owned lane | What is still open for production claim |
| --- | --- | --- | --- |
| Text + sentence extraction | Docling, SmolDocling, MinerU, Surya, PDF-Extract-Kit, OpenParse | `native_text`, `sentence_segmentation`, `scanned_ocr` | Word-level + sentence-boundary accuracy by language/locale; low-confidence fallback behavior |
| Structures + section hierarchy | Docling, Surya, MinerU, PP-Structure, Marker, LlamaParse | `layout`, `reading_order`, `headings_and_sections(candidate)` | Heading-depth/nesting semantics, rotated/multi-column structure, footer/header distinction |
| Layout + reading order | DoclingDocument, Surya/PP-Structure layout stacks, PaddleOCR-VL | `layout`, `reading_order` | Cross-tool ordering consistency on complex schedules and scanned/rotated pages |
| Tables (digital + scanned) | Docling, Surya/PP-Structure, MinerU, TATR, GMFT, img2table | `tables` (born-digital), `native` table/cell adapters | Scanned-table reconstruction and merged/borderless table recovery with span-aware provenance |
| Images + figures + charts | Docling, Marker, PaddleOCR-VL, MinerU, Mistral OCR, Gemini | `figures` (artifact lineage), `charts_and_diagrams`/`vlm_annotation` candidates | Bounded crop→bbox→caption provenance, anti-hallucination policy, and non-citation default for derived semantics |
| Forms / KVP / marks | Azure DI, Google Document AI, Textract, Paddle KIE, PP-Structure KIE | `forms` + native AcroForm, `key_value_extraction(candidate)`, `selection_marks(unavailable)` | Specialist KVP/mark profile with schema + uncertainty + reviewer state machine |
| Formula / math / LaTeX | MinerU, Surya, PaddleOCR PP-Structure, Mathpix/Nougat/Pix2Text | `formulas(candidate)` | No source-linked formula production lane today; region/span provenance and normalization missing |
| Office/web/email structure | python-docx, python-pptx, openpyxl, trafilatura, mailparser, Docling | `office_and_email_structure` | Relationship-preservation and malformed-container behavior for nested structures |
| Multilingual + handwriting | Surya, PaddleOCR, LayoutXLM/LiLT, managed document-intelligence | `multilingual(routing_only)`, `handwriting(unavailable)` | Script-stratified accuracy gates and handwritten routing/review policy |

### 2026-07-22 per-class frontier shortlist (discovery + runtime)

This matrix adds explicit "who owns what today" plus the best discovery candidates
to validate next from the local workbook and local sweeps.

Evidence bundle:

- `docs/technical/document_parser_capability_catalog_2026-07-22.md`
- `docs/review/evidence/local-model-eval/capability_frontier_candidates_2026-07-22.json`
- `docs/review/evidence/local-model-eval/capability_gate_run_2026-07-22-doctr.json`

| Capability class | Discovery candidates (local catalog/frontier) | Source-anchored CoverWise lane | Current production status | First hard gate |
|---|---|---|---|---|
| Text / OCR | Docling, SmolDocling, MinerU, Marker, Unstructured, OpenParse | `native_text`, `sentence_segmentation`, `scanned_ocr` | Tier 2 structural extraction; synthetic OCR cases passed | Language-specific word/line boundary and confidence calibration on consented corpus |
| Sentences | Docling/Surya families + sentence-aware parser families | `sentence_segmentation` with exact offsets and conservative split rules | Structural-only for now; accuracy by language still open | Multilingual sentence-boundary fixture suite and punctuation-edge behavior |
| Structures / sections | Docling, Surya, MinerU, Marker, PP-Structure, LlamaParse | `layout`, `reading_order`, `headings_and_sections(candidate)` | Block geometry and ordering are source-anchored; heading hierarchy is not | Heading-depth + nested-structure fixtures, rotated/multicolumn cases |
| Layout + reading order | DoclingDocument, Surya/PP-Structure, PaddleOCR-VL | `layout`, `reading_order` + emitted block order | Tier 2 source ordering for native pages; complex ordering is benchmark-open | Multi-tool order consistency and complex-page semantic ordering fixtures |
| Tables (digital + scanned) | Docling, Surya, MinerU, PaddleOCR-PP Structure, TATR/GMFT/img2table | `tables` + native table/cell adapters | Born-digital tables/cells are covered; scanned-table reconstruction is open | Merged-cell, borderless, low-quality, and malformed-table benchmarks |
| Images / figures / charts | Docling, Marker, LlamaParse, Mistral OCR, Gemini, OpenAI vision | `figures` + `charts_and_diagrams`/`image_understanding` candidates + image hashes | Structural artifact retention is owned; semantic claims remain derived | Bounded crop→bbox→caption provenance + anti-hallucination policy |
| Forms / KVP / marks | Azure DI, Google Document AI, Textract, Paddle KIE, PP-Structure KIE | `forms` owned for native widgets; `key_value_extraction(candidate)`, `selection_marks(unavailable)` | Native AcroForm is owned; KVP/marks remain open | Specialist KVP/marks adapters with geometry schema + reviewer state |
| Formula / math | MinerU, Surya, PaddleOCR PP-Structure, Mathpix, Pix2Text, Nougat | `formulas(candidate)` only | No production formula lane | Formula region/span provenance and normalization before any policy claim |
| Office / web / email structure | python-docx, python-pptx, openpyxl, trafilatura, mailparser | `office_and_email_structure` | Core structure is owned; relationship constraints are open | Malformed container and relationship-preservation adversarial fixtures |
| Multilingual + handwriting | Surya, PaddleOCR, LayoutXLM/LiLT, managed DI | `multilingual(routing_only)`, `handwriting(unavailable)` | Script observation is implemented; quality gates pending | Script/locale OCR + handwriting corpus gates plus manual-review fallback |

### 2026-07-22 executed local evidence snapshot

- `capability_gate_run_2026-07-22.json` (no OCR profile): mixed native/form/table/office cases passed with `all_executed_cases_passed=true` and `not_run_cases=2`.
- `capability_gate_run_2026-07-22-doctr.json` (`--ocr-profile doctr`): native, scanned, mixed-scan, and office cases passed with `all_executed_cases_passed=true`, and scanned-ocr paths now produce explicit `scanned_ocr`.
- Registry snapshot (`capability_registry_snapshot`) now reports `scanned_ocr=available`, `headings_and_sections=candidate`, `selection_marks=unavailable`, and `handwriting=unavailable` in the active environment.

## Operational interpretation

- Keep parser diversity in the catalog as route candidates, not defaults.
- Keep runtime `available` statuses as operational truth only; everything `candidate`/`routing_only` remains in specialist lanes.
- Do not use VLM/image-derived outputs as source-citation text until the bounded annotation gate is passed.
