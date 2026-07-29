# Product Audit: CoverWise — 6-Month Play Store Post-Mortem

**Date:** 2026-07-28
**Context:** Imagined scenario — app has been live on Play Store for 6 months with 500–2K downloads, <5% week-1 retention, zero revenue, declining installs after month 3.
**Source:** Codebase analysis and architectural review.

---

## Executive Summary

CoverWise has a **strong technical foundation** (grounded RAG with citation verification, 706 passing backend tests, multi-language support) but suffers from a fundamental product–market mismatch: it solves a **once-a-year problem** (understanding a policy) using a **high-friction interface** (upload PDF → wait for OCR → get answers). The app's architecture is built for **depth** (multiple insurance types, family coverage, claims logging) but users never reach that depth because they churn before the first Q&A.

---

## 🔴 What's Likely Failing (Ranked by Impact)

### 1. Cold Start Crisis — The Biggest Problem

- **Symptom:** High install-to-registration drop. Users who install see an empty state.
- **Root cause:** The app is useless until the user: (1) finds a physical insurance policy PDF, (2) uploads it, (3) waits 30s–2min for OCR, (4) navigates to Q&A. That's 4+ steps and 2+ minutes before any value. Most users never complete step 1.
- **Code evidence:** `main.dart` shows `OnboardingScreen` → `SplashScreen` → `DocumentsScreen` flow. No path bypasses the document management layer.
- **Fix priority: ⭐⭐⭐⭐⭐**

### 2. Zero Recurring Engagement

- **Symptom:** Users open the app once, get their answers, never return.
- **Root cause:** The core value prop ("understand your policy") is a **one-shot use case**. After the first Q&A session, there's no reason to come back until renewal (12 months later).
- **What exists but isn't leveraged:**
  - Renewal reminders — fire once, 30/14/7 days before expiry
  - Insurance literacy content — buried in a menu
  - Claims log — self-reported, no push to update
  - Family management — no collaborative features
- **Fix priority: ⭐⭐⭐⭐⭐**

### 3. No Monetization (Zero Revenue)

- **Symptom:** 0% conversion rate. Not because users won't pay — because there's nothing to pay for.
- **Root cause:** RevenueCat is wired but incomplete. No paywall screen, no pricing tiers, no free-vs-premium split, no trial flow, no purchase-to-unlock gating.
- **Code evidence:** RevenueCat wired in `main.dart` (`billingInitProvider`, `billingAdapterProvider.identifyAccount`) but `AppConfig.hasRevenueCatConfig` requires build-time defines that are never set for release.
- **Fix priority: ⭐⭐⭐⭐**

### 4. No User Acquisition Pipeline

- **Symptom:** Organic discovery near zero. No ASO, no content marketing.
- **Root cause:** No Play Store listing optimization (keywords, screenshots, descriptions). No blog/content to drive SEO. No referral or share mechanism. No social proof (ratings, reviews). No app indexing.
- **Fix priority: ⭐⭐⭐⭐**

### 5. High Onboarding Friction

- **Symptom:** Significant drop between "Installed" → "Uploaded first document."
- **Root cause:** Onboarding shows feature explanations but doesn't get the user to value fast enough. The `startWithFilePicker: true` path exists but requires specific completion flags. The full user flow is ~8 screens before first aha moment.
- **User flow (current):** Splash (2s) → Onboarding (5 swipes) → Empty dashboard → Tap "Upload" → Find PDF on device → Wait for processing → See extracted fields → Ask a question = ~2 minutes before any value.
- **Fix priority: ⭐⭐⭐**

### 6. Analytics Blindness

- **Symptom:** Can't diagnose what's failing because user behavior is invisible.
- **Root cause:** `AnalyticsService` buffers events in Hive and flushes via API, but no analytics dashboard is actively monitored. No cohort tracking, no funnel analysis. Only `app_session_started` is tracked. No onboarding step tracking, no upload completion rate.
- **Code evidence:** `/analytics/summary` endpoint exists, `/ops/dashboard` exists — neither is used in a live context.
- **Fix priority: ⭐⭐⭐**

### 7. Perceived Lack of Trust

- **Symptom:** Users install, see data access requests, uninstall.
- **Root cause:** The app needs camera/gallery access, notification permissions, and Supabase auth. Users don't know what CoverWise is — "reads your insurance documents" sounds suspicious. Permission dialogs show a generic app name.
- **Fix priority: ⭐⭐⭐**

---

## 🟢 What's Good (Strengths to Leverage)

### 1. Grounded RAG with Evidence-Backed Answers

This is the **moat**. Most "AI document readers" hallucinate. CoverWise verifies every citation against source text (`evidence_substrate_service.py`), shows verification status badges (`fully_backed` / `partially_backed` / `abstained`), and links answers to specific source pages.

**Marketing message:** "Every answer cites its source. No hallucination."

### 2. Multi-Insurance-Type Coverage

Health, Motor, Life, Home, Travel, Marine — plus type-specific fields (VIN, NCB for motor; room rent cap for health). Most competitors handle only one type.

### 3. Multi-Language Support (M10)

Hindi, Gujarati, Marathi ARB files exist. India's insurance market is heavily non-English. This is a massive ASO and acquisition angle.

### 4. Robust Local-First Architecture

Hive for offline storage, principal-scoped encryption, workspace isolation per identity, claims sync service. The app works **offline** — rare for AI apps.

### 5. Sentry + Prometheus + Analytics Stack

Error tracking, performance monitoring, and business metrics — most early-stage apps have nothing. The foundation for data-driven decisions exists and just needs to be used.

### 6. 700+ Passing Tests

Engineering rigor is rare at this stage. Enables fast shipping without regression fear.

---

## 🎯 Action Plan (Priority Order)

### Immediate — Fix the Cold Start (First-Principles Approach)

The "demo policy" idea was rejected as not first-principles (see `docs/decisions/ADR-2026-07-28-reject-demo-mode.md`). Instead:

| Action | Effort | Impact |
|--------|--------|--------|
| Camera-to-answer flow — snap a policy page, get extraction + Q&A in one screen, bypassing document management layer entirely | 1 week | ⭐⭐⭐⭐⭐ |
| Email-to-CoverWise — every user gets a unique inbound email; forward policy PDF → auto-processed → push notification when ready | 3 days | ⭐⭐⭐⭐⭐ |

### Week 2 — Monetization

| Action | Effort | Impact |
|--------|--------|--------|
| Define freemium tiers (free: 1 policy, 10 Q&As; premium: unlimited) | 0.5 day | ⭐⭐⭐⭐ |
| Build a paywall screen using RevenueCat `Purchases.getOfferings()` | 2 days | ⭐⭐⭐⭐ |
| Gate premium features (policy comparison, export, family sharing) | 2 days | ⭐⭐⭐⭐ |

### Week 3 — Retention Loops

| Action | Effort | Impact |
|--------|--------|--------|
| Push notification campaigns — weekly insurance tip, "Did your premium change?" check | 1 day | ⭐⭐⭐⭐ |
| Content feed — pull insurance literacy articles into the Home tab | 2 days | ⭐⭐⭐⭐ |
| Seasonal triggers — "It's monsoon season — review your flood cover" | 1 day | ⭐⭐⭐ |

### Week 4 — Acquisition

| Action | Effort | Impact |
|--------|--------|--------|
| Play Store listing optimization — keywords, screenshots showing citation badges | 1 day | ⭐⭐⭐⭐ |
| Shareable coverage summary — "Share my coverage" generates formatted text/image with app download link | 2 days | ⭐⭐⭐ |
| Referral program — "Add a family member to share policies" | 3 days | ⭐⭐⭐ |

### Ongoing — Analytics

| Action | Effort | Impact |
|--------|--------|--------|
| Track onboarding funnel — install → upload → first Q&A → return within 7 days | 1 day | ⭐⭐⭐ |
| Set up cohort analysis — D1, D7, D30 retention by acquisition source | 1 day | ⭐⭐⭐ |
| Monitor Sentry Issues daily — fix top crash by DAU impact | Ongoing | ⭐⭐⭐ |

---

## 📊 Health Score Estimate

| Dimension | Score | Notes |
|-----------|-------|-------|
| Technical quality | ⭐⭐⭐⭐⭐ | 700+ tests, Sentry, offline-first, encrypted |
| Product quality | ⭐⭐⭐ | Good depth, but buried behind friction |
| User experience | ⭐⭐ | Cold start is the killer. Empty-until-upload |
| Monetization | ⭐ | Not started |
| Retention | ⭐ | One-shot use case, no daily hooks |
| Acquisition | ⭐ | No ASO, no marketing, no referrals |
| Analytics | ⭐⭐ | Infrastructure exists, no data-driven decisions |

**Overall: Struggling but salvageable.** The technical foundation is unusually strong for a 6-month app. The problems are product and growth, not engineering.

---

## ⚠️ Supersession Notice (2026-07-29)

This analysis was prepared before [ADR-2026-07-29-02](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md) established the layered doctrine stack (Product Constitution → Wedge → Commercial Boundary → Feature ADRs).

### Findings that remain valid
- Cold start / comprehension-delay diagnosis (§1)
- One-shot use case / engagement challenge (§2)
- Monitoring/Sentry foundations (§6)
- Strong technical foundation ($700+ tests, offline-first, encrypted)
- Dashboard/comprehension-path friction framing

### Recommendations that are superseded or narrowed
- **Demo policy / sample policy** (Immediate section): Rejected as default onboarding solution. A read-only marketing-site example remains an experiment, not a strategy. See ADR-2026-07-29-02 §4.10.
- **Camera-first flow** (Immediate section): Rejected as the default onboarding path. Camera may remain an optional fallback for printed documents. See ADR-2026-07-29-02 §4.9.
- **Content feed / literacy articles** (Week 3): Not inside the product wedge (Gate C — education is not comprehension of own policies). Belongs on marketing site if pursued.
- **Seasonal triggers / "review your flood cover"** (Week 3): Must use evidence-state wording only (e.g., "flood coverage was not found in the uploaded policy — this is not proof it is excluded"). Never "not covered" from absence. See ADR-2026-07-29-02 §4.3.
- **Monetization pricing** (Week 2): Exact prices are Proposed hypotheses, not settled. See ADR-2026-07-29-02 §4.7.

### Governing documents

| Layer | Document |
|-------|----------|
| Product constitution | [`PRODUCT_FIRST_PRINCIPLES.md`](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) |
| Strategy & wedge | [`FIRST_PRINCIPLES_WEDGE.md`](../architecture/FIRST_PRINCIPLES_WEDGE.md) |
| Commercial boundary | [`FREE_VS_PAID_BOUNDARY.md`](../architecture/FREE_VS_PAID_BOUNDARY.md) |
| Reconciliation | [`ADR-2026-07-29-02`](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md) |

This audit's technical findings (cold start, engagement, retention) remain valid. Its product-strategy recommendations (demo, camera, literacy, monetization) are governed by the doctrine stack above.

Original audit text preserved unchanged. This supersession notice was added on 2026-07-29 per ADR-2026-07-29-02 Phase 7.

---

## Addendum (2026-07-29): Supersession status per recommendation

> This addendum is append-only. The original audit above is preserved unchanged as a historical analysis. This section classifies each recommendation against the now-proposed layered doctrine stack ([ADR-2026-07-29-02](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md); [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md)). The audit's *diagnostic* findings (cold-start friction, zero recurring engagement, no monetization, analytics blindness) remain valid observations; several of its *recommendations* are superseded.

### Recommendations — status

| Audit recommendation | Current status | Governing doctrine |
|----------------------|----------------|--------------------|
| **Camera-to-answer flow** (P0, "snap a policy page") | **Superseded as a default.** Reclassified as a strategy decision, not a permanent principle. Direct digital import is preferred; camera may remain an optional fallback. | [ADR-2026-07-29-02 §4.9](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md); [ADR-2026-07-28-reject-demo-mode](../decisions/ADR-2026-07-28-reject-demo-mode.md) |
| **Demo / sample policy** (implied cold-start fix) | **Rejected for launch.** A clearly-labelled read-only marketing-site/onboarding-preview example remains an experiment, not a constitutional violation. | [ADR-2026-07-29-02 §4.10](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md); [ADR-2026-07-28-reject-demo-mode](../decisions/ADR-2026-07-28-reject-demo-mode.md) |
| **Email-to-CoverWise / Share-sheet / auto-import** | **Valid strategy direction**, pending user evidence on which channels policies actually arrive through. Do not assert "most Indian policies arrive via X" without a source. | [ADR-2026-07-29-02 §4.9](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md) |
| **Freemium tiers + paywall + gating** | **Valid direction**, but exact limits/prices are Proposed, not settled. Move detail to [FREE_VS_PAID_BOUNDARY.md](../architecture/FREE_VS_PAID_BOUNDARY.md). | [ADR-2026-07-29-02 §4.6, §4.7](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md) |
| **Push campaigns / "Did your premium change?"** | **Renewal reminders valid** (factual dates only). "Premium change" prompts must use evidence-state wording, not imply advice. No "Start renewal" transaction. | [ADR-2026-07-29-02 §4.3, §4.5](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md) |
| **Content feed — insurance literacy articles in Home tab** | **Superseded.** Generic literacy content is outside the comprehension wedge (it does not help understand *the user's* policies). A contextual glossary tied to the user's own policy remains in scope. | [Product Constitution Principle 4](../planning/product/PRODUCT_FIRST_PRINCIPLES.md); [ADR-2026-07-29-02 §4](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md) wedge table (Glossary row) |
| **Seasonal triggers ("review your flood cover")** | **Valid as "coverage facts and verification prompts"** with evidence-state wording only. Never "you are not covered" from absence. | [ADR-2026-07-29-02 §4.3](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md) |
| **Play Store ASO, shareable coverage summary, referrals** | **Valid growth direction**, subject to launch-claim registry and the no-share rule for sensitive data. | [Product Constitution Principle 10, 11](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) |
| **Onboarding funnel + cohort analytics** | **Valid and in flight.** Analytics instrumentation is decision-enabling and not boundary-shaped. | [ANALYTICS_STRATEGY_2026-07-28.md](../analysis/ANALYTICS_STRATEGY_2026-07-28.md) |

### What remains valid in this audit

The diagnostic core — cold-start friction blocks comprehension, the product lacks recurring engagement hooks, monetization is unwired, analytics is blind — remains accurate and useful. Only the specific feature recommendations flagged above are superseded or narrowed. This audit must not be cited as authorization for camera-first, demo policy, or a literacy content feed.
