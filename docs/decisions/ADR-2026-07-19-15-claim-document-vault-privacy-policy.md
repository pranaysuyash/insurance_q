# ADR-2026-07-19-15: Claim Document Vault privacy policy — medical records handled with explicit consent, retention, encryption, and the user's right to export and delete

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Claim Document Vault (per ADR-2026-07-19-08 #3) is a privacy-sensitive surface because it stores claim paperwork that may include medical records (discharge summaries, diagnosis information, treatment details, prescriptions, diagnostic reports). The vault's privacy policy is explicit:** (1) a new consent purpose `medical_records` is added to the consent ledger (per ADR-2026-07-19-07) and is required before the user can upload a medical record; (2) the vault's retention period is 7 years (aligned with Indian medical record retention norms and the Indian Medical Council Act); (3) the vault's documents are encrypted at rest using the principal encryption from ADR-2026-07-19-06 (reopened to use a stable random 256-bit DEK, not JWT-derived); (4) the support-operator role (per ADR-2026-07-19-12) can read vault documents only with a reason, the read is audit-logged, and the user is notified by email; (5) the user has a right to export the vault as a PDF and a right to delete the vault (the deletion is durable via the outbox per ADR-2026-07-19-10); (6) the vault is not shared with partners, insurers, or third parties under any circumstances; the product does not train any model on vault contents. The vault is a filing cabinet, not a data source.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Deferred (operator sign-off, 2026-07-19).** The privacy policy is acceptable as written — the six components (consent, retention, encryption, support-operator access, user's right to export/delete, no-share rule) are the right shape. The implementation is deferred to a later exploration. The operator's reasoning: "I don't want my solo product to be bogged down because of these extra regulatory stuff, we research and get to this again later." The Claim Document Vault surface (per ADR-2026-07-19-08 #3) can ship in the meantime with a simpler privacy stance: local-first, encrypted by the principal encryption (per ADR-06), not shared with anyone by default (the no-share rule), but without the formal `medical_records` consent purpose, the formal 7-year retention enforcement, the formal support-operator access rules, or the formal export-as-PDF. The user is told the vault is private. When the operator revisits this ADR, the six components are the implementation checklist. The launch-claim registry entry "the Claim Document Vault does not share contents with anyone, ever; the user has full control over the vault" still applies even in the deferred state — the no-share rule is a minimum-viable privacy stance. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #3 (the Claim Document Vault that this ADR governs), [ADR-2026-07-19-07](./ADR-2026-07-19-07-security-phase-2-server-side-consent-ledger.md) (the consent ledger that the new purpose is added to), [ADR-2026-07-19-06](./ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md) (the principal encryption that protects the vault at rest), [ADR-2026-07-19-12](./ADR-2026-07-19-12-operator-trust-model.md) (the support-operator access rules), [ADR-2026-07-19-10](./ADR-2026-07-19-10-outbox-only-durable-work-primitive.md) (the durable deletion path), [canonical architecture doc](../../architecture/coverwise_canonical_architecture.md).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Claim Document Vault is a privacy-sensitive surface; the privacy policy defines consent, retention, encryption, support-operator access, user's right to export and delete, and the no-share rule. Status: Proposed.
- **2026-07-19 (operator sign-off, deferred)**: **Deferred.** The privacy policy is acceptable as written; the six components are the right shape. The implementation is deferred to a later exploration. The operator's reasoning: "I don't want my solo product to be bogged down because of these extra regulatory stuff, we research and get to this again later." The Claim Document Vault surface can ship in the meantime with a simpler privacy stance (local-first, encrypted, no-share, but without the formal consent/retention/access rules). When the operator revisits, the six components are the implementation checklist. The launch-claim registry entry "the Claim Document Vault does not share contents with anyone, ever; the user has full control over the vault" still applies even in the deferred state.

---

## Context

The Claim Document Vault (per ADR-2026-07-19-08 #3) is the user's filing cabinet for claim paperwork: discharge summaries, approval letters, settlement statements, denial letters, follow-up emails, photos of receipts. The operator's per-feature thinking (per ADR-2026-07-19-08 revision 2) was: "I don't want the user to think we help with claims but we can help them track their old claims docs they submitted, the discharge, approvals etc."

The vault is privacy-sensitive for three reasons:

1. **Medical records**: discharge summaries, diagnosis information, treatment details, prescriptions, and diagnostic reports are medical records under Indian law (the Indian Medical Council Act, the Information Technology Act, the Digital Information Security in Healthcare Act — DISHA — proposed but not yet enacted). Medical records are sensitive personal data; the user has a right to control who sees them.

2. **Insurance context**: claim paperwork reveals the user's relationship with their insurer (which insurer, what type of claim, what was approved, what was denied, what the settlement was). This is sensitive financial information that the user may not want shared.

3. **Operator access**: the support-operator role (per ADR-2026-07-19-12) is a real role that can read user data. Without explicit rules, a support operator could read any user's vault without the user's knowledge. The audit's T-8-8 is explicit: "Operator authorization beyond bearer token (RBAC + audit trail)." The audit trail + reason requirement is the foundation, but vault access needs additional rules because the data is medical.

The vault's privacy policy is the engineering answer to these three concerns. The policy defines: consent (the user opts in to storing medical records), retention (how long the vault is kept), encryption (how the vault is protected at rest), support-operator access (when a support operator can read the vault, with what notification), user's right to export and delete (the user can take the vault out and delete it), and the no-share rule (the vault is not shared with anyone, ever).

---

## The privacy policy in detail

### 1. Consent: the `medical_records` purpose

- **What it is:** the consent ledger (per ADR-2026-07-19-07) gains a new purpose: `medical_records`. The user must explicitly grant consent for this purpose before the vault can store a medical record. The consent is recorded in the consent ledger with timestamp, principal, purpose, and version.
- **Where the user grants consent:** the first time the user opens the Claim Document Vault, the vault shows a consent card: "This vault may contain medical records. By continuing, you consent to CoverWise storing these records encrypted on your device and on our servers, for up to 7 years, with access limited to you and to support operators who need to help you (with a reason logged and you notified by email). You can export or delete the vault at any time. We will never share your vault with insurers, partners, or third parties. We will never train any model on your vault contents."
- **What the user can do:** the user can grant consent, deny consent (the vault is hidden), or grant consent with a specific retention period (e.g. 3 years instead of 7). The user's choice is recorded in the consent ledger.
- **What happens if the user withdraws consent later:** the withdrawal is recorded in the consent ledger. The vault is locked (no new uploads). The existing documents are kept until the user's chosen retention period expires, then deleted via the outbox (per ADR-2026-07-19-10). The user can also request immediate deletion.
- **Why this matters:** the consent purpose is the legal basis for storing medical records. Without explicit consent, the storage is unlawful. The consent ledger (per ADR-2026-07-19-07) is the record.

### 2. Retention: 7 years (or less, by user choice)

- **What it is:** the vault's documents are kept for 7 years from the date of upload, aligned with the Indian Medical Council Act's recommended retention for medical records. The user can choose a shorter retention period (3 years, 1 year, or "until I delete") at the time of consent.
- **What happens when retention expires:** the document is deleted via the outbox (per ADR-2026-07-19-10). The deletion is durable (the outbox handler deletes the document from the substrate, the storage, and the local cache). The deletion is audit-logged.
- **Why 7 years:** the Indian Medical Council Act recommends 7 years for medical records. The user can choose less. The product does not choose more.
- **What about claims-related non-medical documents?** approval letters, settlement statements, denial letters, and follow-up emails are not medical records. The user can store them in the vault with the same consent and retention rules, or the user can store them in a separate "claim documents" vault with a different consent purpose. This ADR scopes the medical-records handling; the claim-documents handling is a future ADR if the user wants separation.

### 3. Encryption: principal encryption, at rest and in transit

- **What it is:** the vault's documents are encrypted at rest using the principal encryption from ADR-2026-07-19-06 (reopened per the bc16e9e fix to use a stable random 256-bit DEK in flutter_secure_storage, not JWT-derived). The encryption is per-document: each document has its own DEK, encrypted with the principal's master key. The server-side storage is also encrypted (the server stores the ciphertext, not the plaintext).
- **What "in transit" means:** the document is encrypted on the device before upload. The document is transmitted over TLS. The document is stored as ciphertext on the server. The document is decrypted on the device when the user views it.
- **What the server can see:** the server can see the document's metadata (upload date, document type, document size, the user's principal ID) but not the document's contents. The server cannot decrypt the document.
- **Why this matters:** the encryption is the technical safeguard. The consent is the legal basis. Both are required.

### 4. Support-operator access: read-only, with reason, audit-logged, user notified

- **What it is:** the support-operator role (per ADR-2026-07-19-12) can read vault documents only with a reason. The read is audit-logged. The user is notified by email. The user can see the access in the audit log (per ADR-2026-07-19-12's user-visible audit log).
- **When a support operator can read the vault:** only when the user has explicitly requested support (e.g. the user has opened a support ticket, the user has called the support line, the user has emailed support). The reason is "user requested support for [ticket/call/email ID]." The reason is logged in the audit trail.
- **What the support operator sees:** the document's contents (the discharge summary, the approval letter, etc.). The support operator cannot download, copy, or share the document. The support operator's session is logged out after the support interaction.
- **What the user sees:** an email notification: "[Support Operator Name] accessed your Claim Document Vault at [timestamp] for [reason]. You can see the full audit log at [link]." The user can dispute the access (the dispute is recorded in the audit log and triggers a security review).
- **What happens if a support operator accesses the vault without a user request:** the access is flagged as suspicious by the security monitoring (per ADR-2026-07-19-12's security role). The support operator's session is revoked. The access is investigated.
- **Why this matters:** the audit's T-8-8 is "RBAC + audit trail." The vault's access rules are the most sensitive case of the RBAC. The reason + audit + notification is the trust contract.

### 5. User's right to export and delete

- **What "export" means:** the user can download the entire vault as a single PDF (with all documents, metadata, and the consent ledger entries). The PDF is encrypted with a user-chosen password. The user can store the PDF anywhere (local device, cloud storage, email to self).
- **What "delete" means:** the user can delete the entire vault (all documents) or individual documents. The deletion is durable via the outbox (per ADR-2026-07-19-10): the document is removed from the substrate, the storage, and the local cache. The deletion is audit-logged. The user receives a confirmation email.
- **What the deletion does NOT do:** the deletion does not affect the audit log (the audit log is immutable per ADR-2026-07-19-12). The deletion does not affect the consent ledger (the consent withdrawal is recorded, but the historical consent entries are preserved). The user can see what was deleted and when.
- **What the deletion does:** the deletion is permanent. The document is gone. The user cannot recover it (unless the user exported it before deletion).

### 6. The no-share rule

- **What it is:** the vault's documents are not shared with anyone, ever. Not with insurers. Not with partners. Not with third parties. Not with model training pipelines. Not with analytics. Not with customer support tools that are not the audit-logged support-operator access described above.
- **What "not shared" means:** the document's ciphertext is not transmitted to any party other than the user. The document's plaintext is not transmitted to any party other than the user (and the audit-logged support operator). The document's metadata (upload date, document type, document size) is stored on the server for the user's own use (e.g. the vault's UI shows the metadata); the metadata is not shared.
- **What the product does with the vault contents:** the product stores them. The product encrypts them. The product retrieves them for the user. The product does not analyze them, classify them, summarize them, or use them for any purpose other than the user's own access.
- **What "we will never train any model on your vault contents" means:** the LLM extractors (per ADR-2026-07-19-14's `MemberExclusionsExtractor` and others) do not run on vault contents. The vault is a filing cabinet, not a data source. The substrate is the data source; the substrate is built from the policy documents, not from the claim documents.
- **Why this matters:** the operator's per-feature thinking was "we are letting users upload all kinds of policy docs, then why not later have partnerships to get ads or upsell policies etc?" (per ADR-2026-07-19-08 #5). The Value-Add Partnerships framework is for the user's policy data, not for the user's claim documents. The vault is excluded from partnerships by design.

---

## Options considered

### Option A: The full privacy policy above. CHOSEN.

- **How it works:** consent + retention + encryption + support-operator access rules + user's right to export/delete + no-share rule. All six elements are implemented as code, tests, and a launch-claim registry entry.
- **Why chosen:** the vault is privacy-sensitive. The privacy policy is the engineering answer. Each element addresses a specific concern (legal basis, retention, technical safeguard, trust contract, user agency, boundary discipline).
- **Cost:** L. 4-6 weeks. The consent purpose, the retention enforcement, the per-document encryption, the support-operator access rules, the export/delete UI, the no-share enforcement, the tests.
- **Quality:** the vault is honest about its sensitivity. The user has control. The support operator is bounded. The boundary is enforced.

### Option B: Minimal privacy policy (encryption only). REJECTED.

- **How it works:** the vault is encrypted at rest. Nothing else. The user can store anything. The support operator can read anything. The retention is forever.
- **Why rejected:** encryption is a technical safeguard, not a privacy policy. The legal basis (consent), the retention (7 years or less), the support-operator access (reason + audit + notification), the user's right to export and delete, and the no-share rule are all missing. The audit's T-8-8 is explicit about the access rules. The user's agency is missing.

### Option C: Refuse medical records entirely. REJECTED.

- **How it works:** the vault only stores non-medical claim documents (approval letters, settlement statements, denial letters, follow-up emails). The user is told "for medical records, use a different app."
- **Why rejected:** the operator's per-feature thinking was explicit: "we can help them track their old claims docs they submitted, the discharge, approvals etc." The user needs to store discharge summaries. Telling the user to use a different app is not the answer; the user already has CoverWise for the claim process, the vault is the natural place for the paperwork. The privacy policy is the answer, not the refusal.

---

## Chosen path

**The privacy policy is the right shape. The implementation is deferred.**

**What ships in the meantime (the "minimum-viable privacy stance" for the Claim Document Vault):**

1. **Local-first storage** — the vault's documents are stored on the user's device, encrypted with the principal encryption (per ADR-2026-07-19-06 reopened, stable random 256-bit DEK).
2. **No-share rule (absolute)** — the vault's documents are not shared with anyone, ever. Not with insurers. Not with partners. Not with third parties. Not with model training. Not with analytics. The CI test (the launch-claim registry entry) is enforced from day one.
3. **User's right to delete** — the user can delete the entire vault or individual documents. The deletion is durable via the outbox (per ADR-2026-07-19-10).
4. **User's right to export (simplified)** — the user can export the vault as a JSON or ZIP (not the full PDF flow). The export is encrypted with a user-chosen password.
5. **In-app disclosure** — the vault's first-open UX shows a card: "Your documents are private. We don't share them with anyone. You can export or delete them at any time. We may add additional protections in the future (medical-records consent, retention enforcement, etc.) — see ADR-2026-07-19-15 for the full policy."

**What is deferred (the six components, when the operator revisits):**

1. Consent purpose `medical_records` + the formal consent card
2. Retention enforcement (the scheduled outbox job that deletes expired documents after 7 years or less)
3. Per-document encryption (the vault ships with principal-encryption-at-rest in the meantime; per-document DEKs are a hardening)
4. Support-operator access rules (the formal RBAC entry, the reason requirement, the audit-logged access, the user notification; the vault ships with no support-operator access in the meantime — the support operator cannot read the vault until the rules are in place)
5. Export-as-PDF (the vault ships with export-as-JSON-or-ZIP; the PDF flow is a hardening)
6. Legal review (DPA, DISHA, Indian Medical Council Act) — deferred; the engineering ADR is the foundation

**When the operator revisits:** the six components are the implementation checklist. The effort is L. 4-6 weeks. The operator (you) decides when to revisit based on the product's growth, the regulatory landscape, and the user's needs.

---

## Why this path

### 1st-principle argument

The vault stores medical records. Medical records are sensitive personal data. The user has a right to control who sees them. The product's job is to give the user control, not to take it. The privacy policy is the engineering answer to the user's right.

The same argument as the trust audit's NO-GO: stop showing what the system does not know, and stop doing what the user did not consent to. The vault's privacy policy is the consent mechanism.

### Anti-lying-UI argument (motto v3 §0.7)

A vault that says "your documents are private" but shares them with partners is a lying UI. The privacy policy is the engineering answer. The launch-claim registry entry is the test.

### Anti-undefined-boundary argument (motto v3 §0.11 customer-facing claims)

The Value-Add Partnerships framework (per ADR-2026-07-19-08 #5) is for the user's policy data. The vault is excluded from partnerships by design. The boundary is explicit. The launch-claim registry entry is the test.

### Anti-coerced-consent argument (motto v3 §0.4 acceptance contract)

The consent is explicit, granular, and revocable. The user can grant or deny. The user can choose a shorter retention. The user can withdraw consent later. The user can export and delete. The acceptance contract for "the user uploads a medical record" is "the user knows what is happening and can stop it."

### Operator-decision-required argument

This ADR is **proposed, not accepted**. The privacy policy is a recommendation. The operator may want a different policy (e.g. shorter retention, no support-operator access, no encryption at rest, different consent UX); the operator may want a separate ADR for the legal review (the Indian Medical Council Act, DISHA, etc.). The reason this is an ADR and not a code change is that the privacy policy is load-bearing and the operator should sign off on it.

---

## Tradeoffs

- **The privacy policy is 4-6 weeks of work.** The vault is delayed. The mitigation is the privacy policy is the prerequisite for the vault; the user cannot use the vault without the policy.
- **The per-document encryption is expensive.** Each document has its own DEK, encrypted with the principal's master key. The encryption/decryption is per-document, not per-vault. The mitigation is the encryption is local-first; the performance impact is on the device, not the server.
- **The support-operator access rules add operational overhead.** Every access requires a reason. Every access triggers an email to the user. The support operator's workflow is slower. The mitigation is the rules are the trust contract; the operational overhead is the cost of having a trust contract.
- **The retention enforcement is a scheduled outbox job.** The job runs periodically (e.g. daily). The job may be slow if there are many expired documents. The mitigation is the job is batched; the operator can monitor the job via the operator CLI (per ADR-2026-07-19-10).
- **The no-share enforcement is a CI test.** The test scans the production code for any code path that transmits vault contents to a non-user party. The test may be too strict (e.g. legitimate test fixtures). The mitigation is the test's exclusion list.
- **The consent UX may be friction.** The user has to read a consent card before storing a medical record. The friction is the cost of explicit consent. The mitigation is the consent card is short and clear; the user can grant or deny in one tap.

---

## Assumptions

- **The 7-year retention is the right default.** Aligned with the Indian Medical Council Act. The user can choose less. The product does not choose more. The operator may want a different default; the ADR is the place to discuss.
- **The per-document encryption is the right granularity.** Per-document DEKs allow per-document deletion and per-document access control. The alternative (one DEK per vault) is simpler but less granular. The operator may want per-vault encryption; the ADR is the place to discuss.
- **The support-operator access rules are the right trust contract.** Reason + audit + notification. The alternative (no support-operator access) is more private but less useful. The operator may want a different contract; the ADR is the place to discuss.
- **The no-share rule is absolute.** The vault is never shared. The Value-Add Partnerships framework is excluded by design. The operator may want a different rule; the ADR is the place to discuss.
- **The export-as-PDF is the right export format.** PDF is portable, encrypted, and includes metadata. The alternative (export as JSON or ZIP) is more flexible but less user-friendly. The operator may want a different format; the ADR is the place to discuss.
- **The legal review is a separate workstream.** The Indian Medical Council Act, DISHA, and any state-level medical record retention laws are the legal framework. A separate legal review ADR is recommended; the engineering ADR is the foundation.

---

## Risks

- **The operator disagrees with the policy.** This is a feature of the decisions-first process, not a bug. The mitigation is to make the policy explicit and easy to revisit.
- **A legal review finds a different policy is required.** The mitigation is the legal review is a separate workstream; the engineering ADR is the foundation that the legal review builds on.
- **The per-document encryption is too slow.** The mitigation is the encryption is local-first; the user can test the performance on their device; the operator can monitor via the operator CLI.
- **The support-operator access rules are too restrictive.** The mitigation is the rules are configurable per role; the operator can adjust the rules.
- **The no-share rule conflicts with a future business need.** The mitigation is the no-share rule is a first-class boundary; any conflict triggers an ADR revision.
- **The retention enforcement is not run.** The mitigation is the outbox job is scheduled; the operator CLI shows the job status; the audit log shows the job runs.

---

## Validation plan

- **For the consent purpose:** a unit test that asserts the consent card is shown on first open and the consent is recorded in the consent ledger.
- **For the retention enforcement:** an integration test that asserts an expired document is deleted via the outbox.
- **For the per-document encryption:** a unit test that asserts each document has its own DEK and the DEK is encrypted with the principal's master key.
- **For the support-operator access rules:** an integration test that asserts a support operator access requires a reason, the access is audit-logged, and the user is notified.
- **For the user's right to export:** a unit test that asserts the export-as-PDF includes all documents, metadata, and the consent ledger entries; the PDF is encrypted with a user-chosen password.
- **For the user's right to delete:** an integration test that asserts a deletion removes the document from the substrate, the storage, and the local cache; the deletion is audit-logged.
- **For the no-share enforcement:** a CI test that scans the production code for any code path that transmits vault contents to a non-user party. The test fails if such a code path is found.
- **For the launch-claim registry:** a CI test that asserts the entry exists and links to the tests.
- **For the canonical doc:** a doc-lint test that asserts the vault's privacy policy is defined as a first-class section.
- **End-to-end:** the launch playbook's Step 8 (real-device end-to-end) runs after the privacy policy is implemented. The validation includes: user opens vault → consent card shown → user grants consent → user uploads discharge summary → document is encrypted → user views document → user exports vault → user deletes document → audit log shows the actions.

---

## Rollback or migration path

The privacy policy is additive. The consent purpose is a new entry in the consent ledger. The retention enforcement is a new scheduled outbox job. The per-document encryption is a new code path. The support-operator access rules are new entries in the RBAC table. The user's right to export and delete are new UI features. The no-share enforcement is a new CI test.

If the policy turns out to be wrong:
- The consent purpose can be removed (existing consents remain in the consent ledger; new consents cannot be granted).
- The retention enforcement can be disabled (the scheduled job is not run).
- The per-document encryption can be disabled (the documents are stored in plaintext; this is a security regression and is logged).
- The support-operator access rules can be relaxed (the rules are configurable per role).
- The user's right to export and delete can be removed (the UI is hidden; the data is still there).
- The no-share enforcement can be disabled (the CI test is removed; the boundary is gone).

The launch-claim registry entry is updated when the policy changes. The CI gate fails if the entry is not updated.

---

## What would cause this decision to be revisited

- **A legal review finds a different policy is required.** A future ADR revises the policy to match the legal review.
- **A regulator requires additional protections.** A future ADR adds the protections.
- **The Value-Add Partnerships framework (per ADR-2026-07-19-08 #5) evolves.** The no-share rule is a first-class boundary; any evolution triggers an ADR revision.
- **The Indian Medical Council Act or DISHA is enacted.** A future ADR revises the policy to match the new law.
- **The market changes.** A competitor offers a different vault policy. The operator may decide to revise. This ADR's revisit trigger would note the change but the original 1st-principle argument stands.

---

## Anything else? (operator's standing review prompt)

The Claim Document Vault privacy policy raises a more general question: **what other privacy-sensitive surfaces does the product have, and what are their privacy policies?** The pattern is: any surface that handles sensitive personal data has an explicit privacy policy.

- **Family Coverage Map (per ADR-2026-07-19-08 #6)** — per-member observations may include health information (a family member's medical history inferred from exclusions). The privacy policy: the observations are substrate-grounded, the user can dismiss observations, the user's family members are not third parties (the user is the data controller for the family's coverage data on the user's policies). The family member's data is the user's data by virtue of being on the user's policy. The future ADR ("Family Coverage Map privacy policy") will formalize this. The pattern is the same: consent + retention + encryption + access rules + user's right to export/delete + no-share.
- **Coverage Check-in (per ADR-2026-07-19-08 #1)** — the check-in asks the user about life events (new baby, new diagnosis, etc.). The user's responses are sensitive personal data. The privacy policy: the responses are stored locally on the device, encrypted with the principal encryption, never shared with anyone. The future ADR ("Coverage Check-in privacy policy") will formalize this.
- **Coverage Adequacy (per ADR-2026-07-19-08 #2)** — the user picks a scenario (C-section, knee replacement, etc.). The scenario is sensitive personal data (the user is interested in a specific medical event). The privacy policy: the scenario is stored locally on the device, encrypted, never shared. The future ADR ("Coverage Adequacy privacy policy") will formalize this.
- **Account contact (the user's own phone for IRDAI escalation and claim contact)** — the phone is sensitive personal data. The privacy policy is already in the consent ledger (per ADR-2026-07-19-07) with purpose `account_contact`. The retention is until the user deletes the account. The encryption is the principal encryption. The no-share rule is in effect (the phone is not shared with partners or advertisers). The policy is already in place; this ADR is the template for the other surfaces.

The pattern is reusable: any new surface that handles sensitive personal data gets a privacy policy ADR. The policies are the engineering answer to the user's right to control their data.

---

## Links

- **Affected files (this ADR, after operator sign-off):**
  - `supabase/migrations/2026_07_19_medical_records_consent.sql` (new: the consent purpose schema)
  - `src/services/consent_ledger_service.py` (extend: the new `medical_records` purpose)
  - `mobile/lib/screens/claim_document_vault_screen.dart` (new: the vault UI with the consent card; per ADR-2026-07-19-08 #3)
  - `mobile/lib/services/vault_encryption_service.dart` (new: the per-document encryption service)
  - `src/services/retention_enforcement.py` (new: the scheduled outbox job)
  - `src/workers/retention_enforcement_handler.py` (new: the outbox handler)
  - `src/api/operator.py` (extend: the support-operator access rules for `medical_records:read`)
  - `mobile/lib/screens/vault_export_screen.dart` (new: the export-as-PDF UI)
  - `src/services/vault_export_service.py` (new: the export service)
  - `src/services/vault_deletion_service.py` (new: the deletion service)
  - `tests/test_medical_records_consent.py` (new)
  - `tests/test_retention_enforcement.py` (new)
  - `tests/test_vault_encryption.py` (new)
  - `tests/test_vault_support_operator_access.py` (new)
  - `tests/test_vault_export.py` (new)
  - `tests/test_vault_deletion.py` (new)
  - `tests/test_no_vault_share.py` (new: the launch-claim registry test)
  - `docs/launch_claims/claim-document-vault-privacy.md` (new: the launch-claim registry entry)
  - `docs/architecture/coverwise_canonical_architecture.md` (add the vault's privacy policy as a first-class section)
  - `docs/decisions/README.md` (add this ADR to the index)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #3 (the Claim Document Vault that this ADR governs)
  - [ADR-2026-07-19-07](./ADR-2026-07-19-07-security-phase-2-server-side-consent-ledger.md) (the consent ledger that the new purpose is added to)
  - [ADR-2026-07-19-06](./ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md) (the principal encryption that protects the vault at rest)
  - [ADR-2026-07-19-12](./ADR-2026-07-19-12-operator-trust-model.md) (the support-operator access rules)
  - [ADR-2026-07-19-10](./ADR-2026-07-19-10-outbox-only-durable-work-primitive.md) (the durable deletion path)
  - [Canonical architecture doc](../../architecture/coverwise_canonical_architecture.md) (target of the doc update)
  - `docs/audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md` (the audit findings on data lifecycle, retention, medical data)
- **Related code (current state):**
  - `mobile/lib/services/consent_ledger.dart` (the consent ledger; the new purpose is added here)
  - `src/services/consent_ledger_service.py` (the consent ledger service)
  - `mobile/lib/services/principal_key_service.dart` (the principal encryption; the per-document DEKs are derived from this)
  - `src/api/operator.py` (the operator endpoints; the support-operator access rules are added here)
- **Motto v3 alignment:** §0.4 (acceptance contract; the user's right to control their data is the contract), §0.5 (evidence tiers; the privacy policy is a tier of trust), §0.7 (AI output boundary; the vault is not a data source for any model), §0.11 (customer-facing claims; the privacy policy is a customer right), §0.12 (this document).

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | **Reaffirmed as deferred per [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md).** Status unchanged (Deferred per operator). When implemented, the Claim Document Vault is private organisation of user-provided documents with complete lifecycle controls — it is **not** claims consultancy or default medical-record expansion (Gate C). Original reasoning preserved. | Operator direction: layered doctrine stack. |


---

## Doctrine reconciliation note (2026-07-29)

> Append-only note added 2026-07-29. This section does not modify any prior
> content in this ADR; the original decision, reasoning, and existing update
> logs above remain intact and authoritative for their date.

- **Date:** 2026-07-29
- **Governing ADR:** [ADR-2026-07-29-02 (doctrine stack reconciliation)](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
- **What changed:** [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) establishes a layered doctrine stack. The [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) (`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`) now sits above feature ADRs, with a five-gate stack (Gates A-E: Outcome, Truth, Product role, Lifecycle, Strategy/commercial). Reaffirmed as Deferred (operator): when implemented, it is private organisation of user-provided documents with complete lifecycle controls; NOT claims consultancy or default medical-record expansion (Gate C).
- **Why:** Operator direction to unify two competing uncommitted first-principles documents into one layered stack before any boundary-shaped code changes.
- **What triggered it:** Discovery that the repository held conflicting uncommitted doctrine (Principles vs Wedge) and that ADR-2026-07-29-01 self-declared "Accepted" without sign-off evidence.
- **What original reasoning remains valid:** All prior reasoning in this ADR is preserved unchanged. This note only constrains surface semantics where they intersect the constitution's gates.
- **Status change for this ADR:** None (this ADR's own status is unchanged by this note).
- **Operator sign-off:** None required for this note; it records the reconciliation linkage. The reconciliation ADR itself remains Proposed pending operator sign-off.
- **Code authorization:** None. No code, route, entitlement, pricing, comparison, claims, renewal, camera, demo, or onboarding change is authorized by this note.
