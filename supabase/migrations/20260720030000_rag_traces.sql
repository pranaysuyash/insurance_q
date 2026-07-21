-- CoverWise RAG query traces (Commit 5, ADR-2026-07-20-26, motto_v4 §0.10)
-- Date: 2026-07-20
-- Purpose: Per-query audit and trace logging for RAG queries.

create table if not exists public.rag_query_traces (
  id uuid primary key default gen_random_uuid(),
  query_text text not null,
  owner_id text,
  retrieval_strategy text,
  top_k integer,
  hits_count integer,
  citations_count integer,
  citations_verified integer,
  citations_approximate integer,
  citations_rejected integer,
  confidence float,
  retrieval_confidence float,
  llm_used boolean default true,
  llm_model text,
  latency_ms integer,
  cache_hit boolean default false,
  created_at timestamptz not null default now()
);

create index if not exists rag_query_traces_owner_id_idx on public.rag_query_traces (owner_id);
create index if not exists rag_query_traces_created_at_idx on public.rag_query_traces (created_at desc);

alter table public.rag_query_traces enable row level security;
revoke all on table public.rag_query_traces from public, anon, authenticated;
grant select, insert on table public.rag_query_traces to service_role;
