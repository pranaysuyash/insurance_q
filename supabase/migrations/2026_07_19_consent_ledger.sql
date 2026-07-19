-- CoverWise server-side consent ledger (Security Phase 2)
-- Date: 2026-07-19
-- Decision: docs/decisions/ADR-2026-07-19-07-security-phase-2-server-side-consent-ledger.md
-- Convention: follow supabase/migrations/2026_07_18_revops_tables.sql and
--   2026_07_19_job_outbox.sql
--   - public schema
--   - RLS enabled, all access revoked, only service_role granted
--   - if not exists everywhere (idempotent re-runs)
--
-- The consent ledger is the source of truth for the user's
-- privacy decisions (DPDP Act 2023, GDPR if applicable). It is
-- append-only at the database level: a Postgres trigger raises
-- an exception on UPDATE and DELETE for ALL roles, including
-- service_role. The RLS policies additionally deny UPDATE and
-- DELETE for anon and authenticated; the service_role is
-- allowed INSERT.
--
-- Per ADR-2026-07-19-07: append-only is the foundation of the
-- consent model. A bug in the application cannot rewrite
-- history. The trigger is the enforcement mechanism (RLS alone
-- is insufficient because the service_role bypasses RLS).

create extension if not exists pgcrypto;

create table if not exists public.consent_ledger (
  id uuid primary key default gen_random_uuid(),
  -- The Supabase Auth user ID. text (not uuid) per the canonical
  -- CoverWise convention (Supabase user IDs are strings).
  user_id text not null,
  -- The consent type. New types are added without schema change.
  -- v1 types: 'privacy_policy', 'analytics', 'marketing_emails',
  -- 'camera_access'. v2 will add 'biometric_data',
  -- 'third_party_data_sharing', etc.
  consent_type text not null
    check (consent_type in (
      'privacy_policy',
      'analytics',
      'marketing_emails',
      'camera_access'
    )),
  -- Whether the user granted or revoked consent. A revocation
  -- is a new row with granted=false; the "current" state is
  -- the most recent row for (user_id, consent_type).
  granted boolean not null,
  -- The version of the document the user consented to. When
  -- the privacy policy changes, the user is asked to consent
  -- again; the new row records the new policy_version.
  policy_version text not null,
  -- IP address (for audit). Optional; the Flutter app may not
  -- have access to the real IP.
  ip_address text,
  -- User agent (for audit). Optional; the Flutter app sends
  -- 'coverwise-mobile/{version}'.
  user_agent text,
  created_at timestamptz not null default now()
);

-- The "current consent" query: for each (user_id, consent_type),
-- find the most recent row. The composite index supports it.
create index if not exists consent_ledger_user_type_created_idx
  on public.consent_ledger (user_id, consent_type, created_at desc);

-- Append-only enforcement: a Postgres trigger that raises an
-- exception on UPDATE and DELETE. The trigger fires for ALL
-- roles, including service_role (which bypasses RLS). This is
-- the only way to enforce append-only for the service_role.
create or replace function public.consent_ledger_append_only()
returns trigger
language plpgsql
as $$
begin
  if (tg_op = 'UPDATE') then
    raise exception 'consent_ledger is append-only: UPDATE is not allowed (row id=%, user_id=%)',
      old.id, old.user_id
      using errcode = '42501';  -- insufficient_privilege
  end if;
  if (tg_op = 'DELETE') then
    raise exception 'consent_ledger is append-only: DELETE is not allowed (row id=%, user_id=%)',
      old.id, old.user_id
      using errcode = '42501';  -- insufficient_privilege
  end if;
  return null;
end;
$$;

drop trigger if exists consent_ledger_append_only_trg on public.consent_ledger;
create trigger consent_ledger_append_only_trg
  before update or delete on public.consent_ledger
  for each row execute function public.consent_ledger_append_only();

-- RLS: enabled, all access revoked, only service_role granted
-- INSERT. UPDATE and DELETE are additionally denied at the
-- trigger level (which fires for service_role, unlike RLS).
alter table public.consent_ledger enable row level security;
revoke all on table public.consent_ledger from public, anon, authenticated;
grant insert, select on table public.consent_ledger to service_role;

-- v_current_consent: the "current consent state" view. For each
-- (user_id, consent_type), the most recent row. This is the
-- single read path the operator dashboard and the Flutter app
-- use.
create or replace view public.v_current_consent
with (security_invoker = true) as
select distinct on (cl.user_id, cl.consent_type)
  cl.id,
  cl.user_id,
  cl.consent_type,
  cl.granted,
  cl.policy_version,
  cl.ip_address,
  cl.user_agent,
  cl.created_at
from public.consent_ledger cl
order by cl.user_id, cl.consent_type, cl.created_at desc;
grant select on public.v_current_consent to service_role;
comment on view public.v_current_consent is
  'Current consent state per (user_id, consent_type). One row per (user_id, consent_type); the most recent consent_ledger row.';

-- v_consent_history: the audit view. Every consent_ledger row
-- is visible. The operator dashboard reads this for audit.
create or replace view public.v_consent_history
with (security_invoker = true) as
select
  cl.id,
  cl.user_id,
  cl.consent_type,
  cl.granted,
  cl.policy_version,
  cl.ip_address,
  cl.user_agent,
  cl.created_at
from public.consent_ledger cl
order by cl.created_at desc;
grant select on public.v_consent_history to service_role;
comment on view public.v_consent_history is
  'Audit view: every consent_ledger row, newest first. Operator dashboard reads this for compliance audits.';
