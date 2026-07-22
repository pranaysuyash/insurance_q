-- Make Q&A usage reservations recoverable when RAG/provider work fails.
-- Existing rows represent already-consumed usage; only new reservations use
-- the reserved state.

alter table public.qa_usage_events
  add column if not exists status text not null default 'consumed'
    check (status in ('reserved', 'consumed', 'released')),
  add column if not exists finalized_at timestamptz,
  add column if not exists released_at timestamptz,
  add column if not exists reserved_at timestamptz;

create index if not exists qa_usage_events_owner_active_idx
  on public.qa_usage_events (owner_id, source, status, created_at);

create or replace function public.reserve_qa_question(
  p_owner_id text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  prior public.qa_usage_events;
  stale public.qa_usage_events;
  pack public.qa_pack_grants;
  subscription_limit integer;
  subscription_used integer;
  verified_plan text;
begin
  if nullif(trim(p_owner_id), '') is null or p_request_id is null then
    raise exception 'owner and request id are required' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_owner_id, 0));

  -- A provider timeout can prevent the API from reaching its release call.
  -- Reclaim only reservations older than the bounded Q&A execution window;
  -- normal in-flight requests remain counted and protected by the owner lock.
  for stale in
    select * from public.qa_usage_events
     where owner_id = p_owner_id and status = 'reserved'
       and reserved_at is not null
       and reserved_at < now() - interval '15 minutes'
     for update
  loop
    update public.qa_usage_events
       set status = 'released', released_at = now()
     where request_id = stale.request_id;
    if stale.source = 'pack' then
      update public.qa_pack_grants
         set questions_remaining = questions_remaining + 1, updated_at = now()
       where id = stale.pack_grant_id;
    end if;
  end loop;

  select plan_tier into verified_plan
    from public.billing_subscription_states
   where user_uid = p_owner_id
     and source = 'revenuecat_webhook'
     and is_active = true
     and (expires_at is null or expires_at > now())
   limit 1;

  subscription_limit := case coalesce(verified_plan, 'free')
    when 'family' then 500
    when 'plus' then 200
    else 20
  end;

  select * into prior from public.qa_usage_events
   where request_id = p_request_id;
  if found then
    if prior.owner_id <> p_owner_id then
      raise exception 'request id belongs to another owner' using errcode = '42501';
    end if;
    if prior.status <> 'released' then
      return jsonb_build_object(
        'allowed', true, 'duplicate', true, 'source', prior.source,
        'status', prior.status
      );
    end if;

    -- A retry may reuse the same request id after a known failure. Reopen the
    -- same reservation only if the budget is still available.
    if prior.source = 'pack' then
      update public.qa_pack_grants
         set questions_remaining = questions_remaining - 1, updated_at = now()
       where id = prior.pack_grant_id
         and questions_remaining > 0
         and expires_at > now();
      if not found then
        return jsonb_build_object('allowed', false, 'reason', 'qa_budget_exhausted');
      end if;
    else
      select count(*) into subscription_used
        from public.qa_usage_events
       where owner_id = p_owner_id
         and source = 'subscription'
         and status in ('reserved', 'consumed')
         and created_at >= date_trunc('month', now());
      if subscription_used >= subscription_limit then
        return jsonb_build_object('allowed', false, 'reason', 'qa_budget_exhausted');
      end if;
    end if;
    update public.qa_usage_events
       set status = 'reserved', released_at = null, finalized_at = null,
           reserved_at = now()
     where request_id = p_request_id;
    return jsonb_build_object(
      'allowed', true, 'duplicate', true, 'reopened', true,
      'source', prior.source
    );
  end if;

  select count(*) into subscription_used
    from public.qa_usage_events
   where owner_id = p_owner_id
     and source = 'subscription'
     and status in ('reserved', 'consumed')
     and created_at >= date_trunc('month', now());

  if subscription_used < subscription_limit then
    insert into public.qa_usage_events (
      request_id, owner_id, source, status, reserved_at
    ) values (p_request_id, p_owner_id, 'subscription', 'reserved', now());
    return jsonb_build_object(
      'allowed', true, 'duplicate', false, 'source', 'subscription',
      'remaining', subscription_limit - subscription_used - 1
    );
  end if;

  select * into pack from public.qa_pack_grants
   where owner_id = p_owner_id
     and questions_remaining > 0
     and expires_at > now()
   order by expires_at, purchased_at
   limit 1 for update;

  if found then
    update public.qa_pack_grants
       set questions_remaining = questions_remaining - 1, updated_at = now()
     where id = pack.id;
    insert into public.qa_usage_events (
      request_id, owner_id, source, pack_grant_id, status, reserved_at
    ) values (p_request_id, p_owner_id, 'pack', pack.id, 'reserved', now());
    return jsonb_build_object(
      'allowed', true, 'duplicate', false, 'source', 'pack',
      'remaining', pack.questions_remaining - 1
    );
  end if;

  return jsonb_build_object(
    'allowed', false, 'reason', 'qa_budget_exhausted',
    'plan_tier', coalesce(verified_plan, 'free')
  );
end;
$$;

create or replace function public.finalize_qa_question(
  p_owner_id text, p_request_id uuid
)
returns jsonb
language plpgsql security invoker set search_path = public
as $$
begin
  update public.qa_usage_events
     set status = 'consumed', finalized_at = now()
   where request_id = p_request_id and owner_id = p_owner_id
     and status = 'reserved';
  if not found then
    return jsonb_build_object('status', 'already_finalized_or_missing');
  end if;
  return jsonb_build_object('status', 'consumed');
end;
$$;

create or replace function public.release_qa_question(
  p_owner_id text, p_request_id uuid
)
returns jsonb
language plpgsql security invoker set search_path = public
as $$
declare
  released public.qa_usage_events;
begin
  update public.qa_usage_events
     set status = 'released', released_at = now()
   where request_id = p_request_id and owner_id = p_owner_id
     and status = 'reserved'
   returning * into released;
  if not found then
    return jsonb_build_object('status', 'already_released_or_missing');
  end if;
  if released.source = 'pack' then
    update public.qa_pack_grants
       set questions_remaining = questions_remaining + 1, updated_at = now()
     where id = released.pack_grant_id;
  end if;
  return jsonb_build_object('status', 'released', 'source', released.source);
end;
$$;

revoke all on function public.finalize_qa_question(text, uuid) from public, anon, authenticated;
revoke all on function public.release_qa_question(text, uuid) from public, anon, authenticated;
grant execute on function public.finalize_qa_question(text, uuid) to service_role;
grant execute on function public.release_qa_question(text, uuid) to service_role;

comment on table public.qa_usage_events is
  'Idempotent Q&A reservations; request_id prevents duplicate charges and status enables failure release.';
