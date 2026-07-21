-- Canonical analytics retention primitive. Scheduling is an operator/deploy
-- concern; this function is the only production deletion boundary.

create or replace function public.purge_analytics_events(p_cutoff timestamptz)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare deleted_count bigint;
begin
  if p_cutoff >= now() then
    raise exception 'analytics retention cutoff must be in the past';
  end if;
  delete from public.analytics_events where received_at < p_cutoff;
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.purge_analytics_events(timestamptz)
  from public, anon, authenticated;
grant execute on function public.purge_analytics_events(timestamptz) to service_role;
