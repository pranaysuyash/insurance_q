-- Prevent new account-owned data from entering while erasure is pending.
-- The API performs a friendly preflight where possible, but this database
-- boundary closes the race between inventory and deletion across workers.

create or replace function public.reject_active_account_deletion_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.account_deletion_requests adr
    where adr.account_uid = new.owner_id
      and adr.status in ('pending', 'running')
  ) then
    raise exception 'account deletion in progress for owner %', new.owner_id
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists reject_active_account_deletion_document_write_trg
  on public.documents;
create trigger reject_active_account_deletion_document_write_trg
before insert or update of owner_id on public.documents
for each row
execute function public.reject_active_account_deletion_write();

comment on function public.reject_active_account_deletion_write() is
  'Rejects document inserts and ownership transfers while account erasure is pending or running.';
