-- Server-authoritative Q&A consumption and RevenueCat pack grants.
-- Client Hive counters remain an offline UX mirror, never the grant authority.

alter table public.revenuecat_webhook_events
  add column if not exists product_id text;

create table if not exists public.qa_pack_grants (
  id uuid primary key default gen_random_uuid(),
  owner_id text not null,
  provider_event_id text not null unique,
  product_id text not null,
  questions_granted integer not null check (questions_granted > 0),
  questions_remaining integer not null check (questions_remaining >= 0),
  purchased_at timestamptz not null default now(),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists qa_pack_grants_owner_active_idx
  on public.qa_pack_grants (owner_id, expires_at, questions_remaining);

create table if not exists public.qa_usage_events (
  request_id uuid primary key,
  owner_id text not null,
  source text not null check (source in ('subscription', 'pack')),
  pack_grant_id uuid references public.qa_pack_grants(id),
  created_at timestamptz not null default now()
);

create index if not exists qa_usage_events_owner_month_idx
  on public.qa_usage_events (owner_id, source, created_at);

alter table public.qa_pack_grants enable row level security;
alter table public.qa_usage_events enable row level security;
revoke all on public.qa_pack_grants, public.qa_usage_events
  from public, anon, authenticated;
grant select, insert, update on public.qa_pack_grants, public.qa_usage_events to service_role;

-- Extend webhook processing with product-aware consumable grants. The prior
-- function's event ordering/idempotency contract is preserved; pack purchases
-- must not overwrite a subscription state with plan_tier=free.
create or replace function public.process_revenuecat_webhook(
  p_event_id text,
  p_event_type text,
  p_app_user_id text,
  p_event_timestamp_ms bigint,
  p_product_id text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  latest_event_timestamp bigint;
  current_active boolean;
  normalized_plan text;
  inserted_event_id text;
  pack_questions integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_app_user_id, 0));

  insert into public.revenuecat_webhook_events (
    event_id, event_type, app_user_id, product_id, event_timestamp_ms,
    received_at, processing_result
  ) values (
    p_event_id, p_event_type, p_app_user_id, p_product_id, p_event_timestamp_ms,
    now(), 'received'
  ) on conflict (event_id) do nothing
  returning event_id into inserted_event_id;

  if inserted_event_id is null then
    return jsonb_build_object('status', 'duplicate', 'event_id', p_event_id);
  end if;

  select max(event_timestamp_ms) into latest_event_timestamp
    from public.revenuecat_webhook_events
   where app_user_id = p_app_user_id
     and event_id <> p_event_id
     and event_timestamp_ms is not null;

  if p_event_timestamp_ms is not null
     and latest_event_timestamp is not null
     and p_event_timestamp_ms <= latest_event_timestamp then
    update public.revenuecat_webhook_events
       set processed_at = now(), processing_result = 'stale_ignored'
     where event_id = p_event_id;
    return jsonb_build_object('status', 'stale_ignored', 'event_id', p_event_id);
  end if;

  pack_questions := case lower(coalesce(p_product_id, ''))
    when 'coverwise_qa_starter' then 5
    when 'coverwise_qa_value' then 15
    when 'coverwise_qa_pro' then 30
    else null
  end;

  if p_event_type = 'NON_RENEWING_PURCHASE' and pack_questions is not null then
    insert into public.qa_pack_grants (
      owner_id, provider_event_id, product_id, questions_granted,
      questions_remaining, purchased_at, expires_at
    ) values (
      p_app_user_id, p_event_id, p_product_id, pack_questions,
      pack_questions, now(), now() + interval '90 days'
    ) on conflict (provider_event_id) do nothing;

    update public.revenuecat_webhook_events
       set processed_at = now(), processing_result = 'pack_granted'
     where event_id = p_event_id;
    return jsonb_build_object(
      'status', 'pack_granted', 'event_id', p_event_id,
      'questions_granted', pack_questions
    );
  end if;

  normalized_plan := case
    when lower(coalesce(p_product_id, '')) like '%family%' then 'family'
    when lower(coalesce(p_product_id, '')) like '%plus%' then 'plus'
    else 'free'
  end;
  current_active := case
    when p_event_type in (
      'INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION',
      'PRODUCT_CHANGE', 'SUBSCRIPTION_EXTENDED', 'NON_RENEWING_PURCHASE'
    ) then p_expires_at is null or p_expires_at > now()
    when p_event_type in ('CANCELLATION', 'BILLING_ISSUE')
      then p_expires_at is not null and p_expires_at > now()
    when p_event_type = 'TRANSFER' then true
    else false
  end;

  insert into public.billing_subscription_states (
    user_uid, plan_tier, product_id, expires_at, is_active,
    revenuecat_app_user_id, synced_at, source, last_event_id, updated_at
  ) values (
    p_app_user_id,
    case when current_active then normalized_plan else 'free' end,
    p_product_id, p_expires_at, current_active, p_app_user_id,
    now(), 'revenuecat_webhook', p_event_id, now()
  ) on conflict (user_uid) do update set
    plan_tier = excluded.plan_tier,
    product_id = excluded.product_id,
    expires_at = excluded.expires_at,
    is_active = excluded.is_active,
    revenuecat_app_user_id = excluded.revenuecat_app_user_id,
    synced_at = excluded.synced_at,
    source = excluded.source,
    last_event_id = excluded.last_event_id,
    updated_at = excluded.updated_at;

  update public.revenuecat_webhook_events
     set processed_at = now(), processing_result = 'processed'
   where event_id = p_event_id;
  return jsonb_build_object(
    'status', 'processed', 'event_id', p_event_id,
    'event_type', p_event_type,
    'plan_tier', case when current_active then normalized_plan else 'free' end,
    'is_active', current_active
  );
end;
$$;

revoke all on function public.process_revenuecat_webhook(
  text, text, text, bigint, text, timestamptz
) from public, anon, authenticated;
grant execute on function public.process_revenuecat_webhook(
  text, text, text, bigint, text, timestamptz
) to service_role;

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
  pack public.qa_pack_grants;
  subscription_limit integer;
  subscription_used integer;
  verified_plan text;
begin
  if nullif(trim(p_owner_id), '') is null or p_request_id is null then
    raise exception 'owner and request id are required' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_owner_id, 0));

  select * into prior from public.qa_usage_events
   where request_id = p_request_id;
  if found then
    if prior.owner_id <> p_owner_id then
      raise exception 'request id belongs to another owner' using errcode = '42501';
    end if;
    return jsonb_build_object(
      'allowed', true, 'duplicate', true, 'source', prior.source
    );
  end if;

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

  select count(*) into subscription_used
    from public.qa_usage_events
   where owner_id = p_owner_id
     and source = 'subscription'
     and created_at >= date_trunc('month', now());

  if subscription_used < subscription_limit then
    insert into public.qa_usage_events (request_id, owner_id, source)
    values (p_request_id, p_owner_id, 'subscription');
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
    insert into public.qa_usage_events (request_id, owner_id, source, pack_grant_id)
    values (p_request_id, p_owner_id, 'pack', pack.id);
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

revoke all on function public.reserve_qa_question(text, uuid)
  from public, anon, authenticated;
grant execute on function public.reserve_qa_question(text, uuid) to service_role;

comment on table public.qa_usage_events is
  'Idempotent server-side Q&A consumption; request_id prevents duplicate charges.';
