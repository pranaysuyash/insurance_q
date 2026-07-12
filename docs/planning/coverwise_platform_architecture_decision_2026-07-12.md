# Superseded: CoverWise Platform Architecture Decision

**Date:** 2026-07-12  
**Status:** superseded on 2026-07-12 by [`coverwise_long_term_platform_decision_2026-07-12.md`](coverwise_long_term_platform_decision_2026-07-12.md); preserved as the Firestore alternative  
**Decision owner:** Pranay  
**Target launch:** late July 2026

> This document records the Firestore/Cloud Storage option that was evaluated
> before the `pgvector` comparison was completed. It remains useful as an
> alternative and migration reference, but agents must follow the Supabase +
> Postgres/pgvector decision in the linked canonical document.

## Decision summary

Build and deploy CoverWise as **one Python/FastAPI Cloud Run service** backed by two Google-managed data primitives:

1. **Cloud Run:** the only application runtime. It serves the marketing page, upload API, document processing, policy extraction, retrieval, and Q&A.
2. **Cloud Storage:** durable storage for original uploads and derived file artifacts.
3. **Cloud Firestore:** metadata, processing state, policy sections/chunks, embeddings, feedback, and operational records. Firestore vector search replaces Qdrant.

Firebase is the product umbrella, not a requirement to use every Firebase product. Firebase Hosting may be added later for a separately deployed static marketing site, but the current FastAPI app can serve the marketing page directly. Firebase Auth, Analytics, App Check, and Crashlytics are optional additions only when a real product requirement exists.

Redis is removed from the target architecture. Cache and rate-limit behavior starts in-process with bounded safeguards; a managed cache is added only after measured traffic proves it is needed.

## First-principles reasoning

The product's durable value is not the number of services. It is the trustworthy loop:

```text
Policy document -> grounded extraction -> source-aware retrieval -> understandable answer
```

The platform should therefore minimize:

- Number of deployable services.
- Number of stateful systems.
- Number of credentials and billing surfaces.
- Number of data migrations.
- Number of places where retention and deletion must be implemented.
- Number of independent failure modes an operator must understand.

The target has one runtime, one metadata/search system, and one blob store. It can scale horizontally without putting state on the container filesystem.

## Why Cloud Run is the runtime

- It runs the existing Python container without a framework rewrite.
- It scales instances with demand and can scale to zero when idle.
- It supports request timeouts up to 60 minutes, which gives room for a bounded synchronous first release while leaving a path to asynchronous processing.
- It requires the container to listen on the injected `PORT`, making the production contract explicit.
- It keeps the deployment unit portable as an OCI container.

Cloud Run request timeouts are not a substitute for job orchestration. Upload processing must have a bounded timeout and an idempotent document state machine. If processing becomes long-running, the next stage is a Cloud Run Job or Cloud Tasks, not another permanent microservice.

## Why Firestore replaces Qdrant and Redis

Firestore supports K-nearest-neighbor vector search, pre-filtering, and the Python client library. Its maximum supported embedding dimension is 2048, which is compatible with the current 1536-dimensional `text-embedding-3-small` choice.

Firestore becomes the canonical record for:

- Document identity and ownership.
- Processing status and failure reason.
- Policy metadata and structured fields.
- Text chunks and source/page references.
- Embedding vectors.
- User questions and answer evidence references.
- Feedback and support events.

This removes the need to synchronize metadata in one store, chunks in another, and cache state in a third. Firestore vector-search reads are billable, so query limits and index-cost measurement are part of the implementation rather than an afterthought.

## Why Cloud Storage holds documents

Original PDFs/images should not be stored in Firestore documents. Cloud Storage is the durable blob layer and supports lifecycle/retention policies, object metadata, and deletion workflows. The application stores only a storage object reference and controlled metadata in Firestore.

## Target architecture

```text
User / mobile app / browser
              |
       HTTPS custom domain
              |
     Cloud Run: CoverWise API
       |        |          |
       |        |          +--> OpenAI APIs (chat + embeddings)
       |        |
       |        +--> Firestore (state + chunks + vectors + evidence)
       |
       +--> Cloud Storage (originals + derived artifacts)
```

## Canonical data model

### `documents/{document_id}`

- `owner_id` or anonymous session reference.
- `storage_object` and content type.
- `status`: `received`, `processing`, `ready`, `failed`, `deleted`.
- `source_hash` for duplicate detection.
- `page_count` and safe size buckets.
- `created_at`, `updated_at`, `expires_at`.
- `failure_class` and retryability, when failed.

### `documents/{document_id}/chunks/{chunk_id}`

- `text` or a controlled reference to encrypted derived text.
- `embedding` vector.
- `page_number`, section heading, and source span.
- `chunk_version` and `embedding_model`.
- `created_at`.

### `documents/{document_id}/questions/{question_id}`

- Question hash or redacted question reference.
- Answer status and bounded answer payload.
- Evidence chunk IDs and page references.
- Model/provider metadata needed for investigation.
- Latency bucket and failure class.

Do not log or emit raw policy text, raw OCR, questions, or answers to analytics. Retention rules must apply to both Cloud Storage objects and Firestore descendants.

## Processing contract

1. Validate MIME type, size, page limit, and content hash.
2. Create an idempotent Firestore document with `received` state.
3. Store the original object in Cloud Storage.
4. Transition to `processing` using a transaction or compare-and-set guard.
5. Extract text using the supported pipeline and record source/page references.
6. Create structured chunks and embeddings.
7. Write chunks and vector fields to Firestore in bounded batches.
8. Transition to `ready` only after all required writes succeed.
9. On failure, record a safe failure class, retryability, and operator-visible timestamp.
10. Query only `ready` documents and return evidence references with the answer.

Retries must be safe: a repeated upload request with the same owner and source hash must not create uncontrolled duplicate state. A retry after a partial write must resume or replace the same version, not silently mix versions.

## Implementation stages

### Stage 1: make the pipeline single-runtime compatible

- Extract reusable OCR, extraction, ingestion, and query functions from service-bound networking assumptions.
- Keep existing HTTP routes as compatibility adapters during migration.
- Add a storage/repository interface with Firestore as the production implementation and an in-memory/local implementation for tests.
- Remove `--reload` from production commands.
- Add explicit `/healthz` and `/readyz` behavior.

### Stage 2: Firestore and Cloud Storage adapters

- Implement document state and chunk repositories.
- Implement Cloud Storage upload, read, expiry, and deletion operations.
- Implement Firestore vector index creation and bounded nearest-neighbor queries.
- Add migrations/import tooling from current Qdrant/Redis state where needed.
- Do not delete the old adapters until migration evidence exists.

### Stage 3: one-service runtime

- Run the frontend, OCR, and RAG logic in one Cloud Run container.
- Keep service-specific modules for code ownership, but remove mandatory service-to-service HTTP calls in the production path.
- Use dependency injection/configuration to select Firestore/Cloud Storage in production and local backends in development.
- Set concurrency and memory based on real upload/query measurements.

### Stage 4: release and cleanup

- Run representative digital PDFs and supported image/scanned documents.
- Verify duplicate upload, retry, timeout, malformed file, partial write, deletion, and stale state behavior.
- Run a controlled migration and compare answer evidence against the current path.
- Mark Qdrant/Redis adapters historical only after production cutover evidence.

## Options considered

| Option | Strength | Weakness | Decision |
|---|---|---|---|
| Current Compose split | Minimal immediate code change | Five runtime/stateful pieces and more failure seams | Not target architecture |
| Railway with current services | Fastest deployment | Preserves unnecessary service complexity and future migration cost | Temporary only, no longer canonical |
| Railway single container + embedded state | Simple bill | Unsafe persistence and poor horizontal scaling | Rejected |
| Render multi-service | Easy UI deployment | Cost and service count grow with current topology | Rejected |
| Single VPS + Compose | Lowest fixed compute cost | We own patching, backups, monitoring, recovery, and scaling | Rejected for launch |
| Firebase App Hosting | Strong Firebase integration | Primary support is Next.js/Angular, not FastAPI | Rejected as runtime |
| Firebase Hosting + Cloud Run + Firestore + Storage | One Google ecosystem, pay-per-use, durable data path, scalable | Requires a deliberate repository/data migration and Blaze billing | Historical choice in this superseded proposal |
| Supabase + hosted app | Postgres, storage, auth, and pgvector in one backend | Adds a second vendor and a SQL migration; current app is not relationally shaped | Deferred alternative |

## Cost model

The target has usage-based components rather than five always-on services:

- Cloud Run: request/compute usage, with a no-cost tier subject to current Google Cloud terms.
- Firestore: document reads/writes/deletes, vector index reads, storage, and network usage.
- Cloud Storage: stored bytes, operations, and network usage.
- OpenAI/Hugging Face: model/API usage.

This is not a claim of zero cost. It is a claim that idle product usage does not require paying for multiple continuously running services. Budget alerts, maximum file/page/query limits, and usage dashboards are mandatory before accepting real customer documents.

## Risks and mitigations

| Risk | Mitigation | Exit/revisit trigger |
|---|---|---|
| Firestore vector cost grows with index reads | Limit top-k, pre-filter by document, measure Query Explain/index reads | Sustained cost or latency above budget |
| Synchronous upload exceeds request timeout | Bound processing; move to Cloud Run Job/Cloud Tasks | Any repeated timeout or user-visible partial state |
| OCR memory makes instances expensive | Separate direct-text and OCR paths; measure memory; process pages in bounds | Memory pressure or queue growth |
| Cloud Run scale-out races on state | Firestore transactions, idempotency keys, no local durable state | Duplicate or mixed document versions |
| Sensitive data retention is unclear | Central expiry/deletion workflow across Firestore and Storage | Any unverified deletion path |
| Vendor concentration | Keep repository interfaces and OCI container; export data model | Compliance, pricing, or residency requirement |

## Decision consequences

### Positive

- One deployable application runtime.
- One canonical metadata/search system.
- No always-on Redis requirement.
- No separate vector database operations.
- Scale-to-zero and horizontal scaling are available.
- Firebase capabilities can be added without changing the core runtime.

### Negative

- This is more code change than deploying the existing Compose stack.
- Firestore vector search has different query and billing semantics than Qdrant.
- The team must implement explicit data retention, idempotency, and migration logic.
- Cloud Run cold starts and request limits require bounded processing.

## Acceptance criteria before calling the migration complete

- Local development still works without cloud credentials.
- Production uses only the one Cloud Run application service plus Firestore and Cloud Storage.
- No production request depends on Redis or Qdrant.
- A document can be uploaded, processed, queried, and deleted end to end.
- Repeated upload and retry behavior is idempotent.
- Answers include evidence references tied to stored source/page metadata.
- Raw policy data is absent from analytics and ordinary application logs.
- Firestore and Storage retention/deletion behavior is tested.
- Cloud Run health, timeout, memory, and error metrics are visible.
- The old deployment path is preserved in archive docs and clearly marked superseded.

## Source references

- [Cloud Run container runtime contract](https://docs.cloud.google.com/run/docs/container-contract)
- [Cloud Run pricing](https://cloud.google.com/run/pricing)
- [Firestore vector search](https://firebase.google.com/docs/firestore/vector-search)
- [Firestore pricing and vector index reads](https://firebase.google.com/docs/firestore/pricing)
- [Cloud Storage pricing](https://cloud.google.com/storage/pricing)
