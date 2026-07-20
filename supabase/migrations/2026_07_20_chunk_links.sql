-- Migration: 2026_07_20_chunk_links
-- Description: Add section_type to document_chunks and create chunk_links for context expansion

-- Add section_type to document_chunks
ALTER TABLE document_chunks
ADD COLUMN section_type text DEFAULT 'general';

-- Add check constraint for valid section types
ALTER TABLE document_chunks
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

-- Index for filtering by section type
CREATE INDEX idx_document_chunks_section_type ON document_chunks(section_type);

-- Create chunk_links table for representing graph-like connections between chunks
-- ADR-26: We use a normalized junction table rather than JSON arrays inside chunks
-- to allow bidirectional querying and future algorithms like PageRank over chunks.
-- We do NOT use explicit FOREIGN KEYs to document_chunks here because chunks are
-- identified by their vector store UUIDs, which might not be backed by primary keys
-- in this specific DB if multi-backend logic splits storage. Application handles consistency.
CREATE TABLE chunk_links (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_chunk_id uuid NOT NULL,
    target_chunk_id uuid NOT NULL,
    link_type text NOT NULL,
    weight float DEFAULT 1.0,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT check_valid_link_type CHECK (link_type IN ('adjacent', 'semantic', 'structural', 'cross_reference')),
    CONSTRAINT unique_chunk_link UNIQUE (source_chunk_id, target_chunk_id, link_type)
);

-- Indexes for fast traversal
CREATE INDEX idx_chunk_links_source ON chunk_links(source_chunk_id);
CREATE INDEX idx_chunk_links_target ON chunk_links(target_chunk_id);

-- Enable RLS and setup policies
ALTER TABLE chunk_links ENABLE ROW LEVEL SECURITY;

-- Revoke all permissions initially
REVOKE ALL ON chunk_links FROM PUBLIC;

-- Only service_role can access chunk_links (since it's an internal pipeline table)
GRANT ALL ON chunk_links TO service_role;
