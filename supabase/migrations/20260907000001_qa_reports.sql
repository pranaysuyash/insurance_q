create table if not exists public.qa_reports (
  id uuid primary key default gen_random_uuid(),
  report_id text not null unique,
  user_id text not null,
  question text not null,
  answer_text text not null,
  category text not null,
  comments text,
  document_id text,
  model_run_id text,
  user_agent text,
  ip_address text,
  status text not null default 'registered',
  created_at timestamptz not null default now()
);
alter table public.qa_reports enable row level security;
-- Users can insert their own reports
create policy "users_insert_reports" on public.qa_reports
  for insert with check (auth.uid()::text = user_id);
-- Users can read their own reports
create policy "users_read_own_reports" on public.qa_reports
  for select using (auth.uid()::text = user_id);
-- Service role can read/update all (for moderation)
