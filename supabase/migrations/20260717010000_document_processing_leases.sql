-- Restart-safe processing lease upgrade.
-- Apply after 001 when an earlier documents table already exists.

alter table public.documents
  add column if not exists source_hash text,
  add column if not exists processing_attempts integer not null default 0,
  add column if not exists processing_started_at timestamptz,
  add column if not exists processing_lease_expires_at timestamptz;

create unique index if not exists documents_owner_source_hash_unique
  on public.documents (owner_id, source_hash)
  where source_hash is not null;

create index if not exists documents_recovery_idx
  on public.documents (status, processing_lease_expires_at);

create or replace function public.claim_document_processing(
  p_document_id uuid,
  p_owner_id text,
  p_lease_seconds integer default 900
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.documents
  set
    status = 'processing',
    processing_attempts = processing_attempts + 1,
    processing_started_at = now(),
    processing_lease_expires_at = now() + make_interval(secs => p_lease_seconds),
    updated_at = now(),
    payload = payload || jsonb_build_object(
      'status', 'processing',
      'processing_attempts', processing_attempts + 1,
      'processing_started_at', now(),
      'processing_lease_expires_at', now() + make_interval(secs => p_lease_seconds)
    )
  where id = p_document_id
    and owner_id = p_owner_id
    and (
      status = 'received'
      or (status = 'processing' and processing_lease_expires_at <= now())
    );
  return found;
end;
$$;

revoke all on function public.claim_document_processing(uuid, text, integer)
  from public, anon, authenticated;
grant execute on function public.claim_document_processing(uuid, text, integer)
  to service_role;
