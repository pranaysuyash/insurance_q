# 02 — Project Reconstruction Report

**Bundle:** 2026-07-30-coverage-details-summary-share-gating
**Doc B (Part 0)** — current reality, documented intent, long-term vision, and scope classifications
**Author:** session-init agent
**Date:** 2026-07-30

---

## A. Current reality (what the project demonstrably does today)

- **Repo:** `medpiper/insurance_app` at `~/Projects/medpiper/insurance_app`, `main` branch.
- **Architecture:** Flutter mobile app (mobile/) + FastAPI Python backend (src/) + Supabase identity/persistence + RevenueCat billing + Sentry error capture.
- **Mobile stack:** Flutter, Riverpod, Hive (principal-scoped local storage), share_plus, supabase_flutter, sentry_flutter, flutter_secure_storage, app_links, dio, connectivity_plus.
- **Backend stack:** FastAPI app in src/ with extraction, RAG, mobile-specific routes. Production config: `rag-service-config-mumbai-v6-public-redis.json`. Build artifacts in dist-build/ or out/.
- **Headline product (working code):** CoverWise is a **Flutter mobile app** that lets users upload insurance policy PDFs (or photos), extracts structured fields, renders a coverage summary, and provides Q&A against the policy. Has 4-tab navigation with floating "Ask" FAB per Decision 5.
- **Mobile screens present and exercised:** Dashboard, DocumentsScreen, CoverageDetailsSummaryScreen, PolicyDetailScreen, QaScreen, Emergency, ClaimsAssistant, RenewalCalendar, CoverageGap, PolicyComparison, InsightsScreen, WhatIfCalculator, Profile, Settings, Help, Privacy, About, Family, FamilyVisualization, InsuranceCard, InsuranceLiteracy, Account, Splash, Onboarding, NotificationPreferences, ResetPassword, ClaimTracking, Search.
- **Entitlement system:** `mobile/lib/models/entitlement.dart` defines `PlanTier { free, plus, family }`, `PlanLimits` (with `allowExport` per tier), `Entitlement` (state of `planTier`, `expiresAt`, `questionsUsedThisMonth`, `packs`, `operationUsage`). Canonical gate logic lives at `entitlement_provider.dart:checkAction('export')` returning `null` or `'Export is available on Plus and Family plans.'` for the free tier.
- **Documentation surface:** docs/ has planning/product, architecture, decisions subdirectories. Multiple coverwise_*.md / coverwise_*.docx renamings artifacts at repo root. DECISION_LOG.md chronicles 5 logged decisions so far.
- **Status:** working-tree dirty on 10 mobile files + 5 repo-root files (mostly parallel-agent work). 456 insertions / 189 deletions across the mobile refactor.

## B. Documented intent (what current canonical docs say it should do)

- **motto_v4.md** treats the project as an *agent operating system* — defines doctrine, evidence tiers, decision gates, scope expansion control, parallel-editor hold. Sole allowed doctrine filename in the working tree.
- **Product Constitution (Proposed)** declares the irreducible loop: user-owned policy → consent → secure import → completeness-aware processing → source-preserving normalisation → evidence/uncertainty → plain-language explanation → organisation/retrieval → user verification → correction/export/replacement/retention/deletion. Twelve non-negotiable principles (policy is authoritative; verifiability is the product; abstention is a valid outcome; explain-don't-advise; one principal owns one graph; consent is enforced behaviour; feature = end-to-end workflow; one canonical path per truth; reliability at moment of need; business model aligns with trust; every public claim is operational contract; long-term thinking ≠ maximalism).
- **First-Principles Wedge (Proposed, subordinate to constitution)** consolidates the wedge: owned policy → secure import → evidence-backed workspace → source-verifiable explanation and Q&A → neutral organisation → factual reminders/emergency retrieval → personal notes/document lifecycle. Each surface has an allowed contract and forbidden interpretation.
- **Free vs Paid Boundary (Proposed)** classifies features into 🧠 Comprehension (free baseline), ⚡ Convenience (paid candidate), 🔬 Depth (paid candidate). Detailed per-feature analysis included.
- **DECISION_LOG.md** carries 5 settled decisions: P0-2 Executive Summary Card, P0-3 Streaming QA Answers, P0-4 Dynamic More Screen, Nav Restructure (5 → 4 tabs + FAB), P0-2 again (restated; one was approved twice — read both for nuance). P0-1 Direct-to-camera was deferred per first-principles.
- **DESIGN.md** locks visual direction: ink/blue/mint/cloud/line tokens, calm document-first hierarchy, signature = explicit verification state on every generated answer.

## C. Long-term vision (what the project is intended to become)

> *A private, source-verifiable personal insurance knowledge workspace that helps people understand and organise policies they already own. It reports what the uploaded policy workspace establishes, what it does not establish, and where each material fact comes from. It does not recommend, quote, underwrite, broker, transact, or represent claims.*

This phrasing is from the proposed constitution's §1. The wedge is intended to be the durable shape; speculative features (what-if, advisor marketplace, lead capture, demo policy as default onboarding) are explicitly *outside*. The wedge may be re-scoped on evidence. The constitution survives renames.

For this workstream, the relevant long-term promise is:

> *User can navigate to the coverage summary screen, tap share, and receive an accurate gate experience that respects their actual plan (free / plus / family).*

The share gate is a **user-visible trust surface** — it's where the user discovers "oh, the app knows my plan, and tells me honestly what's gated." Failing this surface means the user gets silent denials or silent unlocks.

## D. Implemented scope

- **Entitlement-gated share on Coverage Details Summary Screen** — fully implemented. Test exists in `mobile/test/coverage_details_summary_screen_test.dart` for three tiers + three PlanLimits invariants.
- **`buildCoverageShareText(PolicySummary)`** — extracted as a module-level function in the same screen file; unit-tested independently by `mobile/test/coverage_share_text_test.dart`.
- **`EntitlementNotifier.checkAction('export')`** — implemented and exercised by `mobile/test/entitlement_test.dart`.
- **`CoverWiseSnackBar.warning(context, message, actionLabel: 'Upgrade', onAction: ...)`** — implemented and tested in `mobile/test/coverwise_snackbar_test.dart`.
- **Plan-gate boundary in `planLimits` map** — single canonical truth table; immutable.

## E. Partial scope

- **Coverage Details Summary deep-link route** — not registered in `main.dart`'s named routes map. The screen is reached only via direct `MaterialPageRoute` pushes from `dashboard_screen.dart` and `policy_detail_screen.dart`. This is intentional: the screen takes a `PolicySummary` object as a constructor arg, not a `documentId` string. Adding a deep-link route would require an argument contract decision (e.g. documentId → fetch summary).
- **In-flight auth/workspace refactor** — covers 10 mobile files, 456+/189- lines. The parallel agent's diff (visible in `git diff`) shows: reorganised auth state, defensive date parsing, principal-key DEK hardening, pubspec bumps, widget_test changes. Cannot land this workstream's verification until this refactor lands or the auth_service.dart blocked line gets fixed.
- **Constitution + ADR-2026-07-29-02 sign-off** — *Proposed, awaiting operator sign-off*. Until signed, doctrine hierarchy is directional only.

## F. Planned scope

- None of the in-scope work for this brief touches new surface plans. Mechanical alignment of one test against one canonical gate.

## G. Contradictory scope

- **`CoverageDetailsSummaryScreen` is not in `main.dart`'s `routes:` map** — only reachable via direct pushes. Future deep-link extension would need an argument contract decision.
- **`EntitlementNotifier.checkAction` intermixes "expired" branch with per-action branches** — design wart, not a contradiction per se but a potential future-proofing issue.
- **The 2026-07-23 UX audit's P0-1 (direct-to-camera) is in `DECISION_LOG.md` Decision 1 as "Defer P0-1" but the audit addenda of 2026-07-29 reclassify it as "rejected as default; optional fallback allowed"**. The Decision Log entry is too brief to be self-explanatory; read the addenda for the precise supersession reasoning.
- **`planLimits[PlanTier.plus].allowExport = true` but `PlanTier.free.allowExport = false`** — the gate-reason string `'Export is available on Plus and Family plans.'` matches the test's `find.textContaining('Export is available on Plus')` substring; this is consistent but worth noting because **substring assertions are looser than exact-match assertions** and could pass even if the canonical copy drifted.

## H. Obsolete scope

- The 2026-07-23 audit's P0-P3 recommendations for camera-first, demo policy, what-if calculator, advisor marketplace, claim assistant v1 are explicitly superseded by `motto_v4.md`'s 2026-07-29 addenda and the proposed constitution P4. They are not authoritative. Out of scope for this workstream.

## I. Unknown scope

- Whether ADR-2026-07-29-02 (and the proposed constitution) has been *signed off* by the operator as of 2026-07-30. Docs still read *Proposed, awaiting operator sign-off.* Status changes may shift downstream recommendations.
- Whether the parallel agent's refactor has additional commit-units staged that resolve the auth_service.dart `createdAt` type-mismatch. The visible diff shows the defensive parse form intended; whether it lands soon is unknown.
- Whether the operator intends this workstream to *also* add new test coverage (e.g. add an `expired-plan` test case, an `ownership-loss` test case, a `snackbar-dismiss` test case) — the IDE-open file is `coverage_details_summary_screen_test.dart`, which is suggestive but ambiguous. Default assumption: WS-2 was scoped to existing test contracts; new test cases are out of scope unless the operator says otherwise.

---

## Anything else? (motto §0.1.1)

The 2026-07-29 addenda on the UX audit explicitly limit the role of legacy audit recommendations, which is a healthy doctrine-stack-in-action signal: an earlier recommendation got walked back on better evidence, and the doc reflects that. Future readings of this bundle should treat the `UX_AUDIT_FIRST_PRINCIPLES.md` addendum dates (2026-07-29) as authoritative.
