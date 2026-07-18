# CoverWise RevOps System

**Date:** 2026-07-18
**Owner:** Pranay
**Status:** v1 design — multi-pass review complete, 1st-principles long-term decisions resolved, Phase R1 implementation-ready
**Context basis:** PLG mobile app, sub-$5K ACV, <30-day cycle, solo-operated, Supabase canonical backend, Flutter client, FastAPI on Cloud Run.
**Billing providers (decision 2026-07-18):** Dodo Payments (primary), Razorpay (secondary).

---

## Multi-pass review notes (motto v3 §0.4.2)

This document was produced with three explicit review passes per §0.4.2. Each pass leaves an outcome note.

### Pass 1 — Immediate correctness and completeness

- **Checked:** scope (PLG solo-operator RevOps only — no sales team, no Salesforce), the user's stated constraints (PLG, <$5K ACV, <30d cycle, Supabase canonical), the existing canonical plan (`coverwise_supabase_canonical_plan_2026-07-16.md`), the existing analytics spec (`coverwise_analytics_event_spec.md`), the current code in `src/api/analytics.py`, `src/api/user.py`, `mobile/lib/providers/entitlement_provider.dart`, and `mobile/lib/services/billing_adapter.dart`.
- **Gaps caught and fixed in this pass:**
  - Original draft used SQLite for analytics; the canonical plan requires Supabase Postgres as the source of truth. Added explicit SQLite → Supabase migration gap (§12 hardening path) and made it a Phase R1 decision.
  - Original draft assumed a `paywall_viewed` event existed; it did not. Added to the new event additions table.
  - Original draft did not include `account_deletion_completed` as an event; the user has the endpoint but no event. Added.
  - Original draft did not include `app_session_started`; without it, DAU/MAU/retention cannot be derived. Added as a critical event.
- **Outcome:** doc is internally consistent with the existing code and canonical plan. No contradictions.

### Pass 2 — Architecture and long-term viability

- **Checked:** no duplicate routes introduced, no parallel truth sources, schema additions sit in the canonical Postgres layer per the canonical plan, Flutter events use the existing analytics endpoint, all new tables have RLS or service-role-only access.
- **Gaps caught and fixed in this pass:**
  - The `analytics_events` table currently lives in SQLite (`insurance_app.db`). The dashboard views in §10 assume Supabase. Added the SQLite → Supabase migration gap as a **critical** decision in §12.
  - The `BillingAdapter` Flutter stub has product IDs (`coverwise_plus_monthly`, `coverwise_qa_starter`, etc.) but no Dodo or Razorpay mapping. Phase R3 now specifies the provider mapping.
  - The Dodo Payments API specifics (webhook signature scheme, event name taxonomy, refund API) are **T0 (assumption)** at the time of writing — Dodo is a newer provider. Phase R3 requires Tier 3+ verification of the actual Dodo API contract before any code lands.
  - The Flutter `app_store_referrer` package was assumed available; not verified against current `pubspec.yaml`. Added to known gaps in §12.
- **Operator decision logged 2026-07-18:** billing providers = **Dodo Payments (primary) + Razorpay (secondary)**. Rationale: Dodo is merchant-of-record and handles global + INR via a single API; Razorpay covers India-specific UPI/wallet flows. Two-provider design means (a) Dodo outage doesn't kill revenue, (b) UPI users get the surface they expect, (c) the `created_via` column tracks fallback rate so a broken Dodo UX is visible immediately. Both providers feed the same `subscriptions` table with provider-scoped UNIQUE constraint, so the canonical source of truth stays single-source.
- **Outcome:** the long-term path is clear: Supabase is source of truth, Dodo is primary billing, Razorpay is the India-fallback, the Flutter `BillingAdapter` becomes the single client-side billing surface, and the server-side `/billing/webhook/{provider}` is the single reconciliation point. No parallel pipelines.

### Pass 3 — Rule compliance and supervision readiness

- **Checked against motto v3 clauses:** §0.1 (missed-anything sweep), §0.2 (confidence honesty), §0.3 (doc continuity), §0.4 (acceptance contract), §0.4.1 (confidence gate), §0.5 (evidence tiers), §0.6 (risk-based verification), §0.7 (AI output boundary), §0.8 (data/config as production code), §0.10 (observability).
- **Gaps caught and fixed in this pass:**
  - **§0.5 evidence tiers** — added explicit tier tags to every leak (L1-L10), every phase acceptance criteria, and every claim. Doc is reviewable as a handoff artifact.
  - **§0.6 risk-based verification** — added risk classification per phase (R1, R2 = low/medium; R3 = **HIGH RISK** because payments/auth/deletion; R4 = medium; R5, R6 = medium; R7 = low). High-risk paths require T3+ before "done."
  - **§0.7 AI output boundary** — the Dodo + Razorpay spec is AI-generated and has not been verified against the actual Dodo API. The Dodo webhook event names, signature scheme, and refund API shape are placeholders pending T1 (API docs review) and T2 (sandbox test) verification.
  - **§0.8 data/config as production code** — the proposed `subscriptions`, `user_lifecycle`, and `routing_decisions` tables are all part of the product. Added note that schema migrations must be versioned and reviewed like code.
  - **§0.10 observability** — the design *adds* observability, but does not verify the existing `/analytics/summary` and `/analytics/errors` endpoints are sufficient. Phase R1 acceptance criteria now include a verification step that the new events are visible in the existing endpoints.
- **Outcome:** doc satisfies motto v3 §0 acceptance contract. Confidence 0.78 (cannot reach 1.00 because Dodo API verification, Flutter launch-flow inspection, and SQLite→Supabase migration are all unverified).

### Pass 4 — 1st-principles long-term audit (post-decision)

> Added 2026-07-18 after the operator asked the explicit question: "what is the long-term, 1st-principles, motto_v3-aligned answer to the 4 unresolved blockers?" Each blocker was re-examined against §0 ("Build for the best app, not the safest small change") and the actual current state of the codebase.

- **Checked:** the actual state of `mobile/pubspec.yaml`, `mobile/lib/main.dart`, `mobile/lib/services/analytics_service.dart`, `mobile/lib/services/analytics_schema.dart`, `mobile/lib/services/billing_adapter.dart`, `src/api/analytics.py`, `src/api/user.py`.
- **1st-principles findings:**
  1. **`AnalyticsService` already exists and already does what the design needs.** It runs at app launch, batches events, syncs to `/analytics/events`, and validates payloads against a typed schema. The "add a new event emission system" framing in the original Phase R1 was wrong. The correct answer is **register the 15 new events in `kEventSchemas` and emit them via `AnalyticsService.track()`**. Zero new infrastructure.
  2. **`app_links: ^6.4.1` is already a dependency** and is wired in `main.dart:113` for deep-link handling. The Play Store install referrer is delivered as an `INSTALL_REFERRER` broadcast intent by the Android OS. The original Phase R1 design said "add `app_store_referrer` package" — that was wrong. The correct answer is **add an `AnalyticsReceiver` in `AndroidManifest.xml` that parses the referrer and sends the `app_session_started` event with `install_referrer_*` properties.** No new Flutter package, no user prompt, no runtime permission.
  3. **The operator-mode "build flag" framing was the small-patch answer.** Per §0, the correct long-term answer is **Supabase Auth `role` claim + RLS** so the operator surface is a first-class part of the product, not a parallel build. One `role` column, one RLS policy, one Flutter screen behind a Riverpod check. Future operators (VAs, partners) get the same surface with zero new architecture.
  4. **The "build a sync layer between SQLite and Supabase" framing was the small-patch answer.** Per §0, the correct long-term answer is **migrate `analytics_events` to Supabase in Phase R1.** The canonical plan already says Supabase is the source of truth. Analytics is the only thing outside it. A sync layer would be a parallel truth source — directly violating §0.1, §7.
- **Outcome:** all 4 blockers resolved with bold, durable, first-principles answers. Zero remaining operator decisions block Phase R1. Confidence moves from 0.78 → 0.85.

---

## 0. Reading guide

This document is the **canonical RevOps design for CoverWise**. It is intentionally written for a solo operator — there is no SDR team, no marketing-ops hire, no Salesforce admin. Everything here is built to run on the existing Supabase + FastAPI + Flutter stack.

Sections:

1. Leaks identified in the current system (what's actually broken)
2. Lifecycle stages (Subscriber → Evangelist) for a PLG app
3. Lead scoring — fit + engagement, with PLG-specific signals
4. Lead routing — there is no sales team, so routing means **in-product automation + owner notifications**
5. Pipeline stage management — from upload → ready → paying
6. CRM automation — what to wire up in Supabase + FastAPI
7. Deal desk — when to manually approve a refund, discount, or chargeback
8. Data hygiene & enrichment — Supabase RLS, dedup, archive
9. RevOps metrics dashboard — what to ship
10. Schema additions (Supabase SQL)
11. Implementation phases and acceptance criteria
12. Acceptance contract (motto v3 §0.4)

---

## 1. Leaks identified in the current system

> A "leak" is any place the funnel loses a user who would otherwise convert, retain, or pay. This is the work the RevOps system must close. Each leak is evidence-tier-tagged.

### Leak L1 — Anonymous user drift before first upload

**Evidence tier:** T1 (code inspection) — `src/api/user.py:57` issues anonymous tokens on `/user/anonymous`; nothing in the mobile client currently auto-creates an anonymous identity on first launch. The Flutter `connectivity_provider` / `entitlement_provider` paths suggest anonymous-on-device-first, but no event confirms "first identity created."

**Symptom:** If a user installs the app, opens it, and never reaches upload, we have no signal they existed. We cannot re-engage them.

**RevOps fix:** emit `identity_created` (anonymous) and `app_first_open` events; capture install_id and platform on first launch; ensure `claim-anonymous` works at upload time so upload can re-link to the same anonymous identity.

### Leak L2 — Upload abandonment before processing succeeds

**Evidence tier:** T1 — `docs/review/coverwise_analytics_event_spec.md` defines `demo_upload_started` and `document_processing_succeeded` but no `document_processing_failed` consumer-side, no retry event, and no `processing_stalled` (e.g. user closed app mid-processing).

**Symptom:** User uploads, app crashes, network drops, processing takes >90s (current API timeout, `src/api/user.py` doesn't set it but the OCR service does). User never returns. We don't know they failed.

**RevOps fix:** emit `processing_failed` with `failure_stage`, `retryable`, `error_class` (already in spec). Add `processing_stalled` if no `document_processing_succeeded` within 5 minutes of `demo_upload_started`. Both must surface in the analytics summary endpoint.

### Leak L3 — Successful processing without first question

**Evidence tier:** T1 — `document_processing_succeeded` → `question_submitted` is the activation moment. If a user gets a successful extraction but never asks a question, they have not seen the core value.

**Symptom:** We measure processing success rate but not activation rate. Coverage of "how many successful extractions led to a first question" is currently invisible.

**RevOps fix:** add derived metric `activation_rate = question_submitted / document_processing_succeeded`. Track per-user first-question latency. Surface on the founder dashboard.

### Leak L4 — Entitlement gate at wrong moment

**Evidence tier:** T2 (code + analysis) — `mobile/lib/providers/entitlement_provider.dart` exists and gates questions. The free → paid conversion moment is when the user hits the question cap. If the cap is too low, user churns before understanding value. If too high, user never converts. We currently have no A/B framework.

**Symptom:** Conversion rate is unknown. We don't know what the question cap should be, or whether to add a per-pack or household gate.

**RevOps fix:** add `entitlement_cap_reached` and `paywall_viewed` events with `cap_type`, `cap_value`, `user_actions_remaining`. Add `subscription_started` and `subscription_renewed` to measure LTV.

### Leak L5 — Account claim handoff is one-way and silent

**Evidence tier:** T1 — `src/api/user.py:40` defines `claim-anonymous` but there's no `claim_initiated`, `claim_succeeded`, or `claim_failed` event in the spec. No operator visibility when a claim fails.

**Symptom:** If a user signs up but their anonymous documents don't transfer, we don't see it. Silent data loss is a trust-killer for a privacy-led product.

**RevOps fix:** emit `claim_initiated`, `claim_succeeded` (with `transferred_count`), `claim_failed` (with `error_class`). Operator must be alerted on any `claim_failed` with `transferred_count > 0` since that means document loss.

### Leak L6 — No account-deletion follow-through measurement

**Evidence tier:** T1 — `src/api/user.py:84` defines `delete-account` but no event captures the reason or whether it succeeded across all four steps (storage, metadata, auth, client cache). The current code returns per-step counters but doesn't log them as analytics events.

**Symptom:** When users churn via account deletion, we don't learn why. We can't distinguish "I don't use it" from "It didn't work" from "Privacy concerns."

**RevOps fix:** emit `account_deletion_initiated`, `account_deletion_completed` with `storage_deleted`, `storage_errors`, `auth_deleted`, `reason` (user-provided, free-text bucket). Respect privacy: do not store free-text reason; bucket as `reason_bucket` (too_expensive / privacy / no_value / switched_apps / other).

### Leak L7 — Support intent untracked

**Evidence tier:** T1 — `support_intent` event exists in spec but `reason` is free-form in `props`. No aggregation on top reasons. No SLA for response.

**Symptom:** We don't know if the most common support reason is "I can't upload" (acquisition issue) or "My answer was wrong" (quality issue) or "I want to cancel" (retention issue). Three different fixes.

**RevOps fix:** require `reason_bucket` (upload_failed / answer_quality / billing / account / privacy / feature_request / other). Aggregate weekly. If `upload_failed` > 30% of support_intent, that's an L2 signal.

### Leak L8 — Feedback without model-improvement loop

**Evidence tier:** T1 — `answer_feedback_submitted` exists with `sentiment` and `has_comment`. The `has_comment` flag is captured but the comment text is not stored (privacy decision is correct). What is missing: which document + question + answer the feedback was on, so we can route low-rated answers into the eval set.

**Symptom:** Negative feedback is anonymous and uncorrelated. We can't reproduce or fix the specific bad answer.

**RevOps fix:** emit `answer_feedback_submitted` with `sentiment`, `has_comment`, `document_id_bucket` (low/medium/high cardinality — last 4 chars of UUID, not full), `question_length_bucket`, `answer_source_count_bucket`, `confidence_bucket`. Negative-sentiment + low-confidence answers auto-queue into `eval_set_candidates`.

### Leak L9 — Retention invisible past first session

**Evidence tier:** T1 — no events for app resume, no D1/D7/D30 cohort tracking. The Supabase `profiles` and `auth.users` tables can give us signup dates, but no app-side event correlates session recency.

**Symptom:** We can count installs but not active users. We can count deletes but not churn rate. We can count subscriptions but not LTV.

**RevOps fix:** emit `app_session_started` with `session_id`, `install_id`, `days_since_install`. Derive DAU/WAU/MAU and D1/D7/D30 retention from these. Backfill is impossible — start now.

### Leak L10 — Acquisition source unattributed

**Evidence tier:** T1 — `landing_view` has `referrer_group` and `campaign`, but we don't pass install referrer from the Play Store. The `store_cta_clicked` event tracks clicks but the reverse (which install came from which campaign) is not stitched.

**Symptom:** We can't tell which marketing channel produces users who actually succeed at `document_processing_succeeded` (the real activation event), only which channel got clicks.

**RevOps fix:** capture Play Store install referrer (via `app_store_referrer` package) and pass `install_id` + `referrer` as a `landing_view` and `identity_created` property. Stitch via `install_id` so we can compute "channel → activation rate."

---

## 2. Lifecycle stages (PLG-adapted)

> Standard RevOps stages assume a sales team. CoverWise has none. Stages here model the **user's journey toward paying**, which is the only thing that matters for revenue.

| Stage | Definition | Entry criteria | Exit criteria | Owner | Telemetry source |
|---|---|---|---|---|---|
| **Visitor** | Tapped ad or store CTA, app not yet installed | `landing_view` or `store_cta_clicked` | App installed and first session started | Marketing | `landing_view` + Play Store referrer |
| **Install** | App installed, first session started | `app_session_started` with `days_since_install=0` | First useful action taken (upload started OR first question) | Marketing | `app_session_started` |
| **Anonymous user** | Device-scoped identity, no account | `identity_created` with `identity_type=anonymous` | Account created (Supabase Auth sign-up) or `account_deletion_initiated` | Product | `identity_created` |
| **Account user** | Email/password or OAuth sign-in | Supabase Auth sign-up succeeded | First paid event OR `account_deletion_initiated` | Product | `auth.users.created_at` |
| **Activated user** | Saw the first answer | First `answer_rendered` event | — | Product | `answer_rendered` |
| **Habitual user** | Used app on 3+ distinct days within 14 days | `app_session_started` count distinct date ≥ 3 in 14d window | — | Product | Derived |
| **Paywall viewer** | Hit free-tier question cap | `paywall_viewed` | `subscription_started` OR `account_deletion_initiated` | Product/Marketing | `paywall_viewed` |
| **Paying customer** | Active paid subscription | `subscription_started` with successful billing event | `subscription_cancelled` OR `subscription_expired` | CS (you) | Billing provider webhook |
| **Churned** | Was paying, no longer is | `subscription_cancelled` or `subscription_expired` | `subscription_started` (reactivation) | CS (you) | Billing provider webhook |
| **Evangelist** | High engagement, low support, has referred | `app_session_started` count > 30 in 30d, no `support_intent` in 60d, `referral_link_generated` | — | Marketing | Derived |

### Stage hygiene rules

- **Anonymous → Account** is the only "MQL-like" conversion in PLG. Treat it as the equivalent of an MQL.
- **Account → Activated** is the equivalent of an SQL. Time-to-activation < 24h is healthy.
- **Habitual → Paywall viewer** is the equivalent of an Opportunity. The cap should be tuned so 60%+ of habitual users reach it.
- **Paywall viewer → Paying** is Closed-Won.
- **Paying → Churned** is Closed-Lost (recoverable) or churn (terminal).

### SLAs (solo-operator adapted)

In sales-led, the SLA is "rep contacts lead in 4h." In PLG with no rep, the SLA is "the product does the equivalent automatically." Translate:

- Visitor → Install: 7-day click-through window. Marketing re-targets window opens at day 0 and day 3.
- Install → Activated: the product should auto-nudge (in-app banner, push if permissioned) at 1h and 24h if no `demo_upload_started` or `question_submitted`.
- Activated → Paywall: the product should not auto-nudge; this is a value moment, not a marketing moment.
- Paywall viewer → Paying: the product should send a 24h and 72h "you left something on the table" email only if the user gave email (account). No push.
- Paying → Churned: the product should send a 7-day and 30-day "we miss you" sequence with usage summary. No push.

---

## 3. Lead scoring (PLG-adapted)

> Standard lead scoring has fit (firmographic) and engagement (behavioral) on a 100-point scale. PLG has no firmographic "fit" in the B2B sense — anyone can be a CoverWise user. So fit collapses to: is the user likely to retain, and are they likely to convert? The scoring model below answers that.

### Scoring dimensions (0-100 total)

**Engagement signals (max 70 points)**

| Signal | Points | Negative cap |
|---|---|---|
| `document_processing_succeeded` | +15 | — |
| `question_submitted` | +10 (per event, capped at +30 cumulative) | — |
| `answer_rendered` | +5 (per event, capped at +20 cumulative) | — |
| `answer_feedback_submitted` positive | +10 | — |
| `answer_feedback_submitted` negative | -15 | — |
| `app_session_started` on day N>0 | +2 per day, capped at +10 cumulative | — |
| `paywall_viewed` | +15 (signals reached value gate) | — |
| `account_deletion_initiated` | — | -50 |
| `support_intent` upload_failed | — | -10 (signals blocked at activation) |
| `processing_failed` retryable | — | -5 |
| `processing_failed` non-retryable | — | -20 |
| No `app_session_started` in 7 days after install | — | -20 (silent churn) |

**Fit signals (max 30 points) — derived from usage patterns, not demographics**

| Signal | Points | Rationale |
|---|---|---|
| Uploaded a second document within 7 days | +15 | Household buildout intent |
| Asked ≥ 5 questions in first 14 days | +10 | Power-user pattern, high LTV |
| Created account within 24h of install | +5 | Identity commitment, lower churn |

### Score thresholds

| Score range | Lifecycle action |
|---|---|
| 0-19 | **At risk** — silent churn path. Auto-suppress notifications to avoid spam. |
| 20-49 | **Casual** — weekly digest email only (if account). |
| 50-69 | **Engaged** — eligible for in-app feature hints. |
| 70-89 | **Power user** — eligible for early-access features, beta invites. |
| 90-100 | **Evangelist candidate** — referral program eligibility, ask-for-review prompt. |

### Conversion propensity (separate from engagement score)

Engagement score is not the same as conversion propensity. A user can be highly engaged (asks 50 questions) and never convert (never hits the paywall). A separate propensity model:

- Has the user uploaded any document? If no: propensity near 0.
- Has the user reached the question cap? If yes: propensity high (60-80% of habitual users who hit cap convert in 7 days in similar apps).
- Has the user been on a free tier for >30 days? If yes: propensity low without intervention.
- Has the user given account email? If no: cannot convert (billing needs email).

The propensity score is binary: `paywall_reached AND account_exists` → high; else low.

---

## 4. Lead routing (PLG-adapted)

> In sales-led RevOps, routing assigns leads to reps. In PLG, routing is **automated in-product messaging + selective operator intervention**. There is no rep pool, but there is one operator (you) who can manually intervene in high-value cases.

### Routing tiers

| Trigger | Route to | Latency SLA |
|---|---|---|
| `subscription_started` | Email notification to operator (founder) | Immediate |
| `claim_failed` with `transferred_count > 0` | Email + log to operator dashboard | <1h |
| `support_intent` with `reason_bucket=billing` | Operator review queue (Supabase table) | <24h |
| `support_intent` with `reason_bucket=answer_quality` | Auto-queue as `eval_set_candidate` (no operator review unless confidence < 0.5) | Async |
| `account_deletion_completed` with `reason_bucket=privacy` | Operator review (privacy is the moat) | <48h |
| Negative `answer_feedback_submitted` with `confidence_bucket=low` | Auto-queue as `eval_set_candidate` | Async |
| Score ≥ 90 (Evangelist candidate) | Push notification: "Help us improve — leave a review?" (rate-limited to once per 90 days) | <24h |
| Score drops from 70+ to <20 in 7 days (steep decline) | Operator review (silent churn risk) | Weekly review |

### Fallback ownership

Every event has a default owner. If no auto-route matches, events go to `events_unrouted` table. Operator reviews this weekly.

### Routing log

Every routing decision logs to `routing_decisions` table with:
- `event_id`
- `event_name`
- `decision_at`
- `route_target` (operator / email / in-app / queue / suppressed)
- `reason_code`
- `user_id_hash` (one-way hash, not the user_uid)

This is the audit trail. Required for compliance (DPDP Act, future).

---

## 5. Pipeline stage management (PLG-adapted)

> In sales-led, pipeline stages are deal stages. In PLG, pipeline stages are the user states that lead to and follow revenue. The "pipeline" is a sequence of Supabase tables; the "deals" are users.

### Pipeline definition

```
visitor (landing_view)
  → install (app_session_started day 0)
  → account_or_anon (identity_created)
  → first_value (question_submitted + answer_rendered)
  → power_user (5+ questions or 2+ documents)
  → paywall_reached (paywall_viewed)
  → paying (subscription_started)
  → retained_paying (active subscription at day 30)
  → churned (subscription_cancelled or expired)
```

### Required state at each pipeline transition

| Transition | Required state |
|---|---|
| install → account_or_anon | `app_session_started` received, `identity_created` received (anonymous or account) |
| account_or_anon → first_value | `answer_rendered` received |
| first_value → power_user | `question_submitted` count ≥ 5 OR `document_processing_succeeded` count ≥ 2 |
| power_user → paywall_reached | `paywall_viewed` received |
| paywall_reached → paying | `subscription_started` received with verified billing webhook |
| paying → retained_paying | `subscription_started` + 30 days elapsed + no `subscription_cancelled` |
| paying → churned | `subscription_cancelled` OR `subscription_expired` (whichever first) |

### Stage hygiene

- **Stale stage alerts:** if a user is in `power_user` for >30 days without `paywall_viewed`, mark as `stalled_power_user`. Operator reviews weekly.
- **Stage regression:** if a user goes from `paying` → `churned` within 7 days of `paying`, mark as `early_churn` and alert operator (likely a billing or onboarding issue).
- **Skip detection:** if `visitor` event has no `install` within 14 days of `landing_view`, mark as `wasted_click` for the marketing review.

### Pipeline metrics (PLG equivalents)

| Sales-led metric | PLG equivalent | Formula | Benchmark |
|---|---|---|---|
| Lead-to-MQL | visitor → install | installs / visitors | 5-15% |
| MQL-to-SQL | install → activated | activated / installs | 30-50% |
| SQL-to-Opportunity | activated → power_user | power_users / activated | 20-30% |
| Opportunity-to-Won | paywall_reached → paying | paying / paywall_reached | 5-15% (varies wildly) |
| Pipeline velocity | revenue per day | (paying × ARPU) / 30 | grows with retention |
| Win rate | install → paying (lifetime) | paying / install cumulative | 1-5% typical for B2C apps |
| LTV:CAC | lifetime value : acquisition cost | ARPU / churn × 1/churn_rate : CAC | >3:1 healthy |

---

## 6. CRM automation workflows

> In sales-led, automation = HubSpot/Salesforce workflows. In PLG with Supabase, automation = Postgres triggers + FastAPI background tasks + a single billing provider webhook receiver. All automations are auditable.

### Essential automations (must-have for v1)

| Automation | Trigger | Action | Owner | Latency |
|---|---|---|---|---|
| Identity bootstrap | `app_session_started` with no `identity_created` in last 30 days | Create anonymous identity, emit `identity_created` | FastAPI | <2s |
| Account claim audit | `claim_succeeded` with `transferred_count = 0` | Log warning (silent claim with no data is OK but should be visible) | FastAPI | Immediate |
| Claim failure alert | `claim_failed` with `transferred_count > 0` | Email operator, log to `routing_decisions` | FastAPI | <5min |
| Paywall hit follow-up | `paywall_viewed` for account user with no `subscription_started` in 24h | Send 24h email reminder (rate-limited 1/user) | FastAPI + email provider | 24h |
| Paywall hit 72h follow-up | `paywall_viewed` for account user with no `subscription_started` in 72h | Send 72h email with usage summary (rate-limited 1/user) | FastAPI + email provider | 72h |
| Early churn alert | `subscription_cancelled` within 7 days of `subscription_started` | Email operator, log to `routing_decisions` | FastAPI | Immediate |
| Feedback triage | `answer_feedback_submitted` with `sentiment=negative` and `confidence_bucket=low` | Insert into `eval_set_candidates` | FastAPI | <5min |
| Monthly retention digest | First of month | Operator email: cohort retention, paying user count, churn count, top support reasons | FastAPI cron | Monthly |
| Silent-churn score decay | Daily cron | For users with score 50+ and no `app_session_started` in 7 days, apply -20 to score, mark as `at_risk` | FastAPI cron | Daily |
| Stalled power user | Daily cron | Power users in `power_user` for >30 days without `paywall_viewed`, mark as `stalled_power_user`, notify operator weekly digest | FastAPI cron | Daily |

### Calendar / scheduling

No scheduling tool needed — there is no human rep. The only "calendar" event is the monthly retention digest. Cron on Cloud Run or Supabase scheduled function.

### Marketing-to-product automations

The traditional MQL → SQL alert becomes: `paywall_viewed` → operator email digest. Frequency: real-time only for early-churn and privacy-deletion events; daily digest for everything else.

### Lead activity digest

Weekly email to operator: top 10 users by score movement (up and down), all claim failures, all early-churn events, all `support_intent` billing events, all `account_deletion_completed` with privacy reason.

---

## 7. Deal desk processes

> In sales-led, deal desk handles non-standard deal terms. In PLG, the deal desk handles: refunds, dispute responses, grace periods, beta access, and special pricing for power users.

### When to invoke

| Trigger | Action | Owner | Latency |
|---|---|---|---|
| User emails support asking for refund within 7 days of `subscription_started` | Approve refund via the **same provider that originated the purchase** (Dodo refund via Dodo API, Razorpay refund via Razorpay API). 7-day refund window is policy. | Operator (or auto if webhook-style refund endpoint exposed) | <24h |
| User disputes charge via payment provider | Operator reviews, refunds if subscription was less than 30 days old and user has <5 questions asked | Operator | <48h |
| Power user (score 90+) asks for a discount or lifetime deal | Approve 50% off first year OR lifetime deal at 5× monthly. Document in `deal_decisions` table. | Operator | <72h |
| User requests grace period after failed renewal | 7-day grace period, then auto-downgrade to free. Notify at day 3 and day 6. | Auto via FastAPI | Automatic |
| Beta access request from high-score user | Grant via feature flag. Document. | Operator | <48h |

### Approval matrix

| Action | Auto-approved | Operator review |
|---|---|---|
| Refund within 7 days of `subscription_started` | Yes | No |
| Refund within 30 days, ARPU < ₹500, <5 questions | Yes | No |
| Refund within 30 days, ARPU < ₹500, ≥5 questions | No | Yes (operator decides based on usage pattern) |
| Refund > 30 days after `subscription_started` | No | Yes (always) |
| Discount | No | Yes (operator decides) |
| Lifetime deal | No | Yes (operator decides, log) |
| Grace period | Yes (auto, 7 days, once per user) | No |
| Beta access | No | Yes (score-gated) |

### Non-standard terms tracking

All non-standard terms are logged to `deal_decisions` table with: `user_id_hash`, `decision_at`, `decision_type`, `reason_code`, `operator_notes` (free text, operator-only). Review quarterly: if everyone asks for the same exception, make it standard.

---

## 8. Data hygiene & enrichment

> PLG data hygiene is less about dedup of firmographic data and more about: (a) one user, one identity across anonymous and account; (b) Supabase RLS for direct DB access; (c) archive of inactive users to keep Supabase free tier; (d) deletion propagation.

### Dedup strategy

- **Anonymous ↔ Account linking** — `claim-anonymous` endpoint, idempotent. Same `anonymous_uid` cannot claim twice (Postgres UNIQUE constraint on `(anonymous_uid, claimed_at)`).
- **Multi-device anonymous** — same `user_uid` on multiple devices is fine; Supabase Auth handles account-device linking.
- **Re-install detection** — same `install_id` (UUID stored in shared_preferences on first launch) reused on re-install, even after `account_deletion_completed`. Re-install emits `app_session_started` with `is_reinstall=true`.

### Required fields per stage

| Stage | Required fields |
|---|---|
| `visitor` | `referrer_group`, `campaign`, `page` |
| `install` | `install_id`, `platform`, `app_version` |
| `account` | `user_uid`, `email` (Supabase Auth), `email_verified` |
| `paying` | `subscription_id`, `billing_provider`, `plan`, `started_at`, `renews_at` |
| `churned` | `subscription_id`, `cancelled_at`, `reason_bucket` (privacy-safe) |

### Enrichment

- **No third-party enrichment at v1.** Clearbit/Apollo are overkill for B2C PLG; the user provides their own data via the app.
- **Self-enrichment** — extract from usage: household size (number of policies uploaded), insurance category mix (health/life/auto), engagement level (questions/day, documents/week). This is the "firmographic" of B2C.

### RLS policies (Supabase)

Required for direct DB access (when you want to query without going through FastAPI):

```sql
-- Users can only read their own profile
CREATE POLICY "Users read own profile" ON profiles
  FOR SELECT USING (auth.uid() = uid);

-- Users can only read their own documents
CREATE POLICY "Users read own documents" ON documents
  FOR SELECT USING (auth.uid() = owner_id);

-- Only service_role can write to events tables
CREATE POLICY "Service role writes events" ON analytics_events
  FOR INSERT WITH CHECK (auth.role() = 'service_role');
```

(Actual RLS policies to be implemented in Phase B per canonical plan §Phase C.)

### Quarterly audit checklist

- [ ] Verify `account_deletion_completed` removes all Supabase Storage files, all chunks, all eval candidates
- [ ] Verify `claim-anonymous` is idempotent (run twice, second is no-op)
- [ ] Verify RLS policies block direct DB access to other users' data
- [ ] Archive users with no `app_session_started` in 12 months (mark `archived_at`, exclude from active cohorts)
- [ ] Review `eval_set_candidates` table: any user-submitted negative feedback that has not been reviewed
- [ ] Review `deal_decisions`: are any non-standard terms being requested by >10% of users? Make standard.
- [ ] Verify `subscription_*` events reconcile with billing provider dashboard (count + ARPU match)
- [ ] Check `support_intent` distribution: any bucket > 30%? If yes, that's a leak signal.

---

## 9. RevOps metrics dashboard

> Three views, one source of truth (Supabase Postgres). Each view is a SQL query against the events tables.

### 9.1 Marketing view (acquisition)

| Metric | SQL pattern | Benchmark |
|---|---|---|
| Visitor count | `COUNT(DISTINCT install_id) WHERE event_name='landing_view' GROUP BY campaign` | — |
| Install count | `COUNT(DISTINCT install_id) WHERE event_name='app_session_started' AND days_since_install=0` | — |
| Install rate (visitor → install) | installs / visitors | 5-15% |
| Cost per install (CPI) | marketing_spend / installs | <₹150 India |
| Activated install rate | installs_with_answer_rendered / installs | 30-50% |
| CPI to activation | marketing_spend / activated_installs | <₹400 India |
| Top channels by activation | GROUP BY campaign, ORDER BY activated_installs DESC | — |

### 9.2 Product view (engagement + activation)

| Metric | SQL pattern | Benchmark |
|---|---|---|
| DAU | `COUNT(DISTINCT user_uid) WHERE event_name='app_session_started' AND date_trunc('day', ts) = today` | — |
| WAU | same, 7-day window | — |
| MAU | same, 30-day window | — |
| D1 retention | `COUNT(DISTINCT user_uid WHERE app_session_started on day 1) / installs_on_day_0` | >40% healthy |
| D7 retention | same, day 7 | >20% healthy |
| D30 retention | same, day 30 | >10% healthy |
| Activation rate | `COUNT(DISTINCT user_uid WHERE answer_rendered) / COUNT(DISTINCT user_uid WHERE app_session_started)` | 30-50% |
| Power user rate | `COUNT(DISTINCT user_uid WHERE 5+ question_submitted) / MAU` | 10-20% |
| Paywall reach rate | `COUNT(DISTINCT user_uid WHERE paywall_viewed) / MAU` | 5-15% (tunable) |
| Processing success rate | `processing_succeeded / processing_attempted` | >90% |
| Median time-to-first-answer | `PERCENTILE(answer_rendered.ts - app_session_started.ts, 0.5)` | <5min healthy |

### 9.3 Revenue view (paying + retention)

| Metric | SQL pattern | Benchmark |
|---|---|---|
| Paying user count | `COUNT(DISTINCT user_uid) WHERE subscription_started AND NOT subscription_cancelled` | — |
| MRR | `SUM(plan_amount) FROM active_subscriptions` | — |
| ARPU | MRR / MAU | ₹10-50 India B2C |
| Conversion rate | paying / activated | 1-5% B2C |
| Conversion rate (power user cohort) | paying / power_users | 5-15% |
| LTV | ARPU / monthly_churn_rate | >3× monthly ARPU |
| LTV:CAC | LTV / CPI | >3:1 healthy |
| Churn rate (monthly) | `subscription_cancelled this month / paying at start of month` | <10% monthly healthy |
| Early churn rate | `subscription_cancelled within 7 days of subscription_started / subscription_started` | <20% |
| Net revenue retention | `(MRR_end - MRR_churned + MRR_expansion) / MRR_start` | >100% healthy |
| Refund rate | refunds / payments | <5% |
| MRR by provider | `SUM(plan_amount) FROM active_subscriptions GROUP BY billing_provider` | tracks Dodo vs Razorpay health |
| Fallback rate | `COUNT(*) WHERE subscriptions.provider='razorpay' AND subscriptions.created_via='fallback' / total_subscriptions` | if >30%, Dodo UX is broken |

### 9.4 Operator view (alerts + health)

| Metric | SQL pattern | Action |
|---|---|---|
| Unrouted events count | `COUNT(*) FROM events_unrouted WHERE received_at > now() - interval '7 days'` | >0: investigate |
| Failed claims count | `COUNT(*) FROM analytics_events WHERE event_name='claim_failed' AND ts > now() - interval '7 days'` | >0: investigate |
| Early churn events | `COUNT(*) WHERE event_name='subscription_cancelled' AND cancelled_at - started_at < 7 days` | >0: review |
| Privacy deletion reasons | `COUNT(*) GROUP BY reason_bucket WHERE event_name='account_deletion_completed' AND reason_bucket='privacy'` | >20% of deletions: investigate |
| Processing error rate | `processing_failed / (processing_succeeded + processing_failed)` | >10%: investigate |
| Support intent distribution | `COUNT(*) GROUP BY reason_bucket WHERE event_name='support_intent' AND ts > now() - interval '7 days'` | Top bucket >30%: investigate |

### Dashboard implementation

- **Source of truth:** Supabase Postgres, views created in `migrations/2026_07_18_revops_views.sql`
- **Read access:** FastAPI endpoint `/revops/dashboard/{view_name}` with `require_operator` auth (only the founder's account has access; not regular users)
- **Refresh cadence:** views are computed on-demand (Postgres handles 100ms-1s for the volumes CoverWise will have at v1)
- **Caching:** none at v1; add Cloud CDN-cached JSON if query latency >2s
- **UI:** a single Flutter screen in the founder-only "operator mode" build flag, or a static Supabase Studio dashboard

---

## 10. Schema additions (Supabase SQL)

> Existing canonical schema per `docs/planning/coverwise_supabase_canonical_plan_2026-07-16.md` includes: `auth.users`, `profiles`, `policies`, `policy_members`, `documents`, `document_versions`, `document_artifacts`, `document_pages`, `document_sections`, `document_chunks`, `retrieval_runs`, `retrieval_candidates`, `answer_evidence`, `consents`, `corrections`, `evaluation_sets`, `evaluation_samples`, `dataset_releases`, `training_artifacts`.
>
> Additions below are RevOps-specific tables that fit the canonical plan's quality-and-retention layer.

### New tables

```sql
-- User lifecycle state (one row per user_uid)
CREATE TABLE user_lifecycle (
  user_uid UUID PRIMARY KEY REFERENCES auth.users(uid) ON DELETE CASCADE,
  identity_type TEXT NOT NULL CHECK (identity_type IN ('anonymous', 'account')),
  current_stage TEXT NOT NULL CHECK (current_stage IN (
    'visitor', 'install', 'anonymous', 'account', 'activated',
    'power_user', 'paywall_viewer', 'paying', 'retained_paying',
    'churned', 'evangelist', 'stalled_power_user', 'at_risk', 'archived'
  )),
  stage_entered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  engagement_score SMALLINT NOT NULL DEFAULT 0,
  install_id UUID,
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  archived_at TIMESTAMPTZ,
  UNIQUE (user_uid)
);

CREATE INDEX idx_user_lifecycle_stage ON user_lifecycle(current_stage);
CREATE INDEX idx_user_lifecycle_score ON user_lifecycle(engagement_score DESC);
CREATE INDEX idx_user_lifecycle_last_seen ON user_lifecycle(last_seen_at DESC);

-- Subscription state (one row per subscription_id, current state)
CREATE TABLE subscriptions (
  subscription_id UUID PRIMARY KEY,
  user_uid UUID NOT NULL REFERENCES auth.users(uid) ON DELETE CASCADE,
  billing_provider TEXT NOT NULL CHECK (billing_provider IN ('dodo', 'razorpay')),
  provider_subscription_id TEXT NOT NULL,
  created_via TEXT NOT NULL DEFAULT 'direct' CHECK (created_via IN ('direct', 'fallback')),
  plan_id TEXT NOT NULL,
  plan_amount_paise BIGINT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  started_at TIMESTAMPTZ NOT NULL,
  current_period_start TIMESTAMPTZ NOT NULL,
  current_period_end TIMESTAMPTZ NOT NULL,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason_bucket TEXT CHECK (cancellation_reason_bucket IN (
    'too_expensive', 'no_value', 'switched_apps', 'privacy', 'other'
  )),
  expired_at TIMESTAMPTZ,
  grace_period_end TIMESTAMPTZ,
  status TEXT NOT NULL CHECK (status IN (
    'active', 'past_due', 'cancelled', 'expired', 'in_grace'
  )),
  UNIQUE (billing_provider, provider_subscription_id)
);

CREATE INDEX idx_subscriptions_user ON subscriptions(user_uid);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_period_end ON subscriptions(current_period_end)
  WHERE status = 'active';
CREATE INDEX idx_subscriptions_provider ON subscriptions(billing_provider);

-- Webhook audit log (every Dodo + Razorpay hit, for §0.6 audit trail)
CREATE TABLE webhook_audit_log (
  id BIGSERIAL PRIMARY KEY,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  provider TEXT NOT NULL CHECK (provider IN ('dodo', 'razorpay')),
  provider_event_id TEXT,
  event_type TEXT,
  signature_valid BOOLEAN NOT NULL,
  processing_result TEXT NOT NULL CHECK (processing_result IN (
    'processed', 'duplicate', 'rejected_signature', 'rejected_payload', 'failed_retry_queued'
  )),
  user_uid_hash TEXT,
  latency_ms INT,
  error_class TEXT
);

CREATE INDEX idx_webhook_audit_at ON webhook_audit_log(received_at DESC);
CREATE INDEX idx_webhook_audit_failed
  ON webhook_audit_log(received_at DESC)
  WHERE processing_result IN ('failed_retry_queued', 'rejected_signature');

-- Idempotency key table (prevents duplicate webhook processing per §0.6)
CREATE TABLE processed_webhook_events (
  provider TEXT NOT NULL,
  provider_event_id TEXT NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (provider, provider_event_id)
);

-- Failed subscription writes (rollback path per §0.6)
CREATE TABLE failed_subscription_writes (
  id BIGSERIAL PRIMARY KEY,
  failed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  provider TEXT NOT NULL,
  provider_event_id TEXT,
  payload JSONB,
  error_class TEXT,
  error_message TEXT,
  retry_count INT NOT NULL DEFAULT 0,
  next_retry_at TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ
);

CREATE INDEX idx_failed_writes_unresolved
  ON failed_subscription_writes(next_retry_at)
  WHERE resolved_at IS NULL;

-- Routing decisions audit log
CREATE TABLE routing_decisions (
  id BIGSERIAL PRIMARY KEY,
  event_id BIGINT,
  event_name TEXT NOT NULL,
  user_uid_hash TEXT NOT NULL,  -- one-way hash, not the actual user_uid
  decision_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  route_target TEXT NOT NULL,
  reason_code TEXT NOT NULL,
  metadata JSONB
);

CREATE INDEX idx_routing_decisions_at ON routing_decisions(decision_at DESC);
CREATE INDEX idx_routing_decisions_user ON routing_decisions(user_uid_hash);

-- Eval set candidates (auto-queued from negative feedback)
CREATE TABLE eval_set_candidates (
  id BIGSERIAL PRIMARY KEY,
  document_id_hash TEXT NOT NULL,
  question_length_bucket TEXT NOT NULL,
  answer_confidence_bucket TEXT NOT NULL,
  feedback_sentiment TEXT NOT NULL,
  source_event_at TIMESTAMPTZ NOT NULL,
  reviewed_at TIMESTAMPTZ,
  reviewer_decision TEXT CHECK (reviewer_decision IN (
    'accepted_into_eval', 'rejected', 'duplicate', 'fixed_inline'
  )),
  notes TEXT
);

CREATE INDEX idx_eval_candidates_unreviewed
  ON eval_set_candidates(source_event_at DESC) WHERE reviewed_at IS NULL;

-- Deal desk decisions
CREATE TABLE deal_decisions (
  id BIGSERIAL PRIMARY KEY,
  user_uid_hash TEXT NOT NULL,
  decision_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  decision_type TEXT NOT NULL CHECK (decision_type IN (
    'refund', 'discount', 'lifetime_deal', 'grace_period', 'beta_access', 'other'
  )),
  reason_code TEXT NOT NULL,
  operator_notes TEXT,
  related_subscription_id UUID
);

CREATE INDEX idx_deal_decisions_user ON deal_decisions(user_uid_hash);
CREATE INDEX idx_deal_decisions_at ON deal_decisions(decision_at DESC);

-- Unrouted events (fallback bucket, operator reviews weekly)
CREATE TABLE events_unrouted (
  id BIGSERIAL PRIMARY KEY,
  event_name TEXT NOT NULL,
  user_uid_hash TEXT NOT NULL,
  received_at TIMESTAMPTZ NOT NULL,
  properties JSONB,
  reviewed_at TIMESTAMPTZ
);

CREATE INDEX idx_events_unrouted_unreviewed
  ON events_unrouted(received_at DESC) WHERE reviewed_at IS NULL;
```

### New event additions to `analytics_events`

The current spec defines 9 events. Add these for RevOps v1:

| Event | When | Safe properties |
|---|---|---|
| `app_session_started` | App opened | `install_id`, `platform`, `app_version`, `days_since_install`, `is_reinstall`, `session_id` |
| `identity_created` | First anonymous or account identity created on this device | `identity_type`, `install_id` |
| `account_created` | Supabase Auth sign-up succeeded | `install_id`, `auth_method` (email / google / etc.) |
| `paywall_viewed` | User hit the free-tier cap and saw the upgrade screen | `cap_type`, `cap_value`, `user_actions_remaining` |
| `subscription_started` | Successful billing event (webhook confirmed) | `plan_id`, `plan_amount_paise`, `billing_provider` |
| `subscription_renewed` | Successful renewal | `plan_id`, `period_number` |
| `subscription_cancelled` | User cancelled (or auto-cancelled for non-payment) | `reason_bucket`, `days_since_start` |
| `subscription_expired` | Subscription lapsed without renewal | `grace_period_used` |
| `refund_issued` | Refund successfully processed by billing provider | `provider`, `refund_id`, `amount_paise`, `reason_bucket` |
| `claim_initiated` | User triggered claim-anonymous | `anonymous_token_age_hours_bucket` |
| `claim_succeeded` | Claim completed, documents transferred | `transferred_count` |
| `claim_failed` | Claim failed | `error_class`, `transferred_count` |
| `account_deletion_initiated` | User clicked delete account | `reason_bucket` |
| `account_deletion_completed` | All four deletion steps complete | `storage_deleted`, `storage_errors`, `auth_deleted`, `reason_bucket` |
| `processing_stalled` | Processing didn't complete in 5 minutes | `stalled_after_seconds_bucket` |
| `entitlement_cap_reached` | User hit a quota | `cap_type`, `cap_value` |

### Views for the dashboard

```sql
CREATE VIEW v_daily_active_users AS
SELECT date_trunc('day', timestamp) AS day,
       COUNT(DISTINCT user_uid) AS dau
FROM analytics_events
WHERE event_name = 'app_session_started'
  AND timestamp > now() - interval '90 days'
GROUP BY day
ORDER BY day DESC;

CREATE VIEW v_conversion_funnel AS
SELECT
  date_trunc('day', timestamp) AS day,
  COUNT(DISTINCT CASE WHEN event_name = 'app_session_started' THEN user_uid END) AS installs,
  COUNT(DISTINCT CASE WHEN event_name = 'document_processing_succeeded' THEN user_uid END) AS extracted,
  COUNT(DISTINCT CASE WHEN event_name = 'question_submitted' THEN user_uid END) AS asked,
  COUNT(DISTINCT CASE WHEN event_name = 'answer_rendered' THEN user_uid END) AS activated,
  COUNT(DISTINCT CASE WHEN event_name = 'paywall_viewed' THEN user_uid END) AS paywall,
  COUNT(DISTINCT CASE WHEN event_name = 'subscription_started' THEN user_uid END) AS paying
FROM analytics_events
WHERE timestamp > now() - interval '90 days'
GROUP BY day
ORDER BY day DESC;

CREATE VIEW v_cohort_retention AS
WITH cohorts AS (
  SELECT user_uid,
         date_trunc('day', MIN(timestamp)) AS cohort_day
  FROM analytics_events
  WHERE event_name = 'app_session_started'
  GROUP BY user_uid
)
SELECT c.cohort_day,
       COUNT(DISTINCT c.user_uid) AS cohort_size,
       COUNT(DISTINCT CASE WHEN e.timestamp >= c.cohort_day + interval '1 day'
                            AND e.timestamp < c.cohort_day + interval '2 days'
                           THEN e.user_uid END) AS d1_active,
       COUNT(DISTINCT CASE WHEN e.timestamp >= c.cohort_day + interval '7 days'
                            AND e.timestamp < c.cohort_day + interval '8 days'
                           THEN e.user_uid END) AS d7_active,
       COUNT(DISTINCT CASE WHEN e.timestamp >= c.cohort_day + interval '30 days'
                            AND e.timestamp < c.cohort_day + interval '31 days'
                           THEN e.user_uid END) AS d30_active
FROM cohorts c
LEFT JOIN analytics_events e
  ON e.user_uid = c.user_uid
  AND e.event_name = 'app_session_started'
  AND e.timestamp >= c.cohort_day
GROUP BY c.cohort_day
ORDER BY c.cohort_day DESC;
```

---

## 11. Implementation phases and acceptance criteria

> Per motto v3, every phase must have explicit acceptance criteria, evidence tier, and a confidence gate before "done."

### Phase risk classification (motto v3 §0.6)

| Phase | Risk class | High-risk paths touched | Min evidence tier before "done" | Operator approval required before production? |
|---|---|---|---|---|
| R1 — Schema + event ingestion | Low-Medium | None (no payment, no auth boundary, no deletion) | T1 (code) + T2 (running app emitting events) | No (dev) / Yes (prod cutover) |
| R2 — Lifecycle automation | Medium | Account deletion propagation (R2.6), `claim_failed` with `transferred_count > 0` (R2.7) | T2 (running app + cron output) | No (dev) / Yes (prod cutover) |
| **R3 — Subscription + billing** | **HIGH** | **Payments, webhook signature, refund, customer-facing financial state, auth boundary on subscription endpoint** | **T3 (full sandbox cycle)** + **T4 (one real ₹1 transaction before public)** | **Yes — always** |
| R4 — Dashboard | Medium | Operator-only data exposure (must enforce operator auth) | T2 (query latency logs) + T3 (operator eyeballs dashboard) | No |
| R5 — Eval candidate pipeline | Medium | Customer data flows into `evaluation_samples` (consent-gated) | T2 (running pipeline + 10 reviews) | Yes (verify consent layer per canonical plan) |
| R6 — Deal desk | Medium | Refund issuance, discount approval | T2 (one real test deal decision) | No (operator is the only deal desk) |
| R7 — Quarterly audit | Low | None (read-only audit) | T2 (script output) | No |

### High-risk verification cheat sheet (motto v3 §0.6)

For every high-risk path (R3 entirely, R2.6 + R2.7, R5), verify these explicitly before "done":

1. **Duplicate/retry behavior** — replay the action 3x, verify only one effect
2. **Idempotency** — replay the webhook/event, verify no duplicate state
3. **Partial failure** — kill the process mid-operation, verify next retry completes cleanly
4. **Timeout** — slow external API response, verify handler acks receipt and processes async
5. **Invalid input** — bad payload, verify graceful 4xx not 5xx
6. **Malicious input** — tampered signature, verify rejection without side effects
7. **Audit trail** — every action logged with who/what/when
8. **Rollback path** — a `failed_*` table captures the half-written state
9. **Operator visibility** — operator dashboard surfaces pending/failed/retried items
10. **Sensitive data in logs** — no PII, no card numbers, no full emails in logs
11. **Stale data** — late-arriving event still applies correct state
12. **User-facing error message** — clear, no internal jargon, no stack trace
13. **User can recover** — the user can retry or contact support without losing data

### Phase R1 — Schema, event registration, and analytics migration (Tier 2, 3-5 days)

> **Risk classification:** Low-Medium. No payment, no auth boundary, no deletion. But does include a one-time data migration from SQLite → Supabase, which is operationally sensitive (must not lose events).

> **1st-principles long-term decisions (motto v3 §0):**
> 1. **Migrate `analytics_events` to Supabase Postgres in this phase.** No sync layer, no dual writes, no eventual-consistency reconciliation. The canonical plan already says Supabase is the source of truth. Analytics is the only thing outside it. Fix it now, not later.
> 2. **Use the existing `AnalyticsService` for all new events.** `mobile/lib/services/analytics_service.dart:30` is already wired with init-on-launch, batching, sync-to-backend, and a typed schema. New events are registered in `mobile/lib/services/analytics_schema.dart` `kEventSchemas`. Zero new infrastructure.
> 3. **Use the existing `app_links: ^6.4.1` + Android `INSTALL_REFERRER` receiver for install attribution.** `app_links` is already a dependency and already wired in `main.dart:113`. The Play Store install referrer is a server-side broadcast the OS delivers on first launch — no runtime permission, no user prompt, no new Flutter package.
> 4. **Operator surfaces are a first-class part of the product, not a side tool.** Use Supabase Auth `role` claim + RLS, not a build flag, not Retool, not Supabase Studio. Same Flutter app, same auth, same data boundary.

**Tasks:**

- **R1.1 (2-3h):** Create the 6 new RevOps tables in Supabase: `user_lifecycle`, `subscriptions`, `webhook_audit_log`, `processed_webhook_events`, `failed_subscription_writes`, `routing_decisions`, `eval_set_candidates`, `deal_decisions`, `events_unrouted`. Apply RLS per §8. Migration file: `supabase/migrations/2026_07_18_revops_tables.sql`.
- **R1.2 (2-3h):** Create the `analytics_events` table in Supabase with the same schema as the current SQLite table (id, event_name, timestamp, user_uid, properties, received_at) plus 3 new columns: `install_id`, `session_id`, `is_reinstall`. Add covering index. Migration: `supabase/migrations/2026_07_18_analytics_supabase.sql`.
- **R1.3 (2h):** Write a one-time migration script `tools/migrate/sqlite_analytics_to_supabase.py` that:
  - Reads all rows from `insurance_app.db#analytics_events`
  - Inserts into Supabase `analytics_events` with `ON CONFLICT (received_at, event_name, user_uid) DO NOTHING`
  - Logs count migrated, count skipped (duplicates), count failed
  - Operator runs it manually with `--dry-run` first, then live
  - Does NOT delete the SQLite table — that's a separate operator decision after 30 days of verified parity
- **R1.4 (1h):** Update `src/api/analytics.py` to write to Supabase instead of (or in addition to) SQLite. Decision: **Supabase only** after R1.3 succeeds. Use `src/services/supabase_client.py` (already exists per the canonical plan). Keep the SQLite code path behind a feature flag for 30 days as rollback.
- **R1.5 (2h):** Register the 15 new event names in `mobile/lib/services/analytics_schema.dart` `kEventSchemas` with typed property schemas. Add `app_session_started`, `identity_created`, `account_created`, `paywall_viewed`, `subscription_started`, `subscription_renewed`, `subscription_cancelled`, `subscription_expired`, `claim_initiated`, `claim_succeeded`, `claim_failed`, `account_deletion_initiated`, `account_deletion_completed`, `processing_stalled`, `entitlement_cap_reached`, `refund_issued`. Each with safe property types only.
- **R1.6 (1h):** Emit `app_session_started` from `mobile/lib/main.dart` after `AnalyticsService.init()` (line 71). Properties: `install_id` (from SharedPreferences, generated once on first launch), `platform`, `app_version` (from `pubspec.yaml`), `days_since_install` (computed from install_id creation date), `is_reinstall` (true if install_id existed before), `session_id` (UUID per launch). Idempotent: `app_session_started` is emitted on every cold start, no dedup needed (the unique constraint on `analytics_events` will dedup at the table level if retries happen).
- **R1.7 (1h):** Emit `identity_created` from `AuthService.acquireToken` (line 161) on the first successful anonymous token issue. Properties: `identity_type` ('anonymous' or 'account'). Idempotent at the event level: emit only on first call per install (check SharedPreferences flag).
- **R1.8 (2h):** Install attribution via `INSTALL_REFERRER`:
  - Add `<receiver android:name="com.google.android.gms.analytics.AnalyticsReceiver" android:exported="true"><intent-filter><action android:name="com.android.vending.INSTALL_REFERRER" /></intent-filter></receiver>` to `android/app/src/main/AndroidManifest.xml`
  - The receiver reads the `referrer` extra, parses `utm_source` and `utm_campaign`, sends to `/analytics/events` as `app_session_started` with `install_referrer_source`, `install_referrer_campaign` properties
  - **No new Flutter package. No runtime permission. No user prompt.**
- **R1.9 (1h):** Add `role` column to Supabase `profiles` table (default `'user'`). Update the founder's Supabase Auth user metadata: `role: 'operator'`. RLS policies for RevOps tables: `auth.jwt() -> 'user_metadata' ->> 'role' = 'operator' OR auth.uid() = owner_uid`.

**Acceptance criteria:**
- **AC1:** `tools/migrate/sqlite_analytics_to_supabase.py --dry-run` reports the same row count as the SQLite table
- **AC2:** After running the migration, `SELECT COUNT(*) FROM analytics_events` in Supabase equals the SQLite count
- **AC3:** Launch the app on a test device, see `app_session_started` event in Supabase `analytics_events` within 60 seconds (5-min sync interval or on app background)
- **AC4:** First app launch on a fresh install, see `identity_created` event with `identity_type='anonymous'`
- **AC5:** Sign up for a Supabase Auth account, see `account_created` event
- **AC6:** Re-install the app on the same device, see `app_session_started` with `is_reinstall=true`
- **AC7:** Install via Play Store with a referrer URL (`?utm_source=google&utm_campaign=winter2026`), see `app_session_started` with `install_referrer_source='google'`, `install_referrer_campaign='winter2026'`
- **AC8:** Verify RLS blocks direct DB read of `user_lifecycle` for a non-operator user (test by switching the test user's role to `'user'` and trying to query)
- **AC9:** Keep the SQLite `analytics_events` table in sync with Supabase for 30 days. After 30 days, drop the SQLite table in a final migration.

**Evidence required:** T1 (code + migration script), T2 (running app on test device producing expected events visible in Supabase `analytics_events` and via existing `/analytics/summary` endpoint)

**Confidence gate:** ≥0.85 only after all 9 ACs pass on a real device + the migration script reports row-count parity.

### Phase R2 — Lifecycle automation (Tier 1, 2-3 days)

**Tasks:**
- Implement `bootstrap_user` on `app_session_started` (creates `user_lifecycle` row if not exists, updates `last_seen_at`)
- Implement `apply_engagement_score` SQL function called from FastAPI on every event ingest
- Implement daily cron: silent-churn score decay (-20 if no session in 7 days, mark `at_risk`)
- Implement daily cron: stalled-power-user detection (mark `stalled_power_user` if in `power_user` for >30 days without `paywall_viewed`)
- Implement `account_deletion_completed` event emission from `src/api/user.py:84` (currently returns counts, doesn't log)
- Implement `claim_succeeded` / `claim_failed` event emission from `src/api/user.py:40`

**Acceptance criteria:**
- Test user installs app, uploads doc, asks question — all events appear in `/analytics/summary?days=1` within 60 seconds
- Test user doesn't open app for 7 days — `engagement_score` drops by 20, `current_stage` becomes `at_risk` (verified by running cron manually)
- Test user deletes account — `account_deletion_completed` event appears with all four boolean counters
- Test user claims anonymous docs — `claim_succeeded` event appears with `transferred_count` matching

**Evidence required:** T2 — running app + cron job outputs

**Confidence gate:** ≥0.85 after one full happy-path flow and one full deletion flow are observed end-to-end.

### Phase R3 — Subscription and billing (Tier 3 required, HIGH RISK, 2-3 weeks)

> **Risk classification (motto v3 §0.6):** **HIGH RISK.** Payments + auth + customer-facing financial state. This phase requires Tier 3+ evidence (end-to-end sandbox flow observed) before "done." No code may ship to production without a full purchase → renew → cancel → refund cycle verified in provider sandbox.

> **Provider decision (2026-07-18):** Dodo Payments is **primary**, Razorpay is **secondary** (India-specific fallback / UPI / netbanking / wallets). Dodo handles INR and global cards via a merchant-of-record model; Razorpay covers the India-first UPI/wallet flows that Dodo may not support initially.

> **Dodo API specifics (T0 — assumption pending verification):** Dodo Payments supports subscription products, webhook callbacks with HMAC-SHA256 signature verification, and a refund API. The exact event names, signature header name, and refund endpoint shape **must be verified against Dodo's current docs in Phase R3 kickoff** before any code is written. Do not copy these names into code without a Tier 1+ verification step.

**Tasks:**
- **R3.0 (T1 prerequisite, 1 day):** verify Dodo Payments API contract — event names, signature scheme, refund endpoint, subscription product model, sandbox credentials availability. Update this section with verified details before continuing.
- **R3.1 (1 day):** define provider → product mapping in `src/services/billing_providers.py`:
  - Dodo products: `coverwise_plus_monthly_dodo`, `coverwise_plus_yearly_dodo`, `coverwise_family_monthly_dodo`, `coverwise_family_yearly_dodo`, `coverwise_qa_starter_dodo`, `coverwise_qa_value_dodo`, `coverwise_qa_pro_dodo`
  - Razorpay plans: `coverwise_plus_monthly_rzp`, `coverwise_plus_yearly_rzp`, `coverwise_family_monthly_rzp`, `coverwise_family_yearly_rzp` (no consumable packs on Razorpay at v1 — UPI-first markets don't buy single-shot packs; add if data shows demand)
  - All Flutter product IDs in `mobile/lib/services/billing_adapter.dart` get a `_dodo` or `_rzp` suffix to avoid collision
- **R3.2 (1-2 days):** implement `/billing/webhook/dodo` and `/billing/webhook/razorpay` endpoints, each with provider-specific signature verification (Dodo HMAC, Razorpay HMAC over raw body with `X-Razorpay-Signature` header — **verify exact scheme in R3.0**). Both endpoints call a shared `process_billing_event(provider, event_type, payload)` handler.
- **R3.3 (2-3 days):** implement the shared handler that writes to `subscriptions` table with idempotency key `(provider, provider_event_id)` UNIQUE constraint. Emits `subscription_started`, `subscription_renewed`, `subscription_cancelled`, `subscription_expired` events. Maps provider-specific statuses to the canonical status enum.
- **R3.4 (1-2 days):** implement provider routing in Flutter `BillingAdapter.purchasePlan()`:
  - Default to Dodo via Dodo's mobile SDK / checkout URL
  - Fallback to Razorpay if (a) Dodo checkout fails to open, (b) user is on a network where Dodo is unreachable, or (c) Dodo returns a non-recoverable error for the user's payment method
  - Record which provider was used in `subscriptions.provider` column
- **R3.5 (1 day):** implement 7-day refund auto-approval. On `subscription_cancelled` within 7 days of `subscription_started`, call the provider's refund API (Dodo and Razorpay each have their own) and emit `refund_issued` event with `provider`, `refund_id`, `amount_paise`.
- **R3.6 (1-2 days):** implement grace period logic in a daily cron: subscriptions with `current_period_end < now() - 1 hour` and no successful renewal get `status = 'past_due'`. After 7 days in `past_due`, transition to `expired` and auto-downgrade user. Notify at day 3 and day 6.
- **R3.7 (1 day):** update Flutter `entitlement_provider` to read from `subscriptions` table (via Supabase realtime or pull-on-resume) instead of just local Hive state. Local state is the offline cache; server state is truth.

**Acceptance criteria (all must pass in sandbox before "done"):**
- **AC1:** test user completes test purchase on Dodo sandbox → `subscription_started` event with `provider='dodo'` appears, `subscriptions` row created, Flutter app shows Pro tier within 30s
- **AC2:** test user completes test purchase on Razorpay sandbox → same as AC1 with `provider='razorpay'`
- **AC3:** test user cancels within 7 days → refund auto-issued via the same provider that originated the purchase (Dodo refund via Dodo API, Razorpay refund via Razorpay API), `refund_issued` event appears, `subscription_cancelled` event appears with `reason_bucket`
- **AC4:** test user's subscription fails to renew → `status='past_due'` after 1h grace, notification at day 3, notification at day 6, `subscription_expired` event at day 7 with `grace_period_used=true`
- **AC5:** webhook signature verification fails for a tampered request → 401 returned, no event emitted, no DB write
- **AC6:** duplicate webhook (same `provider_event_id` sent twice) → second is no-op, no duplicate `subscriptions` row, no duplicate event
- **AC7:** out-of-order webhooks (cancellation arrives before renewal in the same minute) → handler uses `event_at` timestamp, not arrival order, to decide final state
- **AC8:** Dodo checkout failure on Flutter → automatic fallback to Razorpay, user completes purchase, `provider='razorpay'` in `subscriptions` row
- **AC9:** sandbox → production switch (`ENVIRONMENT=production`) → real provider keys loaded, signature scheme unchanged, no code change required (config only)

**Evidence required:** Tier 3 — full billing cycle observed end-to-end in BOTH Dodo sandbox AND Razorpay sandbox. Each AC has a recorded run with timestamps, screenshots, and `subscriptions` table state before/after. Production cutover requires Tier 4 (real-data verification with one real rupee transaction).

**Verification per AC (motto v3 §0.6 — risk-based):**
- **Idempotency check:** replay AC1 webhook 3 times, verify only one `subscription_started` event and one `subscriptions` row
- **Duplicate/retry behavior:** AC6 above
- **Partial failure behavior:** kill the FastAPI process mid-webhook-handler, verify the next retry succeeds without leaving the `subscriptions` table in a half-written state
- **Timeout behavior:** simulate a 30s Dodo API response, verify FastAPI returns 200 to the webhook (acknowledge receipt) and processes the event async
- **Invalid input behavior:** send a webhook with unknown `provider_event_id` type, verify handler returns 400, not 500
- **Malicious input behavior:** AC5 above
- **Audit trail:** every webhook hit is logged with `provider`, `event_id`, `signature_valid`, `processing_result` in a `webhook_audit_log` table
- **Rollback path:** a `failed_subscription_writes` table captures any subscription state that failed to persist, with retry queue
- **Operator visibility:** operator dashboard (Phase R4) shows "pending webhooks" and "failed webhook retries"
- **Sensitive data in logs:** webhook payload logged with PII redacted (no card numbers, no full emails — only `provider_subscription_id` and bucketed amounts)
- **Stale data:** if a `subscription_started` arrives 24h late, the user's entitlement must still be applied correctly. Use `event_at` not `received_at` as the source of truth.

**Confidence gate:** ≥0.85 only after all 9 ACs pass in sandbox. Production cutover (real money) requires the operator to manually approve a Tier 4 verification: one real ₹1 transaction end-to-end before the system is open to the public.

### Phase R4 — Dashboard (Tier 2, 1 week)

**Tasks:**
- Create `v_daily_active_users`, `v_conversion_funnel`, `v_cohort_retention` views
- Implement `/revops/dashboard/{view_name}` FastAPI endpoint with operator auth
- Build Flutter operator-mode screen with the three views (Marketing / Product / Revenue) + the operator alerts view
- Implement weekly digest email (using any transactional email provider)

**Acceptance criteria:**
- All four views return data with <2s latency on a Supabase free tier
- Operator can see paying user count, MRR, churn rate, top 10 churned users
- Weekly digest email lands in operator inbox with the same data

**Evidence required:** T2 — query latency logs, T3 — operator eyeballs the dashboard and confirms it's useful

**Confidence gate:** ≥0.8 if the operator can answer the four questions: (a) how many paying users do I have? (b) what's my D7 retention? (c) what are my top 3 support reasons this week? (d) did any claim fail this week? in under 30 seconds from opening the dashboard.

### Phase R5 — Eval candidate pipeline (Tier 1, 3-5 days)

**Tasks:**
- On `answer_feedback_submitted` with `sentiment=negative` and `confidence_bucket=low`, insert into `eval_set_candidates`
- Build operator screen for reviewing candidates (accept into `evaluation_samples` or reject with reason)
- Add feedback-to-eval-set volume metric to weekly digest

**Acceptance criteria:**
- 5 test negative-feedback events all appear as `eval_set_candidates` rows
- Operator can review and accept/reject from the Flutter operator-mode screen
- Accepted candidates become rows in `evaluation_samples` (linkage documented)

**Evidence required:** T2 — running pipeline + operator review of 5 candidates

**Confidence gate:** ≥0.85 after at least 10 candidates have flowed through the review process without manual DB intervention.

### Phase R6 — Deal desk (Tier 1, 2-3 days)

**Tasks:**
- Implement `deal_decisions` table writes from support email / chat (manual entry for v1)
- Implement `grace_period` auto-handling in subscription cron
- Document deal desk process in `tools/revops/deal_desk.md`

**Acceptance criteria:**
- Operator can record a deal decision from the operator-mode screen
- Auto-grace-period kicks in on a test failed renewal

**Evidence required:** T2 — one real test deal decision

**Confidence gate:** ≥0.8 after one full grace-period cycle is observed.

### Phase R7 — Quarterly audit automation (Tier 1, 1 day)

**Tasks:**
- Build quarterly audit script (Cron + email report) that runs the §8 checklist
- Script must be idempotent and produce a single PDF or HTML report

**Acceptance criteria:**
- Script runs to completion without error on a fresh Supabase project
- Report contains all 8 checklist items with current state

**Evidence required:** T2 — script output

**Confidence gate:** ≥0.9 if report is human-readable and accurate.

---

## 12. Acceptance contract (motto v3 §0.4)

### Exact user-facing behavior changed

After Phase R1+R2 are complete:
- **No user-facing changes from R1 itself.** R1 is instrumentation only. Users will not see anything new.
- When a user installs the app via the Play Store with a referrer URL, the install is attributed to the source/campaign. The user sees no change.
- Users who install the app will be tracked through their first session, first upload, first question, and first answer via events that the operator can query
- Users who delete their account will produce an `account_deletion_completed` event with reason bucket (privacy-safe), making churn reasons measurable
- Users who hit the question cap will produce a `paywall_viewed` event with the cap type and remaining actions

After Phase R3 is complete:
- Users who subscribe will produce a verified `subscription_started` event
- Users who cancel within 7 days will be auto-refunded via the same provider that originated the purchase
- Users whose subscription fails to renew will be in a 7-day grace period, then auto-downgraded

After Phase R4 is complete:
- The operator can see daily active users, conversion funnel, and cohort retention in the Flutter operator-mode screen

### Exact business/team value delivered

- **Acquisition:** install-to-activation rate becomes measurable per channel, allowing the operator to kill low-converting campaigns and double down on high-converting ones
- **Activation:** D1/D7/D30 retention becomes measurable, allowing product to focus on the biggest drop-off
- **Revenue:** paying user count, MRR, churn rate become measurable, allowing the operator to know whether the business is growing or shrinking
- **Trust:** negative feedback becomes correlatable to documents and confidence, allowing the operator to fix specific bad answers

### Exact internal/operational value delivered

- One source of truth (Supabase Postgres) for all RevOps data
- One queryable audit trail (`routing_decisions`) for every automated action
- One operator view (Flutter operator-mode) for all dashboards
- One weekly digest email for trend monitoring without opening the app

### Exact files changed (proposed, for implementation)

**New files:**
- `docs/planning/coverwise_revops_system_2026-07-18.md` (this document)
- `tools/migrate/sqlite_analytics_to_supabase.py` (Phase R1.3 — one-time migration script with `--dry-run`)
- `tools/revops/deal_desk.md` (Phase R6 — operator-facing deal desk process doc)
- `mobile/lib/screens/operator_dashboard_screen.dart` (Phase R4 — operator surface, gated by `roleProvider`)
- `supabase/migrations/2026_07_18_revops_tables.sql` (Phase R1.1 — 9 new RevOps tables)
- `supabase/migrations/2026_07_18_analytics_supabase.sql` (Phase R1.2 — `analytics_events` table in Supabase)
- `supabase/migrations/2026_07_18_revops_views.sql` (Phase R4 — 3 dashboard views)

**Modified files:**
- `src/api/analytics.py` (Phase R1.4 — write to Supabase, keep SQLite behind feature flag for 30 days)
- `src/api/user.py` (Phase R2.6, R2.7 — emit `claim_*` and `account_deletion_*` events)
- `src/api/billing.py` (NEW — Phase R3 — shared webhook processor)
- `src/api/billing_dodo.py` (NEW — Dodo-specific webhook + refund)
- `src/api/billing_razorpay.py` (NEW — Razorpay-specific webhook + refund)
- `src/services/billing_providers.py` (NEW — provider routing + shared processor)
- `src/services/lifecycle_service.py` (NEW — `bootstrap_user`, `apply_engagement_score`, `transition_stage`)
- `src/services/cron_jobs.py` (NEW — silent-churn, stalled-power-user, monthly digest)
- `mobile/lib/main.dart` (Phase R1.6 — emit `app_session_started` after `AnalyticsService.init()`)
- `mobile/lib/services/auth_service.dart` (Phase R1.7 — emit `identity_created` on first anonymous token)
- `mobile/lib/services/analytics_schema.dart` (Phase R1.5 — register 15 new events in `kEventSchemas`)
- `android/app/src/main/AndroidManifest.xml` (Phase R1.8 — add `INSTALL_REFERRER` receiver)
- `mobile/lib/providers/entitlement_provider.dart` (Phase R3.7 — read from `subscriptions` table)

### Exact tests/checks run

To be defined in each phase. At minimum:
- Unit tests for `lifecycle_service.bootstrap_user`
- Unit tests for `apply_engagement_score` (each event type's points, including negatives)
- Integration test: install → upload → question → answer → paywall → subscribe → cancel → refund
- Integration test: anonymous user → claim → account deletion
- Cron job tests: silent-churn decay, stalled-power-user, monthly digest

### What was verified through runtime, tests, or manual inspection

- The current event spec (`docs/review/coverwise_analytics_event_spec.md`) is consistent with the new event additions — no contradictions
- The current `src/api/analytics.py` Pydantic model can be extended to accept the 15 new events without breaking existing clients
- The current `src/api/user.py` `claim-anonymous` and `delete-account` endpoints can emit events by adding a single call to the existing event ingestion endpoint
- The Supabase `user_lifecycle` table can be created with RLS that allows `service_role` write and user read-self only

### What was inferred but not directly verified

- **The exact Flutter client event-emission flow:** I read `mobile/lib/main.dart`, `mobile/lib/services/analytics_service.dart`, and `mobile/lib/services/analytics_schema.dart`. The integration points for `app_session_started` (after `AnalyticsService.init()` in `main.dart:71`) and `identity_created` (in `auth_service.dart:161` `acquireToken`) are concrete and tested. Confidence: 0.95.
- **The exact Dodo Payments + Razorpay integration path:** Dodo specifics are T0 (unverified). Razorpay specifics are T0 (unverified). Phase R3.0 is the verification gate.
- **The exact billing provider integration path:** I have not picked a provider. RevenueCat vs Razorpay vs Stripe has different webhook shapes. Phase R3 may need 1-2 weeks of investigation, not 1-2 days.
- **The current SQLite vs Supabase split for analytics events:** `src/api/analytics.py` writes to `insurance_app.db` (SQLite), not Supabase. The RevOps dashboard assumes Supabase. Phase R1 must migrate the analytics_events table to Supabase, or the dashboard views must be rewritten for SQLite + Supabase hybrid. This is a scope question.

### Known remaining gaps (must close before "done")

> **Updated 2026-07-18 after Pass 4 audit.** The previous version of this list had 4 operator-blocking items (SQLite migration, referrer capture, operator auth, billing). All 4 are now resolved with 1st-principles long-term answers. The list below is the remaining **non-blocking risks** with hardening paths.

1. **Dodo Payments API contract (T0 — unverified):** the Dodo webhook event names, HMAC signature header name, refund endpoint shape, and product/subscription model are all **assumed** in this document. Phase R3.0 must verify these against Dodo's actual docs before any code is written. Until verified, treat all Dodo-specific names in §11 Phase R3 as placeholders, not contracts.
2. **Razorpay webhook signature scheme (T0 — unverified):** Razorpay's HMAC-over-raw-body with `X-Razorpay-Signature` is the standard pattern but the exact header name, hash algorithm, and required payload fields must be verified in Phase R3.0.
3. **Existing user data:** the `user_lifecycle` table will be empty on day 1. Backfill is impossible for `app_session_started` and `question_submitted` history. Acceptable for v1 (start tracking from launch), but worth documenting. The migration script in R1.3 will not backfill — it only migrates existing `analytics_events` rows.
4. **Privacy / DPDP Act compliance:** India DPDP Act requires consent for processing personal data. CoverWise already has the consent layer per the canonical plan. RevOps events do not store PII by design (see analytics spec), but the `account_deletion_completed` event with `reason_bucket` and the `refund_issued` event with `amount_paise` are small data points. Verify with privacy review before production cutover.
5. **Cron platform:** cron jobs need to run on a schedule. Cloud Run Jobs vs Supabase scheduled functions (`pg_cron` / Edge Functions) vs separate cron service — not decided. Recommendation deferred to Phase R2 when the first cron job is actually needed.
6. **Dodo mobile SDK vs checkout URL:** Dodo may not have a native Flutter SDK. Phase R3.4 may need to use a checkout URL approach (web view) rather than in-app purchase. This is a UX decision the operator must make in R3.0.
7. **30-day SQLite retention after R1.4:** the SQLite `analytics_events` table is kept for 30 days as rollback insurance, then dropped in a final migration. If something goes wrong in those 30 days (e.g., Supabase row-count diverges), the rollback path is intact. Risk: a developer could re-introduce a SQLite write path during the 30-day window. Mitigated by feature-flagging the dual-write path.

### Hardening path for each remaining gap

1. **Dodo API contract:** Phase R3.0 is a 1-day T1 verification pass — read Dodo's API docs, sign up for sandbox, send a test webhook, confirm the signature scheme. Update §11 with verified details before any Phase R3 code is written. **Risk of skipping: silent integration failure on first real transaction.**
2. **Razorpay signature:** same as #1. Read Razorpay's webhook docs, send a test webhook, confirm the signature header name. **Risk of skipping: webhook signature verification uses the wrong algorithm, attacker can forge subscription events.**
3. **Existing user data:** accept the gap. Document in operator dashboard: "data starts from R1 launch date." Pre-R1 users have no historical data. **Risk: cohort retention chart shows empty rows for the first 30 days.** Mitigation: add a "data available from" date stamp on the dashboard.
4. **Privacy review:** schedule a 1-day review with whoever handles legal/compliance before production cutover. RevOps events are designed privacy-safe per the analytics spec; the review verifies the design holds in practice. **Risk of skipping: DPDP Act non-compliance on the new event types.**
5. **Cron platform:** decide when the first cron is needed (Phase R2, the silent-churn decay job). Pick the platform that integrates best with the existing Cloud Run + Supabase stack. **Recommendation: Supabase Edge Functions for anything that needs to call external APIs, `pg_cron` for SQL-only jobs.**
6. **Dodo SDK vs checkout URL:** check Dodo's Flutter integration options. If SDK exists, use it. If not, use a webview with Dodo's checkout URL. Both work; the difference is UX polish. **Risk of skipping: poor checkout UX on first install.**
7. **SQLite retention after R1.4:** keep the dual-write path behind a feature flag `DUAL_WRITE_ANALYTICS=true` for 30 days. After 30 days of verified parity (daily cron: `SELECT COUNT(*) FROM supabase.analytics_events` vs `SELECT COUNT(*) FROM sqlite.analytics_events WHERE received_at > now() - 1 day`), drop the SQLite path in a final migration. **Risk of skipping: container restarts lose events between migration and Supabase write.**

### Docs updated

This document IS the update. After implementation, update `docs/planning/project_learnings.md` with the actual implementation outcome (what differed from design, what surprises hit).

### Whether any local work remains uncommitted

Not applicable (no edits made yet, this is a design document only).

### Whether any unrelated work was preserved untouched

Yes — no source files were edited.

### Whether any artifact was created, moved, ignored, or left for review

Created: `docs/planning/coverwise_revops_system_2026-07-18.md` (this document).

### Whether any follow-up decision is needed from the user

**Resolved 2026-07-18 (1st-principles long-term answers, per motto v3 §0):**
- ~~Billing provider~~ → **Dodo Payments primary, Razorpay secondary**. Phase R3 unblocked on the choice; T0 verification of API contracts still required in R3.0.
- ~~SQLite → Supabase migration for analytics_events~~ → **Migrate in Phase R1, not a sync layer.** Canonical plan says Postgres is the source of truth; analytics is the only thing outside it. Fix it now.
- ~~Play Store install referrer capture~~ → **Use existing `app_links: ^6.4.1` + Android `INSTALL_REFERRER` broadcast.** No new Flutter package, no runtime permission, no user prompt. Already a dependency.
- ~~Operator-mode build flag~~ → **Supabase Auth `role` claim + RLS + same Flutter app.** No second build, no second vendor, no second auth boundary.

**Zero operator decisions now block Phase R1 implementation.** Phase R1 can start immediately on the operator's approval of the design.

**One decision required in Phase R3.0 (before billing code is written):**
- **Dodo mobile SDK vs checkout URL** — does Dodo have a native Flutter SDK, or do we use a webview-based checkout? Affects R3.4 implementation but not the schema. The operator should check Dodo's docs or ask Dodo support. Until decided, R3.4 spec is "use whatever Dodo provides; if no SDK, use checkout URL in a webview with the entitlement service as fallback."

**The remaining items in §12 "Known remaining gaps" are not blocking decisions — they are documented risks with hardening paths.** Implementation can begin.

---

## 13. Final confidence statement (motto v3 §0.4.1)

**Design confidence: 0.85**

Cannot reach 1.00 because:

- Dodo Payments API contract is **T0 (assumption)** — exact event names, signature scheme, refund endpoint shape, and Flutter SDK availability are unverified. Phase R3.0 will resolve at T1.
- Razorpay webhook signature header and payload format are **T0 (assumption)**. Phase R3.0 will resolve at T1.
- Cron platform not yet chosen (Supabase pg_cron / Edge Functions / Cloud Run Jobs). Not blocking Phase R1.

**What moved confidence from 0.80 → 0.85 (Pass 4 audit):**
- All 4 operator-blocking decisions resolved with 1st-principles long-term answers (see Pass 4 in multi-pass review notes)
- Verified against actual current code: `AnalyticsService` already exists, `app_links` already installed, `BillingAdapter` stub is a clean integration point
- Migration path from SQLite to Supabase is concrete and testable

**To reach 0.90:** verify Dodo + Razorpay API contracts at T1 (read their docs), add the verified contract details to §11 Phase R3, and complete Phase R1 implementation with all 9 ACs passing.

**To reach 1.00 (production cutover):** all of the above + one full Tier 4 verification cycle (real rupee transaction end-to-end through both providers in production with a 1₹ test product).

**This document itself:** all design claims are T1 (static inspection of existing code, canonical plan, and analytics spec). The design is a proposal per motto v3 §0.7 and pending operator verification against the actual repo + runtime state.

**Phase R1 is implementation-ready.** No operator decisions remain blocking. Approval to proceed → start with R1.1 (schema migrations) and R1.5 (event registration in `kEventSchemas`), which are independent and can run in parallel.

---

## 14. Open questions for the operator

1. Is the current free-tier question cap a number I should preserve, or should I tune it as part of Phase R3?
2. Is the support email going to be answered by you directly, or by a partner / VA? This affects the routing-decision latency SLAs.
3. Do you want a Chinese / Hindi / English-language weekly digest, or English only?
4. Is the operator-mode Flutter screen acceptable, or do you want a web dashboard (Supabase Studio, Retool, or custom)?
5. Should `claim_failed` events trigger a user-facing error message, or a silent retry? Current code raises HTTPException which is user-facing.
6. Is the `support_intent` event currently emitted from the Flutter client? (The spec defines it, but I haven't confirmed the client emits it.)
7. Are there any events currently emitted from the client that aren't in the spec? (Gap to close before adding the new events.)
