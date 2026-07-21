-- Auditable transitions for retention and orphan detection.

alter table public.document_artifacts
  add column if not exists retention_policy_version text;

create table if not exists public.artifact_lifecycle_events (
  id uuid primary key default gen_random_uuid(),
  artifact_id uuid not null references public.document_artifacts(id) on delete cascade,
  from_state text,
  to_state text not null check (to_state in ('active', 'deleting', 'deleted', 'orphaned')),
  reason text not null,
  actor text not null,
  created_at timestamptz not null default now()
);

create index if not exists artifact_lifecycle_events_artifact_idx
  on public.artifact_lifecycle_events (artifact_id, created_at desc);

alter table public.artifact_lifecycle_events enable row level security;
revoke all on public.artifact_lifecycle_events from public, anon, authenticated;
grant select, insert on public.artifact_lifecycle_events to service_role;
