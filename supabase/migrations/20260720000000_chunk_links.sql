-- Migration: 2026_07_20_chunk_links
-- Description: Add section_type to document_chunks and create chunk_links for context expansion

-- Add section_type to document_chunks
ALTER TABLE public.document_chunks
ADD COLUMN IF NOT EXISTS section_type text DEFAULT 'general';

-- Add check constraint for valid section types
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.document_chunks'::regclass
      AND conname = 'check_valid_section_type'
  ) THEN
    ALTER TABLE public.document_chunks
    ADD CONSTRAINT check_valid_section_type
    CHECK (section_type IN (
    'general',
    'definition',
    'exclusion',
    'benefit',
    'sub_limit',
    'schedule',
    'waiting_period',
    'contact'
    ));
  END IF;
END
$$;

-- Index for filtering by section type
CREATE INDEX IF NOT EXISTS idx_document_chunks_section_type ON public.document_chunks(section_type);

-- Create chunk_links table for representing graph-like connections between chunks.
-- The canonical Supabase chunk identity is document_chunks.id (bigint). Keeping
-- the junction table on that same type makes joins owner-safe and prevents the
-- previous UUID/vector-store identity split from returning unusable links.
CREATE TABLE IF NOT EXISTS public.chunk_links (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_chunk_id bigint NOT NULL REFERENCES public.document_chunks(id) ON DELETE CASCADE,
    target_chunk_id bigint NOT NULL REFERENCES public.document_chunks(id) ON DELETE CASCADE,
    link_type text NOT NULL,
    weight float DEFAULT 1.0,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT check_valid_link_type CHECK (link_type IN ('adjacent', 'semantic', 'structural', 'cross_reference')),
    CONSTRAINT unique_chunk_link UNIQUE (source_chunk_id, target_chunk_id, link_type)
);

-- Indexes for fast traversal
CREATE INDEX IF NOT EXISTS idx_chunk_links_source ON public.chunk_links(source_chunk_id);
CREATE INDEX IF NOT EXISTS idx_chunk_links_target ON public.chunk_links(target_chunk_id);

-- Enable RLS and setup policies
ALTER TABLE public.chunk_links ENABLE ROW LEVEL SECURITY;

-- Revoke all permissions initially
REVOKE ALL ON public.chunk_links FROM PUBLIC, anon, authenticated;

-- Only service_role can access chunk_links (since it's an internal pipeline table)
GRANT ALL ON public.chunk_links TO service_role;
