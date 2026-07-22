-- Explicit consent purposes for secondary use of customer-derived material.
-- document_processing is not sufficient authority for evaluation or training.

alter table public.consent_ledger
  drop constraint if exists consent_ledger_consent_type_check;

alter table public.consent_ledger
  add constraint consent_ledger_consent_type_check
  check (consent_type in (
    'privacy_policy',
    'document_processing',
    'analytics',
    'marketing_emails',
    'camera_access',
    'evaluation_dataset',
    'model_improvement'
  ));
