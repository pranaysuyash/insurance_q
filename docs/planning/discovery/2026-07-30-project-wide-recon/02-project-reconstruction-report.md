# 02 — Project Reconstruction Report (Project-Wide)

**Bundle:** 2026-07-30-project-wide-recon
**Doc B (Part 0)** — current reality, intent, vision, scope classifications
**Author:** session-init agent
**Date:** 2026-07-30

---

## A. Current reality (what the project demonstrably does today)

- **Repo:** `medpiper/insurance_app` at `~/Projects/medpiper/insurance_app`, `main` branch. Head commit: `f941f13 feat: land CoverWise product and analytics foundation`.
- **Stack (live code, not docs):**
  - **Mobile:** Flutter 3.x, Dart `>=3.0.0`. Riverpod state. Hive local cache (principal-scoped encrypted). share_plus, supabase_flutter, sentry_flutter, app_links, connectivity_plus, dio. `flutter_test` test pyramid, `mobile/test/` contains ~80+ test files (per `README.md` 636 passing in full suite, per `coverwise_native_mobile_platform_store_readiness_audit_2026-07-21.md` rephrased 2026-07-29).
  - **Backend:** Python 3.11+ FastAPI in `src/`. Uvicorn / Starlette. SQLAlchemy + Alembic migrations in `supabase/`. PyJWT (HS256) for anonymous tokens. OpenAI SDK with conditional gpt-5+ kwargs handling. RAG pipeline with retrieval_text / source_text separation.
  - **Persistence / identity / sync:** Supabase Postgres, pgvector extension, Supabase Storage (private buckets). Schema migrations in `supabase/migrations/` (e.g., `2026_07_18_revops_tables.sql`, `2026_07_18_evidence_substrate.sql`).
  - **Auth:** Bearer token (anonymous HS256 JWT). Operator gating via shared-secret `X-Operator-Token` for Phase 0; full RBAC deferred.
  - **Billing:** Dodo Payments primary + Razorpay secondary (per retro-Decision 2026-07-18-03). `mobile/lib/services/billing_adapter.dart` routes by currency/method.
  - **Observability:** Sentry client. Analytics Service (Riverpod notifier) → buffered events → Supabase dual-write tables. Operator dashboard views (3 dashboard views per RevOps R1).
  - **CI/CD:** `.github/workflows/ci.yml` (modified).
  - **Native build:** `mobile/build/` outputs are gitignored, current build removed per README §🚀 Deployment.
- **Mobile screens (live, exercised):** Dashboard, DocumentsScreen, CoverageDetailsSummaryScreen, PolicyDetailScreen (~1,439 lines god-object per audit, currently rendered in file at 935 lines), QaScreen, Emergency, ClaimsAssistant, RenewalCalendar, CoverageGap, PolicyComparison, InsightsScreen, WhatIfCalculator (constitutionally out-of-scope but on disk per retro-ADR), Profile, Settings, Help, Privacy, About, Family, FamilyVisualization, InsuranceCard, InsuranceLiteracy, Account, Splash, Onboarding, NotificationPreferences, ResetPassword, ClaimTracking, Search.
- **Working-tree state:** dirty on 15+ files (10 in `mobile/`, 5 in repo root) — all pre-existing parallel-agent work. New since session start: 10 files in `docs/planning/discovery/2026-07-30-coverage-details-summary-share-gating/` + `Decision 7` appended to `DECISION_LOG.md`. This project-wide bundle is being written now.
- **Test counts:** README claims 378 backend tests + 636 Flutter tests, "All tests passing." `strategic_assessment_2026-07-17.md` (Buffy) flags 6 dismissed "pre-existing" test failures (some real, some attributed to "timeout" without investigation).
- **Document volume:** `docs/` contains 50+ markdown files: audits, planning, deployment, technical, research, evaluations, regulatory.

## B. Documented intent (what current canonical docs say it should do)

- **motto_v4.md** defines the agent operating system: doctrine hierarchy, evidence tiers, decision-record rules, acceptance contract, parallel-editor protocol.
- **Proposed Product Constitution** defines the irreducible loop and gates A–E: owned policy → consent → import → completeness-aware processing → source-preserving normalisation → evidence/uncertainty → plain-language explanation → organisation/retrieval → verification → correction/export/replacement/retention/deletion.
- **First-Principles Wedge** names the durable product shape: owned policy → secure import → evidence-backed workspace → source-verifiable explanation and Q&A → neutral organisation → reminders/emergency retrieval → personal notes/document lifecycle.
- **Free vs Paid Boundary** classifies features into 🧠 Comprehension (free baseline), ⚡ Convenience (paid candidate), 🔬 Depth (paid candidate).
- **Per-feature ADRs** govern specific decisions (40+ in `docs/decisions/`).
- **Strategic Assessment 2026-07-17** says what's well-done (PolicyDetailScreen, durable architecture, privacy-first design, test infrastructure, documentation as first-class) and what's badly-broken (test-to-code ratio low, 6 dismissed test failures, backend granularity mismatch, scope bloat, no retry, no offline emergency data).
- **Naming process 2026-07-28** produced "CoverWise" as final choice (founder redirects captured verbatim). Documented in `docs/planning/naming/`.
- **UX Audit 2026-07-23** lists P0/P1/P2/P3 priorities but is partly superseded by the 2026-07-29 addenda.

## C. Long-term vision (what the project is intended to become)

> CoverWise is a private, source-verifiable personal insurance knowledge workspace that helps people understand and organise policies they already own. It reports what the uploaded policy workspace establishes, what it does not establish, and where each material fact comes from. It does not recommend, quote, underwrite, broker, transact, or represent claims.

The durable user outcome is **comprehension** — understanding and organising policies the person already owns. The wedge is the durable product shape. The constitution survives renames.

For project-scope Parts 8 (Scorecard) and 16 (Final Delivery), the *long-term vision* drives the scorecard: every project-wide quality dimension must serve this outcome or be cut.

## D. Implemented scope (project-wide)

- **Flutter mobile app** with offline-first local storage, principal-scoped encryption, consent ledger, upload + processing UI, policy detail / executive summary, Q&A (streaming SSE), comparison (neutral, no winner), coverage gaps with resolution tracking, family coverage organisation, personal claim log, renewal calendar, what-if *calculator on disk but constitutionally out-of-scope*, emergency screen, claims assistant (narrowed to process/contacts per ADR-2026-07-29-02 §4.4), insurance card, insurance literacy quiz.
- **Backend RAG pipeline** with OCR/PDF extraction, structured-field extraction (13 fields per `PolicySummaryExtraction`), retrieval-augmented Q&A with citation enforcement, evidence substrate (4 immutable tables per retro-Decision 2026-07-18-06), LLM honesty check per retro-Decision 2026-07-18-07.
- **Anonymous HS256 JWT auth** with future migration path to real auth. Principal-scoped encrypted Hive boxes per retro-Decision 2026-07-19-06. Operator RBAC deferred (shared secret Phase 0).
- **Dodo + Razorpay billing** with entitlement registry (`PlanLimits`) and operation-cost attribution.
- **Operator dashboards** (3 views per RevOps R1) backed by Supabase analytics tables.
- **Documentation corpus** (40+ ADRs, 50+ docs) including doctrine stack, naming, audits, decision records.
- **CI** in `.github/workflows/ci.yml`.

## E. Partial scope (project-wide)

- **Constitution + ADR-2026-07-29-02 sign-off** — *Proposed, awaiting operator sign-off.* Highest-impact unblocked item.
- **Six "pre-existing" test failures** dismissed in 2026-07-17 strategic assessment — including one likely real (gapId refactor) and three timeouts without root-cause analysis.
- **Backend granularity mismatch** between ProcessingStatusScreen's 5 sub-stages and backend's 3 states — known issue, not yet fixed.
- **No upload retry mechanism** — Indian mobile networks.
- **No offline emergency card cache.**
- **What-If Calculator on disk but constitutionally out of scope** — the wedge and constitution have rejected this; the code still exists (per `manhattan-style tear-down` audit, line 311 of `docs/review/exploration_map.md` lists this for removal).
- **`legal_risk_copy_audit_2026-07-24.md`** flagged 83 files / 1,793 lines; `legal_risk_remediation_priority_2026-07-25.md` and `legal_risk_remediation_2026-07-25.md` exist; remediation status not visible.
- **Hindi localization (`app_hi.arb`)** referenced but not deeply audited.
- **`AGENTS.md`** missing.
- **iOS App Store deployment** — Android APK ready; iOS sign-off pending.
- **Multi-language support** — listed as P2 roadmap item per README.
- **Multi-region deployment** — listed as P2 roadmap item per README.

## F. Planned scope (project-wide)

- **CoverWise naming**: locked at "CoverWise" per the 2026-07-28 founder decision (Tippani, Amanat, Kosha rejected by founder redirects). Documented at `docs/planning/naming/`.
- **Long-term surface extensions**: per retro-Decision 2026-07-19-08 + ADR-2026-07-19-XX family — Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault, Partnerships framework. Each has substrate-extension ADR + privacy/data-handling policy ADR. Current implementation status varies; the substrate extensions are mostly Proposed; the privacy/policies are Accepted.
- **RevenueCat primary integration** — README claims Dodo primary, but `mobile/lib/providers/entitlement_provider.dart` and `BillingAdapter` show RevenueCat integration patterns. Stage 2 of billing migration pending.
- **Backend subscription sync endpoint** — mentioned as a roadmap item.
- **Multi-language** — P2.
- **Real billing integration** — claimed partial; current code uses stubbed/staged integrations per `coverwise_revops_system_2026-07-18.md`.

## G. Contradictory scope (project-wide)

- **Strategic Assessment 2026-07-17** says scope is "too big" — recommends cut from 32→15 screens. Audit adenda 2026-07-29 leave the product-expansion recommendations superseded, but the engineering observation (god-objects, repetitive copy) remains valid.
- **Doctrine stack reconciliation status**: constitution, wedge, commercial boundary, ADR-2026-07-29-02 all read "Proposed." Self-declared "Accepted" without sign-off (per ADR-2026-07-29-02 §1 inventory table) is a known contradiction.
- **Hero copy "evidence-backed" / "grounded"** — content audit 2026-07-19 flags as jargon. Legal-risk audit 2026-07-24 flags 14 categories of copy risk across 83 files.
- **Backend granularity mismatch** between 5-stage frontend and 3-state backend (Buffy §2.3) — frontend simulates progression.
- **`claim_assistance_screen.dart`** carries "grounded" + "substrate" + "parser pipeline" jargon per content audit; IRDAI mention buried in step 5/5.
- **What-If Calculator**: on disk but constitutionally out of scope (Gate C rejection). Code lives; product-disagreement-with-code.
- **README** preserves a June 2025 AWS deployment snapshot that does not match the current Cloud Run target. README itself flags this as preserved-historical.

## H. Obsolete scope (project-wide)

- **AWS deployment scripts** (`aws_deployment.sh`, `aws_ecs_simple.sh`, `aws_migration_complete.md`): preserved-historical per README. Live target is Cloud Run (`tools/deploy_cloud_run.sh`).
- **`docs/archive/deployment/`** — historical deployment records per ADR-2026-07-29-02 inventory.
- **The company-era AWS App Runner URL** in README — preserved for historical record; current production target is different.
- **"Out of date" labeled items in `REPO.md`** (per Buffy): the 2026-07-17 strategic assessment enumerates ~20 stale planning docs.

## I. Unknown scope (project-wide)

- **Constitution / ADR-2026-07-29-02 sign-off status** as of 2026-07-30 — still read "Proposed, awaiting operator sign-off."
- **Whether tests that were "passing" at README commit time are still passing** — Buffy's strategic assessment dated 2026-07-17 reported 6 dismissed failures; not re-verified in this session.
- **iOS App Store deployment** — README claims APK ready, iOS pending; iOS-specific blockers invisible to this session.
- **Live backend deployment** — README §"Launch status" claims "not yet deployed for customer use"; not visible to this session.
- **Live analytics events** — instrumentation exists but content not sampled.
- **Current launch claim registry status** — referenced in `motto_v4.md` §0.11.1 and ADR-2026-07-19-09; the actual registry file's state unknown to this session.
- **Whether the 14 ADR-2026-07-19-XX additions are still implemented** — substrate extensions + privacy/data-handling policies. Code state in `mobile/lib/models/policy_summary.dart` shows 6 type-specific field groups (motor, travel, life, home, health, marine) + 3 deferred (cyber, liability, pet). 4 × family/check-in/adequacy/vault substrate extensions not directly visible in this screen file.

---

## Anything else? (motto §0.1.1)

The project's documentation-to-code ratio is healthy: decisions are recorded, audits surface gaps, naming/billing/product decisions have ADRs. The biggest *gaps* are operational: 6 test failures without root-cause analysis, doctrine stack unratified, scope-vs-screens mismatch, backend/frontend state-granularity mismatch. The discovery documents that follow (03-09) attempt to capture these systematically.
