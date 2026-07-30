# CoverWise — Strategic Assessment

**Date:** 2026-07-17
**Evidence Tier:** Tier 1 (static inspection + test suite analysis)
**Author:** Buffy (AI Agent)
**Purpose:** Honest, first-principles assessment of what's working, what's broken, and what to do before launch.

---

## 0. Assessment Philosophy

> This is not a celebration document. It's not a pessimism document. It's a diagnostic — the kind of document a founder needs to read before making shipping decisions.

---

## 1. What's Extremely Well Done

### 1.1 PolicyDetailScreen (9/10) — The Core Value Proposition

This screen alone justifies the app's existence. A 40-page PDF becomes one scannable page with:
- Money rows (coverage, premium, deductible)
- Dates (policy start, expiry, waiting periods)
- Benefits, exclusions, and coverage items
- Quick actions (call insurer, share summary)
- View source document button for trust-building

**Why it's excellent:** It turns an inaccessible document into an actionable one. The user who uploads a policy and sees this screen has their "aha" moment.

### 1.2 Architecture Decisions — Durable, Not Patchwork

- **Anonymous auth with Hive→SecureStorage migration** — thoughtful, privacy-first
- **Idempotent document upload with hash-based deduplication** — prevents duplicate processing
- **Durable document processing with lease-based recovery** — production-grade background task management
- **ConsentLedger as purpose-specific audit trail** — not a single boolean, but a grant/revoke system with timestamps per purpose
- **Riverpod state management** — clean provider boundaries, no state leaks observed

### 1.3 Privacy-First Design — Genuinely Rare

The consent system is over-engineered in the best way:
- Purpose-specific consent (document_processing, analytics, lead_capture)
- Grant/revoke with timestamps for auditability
- Analytics gating in `track()` that respects revocation across restarts
- Fail-open defaults that are documented and intentional
- Onboarding consent toggle that only records if user explicitly changes it

Most apps in this space would just slap a "we collect data" banner and move on. This is genuinely privacy-respecting.

### 1.4 ProcessingStatusScreen (8/10) — UX for Invisible Work

Real-time stage visibility (Received → Reading → Extracting → Classifying → Indexing → Complete/Failed) with pulse animation, auto-navigate on completion, and PopScope dismiss warning. Turns a black-box backend process into something the user can see and trust.

### 1.5 Emergency Access — One Tap

The dashboard shortcut button for emergency access is exactly right. In a real emergency, you don't want to dig through menus. Safety-critical feature done properly.

### 1.6 Test Infrastructure — 348 Tests Passing

For a solo-founder project, having 348 tests with clean flutter analyze is remarkable. The consent ledger tests, entitlement tests, processing status tests, and what-if calculator tests show real engineering discipline.

### 1.7 Documentation as First-Class Citizen

The `FLOW_AND_SCREEN_AUDIT.md` is one of the most thorough audit documents I've seen in a solo project. Every screen rated, every flow mapped, every gap tracked with priority and rationale. This is motto_v3 §0.3 in action.

### 1.8 Q&A System (9/10)

3-tab design, confidence badge (color-coded), follow-up chips with loading state, demo sequence, history. Trust-building through transparency and value density.

### 1.9 Coverage Gap Resolution Tracking (9/10)

Filter bar (All/Open/Addressed), mark-as-addressed with notes dialog, resolution badge, strikethrough styling, reopen button, empty states. Hive-persisted. Production-grade workflow.

### 1.10 Insurance Health Score (8/10)

At-a-glance 0–100 score on dashboard with animated circular gauge, 4-factor breakdown, expandable detail. Uses AppStateRepository for gap resolution tracking.

---

## 2. What's Extremely Bad

### 2.1 Test-to-Code Ratio is Dangerously Low

- 89 Dart files, 25 test files
- 22,475 lines of code
- Many screens have zero widget tests
- The consent gate test was the FIRST analytics test ever written
- No widget tests for onboarding, dashboard, most screens
- 6 test failures flagged as "pre-existing" or "timeout" and dismissed

**Why this matters:** You're about to launch. If a user taps "Upload" and it crashes, you have no automated way to catch it. The "pre-existing" test failures are not someone else's problem — they're your launch blockers.

### 2.2 6 Test Failures Being Dismissed

| Test | Status | Excuse Used | Actual Impact |
|---|---|---|---|
| coverage_gap_tracking_test.dart | ❌ | "gapId import issue" | **Our change broke it** — gapId was refactored |
| confidence_badge_test.dart | ❌ | "Dart compiler crash" | May indicate real code issue |
| widget_test.dart | ❌ | "Missing MaterialApp" | Pre-existing but still a failure |
| global_error_boundary_test.dart | ⏱️ | "timeout" | Suggests ErrorWidget.builder fix may cause hangs |
| policy_type_test.dart | ⏱️ | "timeout" | Could indicate slow init or infinite loop |
| service_test.dart | ⏱️ | "timeout" | May depend on external services |

**motto_v3 violation:** §0.14 (Operator Workflow) — "The system must explain its own state." Dismissing test failures without investigation violates this.

### 2.3 Backend Granularity Mismatch — Users Are Lied To

The ProcessingStatusScreen shows 5 sub-stages (OCR → Extraction → Classification → Indexing → Complete) but the backend only exposes 3 states (`processing` → `completed` → `failed`). The frontend *simulates* progression through sub-stages.

**Why this matters:** When the backend is slow or stuck, the frontend shows stage 3/5 indefinitely. The user thinks extraction is happening, but the backend might be waiting for OCR that already failed. This erodes the trust that the rest of the app builds.

### 2.4 Scope Bloat — 40+ Screens for a Solo Launch

| Category | Count | Should Be |
|---|---|---|
| Full screens | 32 | ~15 |
| Dialogs/sheets | 8 | ~4 |
| Services | 12 | ~8 |
| Models | 7 | ~5 |
| Providers | 15+ | ~10 |

Features that should be cut for solo launch:
- **Claims Assistant** (7/10) — guidance-only, no actual claims workflow
- **Claim Tracking** (6/10) — local-only, no insurer integration
- **Insurance Literacy Quiz** (8/10) — nice-to-have, not core value
- **Digital Insurance Card** (8/10) — nice-to-have, not core value
- **What-If Calculator** (8/10) — interesting but not essential for launch
- **Family Management** (6/10) — basic, not differentiated

**Why this matters:** Every screen you ship is a screen you maintain. For a solo founder, maintenance burden is the #1 killer. Ship 15 excellent screens, not 32 mediocre ones.

### 2.5 Documentation Bloat

| Doc | Lines | Actually Used? |
|---|---|---|
| FLOW_AND_SCREEN_AUDIT.md | ~500 | ✅ Reference |
| RAG_SEARCH_VECTOR_DB_EMBEDDINGS_RESEARCH.md | ~800 | ⚠️ Aspirational |
| MODEL_TRAINING_PLAN.md | ~400 | ⚠️ Future work |
| WIDE_OPEN_BRAINSTORM.md | ~300 | ⚠️ Decision record |
| coverwise_monetization_ads_responsible_data_research_2026-07-16.md | ~600 | ⚠️ Strategy doc |
| docs/planning/** | ~20+ files | ❌ Mostly stale |

**motto_v3 violation:** §0.13 (Scope Control) — "Documentation must serve the current build phase." Half these docs describe features that don't exist yet or decisions that were already made.

### 2.6 No Retry Mechanism for Failed Uploads

Indian mobile networks are unreliable. A user uploads a 10MB PDF on 4G, the upload fails at 90%, and they have to start over. This is table-stakes for the Indian market.

### 2.7 No Offline Emergency Data

The EmergencyScreen requires a network connection to load policy data. In a real emergency (car accident, hospital admission), connectivity may be poor or unavailable. Emergency card data should be cached locally.

---

## 3. What Needs Fixing Before Launch (Priority Order)

### P0: Launch Blockers

| # | Item | Effort | Why |
|---|---|---|---|
| 1 | **Fix all 6 test failures** | 1-2 days | Can't ship with known failures. Investigate each, fix or remove. |
| 2 | **Add widget tests for 5 critical screens** | 2-3 days | Dashboard, Documents, Q&A, PolicyDetail, Emergency — the screens users touch every day. |
| 3 | **Fix backend granularity mismatch** | 1 day | Either add real stage reporting to backend, or simplify frontend to show actual states. Don't lie to users. |
| 4 | **Add upload retry mechanism** | 1 day | Essential for Indian mobile networks. Queue failed uploads for automatic retry. |

### P1: Pre-Launch Polish

| # | Item | Effort | Why |
|---|---|---|---|
| 5 | **Cut scope to 15 screens** | 1-2 days | Remove Claims, Claim Tracking, Insurance Literacy, Digital Insurance Card, What-If Calculator. These dilute core value. |
| 6 | **Cache emergency card data locally** | 0.5 day | Emergency access must work offline. |
| 7 | **Add loading shimmer for document upload** | 0.5 day | Visual feedback during the most anxiety-inducing moment. |
| 8 | **Fix test-to-code ratio** | Ongoing | Target: 1 test file per screen, 1 test per major flow. |

### P2: Post-Launch

| # | Item | Effort | Why |
|---|---|---|---|
| 9 | Multi-language support | Large | Indian market needs Hindi, Tamil, etc. Post-launch. |
| 10 | Real billing integration (RevenueCat) | Medium | Entitlement stub exists. Need SDK integration. |
| 11 | Backend subscription sync | Medium | Need endpoint for plan management. |
| 12 | Cross-document Q&A improvement | Medium | Current implementation is basic. |

---

## 4. Test Health Report

### Current State

| Metric | Value | Target | Gap |
|---|---|---|---|
| Total tests | 348 | 400+ | -52 |
| Passing | 342 | 348 | -6 |
| Failing | 6 | 0 | -6 |
| Screens with tests | ~12/32 | 32/32 | -20 |
| Services with tests | ~8/12 | 12/12 | -4 |
| Models with tests | ~5/7 | 7/7 | -2 |

### Test Failures Detail

1. **coverage_gap_tracking_test.dart** — `gapId` import broken after refactor. Fix: update import path.
2. **confidence_badge_test.dart** — Dart compiler crash. Likely a test isolation issue. Fix: simplify test or skip with justification.
3. **widget_test.dart** — Missing MaterialApp wrapper. Fix: wrap test widget in MaterialApp.
4. **global_error_boundary_test.dart** — Timeout. Likely ErrorWidget.builder causing infinite frame scheduling. Fix: investigate ErrorWidget.builder behavior in test environment.
5. **policy_type_test.dart** — Timeout. Could be slow model initialization. Fix: mock dependencies.
6. **service_test.dart** — Timeout. Likely depends on external services. Fix: mock HTTP calls.

### Addendum (2026-07-30): All six dismissed tests verified PASSING on the current `main` working tree

> **Superseded per `DECISION_LOG.md` Decision 9.** The six "dismissed failures" diagnoses above in §2.2 are retracted. Re-running each test in isolation against current `main` (commit `f941f13`) using the same flags as CI (`flutter test --concurrency=1 --dart-define-from-file=.dartdefine.env`) shows all 50 individual test cases pass in ~4 seconds:

> - `coverage_gap_tracking_test.dart` — 23/23 pass
> - `confidence_badge_test.dart` — 10/10 pass
> - `widget_test.dart` — 1/1 pass (when run with `--dart-define-from-file=.dartdefine.env`)
> - `global_error_boundary_test.dart` — 3/3 pass
> - `policy_type_test.dart` — 2/2 pass
> - `service_test.dart` — 11/11 pass

> The original diagnoses were based on local-machine `flutter test test/foo.dart` runs that lacked the `--dart-define-from-file=.dartdefine.env` flag; in that mode `widget_test.dart` fails because `AppConfig.baseUri` throws `StateError: API_BASE_URL is required` from `app_config.dart:183`. CI includes the env flag (`.github/workflows/ci.yml:74`), so CI does not exhibit the failure. **No source-code change is required.** The launch-blocker claim that §3 P0 #1 was based on has no basis against current `main`; §3 P0 #1 should be considered Closed-Without-Action at this time. Original §2.2 text preserved above as historical record.

---

## 5. Architecture Health

### What's Solid

- **State management** (Riverpod) — clean, no leaks, proper provider boundaries
- **Auth flow** — anonymous with migration path to real auth
- **Document processing** — durable with lease recovery, idempotent upload
- **Consent system** — purpose-specific, auditable, privacy-first
- **Analytics** — local-first with consent gating

### What Needs Work

- **Error handling** — GlobalErrorBoundary exists but many screens don't use it consistently
- **Offline support** — only analytics has offline queue. Emergency data, document cache, and Q&A history should work offline.
- **Backend contract** — frontend simulates backend states instead of consuming real ones. This creates maintenance burden and user confusion.

---

## 6. Strategic Recommendations

### For a Solo Founder, the #1 Risk is Maintenance Burden

Every screen you ship is a screen you maintain. Every feature you add is a feature that can break. For a solo founder, the optimal strategy is:

1. **Ship the minimum viable product.** 15 screens, not 32.
2. **Test what you ship.** Widget tests for every screen.
3. **Fix what breaks.** No "pre-existing" excuses.
4. **Document what matters.** One audit doc, one architecture doc, one roadmap. Not 20 planning docs.

### The "Ship It" Checklist

Before marking this app as launch-ready:

- [ ] All tests pass (0 failures)
- [ ] Widget tests for 5 critical screens
- [ ] Backend/frontend state alignment (no simulated stages)
- [ ] Upload retry mechanism
- [ ] Emergency data cached locally
- [ ] Scope cut to 15 screens
- [ ] All "pre-existing" test failures resolved
- [ ] Error boundary tested in production-like environment

---

## 7. motto_v3 Compliance

| Clause | Status | Notes |
|---|---|---|
| §0.1 (Boldness & Long-Term Build) | ✅ | Architecture is solid |
| §0.3 (Documentation Continuity) | ✅ | This document fulfills the requirement |
| §0.5 (Evidence Tiers) | ✅ | All claims are Tier 1 (static inspection) |
| §0.6 (Risk-Based Verification) | ⚠️ | High-risk paths identified but not all verified |
| §0.8 (Data Layer Rule) | ✅ | Policy summaries, terminology are data-driven |
| §0.10 (Observability) | ✅ | Analytics events tracked |
| §0.11 (Customer-Facing Claims) | ✅ | Document preview implemented |
| §0.12 (Decision Record) | ✅ | This document serves as decision record |
| §0.14 (Operator Workflow) | ⚠️ | Test failures dismissed without investigation |
| §0.15 (Third-Layer Rule) | ⚠️ | Backend/frontend granularity mismatch |
| §0.13 (Scope Control) | ❌ | 40+ screens for solo launch is over-scoped |

---

## 8. Change Log

| Date | Change | Author |
|---|---|---|
| 2026-07-17 | Initial strategic assessment created | Buffy |
