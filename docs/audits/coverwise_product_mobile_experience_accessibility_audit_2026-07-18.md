# CoverWise Product, Mobile Experience, Accessibility, and Customer-Trust Audit

**Date:** 2026-07-18  
**Repository:** `pranaysuyash/insurance_q`  
**Branch:** `main`  
**Commit:** `e3440a5da174c0cbbe279878bdff21950d8cab63`  
**Evidence tier:** Tier 1 static implementation inspection  
**Runtime status:** no current CI/check status was attached to the audited commit  
**Scope:** mobile information architecture, onboarding, upload, processing, policy detail, Q&A, family, emergency, renewal, claims, comparison, coverage review, what-if calculations, monetization UX, accessibility, responsive behaviour, offline states, and marketing-to-product consistency

---

## Executive Summary

CoverWise has a polished visual system and several strong interaction patterns, but the product experience currently makes more confident insurance conclusions than the underlying system can justify.

The most serious problems are not spacing, colour, or animation. They are **product-contract failures**:

- an arbitrary 0–100 “Insurance Health Score” labels households Excellent, Good, Needs Attention, or At Risk;
- a coverage-gap engine treats missing policies or missing extracted phrases as actual gaps and recommends buying, renewing, or adding riders;
- a what-if tool uses invented premium multipliers and renders rupee estimates;
- generic claims guidance gives deadlines, expected processing times, identity-document lists, and procedural instructions that are not derived from the selected policy;
- a live-looking Q&A pack store grants local entitlements without taking or verifying payment;
- local offline uploads are labelled as waiting to sync, but no durable sync worker was found;
- emergency, renewal, family, comparison, and policy screens display model-derived fields without field-level evidence or freshness state;
- feature entitlements are inconsistent with navigation and are enforced only in parts of the client;
- cross-device and backup promises are not supported by the data flow;
- public marketing promises scans, grounded answers, offline-ready details, coverage-gap support, and claim guidance beyond the currently reliable production capability.

**Verdict: NO-GO for the current full product surface.**

A launchable CoverWise should be narrowed to four evidence-backed jobs:

1. keep and review an owned policy;
2. show an evidence-linked policy summary;
3. answer document-grounded questions with verified citations;
4. surface verified renewal and insurer-contact details.

Emergency access can remain only when each field has a verified source and freshness state. The speculative score, gap, what-if pricing, generic claim deadlines, simulated purchases, and unsupported backup flows should be removed or disabled before customer use.

---

# 1. Product Thesis Versus Implemented Surface

The repository’s strongest written thesis is:

> Help users understand, organise, search, compare, and remember information in policies they already own, without selling, recommending, procuring, or acting on insurance.

The implemented app goes materially further. Its navigation exposes more than thirty full screens and tools, including:

- policy summaries;
- Q&A;
- family inventory;
- emergency cards;
- renewal actions;
- coverage gaps;
- comparison;
- premium what-if calculations;
- claim guidance;
- a claim log;
- insurance cards;
- literacy content;
- a health score;
- subscriptions and Q&A packs;
- account and phone-backup prompts.

The breadth obscures the core job and creates a large trust surface. Several features imply suitability, sufficiency, pricing, or claim procedure despite the product’s own permanent boundary.

---

# 2. What Is Strong and Should Be Preserved

## 2.1 Direct first-value path

Onboarding and dashboard upload actions can open the file picker directly. This reduces avoidable navigation before the first useful outcome.

**Preserve:** one primary action from onboarding and empty dashboard to source selection.

## 2.2 Consistent visual system

The app has reusable page headers, surfaces, icon badges, status chips, action rows, information panels, state transitions, and empty/error views. This creates recognisable product language and makes a narrower product easier to polish.

## 2.3 Visible processing state

A dedicated processing screen is better than a blocking spinner. It has live-region semantics, filenames, dismiss warnings, terminal states, and a path to policy detail.

**Preserve:** visible work and user-safe exit, but show only states the backend actually proves.

## 2.4 Evidence-adjacent Q&A design

The Q&A screen supports a selected policy or all policies, source cards, confidence and retrieval fields, missing information, follow-up suggestions, answer history, and feedback. The UI structure is useful once the source DTO and citation verifier are repaired.

## 2.5 Offline emergency intent

Emergency information is read from a local summary cache and the screen does not block on a network call. Offline intent is correct for a high-stress surface.

**Preserve:** offline availability, but only for verified and freshness-labelled fields.

## 2.6 Helpful accessibility work

The implementation includes meaningful use of `Semantics`, live regions, text scaling checks, minimum target sizes, reduced-motion tokens, and labels on controls and state changes. This is stronger than a typical early mobile product and should remain part of acceptance criteria.

## 2.7 Honest empty and partial copy in selected places

Some screens correctly say summary not available, expiry date not found, general guidance only, source document unavailable on this device, or processing is taking longer than expected. This needs to become the rule rather than an exception.

---

# 3. Scorecard

| Area | Judgement | Reason |
|---|---|---|
| Core upload flow | Directionally strong | Direct file picker and visible progress, but offline and completion semantics are inaccurate |
| Policy detail | Visually strong, evidentially unsafe | Clean hierarchy but values have no field-level proof or conflict state |
| Q&A | Strong shell, broken trust contract | Source metadata is flattened and citations are not rendered or verified |
| Emergency | High-risk partial | Offline cache exists, but values and contacts can be stale or unsupported |
| Renewal | Useful intent | Dates and contacts can be wrong; CTA language becomes action advice |
| Family | Premature | Model-derived people and DOBs lack evidence and correction workflow |
| Comparison | Superficial | Different policy categories and unnormalised fields are compared as peers |
| Coverage review | Unsafe | Missing data becomes a gap and recommendation |
| Health score | Unsafe | Arbitrary formula presented as household insurance condition |
| What-if | Unsafe | Invented pricing model rendered as rupee estimates |
| Claims | Unsafe | Generic procedures and deadlines presented as practical guidance |
| Monetization UX | Deceptive in current form | Stub billing grants local purchases and prices look live |
| Navigation | Overloaded | Five primary tabs plus a dense dashboard and fifteen More routes |
| Accessibility | Promising but incomplete | Good semantics, limited large-text/modal/table verification and no automated CI |
| Internationalisation | Not ready | Hard-coded English, India-specific currency and assumptions, no localisation architecture |
| Cross-device continuity | Broken | Local list is the app source of truth and no server restore flow is wired |

---

# 4. P0 Findings

## P0-01: The Insurance Health Score is an invented suitability signal

`mobile/lib/providers/health_score_provider.dart` assigns 25 points each for active-policy ratio, user-marked resolution of generated gaps, presence of three assumed “essential” types, and lack of expired/expiring policies. It labels the result Excellent, Good, Needs Attention, or At Risk, and can say coverage is strong across the board.

The score does not consider household income and liabilities, dependants, actual sums insured versus exposure, exclusions, sublimits, riders, waiting periods, deductibles, co-pay, policy overlap, employer cover, missing documents, or user needs. Its type comparison is also structurally unreliable because full strings such as `Health Insurance` are compared with `health`, `motor`, and `life`.

### Required action

Remove the customer-facing health score. A safe replacement is a neutral **Workspace Completeness** indicator based only on observable facts such as verified dates, unreadable pages, and fields requiring confirmation. It must not label adequacy or risk.

---

## P0-02: Coverage-gap detection converts absence of evidence into insurance advice

`PolicyExtractionService.analyzeCoverageGaps()` creates gaps when no health, life, or auto policy is in the local summary list, or maternity/critical-illness phrases are absent. It recommends purchasing policies, adding riders, ensuring auto coverage, and renewing immediately or buying a new policy.

A missing upload is not proof of no insurance. A missing phrase in an incomplete summary is not proof that coverage is absent.

### Required action

Remove the current engine. A safe replacement may show only:

```text
Not found in the uploaded documents
Not verified because pages are missing
Conflicting values found
No current policy of this type is present in this workspace
```

It must not recommend a product, rider, amount, renewal, or purchase.

---

## P0-03: The What-If Calculator fabricates premium estimates

`WhatIfCalculator.estimatePremium()` applies arbitrary factors: coverage multiplier, 0.85 or 1.15 for deductible direction, 1.08 for maternity, 1.03 for daycare, and 1.05 for pre/post hospitalisation. The screen renders “Estimated Results” in rupees and defaults a missing deductible to ₹10,000.

There is no actuarial, insurer, product, demographic, underwriting, age, location, claim-history, tax, or regulatory basis.

### Required action

Remove the feature. A safe arithmetic tool may only calculate transparent values from documented or user-entered numbers, such as annualised premium or percentage difference, without calling the result an insurance estimate.

---

## P0-04: Claims guidance presents generic deadlines and procedures as practical instructions

The hard-coded claim guide includes 24–48 hour notices, 7–30 day processing, 30 day life-claim processing, early-death investigation, Aadhaar, and fixed document lists. Only helpline/email are selected-policy data.

Deadlines and requirements vary by policy, insurer, incident, jurisdiction, network status, and claim type.

### Required action

Separate:

1. policy-derived claim information with page/quote evidence;
2. clearly general preparation notes with no deadline unless maintained from a current authoritative source.

---

## P0-05: Q&A pack purchase UI simulates successful payment

`BillingAdapter.purchaseQaPack()` and `purchasePlan()` directly grant local entitlements. The screen shows prices, Buy buttons, progress, success, active packs, expiry, and balance without a billing SDK, receipt, store transaction, backend entitlement, or release guard.

### Required action

Remove purchase actions from production builds until real billing and backend receipt verification exist. The stub must fail closed outside explicit development mode.

---

## P0-06: Entitlements are client-local, inconsistent, and not enforced across the product

The plan registry marks comparison, family, cloud sync, emergency access, and advanced search as paid, but routes are exposed through navigation and dashboard. Entitlements are local and trivially mutable.

### Required action

Until billing exists, run one honest free product with server-enforced cost limits. Later make entitlement server-authoritative and receipt-backed. Emergency access to the user’s own stored facts should not be paywalled.

---

## P0-07: Offline pending uploads have no discovered sync executor

Transport failures create a local `pending_upload` record and copy says it will sync when online. No durable queue, network listener, retry worker, or manual sync consumer was found.

### Required action

Implement a real idempotent upload operation queue, or relabel the state “Saved on this device only. Tap to upload when online.”

---

## P0-08: Core policy values and status are rendered as facts without evidence state

Policy detail, dashboard, emergency, renewal, comparison, and family surfaces display policy number, insurer, money values, benefits, exclusions, dates, active/expired state, people, and DOBs without field-level page, quote, completeness, conflict, or verification state.

### Required action

Every critical field must display one of:

- Verified in policy, with page/source action;
- Found, please confirm;
- Conflicting values;
- Not found;
- Source incomplete.

Unknown dates must not default visually to Active.

---

## P0-09: Emergency information can be stale, incomplete, or wrong without warning

Emergency cards trust cached summaries and permit immediate call/email actions without last-verified time, source page, completeness, superseded-version status, or contact evidence.

### Required action

Create a dedicated verified offline emergency snapshot with exact document/version, source evidence, generated/confirmed timestamps, and visible stale/incomplete warnings.

---

## P0-10: Auto-detected family data has no evidence or correction workflow

Model-generated names, DOBs, and relationships are shown under Family. “From document” has no source page, and auto-detected people cannot be edited or rejected individually.

### Required action

Treat each person as an extraction candidate with source, accept/edit/reject, and no relationship inference unless explicitly stated.

---

## P0-11: Policy comparison compares fields that are not normalised or necessarily comparable

Any two or three summaries can be compared without normalising category, currency, frequency, tax, floater/per-person cover, riders, benefit definitions, waiting periods, co-pays, or source completeness.

### Required action

Comparison must be field-specific, evidence-backed, and label incompatible fields/policies as not comparable. No overall winner or suitability conclusion.

---

## P0-12: Phone capture promises backup and cross-device access that do not exist

The phone number is written to local Hive only, while the UI says the policy is backed up and available across devices.

### Required action

Remove the feature or relabel it as a local contact preference until verified account recovery exists.

---

## P0-13: Account restore and cross-device continuity are not wired to the document source of truth

`documentsProvider` reads only local Hive. No active flow lists owned remote documents and restores them on a clean device, despite account messaging promising restoration.

### Required action

Implement a server-owned document library with local cache reconciliation, or remove restore/sync claims.

---

## P0-14: Public marketing claims exceed current production capability

The landing page promises scans, grounded answers, offline-ready details, coverage gaps, family checks, claim steps, and answers with sources. The production path does not consistently support them.

### Required action

Use a claim registry linking every statement to implementation, test, evidence tier, release state, and limitations.

---

# 5. P1 Findings

1. Navigation is too broad: five tabs, dense dashboard, and fifteen More routes.
2. Main-tab state is likely destroyed because selected pages are rebuilt rather than retained in an `IndexedStack`/nested navigator.
3. Dashboard duplicates most application navigation and buries current tasks.
4. Feature routes are not capability-aware.
5. Local and backend IDs are exposed to users.
6. Duplicate detection is filename-based rather than source/version-aware.
7. Processing-consent reuse does not compare saved and current disclosure versions.
8. Processing stages can imply durable progress that only exists in memory.
9. Processing screen blocks back navigation even though processing is asynchronous.
10. Raw Dio clients cause silent 401/fallback experiences.
11. Q&A quota can be deducted for non-empty fallback/error text.
12. Q&A copy/share omit evidence.
13. Confidence badge implies calibrated probability.
14. Search is only a local summary substring search.
15. Renewal reminders can be scheduled from unverified dates.
16. “Start renewal” crosses from reminder to action guidance.
17. Horizontal comparison table is difficult on narrow screens and assistive technology.
18. Long claims bottom sheet may not be scrollable.
19. Large text, landscape, tablet, and assistive-technology coverage is inconsistent.
20. Product is India-specific without a localisation architecture.
21. Web/desktop generation is configured without a supported-platform capability matrix.
22. Success copy often precedes durable outcomes.
23. Some flows can display raw exception strings.
24. Users cannot correct core extracted fields with source-preserving edits.
25. Feedback is keyed too loosely by question text.
26. Verified policy facts and general education use similar visual language.
27. Onboarding introduces broad future value before proving the core summary job.
28. “No gaps detected” overstates a small heuristic set.
29. Expiry state lacks a canonical timezone/end-of-day rule.
30. Profile, Settings, privacy, and account controls are fragmented and duplicated.

---

# 6. Target Product Surface

```text
Home
  Verified renewal alerts
  Recent policies
  Add policy

Policies
  Library
  Policy detail
  Source viewer
  Verified emergency snapshot

Ask
  Select one or all owned policies
  Verified answer and citations
  Missing/uncertain state

Settings
  Account and devices
  Data and consent
  Notifications
  Help and legal
```

| Feature | Decision before launch |
|---|---|
| Upload and library | Keep after durable sync and truthful status |
| Policy detail | Keep after evidence fields and correction |
| Q&A | Keep after citation/source repair and evaluation |
| Renewal date/reminder | Keep only for verified dates |
| Insurer contacts | Keep only with evidence |
| Emergency snapshot | Keep only as verified offline artifact |
| Owned-policy comparison | Defer until normalised evidence model |
| Family inventory | Defer until evidence/correction and identity scoping |
| Coverage gaps | Remove current implementation |
| Insurance health score | Remove |
| What-if premium estimate | Remove |
| Generic claim deadlines | Remove/rebuild as sourced information |
| Claim tracker | Defer |
| Insurance cards | Defer |
| Literacy quiz | Move to public content later |
| Q&A packs/subscriptions | Hide until real billing and value proof |
| Phone backup | Remove until real account recovery |

---

# 7. Accessibility and Inclusive Design Contract

Required checks:

- text scale 1.0, 1.3, 1.5, and 2.0;
- small phone, large phone, tablet, landscape;
- screen reader traversal order;
- keyboard focus if web/desktop remain supported;
- no colour-only meaning;
- minimum touch targets;
- reduced motion;
- high contrast and dark mode;
- scrollable modal sheets;
- accessible table/card alternatives;
- human-readable errors and retry;
- locale-aware numbers, currency, dates, and phone numbers.

Run Flutter semantics/widget tests in CI and add TalkBack/VoiceOver acceptance evidence for critical flows.

---

# 8. Ordered Remediation

## Phase 0

Remove health score, coverage recommendations, premium estimates, generic claim deadlines, purchase/upgrade UI, phone-backup claims, and unsupported marketing. Rename delete and sync states truthfully.

## Phase 1

Build evidence-aware summary, exact source navigation, user correction, partial/failed states, durable upload status, and one clean policy detail.

## Phase 2

Repair Q&A source DTO, verified citations, copy/share, quota semantics, and confidence.

## Phase 3

Add verified renewal, verified contacts, offline emergency snapshot, and remote library restore.

## Phase 4

Expand only after trust/retention evidence.

---

# 9. Product Release Gates

- no invented insurance score, recommendation, price, deadline, or suitability signal;
- every critical displayed value has evidence or uncertainty state;
- pending uploads have a real queue or no auto-sync claim;
- emergency snapshot is verified and freshness-labelled;
- no simulated purchase path;
- entitlements are server-authoritative when introduced;
- user can correct extracted facts;
- navigation is reduced to core jobs;
- marketing claims have implementation/test evidence;
- critical flows pass accessibility checks;
- account restore works before cross-device messaging;
- high-risk flows have Tier 3 or higher evidence.

---

# 10. Evidence Index

| Area | Primary implementation |
|---|---|
| Navigation | `mobile/lib/main.dart`, `mobile/lib/screens/more_screen.dart` |
| Dashboard | `mobile/lib/screens/dashboard_screen.dart` |
| Upload/offline | `mobile/lib/screens/documents_screen.dart`, `mobile/lib/services/document_service.dart` |
| Processing | `mobile/lib/screens/processing_status_screen.dart` |
| Policy detail | `mobile/lib/screens/policy_detail_screen.dart` |
| Q&A | `mobile/lib/screens/qa_screen.dart`, `mobile/lib/services/query_service.dart` |
| Family | `mobile/lib/screens/family_screen.dart` |
| Emergency | `mobile/lib/screens/emergency_screen.dart` |
| Renewal | `mobile/lib/screens/renewal_calendar_screen.dart` |
| Claims | `mobile/lib/screens/claims_assistant_screen.dart`, `mobile/lib/services/policy_extraction_service.dart` |
| Gaps and score | `mobile/lib/screens/coverage_gap_screen.dart`, `mobile/lib/providers/health_score_provider.dart` |
| Comparison | `mobile/lib/screens/policy_comparison_screen.dart` |
| What-if | `mobile/lib/utils/what_if_calculator.dart`, `mobile/lib/screens/what_if_calculator_screen.dart` |
| Billing | `mobile/lib/models/entitlement.dart`, `mobile/lib/services/billing_adapter.dart`, `mobile/lib/screens/qa_packs_screen.dart` |
| Public claims | `src/frontend/templates/index.html`, `README.md` |

---

# 11. Bottom Line

The visual app is ahead of the truth system. The next product milestone is a smaller product in which every status, value, source, action, payment, and promise means exactly what the system can prove.
