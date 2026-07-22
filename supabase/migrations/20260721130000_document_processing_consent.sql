-- Align the server consent ledger with the upload journey's explicit
-- document-processing purpose. Existing consent rows remain valid; the
-- vocabulary expands additively for new grants.

alter table public.consent_ledger
  drop constraint if exists consent_ledger_consent_type_check;

alter table public.consent_ledger
  add constraint consent_ledger_consent_type_check
  check (consent_type in (
    'privacy_policy',
    'document_processing',
    'analytics',
    'marketing_emails',
    'camera_access'
  ));
