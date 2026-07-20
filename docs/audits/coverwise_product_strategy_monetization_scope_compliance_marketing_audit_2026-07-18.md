# CoverWise Product Strategy, Monetization, Scope Boundary, Compliance Readiness, and Marketing Audit

**Date:** 2026-07-18  
**Repository:** `pranaysuyash/insurance_q`  
**Branch:** `main`  
**Commit:** `e3440a5da174c0cbbe279878bdff21950d8cab63`  
**Evidence tier:** Tier 1 repository and product inspection  
**Important limitation:** product-risk and compliance-readiness analysis, not legal, tax, insurance, medical, or app-store counsel  
**Scope:** product wedge, customer, value proposition, feature portfolio, permanent non-regulated boundary, monetization, billing, unit economics, lead capture, pricing, public claims, support, complaints, incident handling, and launch sequencing

---

## Executive Summary

The repository contains a strong strategic decision: CoverWise should remain a solo-operated, non-regulated software product that helps users understand policies they already own. It should not recommend, sell, rank, procure, renew, or act on insurance.

The current implementation violates that decision in several places:

- coverage gaps recommend buying policies and riders;
- expired policies prompt immediate renewal or purchase;
- the What-If Calculator simulates premiums and underwriting changes;
- the Health Score judges household insurance condition;
- the claim guide gives procedural deadlines and requirements;
- “Start renewal” moves from reminder to action guidance;
- lead-capture endpoints and phone prompts create a sales/account narrative without a coherent purpose;
- Q&A packs and plan prices look live while billing is a local success stub;
- Free/Plus/Family packaging is inconsistently enforced and not linked to willingness-to-pay evidence;
- public marketing promises capability and reliability the production path cannot prove.

The app is also overbuilt relative to its validated wedge. More than thirty screens compete for attention before the core policy-summary and evidence-Q&A flow is trustworthy.

**Strategic verdict: do not launch or monetise the broad current surface.**

The best near-term product is:

> A private policy workspace that turns an owned policy into a source-linked summary, answers document-grounded questions, and keeps verified expiry and insurer-contact details ready.

The differentiation is neutrality and evidence, not recommendation, claim representation, actuarial simulation, or feature count.

Monetization should wait until the product demonstrates successful first-policy completion, repeated evidence-backed questions, renewal/emergency utility, retention, acceptable cost, and trust/correction metrics.

When monetisation begins, charge for software capacity and convenience, not safety access or unsupported intelligence. Billing must be real, receipt-verified, server-authoritative, and store-compliant before any price or Buy action is shown.

---

# 1. Permanent Product Boundary

The owner decision says CoverWise will not become an insurer, broker, agent, web aggregator, marketplace, claims representative, or regulated intermediary. It will not solicit, sell, procure, renew, recommend, rank products, earn commissions, or sell leads.

This must be enforced as code and content policy.

## Safe actions

- organise user-supplied policies;
- extract documented facts with evidence;
- explain clauses without changing meaning;
- answer from selected owned documents;
- show exact differences between documented fields;
- remind the user of a verified date;
- expose verified insurer contacts;
- maintain private notes/records;
- export and delete user data.

## Unsafe without a new deliberate review

- “you need” or “you should buy” conclusions;
- adequacy or risk scores;
- recommended coverage amounts;
- premium simulations;
- overall policy winners;
- renewal recommendation;
- claim approval/probability/timeline prediction;
- filing or representing claims;
- insurer/broker referrals or compensated leads;
- health diagnosis, treatment, or risk prediction.

---

# 2. What Is Strong and Should Be Preserved

- Current positioning says the policy and insurer remain the source of truth.
- Strategy correctly rejects behavioural advertising inside the private policy workspace.
- The first useful outcome is clear: a long policy becomes understandable and navigable.
- General software subscriptions can align with the boundary if charging for storage, sync, history, processing capacity, and convenience.
- Cloud Run/Supabase can support a focused solo product after reliability/lifecycle fixes.

---

# 3. P0 Findings

## P0-01: Implemented features violate the permanent non-regulated boundary

| Permanent decision | Current implementation |
|---|---|
| No recommendations | Coverage-gap engine recommends buying policies/riders |
| No renewal instruction | Expired policy recommends renewal/purchase; UI says Start renewal |
| No pricing simulation | What-if tool estimates premiums with arbitrary multipliers |
| No personal risk conclusion | Health score labels household Excellent to At Risk |
| Explain owned documents | Claims guide gives generic deadlines/process assertions |
| No suitability conclusion | Gap/score surfaces imply adequacy/sufficiency |

### Required action

Remove violating features and add product-boundary checks to code review and automated tests.

---

## P0-02: Billing UI is active while payment is a stub

Prices, packs, Buy controls, expiry, balance, and purchase-success messages are live-looking. The adapter grants entitlement without a transaction.

### Required action

Hide all monetization until:

- store products exist;
- billing SDK is integrated;
- receipts/server notifications are verified;
- entitlement is server-authoritative;
- refund, cancellation, restore, expiry, grace, and support work;
- release mode cannot use the stub.

---

## P0-03: Product packaging is not enforceable

Plan limits are local, inconsistent, and not enforced by APIs. Users can access features marked paid while server cost remains real.

### Required action

Do not market tiers yet. Establish one honest product and server cost limits. Later use backend entitlements and capability APIs.

---

## P0-04: Emergency access is configured as a premium entitlement

The plan registry reserves emergency access for Family tier.

A safety-oriented view of already-owned, already-processed user data should not be withheld. Monetise capacity/convenience, not emergency access to the user’s own stored facts.

---

## P0-05: The value proposition is broader than the validated core

The app includes policy intelligence, family management, health scoring, coverage advice, claims assistance, cards, literacy, calculations, search, reminders, accounts, and multiple monetization modes.

No current repository evidence shows which segment repeatedly uses or pays for this bundle.

### Required action

Run one wedge:

```text
owned policy -> evidence summary -> verified Q&A -> renewal/contact utility
```

Measure before expanding.

---

## P0-06: Public claims exceed the production/evidence contract

Marketing says CoverWise reads scans, answers with sources, exposes gaps, handles claim details, and provides offline-ready details. Current production/mobile paths do not consistently support these claims.

### Required action

Maintain a launch-claim registry with implementation, test, evidence tier, and approved wording.

---

## P0-07: Lead capture conflicts with the declared product identity

The backend stores email, phone, name, interest, preferred contact, and notes across all documents. Phone capture is prompted after value delivery.

Even without lead sale, this creates an unnecessary sales-funnel architecture with unclear purpose.

### Required action

Remove document-coupled lead capture. Account contact, support contact, and research participation must be separate purpose-bound flows.

---

## P0-08: Core reliability is not strong enough to charge for AI outcomes

Unresolved defects exist in source completeness, evidence, exact lookup, citations, readiness, deletion, account migration, durable processing, restore, and evaluation.

Charging per question or summary before remediation creates refund, support, and trust risk.

---

## P0-09: No unit-economics contract exists

The code can make many model calls per document/query. Cost tracking is process-local; unknown models cost zero; plan limits are hypotheses.

### Required action

Before pricing, measure:

- average/p95 cost per accepted-ready policy by page class;
- average/p95 cost per verified answer;
- retry/failure cost;
- free-user monthly cost;
- storage/support cost;
- gross margin by usage;
- abuse reserve.

---

## P0-10: No production support, refund, or complaint workflow

The product handles high-stress insurance data and proposes paid packs, but no complete flow exists for wrong extraction, wrong contact/deadline, failed purchase, refund, deletion failure, privacy request, security report, or urgent complaint.

### Required action

Define categories, service levels, escalation, correction, refund, incident handling, and correlation IDs before paid launch.

---

## P0-11: The product boundary is not enforced by tests

The strategy has a good boundary test, but code still contains “consider purchasing,” “renew immediately,” and numeric premium estimates.

### Required action

Add content-policy tests/static checks. High-risk prompts/templates require a named reviewer and evidence.

---

## P0-12: Launch narrative is inconsistent

README says not deployed, then preserves fully operational, full offline functionality, all tests passing, and Play Store readiness. Landing page includes a launch window and broad claims.

### Required action

One current launch status, one release manifest, and no dated launch promise until gates pass.

---

# 4. P1 Findings

1. Free/Plus/Family prices are embedded before validation.
2. annual/monthly discounts have no billing-catalogue source.
3. packs expire locally after 90 days.
4. question usage is client-controlled and tamperable.
5. plan reset/expiry use device time.
6. pay-per-question can incentivise unnecessary follow-ups.
7. charging per question is misaligned when answers fail/abstain.
8. purchase analytics use unsupported fields and price strings.
9. no taxation/invoice/refund data model.
10. no product-catalogue availability state.
11. no downgrade/data-retention contract after expiry.
12. cloud sync is paid but restore is not wired.
13. Family tier bundles immature features.
14. comparison is paid despite lacking evidence normalisation.
15. annual review has no authoritative workflow.
16. runtime copy does not define a precise primary persona.
17. “Built for Indian policyholders” is broad relative to formats/languages/insurers.
18. no usability evidence with policyholders in stressful contexts.
19. no willingness-to-pay/pricing research evidence.
20. no enforced activation, retention, trust, correction, support KPIs.
21. analytics cannot reliably sync and consent is unsafe.
22. no clean separation of acquisition analytics and private workspace behaviour.
23. no current research repository links product decisions to user evidence.
24. production marketing CTAs still say Try the demo while public demo is disabled.
25. landing page claim/gap statements cross the safe boundary.
26. no formal content review gate for regulated-adjacent language.
27. insurer contact convenience and lead/referral are not separated in data model.
28. no maintained subprocessor/model-provider disclosure artefact.
29. no policy for user-document use in model improvement.
30. superseded regulated partnership ideas remain alongside permanent rejection.
31. health expansion is discussed before policy retention evidence.
32. public education, private workspace, and paid product are not architecturally separated.
33. solo-founder support load is not a hard scope constraint.
34. no kill switch/feature flag policy for unsafe surfaces.
35. no customer-visible correction provenance after support intervention.

---

# 5. Recommended Wedge

## Primary user

An Indian policyholder who already owns a policy and needs exact terms without a sales conversation.

## Primary moment

- What policy is this?
- What are the key dates and money fields?
- What does this clause say?
- Where is the evidence?
- How do I contact the insurer?

## Promise

> CoverWise organises policies you already own and turns them into evidence-linked facts and answers. It does not recommend or sell insurance.

## Launch capabilities

- private policy vault;
- verified summary;
- exact source viewer;
- grounded Q&A with citations;
- verified expiry reminder;
- verified insurer contacts;
- export/delete/account controls.

## Explicit non-capabilities

- no adequacy score;
- no purchase recommendation;
- no premium estimate;
- no overall winner;
- no claim prediction/representation;
- no generic deadline presented as policy fact;
- no ads or compensated leads.

---

# 6. Measurement Framework

## Trust/quality

- displayed critical fields with verified evidence;
- correction rate by field;
- invalid citation rate;
- unsupported-answer abstention;
- source-open rate;
- trust/helpfulness after evidence inspection;
- critical complaint rate.

## Activation

- selected file → accepted upload;
- accepted → truthful ready;
- ready → evidence summary viewed;
- summary → first question;
- first question → source opened.

## Retention

- return for second policy;
- return near renewal;
- repeated verified Q&A;
- reminder use;
- account restore use.

## Economics

- cost per ready policy;
- cost per verified answer;
- support time per active user;
- storage per policy;
- paid conversion only after real billing;
- gross margin by cohort.

## Boundary safety

- prohibited recommendation incidents;
- ungrounded numeric estimate incidents;
- claim/renewal instruction incidents;
- marketing claim violations.

---

# 7. Monetization Sequence

## Stage 0: No purchase UI

Prove trust, reliability, and retention with controlled users.

## Stage 1: Capacity subscription experiment

Potential paid value: more verified policies, real sync/restore, longer history, higher verified-Q&A allowance, mature household organisation, and export/review workflows.

Do not paywall emergency facts, deletion, export, or correction.

## Stage 2: Real billing

Products configured, billing SDK, backend receipt/server-notification verification, entitlement ledger, restore/refund/cancellation/grace/dispute, support, tax/invoice review, and store evidence.

## Stage 3: Pricing tests

Use real cohorts and measured costs, not hardcoded hypotheses.

---

# 8. Compliance-Readiness Work

Before public launch with real policies/payments, obtain qualified review of:

- product boundary and marketing;
- privacy notice, purposes, processors, retention, and rights;
- account/anonymous identity and family/children data;
- app-store data-safety and health/finance declarations;
- subscription/pack expiry/refund/cancellation disclosures;
- payment tax/invoice treatment;
- incident/breach response;
- claims and renewal content;
- accessibility/support obligations;
- international data transfer/expansion.

Engineering must provide actual data flows, not aspirational copy.

---

# 9. Ordered Remediation

## Phase 0

Remove unsafe features, hide stub billing/prices, remove lead-funnel/false backup claims, correct public copy, and freeze launch-date claims.

## Phase 1

Ship the evidence-backed wedge internally, instrument trust/activation/retention/cost, run user research, and build correction/support.

## Phase 2

Prove reliability/repeat use, implement real restore/billing foundation, obtain qualified review, and run pricing research.

## Phase 3

Introduce one capacity offer and monitor support, trust, cost, refund, and boundary incidents.

---

# 10. Release Gates

- product boundary represented in code/copy/prompts/tests;
- current gap, health-score, what-if price, and generic claim advice absent;
- no purchase UI until verified billing;
- no client-only entitlement authority;
- no safety/data-right paywall;
- first-policy and first-answer gates pass;
- unit economics measured;
- support/correction/refund/privacy/security workflows exist;
- every public claim is registered/approved;
- current README/landing page have no readiness confusion;
- qualified review covers actual release flows;
- launch is evidence-based, not date-based.

---

# 11. Evidence Index

| Area | Paths |
|---|---|
| Permanent boundary | `docs/planning/coverwise_monetization_ads_responsible_data_research_2026-07-16.md` |
| Positioning | `README.md`, `src/frontend/templates/index.html` |
| Boundary violations | `mobile/lib/services/policy_extraction_service.dart`, `mobile/lib/providers/health_score_provider.dart`, `mobile/lib/utils/what_if_calculator.dart`, `mobile/lib/screens/renewal_calendar_screen.dart` |
| Claims | `mobile/lib/screens/claims_assistant_screen.dart` |
| Plans/pricing | `mobile/lib/models/entitlement.dart`, `mobile/lib/models/qa_pack.dart` |
| Stub purchases | `mobile/lib/services/billing_adapter.dart`, `mobile/lib/screens/qa_packs_screen.dart` |
| Lead capture | `mobile/lib/widgets/lead_capture_dialog.dart`, `mobile/lib/widgets/phone_capture_sheet.dart`, `src/api/document.py` |
| Cost | `src/llm/client.py`, `src/rag/pipeline.py` |
| Prior strategy contradictions | `docs/strategic_assessment_2026-07-17.md` |

---

# 12. Bottom Line

CoverWise has a coherent strategic identity in its best planning document and an incoherent product portfolio in code. The opportunity is to become the most trustworthy way to understand a policy the user already owns. Every feature and revenue decision should strengthen that promise or be removed.
