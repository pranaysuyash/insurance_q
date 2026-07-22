-- Keep verified consumables with the workspace during anonymous -> account
-- conversion. The existing claim RPC remains the single transfer boundary.

create or replace function public.claim_anonymous_documents(
  p_anonymous_owner text,
  p_account_owner text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  transferred integer;
begin
  if nullif(trim(p_anonymous_owner), '') is null
     or nullif(trim(p_account_owner), '') is null
     or p_anonymous_owner = p_account_owner then
    raise exception 'distinct owners are required';
  end if;

  update public.documents
  set owner_id = p_account_owner,
      payload = jsonb_set(payload, '{user_uid}', to_jsonb(p_account_owner), true),
      updated_at = now()
  where owner_id = p_anonymous_owner;
  get diagnostics transferred = row_count;

  update public.qa_pack_grants
  set owner_id = p_account_owner,
      updated_at = now()
  where owner_id = p_anonymous_owner;

  return transferred;
end;
$$;

revoke all on function public.claim_anonymous_documents(text, text)
  from public, anon, authenticated;
grant execute on function public.claim_anonymous_documents(text, text)
  to service_role;
