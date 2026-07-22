-- Fence stale workers after lease expiry and reclaim.
--
-- The original queue keyed lease mutations only by job id. A worker that
-- continued after losing its lease could therefore renew or complete a job
-- already claimed by another worker. The token changes on every claim and is
-- required for all worker-owned state transitions.

alter table public.job_outbox
  add column if not exists lease_token uuid;

update public.job_outbox
set lease_token = gen_random_uuid()
where lease_token is null;

alter table public.job_outbox
  alter column lease_token set default gen_random_uuid(),
  alter column lease_token set not null;

create or replace function public.claim_job_outbox(
  p_lease_seconds integer default 60
)
returns setof public.job_outbox
language plpgsql
security invoker
as $$
begin
  if p_lease_seconds < 1 then
    raise exception 'lease_seconds must be positive';
  end if;

  return query
  with candidate as (
    select id
    from public.job_outbox
    where status = 'pending'
      and next_attempt_at <= now()
    order by next_attempt_at, created_at
    for update skip locked
    limit 1
  )
  update public.job_outbox j
  set status = 'running',
      attempts = j.attempts + 1,
      lease_expires_at = now() + make_interval(secs => p_lease_seconds),
      lease_token = gen_random_uuid(),
      updated_at = now()
  from candidate
  where j.id = candidate.id
  returning j.*;
end;
$$;

create or replace function public.reclaim_job_outbox(
  p_max_age_seconds integer default 300
)
returns integer
language plpgsql
security invoker
as $$
declare reclaimed integer;
begin
  if p_max_age_seconds < 0 then
    raise exception 'max_age_seconds cannot be negative';
  end if;

  with stuck as (
    select id, attempts, max_attempts
    from public.job_outbox
    where status = 'running'
      and lease_expires_at < now() - make_interval(secs => p_max_age_seconds)
    for update skip locked
  )
  update public.job_outbox j
  set status = case when stuck.attempts >= stuck.max_attempts
                    then 'dead_letter' else 'pending' end,
      lease_expires_at = null,
      lease_token = gen_random_uuid(),
      next_attempt_at = case when stuck.attempts >= stuck.max_attempts
                             then j.next_attempt_at else now() end,
      updated_at = now()
  from stuck
  where j.id = stuck.id;
  get diagnostics reclaimed = row_count;
  return reclaimed;
end;
$$;
