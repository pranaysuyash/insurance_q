# CoverWise Supabase canonical gap register

**Date:** 2026-07-16  
**Baseline:** [`coverwise_supabase_canonical_plan_2026-07-16.md`](../planning/coverwise_supabase_canonical_plan_2026-07-16.md)  
**Audit type:** repository architecture and implementation audit  
**Status:** implementation pass in progress; original gap baseline retained below

## Decision boundary

The target is managed Supabase with PostgreSQL/pgvector, private Storage,
Supabase Auth, and one FastAPI pipeline. This register compares the current
repository with that target. Existing local/Qdrant/SQLite code is preserved as
migration evidence, but it is not accepted as production truth.

## Addendum — 2026-07-21 implementation audit

The following closures are now implemented in the current worktree:

- PostgreSQL FTS and pgvector are both canonical retrieval paths, with server-side owner/document filters.
- Supabase ingestion records source text separately from retrieval text and enforces the 1536-dimensional embedding contract.
- Chunk links use the canonical bigint `document_chunks.id` key.
- Processing status can be projected from the durable document repository; in-memory status is debug-only.
- Outbox claim and stuck-lease reclaim are atomic Postgres functions.
- Production analytics writes and reads fail closed to Supabase instead of silently using SQLite.
- Private Storage owner policies are present.
- Consent-aware dataset releases/items and withdrawal state are present.
- Dataset release approval, owner withdrawal propagation, retrieval candidate/
  answer evidence lineage, source artifact inventory, and approved-release
  model-run/artifact lineage are now implemented. Processing stage history is
  now append-only and durable as well.
- A reusable synthetic Supabase retrieval benchmark has passed locally with
  owner isolation, one FTS hit, one pgvector hit, and recorded latency evidence
  at [`supabase-retrieval-benchmark-local.json`](evidence/supabase-retrieval-benchmark-local.json).
- The complete cutover/rollback evidence boundary is recorded in
  [`coverwise_supabase_cutover_report_2026-07-21.md`](coverwise_supabase_cutover_report_2026-07-21.md).

Evidence: targeted Python tests (71 passed in the broader retrieval/outbox set,
18 in the auth/identity set), Python compilation, local PostgreSQL execution of
the migration set, a clean `supabase db reset --local --no-seed`, `supabase db
lint --local`, migration listing, and direct inspection of the created
tables/functions.

The full repository Python suite was subsequently run with the project
`.venv`: **350 passed, 1 skipped**. The system-Python dependency failures are
environment noise, not the repository-suite result.

Remaining gaps are narrower and require either application work or configured
external systems:

- password recovery is implemented in the mobile client, but live Supabase
  Auth/RLS integration evidence is not verified against a real project;
- production deletion is now outbox-backed, but real Storage/Auth deletion,
  retry, and post-deletion verification still require a configured staging
  project;
- substrate extraction is now enqueued from production document processing and
  reloads persisted page OCR in the worker; worker crash/reclaim and staging
  post-condition evidence remain open;
- production startup no longer creates legacy SQLite anti-abuse tables;
  Supabase rate-limit RPCs are the only production path;
- structured policy summaries now use the canonical Supabase projection in
  production; local Redis/file storage remains development-only;
- retrieval benchmark, representative corpus backfill, rollback checkpoint, and
  production backup/restore evidence are not present;
- the contextual retrieval backfill is now bounded and resumable by page, and
  updates the durable embedding model/version/dimension columns with each
  vector. A representative-corpus run and rollback checkpoint are still not
  present;
- the legacy Qdrant/SQLite compatibility code remains available and needs a
  measured cutover/retirement decision;
- source-file links are now part of the export when supported by the private
  object store; derived-object retention, orphan scans, and restore remain
  governed operational follow-ups.
- the full mobile Flutter test suite now passes: 588 tests passed. This removes
  the earlier machine-capacity verification gap, but does not substitute for
  authenticated runtime or staging evidence.
- approved evaluation releases now have an executable per-item run contract,
  hash-only result persistence, aggregate metrics, and terminal model lineage;
  actual provider/model evaluation and training execution remain deployment- and
  credential-dependent.
- retention now has one executable maintenance command covering analytics purge
  and fenced artifact deletion; deployment must still schedule it and prove it
  against staging.

### Anything else?

### Addendum — 2026-07-21 verification correction

The earlier local reset/lint evidence above applies to the migration set that
was available when that check ran. A fresh `supabase db lint --local` rerun on
the current 33-migration worktree was attempted after the later migrations were
added, but the local Postgres service was unavailable (`LegacyDbConnectError`).
The current evidence is therefore the project-venv Python suite, the full
Flutter suite, targeted contract tests, compilation, diff validation, and the
previously successful local migration subset—not a fresh full migration reset.

The ignored `.env` was then used for a non-secret remote probe. Supabase Auth
settings returned HTTP 200 with email enabled, anonymous users disabled, and
email confirmation required. The service key could read the established
canonical tables, while `public.model_run_results` was absent from the remote
schema (`PGRST205`), proving that the new migration still needs to be applied.
Publishable-key reads of `job_outbox` and `identity_aliases` were denied; an
empty publishable-key `documents` result was consistent with owner RLS. No
test account was created and no remote write was attempted.

Yes: the remaining risk is now primarily verification and lifecycle closure,
not the basic Supabase data/retrieval substrate. Do not cut over until the
remaining gates above have Tier 3+ evidence.

## Summary

| Priority | Area | Current state | Gap |
|---|---|---|---|
| P0 | Supabase schema | Core schema plus evidence, consent, retrieval, dataset, policy-domain, and per-item evaluation-result migrations exist; production answers persist privacy-safe audit lineage | Evidence is rendered in mobile Q&A; non-Q&A claim surfaces and live route-level verification remain |
| P0 | Production retrieval | Supabase full-text + pgvector RPCs are canonical, owner/document filtered, and return immutable source text for citations | Representative corpus benchmark and backfill/cutover evidence are missing |
| P0 | Embedding contract | Supabase ingestion fails closed outside the 1536d/model-version contract | A production embedding-provider decision and existing-corpus re-embedding are still unverified |
| P0 | Processing state | Repository leases and append-only processing events are authoritative; local status is debug-only | Full staging recovery/operator verification remains |
| P1 | Retrieval auditability | Query traces, candidate lineage, answer hashes, and citation evidence are persisted without raw content; production requests await the audit write | Full live-pipeline audit write/read evidence remains |
| P1 | Training readiness | Consent-aware registry, draft approval, withdrawal propagation, approved-release lineage, stable manifests, and an executable per-item evaluation contract exist | Credentialed provider evaluation, training execution, and published artifact delivery remain |
| P1 | Auth lifecycle | Anonymous linking, metadata/source export, and durable deletion request/worker exist locally | No production provider verification or full account-flow evidence |
| P1 | Analytics/rate limits | Production analytics and upload rate limits use Supabase RPCs; stable event identity, retention purge primitive, and a schedulable maintenance command are explicit | Deployment scheduling and multi-instance staging evidence remain |
| P1 | Storage lifecycle | Private Storage policies, source and derived artifact inventory/checksums, and audited retention/orphan transitions exist | Scheduled execution, restore, and complete deletion evidence remain |
| P2 | Migration/cutover | Supabase adapters coexist with Qdrant/SQLite; local contract benchmark and production startup assertions exist | No representative corpus comparison, backfill, rollback checkpoint, or retirement gate |
| P2 | Tests | Local migration/RPC smoke, synthetic Supabase retrieval benchmark, full Python suite, and full Flutter suite exist | Staging RLS/Auth and representative corpus benchmark remain |

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
or superseded marker, and do not delete historical material. Key user-facing
and architecture entry points now meet this requirement; remaining files are
historical review candidates rather than active production instructions.

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

## Addendum (2026-07-21) — policy domain and artifact lifecycle

Migration `20260721080000_policy_domain_model.sql` adds durable `policies`,
`policy_versions`, and `document_sections`. The processing job projects bounded
classification and section metadata into this model after classification;
`src/services/policy_domain_service.py` is idempotent per document and never
writes OCR or retrieval source text.

Migration `20260721081000_artifact_lifecycle_audit.sql` adds a versioned
retention-policy field and append-only transition events. The lifecycle service
can mark expired inventory entries as `deleting`, mark missing storage listings
as `orphaned`, and record completed deletion. A scheduler, real Storage listing,
restore test, and staging evidence remain open gates.

Page images written during processing now pass through the object-store
reference boundary and are registered as `page_image` artifacts with owner,
size, content type, and checksum. The inventory still requires a real Storage
listing and restore rehearsal for Tier 3 evidence.

Migration `20260721083000_policy_summaries.sql` and
`PolicyExtractionService` now make structured summaries durable in Supabase in
production. The summary route still needs credentialed end-to-end verification
against a real owner-scoped document.

Migration `20260721084000_fts_source_text_contract.sql` makes FTS rank the
retrieval representation while returning `source_text` to the API. This closes
the lexical citation-contamination path; a fresh migration reset and live
citation traversal remain required for Tier 3 evidence.

`DatasetRegistry.materialize_manifest()` now provides the execution boundary
for approved releases: only active items are included and the resulting
manifest is deterministically hashed. It is a release contract, not evidence
that a model-training job has run; the executor and published model artifact
remain a separate gated step.

The main user guide, modern stack overview, comprehensive architecture
snapshot, and TODO checklist now explicitly point to the managed-Supabase
canonical architecture. Historical Firebase/Qdrant/Redis material remains
available but is marked non-authoritative.

`20260721082000_analytics_retention.sql` and
`AnalyticsRetentionService` add the service-role-only retention boundary. The
function rejects future cutoffs and returns the deleted-row count. A scheduled
production invocation and observed retention report remain external gates.

Migration `20260721090703_analytics_event_idempotency.sql` is now matched by
the API's deterministic event identity generation, so retries do not depend on
`received_at` and duplicate events are safely ignored by the canonical unique
index.

## Audit confidence

Evidence tier: **Tier 1 static repository inspection**. This register does not
claim a live Supabase project, production backup, RLS, retrieval benchmark, or
cross-instance runtime flow. Those are explicit closure gates above.

## Addendum (2026-07-21) — policy domain projection

Migration `20260721080000_policy_domain_model.sql` adds durable `policies`,
`policy_versions`, and `document_sections` tables. The processing job now
projects bounded classification metadata and retrieved section structure into
that model after classification. The projection is idempotent per document and
does not persist OCR text or model-generated retrieval text. Production still
needs a representative staging run to prove the projection against real
classification output and policy-version supersession behavior.

## Addendum — current upload and remote schema recheck (2026-07-21)

The earlier `BackgroundTasks` upload finding is superseded: production upload
uses the durable `document_processing` outbox job and fails closed when the
outbox is unavailable; the in-process compatibility task is development-only.

The read-only schema probe was rerun and returned exit code 0. All required
tables, including `model_run_results`, were queryable and Auth returned HTTP
200 with anonymous users disabled. Migration-ledger baseline parity and
deployed runtime/recovery proof remain open; the table-absence finding is
closed.
