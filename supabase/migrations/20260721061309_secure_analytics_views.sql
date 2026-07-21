-- Harden analytics dashboard views against accidental exposure and owner
-- bypass. These views are operator-only and must inherit the underlying
-- analytics_events RLS posture.

do $$
begin
  -- This migration was created after the project had legacy, non-standard
  -- migration filenames. On a fresh local reset the canonical timestamped
  -- analytics migration sorts before this file; this guard keeps the hardening
  -- safe for older databases where the views do not exist yet.
  if to_regclass('public.v_daily_active_users') is null then
    return;
  end if;

  execute 'alter view public.v_daily_active_users set (security_invoker = true)';
  execute 'alter view public.v_conversion_funnel set (security_invoker = true)';
  execute 'alter view public.v_cohort_retention set (security_invoker = true)';

  execute 'revoke all on table public.v_daily_active_users from public, anon, authenticated';
  execute 'revoke all on table public.v_conversion_funnel from public, anon, authenticated';
  execute 'revoke all on table public.v_cohort_retention from public, anon, authenticated';

  execute 'grant select on table public.v_daily_active_users to service_role';
  execute 'grant select on table public.v_conversion_funnel to service_role';
  execute 'grant select on table public.v_cohort_retention to service_role';
end
$$;
