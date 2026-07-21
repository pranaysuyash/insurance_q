-- Privacy-safe retrieval and answer audit records.
-- Raw query/answer/source text is deliberately excluded. Hashes and bounded
-- metadata explain what happened without turning analytics into a content lake.

alter table public.rag_query_traces add column if not exists query_hash text;
alter table public.rag_query_traces add column if not exists query_length integer;

create index if not exists rag_query_traces_query_hash_idx
  on public.rag_query_traces (query_hash, created_at desc);

create table if not exists public.retrieval_runs (
  id uuid primary key default gen_random_uuid(),
  owner_id text not null,
  query_hash text not null,
  query_length integer not null check (query_length >= 0),
  query_variant_count integer not null default 1 check (query_variant_count >= 1),
  retrieval_strategy text not null,
  top_k integer not null check (top_k between 1 and 50),
  embedding_model text,
  embedding_version text,
  reranker_model text,
  latency_ms integer,
  cache_hit boolean not null default false,
  failure_class text,
  created_at timestamptz not null default now()
);

create table if not exists public.retrieval_candidates (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.retrieval_runs(id) on delete cascade,
  rank integer not null check (rank >= 1),
  chunk_id bigint references public.document_chunks(id) on delete set null,
  document_id uuid references public.documents(id) on delete set null,
  source_path text not null check (source_path in ('dense', 'fts', 'hybrid', 'unknown')),
  score double precision,
  included boolean not null default true,
  created_at timestamptz not null default now(),
  unique (run_id, rank)
);

create table if not exists public.rag_answers (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.retrieval_runs(id) on delete cascade,
  owner_id text not null,
  answer_hash text not null,
  answer_length integer not null check (answer_length >= 0),
  llm_used boolean not null default false,
  llm_model text,
  confidence double precision,
  missing_information_count integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.answer_evidence (
  id uuid primary key default gen_random_uuid(),
  answer_id uuid not null references public.rag_answers(id) on delete cascade,
  citation_index integer not null check (citation_index >= 1),
  chunk_id bigint references public.document_chunks(id) on delete set null,
  document_id uuid references public.documents(id) on delete set null,
  page_number integer,
  citation_status text not null check (citation_status in ('verified', 'approximate', 'rejected')),
  quote_hash text not null,
  created_at timestamptz not null default now(),
  unique (answer_id, citation_index)
);

create index if not exists retrieval_runs_owner_created_idx
  on public.retrieval_runs (owner_id, created_at desc);
create index if not exists retrieval_candidates_chunk_idx
  on public.retrieval_candidates (chunk_id);
create index if not exists rag_answers_owner_created_idx
  on public.rag_answers (owner_id, created_at desc);

alter table public.retrieval_runs enable row level security;
alter table public.retrieval_candidates enable row level security;
alter table public.rag_answers enable row level security;
alter table public.answer_evidence enable row level security;
revoke all on public.retrieval_runs, public.retrieval_candidates,
  public.rag_answers, public.answer_evidence from public, anon, authenticated;
grant select, insert on public.retrieval_runs, public.retrieval_candidates,
  public.rag_answers, public.answer_evidence to service_role;

comment on table public.retrieval_runs is
  'Privacy-safe retrieval run metadata; query text is represented by a hash.';
comment on table public.answer_evidence is
  'Citation lineage without storing raw answer or source text in the audit layer.';
