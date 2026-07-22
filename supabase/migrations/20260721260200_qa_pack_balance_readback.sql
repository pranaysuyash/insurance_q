-- Server-authoritative readback for cross-device Q&A pack convergence.
-- This function deliberately exposes only active, spendable grants.

create or replace function public.get_qa_pack_balance(p_owner_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  packs jsonb;
begin
  if nullif(trim(p_owner_id), '') is null then
    raise exception 'owner id is required';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', id,
        'product_id', product_id,
        'questions_granted', questions_granted,
        'questions_remaining', questions_remaining,
        'purchased_at', purchased_at,
        'expires_at', expires_at
      ) order by expires_at, purchased_at, id
    ),
    '[]'::jsonb
  )
  into packs
  from public.qa_pack_grants
  where owner_id = p_owner_id
    and questions_remaining > 0
    and expires_at > now();

  return jsonb_build_object(
    'packs', packs,
    'pack_questions_remaining', coalesce(
      (
        select sum(questions_remaining)
        from public.qa_pack_grants
        where owner_id = p_owner_id
          and questions_remaining > 0
          and expires_at > now()
      ),
      0
    )
  );
end;
$$;

revoke all on function public.get_qa_pack_balance(text) from public, anon, authenticated;
grant execute on function public.get_qa_pack_balance(text) to service_role;
