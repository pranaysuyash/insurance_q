-- Make the evidence read path version-aware.
--
-- extracted_fields is append-only, so a parser rerun can create multiple rows
-- for the same (document_id, field_name). The UI must not see every historical
-- value merely because each row has evidence. Select the latest extracted
-- field first, then select the strongest evidence attached to that field.
create or replace view public.v_field_citations
with (security_invoker = true) as
with latest_fields as (
  select distinct on (ef.document_id, ef.field_name)
    ef.*
  from public.extracted_fields ef
  order by ef.document_id, ef.field_name, ef.created_at desc, ef.id desc
), strongest_evidence as (
  select distinct on (fe.extracted_field_id)
    fe.*
  from public.field_evidence fe
  order by
    fe.extracted_field_id,
    fe.evidence_strength desc,
    fe.created_at desc,
    fe.id desc
)
select
  ef.document_id,
  ef.field_name,
  ef.value,
  ef.value_type,
  ef.confidence as field_confidence,
  ef.parser_kind,
  fe.cite_string,
  fe.evidence_strength,
  pa.page_number,
  pa.image_uri,
  pa.sha256 as page_sha256
from latest_fields ef
join strongest_evidence fe on fe.extracted_field_id = ef.id
join public.page_artifacts pa on pa.id = fe.page_artifact_id;

grant select on public.v_field_citations to service_role;

comment on view public.v_field_citations is
  'Single read path for policy detail: latest extracted field per document/field with strongest evidence.';
