# CoverWise Supabase cutover and gap-closure report

## Decision

Managed Supabase remains the canonical production backend: Auth, PostgreSQL,
pgvector, FTS, private Storage, durable operational state, and the FastAPI
boundary. Qdrant, SQLite FTS, local metadata, and local object storage remain
development/migration adapters only.

## Implemented contracts

- owner-filtered hybrid FTS/pgvector retrieval with a fixed 1536-dimensional
  embedding contract;
- durable processing leases, append-only processing events, and outbox-backed
  document processing/account deletion/substrate extraction;
- idempotent anonymous-to-account linking;
- private Storage owner policies and source/derived document artifact
  inventory/checksums;
- privacy-safe retrieval runs, candidate lineage, answer hashes, and citation
  evidence;
- production answer requests await audit persistence and fail closed if the
  audit write cannot complete;
- consent-aware draft/approved/revoked dataset releases, item withdrawal, and
  approved-release model-run/artifact lineage;
- metadata account export plus expiring private source download links when the
  selected object-store backend supports them;
- processing uses only ephemeral temp copies and skips legacy local-document
  startup scanning in production;
- production analytics retention has a service-role-only purge primitive with
  future-cutoff protection;
- canonical analytics ingestion derives stable replay identity before insert;
- production structured policy summaries use the durable Supabase projection;
- FTS ranks retrieval text but returns immutable source text for citations;
- normalized policy/version/section projection and deterministic approved
  dataset manifest materialization;
- production startup assertions that reject SQLite/local storage/Qdrant
  configuration and skip legacy SQLite anti-abuse initialization.

## Evidence

| Check | Result | Evidence tier |
|---|---|---|
| Python suite (project `venv`) | 336 passed, 4 skipped, 42 warnings | Tier 2 |
| Local migration reset | All migrations through `20260721079000` replayed before the local Postgres service became unavailable; later migrations through `20260721090703` require a fresh reset; 32 files are currently present | Tier 3 for prior set; new migrations unverified locally |
| Local schema lint | No schema errors | Tier 2/3 |
| Retrieval benchmark | FTS and pgvector each returned the owner-scoped expected document; cross-owner row excluded | Tier 3 |
| Retrieval benchmark artifact | [`supabase-retrieval-benchmark-local.json`](evidence/supabase-retrieval-benchmark-local.json) | Tier 3 |
| RPC permissions | `anon` denied; `service_role` allowed for retrieval writes/reads as intended | Tier 3 |
| Mobile Flutter suite | Not executed: compiler failed before test loading with `No space left on device` | Unverified |
| New domain/lifecycle tests | 9 policy/artifact/model/webhook tests plus 5 billing/temp-storage/substrate tests passed; touched Python modules compile | Tier 2 |

The benchmark is synthetic and local. It is not representative-corpus or
production-latency evidence.

## Rollback and cutover gates

Before a real customer cutover:

1. Create a staging Supabase project and record a database/Storage backup
   checkpoint.
2. Run the benchmark against a consented representative corpus, including
   exact lookup, semantic lookup, duplicate upload, retry, partial failure,
   deletion, and owner-isolation cases.
3. Verify Supabase Auth signup, confirmation, password recovery, anonymous
   linking, sign-out, export, deletion, and RLS with two real test accounts.
4. Verify outbox worker crash/reclaim/dead-letter behavior and post-deletion
   absence from Storage, documents, chunks, artifacts, dataset items, and Auth.
5. Keep the compatibility adapters read-only and available for the defined
   migration window. Revert the production routing configuration to the
   previous adapter only before accepting new customer writes; after cutover,
   restore from the recorded Supabase checkpoint rather than dual-writing
   silently.
6. Run a restore rehearsal and record recovery time, row counts, Storage
   object counts, and retrieval contract checks.

No production cutover, remote migration, backup, restore, or credentialed Auth
test was performed in this workspace.

### Anything else?

The gaps addressed in this pass are locally verified. Policy/version/section
relational modeling, fenced artifact retention/orphan transitions, a remote
server-side billing ledger/RPC, and stable approved-release manifest
materialization are now implemented. Remaining
code/domain work includes executing released manifests and wiring complete
product answer-evidence adoption; the larger
remaining blockers are external evidence gates plus machine capacity for
Flutter verification. None of these results should be presented as production
readiness.
