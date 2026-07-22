# RAG Chat Session Synthesis — 2026-07-21

**Status:** Conversation-derived project direction and learning context
**Evidence boundary:** Tier 0/1 internal context; not primary-source technical evidence
**Repository:** `/Users/pranay/Projects/medpiper/insurance_app`

## Scope and provenance

This artifact synthesizes two ChatGPT conversation records explicitly supplied
for this project. It records durable preferences and architectural implications,
not independently verified technical claims. The conversation material should be
used to shape exploration and implementation priorities; claims about libraries,
benchmarks, security, or production behavior must still be checked against the
repository, runtime, tests, and primary sources.

| Source | Conversation contribution |
| --- | --- |
| [`RAG exploration and documentation`](chatgpt-conversation://6a5f4613-bdfc-83e8-8bb2-c79af5788c04) | Request for comprehensive RAG exploration, durable documentation, exploration-map continuity, and use of relevant skills, plugins, and chat sessions as research inputs. |
| [`RAG app development guide`](chatgpt-conversation://6a4926d2-e31c-83e8-bdd0-edad22e10efe) | Learning/build direction: understand the complete RAG flow, build primitives deliberately, treat retrieval and answer discipline as separate concerns, and make document structure and evidence lineage first-class. |

The synthesis is based on the supplied conversation references and derived
context in the task request. It does not claim that an unavailable connector or
skill session supplied additional transcript evidence.

## Durable decisions and preferences inferred

These are project-direction decisions inferred from the conversations. They are
not substitutes for an accepted ADR or for implementation proof.

1. **RAG means retrieval plus answer discipline.** A useful system is not
   “vector search plus an LLM.” It must retrieve the right evidence, constrain
   the answer to that evidence, cite it, abstain when evidence is insufficient,
   and expose what happened for review.
2. **Learn the complete system through six explicit subsystems:** ingestion,
   chunking, embeddings, index, retrieval, and generation. Evaluation,
   security, operations, and UX are cross-cutting quality gates around them.
3. **Prefer a staged build path.** Start with a manual primitive, then add
   serious document parsing, hybrid retrieval, evaluation, product-grade
   workflow controls, and only then agents where deterministic retrieval fails.
4. **Treat PDFs as multi-view evidence objects, not flat text streams.** The
   minimum useful view set is section/text, table, OCR/image, and
   entity/metadata. Layout/page and structured-record views preserve navigation
   and deterministic lookup.
5. **Keep contracts separate.** Parsing, extraction, chunking, and indexing
   should be distinct stages. A single typed chunk substrate is a reasonable
   starting point only if it retains modality, raw structured payloads,
   confidence, retrieval purpose, and source lineage.
6. **Make lineage non-negotiable.** Page numbers, bounding boxes or regions,
   source spans, document versions, and citations must survive every derived
   representation and remain available to the answer and UI layers.
7. **Route by question intent.** Exact lookup, numeric, table, entity, summary,
   visual, and cross-document questions should not be forced through one dense
   text-retrieval path.
8. **Build a RAG workbench, not only a chat surface.** Retrieval previews,
   sources, citations, query intent, and evaluation results should be visible so
   the system teaches its mechanics and failures remain diagnosable.
9. **Use skills, plugins, and chat sessions as exploration inputs.** They can
   accelerate discovery and learning, but their outputs remain proposals until
   checked against primary sources and the live repository.

## Architecture and flow implications for this repository

The conversation direction fits the repository’s existing evidence-first RAG
work and sharpens its intended shape:

```text
source file
  -> canonical document/evidence model
  -> section/text, table, OCR/image, entity/metadata, layout/page,
     and structured-record views
  -> separate parse / extract / chunk stages
  -> typed, lineage-preserving chunk substrate
  -> keyword + dense + structured indexes
  -> query-intent router and access/freshness filters
  -> candidate fusion, bounded reranking, and context assembly
  -> structured answer generation
  -> citation/span verification and abstention when needed
  -> user workbench + privacy-safe trace + evaluation record
```

The repository already frames this direction in the [comprehensive RAG
exploration](../technical/rag_comprehensive_exploration_2026-07-21.md), the
[primary-source research register](rag_primary_sources_2026-07-21.md), and the
[capability-routed document intelligence ADR](../decisions/ADR-2026-07-21-05-document-intelligence-router-and-evidence-contract.md).
Those documents remain the canonical places for technical evidence, live
implementation status, and accepted architecture.

### View and routing implications

| Query intent | Preferred evidence path | Required discipline |
| --- | --- | --- |
| Exact identifier, entity, date, or numeric lookup | Structured record, metadata, table, and lexical lookup | Preserve exact strings and validate against the source span. |
| Clause, benefit, or exclusion explanation | Section/text view with lexical and dense retrieval | Carry heading path, parent context, version, and citation lineage. |
| Table, schedule, or limit question | Table/cell view, with text fallback only when the table view is unavailable | Preserve headers, row/column relationships, page, and cell geometry. |
| Visual, scan, chart, or image question | OCR/image and layout/page views, optionally with a vision specialist | Keep generated captions distinct from immutable source evidence. |
| Summary across a document | Section/document views with bounded context assembly | Make scope and document version explicit; do not treat a summary as source truth. |
| Cross-document comparison or aggregation | Explicit document selection, structured fields, and multi-source retrieval | Aggregate deterministically where possible and evaluate contradictions, freshness, and owner isolation. |

The existing repository direction of immutable `source_text` plus separately
derived retrieval representations is therefore important: enrichment may improve
recall, but it must never silently become the customer-visible quotation.

## Learning and build roadmap

1. **Manual primitive:** ingest one known document, create simple chunks, build
   one index, retrieve top results, and generate an answer that names its
   evidence. Inspect each intermediate artifact by hand.
2. **Serious document handling:** add the canonical document model and preserve
   page, region, heading, table, OCR/image, entity, and structured-record views.
   Prove that reprocessing can produce new derived records without losing the
   original source artifact.
3. **Hybrid and routed retrieval:** add keyword/dense/structured legs, intent
   routing, filters, fusion, bounded reranking, parent/section context, and
   explicit empty or insufficient-evidence states. Compare each leg separately.
4. **Evaluation workbench:** expose retrieval previews, source spans, query
   intent, citations, and per-slice results. Build a reviewed corpus covering
   exact, numeric, table, OCR, narrative, negative, stale-version, and
   cross-document questions before enabling advanced techniques globally.
5. **Product-grade workflow:** add idempotent ingestion, versioned indexes,
   deletion and permission transitions, retries and fallbacks, structured-output
   validation, citation verification, privacy-safe traces, operator status, and
   latency/cost measurement.
6. **Selective agents:** introduce bounded agent/tool loops only for tasks where
   deterministic routing and retrieval cannot solve decomposition or multi-hop
   needs. Keep tool allowlists, step/time/cost limits, source filters, and the
   same final evidence contract.

## Open questions and verification gates

- **Canonical model:** Does the current CIR/evidence substrate express all
  required section, table, OCR/image, entity, layout/page, and structured-record
  relationships without creating a second evidence store?
- **Shared substrate:** Which fields are common to every retrievable record, and
  which modality-specific payloads must remain lossless alongside them?
- **Routing:** Can exact, table, visual, and cross-document intents be selected
  deterministically enough to avoid unnecessary LLM calls and unsafe query drift?
- **Backend parity:** Do Supabase and Qdrant preserve identical owner filters,
  source fields, model/version contracts, empty states, adjacency, and deletion
  semantics? This is a repository verification gate, not a conversation fact.
- **Lineage:** Can a user move from an answer citation to the correct page,
  region, table cell, or OCR/image artifact through the real runtime path?
- **Version and deletion:** Are stale versions, re-indexing, revocation, and
  partial deletion observable and safe across source, derived views, indexes,
  cache, and audit records?
- **Evaluation:** What reviewed corpus and thresholds establish that a new
  parser, chunk policy, embedding, reranker, contextualizer, or agent improves
  the relevant slice without reducing faithfulness, citation validity, or
  owner isolation?
- **Model/pipeline/data boundary:** For every model-backed stage, are the input
  contract, output schema, validation, fallback, retry, provider, cost,
  latency, and observability recorded separately from the model choice?
- **Security and operations:** Can retrieved instructions be treated as data,
  not authority, and can an operator explain a failed parse, weak retrieval,
  rejected citation, retry, fallback, or partial result after the fact?

Until these gates are answered with repository/runtime evidence, the chat-derived
direction remains a roadmap. The current primary-source and repository documents
already identify higher-priority gates such as retrieval-backend parity,
page/region citation traversal, owner fencing, deletion/version transitions,
and a reviewed multi-view evaluation corpus.

## Relationship to the primary-source research document

This artifact complements, but does not replace, the [RAG primary-source
research register](rag_primary_sources_2026-07-21.md):

- The primary-source register records external evidence, distinguishes verified
  facts from engineering inference, and links to papers, standards, and
  first-party documentation.
- This artifact records user intent, learning goals, durable preferences, and
  project-specific direction inferred from conversations.
- The [comprehensive exploration](../technical/rag_comprehensive_exploration_2026-07-21.md)
  integrates both into the repository’s architecture and open-gate map; its
  implementation claims still require the evidence tier stated there.
- Accepted ADRs and live code/tests outrank this synthesis for implementation
  truth. This file is not an ADR and does not authorize a production change by
  itself.

## Anything else?

The overlooked implication is that the workbench is both a teaching surface and
an operational control surface. Showing retrieved evidence, intent, citations,
and evaluation results reduces the gap between “the model answered” and “the
system can explain and support the answer.” The evaluation corpus, prompts,
schemas, routing rules, and derived views are product data/configuration and
must be versioned, reviewed, access-controlled, and recoverable like code.
