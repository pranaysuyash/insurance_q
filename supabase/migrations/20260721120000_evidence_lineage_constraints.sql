-- Enforce evidence lineage at the substrate boundary.
--
-- Independent foreign keys prove that each referenced row exists, but they do
-- not prove that a field, page, and span belong to the same document/page.
-- This trigger makes cross-document and cross-page evidence impossible for
-- every writer, including future service-role jobs.

do $$
begin
  if exists (
    select 1
    from public.field_evidence fe
    join public.extracted_fields ef on ef.id = fe.extracted_field_id
    join public.page_artifacts pa on pa.id = fe.page_artifact_id
    where ef.document_id <> pa.document_id
  ) then
    raise exception 'Existing field_evidence contains cross-document links';
  end if;

  if exists (
    select 1
    from public.field_evidence fe
    join public.source_spans ss on ss.id = fe.source_span_id
    where ss.page_artifact_id <> fe.page_artifact_id
  ) then
    raise exception 'Existing field_evidence contains cross-page span links';
  end if;
end
$$;

create or replace function public.validate_field_evidence_lineage()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  field_document_id uuid;
  page_document_id uuid;
  span_page_artifact_id uuid;
begin
  select document_id into field_document_id
  from public.extracted_fields
  where id = new.extracted_field_id;

  select document_id into page_document_id
  from public.page_artifacts
  where id = new.page_artifact_id;

  if field_document_id is distinct from page_document_id then
    raise exception
      'field_evidence lineage mismatch: field and page belong to different documents';
  end if;

  if new.source_span_id is not null then
    select page_artifact_id into span_page_artifact_id
    from public.source_spans
    where id = new.source_span_id;

    if span_page_artifact_id is distinct from new.page_artifact_id then
      raise exception
        'field_evidence lineage mismatch: span belongs to a different page';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists validate_field_evidence_lineage_trigger
  on public.field_evidence;
create trigger validate_field_evidence_lineage_trigger
before insert or update of extracted_field_id, page_artifact_id, source_span_id
on public.field_evidence
for each row
execute function public.validate_field_evidence_lineage();

comment on function public.validate_field_evidence_lineage() is
  'Rejects field evidence that crosses document or page lineage boundaries.';
