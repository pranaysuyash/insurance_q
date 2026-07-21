-- CoverWise durable work queue (job_outbox)
-- Date: 2026-07-19
-- Decision: docs/decisions/ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md
-- Convention: follow supabase/migrations/20260718020000_revops_tables.sql and
--   20260718010000_evidence_substrate.sql
--   - public schema
--   - RLS enabled, all access revoked, only service_role granted
--   - if not exists everywhere (idempotent re-runs)
--
-- This is the canonical durable work queue for every async path in
-- CoverWise. The 5 existing async paths (document processing, evidence
-- substrate extraction, Q&A response generation, webhook reconciliation,
-- subscription write-back) all enqueue jobs here; the dispatcher
-- (src/services/job_dispatcher.py) routes by job_type.
--
-- Per ADR-2026-07-19-01: durable work must live where the durable state
-- already lives. The queue is a table, not a managed service.
--
-- Lease / claim / dead-letter semantics:
--   1. A worker claims a job via `UPDATE ... SET status='running',
--      lease_expires_at=now()+lease_seconds WHERE id=$1 AND status='pending'
--      RETURNING *`. The lease is the worker's hold on the job.
--   2. While the job runs, the worker may extend the lease via
--      `UPDATE ... SET lease_expires_at=now()+lease_seconds WHERE id=$1`.
--   3. On success, the worker calls complete(id); on failure, fail(id, err).
--   4. A stuck lease (lease_expires_at < now() AND status='running') is
--      reclaimable by another worker. The reclaim path resets status to
--      'pending' and increments attempts.
--   5. After max_attempts consecutive failures, the job goes to
--      'dead_letter'. The operator dashboard shows dead-letter jobs.

create extension if not exists pgcrypto;

create table if not exists public.job_outbox (
  id uuid primary key default gen_random_uuid(),
  -- The job_type is the dispatch key. New job types require a new entry
  -- in src/services/job_dispatcher.py. The enum is enforced in the
  -- application layer (the SQL CHECK is a safety net, not a contract).
  job_type text not null
    check (job_type in (
      'document_processing',
      'substrate_extraction',
      'qa_response',
      'webhook_reconciliation',
      'subscription_writeback',
      'claim_verification',
      'renewal_diff'
    )),
  -- The payload is opaque to the queue. Each handler validates its own
  -- payload shape. JSONB allows payload evolution without schema
  -- migrations.
  payload jsonb not null,
  status text not null default 'pending'
    check (status in ('pending','running','completed','failed','dead_letter')),
  attempts integer not null default 0,
  -- Default 5 attempts. Operators can override per-job on enqueue.
  max_attempts integer not null default 5,
  -- The earliest time the job is eligible to be claimed. Workers
  -- only pick up rows where next_attempt_at <= now().
  next_attempt_at timestamptz not null default now(),
  -- The worker's lease. NULL when status='pending'. Set on claim.
  -- A stuck lease (now() > lease_expires_at AND status='running') is
  -- reclaimable.
  lease_expires_at timestamptz,
  -- The last error message. Visible in the operator dashboard.
  last_error text,
  -- Optional partition key for multi-worker parallelism. v1 leaves
  -- this NULL (single worker). v2 may set hash(document_id) % N.
  partition_key integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- The pending-row scan is the hot path. Partial index on
-- (next_attempt_at) WHERE status='pending' is the right shape.
create index if not exists job_outbox_pending_idx
  on public.job_outbox (next_attempt_at)
  where status = 'pending';

-- The reclaim scan picks up stuck leases. Partial index on
-- (lease_expires_at) WHERE status='running' is the right shape.
create index if not exists job_outbox_stuck_lease_idx
  on public.job_outbox (lease_expires_at)
  where status = 'running';

-- Dead-letter review.
create index if not exists job_outbox_dead_letter_idx
  on public.job_outbox (created_at desc)
  where status = 'dead_letter';

-- Job-type filtering for per-type dashboards.
create index if not exists job_outbox_job_type_idx
  on public.job_outbox (job_type, created_at desc);

alter table public.job_outbox enable row level security;
revoke all on table public.job_outbox from public, anon, authenticated;
grant select, insert, update, delete on table public.job_outbox to service_role;

-- v_outbox_health: the operator's view of the queue.
-- Returns one row per job_type with the counts and the age of the
-- oldest pending job. Empty job_types are excluded.
create or replace view public.v_outbox_health
with (security_invoker = true) as
select
  job_type,
  count(*) filter (where status = 'pending') as pending_count,
  count(*) filter (where status = 'running') as running_count,
  count(*) filter (where status = 'completed') as completed_count,
  count(*) filter (where status = 'failed') as failed_count,
  count(*) filter (where status = 'dead_letter') as dead_letter_count,
  -- The age of the oldest pending job, in seconds. NULL if none pending.
  extract(epoch from (now() - min(created_at) filter (where status = 'pending')))::integer
    as oldest_pending_age_seconds,
  -- The most recent failure, for the operator dashboard.
  max(last_error) filter (where status = 'dead_letter') as most_recent_dead_letter_error
from public.job_outbox
group by job_type;
grant select on public.v_outbox_health to service_role;
comment on view public.v_outbox_health is
  'Operator view of the job outbox: per-job-type counts and the oldest pending age.';

-- v_outbox_dead_letter: a flat list of dead-letter jobs for the
-- operator to triage.
create or replace view public.v_outbox_dead_letter
with (security_invoker = true) as
select
  id,
  job_type,
  payload,
  attempts,
  last_error,
  created_at,
  updated_at
from public.job_outbox
where status = 'dead_letter'
order by created_at desc;
grant select on public.v_outbox_dead_letter to service_role;
comment on view public.v_outbox_dead_letter is
  'Flat list of dead-letter jobs for the operator to triage and retry.';

-- updated_at trigger (the existing pattern in 2026_07_18_revops_tables.sql
-- uses a function; we replicate that pattern here for consistency).
create or replace function public.job_outbox_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists job_outbox_set_updated_at_trg on public.job_outbox;
create trigger job_outbox_set_updated_at_trg
  before update on public.job_outbox
  for each row execute function public.job_outbox_set_updated_at();
