-- Canonical guest -> account identity links.
-- This table is deliberately service-role only: clients must never assert or
-- rewrite ownership aliases themselves.

create table if not exists public.identity_aliases (
  anonymous_uid text primary key,
  account_uid text not null,
  status text not null default 'pending'
    check (status in ('pending', 'completed', 'failed')),
  transferred_documents integer not null default 0
    check (transferred_documents >= 0),
  last_error_class text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists idx_identity_aliases_account
  on public.identity_aliases (account_uid);

alter table public.identity_aliases enable row level security;
revoke all on table public.identity_aliases from public, anon, authenticated;
grant select, insert, update on table public.identity_aliases to service_role;

comment on table public.identity_aliases is
  'Durable, idempotent guest-to-account ownership link. Service-role only.';
