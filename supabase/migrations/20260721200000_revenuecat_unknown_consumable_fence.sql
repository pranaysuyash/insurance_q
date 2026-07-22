-- Keep unknown RevenueCat consumables out of subscription reconciliation.
-- A product outside the server-owned pack catalogue must not silently
-- overwrite a verified subscription with plan_tier=free.

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
    p_event_id, p_event_type, p_app_user_id, p_product_id,
    p_event_timestamp_ms, now(), 'received'
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

  if p_event_type = 'NON_RENEWING_PURCHASE' then
    if pack_questions is null then
      update public.revenuecat_webhook_events
         set processed_at = now(), processing_result = 'unsupported_product'
       where event_id = p_event_id;
      return jsonb_build_object(
        'status', 'unsupported_product', 'event_id', p_event_id,
        'event_type', p_event_type
      );
    end if;

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
      'PRODUCT_CHANGE', 'SUBSCRIPTION_EXTENDED'
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
