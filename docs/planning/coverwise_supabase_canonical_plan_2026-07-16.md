# CoverWise canonical platform plan

**Date:** 2026-07-16  
**Status:** canonical planning baseline; implementation audit in progress  
**Decision owner:** Pranay

## One decision

CoverWise will use **managed Supabase as its canonical backend**:

- Supabase Auth for anonymous identity, account identity, session lifecycle,
  and account linking.
- Supabase PostgreSQL for all durable product and operational metadata.
- PostgreSQL `pgvector` for semantic retrieval, alongside PostgreSQL full-text
  search and structured filters.
- A private Supabase Storage bucket for original documents and derived files.
- One Cloud Run FastAPI application for API, extraction, ingestion, retrieval,
  Q&A, authorization, and operator-visible state.
- External model providers only for model execution; model outputs remain
  versioned product data with provenance, validation, and evaluation records.

This is the long-term source of truth even while local adapters remain for
development, migration rehearsal, and rollback evidence.

## Why this is the product architecture

CoverWise exists to help people understand the policies they already own. The
core loop is not generic mobile CRUD and not a vector-search demo:

```text
original policy
  -> document version
  -> extraction and normalization
  -> structured policy facts
  -> source-aware chunks
  -> hybrid retrieval
  -> evidence-backed explanation
  -> feedback and evaluation
  -> permissioned quality improvement
```

The durable domain is relational:

```text
owner -> policy -> document version -> page/section -> chunk -> evidence -> answer
```

PostgreSQL gives this domain one queryable system for ownership, versions,
consent, processing state, structured fields, full-text search, vector search,
evidence joins, deletion, audit, and bulk export. It also keeps the data model
portable to another PostgreSQL provider or self-hosted PostgreSQL later.

## Canonical architecture

```text
Flutter mobile client
  |  Supabase Auth session + HTTPS API calls
  v
Cloud Run: FastAPI
  |-- verified identity and authorization
  |-- upload and processing state machine
  |-- OCR/extraction/normalization
  |-- hybrid retrieval: SQL FTS + pgvector + structured filters
  |-- answer generation and evidence validation
  |-- safe logs, audit events, metrics, operator state
  |
  +--> Supabase PostgreSQL + pgvector
  |      product, retrieval, feedback, consent, evaluation metadata
  |
  +--> Supabase private Storage
         original PDFs/images and controlled derived artifacts
  |
  +--> model providers
         extraction, embeddings, reranking, answer generation
```

The mobile client must not become a second processing or retrieval pipeline.
The backend remains the policy/data boundary even where on-device OCR assists
an upload.

## Canonical data layers

### Product and ownership data

- `auth.users` / Supabase Auth identity.
- `profiles` for safe account metadata.
- `policies` for the user-facing insurance object.
- `policy_members` or household relationships.
- `documents` for each uploaded source and processing lifecycle.
- `document_versions` for replacement/re-upload history.
- `document_artifacts` for source and derived Storage objects.

### Retrieval data

- `document_pages` with page boundaries and extraction method.
- `document_sections` with section hierarchy.
- `document_chunks` with canonical text, source references, chunk version,
  embedding model, and `vector(1536)` or the active model dimension.
- PostgreSQL full-text generated/indexed representation.
- `retrieval_runs`, `retrieval_candidates`, and `answer_evidence` for audit and
  evaluation without placing raw sensitive content in ordinary analytics.

### Quality and future model-training data

Customer documents are service data first, not training data by default.

Create a separate permissioned layer:

- `consents` with purpose, version, timestamp, withdrawal, and scope.
- `corrections` with reviewer/source provenance.
- `evaluation_sets` and `evaluation_samples` with expected fields/evidence.
- `dataset_releases` with inclusion rules, transformations, version, expiry,
  and owner approval.
- `training_artifacts` with lineage to the dataset release and model run.

Raw customer files, raw OCR, questions, answers, and embeddings must not enter
shared training or marketing analytics implicitly.

## Retrieval architecture

The target is hybrid and structured, not vector-only:

1. Validate the authenticated owner and document scope.
2. Resolve structured fields first when the query maps to known policy facts.
3. Run PostgreSQL full-text search for exact terms, exclusions, clause names,
   policy numbers, amounts, and dates.
4. Run pgvector similarity search over source-aware chunks.
5. Merge/rerank candidates with a recorded retrieval run.
6. Generate an answer only from accepted evidence.
7. Return source/page references and explicit missing-information states.

Retrieval quality must be evaluated separately from answer quality. The system
must be able to say whether the failure was missing extraction, poor chunking,
poor retrieval, weak reranking, unsupported synthesis, or unavailable model
execution.

## Processing architecture

The canonical state machine is:

```text
received -> stored -> processing -> extracted -> indexed -> ready
                                      |              |
                                      +-> failed <---+
```

Requirements:

- owner-scoped idempotency by source hash and document version;
- private object write before durable metadata claims the source is stored;
- bounded OCR, extraction, embedding, and batch writes;
- lease/claim semantics for retries and scale-out;
- safe failure class and retryability;
- deletion propagation across Storage, metadata, chunks, evidence, caches,
  analytics, and permissioned datasets;
- operator-visible state transitions and recovery actions.

## Auth and authorization

Supabase Auth is required for the durable account path. Anonymous access is a
Supabase Auth anonymous user that can be linked to an account; it is not a
second custom identity system. Every policy-bearing route derives ownership
from the verified token, never from a caller-provided `user_id`, email, or
session ID.

The authorization boundary remains FastAPI because it owns document processing,
retrieval, and sensitive operational workflows. Supabase Row Level Security
must still protect direct database/storage access where enabled.

## Operational decision

Use managed Supabase for production. Self-hosting is a future deployment option,
not the current architecture. The schema, SQL migrations, storage paths, and
repository interfaces must remain portable enough to support that option later.

## Implementation phases

### Phase A — contract and schema

- Freeze the canonical table/object/state contracts.
- Replace the current document-only schema with explicit policy, version,
  page/section/chunk, retrieval, evidence, consent, and dataset contracts.
- Define retention/deletion and provenance fields before writing more data.

### Phase B — canonical repository and retrieval

- Implement Supabase repositories for product metadata and processing state.
- Implement pgvector plus PostgreSQL full-text retrieval.
- Remove correctness dependence on Qdrant, SQLite FTS, local disk, Redis, or
  in-memory state.
- Keep adapters only for local development or controlled migration comparison.

### Phase C — auth and user ownership

- Use Supabase Auth anonymous users and account linking.
- Transfer existing anonymous ownership through a verified, idempotent flow.
- Add account deletion/export and session/device recovery contracts.

### Phase D — quality and training readiness

- Persist retrieval runs and answer evidence.
- Add evaluation-set versioning and failure taxonomy.
- Add consent-aware correction and dataset-release workflows.
- Prove that customer data cannot enter training artifacts without explicit
  permitted purpose.

### Phase E — production cutover

- Run representative real-document comparisons against the target path.
- Verify duplicate, retry, partial failure, timeout, deletion, and recovery.
- Verify backup restore, Storage recovery, auth recovery, and operator access.
- Cut over only after Tier 3+ evidence.

## What this plan deliberately does not decide yet

- Which embedding/reranker/LLM provider wins the benchmark.
- Whether long-running processing needs Cloud Tasks or Cloud Run Jobs.
- Paid product entitlements and billing.
- MFA, social login, or enterprise SSO.
- Whether any customer-derived data may ever enter a training corpus.

Those are downstream decisions. They must not create a second canonical data,
auth, retrieval, or consent path.
