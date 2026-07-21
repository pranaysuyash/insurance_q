-- FTS searches retrieval/context text but returns immutable source text for
-- citations. This mirrors the dense retrieval contract.

create or replace function public.match_document_chunks_fts(
  query_text text,
  match_owner_id text,
  match_count int default 10,
  similarity_threshold double precision default 0.0,
  match_document_ids uuid[] default null
)
returns table (
  id bigint,
  document_id uuid,
  content text,
  metadata jsonb,
  similarity double precision
)
language sql
stable
security invoker
as $$
  with candidates as (
    select d.id, d.document_id, d.source_text, d.metadata,
      ts_rank(d.content_tsv, websearch_to_tsquery('english', query_text))::double precision as similarity
    from public.document_chunks d
    where d.owner_id = match_owner_id
      and (match_document_ids is null or d.document_id = any(match_document_ids))
      and d.content_tsv @@ websearch_to_tsquery('english', query_text)
    union all
    select d.id, d.document_id, d.source_text, d.metadata,
      strict_word_similarity(query_text, d.content)::double precision as similarity
    from public.document_chunks d
    where d.owner_id = match_owner_id
      and (match_document_ids is null or d.document_id = any(match_document_ids))
      and d.content % query_text
  )
  select c.id, c.document_id, c.source_text as content, c.metadata,
    max(c.similarity) as similarity
  from candidates c
  where c.similarity > similarity_threshold
  group by c.id, c.document_id, c.source_text, c.metadata
  order by similarity desc
  limit least(match_count, 50);
$$;

revoke all on function public.match_document_chunks_fts(text, text, integer, double precision, uuid[])
  from public, anon, authenticated;
grant execute on function public.match_document_chunks_fts(text, text, integer, double precision, uuid[])
  to service_role;
