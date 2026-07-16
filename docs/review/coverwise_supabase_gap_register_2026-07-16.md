# CoverWise Supabase canonical gap register

**Date:** 2026-07-16  
**Baseline:** [`coverwise_supabase_canonical_plan_2026-07-16.md`](../planning/coverwise_supabase_canonical_plan_2026-07-16.md)  
**Audit type:** repository architecture and implementation audit  
**Status:** gaps documented; implementation intentionally not started in this pass

## Decision boundary

The target is managed Supabase with PostgreSQL/pgvector, private Storage,
Supabase Auth, and one FastAPI pipeline. This register compares the current
repository with that target. Existing local/Qdrant/SQLite code is preserved as
migration evidence, but it is not accepted as production truth.

## Summary

| Priority | Area | Current state | Gap |
|---|---|---|---|
| P0 | Supabase schema | `documents` and `document_chunks` exist | Missing canonical policy/version/page/section/question/evidence/consent/dataset model |
| P0 | Production retrieval | Supabase dense RPC exists | No Supabase full-text search; exact lookup and hybrid fallback still depend on local SQLite FTS |
| P0 | Embedding contract | Schema fixed at 1536 dimensions | Runtime fallback changes dimensions and still contains Qdrant recreation logic; model/version compatibility is not enforced |
| P0 | Processing state | Repository leases exist | Processing service still owns in-memory status and local directories; end-to-end state is not one durable state machine |
| P1 | Retrieval auditability | Answers return sources/citations in API payloads | No durable retrieval run, candidate, evidence, model, or latency records |
| P1 | Training readiness | Policy/training docs and static eval code exist | No implemented consent-aware dataset registry, release, lineage, or deletion propagation |
| P1 | Auth lifecycle | Anonymous/account path exists locally | No production provider verification, password recovery, deletion/export, or full account-flow evidence |
| P1 | Analytics/rate limits | SQLite/in-memory/optional Redis paths exist | Production observability and abuse controls are not on the canonical Supabase data plane |
| P1 | Storage lifecycle | Private Supabase Storage adapter exists | Retention, derived-artifact inventory, restore, and complete deletion evidence are incomplete |
| P2 | Migration/cutover | Supabase adapters coexist with Qdrant/SQLite | No representative corpus comparison, backfill, rollback checkpoint, or retirement gate |
| P2 | Tests | Local adapter tests exist | No Supabase integration/RLS/RPC/retrieval benchmark suite |

## P0 gaps

### 1. Canonical schema is too narrow

Evidence: [`infra/supabase/001_coverwise_schema.sql`](../../infra/supabase/001_coverwise_schema.sql)
creates `documents` and `document_chunks`, with most document state serialized
inside `payload` JSONB.

Missing durable objects required by the target plan:

- policy and policy-version identity;
- pages and section hierarchy;
- extraction runs and normalized field values;
- questions, answers, and answer evidence;
- retrieval runs and candidates;
- consent/purpose/withdrawal ledger;
- evaluation samples and dataset releases;
- object/artifact inventory and deletion state.

Risk: the product will continue to treat serialized payloads and process-local
objects as truth, making SQL retrieval, reporting, correction, deletion, and
future training lineage incomplete.

Closure criteria: versioned migrations define these contracts, ownership and
foreign keys are explicit, JSON is reserved for flexible metadata, and every
production read/write path has a repository or SQL function with tests.

### 2. Production retrieval is dense-only, not hybrid

Evidence: [`src/services/supabase_vector_store.py`](../../src/services/supabase_vector_store.py)
only calls `match_document_chunks`; the PostgreSQL schema only defines the
vector RPC. [`src/rag/pipeline.py`](../../src/rag/pipeline.py) still calls the
local SQLite FTS path for lexical retrieval.

In Supabase mode, `_init_hybrid_index()` is skipped. Exact-lookups therefore
do not have a working lexical source, and ordinary queries merge dense results
with an empty local index. The target hybrid retrieval contract is not met.

Closure criteria: implement a canonical PostgreSQL full-text representation and
owner/document-filtered SQL search function; merge dense and lexical candidates
in one retrieval service; test exact terms, policy numbers, exclusions, dates,
amounts, and semantic queries against the same Supabase fixture.

### 3. Embedding model/dimension contract is unsafe

Evidence: the schema fixes `embedding vector(1536)`, while
[`src/rag/pipeline.py`](../../src/rag/pipeline.py) supports OpenAI, Ollama, and
sentence-transformers fallbacks with different dimensions. The fallback code
also contains Qdrant collection recreation behavior that is not valid for the
Supabase vector path.

Risk: a provider failure can produce vectors incompatible with the canonical
column, or silently mix embedding spaces. A model change can invalidate all
retrieval without a migration signal.

Closure criteria: choose one production embedding contract; fail closed when
dimensions/model version do not match; add embedding model/version fields and
an index namespace or migration strategy; make fallback behavior explicit for
local development only; benchmark before changing production embeddings.

### 4. Processing state is split

Evidence: [`src/services/document_repository.py`](../../src/services/document_repository.py)
has durable document metadata and leases, but
[`src/services/document_processing_service.py`](../../src/services/document_processing_service.py)
keeps `processing_status` in memory and creates local `storage/documents` and
`temp` directories. The pipeline therefore has durable and ephemeral state
representing the same workflow.

Risk: restarts and scale-out can show inconsistent status, lose intermediate
artifacts, or make operator recovery impossible.

Closure criteria: make the database state machine authoritative; store every
durable artifact through the object-store boundary; persist extraction/indexing
attempts and failure classes; make recovery resume the same version idempotently.

## P1 gaps

### 5. No durable retrieval/evidence audit trail

Current answers expose citations in response models, but retrieval candidates,
score components, query variants, embedding model, reranker, prompt/model
version, latency, and failure class are not persisted as canonical records.

Closure criteria: add bounded, privacy-safe `retrieval_runs`, `candidates`,
`answers`, and `answer_evidence` records; redact ordinary logs; retain enough
metadata to explain a customer-visible answer without storing uncontrolled raw
content in analytics.

### 6. Training documentation is ahead of implementation

Evidence: [`docs/MODEL_TRAINING_PLAN.md`](../MODEL_TRAINING_PLAN.md) defines
purpose-specific contribution and evaluation principles, but there are no
Supabase tables or services for consent ledger, corrections, dataset registry,
dataset release, artifact lineage, or deletion propagation.

Closure criteria: implement the data/config layer described in the canonical
plan before accepting any customer-derived training contribution. Static eval
sets must be versioned, and every released sample must point to permitted
source/provenance and an expiry/deletion status.

### 7. Account lifecycle is incomplete for durable production ownership

The repository now has Supabase Auth integration and anonymous-to-account
transfer code, but there is no verified production account flow in this
checkout. Password recovery, account deletion, data export, linked-device
recovery, and Supabase RLS policy verification remain open.

Closure criteria: configure a real Supabase project; verify sign-up/confirmation,
sign-in/refresh, anonymous linking, sign-out, deletion/export, and owner
isolation against a real document; add integration evidence and RLS tests.

### 8. Analytics and rate limits are not canonical production data

Evidence: [`src/api/analytics.py`](../../src/api/analytics.py) and
[`src/utils/database_migration.py`](../../src/utils/database_migration.py) use
SQLite. Anti-abuse has in-memory fallback behavior, while the Supabase rate
limit migration exists separately.

Risk: multi-instance Cloud Run behavior, retention, operator dashboards, and
account-level usage cannot be trusted from local state.

Closure criteria: move safe analytics/operational events and rate-limit windows
to explicit Supabase tables/functions or an intentionally selected managed
service; define retention and property schema; prove no raw policy/question/
answer content enters analytics.

### 9. Storage lifecycle is not fully modeled

The private Supabase Storage adapter exists, but the database does not yet have
an artifact inventory, retention transition, restore verification, or complete
deletion ledger covering source files, derived outputs, embeddings, caches,
analytics, and permitted datasets.

Closure criteria: every object has an owning document version, purpose, content
type, retention/deletion state, and checksum; deletion is idempotent and
auditable; restore and orphan-object scans are tested.

## P2 gaps

### 10. Local and production paths are not yet separated cleanly

Qdrant, SQLite FTS, SQLite analytics, local object storage, and in-memory
fallbacks remain imported in the active pipeline. This is acceptable only as a
temporary migration state. It is not acceptable to claim canonical production
cutover until configuration, tests, and runtime logs prove the Supabase path is
the only correctness path.

Closure criteria: add an explicit local-adapter boundary, a production startup
assertion, and a cutover report showing no Qdrant/local FTS/local disk access
for production document processing or retrieval.

### 11. No Supabase integration benchmark or cutover evidence

Current tests primarily exercise SQLite, Qdrant mocks, and in-process behavior.
There is no representative Supabase corpus comparison covering extraction,
chunking, hybrid retrieval, citations, duplicate uploads, retries, partial
writes, deletes, latency, index size, and restore.

Closure criteria: create a safe staging Supabase project/fixture, run the
comparison, save results under `docs/review/evidence/`, and define numerical
quality/latency gates before cutover.

### 12. Documentation drift remains

Several older docs still describe Firebase, Qdrant, Redis, or local SQLite as
active architecture. The 2026-07-16 canonical plan is now the authority, but
historical docs need dated addenda or explicit superseded markers so future
agents do not select an obsolete path.

Closure criteria: inventory architecture-related docs, add a canonical pointer
or superseded marker, and do not delete historical material.

## Recommended execution order

1. Freeze schema, state, retrieval, provenance, consent, and deletion contracts.
2. Replace payload-only document storage with canonical relational tables.
3. Implement PostgreSQL full-text plus pgvector retrieval and its audit records.
4. Fix the embedding model/version contract.
5. Make durable processing state authoritative and remove correctness dependence
   on local process state.
6. Complete Auth lifecycle and RLS/integration evidence.
7. Move analytics/rate limits and storage lifecycle to canonical operational
   paths.
8. Build the evaluation/dataset registry and training-release boundary.
9. Run staging corpus/cutover/rollback verification.
10. Mark Qdrant, SQLite FTS, local disk, and historical Firebase paths as
    compatibility or archived only after evidence exists.

## Audit confidence

Evidence tier: **Tier 1 static repository inspection**. This register does not
claim a live Supabase project, production backup, RLS, retrieval benchmark, or
cross-instance runtime flow. Those are explicit closure gates above.
