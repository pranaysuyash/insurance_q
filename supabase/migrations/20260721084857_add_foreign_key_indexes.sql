-- Foreign-key indexes for joins and ON DELETE SET NULL/CASCADE paths.
-- The leading columns of existing composite/unique indexes already cover
-- release_id, run_id, answer_id, model_run_id, and document_id; these are
-- the remaining referenced columns without a suitable leading index.

create index if not exists dataset_items_source_chunk_idx
  on public.dataset_items (source_chunk_id)
  where source_chunk_id is not null;

create index if not exists dataset_items_consent_record_idx
  on public.dataset_items (consent_record_id)
  where consent_record_id is not null;

create index if not exists retrieval_candidates_document_idx
  on public.retrieval_candidates (document_id)
  where document_id is not null;

create index if not exists answer_evidence_chunk_idx
  on public.answer_evidence (chunk_id)
  where chunk_id is not null;

create index if not exists answer_evidence_document_idx
  on public.answer_evidence (document_id)
  where document_id is not null;

create index if not exists document_sections_parent_idx
  on public.document_sections (parent_section_id)
  where parent_section_id is not null;

create index if not exists document_sections_source_chunk_idx
  on public.document_sections (source_chunk_id)
  where source_chunk_id is not null;
