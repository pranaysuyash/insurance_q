create table if not exists public.qa_usage (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  query_date date not null default current_date,
  call_count int not null default 0,
  plan_tier text not null default 'free',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, query_date)
);
alter table public.qa_usage enable row level security;
create policy "users_own_usage" on public.qa_usage
  for all using (auth.uid()::text = user_id);
