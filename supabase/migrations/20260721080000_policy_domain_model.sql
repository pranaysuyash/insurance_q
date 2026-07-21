-- Durable policy identity and document structure.
-- Documents remain the immutable source upload; these tables give product
-- surfaces stable policy/version/section keys without parsing JSON payloads.

create table if not exists public.policies (
  id uuid primary key default gen_random_uuid(),
  owner_id text not null,
  family_member_id text,
  policy_number text,
  insurer text,
  policy_type text,
  status text not null default 'active'
    check (status in ('active', 'archived', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists policies_owner_idx on public.policies (owner_id, updated_at desc);
create index if not exists policies_owner_number_idx on public.policies (owner_id, policy_number)
  where policy_number is not null;

create table if not exists public.policy_versions (
  id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.policies(id) on delete cascade,
  document_id uuid not null references public.documents(id) on delete cascade,
  version_label text not null,
  effective_from date,
  effective_to date,
  status text not null default 'current'
    check (status in ('current', 'superseded', 'processing', 'failed')),
  source_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (policy_id, document_id),
  unique (document_id)
);

create index if not exists policy_versions_policy_idx
  on public.policy_versions (policy_id, created_at desc);

create table if not exists public.document_sections (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  parent_section_id uuid references public.document_sections(id) on delete cascade,
  ordinal integer not null check (ordinal >= 0),
  title text,
  section_type text not null default 'general',
  start_page integer check (start_page is null or start_page >= 1),
  end_page integer check (end_page is null or end_page >= start_page),
  source_chunk_id bigint references public.document_chunks(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (document_id, ordinal)
);

create index if not exists document_sections_document_idx
  on public.document_sections (document_id, ordinal);

alter table public.policies enable row level security;
alter table public.policy_versions enable row level security;
alter table public.document_sections enable row level security;
revoke all on public.policies, public.policy_versions, public.document_sections
  from public, anon, authenticated;
grant select, insert, update, delete on public.policies, public.policy_versions,
  public.document_sections to service_role;

comment on table public.policies is 'Stable owner-scoped policy identity; not a source document.';
comment on table public.policy_versions is 'Document-backed policy versions with explicit supersession state.';
comment on table public.document_sections is 'Durable retrieval/evidence structure for a document.';
