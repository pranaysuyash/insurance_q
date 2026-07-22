# Retrieval-Augmented Generation: primary-source research

**Scope date:** 2026-07-21 (research and source-access snapshot)

**Repository:** `/Users/pranay/Projects/medpiper/insurance_app`

**Source rule:** This artifact uses only primary sources: original research papers, standards/specifications, official product documentation, and first-party repositories. Vendor documentation describes vendor capability, not independent quality; paper results are not production guarantees. Package/framework capabilities are stated at the capability level rather than as unpinned version claims.

## Executive synthesis

RAG is a pipeline, not a single model feature. A complete system ingests source data, preserves structure and provenance, chunks or represents it for retrieval, computes one or more searchable representations, retrieves candidates under authorization and freshness constraints, optionally fuses and reranks them, assembles bounded evidence, and generates an answer whose claims can be traced back to that evidence. The original RAG paper formalized combining parametric model memory with a non-parametric dense-vector index and distinguished a fixed-passage generator from one that can use different passages during generation ([Lewis et al., 2020](https://arxiv.org/abs/2005.11401)). Current framework documentation exposes the same decomposition as loaders, splitters/parsers, embeddings, vector stores, retrievers, and generation ([LangChain retrieval](https://docs.langchain.com/oss/python/langchain/retrieval)).

The durable quality pattern is staged retrieval: use inexpensive lexical and/or dense retrieval for recall, combine candidates when signals are complementary, use a more expensive query-document model or late-interaction model for precision, then pass a small, deduplicated, provenance-bearing context to the generator. BEIR’s primary benchmark reports BM25 as a robust baseline and finds that reranking and late interaction can improve effectiveness at higher computational cost, while dense and sparse neural first-stage methods are more efficient but may generalize less reliably ([BEIR](https://arxiv.org/abs/2104.08663)). This is evidence for benchmarking the whole stack, not a universal prescription.

The largest practical quality lever is usually the data layer: extraction, layout, tables, headings, metadata, versioning, ACLs, and chunk-to-source links. Structure-aware parsers such as Docling and Unstructured preserve document elements and layout metadata instead of flattening every file into an undifferentiated string ([Docling technical report](https://arxiv.org/abs/2408.09869), [Docling document model](https://docling-project.github.io/docling/concepts/docling_document/), [Unstructured partitioning](https://docs.unstructured.io/open-source/core-functionality/partitioning)). A stronger embedding model cannot recover a table relationship or heading hierarchy that ingestion discarded.

## 1. Verified source facts versus recommendations and inference

### Verified source facts

- The original RAG formulation combines a pretrained generator with an external non-parametric memory accessed by a neural retriever; the paper evaluates fixed-passage and per-token passage-conditioning variants ([RAG paper](https://arxiv.org/abs/2005.11401)).
- Dense retrieval maps queries and documents into a shared vector space; DPR presents a dual-encoder approach for open-domain QA ([DPR paper](https://arxiv.org/abs/2004.04906)).
- Learned sparse retrieval can retain inverted-index-like exact-term behavior while adding learned expansion; SPLADE uses sparse regularization and term weighting ([SPLADE](https://arxiv.org/abs/2107.05720)).
- Hybrid retrieval combines lexical and vector signals. Elasticsearch documents RRF as a rank-based fusion method; OpenSearch documents normalization and rank-fusion processors; Pinecone documents dense+sparse hybrid patterns ([Elasticsearch hybrid](https://www.elastic.co/docs/solutions/search/hybrid-search), [OpenSearch hybrid](https://docs.opensearch.org/latest/vector-search/ai-search/hybrid-search/index/), [Pinecone hybrid](https://docs.pinecone.io/guides/search/hybrid-search)).
- Cross-encoders score query-document pairs jointly and are normally applied to a smaller candidate set because they are more expensive than independent embedding retrieval ([LangChain cross-encoder reranker](https://docs.langchain.com/oss/python/integrations/document_transformers/cross_encoder_reranker), [Haystack rankers](https://docs.haystack.deepset.ai/docs/choosing-the-right-ranker)).
- HyDE generates a hypothetical document, embeds it, and retrieves real documents by vector similarity; the paper explicitly notes that the hypothetical document may contain false details ([HyDE](https://arxiv.org/abs/2212.10496)).
- Self-RAG trains a model to adaptively retrieve and self-critique using reflection tokens; CRAG adds retrieval evaluation and corrective actions ([Self-RAG](https://arxiv.org/abs/2310.11511), [CRAG](https://arxiv.org/abs/2401.15884)).
- MTEB spans multiple embedding tasks, datasets, and languages and reports that no single embedding method dominates all tasks ([MTEB](https://arxiv.org/abs/2210.07316)).
- RAGAS separates retrieval and generation dimensions and proposes reference-free metrics; it does not remove the need for domain-specific human or gold-set evaluation ([RAGAS](https://arxiv.org/abs/2309.15217)).
- RAG systems are exposed to direct and indirect prompt injection, including malicious instructions in retrieved files; OWASP states that RAG does not fully mitigate prompt injection and recommends content segregation, least privilege, output validation, and adversarial testing ([OWASP LLM01:2025](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)).
- OpenTelemetry’s GenAI semantic conventions include retrieval query attributes and establish a standard vocabulary for GenAI telemetry ([OpenTelemetry GenAI conventions](https://opentelemetry.io/docs/specs/semconv/registry/attributes/gen-ai/)).

### Recommendations and inference in this artifact

The proposed reference architecture, default stage ordering, security controls, telemetry fields, cost tactics, and vendor-selection heuristics below are engineering recommendations inferred from the cited facts and from common system-design constraints. They are not claims that a paper or vendor guarantees a particular outcome. They should be validated against the app’s actual corpus, access model, latency budget, and labeled evaluation set.

## 2. RAG architecture and end-to-end flow

### 2.1 Ingestion and indexing flow

```text
source files / APIs
        |
        v
acquire + authenticate + checksum + version
        |
        v
parse / OCR / layout / tables / images / metadata
        |
        v
canonical document model + provenance + ACLs
        |
        v
structure-aware segmentation and parent/child links
        |
        +--> dense embeddings --> vector index
        +--> sparse/BM25 representation --> inverted index
        +--> multimodal or late-interaction vectors --> multimodal index
        |
        v
index manifest: parser, model, chunk policy, source version, timestamps
```

The ingestion contract should make a source document and its derived search records separately addressable. A chunk should retain at least source ID, version/hash, page or section location, parser status, content type, tenant/owner, ACL classification, and parent/child relationship. This is a recommendation: the cited parsers and stores expose the relevant building blocks, but the application owns the end-to-end contract.

### 2.2 Query and answer flow

```text
user query + conversation state + authorization
        |
        v
query classification / rewrite / decomposition (optional)
        |
        v
ACL and freshness filters
        |
        +--> lexical/BM25 or learned sparse retrieval
        +--> dense ANN retrieval
        +--> multimodal or metadata retrieval
        |
        v
deduplicate + fuse ranks/scores
        |
        v
rerank / diversity / parent expansion / evidence sufficiency check
        |
        v
bounded context with source IDs and citations
        |
        v
generator or tool-using agent
        |
        v
groundedness / schema / policy / citation validation
        |
        v
answer, abstention, clarification, or operator escalation
```

LangChain’s current documentation distinguishes a predictable two-step RAG chain, an agentic RAG system in which an LLM decides when and how to retrieve, and a hybrid design with query preprocessing and validation ([RAG architectures](https://docs.langchain.com/oss/python/langchain/retrieval)). This is a useful control/latency taxonomy: two-step paths are easier to bound; agentic paths can handle tool choice and iterative retrieval but add variable calls and failure modes.

### 2.3 Architecture choices

| Architecture | Source-verified shape | Recommendation / trade-off |
|---|---|---|
| Two-step RAG | Retrieve, then generate; one predictable retrieval stage and one generation stage ([LangChain](https://docs.langchain.com/oss/python/langchain/retrieval)) | Default for FAQ, policy, and document explanation where query intent is clear. |
| Hybrid/self-correcting RAG | Query enhancement, retrieval validation, and answer validation can be inserted between stages ([LangChain](https://docs.langchain.com/oss/python/langchain/retrieval)) | Prefer for high-value answers where a failed retrieval must produce a retry or abstention rather than confident synthesis. |
| Agentic RAG | Agent chooses whether to call retrieval tools and can loop over tool results ([LangGraph agentic RAG](https://docs.langchain.com/oss/python/langgraph/agentic-rag), [Haystack Agent](https://docs.haystack.deepset.ai/docs/agent)) | Use only when tool choice, decomposition, or multi-hop behavior justifies variable latency and stronger guardrails. |
| Trained adaptive RAG | Self-RAG learns adaptive retrieval and critique behavior ([Self-RAG](https://arxiv.org/abs/2310.11511)) | Treat as a model-training research path, not a drop-in orchestration feature. |

## 3. Chunking and structure-aware parsing

### 3.1 Chunking principles

Chunking controls what one retrieval score means. Fixed-size chunks are simple and make index size predictable, but may split a definition from its qualifier or mix unrelated sections. Recursive splitters try larger structural separators first; LangChain’s recommended generic splitter tries paragraphs, then lines, then words, and supports token- or character-based sizing ([RecursiveCharacterTextSplitter](https://docs.langchain.com/oss/python/integrations/splitters/recursive_text_splitter)). Haystack’s `DocumentSplitter` supports word, sentence, passage, page, line, and function units, overlap, and a minimum-fragment threshold ([Haystack DocumentSplitter](https://docs.haystack.deepset.ai/docs/documentsplitter)).

Structure-based splitting should be the first candidate for Markdown, HTML, JSON, source code, and well-formed policy documents. LangChain explicitly documents header-, tag-, object/array-, and function/class-based splitting as ways to preserve logical organization ([Text splitters](https://docs.langchain.com/oss/python/integrations/splitters/index)). Use token budgets after structural segmentation, not as a replacement for it.

Overlap can preserve boundary context but increases storage, embedding, and retrieval duplication. The correct overlap is corpus- and task-dependent; benchmark zero overlap, small overlap, and parent-context expansion rather than assuming that more overlap improves quality.

### 3.2 Layout-aware document parsing

For PDFs and office files, parsing is an information-recovery step, not mere text extraction. Docling represents text, tables, pictures, and layout information in a structured `DoclingDocument` and reports models for layout and table-structure recognition ([Docling technical report](https://arxiv.org/abs/2408.09869), [Docling document model](https://docling-project.github.io/docling/concepts/docling_document/)). Unstructured partitions many formats into typed elements and uses element metadata when chunking; its `by_title` strategy keeps title-defined sections together and only falls back to splitting an element when it exceeds the desired maximum ([Unstructured partitioning](https://docs.unstructured.io/open-source/core-functionality/partitioning), [Unstructured chunking](https://docs.unstructured.io/open-source/core-functionality/chunking)). Microsoft MarkItDown targets Markdown output while warning that it performs I/O with the current process privileges and that untrusted inputs must be sanitized ([MarkItDown repository](https://github.com/microsoft/markitdown)).

Google’s Document AI layout parser is explicitly positioned for RAG because ordinary OCR can flatten headings, tables, and lists; Google also documents a data-residency limitation for the Gemini-based processor ([Document AI layout parser](https://docs.cloud.google.com/document-ai/docs/layout-parse-chunk)). That limitation is a deployment fact to review before sending sensitive documents to a managed parser.

### 3.3 Recommended canonical document model

Recommendation: retain both a lossless source reference and a normalized representation. Each element should have `document_id`, `document_version`, `element_id`, `element_type`, `text` or binary reference, page/bounding box, heading path, table/figure relationship, source URI, parser/model versions, and ACL/retention metadata. Derived chunks should point to one or more element IDs, never replace them. This enables re-chunking and re-embedding without losing original provenance, and makes table/figure-specific retrieval possible.

## 4. Retrieval families

### 4.1 Dense retrieval

Dense retrieval encodes queries and documents as continuous vectors and uses similarity search. DPR is the canonical dual-encoder example ([DPR](https://arxiv.org/abs/2004.04906)). Approximate-nearest-neighbor indexes trade exact recall for speed and memory. FAISS provides exact flat indexes, HNSW, IVF, product/scalar quantization, and optional GPU/ROCm support in its first-party library and index-selection guidance ([FAISS repository](https://github.com/facebookresearch/faiss), [FAISS index guide](https://github.com/facebookresearch/faiss/wiki/Guidelines-to-choose-an-index)).

Dense retrieval is strong for paraphrase and semantic similarity but can miss exact identifiers, rare product codes, legal phrases, and newly introduced terms. The last sentence is an engineering inference supported by the complementary strengths documented by Pinecone for semantic versus lexical search ([Pinecone hybrid](https://docs.pinecone.io/guides/search/hybrid-search)).

### 4.2 Sparse retrieval

Classic sparse retrieval uses token statistics and inverted indexes; BM25 remains a strong baseline in BEIR ([BEIR](https://arxiv.org/abs/2104.08663)). Learned sparse models such as SPLADE produce sparse term-impact representations with expansion, preserving lexical-index behavior while adding semantic vocabulary ([SPLADE](https://arxiv.org/abs/2107.05720)). Sparse retrieval is appropriate when exact strings, identifiers, dates, formulas, or domain terminology matter. It is also explainable at the term-match level, though learned sparse expansion is less transparent than raw BM25.

### 4.3 Hybrid retrieval and fusion

Hybrid retrieval runs lexical and semantic searches and fuses candidate lists. Elasticsearch recommends RRF for combining full-text and vector results ([Elasticsearch hybrid](https://www.elastic.co/docs/solutions/search/hybrid-search)); its RRF reference defines the rank-based formula and parameters such as `rank_constant` and `rank_window_size` ([Elasticsearch RRF](https://www.elastic.co/docs/reference/elasticsearch/rest-apis/reciprocal-rank-fusion)). OpenSearch supports score normalization and rank-fusion processors in a search pipeline ([OpenSearch hybrid](https://docs.opensearch.org/latest/vector-search/ai-search/hybrid-search/index/)). Weaviate documents configurable fusion of vector and BM25F results ([Weaviate hybrid](https://docs.weaviate.io/weaviate/concepts/search/hybrid-search)).

Recommendation: start with separately observable dense and sparse candidate lists, fuse with RRF as a baseline, then tune weighted score fusion only after measuring score calibration and corpus-specific gains. Preserve each component score/rank in telemetry so relevance regressions are diagnosable.

### 4.4 Metadata and authorization filters

Metadata filtering is a correctness boundary, not just a relevance feature. Pinecone documents namespaces for tenant isolation and faster targeted queries, metadata filters, eventual consistency, and query-result limits ([Pinecone namespaces](https://docs.pinecone.io/guides/index-data/indexing-overview), [Pinecone search overview](https://docs.pinecone.io/guides/search/search-overview)). Chroma supports metadata and document filters in `query`/`get` ([Chroma query](https://docs.trychroma.com/docs/querying-collections/query-and-get), [Chroma metadata filtering](https://docs.trychroma.com/docs/querying-collections/metadata-filtering)). Elasticsearch documents shared filters across lexical and vector retrieval ([hybrid search](https://www.elastic.co/elasticsearch/hybrid-search)).

Recommendation: apply tenant, owner, ACL, retention, and legal-hold filters before the generator sees candidates. Test filter bypasses, empty filtered result sets, stale permissions, and concurrent ACL changes. Never rely on a post-generation instruction such as “do not reveal other users’ data” as the primary access control.

## 5. Reranking and multi-stage retrieval

Reranking is a precision stage over a small candidate set. Cross-encoders inspect query and document jointly; Haystack documents API-based and local cross-encoder rankers, as well as deterministic metadata and diversity rankers ([Haystack rankers](https://docs.haystack.deepset.ai/docs/choosing-the-right-ranker)). Elasticsearch supports semantic reranking over lexical, dense, sparse, or hybrid candidates and emphasizes that the model should operate on a small top-k set because it is computationally expensive ([semantic reranking](https://www.elastic.co/docs/solutions/search/ranking/semantic-reranking)). Pinecone exposes hosted reranking as a second-stage operation ([Pinecone rerank](https://docs.pinecone.io/guides/search/rerank-results)). Vertex AI RAG Engine documents both a ranking API with lower latency and an LLM reranker with higher latency ([Vertex reranking](https://cloud.google.com/vertex-ai/generative-ai/docs/retrieval-and-ranking?authuser=1)).

Late interaction is a middle ground between one-vector retrieval and full cross-encoding. ColBERT encodes query and document tokens separately and applies contextualized late interaction; Qdrant’s first-party tutorial shows dense+sparse candidate retrieval followed by a ColBERT-style multi-vector reranking stage ([ColBERT repository](https://github.com/stanford-futuredata/ColBERT), [Qdrant hybrid with reranking](https://qdrant.tech/documentation/tutorials-search-engineering/reranking-hybrid-search/)).

Recommended default: retrieve a wider set, deduplicate by source/section, rerank, then select a small context using both relevance and diversity. Measure recall before reranking, NDCG/MRR after reranking, answer groundedness, and p50/p95 latency separately. Do not call a reranker a recall fix: it can only reorder what first-stage retrieval found.

## 6. Query transformation, parent-child, and multi-vector retrieval

### 6.1 Query transformation

Query transformation changes the retrieval representation, not the user’s canonical question. Techniques include normalization, spelling/entity expansion, multi-query generation, decomposition into subquestions, hypothetical-document generation, and metadata-aware query construction. HyDE is a documented paper-backed example, but its hypothetical text can be wrong, so retain the original query and treat the generated text as a retrieval aid only ([HyDE](https://arxiv.org/abs/2212.10496)). LangChain’s current architecture docs list query enhancement and rewrite loops as hybrid RAG components ([LangChain retrieval](https://docs.langchain.com/oss/python/langchain/retrieval)); LlamaIndex exposes a HyDE query transform in its official API documentation ([LlamaIndex HyDE transform](https://docs.llamaindex.ai/en/v0.10.18/api_reference/query/query_transform.html)).

Recommendation: log original query, transformed queries, transformation reason, model/version, and retrieved results. Bound the number of generated variants and cache deterministic transformations. Never let a rewrite silently change tenant, date, or policy constraints.

### 6.2 Hierarchical and parent-child retrieval

Small child chunks can give high retrieval precision while a parent section supplies enough context for synthesis. LlamaIndex’s hierarchical node parser creates coarse-to-fine nodes with parent references, and its AutoMergingRetriever can replace retrieved children with a parent when enough children from that parent are retrieved ([LlamaIndex hierarchical parser](https://docs.llamaindex.ai/en/v0.10.22/api_reference/node_parsers/hierarchical/), [LlamaIndex node parser modules](https://docs.llamaindex.ai/en/v0.10.18/module_guides/loading/node_parsers/modules.html)). The official LlamaIndex pack also describes “small-to-big” retrieval: index child chunks while linking them to parents ([small-to-big retriever pack](https://docs.llamaindex.ai/en/v0.10.23/api_reference/packs/recursive_retriever/)).

Recommendation: index children for recall, carry parent IDs and section paths, and expand only after ranking. Expansion should be bounded by token budget and should preserve the child evidence that triggered the expansion. Test the failure case where one parent contains many unrelated children; majority thresholds and section boundaries must be corpus-specific.

### 6.3 Multi-vector and multimodal representations

Multi-vector retrieval represents one logical item with multiple vectors, such as token vectors, page vectors, text/image vectors, or separate embedding spaces. ColBERT’s late interaction and Qdrant’s multi-vector configuration are primary examples ([ColBERT](https://github.com/stanford-futuredata/ColBERT), [Qdrant multivector search](https://qdrant.tech/documentation/concepts/vectors/#multivectors)). Haystack documents multi-embedding retrieval, including multiple embeddings for one document and multimodal retrieval ([Haystack retrievers](https://docs.haystack.deepset.ai/docs/retrievers)).

Multi-vector systems increase index size, indexing cost, and query complexity. They are justified when one pooled vector loses token-level, page-level, or cross-modal evidence that materially affects task quality; otherwise a simpler dense+sparse baseline is easier to operate.

## 7. Agentic and multi-hop RAG

Agentic RAG gives a model tools and control flow to decide whether to retrieve, which retriever to call, how to decompose a question, and whether to retry. LangGraph’s official tutorial builds a graph with query-or-respond, retrieval, document grading, question rewriting, and answer generation nodes ([LangGraph agentic RAG](https://docs.langchain.com/oss/python/langgraph/agentic-rag)). Haystack’s Agent is a loop-based component that calls tools, updates state, and stops on configured exit conditions ([Haystack Agent](https://docs.haystack.deepset.ai/docs/agent)).

Multi-hop questions often require retrieving one fact to construct the next query. CRAG’s retrieval evaluator and corrective actions, Self-RAG’s adaptive retrieval/critique, and LlamaIndex’s sub-question and recursive-retriever examples are primary references for different points in this design space ([CRAG](https://arxiv.org/abs/2401.15884), [Self-RAG](https://arxiv.org/abs/2310.11511), [LlamaIndex recursive/table example](https://docs.llamaindex.ai/en/stable/examples/query_engine/sec_tables/tesla_10q_table/)).

Recommendation: keep the agent loop behind explicit budgets: maximum tool calls, maximum retrieved tokens, maximum wall-clock time, allowed domains/stores, retry count, and stop conditions. Every hop should record query, tool, filter, result IDs, decision, and failure reason. For high-risk domains, require deterministic authorization and validation outside the model, and use human approval for consequential actions; OWASP explicitly recommends least privilege and human approval for high-risk actions ([OWASP LLM01](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)).

## 8. Multimodal and document RAG

Text-only RAG can miss information encoded in figures, charts, tables, layout, and images. MuRAG introduced a multimodal external memory containing image and text for open QA ([MuRAG](https://arxiv.org/abs/2210.02928)). M3DocRAG evaluates multi-page, multi-document visual document QA where evidence may be text, charts, or figures ([M3DocRAG](https://arxiv.org/abs/2411.04952)). Docling and Document AI layout parsing provide ingestion-side structure; ColBERT/ColPali-style systems provide page or token-level visual retrieval ([Docling](https://arxiv.org/abs/2408.09869), [Document AI layout parser](https://docs.cloud.google.com/document-ai/docs/layout-parse-chunk)).

Three implementation patterns are distinct:

1. **Convert-to-text:** OCR and/or caption tables, figures, and pages, then use text RAG. This is operationally simple and supports text-only generators, but conversion errors can erase visual relationships.
2. **Dual index:** keep text/sparse/dense retrieval and a visual/page index, then fuse or route based on query type. This preserves modality-specific evidence but adds synchronization and evaluation work.
3. **Visual late interaction:** index page or patch-level multimodal representations and pass retrieved page images to a vision-language generator. This preserves layout but raises storage, model, and privacy costs.

Recommendation: retain original page images and structured elements alongside OCR text; cite page and element coordinates; evaluate text-only, dual-index, and visual retrieval on figure/table-heavy questions rather than assuming the most expensive modality wins.

## 9. Embeddings and embedding evaluation

An embedding model is part of the retrieval contract: model identity, pooling/normalization, dimensionality, instruction prefix, language coverage, distance metric, and version must be recorded. MTEB shows that embedding quality varies by task and that there is no universal winner ([MTEB](https://arxiv.org/abs/2210.07316)). OpenAI documents embeddings as vectors for semantic similarity and exposes current embedding model guidance in its official API docs ([OpenAI embeddings guide](https://developers.openai.com/api/docs/guides/embeddings)). Sentence Transformers documents separate bi-encoder and cross-encoder roles and provides evaluation utilities ([Sentence Transformers documentation](https://sbert.net/)).

Evaluate the chosen model on:

- in-domain query-document relevance, including exact identifiers and long-tail terminology;
- multilingual and spelling variation if applicable;
- document lengths and chunk sizes actually used;
- hard negatives and near-duplicates;
- filtered retrieval with real ACL predicates;
- latency, memory, embedding throughput, storage bytes, and re-index cost;
- drift after source, parser, model, or chunk-policy changes.

Do not compare embedding leaderboard scores as if they were application accuracy. Public benchmarks are useful screening signals; a de-identified, manually labeled corpus for the product is the release gate.

## 10. Evaluation design

Separate evaluation into retrieval, synthesis, and system operations:

| Layer | Core measures | What it diagnoses |
|---|---|---|
| Retrieval | Recall@k, precision@k, MRR, nDCG@k, hit rate, filtered recall, citation-source recall | Whether the right evidence entered the candidate set and final context |
| Context assembly | Context precision/recall, redundancy, parent-expansion rate, token count, citation coverage | Whether selected evidence is focused, diverse, and traceable |
| Generation | Faithfulness/groundedness, answer relevance, completeness, abstention correctness, citation entailment | Whether the model used evidence without inventing or overclaiming |
| Operations | p50/p95/p99 latency, error/retry/fallback rate, freshness lag, index consistency, cost/query, tokens/query | Whether the system is reliable and economically sustainable |
| Safety | ACL leakage tests, prompt-injection success, poisoning detection, PII exposure, unsafe tool-call rate | Whether the RAG trust boundary holds under adversarial inputs |

BEIR is useful for broad retrieval comparison, MTEB for embedding task diversity, and RAGAS for automated RAG dimensions ([BEIR](https://arxiv.org/abs/2104.08663), [MTEB](https://arxiv.org/abs/2210.07316), [RAGAS](https://arxiv.org/abs/2309.15217)). The recommendation is to add a product-specific gold set with answerability labels, expected sources, ACL variants, stale/updated documents, ambiguous questions, and adversarial documents. Use exact-source recall as a hard gate for extraction or policy-answering paths; a fluent answer is not evidence that retrieval was correct.

## 11. Current framework, database, and managed-platform landscape

| Component | First-party facts / capabilities | Practical fit and caveat |
|---|---|---|
| **LangChain / LangGraph / LangSmith** | LangChain exposes loaders, splitters, embeddings, vector stores, retrievers, RAG architectures, rerankers, and agentic RAG; LangGraph provides graph control flow; LangSmith provides tracing and evaluation ([LangChain retrieval](https://docs.langchain.com/oss/python/langchain/retrieval), [LangGraph agentic RAG](https://docs.langchain.com/oss/python/langgraph/agentic-rag), [LangSmith observability](https://docs.langchain.com/langsmith/observability-concepts)). | Strong orchestration and integration surface. Pin package versions and keep canonical domain contracts outside framework-specific abstractions. SaaS tracing has retention/privacy implications ([LangSmith privacy](https://docs.langchain.com/langsmith/mask-inputs-outputs)). |
| **LlamaIndex** | Official docs cover node parsers, hierarchical nodes, AutoMergingRetriever, recursive retrievers, HyDE, and query engines ([hierarchical node parser](https://docs.llamaindex.ai/en/v0.10.22/api_reference/node_parsers/hierarchical/), [node parser modules](https://docs.llamaindex.ai/en/v0.10.18/module_guides/loading/node_parsers/modules.html), [HyDE](https://docs.llamaindex.ai/en/v0.10.18/api_reference/query/query_transform.html)). | Strong document-centric and hierarchical retrieval abstractions. Some search results are versioned docs; verify APIs against the installed package before implementation. |
| **Haystack** | Modular components/pipelines, document stores, retrievers, hybrid retrievers, rankers, multimodal systems, and loop-based agents ([Haystack introduction](https://docs.haystack.deepset.ai/), [retrievers](https://docs.haystack.deepset.ai/docs/retrievers), [rankers](https://docs.haystack.deepset.ai/docs/rankers), [agents](https://docs.haystack.deepset.ai/docs/agents)). | Good explicit pipeline/dataflow model and local/API ranker choices. Component integration compatibility and provider costs must be tested in the target deployment. |
| **Qdrant** | Supports dense, sparse, hybrid prefetch, payload filtering, multivectors, and late-interaction reranking ([hybrid queries](https://qdrant.tech/documentation/search/hybrid-queries/), [hybrid with reranking](https://qdrant.tech/documentation/tutorials-search-engineering/reranking-hybrid-search/), [multivectors](https://qdrant.tech/documentation/concepts/vectors/#multivectors)). | Strong fit for multi-signal retrieval and payload-aware search. Operate backups, schema/index migration, filtering tests, and cluster capacity as first-class concerns. |
| **pgvector / Supabase** | pgvector supports exact search by default and HNSW/IVFFlat approximate indexes, with halfvec, sparsevec, binary vectors, quantization, and concurrent index creation guidance ([pgvector repository](https://github.com/pgvector/pgvector)). Supabase documents automatic embeddings and pgvector-backed workflows ([Supabase automatic embeddings](https://supabase.com/docs/guides/ai/automatic-embeddings)). | Best when relational joins, tenant ACLs, transactions, and existing Postgres operations dominate. Validate query plans, filtered recall, index build/memory behavior, and embedding-worker retry/idempotency. |
| **Elasticsearch** | Native lexical, dense/sparse/vector, hybrid RRF, filters, semantic reranking, profiling, and ranking APIs ([hybrid search](https://www.elastic.co/docs/solutions/search/hybrid-search), [ranking](https://www.elastic.co/docs/solutions/search/ranking)). | Strong when the product already needs full-text search, analyzers, filters, facets, and operational search tooling. Model deployment and cluster sizing affect cost/latency. |
| **OpenSearch** | Hybrid search uses search pipelines with score normalization or rank fusion ([OpenSearch hybrid](https://docs.opensearch.org/latest/vector-search/ai-search/hybrid-search/index/)). | Open-source search stack with hybrid pipeline controls. Validate plugin/model compatibility and operational burden in the chosen distribution. |
| **Pinecone** | Serverless indexes use usage-based read/write/storage measures; namespaces support tenant partitioning; hybrid dense+sparse retrieval, hosted reranking, metadata filters, result limits, and eventual consistency are documented ([cost](https://docs.pinecone.io/guides/manage-cost/understanding-cost), [namespaces](https://docs.pinecone.io/guides/index-data/indexing-overview), [hybrid](https://docs.pinecone.io/guides/search/hybrid-search), [rerank](https://docs.pinecone.io/guides/search/rerank-results)). | Low infrastructure burden and managed scale. Account for eventual-consistency windows, per-operation cost, vendor data controls, and export/recovery strategy. |
| **Weaviate** | Supports keyword, vector, hybrid search, configurable fusion, reranking, multi-target vectors, filtering, and multi-tenancy ([search concepts](https://docs.weaviate.io/weaviate/concepts/search), [hybrid](https://docs.weaviate.io/weaviate/concepts/search/hybrid-search), [reranking](https://docs.weaviate.io/weaviate/concepts/reranking), [best practices](https://docs.weaviate.io/weaviate/best-practices)). | Good for a feature-rich vector database with hybrid and multi-tenant concepts. Test tenant lifecycle, filter semantics, module/version compatibility, and backup/restore. |
| **Chroma** | Collection query is dense nearest-neighbor search; it supports text/image query inputs, metadata filters, document search, and dense/sparse/hybrid retrieval in its current docs ([query/get](https://docs.trychroma.com/docs/querying-collections/query-and-get), [metadata filtering](https://docs.trychroma.com/docs/querying-collections/metadata-filtering), [project home](https://docs.trychroma.com/)). | Simple local/developer-friendly store and useful prototype surface. Confirm production durability, multi-tenancy, backup, scaling, and sparse/hybrid API behavior for the selected deployment mode. |
| **FAISS** | First-party library for efficient similarity search and clustering, with exact/approximate indexes, quantization, and optional GPU/ROCm support ([repository](https://github.com/facebookresearch/faiss), [index guide](https://github.com/facebookresearch/faiss/wiki/Guidelines-to-choose-an-index)). | Excellent embedded index library, not a complete multi-tenant database or ingestion/ACL service. The application must own persistence, metadata, filtering, updates, and observability. |
| **Vertex AI RAG Engine / Vertex AI Search** | RAG Engine manages corpora/files, chunking, retrieval, reranking, and Gemini generation; Google documents fixed chunking/overlap, managed DB choices, connectors, supported vector databases, and current security-control boundaries ([RAG quickstart](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/rag-quickstart?authuser=4), [transformations](https://cloud.google.com/vertex-ai/generative-ai/docs/fine-tune-rag-transformations?authuser=4), [reranking](https://cloud.google.com/vertex-ai/generative-ai/docs/retrieval-and-ranking?authuser=1), [security controls](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/security-controls), [Vertex AI Search](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/learn/vertex-ai-search)). | Attractive for GCP-native managed grounding and connectors. Confirm region, CMEK/VPC-SC/data-residency support for the exact RAG path; Google’s docs explicitly list unsupported controls and parser endpoint limitations. |
| **OpenAI Retrieval / File Search** | OpenAI vector stores automatically chunk, embed, and index files; current docs expose configurable static chunking, attributes and filters, hybrid ranking weights, score thresholds, expiration policies, supported file types, search results, and file citations ([Retrieval guide](https://developers.openai.com/api/docs/guides/retrieval), [File Search](https://developers.openai.com/api/docs/guides/tools-file-search), [Vector Stores reference](https://developers.openai.com/api/reference/resources/vector_stores)). | Fastest path when managed ingestion and OpenAI generation are acceptable. Treat vendor-managed parsing/chunking and retention as an external contract; keep source IDs/versioning in application metadata and verify deletion/privacy requirements. |

## 12. Production reliability, security, privacy, observability, cost, and latency

### 12.1 Reliability and recovery

Recommended reliability contract:

- **Idempotent ingestion:** source checksum + parser/model/chunk-policy version determines a derived-index key; retries must not duplicate chunks.
- **Partial failure visibility:** record per-file and per-stage states such as received, parsing, parsed, embedding, indexed, failed, stale, and deleted; make failed sources query-ineligible or clearly marked.
- **Versioned rebuilds:** build a new index generation, validate it, then atomically switch the read alias; retain the prior generation for rollback.
- **Freshness:** measure source-to-index lag and provider consistency windows. Pinecone explicitly documents eventual consistency ([search overview](https://docs.pinecone.io/guides/search/search-overview)); OpenAI exposes vector-store processing status and expiration ([Retrieval](https://developers.openai.com/api/docs/guides/retrieval)).
- **Timeout/fallback:** cap parser, embedding, retrieval, reranker, and generation time independently. If reranking times out, either return the first-stage result under a visible degraded status or abstain; do not silently pretend the full path ran.
- **Auditability:** persist source version, retrieval query, filters, candidate IDs, ranker/model versions, selected evidence, answer citations, and policy/validation results.

### 12.2 Security and privacy

RAG expands the trust boundary because untrusted files and retrieved text become model inputs. OWASP documents indirect prompt injection through websites/files, data/model poisoning, vector/embedding weaknesses, sensitive information disclosure, excessive agency, and unbounded consumption in its LLM Top 10 resources ([LLM01 prompt injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/), [2025 LLM Top 10 PDF](https://owasp.org/www-project-top-10-for-large-language-model-applications/assets/PDF/OWASP-Top-10-for-LLMs-v2025.pdf)).

Required controls are recommendations derived from those threats:

- authenticate and authorize every source and query; enforce ACL filters before retrieval and before response assembly;
- segregate retrieved content from system instructions and label it untrusted;
- validate parser outputs, URLs, archive paths, MIME types, decompression limits, and embedded links;
- scan and quarantine documents containing prompt-injection patterns or unexpected executable content, while recognizing that detection is not sufficient by itself;
- use least-privilege service accounts and keep credentials in code/tool handlers rather than exposing them to the model ([OWASP LLM01](https://genai.owasp.org/llmrisk/llm01-prompt-injection/));
- sign or hash source/index manifests and pin model/parser artifacts; OWASP identifies weak provenance and third-party supply-chain risk ([OWASP LLM03:2025](https://genai.owasp.org/llmrisk/llm032025-supply-chain/));
- redact or tokenize PII before telemetry and external parsing where policy requires it;
- define retention/deletion behavior for original files, parsed text, embeddings, traces, caches, backups, and provider-managed stores;
- test cross-tenant retrieval, deletion propagation, stale ACLs, malicious documents, prompt injection, and multimodal hidden instructions.

Managed services have distinct data policies. For example, LangSmith documents trace retention tiers, masking/conditional tracing, and deletion behavior ([LangSmith privacy](https://docs.langchain.com/langsmith/mask-inputs-outputs), [retention](https://docs.langchain.com/langsmith/data-purging-compliance)); OpenAI documents vector-store expiration and storage billing ([OpenAI Retrieval](https://developers.openai.com/api/docs/guides/retrieval)); Google documents RAG Engine security-control coverage and unsupported controls ([Vertex security controls](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/security-controls)). These are facts about each service, not interchangeable compliance guarantees.

### 12.3 Observability

Use traces that preserve the causal chain:

```text
request
  -> auth/filter decision
  -> query transform(s)
  -> each retriever call and candidate set
  -> fusion/rerank/parent expansion
  -> context assembly and token count
  -> generation/tool calls
  -> citation/groundedness/policy validation
  -> user-visible result or escalation
```

OpenTelemetry’s GenAI conventions provide standard attributes for retrieval queries and model operations ([GenAI conventions](https://opentelemetry.io/docs/specs/semconv/registry/attributes/gen-ai/)). LangSmith documents automatic and manual tracing, tags/metadata, production monitoring, and input/output masking ([observability](https://docs.langchain.com/langsmith/observability-concepts), [masking](https://docs.langchain.com/langsmith/mask-inputs-outputs)).

Recommended per-request fields: request/trace ID, tenant, source/index generation, query hash or redacted query, transformed-query hashes, filter hash, retriever names and versions, candidate counts, score distributions, fused ranks, reranker latency, selected source IDs, context token count, model/provider, input/output tokens, cache hit, retries/fallbacks, answer validation, citation coverage, and user/operator feedback. Avoid logging raw sensitive documents by default; trace IDs and stable hashes should support investigation without creating a second sensitive data lake.

### 12.4 Cost and latency

The cost stack is additive: parsing/OCR, embedding, index storage, query retrieval, reranking, generation tokens, telemetry, and reprocessing. OpenAI charges vector-store storage based on parsed chunks and embeddings and documents expiration; Pinecone documents usage-based serverless read/write/storage charges; LangSmith documents trace billing and retention ([OpenAI pricing in Retrieval](https://developers.openai.com/api/docs/guides/retrieval), [Pinecone cost](https://docs.pinecone.io/guides/manage-cost/understanding-cost), [LangSmith usage](https://docs.langchain.com/langsmith/administration-overview)).

Recommended latency budget:

1. parallelize independent lexical/dense retrieval;
2. retrieve a bounded candidate pool;
3. rerank only after filtering and deduplication;
4. expand parents only for selected children;
5. cap context tokens and avoid sending unused metadata/binary vectors;
6. cache immutable embeddings and safe query transformations;
7. batch ingestion and embedding work;
8. use exact search for small collections and ANN only when measured latency/scale justifies recall trade-offs;
9. measure p95/p99 and cold-start behavior, not only average latency.

## 13. Recommended reference design for a sensitive document product

This section is recommendation/inference, not a source-verified product decision.

1. **Canonical source layer:** immutable original file plus document/version manifest, owner/tenant/ACL, checksum, retention, and deletion state.
2. **Parser layer:** route digital PDFs through a deterministic parser; route scanned/layout-heavy files through a layout/OCR parser; preserve text, tables, images, page coordinates, and parser evidence.
3. **Representation layer:** start with structure-aware child chunks carrying heading/page metadata; retain parent links. Build dense and lexical indexes first. Add visual or late-interaction vectors only for measured failure classes.
4. **Query layer:** preserve the original question; apply bounded normalization and optional decomposition. Apply authorization and freshness filters before retrieval.
5. **Retrieval layer:** parallel BM25/sparse and dense retrieval; fuse with RRF; rerank a bounded candidate set; expand parent context only after ranking; return source IDs and locations.
6. **Answer layer:** instruct the generator to answer only from supplied evidence, cite source IDs, express uncertainty, and abstain when evidence is absent or conflicting. Validate citations and structured fields deterministically.
7. **Operations layer:** idempotent indexing, retry/dead-letter states, generation aliases, freshness dashboards, model/parser/chunk manifests, trace sampling/masking, cost budgets, and incident replay.

This architecture keeps the three layers distinct: model choice, pipeline control flow/validation, and data/configuration/provenance. Improving one layer does not establish correctness of the others.

## 14. Research and implementation checklist

- [ ] Define answerable question types, abstention policy, and citation contract.
- [ ] Inventory source formats, layout complexity, language, ACLs, retention, and update cadence.
- [ ] Select and version a canonical parser/document model.
- [ ] Benchmark structure-aware, recursive, and fixed-size chunk policies on a labeled corpus.
- [ ] Establish BM25 and exact vector-search baselines before approximate indexes.
- [ ] Compare dense, sparse, and hybrid retrieval with filtered recall and latency.
- [ ] Add reranking only after measuring candidate recall and candidate-pool size.
- [ ] Test parent-child expansion, duplicates, and context-token impact.
- [ ] Add multimodal retrieval only for questions whose evidence is visual or layout-dependent.
- [ ] Build retrieval and answer gold sets with expected source IDs and difficult negatives.
- [ ] Evaluate stale data, missing data, conflicting documents, malformed files, and authorization changes.
- [ ] Run prompt-injection, poisoning, PII, cross-tenant, and deletion-propagation tests.
- [ ] Instrument traces, cost, latency, retries, fallbacks, and source lineage.
- [ ] Record parser, embedding, ranker, generator, prompt, index, and chunk-policy versions in every answer trace.
- [ ] Re-test after every data/config/model change; treat configs and prompts as production code.

## 15. Source register

### Foundational papers and retrieval methods

- [RAG — Lewis et al. (2020)](https://arxiv.org/abs/2005.11401)
- [DPR — Karpukhin et al. (2020)](https://arxiv.org/abs/2004.04906)
- [SPLADE — Formal et al. (2021)](https://arxiv.org/abs/2107.05720)
- [ColBERT first-party repository](https://github.com/stanford-futuredata/ColBERT)
- [HyDE — Gao et al. (2022)](https://arxiv.org/abs/2212.10496)
- [Self-RAG — Asai et al. (2023)](https://arxiv.org/abs/2310.11511)
- [CRAG — Yan et al. (2024)](https://arxiv.org/abs/2401.15884)
- [RRF — Cormack, Clarke, and Buettcher (2009), ACM DOI](https://doi.org/10.1145/1571941.1572114)

### Parsing and chunking

- [Docling technical report](https://arxiv.org/abs/2408.09869)
- [Docling document model](https://docling-project.github.io/docling/concepts/docling_document/)
- [Unstructured partitioning](https://docs.unstructured.io/open-source/core-functionality/partitioning)
- [Unstructured chunking](https://docs.unstructured.io/open-source/core-functionality/chunking)
- [Microsoft MarkItDown repository](https://github.com/microsoft/markitdown)
- [Google Document AI layout parser](https://docs.cloud.google.com/document-ai/docs/layout-parse-chunk)
- [LangChain text splitters](https://docs.langchain.com/oss/python/integrations/splitters/index)
- [Haystack DocumentSplitter](https://docs.haystack.deepset.ai/docs/documentsplitter)

### Evaluation and embeddings

- [BEIR — Thakur et al. (2021)](https://arxiv.org/abs/2104.08663)
- [MTEB — Muennighoff et al. (2022)](https://arxiv.org/abs/2210.07316)
- [RAGAS — Es et al. (2023)](https://arxiv.org/abs/2309.15217)
- [BRIGHT reasoning-intensive retrieval benchmark](https://arxiv.org/abs/2407.12883)
- [OpenAI embeddings guide](https://developers.openai.com/api/docs/guides/embeddings)
- [Sentence Transformers documentation](https://sbert.net/)

### Multimodal and document RAG

- [MuRAG — Chen et al. (2022)](https://arxiv.org/abs/2210.02928)
- [M3DocRAG — Cho et al. (2024)](https://arxiv.org/abs/2411.04952)
- [Docling technical report](https://arxiv.org/abs/2408.09869)
- [Qdrant multivectors](https://qdrant.tech/documentation/concepts/vectors/#multivectors)

### Frameworks, databases, and managed platforms

- [LangChain retrieval](https://docs.langchain.com/oss/python/langchain/retrieval)
- [LangGraph agentic RAG](https://docs.langchain.com/oss/python/langgraph/agentic-rag)
- [LangSmith observability](https://docs.langchain.com/langsmith/observability-concepts)
- [LlamaIndex node parsers](https://docs.llamaindex.ai/en/v0.10.18/module_guides/loading/node_parsers/modules.html)
- [Haystack documentation](https://docs.haystack.deepset.ai/)
- [Qdrant hybrid queries](https://qdrant.tech/documentation/search/hybrid-queries/)
- [pgvector first-party repository](https://github.com/pgvector/pgvector)
- [Supabase automatic embeddings](https://supabase.com/docs/guides/ai/automatic-embeddings)
- [Elasticsearch hybrid search](https://www.elastic.co/docs/solutions/search/hybrid-search)
- [OpenSearch hybrid search](https://docs.opensearch.org/latest/vector-search/ai-search/hybrid-search/index/)
- [Pinecone hybrid search](https://docs.pinecone.io/guides/search/hybrid-search)
- [Pinecone search overview](https://docs.pinecone.io/guides/search/search-overview)
- [Weaviate search concepts](https://docs.weaviate.io/weaviate/concepts/search)
- [Chroma query/get](https://docs.trychroma.com/docs/querying-collections/query-and-get)
- [FAISS first-party repository](https://github.com/facebookresearch/faiss)
- [Vertex AI RAG Engine quickstart](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/rag-quickstart?authuser=4)
- [Vertex AI RAG transformations](https://cloud.google.com/vertex-ai/generative-ai/docs/fine-tune-rag-transformations?authuser=4)
- [Vertex AI RAG reranking](https://cloud.google.com/vertex-ai/generative-ai/docs/retrieval-and-ranking?authuser=1)
- [OpenAI Retrieval](https://developers.openai.com/api/docs/guides/retrieval)
- [OpenAI File Search](https://developers.openai.com/api/docs/guides/tools-file-search)
- [OpenAI Vector Stores reference](https://developers.openai.com/api/reference/resources/vector_stores)

### Reliability, security, privacy, observability

- [OWASP LLM01:2025 Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/)
- [OWASP LLM03:2025 Supply Chain](https://genai.owasp.org/llmrisk/llm032025-supply-chain/)
- [NIST AI RMF Generative AI Profile](https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.600-1.pdf)
- [OpenTelemetry GenAI semantic conventions](https://opentelemetry.io/docs/specs/semconv/registry/attributes/gen-ai/)
- [LangSmith data masking](https://docs.langchain.com/langsmith/mask-inputs-outputs)
- [LangSmith data purging](https://docs.langchain.com/langsmith/data-purging-compliance)
- [Vertex AI security controls](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/security-controls)

## Anything else?

Yes: the most consequential RAG decision is not “which vector database?” It is whether the system has a durable, versioned, access-controlled evidence contract from original source through user-visible citation. If that contract is absent, database swaps, larger models, and better prompts can improve demos while making failures harder to explain. The next decision unit should therefore be the corpus-specific evidence and evaluation contract; platform selection should follow its retrieval, privacy, latency, and operational requirements.
