-- CoverWise multi-granularity chunking (Commit 4, ADR-2026-07-20-26)
-- Date: 2026-07-20
-- Purpose: Add chunk_type to document_chunks to support multi-granularity (sentence, paragraph, section, document).

alter table public.document_chunks
  add column if not exists chunk_type text default 'paragraph'
    check (chunk_type in ('sentence', 'paragraph', 'section', 'document'));

create index if not exists document_chunks_chunk_type_idx
  on public.document_chunks (chunk_type);

comment on column public.document_chunks.chunk_type is
  'Granularity of chunk: sentence (high precision), paragraph (default context), section, document (summary).';
