-- Enable pg_trgm extension
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Add content_tsv tsvector column to document_chunks
ALTER TABLE public.document_chunks
ADD COLUMN IF NOT EXISTS content_tsv tsvector 
GENERATED ALWAYS AS (to_tsvector('english', coalesce(content, ''))) STORED;

-- Create GIN index on content_tsv
CREATE INDEX IF NOT EXISTS document_chunks_content_tsv_idx ON public.document_chunks USING GIN (content_tsv);

-- Create GIN trigram index on content
CREATE INDEX IF NOT EXISTS document_chunks_content_trgm_idx ON public.document_chunks USING GIN (content gin_trgm_ops);

-- Create match_document_chunks_fts function
CREATE OR REPLACE FUNCTION public.match_document_chunks_fts(
  query_text text,
  match_owner_id text,
  match_count int DEFAULT 10,
  similarity_threshold double precision DEFAULT 0.0,
  match_document_ids uuid[] DEFAULT NULL
)
RETURNS TABLE (
  id bigint,
  document_id uuid,
  content text,
  metadata jsonb,
  similarity double precision
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
AS $$
BEGIN
  RETURN QUERY
  WITH ts_results AS (
    SELECT
      d.id,
      d.document_id,
      d.content,
      d.metadata,
      ts_rank(d.content_tsv, websearch_to_tsquery('english', query_text)) AS similarity
    FROM public.document_chunks d
    WHERE d.owner_id = match_owner_id
      AND (match_document_ids IS NULL OR d.document_id = ANY(match_document_ids))
      AND d.content_tsv @@ websearch_to_tsquery('english', query_text)
  ),
  trgm_results AS (
    SELECT
      d.id,
      d.document_id,
      d.content,
      d.metadata,
      strict_word_similarity(query_text, d.content) AS similarity
    FROM public.document_chunks d
    WHERE d.owner_id = match_owner_id
      AND (match_document_ids IS NULL OR d.document_id = ANY(match_document_ids))
      AND d.content % query_text
  ),
  combined_results AS (
    SELECT * FROM ts_results
    UNION ALL
    SELECT * FROM trgm_results
  )
  SELECT
    cr.id,
    cr.document_id,
    cr.content,
    cr.metadata,
    MAX(cr.similarity)::double precision AS similarity
  FROM combined_results cr
  WHERE cr.similarity > similarity_threshold
  GROUP BY cr.id, cr.document_id, cr.content, cr.metadata
  ORDER BY similarity DESC
  LIMIT least(match_count, 50);
END;
$$;

-- Grant execute to service_role (and optionally postgres/anon/authenticated)
REVOKE ALL ON FUNCTION public.match_document_chunks_fts(text, text, integer, double precision, uuid[])
  FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.match_document_chunks_fts(text, text, integer, double precision, uuid[])
  TO service_role;
