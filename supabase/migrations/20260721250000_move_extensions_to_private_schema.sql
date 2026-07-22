-- Keep database extensions out of the exposed public schema while preserving
-- the existing typed vector and trigram retrieval contract.

create schema if not exists extensions;
alter extension vector set schema extensions;
alter extension pg_trgm set schema extensions;

alter function public.match_document_chunks(
  extensions.vector, text, integer, double precision
)
  set search_path = extensions, public;
alter function public.match_document_chunks(
  extensions.vector, text, integer, double precision, uuid[], text, text
)
  set search_path = extensions, public;
alter function public.match_document_chunks_fts(
  text, text, integer, double precision, uuid[]
)
  set search_path = extensions, public;
