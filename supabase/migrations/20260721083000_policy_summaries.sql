-- Durable structured policy-summary projection.

create table if not exists public.document_policy_summaries (
  document_id uuid primary key references public.documents(id) on delete cascade,
  summary jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.document_policy_summaries enable row level security;
revoke all on public.document_policy_summaries from public, anon, authenticated;
grant select, insert, update, delete on public.document_policy_summaries to service_role;

comment on table public.document_policy_summaries is
  'Canonical structured summary projection for a policy document; service-role only.';
