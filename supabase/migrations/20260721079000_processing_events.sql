-- Append-only processing stage history for restart/operator diagnosis.

create table if not exists public.processing_events (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  owner_id text not null,
  stage text not null,
  state text not null check (state in ('started', 'in_progress', 'completed', 'failed')),
  progress integer not null check (progress between 0 and 100),
  attempt integer not null default 0 check (attempt >= 0),
  error_class text,
  created_at timestamptz not null default now()
);

create index if not exists processing_events_document_created_idx
  on public.processing_events (document_id, created_at desc);
create index if not exists processing_events_owner_created_idx
  on public.processing_events (owner_id, created_at desc);

alter table public.processing_events enable row level security;
revoke all on public.processing_events from public, anon, authenticated;
grant select, insert on public.processing_events to service_role;

comment on table public.processing_events is
  'Append-only stage transitions for durable processing recovery and operator diagnosis.';
