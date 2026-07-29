# ADR-2026-07-19-16: Value-Add Partnerships — partner-vetting policy, opt-in mechanism, and the no-medical-records boundary

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Value-Add Partnerships framework (per ADR-2026-07-19-08 #5) is built as a framework first, partnerships second.** The framework has three components: (1) a public partner-vetting policy (a marketing site page, not an in-app page) that names the criteria a partner must meet (regulatory standing, data handling, no resale, no unsolicited contact, opt-out honored, etc.); (2) an in-app opt-in toggle ("I'm interested in offers from CoverWise's vetted partners") that records the user's choice in the consent ledger (per ADR-2026-07-19-07) with a new purpose `partnership_offers`; (3) a server-enrolled opt-in webhook that the partner polls (or subscribes to) to learn when a user has opted in. The product does not share the user's documents, the substrate fields, or any Claim Document Vault contents with partners. The product shares only the user's opt-in signal (a single boolean: "this user opted in to partnership offers"). The user can opt out at any time; the opt-out is propagated to the partner within 24 hours. The boundary is enforced by a CI test (the launch-claim registry entry) that scans the production code for any code path that shares user data with a non-user, non-partner-opt-in party.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** The Value-Add Partnerships framework is built as framework first (opt-in toggle + opt-in webhook + no-share boundary + launch-claim registry entry), partnerships second (per-partner ADRs after a partner is vetted). The partner-vetting policy is a public document with 7 criteria. The opt-in toggle is disabled by default; the consent is recorded in the consent ledger with purpose `partnership_offers`. The opt-in webhook shares only the opt-in signal — never user data. The CI test (the launch-claim registry entry) is the boundary enforcement. The Claim Document Vault is excluded by design. The "data-handling policy per third-party integration" pattern is reusable for future ADRs (LLM provider, Qdrant, Supabase Storage). See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #5 (the Value-Add Partnerships framework that this ADR governs), [ADR-2026-07-19-07](./ADR-2026-07-19-07-security-phase-2-server-side-consent-ledger.md) (the consent ledger that the new purpose is added to), [ADR-2026-07-19-15](./ADR-2026-07-19-15-claim-document-vault-privacy-policy.md) (the no-medical-records boundary), [canonical architecture doc](../../architecture/coverwise_canonical_architecture.md).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Value-Add Partnerships framework is built as framework first (opt-in + webhook + no-share boundary), partnerships second (partner-vetting policy + partner onboarding). The framework is empty by default; the user opts in explicitly. The no-medical-records boundary is enforced. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The framework is the foundation; the partnerships are the application. The partner-vetting policy is a public document; the opt-in toggle is disabled by default; the opt-in webhook shares only the opt-in signal. The CI test is the boundary enforcement. The "data-handling policy per third-party integration" pattern is reusable for future ADRs (LLM provider, Qdrant, Supabase Storage).

---

## Context

The operator's per-feature thinking (per ADR-2026-07-19-08 revision 2) was: "we haven't thought of long term partnerships, we are letting users upload all kinds of policy docs, then why not later have partnerships to get ads or upsell policies etc?" The Value-Add Partnerships framework is the answer: the product will, in the long term, partner with insurers, financial planners, tax advisors, will-preparation services, and other adjacent services. The user is a high-value audience for these partners.

The framework's design must balance two concerns:

1. **The user has a right to control their data.** The user uploads sensitive personal data (policies, family coverage, claim documents, life events). The user has a right to decide who sees what. The framework must be opt-in, granular, and revocable.
2. **The partners have a legitimate interest in reaching the user.** Insurance customers are a high-value audience. The partners are vetted (regulatory standing, data handling, etc.). The partners can offer relevant services (a tax advisor for a user with a large life insurance policy, a financial planner for a user with a family floater).

The framework's design resolves the tension: the user opts in (explicit consent), the partner is vetted (public criteria), the product shares only the opt-in signal (not the user's data), the user can opt out at any time. The boundary is the no-share rule: the product does not transmit user data to partners; the user is the actor, not the recipient.

The operator's other per-feature thinking (per ADR-2026-07-19-15) was about the Claim Document Vault's privacy: the vault is excluded from partnerships by design. This ADR formalizes the exclusion.

---

## The framework in detail

### Component 1: The partner-vetting policy (a public document, a marketing site page)

- **What it is:** a public document on the marketing site that names the criteria a partner must meet to be listed as a CoverWise-vetted partner. The criteria are:
  1. **Regulatory standing**: the partner must be registered with the relevant Indian regulator (IRDAI for insurers, SEBI for financial advisors, CBDT for tax advisors, etc.). The partner's registration number is on the marketing site.
  2. **Data handling**: the partner must commit to data handling practices that meet or exceed Indian data protection law (the Information Technology Act, the proposed Digital Personal Data Protection Act, the proposed Digital Information Security in Healthcare Act). The partner's data handling policy is on the marketing site.
  3. **No resale**: the partner must commit to not reselling, sharing, or trading the user's opt-in signal with any third party. The partner's no-resale commitment is on the marketing site.
  4. **No unsolicited contact**: the partner must commit to not contacting the user outside the channel the user opted into (e.g. if the user opts in to email, the partner sends email, not phone calls). The partner's no-unsolicited-contact commitment is on the marketing site.
  5. **Opt-out honored**: the partner must commit to honoring the user's opt-out within 24 hours. The partner's opt-out SLA is on the marketing site.
  6. **No dark patterns**: the partner must commit to not using dark patterns in their offer UX (e.g. pre-checked opt-ins, hidden costs, misleading copy). The partner's no-dark-patterns commitment is on the marketing site.
  7. **Annual review**: the partner is reviewed annually. The review is published. The review covers the partner's continued regulatory standing, data handling, and customer feedback.
- **Who is the author:** the operator (Pranay) is the author of the partner-vetting policy. The policy is a public document. The policy can be revised by the operator; the revision is published with a date.
- **What the marketing site shows:** a "Partners" page that lists each vetted partner with the criteria they met, the partner's regulatory standing, the partner's data handling policy, and a "report a partner" link for user feedback.

### Component 2: The in-app opt-in toggle (a settings page, a consent ledger entry)

- **What it is:** a settings page with a single toggle: "I'm interested in offers from CoverWise's vetted partners." The toggle is disabled by default. The toggle's label is clear: "We'll let vetted partners know you're interested. We will NOT share your policies, family coverage, claim documents, or any other personal data with partners. We'll only share the fact that you've opted in. You can opt out at any time."
- **What the toggle does:** when the user enables the toggle, the consent ledger (per ADR-2026-07-19-07) records a new consent with purpose `partnership_offers`, timestamp, principal, and version. When the user disables the toggle, the consent ledger records a withdrawal.
- **What the user sees:** a confirmation card after enabling: "You're opted in. Vetted partners will be able to send you offers through the channels you've selected. You can change your preferences or opt out at any time in Settings."
- **What the user can do:** the user can enable or disable the toggle at any time. The user can also enable per-partner-category opt-in (e.g. opt in to insurers but not to tax advisors). The per-category opt-in is a future enhancement; the first version has a single global toggle.
- **Why this matters:** the opt-in is explicit, granular, and revocable. The consent ledger (per ADR-2026-07-19-07) is the record. The user has full control.

### Component 3: The opt-in webhook (a server-enrolled endpoint, a partner polls or subscribes)

- **What it is:** a server-enrolled webhook endpoint that the partner polls (or subscribes to) to learn when a user has opted in. The webhook payload is: `{ "principal_id": "...", "opted_in": true/false, "consent_version": "...", "timestamp": "..." }`. The payload contains NO user data — only the opt-in signal.
- **What the partner sees:** the opt-in signal. The partner does not see the user's policies, family coverage, claim documents, life events, or any other personal data. The partner sees a single boolean: "this user opted in to partnership offers."
- **What the partner does with the opt-in signal:** the partner uses the signal to send an offer to the user through the channel the user selected (email, in-app, etc.). The partner does not use the signal for any other purpose. The partner's data handling is bound by the partner-vetting policy.
- **What the webhook does NOT do:** the webhook does not transmit user data. The webhook is a one-way signal: the product tells the partner "this user opted in" or "this user opted out." The partner does not poll the product for user data.
- **How the partner is enrolled:** the partner signs a data processing agreement (DPA) with the operator. The DPA binds the partner to the partner-vetting policy. The DPA is reviewed by legal counsel (a future legal review ADR). The partner is added to the partner registry (a server-side table of vetted partners with their webhook URLs and credentials).
- **Why this matters:** the webhook is the technical safeguard. The DPA is the legal safeguard. The no-share rule is the boundary.

### Component 4: The no-medical-records boundary (per ADR-2026-07-19-15)

- **What it is:** the Claim Document Vault's contents (per ADR-2026-07-19-15) are excluded from the Value-Add Partnerships framework by design. The vault's no-share rule is absolute: the vault's contents are not shared with anyone, ever, including partners.
- **Why this matters:** the operator's per-feature thinking was clear: the vault is a filing cabinet for the user's claim paperwork, including medical records. The vault is private to the user. The vault is not a partnership data source.
- **How it's enforced:** the CI test (the launch-claim registry entry) scans the production code for any code path that shares vault contents with a non-user, non-partner-opt-in party. The test fails if such a code path is found. The test is the boundary.

### Component 5: The no-other-data boundary (the substrate, the family coverage, the check-in, the adequacy)

- **What it is:** in addition to the no-medical-records boundary, the product does not share the substrate's extracted fields, the Family Coverage Map's per-member observations, the Coverage Check-in's life events, the Coverage Adequacy's scenarios, or any other user data with partners. The product shares only the opt-in signal.
- **Why this matters:** the user uploads sensitive personal data across multiple surfaces. The user has a right to control who sees what. The framework's no-share rule is absolute: the product shares only the opt-in signal, nothing else.
- **How it's enforced:** the CI test (the launch-claim registry entry) covers all user data, not just the vault. The test scans for any code path that shares user data with a non-user, non-partner-opt-in party.

---

## Options considered

### Option A: Build the framework as described above (opt-in toggle + webhook + no-share boundary), partner onboarding second. CHOSEN.

- **How it works:** the framework is built first (1-2 weeks). The partner-vetting policy is published. The opt-in toggle is in the app. The webhook is enrolled. The framework is empty by default. Partners are onboarded one at a time, after the partner-vetting policy is signed by the partner and the DPA is reviewed.
- **Why chosen:** the framework is the foundation. The partnerships are the application. The user has control from day one. The boundary is enforced from day one. The partnerships are added incrementally.
- **Cost:** S-M. 1-2 weeks for the framework. The partner-vetting policy is a marketing site page (a 1-day doc). The opt-in toggle is a settings page (a 1-day UI + consent ledger integration). The webhook is a server endpoint (a 1-2 day backend). The CI test is a 0.5-day test.
- **Quality:** the framework is honest. The user has control. The boundary is enforced. The partnerships are added when ready.

### Option B: Build the framework + onboard a single launch partner (e.g. a tax advisor) in the same release. REJECTED.

- **How it works:** the framework is built + a single launch partner is onboarded in the same release. The partner-vetting policy is published. The opt-in toggle is in the app. The webhook is enrolled. The partner is live.
- **Why rejected:** the partner onboarding is a separate workstream. The partner must be vetted (regulatory standing, data handling, etc.); the vetting is a legal review. The partner must sign the DPA; the DPA is a legal document. The partner's webhook must be tested; the testing is an integration effort. The single-partner launch is a 4-6 week workstream, not a 1-2 week workstream. Mixing the framework and the launch partner is a scope creep.

### Option C: Build the framework + onboard multiple launch partners (e.g. an insurer, a tax advisor, a financial planner) in the same release. REJECTED.

- **How it works:** the framework is built + multiple launch partners are onboarded in the same release.
- **Why rejected:** same as option B, but worse. Multiple partners = multiple DPAs = multiple legal reviews = multiple integration efforts = a 2-3 month workstream. The framework is the foundation; the partnerships are added incrementally.

---

## Chosen path

**Option A: the framework first, partnerships second.** The user has control from day one. The boundary is enforced from day one. The partnerships are added when ready.

**Work to implement:**

1. **Partner-vetting policy** — a public document on the marketing site. The document names the criteria, the partner's commitments, the annual review process. The marketing site page lists each vetted partner. Effort: S. 1-2 days.
2. **In-app opt-in toggle** — a settings page with a single toggle. The toggle's label is clear. The toggle records consent in the consent ledger with purpose `partnership_offers`. Effort: S. 1-2 days.
3. **Consent ledger purpose** — extend the consent ledger (per ADR-2026-07-19-07) with the new `partnership_offers` purpose. Effort: S. 0.5 day.
4. **Opt-in webhook** — a server endpoint that the partner polls or subscribes to. The webhook payload is the opt-in signal only. Effort: M. 1-2 days.
5. **Partner registry** — a server-side table of vetted partners with their webhook URLs and credentials. Effort: S. 0.5 day.
6. **CI test (no-share boundary)** — a CI test that scans the production code for any code path that shares user data with a non-user, non-partner-opt-in party. The test fails if such a code path is found. Effort: S. 0.5 day.
7. **Launch-claim registry entry** — "the Value-Add Partnerships framework does not share user data with partners; only the opt-in signal is shared." Effort: S. 0.5 day.
8. **Canonical doc update** — define the Value-Add Partnerships framework as a first-class section of the canonical doc. The partner-vetting policy, the opt-in toggle, the webhook, and the no-share boundary are documented. Effort: S. 0.5 day.

**Total effort:** S-M. 1-2 weeks for the framework. The partner onboarding is a future workstream (a separate ADR per partner).

**Sequence:**

1. Partner-vetting policy (the public document first).
2. Consent ledger purpose (the legal basis).
3. In-app opt-in toggle (the user-facing feature).
4. Opt-in webhook + partner registry (the technical safeguard).
5. CI test (the boundary enforcement).
6. Launch-claim registry entry + canonical doc update (the record).

**Dependency:** the Value-Add Partnerships surface (per ADR-2026-07-19-08 #5) is unblocked after this ADR is implemented. The surface is a settings page with the opt-in toggle. The partner onboarding is a future workstream.

---

## Why this path

### 1st-principle argument

The user uploads sensitive personal data. The user has a right to control who sees what. The product's job is to give the user control, not to take it. The framework is the engineering answer: the user opts in explicitly, the partner is vetted, the product shares only the opt-in signal, the user can opt out at any time.

The same argument as the Claim Document Vault privacy policy (per ADR-2026-07-19-15): the user has a right to control their data. The framework respects the right.

### Anti-lying-UI argument (motto v3 §0.7)

A partnership surface that says "we'll only share your opt-in signal" but shares the user's policies is a lying UI. The no-share boundary is the engineering answer. The launch-claim registry entry is the test.

### Anti-coerced-consent argument (motto v3 §0.4 acceptance contract)

The opt-in is explicit, granular, and revocable. The user can grant or deny. The user can opt out at any time. The acceptance contract for "the user enables the partnership opt-in" is "the user knows what is happening and can stop it."

### Anti-undefined-boundary argument (motto v3 §0.11 customer-facing claims)

The partner-vetting policy is a public document. The criteria are public. The partner's commitments are public. The boundary is explicit. The user can audit.

### Operator-decision-required argument

This ADR is **proposed, not accepted**. The framework is a recommendation. The operator may want a different framework (e.g. opt-in per partner category, opt-in per channel, opt-in with a confirmation email); the operator may want to defer partner onboarding until a partner is actually vetted. The reason this is an ADR and not a code change is that the framework is load-bearing and the operator should sign off on it.

---

## Tradeoffs

- **The framework is empty by default.** No partners are listed. The user sees the opt-in toggle but the opt-in does nothing until a partner is onboarded. The user may be confused. The mitigation is the opt-in toggle's label is clear: "We'll let vetted partners know you're interested. We're currently partnering with [list]."
- **The partner-vetting policy is a public commitment.** The operator must hold partners to the criteria. The annual review is a real review. The mitigation is the annual review is a workstream; the operator is the author of the review.
- **The opt-in webhook is a one-way signal.** The partner cannot query the product for user data. The partner cannot ask "what policies does this user have?" The partner sees only the opt-in signal. The mitigation is the partner's offer is generic; the user responds if interested.
- **The no-share boundary is enforced by a CI test.** The test may be too strict (e.g. legitimate test fixtures). The mitigation is the test's exclusion list.
- **The opt-in is a single global toggle.** The user cannot opt in to insurers but not to tax advisors. The per-category opt-in is a future enhancement. The mitigation is the first version is the global toggle; the per-category opt-in is a follow-up.

---

## Assumptions

- **The partner-vetting policy is the right set of criteria.** The 7 criteria (regulatory standing, data handling, no resale, no unsolicited contact, opt-out honored, no dark patterns, annual review) are a starting set. The operator may want additional criteria; the ADR is the place to discuss.
- **The opt-in toggle's label is clear.** The label is long but explicit. The operator may want a shorter label; the ADR is the place to discuss.
- **The opt-in webhook's payload is the opt-in signal only.** The payload is `{ "principal_id": "...", "opted_in": true/false, "consent_version": "...", "timestamp": "..." }`. The operator may want additional fields (e.g. the partner categories the user opted in to); the ADR is the place to discuss.
- **The partner registry is a server-side table.** The table is small (a handful of partners). The operator may want a different storage; the ADR is the place to discuss.
- **The CI test is the right enforcement mechanism.** The test scans the production code for any code path that shares user data. The operator may want additional enforcement (e.g. a runtime check); the ADR is the place to discuss.
- **The legal review (DPA) is a separate workstream.** The partner signs a DPA with the operator. The DPA is reviewed by legal counsel. The legal review is a future ADR.

---

## Risks

- **The operator disagrees with the framework.** This is a feature of the decisions-first process, not a bug. The mitigation is to make the framework explicit and easy to revisit.
- **A partner is vetted but the user opts in and the partner's offer is bad.** The user can opt out. The partner can be un-vetted. The mitigation is the annual review + the user feedback mechanism.
- **The opt-in webhook is compromised.** The webhook is authenticated (the partner has credentials). The mitigation is the credentials are rotated; the partner is reviewed annually.
- **The no-share boundary is bypassed.** The CI test catches the bypass. The mitigation is the CI test is a release guard; the bypass is a regression.
- **The partner-vetting policy is held to a different standard than the policy says.** The annual review is the safeguard. The mitigation is the review is published; the user can audit.
- **A regulator requires a different framework.** The mitigation is the framework is a first-class boundary; any change triggers an ADR revision.

---

## Validation plan

- **For the partner-vetting policy:** a doc-lint test that asserts the policy is published and the criteria are listed.
- **For the in-app opt-in toggle:** a widget test that asserts the toggle is present, the label is clear, and the consent is recorded in the consent ledger.
- **For the opt-in webhook:** an integration test that asserts the partner receives the opt-in signal when the user enables the toggle, and the opt-out signal when the user disables the toggle.
- **For the partner registry:** a unit test that asserts the partner is enrolled with the right webhook URL and credentials.
- **For the no-share boundary:** a CI test that scans the production code for any code path that shares user data with a non-user, non-partner-opt-in party. The test fails if such a code path is found.
- **For the launch-claim registry:** a CI test that asserts the entry exists and links to the tests.
- **For the canonical doc:** a doc-lint test that asserts the Value-Add Partnerships framework is defined.
- **End-to-end:** the launch playbook's Step 8 (real-device end-to-end) runs after the framework is implemented. The validation includes: user opens Settings → enables the partnership opt-in → consent is recorded → partner receives the opt-in signal → partner sends an offer → user receives the offer → user can opt out → opt-out is propagated to the partner.

---

## Rollback or migration path

The framework is additive. The partner-vetting policy is a public document. The opt-in toggle is a settings page. The opt-in webhook is a server endpoint. The partner registry is a server-side table. The no-share boundary is a CI test.

If the framework turns out to be wrong:
- The partner-vetting policy can be revised (the policy is updated; the partners are re-vetted).
- The opt-in toggle can be hidden (the settings page is removed).
- The opt-in webhook can be disabled (the endpoint returns 404).
- The partner registry can be cleared (the partners are un-enrolled).
- The no-share boundary can be disabled (the CI test is removed; the boundary is gone).

The launch-claim registry entry is updated when the framework changes. The CI gate fails if the entry is not updated.

---

## What would cause this decision to be revisited

- **A partner is vetted and onboarded.** The framework is exercised. The partner onboarding is a future ADR.
- **The operator wants per-category opt-in.** A future ADR adds per-category opt-in (insurers, tax advisors, financial planners, etc.).
- **A regulator requires additional disclosures.** A future ADR adds the disclosures.
- **The Indian Digital Personal Data Protection Act is enacted.** A future ADR revises the framework to match the new law.
- **The market changes.** A competitor offers a different partnership model. The operator may decide to revise. This ADR's revisit trigger would note the change but the original 1st-principle argument stands.

---

## Anything else? (operator's standing review prompt)

The Value-Add Partnerships framework raises a more general question: **what other third-party integrations does the product have, and what are their data-handling policies?** The pattern is: any third-party integration that handles user data has an explicit data-handling policy.

- **LLM providers (OpenAI, Anthropic, etc.)** — the user's policies and the substrate's extracted fields are sent to the LLM for extraction, summary, and Q&A. The data-handling policy: the LLM provider is contractually bound not to train on the user's data (the operator's API agreement with the LLM provider); the data is transmitted over TLS; the data is not stored on the LLM provider's servers beyond the request-response cycle (per the LLM provider's zero-retention policy, where applicable). The launch-claim registry entry is "CoverWise does not allow LLM providers to train on user data; data is transmitted over TLS and is not retained beyond the request-response cycle." The policy is already in the consent ledger (per ADR-2026-07-19-07) with purpose `model_improvement` (the user can opt out of having their data used for model improvement). The policy is a future ADR ("LLM provider data-handling policy") to formalize.
- **Vector database (Qdrant)** — the substrate's embeddings are stored in Qdrant. The data-handling policy: Qdrant is a managed service; the operator's account is bound by Qdrant's data-handling policy; the embeddings are not user-readable (they are vectors, not text). The launch-claim registry entry is "CoverWise stores embeddings in Qdrant; the embeddings are vectors, not text; the operator's Qdrant account is bound by Qdrant's data-handling policy." The policy is a future ADR.
- **Storage provider (Supabase Storage)** — the user's uploaded documents are stored in Supabase Storage. The data-handling policy: Supabase is a managed service; the operator's account is bound by Supabase's data-handling policy; the data is stored in the operator's region (India, per the operator's data residency requirement). The launch-claim registry entry is "CoverWise stores user documents in Supabase Storage in the operator's region; the operator's Supabase account is bound by Supabase's data-handling policy." The policy is a future ADR.
- **Analytics provider (the RevOps analytics events per ADR-2026-07-19-08 #5)** — the analytics events may include user actions. The data-handling policy: the events are aggregate, not individual; the events do not include user documents; the events are stored in Supabase; the operator's account is bound by Supabase's data-handling policy. The launch-claim registry entry is "CoverWise stores analytics events in Supabase; the events are aggregate, not individual; the events do not include user documents." The policy is a future ADR.

The pattern is reusable: any third-party integration that handles user data gets a data-handling ADR. The ADRs are the engineering answer to the user's right to know who sees their data.

---

## Links

- **Affected files (this ADR, after operator sign-off):**
  - `docs/architecture/partner_vetting_policy.md` (new: the public partner-vetting policy)
  - `mobile/lib/screens/partnership_settings_screen.dart` (new: the settings page with the opt-in toggle)
  - `src/services/consent_ledger_service.py` (extend: the new `partnership_offers` purpose)
  - `supabase/migrations/2026_07_19_partner_registry.sql` (new: the partner registry table)
  - `src/api/partnership_webhook.py` (new: the opt-in webhook endpoint)
  - `src/services/partnership_service.py` (new: the service that manages partner enrollment and opt-in propagation)
  - `mobile/marketing-site/src/pages/partners.md` (new: the marketing site Partners page)
  - `tests/test_partner_vetting_policy.py` (new: the doc-lint test)
  - `tests/test_partnership_opt_in_toggle.py` (new: the widget test)
  - `tests/test_partnership_opt_in_webhook.py` (new: the integration test)
  - `tests/test_partner_registry.py` (new: the unit test)
  - `tests/test_no_user_data_share.py` (new: the CI test for the no-share boundary)
  - `docs/launch_claims/value-add-partnerships-framework.md` (new: the launch-claim registry entry)
  - `docs/architecture/coverwise_canonical_architecture.md` (add the Value-Add Partnerships framework as a first-class section)
  - `docs/decisions/README.md` (add this ADR to the index)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #5 (the Value-Add Partnerships framework that this ADR governs)
  - [ADR-2026-07-19-07](./ADR-2026-07-19-07-security-phase-2-server-side-consent-ledger.md) (the consent ledger that the new purpose is added to)
  - [ADR-2026-07-19-15](./ADR-2026-07-19-15-claim-document-vault-privacy-policy.md) (the no-medical-records boundary)
  - [Canonical architecture doc](../../architecture/coverwise_canonical_architecture.md) (target of the doc update)
  - `docs/audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md` (the audit findings on third-party data handling)
  - `docs/audits/coverwise_product_strategy_monetization_scope_compliance_marketing_audit_2026-07-18.md` (the strategy audit on partnerships and disclosures)
- **Related code (current state):**
  - `src/services/consent_ledger_service.py` (the consent ledger; the new purpose is added here)
  - `mobile/lib/services/consent_ledger.dart` (the Flutter consent ledger)
  - `supabase/migrations/` (the Supabase migrations; the partner registry is a new migration)
- **Motto v3 alignment:** §0.4 (acceptance contract; the opt-in is the contract), §0.5 (evidence tiers; the no-share boundary is enforced by a launch-claim registry test), §0.7 (AI output boundary; the framework does not share user data with partners), §0.11 (customer-facing claims; the partner-vetting policy is a customer right), §0.12 (this document).

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | **Reaffirmed + launch-gate clarification per [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) §7 and constitution Principle 10.** The partnerships framework remains disabled by default. Inclusion in the widened wedge does not authorize any partner/referral/offer surface for launch. Any partner path requires a separate accepted ADR, explicit opt-in, purpose-specific consent, no default sharing of uploaded documents, compensation disclosure, and launch-claim coverage. Original reasoning preserved. | Operator direction: layered doctrine stack. |


---

## Doctrine reconciliation note (2026-07-29)

> Append-only note added 2026-07-29. This section does not modify any prior
> content in this ADR; the original decision, reasoning, and existing update
> logs above remain intact and authoritative for their date.

- **Date:** 2026-07-29
- **Governing ADR:** [ADR-2026-07-29-02 (doctrine stack reconciliation)](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
- **What changed:** [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) establishes a layered doctrine stack. The [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) (`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`) now sits above feature ADRs, with a five-gate stack (Gates A-E: Outcome, Truth, Product role, Lifecycle, Strategy/commercial). Reaffirmed + launch-gate clarification: partnerships framework remains disabled by default. Inclusion in the widened wedge does not authorize any partner/referral/offer surface for launch. Any partner path requires a separate accepted ADR, explicit opt-in, purpose-specific consent, no default document sharing, compensation disclosure, launch-claim coverage.
- **Why:** Operator direction to unify two competing uncommitted first-principles documents into one layered stack before any boundary-shaped code changes.
- **What triggered it:** Discovery that the repository held conflicting uncommitted doctrine (Principles vs Wedge) and that ADR-2026-07-29-01 self-declared "Accepted" without sign-off evidence.
- **What original reasoning remains valid:** All prior reasoning in this ADR is preserved unchanged. This note only constrains surface semantics where they intersect the constitution's gates.
- **Status change for this ADR:** None (this ADR's own status is unchanged by this note).
- **Operator sign-off:** None required for this note; it records the reconciliation linkage. The reconciliation ADR itself remains Proposed pending operator sign-off.
- **Code authorization:** None. No code, route, entitlement, pricing, comparison, claims, renewal, camera, demo, or onboarding change is authorized by this note.
