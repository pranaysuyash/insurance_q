-- Inventory of source and derived objects owned by a document.

create table if not exists public.document_artifacts (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  owner_id text not null,
  object_reference text not null,
  artifact_kind text not null check (artifact_kind in ('source', 'page_image', 'derived', 'embedding_cache')),
  content_type text,
  byte_size bigint check (byte_size is null or byte_size >= 0),
  checksum_sha256 text,
  retention_until timestamptz,
  state text not null default 'active' check (state in ('active', 'deleting', 'deleted', 'orphaned')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (document_id, object_reference)
);

create index if not exists document_artifacts_owner_state_idx
  on public.document_artifacts (owner_id, state);
create index if not exists document_artifacts_document_idx
  on public.document_artifacts (document_id);

alter table public.document_artifacts enable row level security;
revoke all on public.document_artifacts from public, anon, authenticated;
grant select, insert, update on public.document_artifacts to service_role;

comment on table public.document_artifacts is
  'Canonical inventory for source and derived objects, retention, checksum, and deletion state.';
