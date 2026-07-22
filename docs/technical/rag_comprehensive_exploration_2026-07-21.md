# Retrieval-Augmented Generation: Comprehensive Exploration

**Date:** 2026-07-21  
**Status:** Research baseline and implementation map  
**Scope:** RAG techniques, architectures, flows, data contracts, packages, vector stores, evaluation, security, operations, and the CoverWise fit  
**Evidence:** Tier 1 static repository inspection plus primary-source research; repo-specific test claims are labelled separately  

This is the canonical broad RAG research document for CoverWise. The dated
`docs/review/rag_pipeline_exploration_map_2026-07-20.md` remains a historical
implementation snapshot, while `docs/review/exploration_map.md` records the
current exploration direction and open gates.

The companion [primary-source research register](../research/rag_primary_sources_2026-07-21.md)
contains the background research pass, verified-source versus inference
separation, and a larger source register.

## Executive conclusion

RAG is not a vector database feature. It is a controlled evidence pipeline:

```text
source -> parse -> normalize -> segment -> enrich -> embed/index
       -> query plan -> retrieve -> fuse -> rerank -> assemble context
       -> generate structured answer -> verify evidence -> present/audit
```

The durable design rule is to keep three layers distinct:

1. **Model layer:** embedding, reranking, generation, vision, and classification
   models.
2. **Pipeline layer:** ingestion, query routing, retrieval, validation, retry,
   fallback, citation verification, and state transitions.
3. **Data/configuration layer:** source documents, OCR, chunk records, metadata,
   schemas, section taxonomies, prompt templates, evaluation sets, model
   contracts, and retention/deletion policy.

For an insurance product, the pipeline and data layers are the trust boundary.
The LLM may propose an answer, but only immutable source evidence can support a
customer-visible policy claim. Retrieval quality, citation correctness,
owner isolation, and auditability must therefore be measured independently from
generation quality.

The most important CoverWise recommendation is not to add every fashionable RAG
technique. It is to make the existing canonical pipeline internally coherent:

- preserve `source_text` as immutable citation truth and use `retrieval_text`
  only for search enrichment;
- keep dense and lexical retrieval as complementary legs;
- make filters owner-scoped before retrieval and before graph expansion;
- use multi-granularity and structure-aware chunks rather than one flat text
  stream;
- rerank only a bounded candidate set;
- verify citations before returning them;
- record privacy-safe traces and evaluate retrieval separately from answers;
- adopt agentic, graph, contextual, or multimodal variants only behind an
  evaluation gate.

## 1. What RAG is and when it is the wrong tool

The original RAG formulation combines parametric model memory with a
non-parametric external memory accessed by a neural retriever. The paper
describes both a single-passage conditioning variant and a token-level variant,
and reports gains on knowledge-intensive tasks. See [Lewis et al.,
2020](https://arxiv.org/abs/2005.11401).

Use RAG when knowledge is external, changing, private, too large for a reliable
prompt, or needs provenance. It is particularly useful when the answer must be
updated without retraining the generator.

Do not automatically use RAG when:

- the complete, stable corpus fits comfortably in context and latency/cost are
  better with direct context or prompt caching;
- the task is deterministic arithmetic, filtering, or a transactional lookup
  better served by SQL or an application function;
- the desired behaviour is style, transformation, or summarization of a small
  user-provided input;
- retrieval cannot satisfy the required access-control, freshness, or evidence
  contract.

Anthropic explicitly notes that for a knowledge base below roughly 200,000
tokens, putting the whole corpus in a prompt may be simpler than RAG. That is a
vendor experiment, not a universal threshold; the correct decision depends on
corpus size, update frequency, privacy, cost, latency, and verification needs.
See [Contextual Retrieval](https://www.anthropic.com/engineering/contextual-retrieval).

## 2. Canonical architecture and flows

### 2.1 Offline ingestion flow

```text
Upload / connector event
  -> malware/type/size validation
  -> immutable object storage + content hash
  -> parser/OCR/layout extraction
  -> canonical intermediate representation (CIR)
  -> normalization and language detection
  -> structural segmentation
  -> metadata, section labels, parent/child IDs, page/span lineage
  -> optional contextual enrichment (never overwrites source text)
  -> embedding and sparse-index generation
  -> vector/sparse/keyword upsert
  -> graph/link creation
  -> index health check and versioned publish
```

Ingestion must be idempotent. A stable source hash plus an explicit
`document_version`/`embedding_version` prevents duplicate chunks and permits
side-by-side re-indexing. Re-embedding should write a new index version and
publish it atomically or through a controlled alias; changing dimensions in an
active collection is not a safe runtime fallback.

### 2.2 Query flow

```text
User query + principal + filters
  -> normalize, language/intent/query-type classification
  -> authorization and corpus selection
  -> exact/structured lookup leg when appropriate
  -> dense query embedding
  -> sparse/BM25 or sparse-vector query
  -> optional query expansion, multi-query, or HyDE
  -> candidate fusion and deduplication
  -> bounded reranking
  -> threshold/coverage/contradiction checks
  -> parent/adjacent/section expansion, still owner-scoped
  -> context budget and source ordering
  -> structured generation
  -> citation/span verification against immutable source text
  -> answer, evidence, uncertainty, and follow-up response
  -> privacy-safe trace, metrics, and operator status
```

### 2.3 Failure and recovery flow

Every stage needs explicit failure semantics:

| Stage | Failure | Safe behaviour | Must be observable |
|---|---|---|---|
| Parse/OCR | unreadable or unsupported input | mark processing failed; retain source; do not index guessed text | parser, page, error class |
| Chunk | malformed structure or oversized content | use deterministic fallback segmentation; mark strategy | chunker/version/count |
| Embed | provider timeout/quota/dimension mismatch | retry boundedly, then route to a compatible versioned fallback or stop | provider, attempts, model, dimensions |
| Index | partial upsert | retry idempotently; do not publish incomplete version | batch and publish state |
| Retrieve | timeout/empty/weak evidence | answer “not found/insufficient evidence”; do not hallucinate | strategy, latency, hit count |
| Rerank | model unavailable | use deterministic first-stage order or skip with trace | reranker status |
| Generate | invalid structured output | retry or use constrained fallback template | schema failure, model, retry |
| Citation | quote not in source | strip or label as approximate; never silently pass | reason and citation status |
| Delete | remote/derived cleanup fails | retain local state and expose retryable pending status | object/vector/cache/audit state |

### 2.4 2-step, agentic, and hybrid RAG

LangChain's current retrieval documentation describes three useful families:

- **2-step RAG:** retrieval always precedes generation; predictable and fast.
- **Agentic RAG:** an LLM decides when to call retrieval tools; flexible but
  variable and harder to bound.
- **Hybrid RAG:** intermediate query enhancement, retrieval validation, and
  answer validation preserve more control while allowing iteration.

See [LangChain retrieval and RAG architectures](https://docs.langchain.com/oss/python/langchain/retrieval).

For CoverWise, policy lookup and citation-critical answers should remain
bounded 2-step or hybrid flows. Agentic retrieval is appropriate only for
explicit research-style tasks, and must have tool allowlists, maximum steps,
per-tool timeouts, budget limits, and a final evidence contract.

## 3. Ingestion, parsing, and chunking

### 3.1 Parse the document before splitting text

Plain text extraction is not enough for policy PDFs. Retain page numbers,
bounding boxes, tables, headings, lists, reading order, figures, and source
hashes in a canonical intermediate representation. Keep the original bytes and
the parser output versioned so a later parser can be compared without losing
lineage.

Useful parser families:

| Need | Options | Tradeoff |
|---|---|---|
| Native PDF text/layout | PyMuPDF, pypdf, pdfplumber | Fast; weaker on scans and complex layout |
| OCR | doctr, Tesseract, PaddleOCR, cloud OCR | Recovers scans; quality/CPU/privacy tradeoffs |
| Structure/table extraction | Docling, Unstructured, Marker | Better structure; heavier models and validation burden |
| Managed document AI | Google Document AI, Azure Document Intelligence, AWS Textract | Operationally easier; data residency/cost/vendor dependency |
| Enterprise connectors | LlamaIndex loaders, LangChain loaders, Haystack converters | Broad integration; connector freshness and permissions are your problem |

[Docling's architecture](https://docling-project.github.io/docling/concepts/architecture/)
and [chunking CLI](https://docling-project.github.io/docling/reference/cli/)
document structure-preserving conversion and hybrid/hierarchical chunking.

### 3.2 Chunking strategies

Chunking is a retrieval design decision, not a formatting detail.

| Strategy | Strength | Failure mode | Good fit |
|---|---|---|---|
| Fixed token/character | Simple, predictable | splits clauses, tables, and definitions | baseline only |
| Recursive separators | preserves paragraph/sentence boundaries better | still blind to semantic structure | general prose baseline |
| Sentence | precise answers | loses context and increases index size | exact facts, sentence-level evidence |
| Paragraph | good local context | can be too broad | policy prose default |
| Section-aware | retains heading and scope | requires reliable structure labels | contracts, policies, manuals |
| Semantic | topic boundaries | embedding cost and unstable boundaries | heterogeneous prose after baseline |
| Parent-child | precise child retrieval plus parent context | more joins and lineage complexity | long structured documents |
| Hierarchical | coarse-to-fine navigation | larger index and query planner | book/report-scale corpora |
| Table-aware | preserves headers and row meaning | hard cell/row semantics | schedules, limits, benefit tables |
| Contextual | restores missing document context | LLM preprocessing cost and contamination risk | isolated chunks with weak self-context |

Recommended chunk record:

```json
{
  "chunk_id": "stable-id",
  "document_id": "source-id",
  "document_version": "content-hash-or-version",
  "source_text": "immutable OCR/native text",
  "retrieval_text": "source text plus optional generated context",
  "chunk_type": "sentence|paragraph|section|table|document",
  "parent_chunk_id": "optional-parent",
  "section_path": ["Policy", "Exclusions", "Dental"],
  "page_number": 4,
  "span": {"start": 1024, "end": 1340},
  "bbox": [0.1, 0.2, 0.8, 0.3],
  "language": "en",
  "source_hash": "sha256",
  "embedding_model": "provider/model",
  "embedding_dimensions": 1536,
  "embedding_version": "v1"
}
```

Never use generated contextual text as a customer-visible quote. Store it
separately and trace the prompt/model used to create it.

### 3.3 Chunk sizing method

Do not choose a universal `chunk_size` from a blog post. Start with a bounded
baseline, then measure:

1. index the same corpus at several token budgets;
2. evaluate exact lookup, semantic, negative, cross-reference, and multi-hop
   questions;
3. measure recall@k, precision@k, citation coverage, latency, index size, and
   generation token usage;
4. select per document class or section type when the slices justify it.

Overlap is useful only when it preserves a dependency. Blind overlap increases
duplicates and can make ranking appear better without increasing evidence
coverage. Parent-child expansion is often a cleaner alternative.

### 3.4 Contextual retrieval

Contextual Retrieval prepends concise chunk-specific context before embedding
and before BM25 indexing. Anthropic reports lower retrieval failure rates in its
experiments and shows the technique stacking with BM25 and reranking; the same
source also says to evaluate chunk boundaries, models, top-k, and prompts for
the target corpus. See [Anthropic Contextual Retrieval](https://www.anthropic.com/engineering/contextual-retrieval).

Decision rule for CoverWise:

- keep it disabled until `source_text`/`retrieval_text` separation and citation
  tests are complete;
- generate contextual text once per chunk version, not per query;
- include `contextualizer_model`, prompt version, and source document version;
- compare baseline vs contextual retrieval on a held-out dataset;
- enable only if recall improves without faithfulness or citation regression.

## 4. Embeddings and representation choices

### 4.1 Dense embeddings

Dense retrieval encodes a query and documents into vectors and uses a similarity
metric. [DPR](https://arxiv.org/abs/2004.04906) established a strong dual-encoder
baseline for open-domain QA, but domain and query distribution matter. Embedding
models are not interchangeable: indexing and query encoding must use compatible
model families, dimensions, normalization, and task instructions.

Track at minimum:

- provider and model identifier;
- query/document instruction prefixes, if any;
- dimensions, distance metric, normalization, tokenizer limits;
- language/domain coverage;
- model and data license;
- model version and migration date;
- cost, throughput, batch size, and failure rate.

Model selection must use the CoverWise policy corpus. Public embedding
benchmarks such as [MTEB](https://github.com/embeddings-benchmark/mteb) are useful
for screening, not a substitute for domain evaluation.

### 4.2 Sparse and lexical representations

BM25 remains important for policy numbers, codes, exclusions, abbreviations,
currency strings, dates, and exact phrases. It is lexical and does not solve
synonyms or paraphrase by itself. Sparse learned representations such as SPLADE
expand terms while remaining compatible with inverted-index style retrieval;
they add model and serving complexity.

The safest default for CoverWise is dense + lexical retrieval. Use a learned
sparse leg only when a labeled evaluation shows a meaningful lift over BM25 for
the language and document types actually supported.

### 4.3 Multi-vector and late interaction

[ColBERT](https://arxiv.org/abs/2004.12832) uses token-level late interaction
instead of collapsing a passage into one vector. It can improve fine-grained
matching but costs more storage and query computation. Qdrant documents support
for sparse vectors, multi-vectors, and combining multiple searches; see [Qdrant
hybrid search guidance](https://qdrant.tech/documentation/faq/qdrant-fundamentals/).

Use late interaction when long passages, terminology, or high-recall passage
matching justify the additional index and serving complexity. It is not the
first upgrade for a small private policy corpus.

### 4.4 HyDE and query transformations

HyDE asks a generator to create a hypothetical answer/document and embeds that
text rather than the raw query. The paper notes that the hypothetical text can
contain false details, with the dense bottleneck used to retrieve real corpus
documents. See [Gao et al., 2022](https://arxiv.org/abs/2212.10496).

Safe use:

- use HyDE as an additional retrieval leg, not as evidence;
- retain the original query for audit and citation context;
- disable it for exact identifiers and low-latency lookups;
- cap generated length and record model/prompt/version;
- compare raw-query, multi-query, and HyDE recall on query slices.

Other query transformations include:

- query rewriting for conversational or underspecified questions;
- multi-query expansion for recall;
- decomposition into subquestions for multi-hop work;
- step-back questions for abstract concepts;
- metadata/entity extraction for pre-filtering;
- query classification into exact, semantic, comparison, aggregation, or
  unsupported classes.

Each transformation can improve recall while increasing latency and introducing
query drift. Keep the original query authoritative and log all derived queries.

## 5. Retrieval, fusion, reranking, and context assembly

### 5.1 First-stage retrieval

First-stage retrieval should optimize recall with a bounded candidate budget.
Typical legs are:

- dense ANN vector search;
- exact/keyword/BM25 search;
- sparse learned vector search;
- metadata/ACL filtering;
- document or section summary retrieval;
- structured database lookup;
- graph or relationship lookup.

Filters are not a post-processing convenience. Apply principal/tenant,
document, language, and data-class filters before candidate expansion wherever
the backend supports it. For insurance, an answer retrieved from another
owner's policy is a critical security failure even if the generation is
faithful to that policy.

### 5.2 Hybrid fusion

Dense and lexical scores are not generally comparable. Fuse by rank (RRF),
calibrated score normalization, or a learned ranker rather than adding raw
cosine and BM25 scores without normalization. Qdrant's guidance recommends
isolating dense and sparse legs, fixing tokenization, tuning fusion on labeled
queries, and adding reranking when precision matters. See [Qdrant hybrid
retrieval FAQ](https://qdrant.tech/documentation/faq/qdrant-fundamentals/).

Minimum fusion checks:

- compare each leg alone before tuning fusion;
- deduplicate by canonical chunk ID;
- preserve source-path provenance (`dense`, `fts`, `hybrid`, `graph`);
- ensure one weak leg cannot swamp a strong leg;
- use query-class-specific weights only when evaluation supports them;
- record candidate ranks and fusion version.

### 5.3 Reranking

Reranking is a second-stage precision step: retrieve a wider candidate set,
score each candidate with a cross-encoder or late-interaction model, and pass a
smaller set to generation. It improves precision at additional latency and
cost. Anthropic's contextual retrieval experiment uses this staged shape and
explicitly calls out the tradeoff. See [reranking in Contextual
Retrieval](https://www.anthropic.com/engineering/contextual-retrieval).

Reranker choices:

| Type | Good at | Cost/risk |
|---|---|---|
| Cross-encoder | query-passage relevance | per-candidate inference cost |
| Late interaction | token-level relevance at scale | more index/storage complexity |
| LLM judge/reranker | flexible domain reasoning | expensive, variable, harder to audit |
| Deterministic boosts | authority, recency, section, exact match | cannot discover unlisted relevance |

Use deterministic boosts for policy section type, exact identifier matches,
document recency, and source authority. Use learned reranking for semantic
relevance. Do not let a reranker rewrite evidence or change access scope.

### 5.4 Context assembly

Context selection is an optimization problem, not “put the largest possible
top-k into the prompt.” Assemble context with:

- a hard token budget;
- deduplication and near-duplicate suppression;
- source diversity when multi-document synthesis is required;
- parent/adjacent expansion only around selected anchors;
- preserved page/span metadata;
- explicit delimiters and source IDs;
- ordering tested for lost-in-the-middle effects;
- a relevance threshold and an insufficient-evidence state.

For a policy answer, a smaller set of high-confidence, source-addressable
chunks is safer than a large context with contradictory or stale clauses.

## 6. Advanced RAG patterns

These patterns are useful design options, not default requirements.

| Pattern | What it does | When to use | CoverWise posture |
|---|---|---|---|
| Parent-child | retrieve small child, expand parent | precise citation plus local context | high-value; already partially represented |
| Hierarchical | index document/section/paragraph/sentence levels | long structured policies | staged after baseline eval |
| Summary index | retrieve document/section summaries first | corpus routing and comparison | useful for multi-policy queries |
| Contextual retrieval | add chunk-specific context at index time | isolated chunks | gated by source/evidence contract |
| HyDE | embed hypothetical answer | vocabulary mismatch | optional extra leg, not exact lookup |
| RAG Fusion | retrieve multiple rewrites and fuse | ambiguous/varied phrasing | useful if query drift is logged |
| Corrective RAG | assess retrieval and correct/retry | weak or noisy corpora | implement deterministic gate first |
| Self-RAG | model decides retrieval/critique actions | research-style adaptive answering | not default for regulated claims |
| Agentic/multi-hop | tool calls and iterative retrieval | decomposition and cross-source work | bounded tool workflow only |
| GraphRAG | build entity/community graph and summarize neighborhoods | global synthesis and relationship queries | evidence graph is safer than free-form graph first |
| RAPTOR | recursively cluster/summarize tree nodes | very long documents | evaluate against parent-child first |
| Multimodal RAG | retrieve text, tables, images, layouts | scans, charts, forms | add specialist adapters and hashes |
| SQL/structured RAG | query canonical fields then retrieve evidence | dates, amounts, policy metadata | preferred for exact fields |

Primary references include [Self-RAG](https://arxiv.org/abs/2310.11511),
[Corrective RAG](https://arxiv.org/abs/2401.15884), [RAPTOR](https://arxiv.org/abs/2401.18059),
and Microsoft's [GraphRAG repository](https://github.com/microsoft/graphrag).

### 6.1 GraphRAG versus evidence graphs

GraphRAG commonly extracts entities/relationships and creates community-level
summaries to answer global questions. It can be powerful for “what themes span
the corpus?” but introduces extraction errors, update complexity, graph
provenance questions, and higher indexing cost.

CoverWise should first build a narrow evidence graph:

- chunk adjacency and section hierarchy;
- policy/document/insured/entity IDs;
- explicit cross-references and clause links;
- source span and page artifact lineage;
- owner and document-version constraints.

Only then consider generated entity graphs or community summaries, and require
every graph-derived claim to link back to source spans.

### 6.2 Multimodal RAG

For PDFs, “multimodal” can mean native layout, tables, page images, charts,
figures, or vision-language embeddings. Keep modality-specific artifacts and
retrieval IDs, then fuse them at context assembly. Do not turn an image caption
into immutable policy text without marking it as generated and verifying the
underlying page artifact.

## 7. Generation and grounding contract

The generator should receive a typed context envelope, not an unlabelled string:

```json
{
  "query": "user query",
  "sources": [
    {
      "source_id": "chunk-id",
      "document_id": "doc-id",
      "page": 4,
      "source_text": "immutable source",
      "retrieval_text": "search representation",
      "retrieval_score": 0.91,
      "source_path": "dense|fts|hybrid|graph"
    }
  ],
  "instructions": {
    "answer_only_from_sources": true,
    "cite_source_ids": true,
    "say_insufficient_evidence": true,
    "do_not_give_insurance_advice": true
  }
}
```

The output schema should carry:

- answer text;
- citation references by source ID, not only ordinal position;
- quote or span when the UI needs a highlight;
- confidence with a documented meaning;
- missing information and follow-up questions;
- answer status (`grounded`, `insufficient_evidence`, `validation_failed`);
- model/provider/prompt version.

Validation must check schema, source IDs, citation bounds, quote containment,
page/document ownership, and answer claims. The final answer should be
constructed only after rejected citations are removed or explicitly marked.

“Confidence” is not a probability unless calibrated. Separate retrieval
confidence, answer confidence, and citation verification status.

## 8. Evaluation framework

### 8.1 Evaluate four layers separately

1. **Parsing:** text/layout/table/span accuracy against source documents.
2. **Retrieval:** whether the right source chunks appear in top-k.
3. **Generation:** whether the answer is correct, complete, and useful given
   the supplied evidence.
4. **Trust/operations:** citation validity, owner isolation, latency, cost,
   retries, fallback usage, and audit completeness.

RAGAS provides RAG-oriented metrics including context precision, context recall,
response relevancy, faithfulness, noise sensitivity, and context entity recall.
See [Ragas metrics](https://docs.ragas.io/en/stable/concepts/metrics/available_metrics/).
These are useful signals, not release truth by themselves.

### 8.2 Retrieval metrics

Use labeled relevance judgments where possible:

- Recall@k / hit rate: did any relevant evidence appear?
- Precision@k: how much of the candidate set is relevant?
- MRR: how early is the first relevant result?
- nDCG@k: graded relevance and ordering quality;
- MAP@k: average precision across queries;
- exact identifier accuracy;
- citation source recall and citation span validity;
- owner-isolation negative tests.

[BEIR](https://github.com/beir-cellar/beir) provides heterogeneous IR datasets
and reports nDCG, MAP, Recall, Precision, and MRR. Use it to compare generic
retrievers, then use a versioned CoverWise dataset for product decisions.

### 8.3 Dataset design

The CoverWise evaluation corpus must include:

- exact policy number, date, amount, and contact lookups;
- semantic benefit and exclusion questions;
- negative “not found in this document” questions;
- cross-reference and adjacent-clause questions;
- table and schedule questions;
- multi-policy comparison questions;
- contradictory/stale document versions;
- ambiguous and underspecified questions;
- prompt-injection strings embedded in source documents;
- owner/cross-tenant leakage tests;
- paraphrase and multilingual slices when supported.

Each case should store source document/version, expected source chunk or span,
answer rubric, query type, risk class, and reviewer status. Synthetic questions
can expand coverage, but high-risk cases need human review against real source
documents.

### 8.4 Release gates

Require a baseline and a candidate report with:

- retrieval metrics by query slice;
- answer correctness and faithfulness;
- exact citation pass rate;
- unsupported-claim rate;
- empty/weak retrieval refusal rate;
- p50/p95 latency and token/cost estimates;
- fallback and retry rates;
- index freshness and failed-ingestion rate;
- security/ACL negative tests;
- regression comparison against the last published index/model version.

No technique should be enabled globally because a single aggregate score rose.
Ship it only if the relevant slice improves and no critical trust metric
regresses.

## 9. Vector stores and retrieval infrastructure

| Technology | Best fit | Strengths | Watch-outs |
|---|---|---|---|
| **pgvector / Supabase** | product data already in Postgres | SQL joins, RLS, transactions, metadata, one operational substrate | ANN tuning, database contention, vector dimension migrations |
| **Qdrant** | dedicated vector/hybrid retrieval | filters, dense/sparse/multi-vector, RRF, payload indexes | separate service and deletion/audit synchronization |
| **FAISS** | local research/offline index | fast library, broad index options | persistence/ACL/operations are application-owned; unsafe deserialization needs care |
| **Chroma** | local development/prototypes | simple developer workflow | production durability, scaling, and tenancy require validation |
| **Pinecone** | managed vector service | managed scaling, metadata and hybrid patterns | vendor cost, data location, operational coupling |
| **Weaviate** | managed/open vector database | hybrid search, modules, schema abstractions | module/version and operational complexity |
| **Elasticsearch/OpenSearch** | search-first systems | BM25, filters, aggregations, vectors, mature operations | heavier search operations and mapping discipline |
| **Vertex AI RAG Engine** | Google-managed corpus/retrieval | managed ingestion/retrieval and Gemini integration | Google IAM/region/cost/data-boundary dependency; less control than owning the pipeline |
| **OpenAI vector stores/File Search** | OpenAI-hosted retrieval | managed tool integration and simple setup | provider-bound storage, access/data policy, limited custom pipeline control |

Primary documentation: [pgvector](https://github.com/pgvector/pgvector),
[Qdrant](https://qdrant.tech/documentation/), [FAISS](https://github.com/facebookresearch/faiss),
[Pinecone hybrid search](https://docs.pinecone.io/guides/search/hybrid-search),
[Weaviate hybrid search](https://docs.weaviate.io/weaviate/search/hybrid),
[Chroma](https://docs.trychroma.com/), [Supabase vector columns](https://supabase.com/docs/guides/ai/vector-columns),
[Google RAG Engine API](https://docs.cloud.google.com/gemini-enterprise-agent-platform/reference/models/rag-api),
and [OpenAI File Search](https://platform.openai.com/docs/guides/tools-file-search).

### 9.1 CoverWise substrate choice

Supabase is the canonical product substrate because the app already needs
owner-scoped documents, evidence, policy fields, audit, lifecycle, and deletion
records in Postgres. Qdrant remains valuable for local development, dedicated
retrieval experiments, and benchmarking. The two backends must not silently
diverge in ranking, filtering, source-text contracts, or deletion semantics.

If both remain, define a backend contract test that asserts:

- same owner/document filter semantics;
- same embedding model/version/dimension contract;
- same source-text return contract;
- same citation metadata and adjacency behavior;
- same empty/weak retrieval status;
- same invalidation and deletion behaviour.

## 10. Frameworks and packages

Frameworks should provide composition and observability, not hide the retrieval
contract.

| Package/framework | Use it for | CoverWise recommendation |
|---|---|---|
| **LangChain** | loaders, splitters, retrievers, agents, LangGraph orchestration | good adapter layer; keep canonical contracts outside chain internals; [retrieval docs](https://docs.langchain.com/oss/python/langchain/retrieval) |
| **LlamaIndex** | indexing abstractions, node/parent retrieval, query engines, workflows | strong option for document-heavy experiments; avoid a second production pipeline; [docs](https://docs.llamaindex.ai/) |
| **Haystack** | explicit modular pipelines, document stores, retrievers, joiners, agents | useful for transparent retrieval experiments; [retrievers](https://docs.haystack.deepset.ai/docs/retrievers) |
| **DSPy** | optimize prompts/programs against metrics | research/optimization layer, not storage or ACL layer; [repo](https://github.com/stanfordnlp/dspy) |
| **Ragas** | RAG evaluation metrics and experiments | use beside deterministic citation/ACL tests, not instead of them; [docs](https://docs.ragas.io/) |
| **Sentence Transformers** | local embeddings and cross-encoders | good local fallback/benchmarking; pin model and license; [docs](https://www.sbert.net/) |
| **FastEmbed** | lightweight local embedding inference | candidate for CPU-friendly retrieval; evaluate against current models; [repo](https://github.com/qdrant/fastembed) |
| **Docling** | structure/layout-aware document conversion and chunking | candidate for native document specialist; preserve current CIR boundary; [docs](https://docling-project.github.io/docling/) |
| **Unstructured** | broad document partitioning/connectors | useful breadth; validate table/layout fidelity and license/deployment cost; [docs](https://docs.unstructured.io/) |
| **PyMuPDF / pypdf** | native PDF extraction | fast baseline; keep OCR/layout fallback for scans |
| **rank-bm25 / Tantivy / SQLite FTS5** | lexical retrieval | use the one owned by the canonical backend; avoid multiple shadow indexes |

Package selection should be recorded with model/provider, input/output schema,
fallback, retry, cost, latency, and ownership. Do not add LangChain, LlamaIndex,
or Haystack merely to rename existing pipeline steps.

## 11. Security, privacy, and trust

### 11.1 Threats

- cross-tenant retrieval or graph expansion;
- prompt injection in indexed documents;
- data poisoning and malicious uploads;
- stale or superseded policy versions;
- citation spoofing through generated retrieval context;
- sensitive query/answer leakage in logs and traces;
- membership inference or training-data reuse;
- model/provider retention and secondary use;
- embedding inversion or vector-store access compromise;
- connector permission drift;
- deletion that removes the source but leaves vectors/cache/audit artifacts.

### 11.2 Controls

- authorize before retrieval, not after generation;
- apply owner/document/version filters in every retrieval leg and graph query;
- treat retrieved text as untrusted data; delimit it from instructions;
- never allow source text to override system/developer instructions;
- store hashes and bounded metadata in analytics by default, not raw questions;
- encrypt source/object/vector stores and restrict service-role access;
- keep source text immutable and generated context separate;
- version prompts, models, parsers, chunkers, and indexes;
- support tombstones and idempotent deletion across all derived artifacts;
- log operator-visible failure states without logging sensitive payloads;
- test injection, cross-owner, stale-version, malformed-document, and partial-
  deletion cases.

The [OWASP LLM Top 10](https://genai.owasp.org/llm-top-10/) is a useful threat
catalog, but product-specific access control and evidence tests remain the
authority for CoverWise.

### 11.3 Customer-facing insurance claims

RAG must not turn a policy clause into a guarantee, coverage determination, or
claim promise. Answers should distinguish:

- what the uploaded policy text says;
- what is not found in the uploaded documents;
- what requires insurer/administrator confirmation;
- what is a user-entered value versus extracted evidence;
- what is an explanation versus regulated advice.

## 12. Observability and cost/latency

Record a privacy-safe trace for each query:

```text
trace_id, owner_id, query_hash, query_length
query_type, derived_query_count, retrieval_strategy
embedding_model/version, candidate counts and source paths
reranker model/version, selected source IDs and scores
context token count, answer model, schema/citation outcomes
cache hit, retry/fallback classes, latency p50/p95 bucket
```

Do not persist raw source/answer/query text in analytics unless there is an
explicit retention and access policy. The evidence UI may retrieve source text
through the authorized document path when the user opens a citation.

Latency budget should be decomposed into:

- authorization/filter planning;
- query embedding;
- dense retrieval;
- sparse retrieval;
- fusion/deduplication;
- reranking;
- graph/parent expansion;
- generation;
- citation verification;
- durable audit write.

Control cost with batching, caching, bounded candidate sets, model routing,
prompt caching where appropriate, and asynchronous index maintenance. Do not
cache across owners or across index/model versions. Cache invalidation must
follow document mutation, deletion, and publish transitions.

## 13. CoverWise current-state map

This section is a static inspection of the live checkout on 2026-07-21. It is
not a claim of deployed or production runtime proof.

### Implemented or represented in the canonical path

| Capability | Current location | Status/evidence |
|---|---|---|
| Main orchestrator | `src/rag/pipeline.py` | present; Tier 1 |
| OpenAI embedding primary | `src/rag/pipeline.py`, `src/config/settings.py` | present; requires runtime config |
| Ollama/local embedding fallback | `src/rag/pipeline.py` | present; provider execution unverified here |
| Qdrant backend | `src/rag/pipeline.py` | present with in-memory fallback; runtime/deployed status open |
| Supabase/pgvector backend | `src/services/supabase_vector_store.py` | present; remote migration/runtime status open |
| SQLite FTS5 local hybrid leg | `src/rag/pipeline.py` | present for Qdrant path; targeted tests cover exact lookup |
| Supabase FTS migrations | `supabase/migrations/20260720020000_rag_fts.sql`, `20260721084000_fts_source_text_contract.sql` | source exists; applied remote schema unverified |
| RRF/hybrid merge | `src/rag/pipeline.py` | present; threshold/calibration needs eval |
| Query classification | `src/rag/pipeline.py` | present; query-class behaviour needs slice eval |
| Query variants/RAG Fusion | `src/rag/pipeline.py` | present; derived-query cost/quality needs eval |
| HyDE | `src/rag/pipeline.py` | present; should remain an optional retrieval leg |
| Cross-encoder reranker | `src/rag/pipeline.py` | optional with lexical fallback; model execution unverified |
| Parent/sentence chunk records | `src/rag/pipeline.py`, Supabase migrations | partially present; full hierarchy and publish contract remain open |
| Chunk links/section taxonomy | `supabase/migrations/20260720000000_chunk_links.sql` | schema present; end-to-end graph semantics open |
| Immutable/source vs retrieval text | `src/rag/pipeline.py`, retrieval-contract migrations | present in code; live data backfill/remote validation open |
| Citation verification | `src/services/citation_verifier.py`, `src/rag/pipeline.py` | wired in current query path; real payload proof open |
| Privacy-safe retrieval audit | `src/services/retrieval_audit_service.py`, retrieval-audit migration | present; remote RLS/runtime audit proof open |
| Versioned Redis query cache | `src/rag/pipeline.py` | present; cross-version and deletion invalidation need end-to-end proof |
| RAGAS integration | `src/eval/ragas_eval.py` | present, but fixture corpus is not decision-grade |

### Current risks and gaps

This is the dated baseline inventory from the initial exploration pass. The
2026-07-22 reconciliation below supersedes individual items where later
repository/runtime evidence closed them.

1. The local launch audit records a RAG initialization failure caused by an
   `httpx`/OpenAI `proxies` compatibility mismatch. This is a runtime blocker,
   not a RAG technique gap; it needs environment/package verification.
2. `RAGPipeline.__init__` requires an OpenAI API key even though fallback
   providers exist. Decide whether this is intentional and document the local
   mode contract or make provider selection explicit.
3. The `.env.example` still contains legacy-looking embedding defaults while
   code/ADRs use `text-embedding-3-small`. One canonical configuration contract
   is needed.
4. Remote Supabase migration application and owner-scoped hybrid retrieval are
   not proven by local tests alone.
5. The current trace counting code should be reconciled with the model's actual
   citation-status field so verified/approximate/rejected counts cannot silently
   become zero.
6. Multi-granularity and adjacency are represented, but an end-to-end test must
   prove deterministic parent/adjacent expansion, deduplication, deletion, and
   owner fencing.
7. The existing RAGAS fixture set is too narrow for release claims. The
   versioned capability/evaluation work should be extended to a reviewed,
   policy-anchored query set.
8. Contextual retrieval is correctly gated off by default until evidence
   separation/backfill and evaluation are complete.
9. Qdrant and Supabase paths need contract parity tests; otherwise “backend
   fallback” can change retrieval semantics without an operator-visible state.

### Prior project-session material incorporated

This exploration incorporates the prior repo-local session artifacts:

- `docs/review/rag_pipeline_discussion_2026-07-20.md` — decisions on
  `tsvector` + `pg_trgm`, normalized `chunk_links`, contextual retrieval gates,
  reviewed evaluation data, and citation strictness.
- `docs/review/rag_pipeline_exploration_map_2026-07-20.md` — earlier inventory
  of dense, local BM25, RRF, HyDE, RAG Fusion, reranking, evidence substrate,
  and implementation gaps.
- `docs/technical/ai_and_nlp/rag_implementation.md` — earlier implementation
  contract, retained as a historical technical reference.

The user also supplied two explicit ChatGPT conversation references and their
contents in this task. They are synthesized in
[`docs/research/rag_chat_session_synthesis_2026-07-21.md`](../research/rag_chat_session_synthesis_2026-07-21.md):

- [`RAG exploration and documentation`](chatgpt-conversation://6a5f4613-bdfc-83e8-8bb2-c79af5788c04)
  — the request for comprehensive RAG exploration, durable documentation,
  exploration-map continuity, and use of the relevant research skills.
- [`RAG app development guide`](chatgpt-conversation://6a4926d2-e31c-83e8-bdd0-edad22e10efe)
  — the learning/build direction: understand the full RAG flow, build the
  primitive manually before adding frameworks, evaluate retrieval separately
  from generation, and treat PDFs as multi-view evidence objects.

This supplied conversation context is an internal product/learning input, not
primary technical evidence. It informs the proposed direction and learning
sequence; the external claims in this document remain grounded in the primary
source register below. A connector was not required because the relevant chat
records were provided directly in the task.

### Conversation-derived direction to preserve

The durable direction from those conversations is:

```text
raw document
  -> canonical document/evidence model
  -> section, table, OCR/image, entity, layout/page, and structured views
  -> typed chunks and lineage-preserving indexes
  -> query-intent routing across exact, lexical, dense, and structured paths
  -> rerank/assemble context
  -> grounded answer with page/region citations
  -> retrieval, grounding, answer, UX, cost, and latency evaluation
```

Parsing, extraction, chunking, and indexing remain separate contracts. The
initial implementation can share one typed chunk substrate, but it must retain
the original structured payload, modality/type, confidence, page and bounding
box lineage, and the retrieval purpose. Exact identifiers, fields, and numeric
comparisons should route to entity/structured retrieval where possible rather
than relying on semantic similarity alone. The learning/build sequence is
manual primitive -> serious parsing -> hybrid and routed retrieval -> fixed
evaluation harness -> product-grade operations -> selective agentic or
multimodal expansion.

## 14. Recommended target shape

### Near-term canonical contract

```text
DocumentProcessingService
  -> canonical CIR + immutable object/page artifacts
  -> versioned chunk builder
  -> source_text/retrieval_text + lineage metadata
  -> embedding contract validator
  -> Supabase/Qdrant adapter implementing one RetrievalBackend interface
  -> dense + lexical candidate set
  -> RRF + deterministic policy boosts
  -> optional reranker
  -> owner-scoped parent/adjacency expansion
  -> structured answer + citation verifier
  -> privacy-safe retrieval audit
```

### Later, only after baseline gates

- contextual retrieval backfill;
- document/section summary index;
- learned sparse or late-interaction retrieval;
- graph/entity extraction and global summaries;
- agentic multi-hop retrieval;
- multimodal figure/table retrieval;
- model fine-tuning or domain-specific reranker training.

### Do not build

- a second production route or pipeline for the same document/query resource;
- a graph database before the evidence-link contract is useful;
- a model switch without an embedding/index migration plan;
- a raw-text analytics lake for queries and answers;
- an agent that can bypass owner filters or citation validation;
- a “confidence” number without calibration and a documented interpretation.

## 15. Decision and implementation units

These are bounded implementation units, not a promise that documentation alone
closes them:

1. **Contract parity:** define and test one retrieval adapter contract for
   Supabase and Qdrant, including filters, source fields, versions, and empty
   states.
2. **Runtime initialization:** resolve the OpenAI/httpx compatibility failure,
   clarify local-provider startup, and align `.env.example` with canonical
   settings.
3. **Trace correctness:** fix status-field accounting and add a test asserting
   non-zero verified/approximate/rejected counts for representative responses.
4. **Evaluation asset:** expand `docs/eval/corpus/` into reviewed query slices
   with source spans, negative cases, and backend/model baselines.
5. **Hierarchy and deletion:** prove parent/adjacent expansion, deduplication,
   owner fencing, version transitions, and derived-artifact deletion.
6. **Contextual retrieval gate:** backfill only through a versioned, resumable
   job; compare against the baseline; publish only with a passing trust gate.
7. **Advanced retrieval experiments:** evaluate summary, learned sparse,
   late-interaction, GraphRAG, and agentic/multimodal variants behind the same
   benchmark and evidence contracts.

## 16. Anything else?

Yes:

- RAG research is only useful if the selected technique is connected to the
  actual user journey: upload, process, ask, inspect evidence, recover from
  failure, and delete.
- A better retriever cannot compensate for wrong OCR, stale policy versions,
  missing page lineage, or a broken owner filter.
- The evaluation corpus and index metadata are product data assets and need
  versioning, retention, access control, and deletion semantics.
- Every new RAG capability should state its user value, business/team value,
  operational value, evidence tier, and closure trigger in the exploration map.

## 17. Status reconciliation — 2026-07-22

The later exploration-map addenda and this closure pass change the status of
several older baseline statements:

- The earlier OpenAI/httpx startup mismatch is superseded by the later runtime
  re-audit: the active environment initializes successfully. The remaining
  HTTPX deprecation warning is hygiene debt, not evidence of a startup outage.
- Remote schema/object parity has substantially advanced and the map records a
  green current parity audit. Migration-history provenance, clean deployed
  Qdrant/local parity, authenticated page-read traversal, and held-out answer
  quality remain separate higher-tier gates.
- The local provider contract is now explicit in code: `RAGPipeline` and
  `LLMClient` can initialize without `OPENAI_API_KEY` when a local/compatible
  provider is configured. Supabase still fails closed when the canonical
  embedding provider is unavailable because mixing embedding spaces would make
  the durable index unsafe.
- The RAGAS harness now passes retrieved source contexts rather than using the
  generated answer as a fake context. This is a local correctness improvement,
  not a live quality score; provider execution and the reviewed corpus still
  require runtime evaluation.

### Remaining closure set

1. Run a real authenticated two-owner query and citation-to-page traversal.
2. Prove delete/re-index/version transitions across source files, page
   artifacts, chunks, vector/lexical indexes, cache, and audit records.
3. Execute the reviewed corpus across exact, numeric, table, OCR, narrative,
   negative, multilingual, and cross-document slices; retain metrics and
   failure cases.
4. Benchmark real scanned insurance fixtures for tables, key/value fields,
   handwriting, formulas, multilingual text, office formats, and visual/chart
   annotations before promoting specialist parsers.
5. Implement or explicitly defer relationship-aware policyholder/insured/
   nominee extraction, clarification questions, document-view citations, and
   cross-policy comparison with owner and evidence contracts.

The first four require deployed or real-data evidence unavailable from local
unit tests alone. The fifth is product scope and should be accepted through an
ADR or marked as a deliberate post-launch boundary.

### Owners and closure criteria

| Open item | Responsible lane | Closure trigger |
|---|---|---|
| Authenticated two-owner retrieval and citation-to-page traversal | Backend/platform + evidence UX | Deployed replay proves owner isolation, source-span/page navigation, and operator-readable failure states. |
| Delete/re-index/version transitions | Backend/platform + storage operations | Fault-injected replay proves idempotent cleanup across source, derived artifacts, indexes, cache, and audit records. |
| Reviewed held-out RAG evaluation | RAG/evaluation owner | Versioned corpus publishes retrieval, grounding, citation, negative, latency, and cost results with thresholds and failure cases. |
| Real scanned/document-capability benchmark | Document intelligence owner | Consented corpus proves per-capability accuracy, p95 latency, partial failure, retry, licensing, privacy, and manual-review behavior. |
| Relationship extraction, clarification, document view, comparison | Product/UX + domain review | ADR records the user contract and the implementation passes owner/evidence/citation tests; otherwise it is explicitly deferred. |

The synthetic document-capability report now provides stronger local evidence:
10/10 generated/native cases passed, including native PDF tables and figures,
DOCX/HTML/EML/XLSX/PPTX structure, and generated doctr OCR/mixed-page routing.
This remains Tier 2 synthetic evidence; it does not establish accuracy on
consented real insurance documents.

Verification after this reconciliation: the full backend suite passed 508 tests
with one skip; the focused RAG/document suite passed 73 tests; changed RAG
files passed Ruff and Python compilation; and an offline local-provider smoke
run initialized without OpenAI credentials and produced a 768-dimensional
embedding through the configured local/fallback path. Dependency health passed
with `uv pip check`.

## Sources

The following are primary papers or first-party technical documentation used for
this research:

- [Lewis et al. — Retrieval-Augmented Generation](https://arxiv.org/abs/2005.11401)
- [Karpukhin et al. — Dense Passage Retrieval](https://arxiv.org/abs/2004.04906)
- [Gao et al. — HyDE](https://arxiv.org/abs/2212.10496)
- [Khattab and Zaharia — ColBERT](https://arxiv.org/abs/2004.12832)
- [Anthropic — Contextual Retrieval](https://www.anthropic.com/engineering/contextual-retrieval)
- [LangChain — Retrieval and RAG architectures](https://docs.langchain.com/oss/python/langchain/retrieval)
- [Haystack — Retrievers and hybrid retrieval](https://docs.haystack.deepset.ai/docs/retrievers)
- [Docling — Architecture](https://docling-project.github.io/docling/concepts/architecture/)
- [Qdrant — Fundamentals and hybrid search](https://qdrant.tech/documentation/faq/qdrant-fundamentals/)
- [Supabase — Vector columns](https://supabase.com/docs/guides/ai/vector-columns)
- [Pinecone — Hybrid search](https://docs.pinecone.io/guides/search/hybrid-search)
- [Weaviate — Hybrid search](https://docs.weaviate.io/weaviate/search/hybrid)
- [pgvector](https://github.com/pgvector/pgvector)
- [FAISS](https://github.com/facebookresearch/faiss)
- [Google Gemini Enterprise Agent Platform RAG API](https://docs.cloud.google.com/gemini-enterprise-agent-platform/reference/models/rag-api)
- [OpenAI File Search](https://platform.openai.com/docs/guides/tools-file-search)
- [Ragas metrics](https://docs.ragas.io/en/stable/concepts/metrics/available_metrics/)
- [BEIR benchmark](https://github.com/beir-cellar/beir)
- [MTEB benchmark](https://github.com/embeddings-benchmark/mteb)
- [OWASP LLM Top 10](https://genai.owasp.org/llm-top-10/)

### Evidence boundary

Primary sources establish what a paper, package, or platform documents. The
CoverWise recommendations and current-state classifications above are
engineering inferences from those sources plus static inspection of the
checkout. They are not production-runtime proof. Remote Supabase state,
provider credentials, deployed latency, real-document quality, and authenticated
cross-owner behaviour remain separate verification gates.
