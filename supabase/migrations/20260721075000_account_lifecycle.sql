-- Durable account lifecycle requests.
-- Account deletion is intentionally separate from auth.users so that the
-- operator can see, retry, and verify every request after the API returns.

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  account_uid text not null,
  status text not null default 'pending'
    check (status in ('pending', 'running', 'completed', 'failed')),
  stage_state jsonb not null default '{}'::jsonb,
  last_error_class text,
  requested_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

create unique index if not exists account_deletion_one_active_idx
  on public.account_deletion_requests (account_uid)
  where status in ('pending', 'running');

create index if not exists account_deletion_account_idx
  on public.account_deletion_requests (account_uid, requested_at desc);

alter table public.account_deletion_requests enable row level security;
revoke all on table public.account_deletion_requests from public, anon, authenticated;
grant select, insert, update on table public.account_deletion_requests to service_role;

drop trigger if exists account_deletion_set_updated_at_trg
  on public.account_deletion_requests;
create trigger account_deletion_set_updated_at_trg
  before update on public.account_deletion_requests
  for each row execute function public.job_outbox_set_updated_at();

-- Extend the existing queue contract without creating a second queue.
alter table public.job_outbox drop constraint if exists job_outbox_job_type_check;
alter table public.job_outbox add constraint job_outbox_job_type_check check (job_type in (
  'document_processing', 'substrate_extraction', 'qa_response',
  'webhook_reconciliation', 'subscription_writeback', 'claim_verification',
  'renewal_diff', 'account_deletion'
));

comment on table public.account_deletion_requests is
  'Auditable, retryable account erasure requests. Source deletion is not reported complete until all stages succeed.';
