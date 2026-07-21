# CoverWise Supabase setup

This directory contains the original production SQL for the canonical solo-launch
architecture. The executable Supabase CLI migration history now lives under
`supabase/migrations/` with normalized 14-digit versions; the files here remain
the SQL-editor-compatible source snapshot for operational review and rollback.
For local verification, run `supabase db reset --local --no-seed` and
`supabase db lint --local` from the repository root.

## Required secrets

- `SUPABASE_URL`: the project URL.
- `SUPABASE_SERVICE_ROLE_KEY`: server-only key; never ship it in mobile or browser code.
- `SUPABASE_STORAGE_BUCKET`: private bucket name, default `coverwise-documents`.
- `ANONYMOUS_AUTH_SIGNING_KEY`: long random secret for the launch bearer identity.
- `ALLOWED_ORIGINS`: comma-separated final HTTPS browser origins; required in
  production and must never contain `*`.

Account auth uses Supabase Auth. The mobile release receives only the project
URL and publishable/anonymous key through build-time configuration; the API
receives `SUPABASE_SERVICE_ROLE_KEY` only on the server and verifies account
access tokens through Supabase Auth. Never ship the service-role key in mobile.

## Runtime selection

Set `ENVIRONMENT=production`, `DOCUMENT_REPOSITORY_BACKEND=supabase`, and
`DOCUMENT_OBJECT_STORE_BACKEND=supabase`, plus `RAG_VECTOR_BACKEND=supabase`.
Local development continues to use SQLite
and the local document directory unless those variables are explicitly changed.

The DynamoDB/S3 adapters are preserved for historical migration and rollback work;
they are not the current production default. Do not add Qdrant or Redis to the
production deployment while the pgvector migration is in progress.

## Data handling

The storage bucket is private. Document metadata is owner-scoped in Postgres, and
the `document_chunks` table stores immutable source text, retrieval text, embedding
model/version, and ownership fields needed for filtered retrieval. The canonical
hybrid retrieval RPCs cap results at 50 rows and require an owner identifier.

`claim_document_processing` is a `SECURITY DEFINER` function used only by the
server-side service-role client. The migrations explicitly revoke execution from
`public`, `anon`, and `authenticated`; do not weaken that grant when editing the
schema.

`consume_rate_limit` is also service-role-only and accepts only hashed
identifiers. Production uploads and usage reporting call this RPC; local
development retains the SQLite/Redis compatibility path.

Account lifecycle: `GET /user/account/export` returns a versioned metadata
export, while production `DELETE /user/account` writes an
`account_deletion_requests` row and enqueues the canonical `account_deletion`
outbox job. The worker reports completion only after private Storage, document
metadata/chunks, and Supabase Auth deletion stages succeed. Source-file bytes
are intentionally not embedded in the metadata export.

Retrieval audit records live in `retrieval_runs`, `retrieval_candidates`,
`rag_answers`, and `answer_evidence`. They retain hashes and identifiers, not
raw customer queries, answers, quotes, or source text. `document_artifacts`
is the inventory for source and derived objects, checksums, retention, and
deletion state.

`model_runs` and `model_artifacts` are the only governed lineage records for
future evaluation/training execution. A run requires an approved dataset
release with a matching purpose; a dataset draft or ordinary customer upload
cannot start a model run.

`processing_events` is the append-only stage history used for restart and
operator diagnosis; the in-process status map remains only a debug projection.
