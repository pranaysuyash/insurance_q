-- Preserve historical account-deletion jobs while allowing a dead-lettered
-- request to receive one new active retry job.

drop index if exists public.job_outbox_account_deletion_request_idx;

create unique index if not exists job_outbox_account_deletion_request_idx
  on public.job_outbox ((payload->>'request_id'))
  where job_type = 'account_deletion'
    and status in ('pending', 'running');
