-- One destructive account-deletion request must have one durable outbox job.
-- Retries are converged by the database, including concurrent API requests.

create unique index if not exists job_outbox_account_deletion_request_idx
  on public.job_outbox ((payload->>'request_id'))
  where job_type = 'account_deletion';
