-- CoverWise Claims table
-- Date: 2026-07-24
-- Convention: follow supabase/migrations/20260717000000_coverwise_schema.sql
--   - public schema
--   - owner_id text (NOT auth.users FK; Supabase user IDs are strings)
--   - created_at / updated_at timestamptz
--   - RLS enabled, all access revoked, only service_role granted
--   - Comments on every table
--
-- Apply via Supabase SQL editor or:
--   supabase db push

-- ============================================================================
-- claims: one row per insurance claim filed by or on behalf of a user
-- ============================================================================
create table if not exists public.claims (
  id uuid primary key default gen_random_uuid(),
  owner_id text not null,
  document_id text,
  policy_type text not null default 'Unknown',
  insurer text not null default 'Unknown',
  incident_type text not null default 'Other',
  description text not null default '',
  filed_date timestamptz not null default now(),
  reference_number text,
  status text not null default 'filed' check (status in (
    'filed', 'in_review', 'approved', 'rejected', 'paid'
  )),
  notes text,
  photo_paths jsonb default '[]'::jsonb,
  status_history jsonb default '[]'::jsonb,
  initiated_by text not null default 'user' check (initiated_by in ('user', 'agent')),
  agent_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_claims_owner
  on public.claims (owner_id);
create index if not exists idx_claims_status
  on public.claims (status);
create index if not exists idx_claims_filed_date
  on public.claims (filed_date desc);
create index if not exists idx_claims_agent
  on public.claims (agent_id)
  where initiated_by = 'agent';

alter table public.claims enable row level security;

-- RLS: users can read their own claims; service_role has full access.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'claims'
      and policyname = 'Users read own claims'
  ) then
    create policy "Users read own claims"
      on public.claims
      for select
      using (owner_id = auth.jwt() ->> 'sub');
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'claims'
      and policyname = 'Users insert own claims'
  ) then
    create policy "Users insert own claims"
      on public.claims
      for insert
      with check (owner_id = auth.jwt() ->> 'sub');
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'claims'
      and policyname = 'Users update own claims'
  ) then
    create policy "Users update own claims"
      on public.claims
      for update
      using (owner_id = auth.jwt() ->> 'sub');
  end if;
end
$$;

revoke all on table public.claims from public, anon;
grant select, insert, update on table public.claims to authenticated;
grant select, insert, update, delete on table public.claims to service_role;

comment on table public.claims is
  'Insurance claims filed by users or initiated by agents. RLS-scoped to owner_id. Authenticated users can read/insert/update their own rows.';

comment on column public.claims.initiated_by is
  '"user" for self-filed claims, "agent" for agent-initiated claims';
comment on column public.claims.agent_id is
  'The agent or advisor who initiated the claim on behalf of the user';
comment on column public.claims.status_history is
  'JSON array of {status, timestamp} entries tracking status changes';
comment on column public.claims.photo_paths is
  'JSON array of photo file paths associated with the claim';
