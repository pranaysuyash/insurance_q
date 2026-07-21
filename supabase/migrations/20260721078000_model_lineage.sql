-- Model-run and artifact lineage. This records governed experiments; it does
-- not make any customer material eligible for training by itself.

create table if not exists public.model_runs (
  id uuid primary key default gen_random_uuid(),
  dataset_release_id uuid not null references public.dataset_releases(id),
  purpose text not null check (purpose in ('evaluation', 'training', 'benchmark')),
  provider text not null,
  model_name text not null,
  model_version text,
  config_hash text not null,
  status text not null default 'started'
    check (status in ('started', 'completed', 'failed', 'cancelled')),
  metrics jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_by text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.model_artifacts (
  id uuid primary key default gen_random_uuid(),
  model_run_id uuid not null references public.model_runs(id) on delete cascade,
  artifact_kind text not null check (artifact_kind in ('checkpoint', 'evaluation_report', 'manifest', 'log')),
  object_reference text not null,
  checksum_sha256 text not null,
  byte_size bigint check (byte_size is null or byte_size >= 0),
  metrics jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (model_run_id, object_reference)
);

create index if not exists model_runs_release_idx
  on public.model_runs (dataset_release_id, created_at desc);
create index if not exists model_artifacts_run_idx
  on public.model_artifacts (model_run_id);

alter table public.model_runs enable row level security;
alter table public.model_artifacts enable row level security;
revoke all on public.model_runs, public.model_artifacts from public, anon, authenticated;
grant select, insert, update on public.model_runs, public.model_artifacts to service_role;

comment on table public.model_runs is
  'Governed model/evaluation runs linked to a versioned dataset release.';
