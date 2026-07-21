-- CoverWise retrieval contract: immutable source text, explicit embedding
-- identity, and server-side document filtering.

alter table public.document_chunks
  add column if not exists source_text text,
  add column if not exists retrieval_text text,
  add column if not exists embedding_model text,
  add column if not exists embedding_dimensions integer,
  add column if not exists embedding_version text;

update public.document_chunks
set source_text = coalesce(source_text, content),
    retrieval_text = coalesce(retrieval_text, content),
    embedding_model = coalesce(embedding_model, metadata->>'embedding_model', 'legacy-1536'),
    embedding_dimensions = coalesce(embedding_dimensions, 1536),
    embedding_version = coalesce(embedding_version, 'v1')
where source_text is null
   or retrieval_text is null
   or embedding_model is null
   or embedding_dimensions is null
   or embedding_version is null;

alter table public.document_chunks
  alter column source_text set not null,
  alter column retrieval_text set not null,
  alter column embedding_model set not null,
  alter column embedding_dimensions set not null,
  alter column embedding_version set not null;

alter table public.document_chunks
  add constraint document_chunks_embedding_dimensions_positive
  check (embedding_dimensions > 0);

create index if not exists document_chunks_embedding_contract_idx
  on public.document_chunks (embedding_model, embedding_version, embedding_dimensions);

create or replace function public.match_document_chunks(
  query_embedding vector(1536),
  match_owner_id text,
  match_count integer default 8,
  match_threshold double precision default 0.20,
  match_document_ids uuid[] default null,
  match_embedding_model text default 'text-embedding-3-small',
  match_embedding_version text default 'v1'
)
returns table (id bigint, document_id uuid, content text, metadata jsonb, similarity double precision)
language sql stable security invoker
as $$
  select c.id, c.document_id, c.source_text, c.metadata,
         1 - (c.embedding <=> query_embedding) as similarity
  from public.document_chunks c
  where c.owner_id = match_owner_id
    and c.embedding is not null
    and c.embedding_model = match_embedding_model
    and c.embedding_version = match_embedding_version
    and c.embedding_dimensions = 1536
    and (match_document_ids is null or c.document_id = any(match_document_ids))
    and 1 - (c.embedding <=> query_embedding) >= match_threshold
  order by c.embedding <=> query_embedding
  limit least(match_count, 50);
$$;

revoke all on function public.match_document_chunks(vector(1536), text, integer, double precision, uuid[], text, text)
  from public, anon, authenticated;
grant execute on function public.match_document_chunks(vector(1536), text, integer, double precision, uuid[], text, text)
  to service_role;

-- Retire the earlier unconstrained overloads so callers cannot bypass the
-- embedding-contract and document-filter arguments.
revoke all on function public.match_document_chunks(vector(1536), text, integer, double precision)
  from public, anon, authenticated, service_role;
revoke all on function public.match_document_chunks_fts(text, text, integer, double precision)
  from public, anon, authenticated, service_role;
