-- CoverWise Family Workspace table
-- Date: 2026-08-24
-- Canonical schema for user family members with owner isolation and RLS

create table if not exists public.family_members (
  id text primary key default gen_random_uuid()::text,
  user_uid text not null,
  name text not null,
  relationship text not null,
  dob date,
  phone text,
  email text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_family_members_user
  on public.family_members (user_uid);

alter table public.family_members enable row level security;

-- RLS: users can CRUD their own family members; service_role has full access.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'family_members'
      and policyname = 'Users read own family members'
  ) then
    create policy "Users read own family members"
      on public.family_members
      for select
      using (user_uid = auth.jwt() ->> 'sub');
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'family_members'
      and policyname = 'Users insert own family members'
  ) then
    create policy "Users insert own family members"
      on public.family_members
      for insert
      with check (user_uid = auth.jwt() ->> 'sub');
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'family_members'
      and policyname = 'Users update own family members'
  ) then
    create policy "Users update own family members"
      on public.family_members
      for update
      using (user_uid = auth.jwt() ->> 'sub');
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'family_members'
      and policyname = 'Users delete own family members'
  ) then
    create policy "Users delete own family members"
      on public.family_members
      for delete
      using (user_uid = auth.jwt() ->> 'sub');
  end if;
end
$$;

revoke all on table public.family_members from public, anon;
grant select, insert, update, delete on table public.family_members to authenticated;
grant select, insert, update, delete on table public.family_members to service_role;

comment on table public.family_members is
  'Family workspace members belonging to a user. RLS-scoped to user_uid.';
