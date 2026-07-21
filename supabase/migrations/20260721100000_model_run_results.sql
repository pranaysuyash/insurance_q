-- Per-item results for governed evaluation runs.
-- Raw model output is intentionally not stored here; implementations may
-- publish a separately governed artifact and retain only its hash/metrics.

create table if not exists public.model_run_results (
  id uuid primary key default gen_random_uuid(),
  model_run_id uuid not null references public.model_runs(id) on delete cascade,
  dataset_item_id uuid not null references public.dataset_items(id) on delete restrict,
  status text not null check (status in ('passed', 'failed', 'error')),
  score double precision check (score is null or (score >= 0 and score <= 1)),
  output_hash text,
  metrics jsonb not null default '{}'::jsonb,
  error_class text,
  created_at timestamptz not null default now(),
  unique (model_run_id, dataset_item_id)
);

create index if not exists model_run_results_run_idx
  on public.model_run_results (model_run_id, status);

create index if not exists model_run_results_dataset_item_idx
  on public.model_run_results (dataset_item_id);

alter table public.model_run_results enable row level security;
revoke all on public.model_run_results from public, anon, authenticated;
grant select, insert, update on public.model_run_results to service_role;

comment on table public.model_run_results is
  'Hash/metric-only per-item results for an approved governed model run.';
