-- Finish advisor hardening for the legacy revoked retrieval overload and the
-- profile policy. The legacy overload remains for compatibility, but is not
-- exposed to application roles.

alter function public.match_document_chunks(vector, text, integer, double precision)
  set search_path = public;

alter policy "Users read own profile"
  on public.profiles
  using (user_uid = (select auth.uid())::text);
