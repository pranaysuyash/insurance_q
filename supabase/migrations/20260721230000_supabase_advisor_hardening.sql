-- Harden functions and the profile policy flagged by Supabase advisors.
-- Keep vector/pg_trgm in public for the existing typed retrieval contract;
-- moving those extensions requires a separate compatibility migration.

alter function public.claim_job_outbox(integer)
  set search_path = public;
alter function public.reclaim_job_outbox(integer)
  set search_path = public;
alter function public.consent_ledger_append_only()
  set search_path = public;
alter function public.job_outbox_set_updated_at()
  set search_path = public;
alter function public.match_document_chunks(vector, text, integer, double precision, uuid[], text, text)
  set search_path = public;
alter function public.match_document_chunks_fts(text, text, integer, double precision, uuid[])
  set search_path = public;

alter policy "Users read own profile"
  on public.profiles
  using (user_uid = (select auth.jwt() ->> 'sub'));
