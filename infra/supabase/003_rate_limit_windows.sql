-- Canonical shared rate-limit primitive for Cloud Run instances.
-- Identifiers must be SHA-256 hashes; never persist raw IP addresses, sessions,
-- or bearer tokens in this table.

create table if not exists public.rate_limit_windows (
  scope text not null,
  identifier_hash text not null,
  window_started_at timestamptz not null,
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (scope, identifier_hash)
);

alter table public.rate_limit_windows enable row level security;

create or replace function public.consume_rate_limit(
  p_scope text,
  p_identifier_hash text,
  p_limit integer,
  p_window_seconds integer
)
returns table (allowed boolean, current_count integer, retry_after_seconds integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_window_started_at timestamptz;
  v_count integer;
begin
  if p_limit < 1 or p_window_seconds < 1 or length(p_identifier_hash) <> 64 then
    raise exception 'invalid rate-limit input';
  end if;

  insert into public.rate_limit_windows(scope, identifier_hash, window_started_at, request_count, updated_at)
  values (p_scope, p_identifier_hash, v_now, 1, v_now)
  on conflict (scope, identifier_hash) do update
    set window_started_at = case
          when public.rate_limit_windows.window_started_at <= v_now - make_interval(secs => p_window_seconds)
          then v_now else public.rate_limit_windows.window_started_at end,
        request_count = case
          when public.rate_limit_windows.window_started_at <= v_now - make_interval(secs => p_window_seconds)
          then 1 else public.rate_limit_windows.request_count + 1 end,
        updated_at = v_now
  returning window_started_at, request_count into v_window_started_at, v_count;

  return query select
    v_count <= p_limit,
    v_count,
    case when v_count <= p_limit then 0
         else greatest(1, ceil(extract(epoch from (v_window_started_at + make_interval(secs => p_window_seconds) - v_now)))::integer)
    end;
end;
$$;

revoke all on table public.rate_limit_windows from public, anon, authenticated;
revoke all on function public.consume_rate_limit(text, text, integer, integer) from public, anon, authenticated;
grant execute on function public.consume_rate_limit(text, text, integer, integer) to service_role;

create index if not exists rate_limit_windows_updated_at_idx on public.rate_limit_windows(updated_at);
