-- Harden analytics dashboard views against accidental exposure and owner
-- bypass. These views are operator-only and must inherit the underlying
-- analytics_events RLS posture.

alter view public.v_daily_active_users set (security_invoker = true);
alter view public.v_conversion_funnel set (security_invoker = true);
alter view public.v_cohort_retention set (security_invoker = true);

revoke all on table public.v_daily_active_users
  from public, anon, authenticated;
revoke all on table public.v_conversion_funnel
  from public, anon, authenticated;
revoke all on table public.v_cohort_retention
  from public, anon, authenticated;

grant select on table public.v_daily_active_users to service_role;
grant select on table public.v_conversion_funnel to service_role;
grant select on table public.v_cohort_retention to service_role;
