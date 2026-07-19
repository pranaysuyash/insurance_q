# ADR-2026-07-19-20: Family Coverage Map privacy policy — per-member observations handled with the same privacy discipline as the rest of the wedge

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Family Coverage Map (per ADR-2026-07-19-08 #6) handles per-member data that is sensitive but not medical.** Per-member observations (per ADR-2026-07-19-14's substrate extension) may include health-adjacent information (a family member's age, exclusions inferred from the policy). The privacy policy is the same shape as ADR-2026-07-19-15's policy but simpler (no medical records, no formal `medical_records` consent purpose). The policy: (1) the per-member observations are substrate-grounded; (2) the user can dismiss observations; (3) the family member's data is the user's data by virtue of being on the user's policy; (4) the per-member data is encrypted at rest using the principal encryption (per ADR-2026-07-19-06 reopened); (5) the support-operator role (per ADR-2026-07-19-12) can read the Family Coverage Map with reason, audit-logged, user notified; (6) the user has a right to export and delete; (7) the Family Coverage Map is not shared with partners, insurers, or third parties. The policy is a "minimum-viable privacy stance" — the formal consent purpose, retention enforcement, and per-document encryption are deferred (per the ADR-15 pattern). The launch-claim registry entry: "Family Coverage Map per-member observations are substrate-grounded, evidence-backed, and never shared with partners."
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** the Family Coverage Map privacy policy is the minimum-viable privacy stance: per-member observations are substrate-grounded, user can dismiss observations, family member is not a third party, per-member data is encrypted at rest using the principal encryption (per ADR-06 reopened), support-operator access is disabled in the meantime, user has right to export and delete, no-share rule (absolute). The launch-claim registry entry is "Family Coverage Map per-member observations are substrate-grounded, evidence-backed, and never shared with partners." The formal consent purpose (`family_data`), retention enforcement, per-policy encryption, support-operator access rules, and export-as-PDF are deferred to a future revisit (following the ADR-15 pattern). The Family Coverage Map surface (per ADR-2026-07-19-08 #6) is unblocked once this ADR is implemented. Implementation may begin in dependency order: in-app disclosure card → RLS check → no-share CI test → launch-claim registry entry → canonical doc update. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #6 (the Family Coverage Map that this ADR governs), [ADR-2026-07-19-14](./ADR-2026-07-19-14-family-coverage-map-substrate-extension.md) (the substrate extension that produces the per-member observations), [ADR-2026-07-19-15](./ADR-2026-07-19-15-claim-document-vault-privacy-policy.md) (the pattern this ADR follows; deferred per operator's "I don't want my solo product to be bogged down"), [ADR-2026-07-19-12](./ADR-2026-07-19-12-operator-trust-model.md) (the support-operator access rules), [ADR-2026-07-19-06](./ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md) (the principal encryption).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Family Coverage Map is a privacy-sensitive surface (per-member data may include health-adjacent information). The privacy policy is the same shape as ADR-15 but simpler (no medical records). Minimum-viable privacy stance. The launch-claim registry entry is the no-share rule. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The Family Coverage Map privacy policy is the minimum-viable privacy stance: per-member observations are substrate-grounded, user can dismiss observations, family member is not a third party, per-member data is encrypted at rest using the principal encryption (per ADR-06 reopened), support-operator access is disabled in the meantime, user has right to export and delete, no-share rule (absolute). The launch-claim registry entry is "Family Coverage Map per-member observations are substrate-grounded, evidence-backed, and never shared with partners." The formal consent purpose (`family_data`), retention enforcement, per-policy encryption, support-operator access rules, and export-as-PDF are deferred to a future revisit (following the ADR-15 pattern). The Family Coverage Map surface (per ADR-2026-07-19-08 #6) is unblocked once this ADR is implemented. Implementation may begin in dependency order: in-app disclosure card → RLS check → no-share CI test → launch-claim registry entry → canonical doc update.


---

## Context

The Family Coverage Map (per ADR-2026-07-19-08 #6) shows the user how each family member is covered by each of the user's policies. The operator's per-feature thinking was: "i have a family floater, i should know how each member is covered what they may need extra etc, my dependents can't have their own policies."

The per-member data includes:
- Member name, age, relationship
- Per-member sum insured (for family floaters)
- Per-member exclusions (e.g. "dental," "maternity," "pre-existing diabetes")
- Whether the member can have their own policy (the dependents signal)

The exclusions are the most sensitive: they may reveal a family member's medical history (a "pre-existing diabetes" exclusion reveals the family member has diabetes). The age and relationship are less sensitive but still personal.

The Family Coverage Map's privacy policy is the same shape as ADR-15's policy (consent + retention + encryption + access rules + export/delete + no-share) but simpler:
- No `medical_records` consent purpose (the data is not medical records; it's health-adjacent)
- The user is the data controller for the family (the user owns the policies, the user enters the family data)
- The family member is not a third party (the family member is on the user's policy)
- The formal retention enforcement is deferred (per ADR-15's pattern)

The policy is a "minimum-viable privacy stance" — the formal consent purpose, retention enforcement, and per-document encryption are deferred. The launch-claim registry entry is the no-share rule.

---

## The policy in detail

### 1. The per-member observations are substrate-grounded

- The observations are extracted by the parser pipeline v2 (per ADR-14) from the user's policy documents. The observations cite the policy, the page, and the quote. The four-face contract (per ADR-09) applies.
- The observations are not "about" the family member in the sense that the family member has a separate data record; the observations are "about" the policy's coverage of the family member. The user is the data controller; the family member is the data subject.

### 2. The user can dismiss observations

- The Family Coverage Map shows a list of observations, each with a "dismiss" button. When the user dismisses an observation, the observation is hidden from the user's view. The dismissed observation is stored in the substrate with a `dismissed=true` flag; the substrate does not delete the observation (the audit trail requires the record).
- The user can un-dismiss an observation at any time.

### 3. The family member is not a third party

- The family member is on the user's policy. The user owns the policy. The user enters the family data. The user is the data controller.
- The family member does not have a separate account, does not have a separate consent, does not have a separate right to access or delete. The user's choices are the family member's choices by virtue of the policy ownership.
- This is a deliberate product call. The alternative (each family member has a separate account) is a future ADR if the user wants that level of family identity.

### 4. The per-member data is encrypted at rest

- The per-member data is encrypted using the principal encryption (per ADR-06 reopened, stable random 256-bit DEK). The encryption is per-policy (each policy's per-member data has its own DEK).
- The server stores ciphertext only. The server cannot decrypt the per-member data.

### 5. The support-operator access is bounded

- The support-operator role (per ADR-12) can read the Family Coverage Map with reason. The reason is logged. The user is notified by email. The access is audit-logged.
- The support operator cannot modify the Family Coverage Map (read-only). The support operator cannot export the Family Coverage Map (read-only).

### 6. The user has a right to export and delete

- The user can export the Family Coverage Map as a JSON (or PDF, when the formal privacy work lands). The export is encrypted with a user-chosen password.
- The user can delete the Family Coverage Map (all per-member data). The deletion is durable via the outbox (per ADR-10). The deletion is audit-logged.

### 7. The no-share rule (absolute)

- The Family Coverage Map is not shared with anyone, ever. Not with insurers. Not with partners (per ADR-16). Not with third parties. Not with model training. Not with analytics.
- The launch-claim registry entry: "Family Coverage Map per-member observations are substrate-grounded, evidence-backed, and never shared with partners."

---

## What ships in the meantime (the "minimum-viable privacy stance")

1. **Per-member data is encrypted at rest** using the principal encryption (per ADR-06).
2. **No-share rule (absolute)** is enforced by a CI test (the launch-claim registry entry).
3. **User's right to export and delete** is supported.
4. **Support-operator access** is disabled in the meantime (the support operator cannot read the Family Coverage Map until the formal RBAC entry is in place).
5. **In-app disclosure** — the Family Coverage Map's first-open UX shows a card: "Your family data is private. We don't share it with anyone. You can export or delete it at any time. We may add additional protections in the future — see ADR-2026-07-19-20 for the full policy."

**What is deferred (the seven components, when the operator revisits):**
1. Formal consent purpose `family_data` + the formal consent card
2. Retention enforcement (the scheduled outbox job that deletes the Family Coverage Map after the user's chosen retention)
3. Per-policy encryption (the Family Coverage Map ships with principal-encryption-at-rest in the meantime; per-policy DEKs are a hardening)
4. Support-operator access rules (the formal RBAC entry, the reason requirement, the audit-logged access, the user notification; the Family Coverage Map ships with no support-operator access in the meantime)
5. Export-as-PDF (the Family Coverage Map ships with export-as-JSON in the meantime)
6. Family member separate accounts (a future ADR; the family member is not a third party in the meantime)
7. Legal review (Indian data protection law, family data handling) — deferred

**When the operator revisits:** the seven components are the implementation checklist. The effort is M. 2-3 weeks. The operator (you) decides when to revisit.

---

## Anything else flagged

The "privacy policy per surface" pattern (per ADR-15) is now well-established. Three more privacy ADRs follow this pattern:
- **Family Coverage Map privacy policy** (this ADR)
- **Coverage Check-in privacy policy** (per ADR-08 #1) — the user's life events (new baby, new diagnosis) are sensitive
- **Coverage Adequacy privacy policy** (per ADR-08 #2) — the user's scenario picks (C-section, knee replacement) are sensitive

All three follow the same minimum-viable privacy stance: no-share + principal encryption + user's right to export/delete. The formal consent purpose, retention enforcement, per-document encryption, support-operator access rules, and export-as-PDF are deferred to a future revisit, following the ADR-15 pattern.

The full set of privacy ADRs (ADR-15, ADR-20, plus the future Coverage Check-in and Coverage Adequacy privacy ADRs) is the privacy workstream. The workstream is a future exploration (per the operator's "I don't want my solo product to be bogged down because of these extra regulatory stuff"). The minimum-viable privacy stance is the launch state for each surface.
