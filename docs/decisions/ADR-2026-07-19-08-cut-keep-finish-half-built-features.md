# ADR-2026-07-19-08: Cut/keep/finish decisions for 10 half-built features, anchored to the long-term product shape

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** For each of the 10 features the audits flag as "premature, deceptive in current form, or shell," the cut/keep/finish call is anchored to **the long-term product shape** (the wedge: owned policy → evidence summary → verified Q&A → coverage check-in → coverage adequacy → family coverage map → claim document vault → renewal/contact utility), not to "what can we do in 1-2 days." A feature that is part of the long-term shape is **finished properly or kept and redesigned** even if it takes weeks. A feature that is not part of the long-term shape is **cut, not deferred.** A feature that is a thin slice of the long-term shape is **scoped down to the honest part.** Result: **0 cuts, 4 keep-redesign, 4 finish-properly, 2 unchanged** (per revision 2 after operator's per-feature thinking). This replaces the first version of this ADR (which had 4 cuts, 4 keep-with-scope, 1 finish-minimum, 1 defer-pending-D5 and was anchored to 1-2 day triage) and revision 1 (which had 4 cuts, 3 finish-properly, 1 routing change, 1 same-as-billing).
- **Date:** 2026-07-19 (original); 2026-07-19 (revised after operator feedback; see Update log)
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 2, operator sign-off 2026-07-19).** Implementation may begin in dependency order. The 4 keep-redesign and 4 finish-properly items are independent workstreams; the launch happens after the full wedge lands and the launch playbook's Step 8 validates it. Future revisions to per-feature calls will be appended to the Update log below.
- **Related artifacts:** [canonical architecture doc](../../architecture/coverwise_canonical_architecture.md), [ADR-2026-07-19-04](./ADR-2026-07-19-04-coverage-gap-claim-assistance-thin-slice.md), [ADR-2026-07-19-06](./ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md).

## Update log

- **2026-07-19 (original, never committed)**: First version filed with 4 cuts, 4 keep-with-scope, 1 finish-minimum, 1 defer-pending-D5 (anchored to 1-2 day triage; net 5-7 day sprint). Status: Rejected by the operator on the grounds that "cutting everything because of not being planned is wrong; maybe defer, but this is not long-term thinking nor 1st principles nor motto_v3 aligned."
- **2026-07-19 (revision 1)**: Rewritten anchored to the long-term product shape. 4 cuts, 3 finish-properly, 1 routing change, 1 same-as-billing. Net: 4 cuts in 2.5 days, ~6-10 weeks of finish-properly work. Status: Proposed. Awaiting operator sign-off.
- **2026-07-19 (revision 2, this revision)**: Updated after operator's per-feature thinking. The operator widened the product from a narrow wedge ("owned policy → evidence summary → verified Q&A → renewal/contact utility") to a broader wedge that includes: coverage adequacy over time (Health Score, What-If Premium), family context (Family), post-claim document tracking (Old claims / Claim tracker), and a future ad/upsell partnership surface (Lead capture). Several per-feature calls are revised. See "Revisions" section below. Status: Proposed. Awaiting operator sign-off.
- **2026-07-19 (operator sign-off, revision 2)**: **Accepted.** Operator reviewed revision 2 and signed off. Implementation may begin. The 4 keep-redesign and 4 finish-properly items are independent workstreams. The launch happens after the full wedge lands and the launch playbook's Step 8 validates it. The reader sees the full decision history: original (rejected), revision 1, revision 2, sign-off. The reasoning for each per-feature call is visible in §"Per-feature decisions" and §"Revisions."

---

## What changed since the first version of this ADR

The first version of this ADR (filed earlier today, never committed) framed the cut/keep/finish call as a 1-2 day cleanup sprint: 4 cuts, 4 keep-with-scope, 1 finish-minimum, 1 defer-pending-D5, with a net 5-7 day effort. The operator rejected that framing on three grounds: (a) it was anchored to short-term tactics, not long-term product shape; (b) "defer pending D5" was a punt, not a decision; (c) the cuts disguised product calls (e.g. "we can't finish a real billing SDK in 1-2 days, so cut it") as engineering calls.

This revision re-derives each row from the long-term product shape. Where the first version said "defer pending D5" for billing, this version says "finish properly" because verified Q&A has a real cost and a real entitlement. Where the first version said "keep-with-scope" for claim tracker, this version says "scope down as part of the long-term product" — same call, different reason.

---

## Context: the long-term product shape

CoverWise is a Flutter mobile + FastAPI + Supabase product for Indian insurance policyholders. The audits converge on a narrow wedge:

> **owned policy → evidence summary → verified Q&A → renewal/contact utility.**

This wedge is the product. Every feature in the codebase should answer one question: **what role does this feature play in the wedge?** If a feature has no role, it is cut. If a feature is a thin slice of the wedge, it is scoped down to the honest part. If a feature is core to the wedge, it is finished properly, even if the work is measured in weeks.

**Owned policy**: the user uploads a PDF or photograph of their insurance policy. The system extracts the document and produces a durable, private, evidence-backed record on the user's device. The record is grounded in the substrate. Every field has a page reference, a quote, and a confidence. This is the foundation. Without it, nothing else is honest.

**Evidence summary**: the first screen the user sees after upload. Shows what the policy actually says, with citations. Honest about what the substrate knows and what it does not. The "not yet extracted" pattern is the contract: the user is told what the system does not know.

**Verified Q&A**: the daily-use surface. The user asks the policy a question and gets a grounded answer with a page reference. The cost is real (LLM calls, embedding generation, storage, retrieval). The free tier is real. The paid tier is real. The entitlement is real. The billing surface is real.

**Renewal/contact utility**: when the user needs to renew or file a claim, the product gives them the right phone number, email, or insurer process page, grounded in their own policy. Not a claim filing system. Not a renewal service. A grounded utility.

The wedge is the product. The 10 half-built features are the surfaces around the wedge. The cut/keep/finish call is derived from the wedge.

---

## Per-feature decisions

### 1. Insurance Health Score — **CUT. Not part of the long-term product.**

- **Role in the wedge:** none. "Excellent / At Risk" is a suitability rating from a different product (an actuary, an insurer's underwriting tool, a regulator's dashboard). CoverWise is not an actuary. The wedge does not include a suitability rating and should not.
- **Why cut:** the feature is not a thin slice of the wedge. It is a feature from a different product that was added to this one. Disclaimers do not fix the lying UI. The honest call is to remove the surface, not to find a real actuarial source.
- **What is removed:** `mobile/lib/providers/health_score_provider.dart`, `mobile/lib/widgets/health_score_card.dart`, the mount in `mobile/lib/screens/dashboard_screen.dart:121-122`, `mobile/test/health_score_test.dart`, the provider registration, and any docs that describe the feature.
- **What stays:** the dashboard. The dashboard is a real surface (entry to the wedge). Removing the Health Score card is a 1-line edit.
- **Effort:** S. 0.5 day.
- **Source audits:** `docs/audits/coverwise_product_mobile_experience_accessibility_audit_2026-07-18.md` P0-01, `docs/audits/coverwise_current_state_progress_and_next_moves_review_2026-07-19.md §5`.

### 2. What-If Premium Calculator — **CUT. Not part of the long-term product.**

- **Role in the wedge:** none. Premium estimation is an underwriting function. CoverWise is not an underwriter. The user who wants to know "what if I increase my sum insured" should ask an insurer for a quote. The wedge does not include a premium estimator and should not.
- **Why cut:** same reason as #1. The feature is from a different product. The hardcoded multipliers (0.85/1.15/1.08/1.03/1.05) are not from any underwriter and cannot be made honest without becoming a different product.
- **What is removed:** `mobile/lib/utils/what_if_calculator.dart`, `mobile/lib/screens/what_if_calculator_screen.dart`, the route `mobile/lib/main.dart:300`, `mobile/test/what_if_calculator_test.dart`, the entry in `more_screen.dart:24`.
- **What stays:** the More screen. The What-If entry is a 1-line removal.
- **Effort:** S. 0.5 day.
- **Source audits:** `docs/audits/coverwise_product_mobile_experience_accessibility_audit_2026-07-18.md` P0-03, `docs/audits/coverwise_current_state_progress_and_next_moves_review_2026-07-19.md §5`.

### 3. Old claims assistant (`claims_assistant_screen.dart`) — **CUT. Reroute `/claims` to the new `claim_assistance_screen.dart`. The new screen is part of the wedge.**

- **Role in the wedge:** the renewal/contact utility component of the wedge. The new screen is the substrate-backed, insurer-URL-lookup-table-backed, legal-disclaimer-carded, IRDAI-escalation-carded version that landed in bc16e9e. The old screen is generic copy with no insurer routing and no substrate.
- **Why cut the old, keep the new:** the two screens cannot coexist. The user must not be able to reach a feature that bypasses the substrate. This is the canonical doc's "no parallel paths" rule. The new screen is the long-term shape; the old screen is a previous attempt that did not survive the substrate arriving.
- **What is removed:** `mobile/lib/screens/claims_assistant_screen.dart`, the old test `mobile/test/claim_assistance_screen_test.dart` (the new screen has its own test), the `/claims` route registration in `mobile/lib/main.dart:258` (replaced with the new screen's route).
- **What stays:** `mobile/lib/screens/claim_assistance_screen.dart` (the new screen, the per-insurer URL lookup table at lines 313-341, the `_LegalDisclaimerCard`, the `_IRDIAEscalationCard`).
- **Routing change:** every reference to `/claims` in `more_screen.dart:29` and `policy_detail_screen.dart:15,1094` must point to the new screen. The new screen is already reachable from the policy detail screen; the More screen entry needs to be repointed.
- **Effort:** S. 1 day.
- **Source audits:** `docs/audits/coverwise_current_state_progress_and_next_moves_review_2026-07-19.md §5`, `docs/CONTENT_AUDIT_2026-07-19.md` (the 14 in-app copy fixes already applied to the new screen).

### 4. Billing stub / BillingAdapter — **FINISH PROPERLY. The billing surface is core to verified Q&A. Build the real thing.**

- **Role in the wedge:** verified Q&A has a real cost. LLM calls, embedding generation, storage, retrieval, and the operations audit's P0-13 ("Persist LLM token + cost by principal / document / feature / provider / model") confirm the cost is real. A free tier is real. A paid tier is real. An entitlement is real. A billing surface is real. Cutting the billing surface is cutting the wedge.
- **What "finish properly" means:**
  1. **Mobile billing SDK**: RevenueCat (or Paddle, or Lemon Squeezy) for store-integrated billing. Receipt verification on the server. Restore on reinstall. Refund flow. Tax/invoice.
  2. **Server-enforced entitlement ledger**: a `user_entitlements` table that is the only source of truth for "what plan is this user on." The client cannot grant itself a plan. The server checks the entitlement on every Q&A call. The audit's T-4-6 is explicit: "Server-enforced entitlements when introduced; remove client-only plan gates."
  3. **Free tier**: a real, documented free question count per month (e.g. 30 questions, refreshes on the 1st of the month). The count is server-enforced.
  4. **Paid tier**: a real plan with a real price. The price is set by the operator, not the LLM. The plan is described in the marketing site, not invented in the app.
  5. **Restore**: a "Restore purchases" button on the Q&A and settings screens, backed by the store's restore API.
  6. **Server-notification handler**: a webhook endpoint (`POST /billing/webhook`) that the store calls when a subscription event happens. The handler is durable (outbox, not BackgroundTasks — see D3).
  7. **Release guard**: until the SDK and the server are wired, the surfaces that depend on the billing adapter (Q&A pack UI, settings Upgrade/Manage) are hidden behind `BILLING_ENABLED=false` in production. The flag is removed once the integration is real.
- **Why this is not a "1-2 day finish":** it is 2-4 weeks of work. It is the right work. Cutting it would mean cutting the wedge.
- **What is removed:** the current `BillingAdapter` (which is a self-declared skeleton). The current Q&A pack UI's "Buy" buttons and price display. The current entitlement model stays and is extended (it is the math layer).
- **What is added:** the SDK integration, the server-enforced entitlement, the webhook handler, the receipt verification, the restore flow.
- **Effort:** L. 2-4 weeks. This is not a side task; it is a product task.
- **Source audits:** `docs/audits/coverwise_product_strategy_monetization_scope_compliance_marketing_audit_2026-07-18.md` P0-02, T-4-4, T-4-6; `docs/audits/coverwise_operations_reliability_observability_performance_cost_audit_2026-07-18.md` P0-13.
- **Dependency:** the launch playbook's Step 8 (real-device end-to-end) is the validation gate. The release-guard flag prevents the surfaces from being mounted before the integration is real.

### 5. Lead capture — **CUT. Account contact stays; lead surface is removed.**

- **Role in the wedge:** none. Lead capture is a marketing surface, not a product surface. The wedge does not include a "lead." The user has a phone number for IRDAI escalation and claim contact; that phone is part of the account, not a lead. The audit's T-4-7 is explicit: "Remove lead-capture (email/phone/interest) coupled to document uploads; split into account contact, support contact, and research participation as separate purpose-bound flows."
- **What is removed:** the `LeadCaptureDialog` and the `RateLimitDialog` (which gates lead capture); the launch site in `documents_screen.dart:222-230`; the backend `POST /capture-lead` in `src/api/document.py:611-658`; the `leads` table in `src/utils/document_store.py:47-55` (verify with `git log -p supabase/migrations/` before deleting); the `ConsentPurpose.leadCapture` in `mobile/lib/services/consent_ledger.dart:14`.
- **What stays:** `mobile/lib/services/contact_service.dart` as the storage primitive for the user's own phone (used by IRDAI escalation and claim contact). The phone lives in settings, with a clear "this is your account contact" framing, not in a first-upload dialog.
- **Marketing-channel note:** if the operator wants a "join the waitlist" surface, it lives on the marketing site, not in the product. The marketing site is DPDP-compliant by design (separate purpose, separate consent).
- **Effort:** S. 1 day.
- **Source audits:** `docs/audits/coverwise_product_strategy_monetization_scope_compliance_marketing_audit_2026-07-18.md` P0-07, T-4-7; `docs/audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md` P0-13.

### 6. Family inventory — **FINISH PROPERLY, SCOPED. Auto-detected members stay; manual additions are removed until identity scope is solved.**

- **Role in the wedge:** real, but narrow. The user has family members who are on their policies (spouse, kids, parents). The wedge shows the user which family members are on which policies, grounded in the substrate. The wedge does not include a global family identity model with manual additions and DOB collection — that is a different product (a family management app).
- **What "finish properly, scoped" means:**
  1. **Per-document surface**: auto-detected members (read from each document's `policyHolders` list, an extracted substrate field) are shown on the policy detail screen with a "from this document" pointer. The substrate field is the source; the UI displays it. No new collection; no global list.
  2. **No standalone Family tab**: the global "Family" tab in the bottom nav is removed. Family is a property of each policy, not a top-level destination.
  3. **No manual additions**: the "Add family member" dialog is removed. The user does not add family members; the policy does. The user can correct a holder's name on a specific document (T-3-11 in the task list) but that is a per-document correction, not a global add.
  4. **No DOB collection**: the FamilyMember model's DOB field stays in the code (some policies record DOB) but the UI does not collect it from the user.
  5. **Backend unchanged**: `src/api/family.py:1-11` stays "intentionally not mounted." The family is substrate-grounded; it does not need a separate API.
- **What "until identity scope is solved" means:** if the long-term product grows to include a family identity model (e.g. shared family policies across devices, family members as separate principals), that is a separate architectural decision. It is not the current wedge. The current wedge is per-policy, per-principal.
- **What is removed:** `mobile/lib/screens/family_screen.dart` (the standalone screen), `mobile/lib/screens/add_family_member_dialog.dart`, the bottom-nav entry, the `manualFamilyMembersKey` in `mobile/lib/services/app_state_repository.dart:102-136`.
- **What is added:** the per-document family members surface on the policy detail screen. This is a small extension of the existing policy detail UI.
- **Effort:** M. 1-2 weeks including a per-document family members widget and tests.
- **Source audits:** `docs/audits/coverwise_product_mobile_experience_accessibility_audit_2026-07-18.md` §P-family, T-3-11; `docs/audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md` P-family.

### 7. Claim tracker — **FINISH PROPERLY, SCOPED. The surface is renamed to "My claim notes" and is a personal log, not an insurer connection.**

- **Role in the wedge:** real, narrow. The user files a claim. They want to remember: when did I file, with whom, what was the claim number, what was said, what documents did I send. The wedge's renewal/contact utility does not file claims; it tells the user how to file. But the user has a real need for a per-claim log, and that log can be grounded in the substrate (the policy the claim is about, the document pointer, the insurer contact).
- **What "finish properly, scoped" means:**
  1. **Rename**: "Claim tracker" → "My claim notes" or "Claim log." The new name is honest.
  2. **Banner**: "Not connected to any insurer. This is your own log."
  3. **Per-record evidence pointer**: each claim note has a pointer to the policy document it is about (substrate-grounded). The user sees which policy this claim is about.
  4. **Per-record insurer contact**: the claim note can store the insurer phone/email/process page, copied from the policy's renewal/contact utility. No new data collection; just a copy of what the substrate already has.
  5. **Local-only persistence**: the claim log is local to the device. It is not a server resource. The user can export it as JSON or PDF if they want to share it.
  6. **No insurer API**: the log does not connect to any insurer. If the user wants to file a claim, they use the claim-assistance flow (the new `claim_assistance_screen.dart`).
- **What is removed:** the "Claim tracker" name and any "connected to insurer" copy.
- **What stays:** the local CRUD model `mobile/lib/models/claim_record.dart`. The route. The More-screen entry.
- **Effort:** M. 1-2 weeks including a renamed screen, the banner, the per-record pointer, and tests.
- **Source audits:** `docs/audits/coverwise_product_mobile_experience_accessibility_audit_2026-07-18.md` §claim-tracker; `docs/FLOW_AND_SCREEN_AUDIT.md:217,229`.

### 8. Insurance cards — **FINISH PROPERLY, SCOPED. The surface is renamed and is a quick-access display, not a verifiable document.**

- **Role in the wedge:** real, narrow. The user is at a hospital or a garage. They need to call their insurer or read their policy number. They don't have their email open. The product has a screen that shows: policy number, insurer, expiry, one-tap call, one-tap email. The wedge's renewal/contact utility needs this.
- **What "finish properly, scoped" means:**
  1. **Rename**: "Insurance cards" → "Quick access" or "My policy info." The new name is honest.
  2. **Banner**: "Display of your policy info, not a verifiable insurance document. Carry your insurer-issued card for any claim."
  3. **Offline-first**: the screen reads from the substrate locally. No network call. The user can reach it on a phone with no signal.
  4. **Wear / lock-screen friendly**: the surface is designed for one-handed use. Large tap targets. No scrolling. The phone call launches the dialer; the email launches the mail composer; the insurer process page is a deep-link.
  5. **No QR code, no PDF export**: the surface is not trying to be a verifiable proof. A QR code that says "I have a policy" without a cryptographic anchor is a worse lie than no QR code.
  6. **Per-policy card**: the screen shows one card per policy in the user's library. Tap a card to see the detail.
- **What is removed:** the "Digital proof of insurance" copy, the gradient decoration (or kept as decoration; the audit is OK with decorative gradients as long as the copy is honest), any "verifiable" framing.
- **What stays:** the route, the More-screen entry, the policy data, the call/email launch.
- **Effort:** M. 1-2 weeks including a renamed screen, the banner, the offline-first reading, and tests.
- **Source audits:** `docs/FLOW_AND_SCREEN_AUDIT.md:114`; `docs/strategic_assessment_2026-07-17.md:168`.

### 9. Literacy quiz — **CUT. Not part of the long-term product. The education play lives on the marketing site.**

- **Role in the wedge:** none. The product is not an education app. The substrate is the user's own policy; the user learns by reading their policy with the evidence summary, not by taking a generic quiz. The wedge does not include a literacy quiz and should not.
- **What is removed:** `mobile/lib/screens/insurance_literacy_screen.dart`, the route `main.dart:299`, the entry in `more_screen.dart:32-33`.
- **What stays:** the glossary content. The glossary can be rehosted on the marketing site as part of the public content play. The strategy audit's recommendation is "Move to public content later" — the public content site is the right place.
- **Marketing-site note:** if the operator wants to do an "Insurance 101" surface, it lives on the marketing site. The marketing site is DPDP-compliant (separate purpose, separate consent) and is not the product.
- **Effort:** S. 0.5 day for the cut. The marketing-site rehost is a separate workstream.
- **Source audits:** `docs/audits/coverwise_product_mobile_experience_accessibility_audit_2026-07-18.md` §literacy; `docs/CUSTOMER_NEEDS_RESEARCH.md:221,269,294,333`; `docs/strategic_assessment_2026-07-17.md:123,168`.

### 10. Q&A packs — **FINISH PROPERLY (same workstream as #4). The Q&A pack UI is the billing surface for verified Q&A.**

- **Role in the wedge:** real, core. Verified Q&A is the daily-use surface of the wedge. Verified Q&A has a real cost. The Q&A pack UI is the surface that turns the cost into a product: free tier with N questions per month, paid tier with a plan, restore on reinstall, refund flow. Cutting the Q&A pack UI is cutting the billing surface for the wedge.
- **What "finish properly" means:** same workstream as #4. The Q&A pack UI is part of the billing surface. The free tier entitlement is server-enforced. The paid tier is real. The restore flow is real. The "Buy" buttons are real buttons that trigger real purchases. The release-guard flag (`BILLING_ENABLED=false`) prevents the surfaces from being mounted before the integration is real.
- **What is removed:** the current stub `purchaseQaPack` and `purchasePlan` methods. The current UI's hardcoded prices and "Buy" buttons (until the SDK is wired).
- **What is added:** the SDK integration, the server-enforced entitlement, the receipt verification, the restore flow, the real prices (set by the operator), the real "Buy" buttons.
- **What stays:** the entitlement model `mobile/lib/models/entitlement.dart` (extended, not replaced). The Q&A pack model `mobile/lib/models/qa_pack.dart` (extended, not replaced). The free-tier math.
- **Effort:** L. Same workstream as #4. 2-4 weeks total for billing + Q&A packs.
- **Source audits:** `docs/audits/coverwise_product_strategy_monetization_scope_compliance_marketing_audit_2026-07-18.md` P0-02, T-4-4, T-4-5 (emergency access must not be paywalled), T-4-6 (server-enforced entitlements).
- **Dependency:** the launch playbook's Step 8 (real-device end-to-end) is the validation gate. The release-guard flag prevents the surfaces from being mounted before the integration is real.

---

## Chosen path

**Per-feature decisions, in summary (revision 2 — see "Revisions" section for the full per-feature thinking):**

| # | Feature | Decision | Role in the wedge | Effort |
|---|---|---|---|---|
| 1 | Insurance Health Score | KEEP, REDESIGN as "Coverage Check-in" | Periodic surface for "is my coverage keeping up with my life?" | 2-3 wks |
| 2 | What-If Premium Calculator | KEEP, REDESIGN as "Coverage Adequacy" (no premium fabrication) | What-if surface for "am I covered for scenario X?" | 4-6 wks |
| 3 | Old claims assistant | KEEP OLD as "Claim Document Vault" + reroute `/claims` to new | The user's filing cabinet for claim paperwork | 2-3 wks |
| 4 | Billing stub / BillingAdapter | FINISH PROPERLY | Core (verified Q&A has a real cost) | 2-4 wks |
| 5 | Lead capture | KEEP framework, REMOVE lead form | Long-term opt-in for vetted partner offers | 1-2 wks |
| 6 | Family inventory | FINISH PROPERLY, FULL version with coverage-adequacy hook | Per-member coverage map; the user has a family floater | 4-6 wks |
| 7 | Claim tracker | FINISH PROPERLY, integrated with Claim Document Vault | Per-claim status view (shared data model with vault) | (part of #3) |
| 8 | Insurance cards | FINISH PROPERLY, SCOPED | Quick access to policy info, not proof | 1-2 wks |
| 9 | Literacy quiz | CUT | None (marketing site, not product) | 0.5 d |
| 10 | Q&A packs | FINISH PROPERLY (same as #4) | Core (billing surface for verified Q&A) | (part of #4) |

**Net delta (revision 2):** **0 cuts, 4 keep-redesign, 4 finish-properly, 2 unchanged.** The product is wider than revision 1 estimated. The work is larger. The launch is later. See "Revisions" for the per-feature thinking.

**The revised wedge (from "Revisions → B"):** "owned policy → evidence summary → verified Q&A → coverage check-in → coverage adequacy → family coverage map → claim document vault → renewal/contact utility." Each component is substrate-grounded, evidence-backed, and honestly scoped.

---

## Why this path

### 1st-principle argument

The 10 half-built features are not the same shape. Some are from a different product (#1, #2, #9). Some are marketing surfaces, not product surfaces (#5). Some are a previous attempt at the wedge (#3, where the new screen is the right version). Some are core to the wedge but not yet built honestly (#4, #10). Some are real wedge components that need to be scoped to the honest part (#6, #7, #8).

A "cut them all" or "finish them all" answer would treat the 10 as the same shape. They are not. The honest answer is per-feature, anchored to the wedge. The cuts remove features that should not exist. The finishes build features that the wedge requires. The scope-downs make real wedge components honest.

### Anti-parallel-paths argument (motto v3 §0.1)

The audit's T-1-13 is explicit: parallel paths (legacy extraction + substrate, legacy gap engine + new gap screen, old claims screen + new claim assistance, legacy summary + substrate fields) violate the "no parallel systems" rule and let unsafe paths regress. This ADR removes the old claims assistant (#3). The finish-properly items (#4, #6, #7, #8, #10) replace the stubs with real implementations. The release-guard flags prevent the stubs from being mounted before the real implementations land.

### Anti-stubs argument (motto v3 §6, "pre-existing is not an excuse")

The BillingAdapter is a self-declared skeleton. Per the trust audit, a stub that looks like a feature is worse than no feature. The first version of this ADR punted the stub to "defer pending D5." That was wrong. The right answer is: build the real billing surface, with a release-guard flag in the meantime. The stub stays in the codebase as a future integration point; the surface that uses it is hidden. When the real integration lands, the surface activates.

### Anti-short-term-triage argument (the operator's correction)

The first version of this ADR was anchored to "what can we do in 1-2 days?" The operator correctly called this out as "not long term 1st principles, not motto_v3 aligned." A short-term-triage answer produces a product that is honest in 1-2 days but cuts features the wedge needs. The right answer is anchored to the long-term product shape. Some features are expensive to build honestly; they are still built honestly, because the wedge requires them.

### Honest-scope argument (motto v3 §0.4 acceptance contract)

The acceptance contract for "ship a feature" is "the user who uses this feature is not deceived." The Insurance Health Score, the What-If Calculator, the Lead Capture dialog, and the Literacy Quiz all fail the acceptance contract in their current form. The cuts remove them. The finish-properly items pass the acceptance contract after the build. The scope-down items pass the acceptance contract after the relabel + scope change.

### Operator-decision-required argument

This ADR is **proposed, not accepted**. The 4 CUTs, 3 FINISH PROPERLY, 1 FINISH PROPERLY (same as #4), and 1 routing change are recommendations grounded in the long-term product shape, the audits, and the code. The operator may disagree on any row. The reason this is an ADR and not a code change is that the cut/keep/finish call is a product call, not an engineering call. The engineering call is downstream of the product call.

---

## Tradeoffs

- **The cuts lose features that had visible user engagement.** The Insurance Health Score and the What-If Calculator were the most-clicked surfaces on the dashboard and the More screen. Cutting them will show up in analytics as a usage drop. The honest framing is: the prior engagement was on a lying UI, and the audit explicitly flags the lying UI as a worse outcome than no UI.
- **The finish-properly items take 4-8 weeks.** The launch slips. The operator's call. If the launch cannot wait, the cuts can be accelerated, but the wedge does not launch without the billing surface (#4, #10).
- **The scope-down items lose capabilities.** Family manual additions, claim-tracker-as-insurer-connection, insurance-cards-as-proof. These capabilities are not in the long-term product. The audit is right that they are not honest; the cuts to those capabilities are the cost of honesty.
- **The release-guard flag is a temporary state.** Until the real billing integration lands, the Q&A pack UI and the settings Upgrade/Manage are hidden. The free tier is the only honest state. This is acceptable; the launch is delayed, not blocked.
- **The cuts and the finishes are sequenced.** The cuts land first (2.5 days). The finish-properly items land in 4-8 weeks. The launch happens after the finish-properly items and the launch playbook's Step 8.

---

## Assumptions

- **The long-term product shape is the wedge.** The operator has not disagreed with the wedge. This ADR does not re-litigate the wedge decision; that is the strategy audit's call.
- **The 7 substrate fields are enough for the keep-with-scope items.** Specifically: the new claim assistance screen uses `insurer_name` + a per-insurer URL lookup table. The auto-detected family members come from `policyHolders` (a substrate field). The insurance cards and claim tracker are not substrate-grounded but they are also not substrate-claimed (the relabel makes that clear).
- **A real billing SDK (RevenueCat or equivalent) is acceptable.** The strategy audit does not name a specific SDK; this ADR recommends RevenueCat as the default but defers the final pick to the implementation.
- **Server-enforced entitlements are achievable in the current architecture.** The audit's T-4-6 names this as a requirement. The substrate's `evidence_principal_quotas` table (or a new `user_entitlements` table) is the server-side source of truth.
- **The operator can fund or build the 4-8 weeks of finish-properly work.** This is a product call, not an engineering call. The cuts are a 2.5 day task; the finishes are a quarter of work.
- **The launch playbook's Step 8 (real-device end-to-end) is the validation gate.** The finish-properly items are validated by Step 8 before the launch.

---

## Risks

- **The operator disagrees with a row.** This is a feature of the decisions-first process, not a bug. The risk is that the ADR is accepted and then a row is reversed later. The mitigation is to make the ADR's row-by-row decisions explicit and easy to revisit.
- **The finish-properly items are not picked up.** 4-8 weeks of work is a lot. The mitigation is the release-guard flag: the surfaces stay hidden regardless. The risk is that the operator is not reminded to do the work.
- **A real billing SDK is not chosen and integrated in 2-4 weeks.** The mitigation is the release-guard flag: the surfaces stay hidden. The wedge does not launch without the billing surface.
- **The cuts and the finishes are sequenced but not parallel.** The mitigation is the 2.5 day cuts sprint; the finishes can start in parallel with the cuts, but the launch waits for the finishes.
- **The family scope-down loses a real use case.** Some users will want a global family list. The mitigation is the per-document surface: the data is still there, it is just scoped to the document. If the long-term product grows to include a global family model, that is a separate ADR.
- **The claim tracker relabel loses a familiar name.** "Claim tracker" is a known term. "My claim notes" is unfamiliar. The mitigation is the explicit banner explaining the rename. The audit acknowledges the tradeoff; the operator is the final judge.

---

## Validation plan

- **For each CUT:** a release-guard test that asserts the removed surface is not reachable from any code path. The test searches for the removed route name, the removed class, and the removed widget in the bundled Dart code. The test lands in the same commit as the cut.
- **For each FINISH PROPERLY, SCOPED (#6, #7, #8):** a test that asserts the new surface is reachable, the banner is present, and the relabel is in the user-facing copy.
- **For the FINISH PROPERLY (#4, #10):** a test that asserts the release-guard flag is read at the gate, the gate is closed in production builds, and the SDK integration is wired (when the integration lands).
- **For the old claims assistant cut (#3):** a test that asserts `/claims` routes to the new screen and that the old screen class is not referenced.
- **End-to-end:** the launch playbook's Step 8 (real-device end-to-end) runs after the finish-properly items land. The validation includes: owned policy → evidence summary → verified Q&A → renewal/contact utility, with the real billing surface active.

---

## Rollback or migration path

Each row is an independent commit (or commit series for the finish-properly items). Reverting a cut is a 1-commit revert. Reverting a finish-properly item is more involved — it means reverting to the release-guard flag and re-hiding the surface. The cut/finish commits are sequenced so that a revert of a finish does not break a cut that landed earlier.

---

## What would cause this decision to be revisited

- **The operator wants a different wedge.** If the verified Q&A wedge is not the right product to validate, the keep/cut list shifts. The insurance cards, claim tracker, and family inventory are not wedge-related; they can be revisited independently.
- **A real actuarial source is licensed.** The Insurance Health Score and What-If Calculator can be re-evaluated. The audit's NO-GO is about the lying UI; a real actuarial source would make the UI honest.
- **A real billing SDK is not chosen in 2-4 weeks.** The release-guard flag stays. The wedge does not launch without the billing surface. The operator may decide to launch with the free tier only and the billing surface as a follow-up; that is a different ADR.
- **The market changes.** A competitor ships a "Insurance Health Score" feature. The operator may decide to ship a less-honest version to compete. This ADR's revisit trigger would note the change but the original 1st-principle argument stands.
- **The substrate grows to include new fields** (e.g. the strategy audit's T-7-7 "evidence-aware field model + full-document extraction"). The family inventory and claim tracker may grow to use the new fields. The scope-down calls may be revisited.

---

## Doc update (companion to this ADR)

This ADR requires updates to:

- `docs/architecture/coverwise_canonical_architecture.md` §3 (Product surface) gets a "Cut/Keep/Finish" table that mirrors this ADR's per-feature decisions. The doc is the operator-facing map; the table makes the cut/keep/finish state visible at the architecture layer.
- The doc's §4 (Trust tiers) is unchanged; the cuts/keeps do not change the trust contract.
- The doc's §5 (Outbox + durable work) is unchanged; the cuts/keeps do not change the work contract.
- `docs/audits/coverwise_current_state_progress_and_next_moves_review_2026-07-19.md §5` (the cut/keep/finish list) is updated to mirror this ADR.
- `docs/CONTENT_AUDIT_2026-07-19.md` is updated with the new copy (e.g. "Quick access" instead of "Insurance cards," "My claim notes" instead of "Claim tracker," the new banners).

The doc update is a separate commit from any code change. The canonical doc + this ADR + the launch playbook are the three places the cut/keep/finish state is recorded.

---

## Revisions (after operator feedback, 2026-07-19)

The operator's per-feature thinking (recorded as a quote, lightly paraphrased) widened the product from a narrow wedge to a broader wedge. The per-feature calls in §"Per-feature decisions" are revised as follows. The original reasoning stays visible above; the revisions are recorded here for traceability.

### 1. Insurance Health Score — **REVISED: KEEP, REDESIGN AS "Coverage Check-in."**

- **Original call:** CUT. Reason: "Excellent/At Risk" is a suitability rating from a different product.
- **Operator's thinking:** "people have an insurance but under the coverage do they know how their health fares etc? maybe to build a regular checkin tool etc."
- **Revised call:** **KEEP, but redesign as a "Coverage Check-in" tool** — a regular, periodic surface that helps the user reflect on whether their coverage is keeping up with their life (not a suitability score from an actuary). The user can come back quarterly and answer a few questions about their life (new baby, new job, new house, new diagnosis, age change) and see how their coverage compares. The "score" is replaced with a "coverage situation" (a set of grounded observations: "your sum insured has not changed in 3 years, but medical inflation has been ~14% per year; your real coverage is lower than when you bought it"). The observations are substrate-grounded (they cite the policy, the inflation source, the date). The user can opt out of any observation. The check-in is a relationship surface, not a one-time score.
- **Why the revision:** the operator's point is that the user *has* a policy, the user *does not know* whether the policy is keeping up with their life, and the product's job is to help the user notice. This is not an actuarial product; it is a coverage-reflection product. The redesign turns the lying score into an honest relationship tool.
- **What changes:** the "Insurance Health Score" widget is removed. A new "Coverage Check-in" surface is added: a list of grounded observations, each with a substrate citation, a date, and a "dismiss" button. The check-in is surfaced as a quarterly reminder (or on-demand). The underlying math (e.g. medical inflation lookup) is a small table, not an LLM guess.
- **What stays:** the auto-detected family members (per #6 below) feed into the check-in ("your family has grown; your family floater may need review").
- **Effort:** M. 2-3 weeks. The check-in surface + the observation library + the quarterly reminder.
- **Source:** operator's feedback (2026-07-19). Implicitly related to the trust audit's T-3-5 (verified offline emergency snapshot with freshness) — the check-in is the long-term companion to the emergency surface.

### 2. What-If Premium Calculator — **REVISED: KEEP, REDESIGN AS "Coverage Adequacy" tool.**

- **Original call:** CUT. Reason: hardcoded multipliers are not from an underwriter.
- **Operator's thinking:** "what if scenarios that the user wants to know if he has enough coverage or not etc." Separately, on the What-If Premium specifically: "what if premium - we need to explore."
- **Revised call:** **KEEP, but redesign as a "Coverage Adequacy" tool** — a what-if surface that helps the user explore whether their coverage is enough for the scenarios they actually care about. The scenarios are user-defined, not insurer-defined ("if I have a C-section, am I covered? if my parent needs a knee replacement, am I covered?"). The substrate answers based on the user's actual policy. The "premium" framing is removed; the "adequacy" framing is added.
- **Important distinction from the original What-If:** the original What-If fabricated premium numbers (hardcoded multipliers). The new Coverage Adequacy tool does NOT fabricate numbers — it grounds every answer in the substrate. "Am I covered for a C-section?" is answered as "yes" / "no" / "not in the substrate" / "your policy excludes this; here is the exclusion clause." The "what would it cost" framing is removed entirely. The user is told what the policy says, not what the premium would be.
- **Why the revision:** the operator's point is that the user wants to know if they have enough coverage. The product's job is to answer that question with the substrate, not to fabricate premium numbers. The "what if premium" framing is a separate exploration (the operator said "we need to explore" — that's a future ADR, not this one).
- **What changes:** the "What-If Premium Calculator" screen is removed. A new "Coverage Adequacy" surface is added: the user picks a scenario from a list (C-section, knee replacement, day-care procedures, ICU, etc.) and the substrate answers. The "what would it cost" question is removed.
- **What stays:** nothing from the original What-If (the hardcoded multipliers are not reusable). The substrate-grounded Q&A pattern (per ADR-2026-07-19-04) is the foundation.
- **Effort:** L. 4-6 weeks. The scenario library (20-30 common scenarios) + the substrate-grounded answers + the "not in substrate" honest-empty state. The scenario library is a one-time build; the substrate answers are the existing Q&A pipeline.
- **Future ADR:** "What-If Premium" (the original calculator's framing) is deferred to a future ADR. The operator said "we need to explore" — that's a separate decision, not a cut/keep/finish call.
- **Source:** operator's feedback (2026-07-19).

### 3. Old claims assistant (`claims_assistant_screen.dart`) — **REVISED: KEEP OLD AS "Claim Document Vault," reroute `/claims` to the new claim-assistance flow for new claims.**

- **Original call:** CUT + reroute `/claims` to the new `claim_assistance_screen.dart`. Reason: the new screen is the substrate-backed version; the old one is generic copy.
- **Operator's thinking:** "old claims - not yet sure because i don't want the user to think we help with claims but we can help them track their old claims docs they submitted, the discharge, approvals etc."
- **Revised call:** **KEEP the old surface, but repurpose it as the "Claim Document Vault"** — a place for the user to store and track the documents they receive during a claim: discharge summaries, approval letters, settlement statements, denial letters, follow-up emails, photos of receipts. The vault is per-claim, attached to a policy, and local-first. The user can add a document by photographing it, by uploading a PDF, or by linking to a record in the new claim-assistance flow.
- **What the old screen is NOT:** the old screen is not a "claim assistant" (the operator was clear: the user must not think we help with claims). The old screen is not a "claim tracker" (that's #7). The old screen is a **document vault for claim-related paperwork**.
- **What the new `claim_assistance_screen.dart` does:** the new screen continues to do what it does — show the insurer's process page, the claim helpline, the IRDAI escalation card, the legal disclaimer. The new screen is for *filing* a claim (or preparing to file one). The user gets to the insurer's process page; the user reads the legal disclaimer; the user files the claim with the insurer (not with us).
- **What the new "Claim Document Vault" does:** the user comes back after filing and stores the documents. "Here's my discharge summary. Here's the approval letter. Here's the settlement. Here's the denial." The vault is the user's record of what happened. The user can search, tag, and export.
- **Routing:** `/claims` continues to point to the new claim-assistance screen (for filing). The vault is a new route, e.g. `/claim-vault` or `/documents/claim`. The old screen's "4 incident types" generic copy is replaced with the vault UI.
- **Why the revision:** the operator's point is that the user has claim paperwork, the user has no good place to keep it, and the product's job is to give the user a place. The vault is not a "claim assistant" (the user is the assistant); the vault is a filing cabinet.
- **What changes:** the old `claims_assistant_screen.dart` is rewritten as the Claim Document Vault. The 4 incident types are removed. The new screen is a document list with upload, tag, search, export.
- **What stays:** the new `claim_assistance_screen.dart` (the substrate-backed, IRDAI-escalation-carded, legal-disclaimer-carded version) is unchanged. The user's "open the claim" flow goes to the new screen; the user's "store the paperwork" flow goes to the vault.
- **Effort:** M. 2-3 weeks. The vault UI + the document model + the per-claim grouping + the search/tag/export.
- **Source:** operator's feedback (2026-07-19).

### 4. Billing stub / BillingAdapter — **UNCHANGED.** FINISH PROPERLY.

- **Operator did not push back on this call.** The billing surface is core to verified Q&A (per the wedge). The finish is unchanged: RevenueCat + server-enforced entitlement + webhook + restore.
- **Net:** same as revision 1.

### 5. Lead capture — **REVISED: KEEP, REPURPOSE AS "Value-Add Surfaces" framework with future partnership hook.**

- **Original call:** CUT. Reason: lead capture contradicts the non-regulated boundary.
- **Operator's thinking:** "lead capture - this i'm ok to let go but we haven't thought of long term partnerships, we are letting users upload all kinds of policy docs, then why not later have partnerships to get ads or upsell policies etc?"
- **Revised call:** **KEEP the surface as a framework, but do not deploy lead capture now.** The framework is the value-add surface: a place where the user can opt into "I want to hear about offers from partners who have been vetted by CoverWise." The framework is empty by default; the partnership integrations are a future workstream. The lead-capture form (email, phone, interest) is removed. The opt-in is a single toggle: "I'm interested in offers from CoverWise's partners." The user can opt in or out at any time. The opt-in is recorded in the consent ledger (per ADR-2026-07-19-07) with purpose `partnership_offers`.
- **Why the revision:** the operator's point is that long-term, the product has a partnership story. Insurance customers are a high-value audience for insurers and for adjacent services (financial planning, tax filing, will preparation). The product's job is to be a responsible intermediary: the user opts in, the product vets the partner, the user can opt out. The lead-capture form is removed because the operator does not want to capture leads now; the framework is built because the operator wants the future.
- **What "vet the partner" means:** the product publishes a partner-vetting policy. The policy names the criteria (regulatory standing, data handling, no resale, no unsolicited contact, opt-out honored, etc.). The policy is a public document. Partners who meet the criteria are listed on a "Partners" page. The user opts in per partner category, not per partner. The product does not share the user's documents with partners; the product shares the user's opt-in signal with partners (via a server-enrolled webhook). The user can audit the opt-in history.
- **What changes:** the `LeadCaptureDialog` and `RateLimitDialog` are removed. A new "Value-Add Surfaces" framework is added: a settings page with a "Partnership offers" opt-in, a public Partners page (a marketing site page, not an in-app page), a partner-vetting policy document, and a webhook for partner enrollment. The "interest_level" and "preferred_contact" form fields are removed.
- **What stays:** the consent ledger's `ConsentPurpose.partnership_offers` is added. The `contact_service` is retained as the storage primitive for the user's account contact (used by IRDAI escalation and claim contact).
- **Future ADR:** the partner-vetting policy, the Partners page, and the partner enrollment webhook are a future workstream. This ADR builds the framework; the partnerships are a separate decision.
- **Effort:** S-M. 1-2 weeks for the framework + the opt-in toggle + the consent purpose. The partner onboarding is a future workstream.
- **Source:** operator's feedback (2026-07-19). Implicitly related to the strategy audit's T-4-8 (insurer-contact convenience and lead/referral data model separation; maintained subprocessor / model-provider disclosure artefact) — the framework is the disclosure artefact.

### 6. Family inventory — **REVISED: KEEP, BUILD FULL VERSION WITH COVERAGE-ADEQUACY HOOK.**

- **Original call (revision 1):** FINISH PROPERLY, SCOPED. Per-document holders only; standalone Family tab and manual add cut.
- **Operator's thinking:** "family inventory - why not track - i get my personal policy, have a family floater, i should know how each member is covered what they may need extra etc, my dependents can't have their own policies."
- **Revised call:** **KEEP, build the full version with a coverage-adequacy hook.** The user's per-document family members are extracted from the substrate. The user can also manually add family members who are NOT on any policy (the "what they may need extra" case). The Family surface shows: each member, the policies that cover them, the sum insured that applies to them, the room rent cap that applies to them, and a grounded observation ("your mother is 67 and on your family floater; the sum insured for elders is often lower; consider a separate senior-citizen policy"). The observation is substrate-grounded (it cites the policy and the source) and the user can dismiss it.
- **Why the revision:** the operator's point is that the user has a family, the user has a family floater, the user does not know how each member is covered, and the user has dependents who cannot have their own policies (minors, elderly, disabled). The product's job is to show the user the coverage situation per family member and to surface honest observations about gaps. The "dependents can't have their own policies" insight is the load-bearing one: the Family surface is not a directory; it is a coverage map.
- **What changes:** the "scope down" from revision 1 is reversed. The standalone Family tab stays (or returns). The manual-add dialog stays. The FamilyMember model gains a `relationship` field and a `coverage_role` field (primary_holder, spouse, child, parent, dependent). The coverage-adequacy hook integrates with the revised Health Score (#1) and the revised What-If (#2).
- **What stays:** the auto-detected members from the substrate. The backend `src/api/family.py:1-11` stays "intentionally not mounted" (the family is substrate-grounded; the manual additions are local to the device until a future identity-model ADR).
- **What "manually added family members" means for security:** the audit's P-family finding is that manual additions in a global Hive box leak across accounts. The fix (per the security audit) is principal-scoped storage. The principal encryption (per ADR-2026-07-19-06) is the foundation; the manual additions live in the principal-scoped box. The Hive scoping (per the current-state review's P0-08) is a prerequisite for the manual-add feature.
- **Effort:** L. 4-6 weeks. The Family surface + the per-member coverage map + the coverage-adequacy observations + the principal-scoped manual add + the integration with Health Score and What-If.
- **Source:** operator's feedback (2026-07-19). Implicitly related to the trust audit's T-3-11 (user correction flow for extracted facts) — the manual-add is a correction flow for the family.

### 7. Claim tracker — **REVISED: KEEP, INTEGRATE WITH THE NEW CLAIM DOCUMENT VAULT (#3 ABOVE).**

- **Original call (revision 1):** FINISH PROPERLY, SCOPED. Rename to "My claim notes," add a banner "not connected to any insurer."
- **Operator's thinking:** "claim tracker - same as my thinking of old [the Claim Document Vault]."
- **Revised call:** **KEEP, integrate with the new Claim Document Vault (#3 above).** The Claim Document Vault is the primary surface; the Claim Tracker is a per-claim status view that shows the user's claim documents in chronological order with a status (filed, in review, approved, denied, settled, withdrawn). The status is a tag the user sets; the system does not connect to the insurer. The vault and the tracker share the same data model: a `ClaimRecord` with a list of `ClaimDocument`s and a `status`.
- **Why the revision:** the operator's point is that the user files a claim, the user has paperwork, the user has a status. The vault is the documents; the tracker is the status. They are two views of the same data.
- **What changes:** the claim tracker is not a separate screen; it is a view inside the Claim Document Vault. The "rename to My claim notes" is replaced with "show me the claims" inside the vault. The per-record document pointer, the per-record insurer contact, the local-only persistence (per revision 1) all stay.
- **What stays:** the local CRUD model `mobile/lib/models/claim_record.dart`. The vault's per-claim grouping. The local-only persistence (no insurer API).
- **Effort:** rolled into #3 above. The vault and the tracker are the same workstream.
- **Source:** operator's feedback (2026-07-19).

### 8. Insurance cards — **UNCHANGED.** FINISH PROPERLY, SCOPED.

- **Operator did not push back on this call.** The "Quick access" relabel and the "not a verifiable document" banner are the right shape. The offline-first reading and the wearable-friendly surface are the right scope.
- **Net:** same as revision 1.

### 9. Literacy quiz — **UNCHANGED.** CUT.

- **Operator did not push back on this call.** The "Move to public content later" framing is the right call. The quiz is generic and the substrate does not yet extract the relevant fields. The marketing site is the right home.
- **Net:** same as revision 1.

### 10. Q&A packs — **UNCHANGED.** FINISH PROPERLY (same workstream as #4).

- **Operator did not push back on this call.** The billing surface for verified Q&A is core to the wedge. The finish is unchanged.
- **Net:** same as revision 1.

### "Anything else?" (operator's question, 2026-07-19)

The operator asked "anything else?" after the per-feature thinking. Two things are worth flagging:

#### A. The "What-If Premium" question is a future ADR, not a feature call.

- **What the operator said:** "what if from point 2 [Coverage Adequacy] is diff. than the what if i mentioned earlier, what if premium - we need to explore."
- **The distinction:** the Coverage Adequacy tool (#2 above) is "am I covered for scenario X?" — answered from the substrate, no premium fabrication. The What-If Premium question is "if I change my sum insured by Y, what would my premium be?" — a question only an insurer or an underwriter can answer honestly. The product's job is to *not* answer the second question (because we are not an underwriter) and to *help the user ask* the second question (deep-link to the insurer's premium calculator or to a partner quote tool, with a clear "this is the insurer's number, not ours" label).
- **Future ADR:** the "What-If Premium" surface is a separate ADR. The ADR scopes: do we deep-link to the insurer, do we partner with a quote aggregator, do we refuse to show anything and just say "ask your insurer"? The ADR's options are:
  1. Deep-link to the insurer's premium calculator (honest, limited).
  2. Partner with a quote aggregator (honest if the aggregator is vetted; the value-add partnerships framework from #5 above is the precedent).
  3. Refuse and say "ask your insurer" (most honest, least useful).
  4. Explore. (The operator's word. The ADR is the exploration.)
- **This revision's call:** defer the What-If Premium question to a future ADR. Do not include it in the current build.

#### B. The product is wider than the wedge I wrote. The wedge needs to be updated.

- **What changed:** the original wedge was "owned policy → evidence summary → verified Q&A → renewal/contact utility." The operator's per-feature thinking widened the wedge to include:
  - **Coverage Check-in** (#1 above): a periodic surface that helps the user notice when their coverage is keeping up with their life.
  - **Coverage Adequacy** (#2 above): a what-if surface that helps the user explore whether their coverage is enough for the scenarios they care about.
  - **Claim Document Vault** (#3 above): a place for the user to store and track the paperwork from a claim.
  - **Family Coverage Map** (#6 above): a surface that shows the user how each family member is covered and surfaces honest observations about gaps.
  - **Value-Add Partnerships framework** (#5 above): a future opt-in surface for vetted partner offers.
- **The revised wedge:** "owned policy → evidence summary → verified Q&A → coverage check-in → coverage adequacy → family coverage map → claim document vault → renewal/contact utility." The wedge is broader but still narrow. Each component is substrate-grounded, evidence-backed, and honestly scoped.
- **Implication for ADR-09 (evidence-backed):** the four-face contract (substrate ∧ citation ∧ answer ∧ UI) still applies. The new surfaces (check-in, adequacy, family map, vault) use the same contract. No change to ADR-09.
- **Implication for ADR-10 (outbox-only):** the new surfaces generate more durable work (claim document uploads, family member additions, check-in observations). The outbox-only answer still applies. The release guard catches the new durable work. No change to ADR-10.
- **Implication for ADR-11 (substrate as primary deliverable):** the new surfaces all surface substrate-grounded content (coverage observations, adequacy answers, family coverage, claim documents). The "open page" action is even more important now. No change to ADR-11, but the work to add the new surfaces extends the page artifact coverage.
- **Implication for ADR-12 (operator trust model):** the new surfaces add more privileged actions (read another user's claim documents with reason, read a family member's coverage with reason). The 6 roles still apply; the RBAC table grows. No change to ADR-12, but the RBAC table is extended.

### Net delta (revision 2)

| # | Feature | Revision 1 | Revision 2 | Why |
|---|---|---|---|---|
| 1 | Insurance Health Score | CUT | KEEP, REDESIGN as "Coverage Check-in" | User has a policy; user doesn't know if it's keeping up. Honest relationship tool. |
| 2 | What-If Premium Calculator | CUT | KEEP, REDESIGN as "Coverage Adequacy" (no premium fabrication) | User wants to know if covered. Substrate answers. |
| 3 | Old claims assistant | CUT + reroute | KEEP OLD as "Claim Document Vault" + reroute `/claims` to new | User has claim paperwork; user needs a place. Vault ≠ assistant. |
| 4 | Billing stub | FINISH PROPERLY | FINISH PROPERLY | Operator did not push back. |
| 5 | Lead capture | CUT | KEEP framework, REMOVE lead form | Long-term partnership story. User opts in. Future ADR. |
| 6 | Family inventory | FINISH PROPERLY, SCOPED | FINISH PROPERLY, FULL version | User has a family, a floater, and dependents. Coverage map. |
| 7 | Claim tracker | FINISH PROPERLY, SCOPED | FINISH PROPERLY, integrated with vault | Same data model as the vault. |
| 8 | Insurance cards | FINISH PROPERLY, SCOPED | FINISH PROPERLY, SCOPED | Operator did not push back. |
| 9 | Literacy quiz | CUT | CUT | Operator did not push back. |
| 10 | Q&A packs | FINISH PROPERLY (same as #4) | FINISH PROPERLY (same as #4) | Operator did not push back. |

**Net result:** **0 cuts, 4 keep-redesign, 4 finish-properly, 2 unchanged.** The product is wider; the work is larger; the launch is later.

**Effort rollup (revision 2):**
- Coverage Check-in (#1): 2-3 weeks
- Coverage Adequacy (#2): 4-6 weeks
- Claim Document Vault + Claim Tracker (#3 + #7): 2-3 weeks (same workstream)
- Billing + Q&A packs (#4 + #10): 2-4 weeks (same workstream)
- Value-Add Partnerships framework (#5): 1-2 weeks
- Family Coverage Map (#6): 4-6 weeks
- Insurance Cards (#8): 1-2 weeks
- Outbox migration (ADR-10): 1-2 weeks
- Substrate visibility (ADR-11): 1-2 weeks
- Operator trust model (ADR-12): 2-3 weeks
- Evidence-backed four faces (ADR-09): 1-2 weeks

**Total: ~20-30 weeks of product work.** The launch is significantly later than revision 1 estimated. The operator's call.

**Sequence (revision 2):** same as revision 1: cuts (now zero) first, then finish-properly in dependency order. The new order is:
1. Substrate visibility (ADR-11) — the foundation.
2. Evidence-backed four faces (ADR-09) — the contract.
3. Outbox migration (ADR-10) — the durable work.
4. Operator trust model (ADR-12) — the operator side.
5. Value-Add Partnerships framework (ADR-08 #5) — the framework.
6. Insurance Cards (ADR-08 #8) — small, unblocks the home screen.
7. Claim Document Vault + Claim Tracker (ADR-08 #3 + #7) — the claim workflow.
8. Family Coverage Map (ADR-08 #6) — depends on the substrate's per-document holders.
9. Coverage Adequacy (ADR-08 #2) — depends on the substrate's scenario library.
10. Coverage Check-in (ADR-08 #1) — depends on the substrate's life-event signals.
11. Billing + Q&A packs (ADR-08 #4 + #10) — the wedge's billing surface.

The launch happens after the launch playbook's Step 8 (real-device end-to-end) validates the full wedge.

- **Affected files (this ADR, after operator sign-off):**
  - `mobile/lib/providers/health_score_provider.dart` (cut)
  - `mobile/lib/widgets/health_score_card.dart` (cut)
  - `mobile/lib/screens/dashboard_screen.dart` (modify mount)
  - `mobile/lib/utils/what_if_calculator.dart` (cut)
  - `mobile/lib/screens/what_if_calculator_screen.dart` (cut)
  - `mobile/lib/screens/claims_assistant_screen.dart` (cut, reroute `/claims`)
  - `mobile/lib/main.dart` (modify routes)
  - `mobile/lib/services/billing_adapter.dart` (finish properly: SDK + server entitlement)
  - `mobile/lib/screens/qa_packs_screen.dart` (finish properly: real Buy, real entitlement, real restore)
  - `mobile/lib/screens/qa_screen.dart` (gate paywall with real entitlement)
  - `mobile/lib/screens/settings_screen.dart` (gate Upgrade/Manage with real entitlement)
  - `mobile/lib/widgets/lead_capture_dialog.dart` (cut)
  - `mobile/lib/services/contact_service.dart` (retain as account contact)
  - `mobile/lib/services/consent_ledger.dart` (remove `ConsentPurpose.leadCapture`)
  - `mobile/lib/screens/family_screen.dart` (cut, scope down to per-document on policy detail)
  - `mobile/lib/screens/add_family_member_dialog.dart` (cut)
  - `mobile/lib/screens/claim_tracking_screen.dart` (rename to "My claim notes" + banner + per-record document pointer)
  - `mobile/lib/screens/insurance_card_screen.dart` (rename to "Quick access" + banner + offline-first)
  - `mobile/lib/screens/insurance_literacy_screen.dart` (cut)
  - `mobile/lib/services/app_state_repository.dart` (remove `manualFamilyMembersKey`)
  - `src/api/document.py:611-658` (remove `POST /capture-lead`)
  - `src/utils/document_store.py:47-55` (drop `leads` table from schema)
  - `src/api/billing/` (new: webhook handler, entitlement service, receipt verification)
  - `supabase/migrations/` (new: `user_entitlements` table, billing-related tables)
  - `docs/architecture/coverwise_canonical_architecture.md` (add cut/keep/finish table)
  - `docs/decisions/README.md` (add this ADR to the index)
  - `docs/CONTENT_AUDIT_2026-07-19.md` (add the cuts and relabels to the audit)
  - `docs/audits/coverwise_current_state_progress_and_next_moves_review_2026-07-19.md §5` (update per-feature call)
  - `mobile/test/` (release-guard tests per row)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-04](./ADR-2026-07-19-04-coverage-gap-claim-assistance-thin-slice.md) (precedent for ship-then-defer)
  - [ADR-2026-07-19-06](./ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md) (principal encryption; the precondition for keeping local-state features)
  - [Canonical architecture doc](../../architecture/coverwise_canonical_architecture.md) (target of the doc-update companion)
  - `docs/audits/coverwise_product_mobile_experience_accessibility_audit_2026-07-18.md` (source audit, P0-01 through P0-14)
  - `docs/audits/coverwise_product_strategy_monetization_scope_compliance_marketing_audit_2026-07-18.md` (source audit, P0-01 through P0-12)
  - `docs/audits/coverwise_current_state_progress_and_next_moves_review_2026-07-19.md §5` (the cut/keep/finish list)
  - `docs/audits/coverwise_operations_reliability_observability_performance_cost_audit_2026-07-18.md` (P0-13 cost persistence; the cost that makes #4/#10 real)
- **Related code (current state):**
  - `mobile/lib/providers/health_score_provider.dart`
  - `mobile/lib/utils/what_if_calculator.dart`
  - `mobile/lib/screens/claims_assistant_screen.dart`
  - `mobile/lib/services/billing_adapter.dart`
  - `mobile/lib/widgets/lead_capture_dialog.dart`
  - `mobile/lib/screens/family_screen.dart`
  - `mobile/lib/screens/claim_tracking_screen.dart`
  - `mobile/lib/screens/insurance_card_screen.dart`
  - `mobile/lib/screens/insurance_literacy_screen.dart`
  - `mobile/lib/screens/qa_packs_screen.dart`
  - `mobile/lib/screens/dashboard_screen.dart`
  - `src/api/document.py:611-658`
- **Motto v3 alignment:** §0.1 (no parallel paths; the old claims assistant cut is the canonical example), §0.4 (acceptance contract; a feature that cannot pass the "user is not deceived" test is not shipped, and a feature that is core to the wedge is built honestly even if it takes weeks), §0.7 (AI output boundary; the LLM-derived Insurance Health Score and What-If numbers are exactly the kind of output that needs a source), §0.11 (customer-facing claims; the relabel + scope-down are the customer-facing application of this ADR), §0.12 (this document), §0.13 (scope control; the cuts are a deliberate narrowing to the wedge, not a reactive triage).

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | **Widened-wedge clarification per [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md).** The widened-wedge items classified here as keep/finish (Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault, partnerships framework) remain a valid **exploration inventory**, but product inclusion now requires passing the five-gate stack (Gates A–E) in the [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md). Inclusion in this ADR's keep/finish list does not by itself authorize a surface for launch. The original cut/keep/finish reasoning is preserved. | Operator direction: layered doctrine stack; ADR-2026-07-29-02 reconciliation. |


---

## Doctrine reconciliation note (2026-07-29)

> Append-only note added 2026-07-29. This section does not modify any prior
> content in this ADR; the original decision, reasoning, and existing update
> logs above remain intact and authoritative for their date.

- **Date:** 2026-07-29
- **Governing ADR:** [ADR-2026-07-29-02 (doctrine stack reconciliation)](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
- **What changed:** [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) establishes a layered doctrine stack. The [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) (`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`) now sits above feature ADRs, with a five-gate stack (Gates A-E: Outcome, Truth, Product role, Lifecycle, Strategy/commercial). Widened-wedge clarification: the keep/finish items here remain a valid exploration inventory, but product inclusion now requires passing the five-gate stack (Gates A-E) in the Product Constitution. Inclusion in this ADR's list does not by itself authorize a surface for launch.
- **Why:** Operator direction to unify two competing uncommitted first-principles documents into one layered stack before any boundary-shaped code changes.
- **What triggered it:** Discovery that the repository held conflicting uncommitted doctrine (Principles vs Wedge) and that ADR-2026-07-29-01 self-declared "Accepted" without sign-off evidence.
- **What original reasoning remains valid:** All prior reasoning in this ADR is preserved unchanged. This note only constrains surface semantics where they intersect the constitution's gates.
- **Status change for this ADR:** None (this ADR's own status is unchanged by this note).
- **Operator sign-off:** None required for this note; it records the reconciliation linkage. The reconciliation ADR itself remains Proposed pending operator sign-off.
- **Code authorization:** None. No code, route, entitlement, pricing, comparison, claims, renewal, camera, demo, or onboarding change is authorized by this note.
