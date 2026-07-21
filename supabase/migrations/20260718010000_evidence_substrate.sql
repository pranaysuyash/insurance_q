-- CoverWise evidence substrate (Trust Phase 1)
-- Date: 2026-07-18
-- Convention: follow supabase/migrations/20260718020000_revops_tables.sql
--   - public schema
--   - owner_id text (NOT auth.users FK; Supabase user IDs are strings)
--   - RLS enabled, all access revoked, only service_role granted
--   - if not exists everywhere (idempotent re-runs)
--
-- This migration creates four immutable, append-only tables that hold the
-- evidence substrate for policy documents. Every other trust surface
-- (policy detail, Q&A, claim verification, renewal diff) reads from this
-- substrate. The substrate is the contract; the surfaces are views over it.
--
-- Append-only by design:
--   - page_artifacts: written once per page, never updated, deleted only
--     via document cascade.
--   - source_spans: written once per span, never updated, deleted only
--     via page_artifact cascade.
--   - extracted_fields: written once per (document, field) tuple, never
--     updated. To "change" a field, write a new row with a new
--     parser_version; the UI shows the latest by created_at.
--   - field_evidence: written once per (field, page, span) link. The
--     citation contract is that every field shown in the UI has at least
--     one field_evidence row.

create extension if not exists pgcrypto;

-- 1. page_artifacts
-- One row per (document, page_number). The image_uri points to a rendered
-- page PNG in the coverwise-documents storage bucket. ocr_text and
-- layout_json are populated asynchronously by the processing pipeline.
create table if not exists public.page_artifacts (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  page_number integer not null check (page_number >= 1),
  image_uri text not null,
  ocr_text text,
  layout_json jsonb,
  sha256 text not null,
  created_at timestamptz not null default now(),
  unique (document_id, page_number)
);
create index if not exists page_artifacts_document_id_idx
  on public.page_artifacts (document_id);
create index if not exists page_artifacts_document_page_idx
  on public.page_artifacts (document_id, page_number);

alter table public.page_artifacts enable row level security;
revoke all on table public.page_artifacts from public, anon, authenticated;
grant select, insert, delete on table public.page_artifacts to service_role;

-- 2. source_spans
-- One row per logical region within a page (paragraph, table cell, header,
-- footer, list item, other). bbox_json is in PDF points relative to the
-- page, so a renderer can highlight the region on the page image.
create table if not exists public.source_spans (
  id uuid primary key default gen_random_uuid(),
  page_artifact_id uuid not null references public.page_artifacts(id) on delete cascade,
  span_text text not null,
  bbox_json jsonb not null,
  span_type text not null
    check (span_type in ('paragraph','table_cell','header','footer','list_item','other')),
  confidence real not null check (confidence between 0 and 1),
  parser_version text not null,
  created_at timestamptz not null default now()
);
create index if not exists source_spans_page_artifact_id_idx
  on public.source_spans (page_artifact_id);
create index if not exists source_spans_page_artifact_type_idx
  on public.source_spans (page_artifact_id, span_type);

alter table public.source_spans enable row level security;
revoke all on table public.source_spans from public, anon, authenticated;
grant select, insert, delete on table public.source_spans to service_role;

-- 3. extracted_fields
-- One row per (document, field_name, parser_version). The value is a
-- typed wrapper {raw, normalized, display}. parser_kind discriminates
-- between deterministic extraction (free, audit-friendly) and LLM
-- extraction (cost-tracked, lower trust by default).
create table if not exists public.extracted_fields (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  field_name text not null,
  value jsonb not null,
  value_type text not null
    check (value_type in ('string','number','date','currency','enum','clause_text')),
  confidence real not null check (confidence between 0 and 1),
  parser_version text not null,
  parser_kind text not null
    check (parser_kind in ('deterministic_regex','deterministic_lookup','llm_extract')),
  created_at timestamptz not null default now()
);
create index if not exists extracted_fields_document_id_idx
  on public.extracted_fields (document_id);
create index if not exists extracted_fields_document_field_idx
  on public.extracted_fields (document_id, field_name, created_at desc);
create index if not exists extracted_fields_parser_kind_idx
  on public.extracted_fields (parser_kind);

alter table public.extracted_fields enable row level security;
revoke all on table public.extracted_fields from public, anon, authenticated;
grant select, insert, delete on table public.extracted_fields to service_role;

-- 4. field_evidence
-- The citation contract. Every extracted_field the UI displays must have
-- at least one field_evidence row pointing at the page and (optionally)
-- the span it came from. cite_string is the human-readable citation
-- ("page 4, paragraph 3") generated at write time so the UI never
-- invents citation text.
create table if not exists public.field_evidence (
  id uuid primary key default gen_random_uuid(),
  extracted_field_id uuid not null references public.extracted_fields(id) on delete cascade,
  page_artifact_id uuid not null references public.page_artifacts(id) on delete cascade,
  source_span_id uuid references public.source_spans(id) on delete set null,
  evidence_strength real not null check (evidence_strength between 0 and 1),
  cite_string text not null,
  created_at timestamptz not null default now()
);
create index if not exists field_evidence_extracted_field_id_idx
  on public.field_evidence (extracted_field_id);
create index if not exists field_evidence_page_artifact_id_idx
  on public.field_evidence (page_artifact_id);

alter table public.field_evidence enable row level security;
revoke all on table public.field_evidence from public, anon, authenticated;
grant select, insert, delete on table public.field_evidence to service_role;

-- 5. v_field_citations
-- The single read path the policy detail screen uses. Returns, per
-- (document, field), the strongest evidence row. The UI does one
-- query, no joins in app code. The view is read-only by construction.
-- RLS on the underlying tables already restricts access to service_role,
-- so the view inherits that.
create or replace view public.v_field_citations
with (security_invoker = true) as
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
from public.extracted_fields ef
join public.field_evidence fe on fe.extracted_field_id = ef.id
join public.page_artifacts pa on pa.id = fe.page_artifact_id
where fe.evidence_strength = (
  select max(fe2.evidence_strength)
  from public.field_evidence fe2
  where fe2.extracted_field_id = ef.id
);
grant select on public.v_field_citations to service_role;
comment on view public.v_field_citations is
  'Single read path for policy detail. One row per (document, field) with the strongest evidence.';

-- 6. Evidence extraction cost tracking
-- LLM extraction calls cost money. The RevOps R1 substrate already
-- captures events, but extraction cost is per-document and per-field
-- and needs to be queryable. This is the minimum viable cost table;
-- the operator dashboard reads it.
create table if not exists public.evidence_extraction_costs (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  extracted_field_id uuid references public.extracted_fields(id) on delete set null,
  parser_kind text not null check (parser_kind in ('deterministic_regex','deterministic_lookup','llm_extract')),
  model text,
  prompt_tokens integer,
  completion_tokens integer,
  cost_usd numeric(10, 6),
  created_at timestamptz not null default now()
);
create index if not exists evidence_extraction_costs_document_id_idx
  on public.evidence_extraction_costs (document_id);
create index if not exists evidence_extraction_costs_created_at_idx
  on public.evidence_extraction_costs (created_at desc);

alter table public.evidence_extraction_costs enable row level security;
revoke all on table public.evidence_extraction_costs from public, anon, authenticated;
grant select, insert on table public.evidence_extraction_costs to service_role;
