-- Server-authoritative policy-slot reservation.
-- The mobile count remains a UX hint; this boundary owns concurrent uploads.

create table if not exists public.policy_slot_reservations (
  id uuid primary key default gen_random_uuid(),
  owner_id text not null,
  source_hash text not null,
  state text not null default 'pending'
    check (state in ('pending', 'committed', 'released')),
  document_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, source_hash)
);

create index if not exists policy_slot_reservations_owner_state_idx
  on public.policy_slot_reservations (owner_id, state, updated_at);

alter table public.policy_slot_reservations enable row level security;
revoke all on public.policy_slot_reservations from public, anon, authenticated;
grant select, insert, update on public.policy_slot_reservations to service_role;

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

  -- Serialize the account's count plus reservation transition. This is the
  -- race boundary that a client-side document count cannot provide.
  perform pg_advisory_xact_lock(hashtextextended(p_owner_id, 0));

  -- A crashed request cannot hold a slot forever. Processing persistence is
  -- expected to finalize quickly; stale pending reservations are reclaimable.
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

  -- Another request is already creating this exact source. Do not hand the
  -- same pending reservation to both callers: only one request may own the
  -- eventual finalize transition. The caller can retry after the first
  -- request reaches a terminal state or the bounded stale window reclaims it.
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

create or replace function public.finalize_policy_upload_slot(
  p_reservation_id uuid,
  p_owner_id text,
  p_document_id uuid
)
returns boolean
language sql
security invoker
set search_path = public
as $$
  update public.policy_slot_reservations
     set state = 'committed', document_id = p_document_id, updated_at = now()
   where id = p_reservation_id
     and owner_id = p_owner_id
     and state = 'pending'
  returning true;
$$;

create or replace function public.release_policy_upload_slot(
  p_reservation_id uuid,
  p_owner_id text
)
returns boolean
language sql
security invoker
set search_path = public
as $$
  update public.policy_slot_reservations
     set state = 'released', updated_at = now()
   where id = p_reservation_id
     and owner_id = p_owner_id
     and state in ('pending', 'committed')
  returning true;
$$;

revoke all on function public.reserve_policy_upload_slot(text, text)
  from public, anon, authenticated;
revoke all on function public.finalize_policy_upload_slot(uuid, text, uuid)
  from public, anon, authenticated;
revoke all on function public.release_policy_upload_slot(uuid, text)
  from public, anon, authenticated;
grant execute on function public.reserve_policy_upload_slot(text, text) to service_role;
grant execute on function public.finalize_policy_upload_slot(uuid, text, uuid) to service_role;
grant execute on function public.release_policy_upload_slot(uuid, text) to service_role;

comment on table public.policy_slot_reservations is
  'Owner-locked upload-slot reservations; committed slots are counted by entitlement enforcement.';
