-- Consent-aware evaluation/training registry.
-- A dataset release is a named, immutable selection of evidence. Customer
-- material is never copied into a release without a purpose and consent
-- reference, and withdrawal is represented as state rather than deletion.

create table if not exists public.dataset_releases (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  version text not null,
  purpose text not null check (purpose in ('evaluation', 'training', 'benchmark')),
  status text not null default 'draft'
    check (status in ('draft', 'approved', 'revoked')),
  consent_policy_version text,
  manifest_hash text,
  created_by text not null,
  approved_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique (name, version)
);

create table if not exists public.dataset_items (
  id uuid primary key default gen_random_uuid(),
  release_id uuid not null references public.dataset_releases(id) on delete cascade,
  owner_id text,
  source_document_id uuid references public.documents(id) on delete set null,
  source_chunk_id bigint references public.document_chunks(id) on delete set null,
  consent_record_id uuid references public.consent_ledger(id) on delete set null,
  prompt text not null,
  expected_answer text,
  expected_citations jsonb not null default '[]'::jsonb,
  source_snapshot jsonb not null default '{}'::jsonb,
  inclusion_basis text not null,
  status text not null default 'active'
    check (status in ('active', 'withdrawn')),
  withdrawn_at timestamptz,
  withdrawn_reason text,
  created_at timestamptz not null default now(),
  unique (release_id, prompt, source_document_id, source_chunk_id)
);

create index if not exists dataset_items_release_status_idx
  on public.dataset_items (release_id, status);
create index if not exists dataset_items_source_document_idx
  on public.dataset_items (source_document_id)
  where source_document_id is not null;

alter table public.dataset_releases enable row level security;
alter table public.dataset_items enable row level security;
revoke all on public.dataset_releases, public.dataset_items from public, anon, authenticated;
grant select, insert, update on public.dataset_releases to service_role;
grant select, insert, update on public.dataset_items to service_role;

comment on table public.dataset_releases is
  'Versioned, purpose-bound dataset manifests. Service-role only.';
comment on table public.dataset_items is
  'Consent/provenance-linked evaluation or training examples with withdrawal state.';
