-- Claim records are a user's private, self-reported log. CoverWise does not
-- submit claims, receive insurer status, or act through an insurance adviser.
-- Preserve historical columns for migration compatibility, but prevent new
-- agent provenance even for service-role writers.

alter table public.claims
  drop constraint if exists claims_initiated_by_check;

alter table public.claims
  add constraint claims_initiated_by_user_only
  check (initiated_by = 'user') not valid;

alter table public.claims
  alter column initiated_by set default 'user';

comment on table public.claims is
  'Private self-reported claim-log records. Statuses are user-recorded, not insurer-sourced decisions.';

comment on column public.claims.status is
  'A user-recorded claim status. It is not insurer confirmation, eligibility, payment, or adjudication.';

comment on column public.claims.initiated_by is
  'Compatibility field. New records must be user-originated; CoverWise does not act through advisers or agents.';

comment on column public.claims.agent_id is
  'Retired compatibility field. New records do not accept agent provenance.';
