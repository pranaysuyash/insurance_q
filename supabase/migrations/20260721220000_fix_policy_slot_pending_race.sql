-- Reassert the server-authoritative upload-slot race guard.
--
-- The original migration was already applied in some environments before the
-- pending-reservation guard was added. Keep migration history immutable and
-- repair those environments with an additive replacement.

create or replace function public.reserve_policy_upload_slot(
  p_owner_id text,
  p_source_hash text
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  existing public.policy_slot_reservations;
  active_documents integer;
  active_reservations integer;
  max_policies integer;
  verified_plan text;
  existing_found boolean;
begin
  if nullif(trim(p_owner_id), '') is null or nullif(trim(p_source_hash), '') is null then
    raise exception 'owner and source hash are required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_owner_id, 0));

  update public.policy_slot_reservations
     set state = 'released', updated_at = now()
   where owner_id = p_owner_id
     and state = 'pending'
     and updated_at < now() - interval '30 minutes';

  select * into existing
    from public.policy_slot_reservations
   where owner_id = p_owner_id and source_hash = p_source_hash
   for update;
  existing_found := found;

  if existing_found and existing.state = 'committed' then
    return jsonb_build_object(
      'allowed', true, 'duplicate', true,
      'reservation_id', existing.id, 'document_id', existing.document_id
    );
  end if;

  if existing_found and existing.state = 'pending' then
    return jsonb_build_object(
      'allowed', false, 'reason', 'upload_in_progress',
      'reservation_id', existing.id
    );
  end if;

  select plan_tier into verified_plan
    from public.billing_subscription_states
   where user_uid = p_owner_id
     and source = 'revenuecat_webhook'
     and is_active = true
     and (expires_at is null or expires_at > now())
   limit 1;

  max_policies := case coalesce(verified_plan, 'free')
    when 'family' then 50
    when 'plus' then 10
    else 1
  end;

  select count(*) into active_documents
    from public.documents
   where owner_id = p_owner_id
     and status not in ('deleted', 'withdrawn');

  select count(*) into active_reservations
    from public.policy_slot_reservations
   where owner_id = p_owner_id and state = 'pending';

  if active_documents + active_reservations >= max_policies then
    return jsonb_build_object(
      'allowed', false, 'reason', 'policy_limit_reached',
      'plan_tier', coalesce(verified_plan, 'free'),
      'max_policies', max_policies
    );
  end if;

  if existing_found then
    update public.policy_slot_reservations
       set state = 'pending', document_id = null, updated_at = now()
     where id = existing.id;
  else
    insert into public.policy_slot_reservations (owner_id, source_hash)
    values (p_owner_id, p_source_hash)
    returning * into existing;
  end if;

  return jsonb_build_object(
    'allowed', true, 'duplicate', false,
    'reservation_id', existing.id,
    'plan_tier', coalesce(verified_plan, 'free'),
    'max_policies', max_policies
  );
end;
$$;

revoke all on function public.reserve_policy_upload_slot(text, text)
  from public, anon, authenticated;
grant execute on function public.reserve_policy_upload_slot(text, text)
  to service_role;
