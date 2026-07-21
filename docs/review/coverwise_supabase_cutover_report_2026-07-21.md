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
- executable approved-release evaluation runs with per-item hash/metric results
  and terminal model-run lineage;
- answer citations and missing-information disclosures are now rendered in the
  mobile Q&A answer card;
- production startup assertions that reject SQLite/local storage/Qdrant
  configuration and skip legacy SQLite anti-abuse initialization.

## Evidence

| Check | Result | Evidence tier |
|---|---|---|
| Python suite (project `.venv`) | 350 passed, 1 skipped | Tier 2 |
| Local migration reset | All migrations through `20260721079000` replayed before the local Postgres service became unavailable; migrations through `20260721100000` now require a fresh reset | Tier 3 for prior set; later migrations unverified locally |
| Local schema lint | Prior migration subset had no schema errors; current full rerun is blocked by unavailable local Postgres | Tier 2/3 for prior subset |
| Retrieval benchmark | FTS and pgvector each returned the owner-scoped expected document; cross-owner row excluded | Tier 3 |
| Retrieval benchmark artifact | [`supabase-retrieval-benchmark-local.json`](evidence/supabase-retrieval-benchmark-local.json) | Tier 3 |
| RPC permissions | `anon` denied; `service_role` allowed for retrieval writes/reads as intended | Tier 3 |
| Remote Supabase probe | Auth settings HTTP 200; email enabled, anonymous users disabled, confirmation required; established service-role tables queryable; new `model_run_results` table absent; publishable-key protected-table reads denied | Tier 3 partial; migration/auth E2E incomplete |
| Mobile Flutter suite | `flutter test` completed with 588 tests passed; analyzer clean | Tier 2 |
| New domain/lifecycle tests | Focused policy/artifact/model/webhook/billing/temp-storage/substrate/retrieval tests passed; touched Python modules compile | Tier 2 |

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

### Remote schema closure command

The remote project is reachable through the REST Data API, but this checkout is
not linked to a Supabase project and no `SUPABASE_ACCESS_TOKEN` or database
password is available. After an authorized operator supplies those values:

```bash
supabase link --project-ref <project-ref>
supabase db push --dry-run --linked
supabase db push --linked --yes
set -a; . ./.env; set +a
venv/bin/python tools/verify_supabase_schema.py
```

The final verifier must report every required table as `present`, including
`model_run_results`, before the evaluation contract is considered deployed.

### Anything else?

The gaps addressed in this pass are locally verified. Policy/version/section
relational modeling, fenced artifact retention/orphan transitions, a remote
server-side billing ledger/RPC, and stable approved-release manifest
materialization are now implemented. Remaining
code/domain work includes training execution, complete product answer-evidence
adoption across non-Q&A surfaces, and the remaining outbox handlers; the larger
remaining blockers are external evidence gates: credentialed Auth/RLS, staging
deletion and outbox recovery, representative-corpus retrieval/backfill,
retention scheduling, and backup/restore rehearsal. None of these results should
be presented as production readiness.
