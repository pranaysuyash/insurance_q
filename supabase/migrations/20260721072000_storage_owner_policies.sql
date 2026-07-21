-- Private source-document storage. The API normally uses service_role, but
-- direct authenticated access must still be owner-scoped if enabled later.

drop policy if exists coverwise_documents_select on storage.objects;
drop policy if exists coverwise_documents_insert on storage.objects;
drop policy if exists coverwise_documents_update on storage.objects;
drop policy if exists coverwise_documents_delete on storage.objects;

create policy coverwise_documents_select
on storage.objects for select
to authenticated
using (
  bucket_id = 'coverwise-documents'
  and exists (
    select 1
    from public.documents d
    where d.id::text = (storage.foldername(name))[2]
      and d.owner_id = (select auth.uid())::text
  )
);

create policy coverwise_documents_insert
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'coverwise-documents'
  and exists (
    select 1
    from public.documents d
    where d.id::text = (storage.foldername(name))[2]
      and d.owner_id = (select auth.uid())::text
  )
);

create policy coverwise_documents_update
on storage.objects for update
to authenticated
using (
  bucket_id = 'coverwise-documents'
  and exists (
    select 1
    from public.documents d
    where d.id::text = (storage.foldername(name))[2]
      and d.owner_id = (select auth.uid())::text
  )
)
with check (
  bucket_id = 'coverwise-documents'
  and exists (
    select 1
    from public.documents d
    where d.id::text = (storage.foldername(name))[2]
      and d.owner_id = (select auth.uid())::text
  )
);

create policy coverwise_documents_delete
on storage.objects for delete
to authenticated
using (
  bucket_id = 'coverwise-documents'
  and exists (
    select 1
    from public.documents d
    where d.id::text = (storage.foldername(name))[2]
      and d.owner_id = (select auth.uid())::text
  )
);
