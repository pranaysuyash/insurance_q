# ADR-2026-07-21-05 — Capability-routed document intelligence and source evidence

- **Date:** 2026-07-21
- **Status:** Proposed for implementation
- **Scope:** OCR, document parsing, layout, tables, figures, formulas, forms,
  VLMs, and policy-field extraction

## Decision

CoverWise will use one capability-routed document-processing pipeline backed by
a canonical intermediate representation (CIR) and the existing evidence
substrate. PyMuPDF/native format extraction remains the deterministic first
path. OCR, layout, table, form, formula, figure, and VLM components are
specialist profiles selected by document quality and capability needs.

No single VLM or parser will be treated as universal truth. No candidate from
the 149-entry local catalog becomes a production dependency or default merely
because it has a strong vendor benchmark score. A profile must pass the
CoverWise corpus benchmark, source-provenance checks, license/model review,
privacy/data-handling review, and runtime failure/observability checks.

## Context

The attached local catalog gives broad coverage across text, layout, tables,
forms, formulas, images, and VLMs. Existing code is narrower: PyMuPDF and
doctr are active, Docling/MinerU are opt-in branches, policy extraction is
summary-centric, and the evidence substrate is the trust boundary. Existing
research also contains historical recommendations that need correction: the
runtime now has preprocessing, and MinerU’s current official repository does
not support the old blanket “AGPL” description.

The product’s trust requirement is stronger than “return JSON”: every customer-
visible insurance fact must be traceable to source text or a source artifact,
with uncertainty and failure visible to the user/operator.

## Options considered

1. **Install and route every catalogued tool.** Rejected: creates dependency,
   license, cost, platform, and observability sprawl without proving quality.
2. **Choose one universal VLM/parser.** Rejected: text, tables, forms,
   formulas, figures, and handwriting have different error functions and
   provenance requirements.
3. **Keep PyMuPDF plus doctr only.** Rejected as the long-term shape: it leaves
   complex layout, tables, figures, and forms without explicit capability
   coverage, even though it remains the correct launch baseline.
4. **Capability-routed cascade with one CIR and evidence contract.** Chosen:
   broad capability coverage, replaceable specialists, one canonical pipeline,
   and source-preserving output.

## Derived implementation scope

The decision requires the following refactor, not a future “cleanup” item:

- define typed CIR nodes and adapters for current page artifacts/source spans;
- add capability classification and quality gates to the existing processing
  service rather than creating duplicate upload routes or parser services;
- preserve tables, cells, figures/crops, formulas, forms, coordinates,
  reading order, parser/model versions, confidence, and evidence references;
- extend structured policy fields with field-level source/evidence links and
  deterministic validation status;
- add corpus fixtures and a benchmark manifest covering each high-risk
  capability;
- expose parser profile, failure, retry, fallback, and review-needed state to
  operators;
- make the eager doctr dependency behavior explicit and correct the documented
  optional-runtime contract before claiming fallback resilience.

## Tradeoffs

- The CIR adds schema and migration work, but prevents parser-specific storage
  and makes future model replacement safe.
- Multiple specialist profiles require benchmarking and routing telemetry, but
  avoid paying VLM latency/cost for simple digital PDFs.
- Managed services may improve forms/handwriting recall, but introduce data
  residency, retention, cost, and provider-dependency decisions.
- Local models improve privacy and control, but need model/weight license review
  and platform-specific performance validation.

## Validation and rollback

Validation is Tier 3+ for any production adoption: run the versioned corpus
through the real processing flow, inspect stored evidence, verify page/block/
cell citations, replay retries/duplicates, and observe operator failure state.
Until then, candidate profiles remain isolated research configurations. Rollback
is profile-level: disable the candidate and return to the last passing profile
without changing the source artifact or evidence contract.

## Revisit triggers

Revisit when a corpus benchmark shows a specialist is consistently better for a
capability, when a provider changes licensing/data terms, when a new document
class enters the product, or when the existing evidence substrate cannot express
a required source relationship without violating its invariants.

## Anything else?

The catalog should remain a living research inventory, not the production
architecture. The durable competitive advantage is the evidence-preserving
router and CoverWise-specific benchmark corpus: they let the product improve
accuracy without asking users to trust an opaque parser.

## Related records

- `docs/technical/document_intelligence_capability_matrix_2026-07-21.md`
- `docs/technical/local_document_intelligence_evaluation_2026-07-12.md`
- `docs/technical/ocr_pipeline_research_2026-07-11.md`
- `docs/review/exploration_map.md`
- `src/ocr/pipeline.py`
- `src/services/document_processing_service.py`
- `src/workers/substrate_extraction_handler.py`

## Update log

### 2026-07-21 — first implementation slice

Added `src/models/document_intelligence.py` with `DocumentCIR`, `CIRNode`,
source hashing, and conservative capability classification. Existing OCR and
document-processing outputs now carry page/text/artifact lineage in the CIR,
while legacy response fields remain compatible. The doctr import moved to OCR
pipeline construction so slim API imports remain possible; `rag_only` now has
an explicit empty OCR result. The focused CIR/OCR/evidence checks passed, and
the full backend suite passed 352 tests with 1 intentional skip.

The CIR currently proves only page/text/artifact observations. Tables, forms,
figures, formulas, and handwriting remain benchmark-gated specialist work and
must be added through adapters owned by this same contract.

## Review passes

- **Pass 1 — correctness:** CIR ordering, source/retrieval separation, image
  hashes, slim-runtime import behavior, `rag_only`, and existing OCR/evidence
  flows are covered by focused tests; the full backend suite passes 352 tests
  with 1 intentional skip.
- **Pass 2 — architecture:** no route, queue, table, or parallel evidence store
  was introduced. CIR metadata is carried into the existing page artifact
  `layout_json` field and legacy response keys remain compatible.
- **Pass 3 — supervision readiness:** specialist capability claims remain
  explicitly unverified; tables/forms/formulas/figures require corpus evidence,
  license/privacy review, and Tier 3 runtime verification before adoption.
