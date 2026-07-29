# 6-Month Product Post-Mortem: CoverWise Play Store Audit

> **Status:** Draft (imagined scenario analysis, not a real post-mortem)
> **Date:** 2026-07-29
> **Source session:** Founder request: "Audit the app as a live product on Google Play Store but not performing in its 6th month — what may have failed, what's good that may make the app pull up its performance?"
> **Evidence tier:** Product reasoning (Tier 0) — imagined scenario analysis based on codebase review and product audit, not real user data
> **Related:** [First-Principles Derivation](../architecture/FIRST_PRINCIPLES_DERIVATION_FROM_MOTTO.md), [Product Wedge](../architecture/FIRST_PRINCIPLES_WEDGE.md)

---

## 1. Executive Summary

**Imagined scenario:** Launched on Play Store, 500–2K downloads, <5% week-1 retention, zero revenue, declining installs after month 3.

CoverWise has a strong technical foundation (grounded RAG with citation verification, 706+ passing tests, multi-language support) but suffers from a fundamental product–market mismatch: it solves a once-a-year problem (understanding a policy) using a high-friction interface (upload PDF → wait for OCR → get answers). The app's architecture is built for depth (multiple insurance types, family coverage, claims logging) but users never reach that depth because they churn before the first Q&A.

**Health Score:**

| Dimension | Score | Notes |
|-----------|-------|-------|
| Technical quality | ⭐⭐⭐⭐⭐ | 700+ tests, Sentry, offline-first, encrypted |
| Product depth | ⭐⭐⭐ | Good depth, but buried behind friction |
| User experience | ⭐⭐ | Cold start is the killer. Empty-until-upload |
| Monetization | ⭐ | Not started — RevenueCat wired but incomplete |
| Retention | ⭐ | One-shot use case, no daily hooks |
| Acquisition | ⭐ | No ASO, no marketing, no referrals |
| Analytics | ⭐⭐ | Infrastructure exists (events, endpoints, dashboard) but no data-driven decisions being made |

**Overall:** Struggling but salvageable. Technical foundation is unusually strong for a 6-month app. Problems are product and growth, not engineering.

---

## 2. 🔴 Failure Dimensions (Ranked by Impact)

### 2.1 Cold Start Crisis (Impact: ⭐⭐⭐⭐⭐)

**Symptom:** High install-to-registration drop. Users who install see an empty state.

**Root cause:** The app is useless until:
1. Find a physical/digital insurance policy
2. Upload it (find the file, select it)
3. Wait for OCR processing (30s–2min)
4. Navigate to Q&A to ask something

That's 4 steps and 2+ minutes before any value. Most users never complete step 1.

**Evidence in code:** `main.dart` shows `OnboardingScreen` → `SplashScreen` → `DocumentsScreen` flow. No sample policy to explore. No "Try it" button.

**First-principles correction (from the wedge analysis):**
The demo policy suggestion was rejected as outside the wedge (fake data doesn't help comprehension of the user's own situation). The correct fix from first principles is:
- **Shorten the comprehension path** — upload → coverage summary (not upload → Q&A)
- **Reduce onboarding friction** — 3 slides → 1 outcome screen (see `onboarding_first_principles_redesign.md`)
- **Navigate to comprehension output after upload** — not to a chat interface

### 2.2 Zero Recurring Engagement (Impact: ⭐⭐⭐⭐⭐)

**Symptom:** Users open once, get answers, never return.

**Root cause:** The core value prop ("understand your policy") is a one-shot use case. After the first Q&A session, there's no reason to return until renewal (12 months later).

**What exists but isn't leveraged:**
- Renewal reminders — fire once, 30/14/7 days before expiry
- Insurance literacy content — buried in a menu
- Claims log — self-reported, no push to update
- Family management — no collaborative features

**The wedge says:** The app must earn re-engagement at key moments (renewal, claim, life event). Proactive gap alerts and reminder notifications are structural consequences of the use case — not "growth hacks."

### 2.3 No Monetization (Impact: ⭐⭐⭐⭐)

**Symptom:** 0% conversion rate. Not because users won't pay — because there's nothing to pay for.

**Root cause:** RevenueCat is wired in `main.dart` (`billingInitProvider`, `billingAdapterProvider.identifyAccount`) but `AppConfig.hasRevenueCatConfig` requires build-time defines that are never set for release. No paywall screen, no pricing tiers defined, no free vs premium feature split, no trial period flow, no purchase-to-unlock gating.

**Wedge guidance:** Comprehension (coverage summary, grounded Q&A, citation badges) must be free. Convenience (export, sync, priority) and depth (comparison, family matrix, annual review) are paid candidates. See `FREE_VS_PAID_BOUNDARY.md`.

### 2.4 No User Acquisition Pipeline (Impact: ⭐⭐⭐⭐)

**Symptom:** Organic discovery near zero.

**Root cause:**
- No Play Store listing optimization (keywords, screenshots, descriptions)
- No blog/content to drive SEO
- No referral or share mechanism
- No social proof (ratings, reviews)
- No app indexing

### 2.5 High Onboarding Friction (Impact: ⭐⭐⭐)

**Symptom:** Significant drop between "Installed" → "Uploaded first document."

**Root cause:** `OnboardingScreen` shows feature explanations but doesn't get the user to value fast enough. The user flow is: Splash (2s) → Onboarding (5 swipes?) → Empty dashboard → Tap "Upload" → Find a PDF → Wait for processing → See extracted fields → Ask a question = ~2 minutes before any value.

**Corrected in wedge analysis:** The friction matters because comprehension is blocked until real data is in the system. Shortening the comprehension path is the first-principles fix. See `onboarding_first_principles_redesign.md`.

### 2.6 Analytics Blindness (Impact: ⭐⭐⭐)

**Symptom:** You can't diagnose what's failing because you can't see what users do.

**Root cause:** `AnalyticsService` buffers events in Hive and flushes via API. Backend analytics endpoints exist (`/analytics/summary`, `/funnel`, `/errors`, `/ops/dashboard`). But no one is checking them. Only `app_session_started` is tracked. No funnels, no onboarding step tracking, no upload completion rate, no cohort analysis.

**Current state (as of this session's work):** 63 events registered, 38/38 analytics tests pass, backend endpoints operational, funnel endpoint computes 6-stage funnel. The gap is not engineering — it's someone actually looking at the data.

### 2.7 Perceived Lack of Trust (Impact: ⭐⭐⭐)

**Symptom:** Users install, see data access requests, uninstall.

**Root cause:** The app needs camera/gallery access (for upload), notification permissions, and Supabase auth. Users don't know what CoverWise is — "reads your insurance documents" sounds suspicious. The onboarding says "Policy Information Assistant" but permission dialogs show a generic app name.

---

## 3. 🟢 Strengths to Leverage

### 3.1 Grounded RAG with Evidence-Backed Answers

This is the moat. Most "AI document readers" hallucinate. CoverWise:
- Verifies every citation against source text (`evidence_substrate_service.py`)
- Shows verification status badges (fully_backed / partially_backed / abstained)
- Links answers to specific source pages

This is the #1 marketing message: **"Every answer cites its source. No hallucination."**

### 3.2 Multi-Insurance-Type Coverage

Health, Motor, Life, Home, Travel, Marine — plus type-specific fields (VIN, NCB for motor; room rent cap for health; destination, trip duration for travel). This is differentiation. Most competitors handle only one type.

### 3.3 Multi-Language Support (M10)

Hindi, Gujarati, Marathi ARB files exist with 467+ keys each. India's insurance market is heavily non-English. This is a massive ASO and acquisition angle.

### 3.4 Robust Local-First Architecture

- Hive for offline storage
- Principal-scoped encryption
- Workspace isolation per identity
- Claims sync service

The app works offline — rare for AI-powered apps.

### 3.5 Sentry + Prometheus + Analytics Stack

Most early-stage apps have nothing. CoverWise has error tracking (Sentry), performance monitoring (Prometheus metrics), business metrics (5 counters), and a 63-event analytics system. The foundation for data-driven decisions exists — it just needs to be used.

### 3.6 700+ Passing Tests

Engineering rigor is rare at this stage. Users won't see this, but it means you can ship fast without regression fear.

---

## 4. 🎯 Action Plan (Priority Order)

### Immediate (This Week) — Fix Cold Start

| Action | Effort | Impact |
|--------|--------|--------|
| **Shorten comprehension path** — change post-upload destination from Q&A to coverage summary | 1 hour | ⭐⭐⭐⭐⭐ |
| **Reduce onboarding friction** — replace 3-slide onboarding with 1 outcome screen (see redesign doc) | 2-3 hours | ⭐⭐⭐⭐⭐ |
| **Add rate prompt** — after 3rd successful Q&A, show Play Store rating dialog | 2 hours | ⭐⭐⭐⭐ |

### Week 2 — Monetization

| Action | Effort | Impact |
|--------|--------|--------|
| Define freemium tiers (free: 1 policy, 20 Q&As/mo; premium: unlimited) | 0.5 day | ⭐⭐⭐⭐ |
| Build a paywall screen using RevenueCat `Purchases.getOfferings()` | 2 days | ⭐⭐⭐⭐ |
| Gate premium features (policy comparison, export, family sharing) | 2 days | ⭐⭐⭐⭐ |

### Week 3 — Retention Loops

| Action | Effort | Impact |
|--------|--------|--------|
| Push notification campaigns — weekly insurance tip, "Did your premium change?" check | 1 day | ⭐⭐⭐⭐ |
| Content feed — insurance literacy articles on Home tab (reason to open daily) | 2 days | ⭐⭐⭐⭐ |
| Seasonal triggers — "It's monsoon season — review your flood cover" content pulses | 1 day | ⭐⭐⭐ |

### Week 4 — Acquisition

| Action | Effort | Impact |
|--------|--------|--------|
| Play Store listing optimization — keywords, screenshots, descriptions | 1 day | ⭐⭐⭐⭐ |
| Shareable coverage summary — "Share my coverage" generates formatted text with app download link | 2 days | ⭐⭐⭐ |
| Referral program — "Add a family member to share policies" creates network effects | 3 days | ⭐⭐⭐ |

### Ongoing — Analytics

| Action | Effort | Impact |
|--------|--------|--------|
| Track onboarding funnel — install → upload → first Q&A → return within 7 days | 1 day | ⭐⭐⭐ |
| Set up cohort analysis — D1, D7, D30 retention by acquisition source | 1 day | ⭐⭐⭐ |
| Monitor Sentry Issues daily — fix top crash by DAU impact | Ongoing | ⭐⭐⭐ |

---

## 5. Key First-Principles Corrections From This Analysis

The original audit (provided in chat) made two recommendations that were later **rejected by the wedge framework**:

### 5.1 Demo Policy — REJECTED

**Original recommendation:** "Add a sample policy so new users can tap 'Try it' and immediately explore Q&A."

**Wedge rejection:** Fake data doesn't help the user understand THEIR insurance situation. It teaches wrong behavior (user learns to explore fake data, not their own coverage). The correct fix: shorten the real-data comprehension path instead.

### 5.2 Camera-First Flow — REJECTED

**Original recommendation:** Make camera capture the primary upload method.

**Wedge rejection:** Most policies arrive as digital PDFs (email, portal, WhatsApp). Camera flow adds OCR quality degradation + friction (photograph → crop → confirm). Direct digital import (file picker, share sheet) is the correct primary path. Camera remains an optional fallback for printed documents.

---

## 6. Relation to Other Documents

This analysis triggered the creation of the first-principles wedge (`FIRST_PRINCIPLES_WEDGE.md`) and the onboarding/dashboard redesign documents. The monetization analysis became `FREE_VS_PAID_BOUNDARY.md`. This document exists primarily as a record of what was considered and rejected, so future agents don't re-propose demo policies or camera-first flows without understanding why they were rejected.

## 7. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — comprehensive post-mortem analysis from chat | Founder correction: §0.3.1 documentation mandate |
