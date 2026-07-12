# CoverWise Long-Term Platform Decision

**Date:** 2026-07-12  
**Status:** canonical decision  
**Decision owner:** Pranay  
**Launch target:** late July 2026

## Decision

Use a **single Cloud Run FastAPI application service** backed by **one Supabase project**:

- **Cloud Run:** the only application runtime. It serves the marketing site, upload API, document processing, retrieval, and Q&A.
- **Supabase Postgres:** the canonical database for users/sessions, documents, processing state, policy sections, chunks, evidence, feedback, and embeddings through `pgvector`.
- **Supabase Storage:** the canonical durable store for original policy documents and derived artifacts.
- **Supabase Auth:** optional at launch; enable when accounts and cross-device document history are required.
- **OpenAI/Hugging Face:** external model/API dependencies only.

Remove Redis and Qdrant from the production path. Keep local adapters and compatibility code until the migration has passed its cutover acceptance criteria.

## Why this is the first-principles choice

The product is not fundamentally a vector-search demo. It is a document system with trustworthy retrieval. The durable domain objects are:

```text
owner -> document -> versions -> pages/sections -> chunks -> evidence -> answers
```

That structure benefits from relational constraints, transactions, joins, migrations, SQL reporting, and explicit deletion. `pgvector` keeps semantic search next to the metadata it must filter and cite. Postgres is also portable: the schema and SQL can move to another managed Postgres provider or self-hosted Postgres without rewriting the product around a proprietary document API.

This is a better long-term boundary than Firestore for this product, while still keeping operational pieces small:

```text
User / mobile app / browser
              |
       HTTPS custom domain
              |
     Cloud Run: CoverWise API
              |
       Supabase project
       |                 |
   Postgres + pgvector  Storage buckets
       |
   OpenAI/Hugging Face
```

## Why not Firestore as the canonical database

Firestore vector search is technically viable and supports the current embedding dimension. It was evaluated seriously and is preserved in [`coverwise_platform_architecture_decision_2026-07-12.md`](coverwise_platform_architecture_decision_2026-07-12.md).

It is not selected because:

- Policy ownership, document versions, evidence references, and processing state are naturally relational.
- Firestore's document and index billing model is less predictable for chunk-heavy RAG workloads; vector index entries are separately billable reads.
- The application would be more coupled to Firestore query/index semantics.
- Cloud Storage would still be a separate data primitive.

Firestore remains a valid future choice if the product becomes a high-volume, document-oriented Firebase application with realtime client synchronization as a primary requirement.

## Why Supabase/Postgres over other Postgres options

Supabase gives us one managed backend surface for Postgres, `pgvector`, file storage, authentication, database backups on paid plans, and operational UI. It keeps the important data in a standard Postgres schema rather than a provider-specific vector API.

Supabase Free is useful for development but pauses inactive projects and does not include automatic backups. Production should use the paid plan only when the product accepts real customer documents; the current listed Pro price is $25/month before any extra usage or add-ons. This is a deliberate, visible baseline rather than a hidden collection of free-tier limits.

## Options explored

| Option | Data model | Operational pieces | Long-term fit | Decision |
|---|---|---:|---:|---|
| Supabase Postgres + pgvector + Storage | Relational plus vectors and blobs | Cloud Run + one backend project | Strong; portable and product-aligned | **Chosen** |
| Firebase/Firestore + Cloud Storage | Document plus vector indexes and blobs | Cloud Run + Google data services | Strong scale, more vendor-specific query semantics | Rejected for now; preserved alternative |
| Neon Postgres + pgvector | Relational plus vectors | Cloud Run + Neon + separate object storage/auth | Good database, more providers to assemble | Deferred |
| Managed Qdrant + SQL database | Best-of-breed vector plus relational store | Runtime + SQL + Qdrant + blob store | Strong at large retrieval scale, unnecessary now | Rejected for launch |
| Pinecone + SQL database | Dedicated serverless vector system | Runtime + SQL + Pinecone + blob store | Good at vector scale, expensive/extra seam for this wedge | Rejected for launch |
| Single VPS with Postgres/pgvector/Storage | All self-managed | One server, but we own operations | Cheap and portable, poor solo operational tradeoff | Rejected for launch |
| SQLite/FAISS/LanceDB inside Cloud Run | Local embedded state | Few components | Unsafe with scale-to-zero, redeploys, and multiple instances | Rejected |
| Railway current Compose stack | Existing services unchanged | Five service/state seams | Fastest short-term, creates later migration | Temporary fallback only |

## Cost and scale reasoning

The target has one always-relevant runtime and one backend vendor rather than five independently operated services:

- Cloud Run scales application compute with demand.
- Supabase Free is suitable for development; production starts with the smallest paid database/storage footprint that supports retention and backups.
- Model/API usage is separately metered and bounded.
- There is no Redis bill until measured traffic justifies a cache.
- There is no dedicated vector-database bill until the dataset/query profile justifies one.

Supabase's current published Pro baseline is $25/month and includes daily backups retained for seven days; additional storage, egress, compute, or users can add cost. That is more than a free-tier prototype, but it buys a durable database/storage boundary and avoids a second migration when the product gains real users.

The cost-control policy is explicit:

- Set a hard monthly budget alert before production.
- Cap file size, page count, chunk count, top-k, question length, and retries.
- Measure Postgres query latency, index size, storage bytes, model cost, and Cloud Run memory.
- Do not add Redis, Pinecone, Qdrant, a queue, or a second runtime based on speculation.

## Canonical schema direction

### `profiles` or anonymous owner sessions

Identity and consent boundary. Anonymous beta sessions can be supported without pretending they are full accounts.

### `documents`

- `id`, `owner_id`, `source_hash`, `status`, `content_type`.
- `storage_path`, `page_count`, safe size bucket.
- `created_at`, `updated_at`, `expires_at`, `deleted_at`.
- `processing_version`, `failure_class`, `retryable`.

### `document_chunks`

- `id`, `document_id`, `page_number`, section/source references.
- `content` or controlled derived-text reference.
- `embedding vector(1536)` for `text-embedding-3-small`.
- `embedding_model`, `chunk_version`, timestamps.
- HNSW cosine index after representative data is loaded.

### `questions` and `answers`

- `document_id`, owner/session reference, status, timestamps.
- Evidence chunk IDs and page references.
- Model/provider/version metadata.
- Safe latency and failure fields.

Raw document text, questions, and answers must not be sent to marketing analytics or ordinary application logs.

## Processing and reliability contract

1. Validate file type, size, page count, and content hash.
2. Create one document row with `received` state.
3. Upload the original to a private Storage bucket.
4. Claim processing with a transaction/locked state transition.
5. Extract text and source/page references.
6. Chunk, embed, and insert using bounded batches.
7. Mark `ready` only after every required write succeeds.
8. On error, record a safe class and whether retry is allowed.
9. Query only `ready` documents owned by the current session/user.
10. Delete the document row, descendants, and Storage object through one auditable deletion workflow.

Retries must be idempotent. A repeated request with the same owner and source hash must reuse or supersede the same logical document version rather than create uncontrolled duplicates.

## Migration stages

### Stage 0: freeze the contract

- Keep current HTTP routes and user-facing behavior stable.
- Add a repository boundary for documents, chunks, vectors, and cache/rate-limit behavior.
- Record the current Qdrant/Redis data shapes and migration assumptions.

### Stage 1: implement Supabase adapters

- Add schema migrations for the tables above.
- Add private Storage buckets and object lifecycle rules.
- Add Python Postgres access through a pooled connection or Supabase API boundary.
- Add pgvector similarity search filtered by `document_id` and owner/session.
- Add tests for transactions, duplicate uploads, partial writes, deletes, and stale states.

### Stage 2: single-runtime path

- Move frontend, OCR, extraction, ingestion, and query execution behind one FastAPI process.
- Keep modules separated by responsibility but remove mandatory service-to-service HTTP calls in production.
- Use Cloud Run's injected `PORT`; remove `--reload` in production.
- Add `/healthz`, `/readyz`, structured safe logs, and bounded request timeouts.

### Stage 3: shadow and cutover

- Process a fixed representative document set through both current and target paths.
- Compare extracted fields, chunk counts, retrieval evidence, answer citations, latency, and failure classifications.
- Run duplicate/retry/delete tests against the target path.
- Cut over only after acceptance criteria pass.

### Stage 4: retire old infrastructure

- Mark Qdrant/Redis adapters historical.
- Preserve migration scripts and evidence in the archive.
- Do not delete old code or data until retention, rollback, and recovery windows expire.

## Risks and mitigations

| Risk | Mitigation | Revisit trigger |
|---|---|---|
| pgvector index recall/latency | HNSW, filtered queries, exact-search benchmark, `EXPLAIN ANALYZE` | Retrieval quality or p95 latency misses target |
| Postgres connection exhaustion | Supabase pooler, bounded concurrency, connection health checks | Cloud Run scale-out creates pressure |
| Long OCR requests | Tight limits first; move work to Cloud Run Jobs/Tasks only when measured | Repeated timeout or user-visible partial state |
| Sensitive file retention | Private buckets, object expiry, audited deletion, policy alignment | Any deletion mismatch |
| Vendor dependency | Standard Postgres schema, SQL migrations, Storage export path | Compliance, pricing, or residency change |
| Supabase project pause/free limits | Paid production plan and budget alerts | Real-user data accepted |

## Acceptance criteria

- One Cloud Run application service handles the full user flow.
- Production retrieval uses Postgres `pgvector`, not Qdrant.
- Production persistence uses Supabase Postgres and Storage, not local disk.
- Redis is not required for correctness.
- Upload, processing, query, retry, timeout, duplicate, and deletion flows are tested.
- Every answer can identify source/page evidence.
- No raw customer document content enters analytics or ordinary logs.
- Database backups, Storage retention, and deletion behavior are verified.
- The old AWS, Railway, Firestore, Qdrant, and Redis decisions remain preserved and clearly marked superseded where applicable.

## Evidence and references

- [Supabase pricing](https://supabase.com/pricing)
- [Supabase vector columns with pgvector](https://supabase.com/docs/guides/ai/vector-columns)
- [Supabase database overview and backups](https://supabase.com/docs/guides/database/overview)
- [Supabase Storage](https://supabase.com/docs/guides/storage)
- [pgvector project documentation](https://github.com/pgvector/pgvector)
- [Cloud Run pricing](https://cloud.google.com/run/pricing)
