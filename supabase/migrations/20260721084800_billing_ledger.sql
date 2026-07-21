-- Canonical server-side entitlement state and RevenueCat delivery fence.
-- SQLite remains a development fallback only; production uses this ledger.

create table if not exists public.billing_subscription_states (
  user_uid text primary key,
  plan_tier text not null default 'free'
    check (plan_tier in ('free', 'plus', 'family')),
  product_id text,
  expires_at timestamptz,
  is_active boolean not null default false,
  revenuecat_app_user_id text,
  synced_at timestamptz not null default now(),
  source text not null default 'client_sync'
    check (source in ('client_sync', 'revenuecat_webhook')),
  last_event_id text,
  updated_at timestamptz not null default now()
);

create table if not exists public.revenuecat_webhook_events (
  event_id text primary key,
  event_type text not null,
  app_user_id text not null,
  event_timestamp_ms bigint,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_result text not null,
  error_class text
);

create index if not exists billing_subscription_states_active_idx
  on public.billing_subscription_states (user_uid, is_active, updated_at desc);
create index if not exists revenuecat_webhook_events_user_time_idx
  on public.revenuecat_webhook_events (app_user_id, event_timestamp_ms desc);

alter table public.billing_subscription_states enable row level security;
alter table public.revenuecat_webhook_events enable row level security;
revoke all on public.billing_subscription_states, public.revenuecat_webhook_events
  from public, anon, authenticated;
grant select, insert, update on public.billing_subscription_states to service_role;
grant select, insert, update on public.revenuecat_webhook_events to service_role;

-- One database transaction owns idempotency, ordering, and entitlement writeback.
-- The function is invoker-security: only the server-only service_role grant can
-- call it, and it does not create a public authorization bypass.
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
begin
  -- Serialize one account's event stream so timestamp ordering is valid even
  -- when two provider deliveries arrive concurrently.
  perform pg_advisory_xact_lock(hashtextextended(p_app_user_id, 0));

  insert into public.revenuecat_webhook_events (
    event_id, event_type, app_user_id, event_timestamp_ms,
    received_at, processing_result
  ) values (
    p_event_id, p_event_type, p_app_user_id, p_event_timestamp_ms,
    now(), 'received'
  )
  on conflict (event_id) do nothing
  returning event_id into inserted_event_id;

  if inserted_event_id is null then
    return jsonb_build_object('status', 'duplicate', 'event_id', p_event_id);
  end if;

  select max(event_timestamp_ms)
    into latest_event_timestamp
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
    return jsonb_build_object(
      'status', 'stale_ignored', 'event_id', p_event_id,
      'event_type', p_event_type
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
  )
  on conflict (user_uid) do update set
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

comment on table public.billing_subscription_states is
  'Canonical server-authoritative entitlement state; service-role only.';
comment on table public.revenuecat_webhook_events is
  'Idempotent, ordered RevenueCat delivery audit; service-role only.';
