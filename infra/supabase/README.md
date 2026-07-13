# CoverWise Supabase setup

This directory contains the first production schema for the canonical solo-launch
architecture. Apply [`001_coverwise_schema.sql`](001_coverwise_schema.sql),
[`002_document_processing_leases.sql`](002_document_processing_leases.sql), and
[`003_rate_limit_windows.sql`](003_rate_limit_windows.sql) in the Supabase SQL
editor before deploying Cloud Run with the Supabase backends.

## Required secrets

- `SUPABASE_URL`: the project URL.
- `SUPABASE_SERVICE_ROLE_KEY`: server-only key; never ship it in mobile or browser code.
- `SUPABASE_STORAGE_BUCKET`: private bucket name, default `coverwise-documents`.
- `ANONYMOUS_AUTH_SIGNING_KEY`: long random secret for the launch bearer identity.
- `ALLOWED_ORIGINS`: comma-separated final HTTPS browser origins; required in
  production and must never contain `*`.

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
the `document_chunks` table stores embeddings next to the text and ownership fields
needed for filtered retrieval. The `match_document_chunks` RPC caps retrieval at 50
rows and requires an owner identifier.

`claim_document_processing` is a `SECURITY DEFINER` function used only by the
server-side service-role client. The migrations explicitly revoke execution from
`public`, `anon`, and `authenticated`; do not weaken that grant when editing the
schema.

`consume_rate_limit` is also service-role-only and accepts only hashed
identifiers. Wire it into the app before enabling customer uploads in a
multi-instance Cloud Run deployment; its migration alone does not change the
legacy local anti-abuse runtime.
