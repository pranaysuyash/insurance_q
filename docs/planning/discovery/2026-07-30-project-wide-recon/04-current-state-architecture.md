# 04 — Current-State Architecture (Project-Wide)

**Bundle:** 2026-07-30-project-wide-recon
**Doc D (Part 0)** — system map for the CoverWise project at project scope
**Author:** session-init agent
**Date:** 2026-07-30

---

## A. Component inventory (project-wide)

### A.1 Mobile layer (`mobile/`)

- **Framework:** Flutter 3.x with Dart `>=3.0.0`. Material 3. Custom `CoverWiseTheme` with design tokens from `DESIGN.md`.
- **State management:** Riverpod 2.x with `Notifier` and `FutureProvider` patterns.
- **Local persistence:** Hive with principal-scoped AES encryption (JWT-derived key, per retro-Decision 2026-07-19-06).
- **HTTP client:** Dio with custom `AuthInterceptor` for bearer-token acquisition.
- **Identity:** Supabase Auth client + anonymous HS256 JWT (PyJWT-derived).
- **Connectivity:** `connectivity_plus`.
- **Deep links:** `app_links`.
- **Crash reporting:** Sentry Flutter (`sentry_flutter`).
- **Local notifications:** `flutter_local_notifications` for renewal reminders.
- **OS share:** `share_plus`.
- **Storage encryption:** `flutter_secure_storage`.
- **Mobile screens (all paths under `mobile/lib/screens/`):** dashboard, documents, coverage_details_summary, policy_detail, qa, emergency, claims_assistant, renewal_calendar, coverage_gap, policy_comparison, insights, what_if_calculator, family, family_visualization, insurance_card, insurance_literacy, account, splash, onboarding, notification_preferences, reset_password, claim_tracking, search, profile, settings, help_support, privacy_security, about.
- **Services (selected, paths under `mobile/lib/services/`):** auth, app_state_repository, app_state_store, local_storage_service, document_service, notification_service, install_service, principal_key_service, hive_workspace_service, on_device_inference_service, analytics, claims_sync_service, consent_sync_service, billing_adapter, entitlement, document_service.
- **Providers (selected, paths under `mobile/lib/providers/`):** auth, document, policy, entitlement, billing, analytics, locale, theme.
- **Models (selected, paths under `mobile/lib/models/`):** policy_summary (1,595 lines), entitlement, operation_cost, qa_pack, reset_password_args.
- **Widgets:** Shared (`coverwise_components.dart`, `coverwise_theme.dart`, `coverwise_motion.dart`, `coverwise_snackbar.dart`, `global_error_boundary.dart`, `screen_error_boundary.dart`), specialized (`field_citations_card.dart`, `not_yet_extracted_section.dart`, `coverwise_*_badge.dart`).
- **L10n:** `mobile/lib/l10n/app_localizations_gen.dart`, `app_en.arb`, `app_hi.arb`.
- **Tests:** `mobile/test/` — ~80+ files; Flutter widget + unit; `flutter analyze --no-fatal-infos` clean (per README), but 6 failures dismissed per Buffy.

### A.2 Backend layer (`src/`)

- **Framework:** FastAPI on Python 3.11+. Uvicorn. Starlette (for security middleware).
- **Auth:** Bearer token (`PyJWT` HS256). Operator gating via shared-secret `X-Operator-Token` (Phase 0).
- **HTTP security:** Host-header allow-list (ADR-2026-07-24-04); FastAPI/Starlette security baseline (ADR-2026-07-24-06).
- **LLM:** OpenAI Python SDK with conditional gpt-5+/o1+/o3+ kwargs handling (retro-Decision 2026-07-18-09).
- **RAG pipeline:** Retriever + re-ranker + generation; contextual retrieval disabled by default (retro-Decision 2026-07-18-08).
- **Document extraction:** Substrate layer (`src/services/policy_extraction_service.py`) with 13 structured fields + executive summary.
- **Evidence pipeline:** `src/services/evidence_pipeline.py` with LLM honesty check on every extracted field (retro-Decision 2026-07-18-07).
- **Operator APIs:** `src/api/analytics.py` (with `require_operator` dependency).
- **Persistence:** SQLAlchemy; Alembic migrations in `supabase/migrations/`.
- **Testing:** `tests/` — ~378 tests (per README); pytest framework.
- **Coverage:** Real device UX and end-to-end acceptance still required.

### A.3 Persistence layer (`supabase/`)

- **Postgres** for transactional state.
- **pgvector** extension for embeddings.
- **Storage** (private buckets) for original documents.
- **Migrations:** `2026_07_18_revops_tables.sql` (9 tables, 16 events, 3 dashboard views); `2026_07_18_evidence_substrate.sql` (4 immutable append-only tables — `page_artifacts`, `source_spans`, `extracted_fields`, `field_evidence`); `2026_07_18_analytics_supabase.sql` (analytics dual-write).
- **Auth:** Supabase Auth for Supabase-side; PyJWT for anonymous client-side JWTs.

### A.4 Operations / deployment

- **Live platform target:** Cloud Run (per long-term platform decision 2026-07-12). `tools/deploy_cloud_run.sh` is the launch-time deploy.
- **Historical:** AWS App Runner service (preserved-historical per README §71+); Qdrant cloud; Redis cloud; Azure scripts (preserved-historical).
- **CI:** `.github/workflows/ci.yml`.
- **Observability:** Sentry, RevOps R1 analytics tables + 3 dashboard views.
- **Secrets:** Secret Manager (Cloud Run); env vars injected at deploy.

### A.5 External integrations

- **Payments:** Dodo Payments (primary, international cards) + Razorpay (secondary, India UPI/NetBanking) per retro-Decision 2026-07-18-03. Routing by currency/method in `BillingAdapter`.
- **LLM:** OpenAI (gpt-4o default; gpt-5+/o1+/o3+ with conditional handling).
- **Vector DB:** Qdrant cloud (historical); pgvector (current).
- **Bug tracking:** GitHub issues (mentioned in README §📞 Support).
- **Notifications:** Local notifications; no remote push yet.

### A.6 Documentation corpus

- `motto_v4.md` (1,424 lines; operating system)
- `DESIGN.md` (42 lines; visual tokens + signature + anti-references)
- `DECISION_LOG.md` (5 settled decisions + Decision 7 appended this session)
- `docs/decisions/` (40+ ADR files; index at `docs/decisions/README.md`)
- `docs/planning/product/`, `docs/planning/architecture/`, `docs/planning/discovery/`
- `docs/architecture/canonical_architecture.md` (referenced from ADR-2026-07-19-05)
- `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md` (constitution, Proposed)
- `docs/architecture/FIRST_PRINCIPLES_WEDGE.md` (wedge, Proposed subordinate)
- `docs/architecture/FREE_VS_PAID_BOUNDARY.md` (commercial, Proposed)
- `docs/strategic_assessment_2026-07-17.md` (Buffy's diagnostic)
- `docs/coverwise_*.md` / `coverwise_*.docx` (naming + renaming votes)
- `docs/audits/` (multiple)
- `docs/legal/` + `mobile/assets/legal/` (legal policies — duplicated source-of-truth risk per G-12)
- `docs/launch_claims/` (referenced; content not surfaced in this session)
- 50+ total markdown files

## B. State ownership (project-wide)

| Concern | Owner | Storage |
|---|---|---|
| Original policy document | Supabase Storage (private, principal-scoped) | Bucket + RLS |
| Document lifecycle | Backend state machine + append-only events | Postgres + outbox |
| Policy-specific claims | Evidence substrate (4 immutable tables) | Postgres |
| Customer-visible citation | Immutable source text + resolvable page artifact | Postgres + Storage |
| Identity | Supabase Auth (account) OR anonymous HS256 JWT (anon) | Both, with explicit migration |
| Consent | Server-side append-only consent ledger | Postgres (per ADR-2026-07-19-07) |
| Entitlement | Server-side ledger reconciled with billing provider | Postgres + RevenueCat/Dodo |
| Local sensitive data | Principal-scoped encrypted Hive | Mobile device |
| Operator access | Role-scoped + audit + reason-required (Phase 1 deferred) | Postgres + logs |
| Deletion | Durable workflow + completion evidence | Postgres + outbox |
| Public product claims | Launch-claim registry (`docs/launch_claims/`) | Git + tests |

## C. Data flows (project-wide)

### C.1 Upload + processing flow

```
Mobile device
  → user taps "Add policy"
  → permission gate (consent ledger entries)
  → file picker (PDF/JPEG/PNG, 20MB limit)
  → upload to Supabase Storage
  → backend outbox event "document_received"
  → OCR (on-device ML Kit or server)
  → evidence substrate writes (page_artifacts → source_spans → extracted_fields → field_evidence)
  → LLM honesty check on every field (reject hallucinated clauses)
  → executive summary generated from extracted fields
  → mobile polls status; ProcessingStatusScreen renders backend state
  → policy detail screen fetches PolicySummary from backend
  → entitlements check on share/export
```

### C.2 Q&A flow

```
Mobile QaScreen
  → question text
  → consent check
  → POST /query/stream → SSE
  → backend: retrieve (vector search) → rerank → generate (LLM)
  → enforce: source_text and retrieval_text separation; citation enforcement
  → stream tokens to client; client renders with FieldCitationCard
  → abstain when evidence insufficient
  → history written to qa_history box
```

### C.3 Billing flow

```
Mobile BillingAdapter (RevenueCat or Dodo)
  → entitlement event (purchase/refund/expiration)
  → reconcile with backend entitlement ledger
  → apply plan-level caps (max policies, max questions, allow*)
  → mobile `entitlementProvider` reflects current state
  → checkAction('action_name') gates user-visible surfaces
```

## D. Major dependencies (project-wide)

- Flutter 3.x / Dart 3.x
- Riverpod 2.x
- Hive + flutter_secure_storage
- share_plus, supabase_flutter, dio, sentry_flutter, app_links, connectivity_plus
- FastAPI / Uvicorn / Starlette
- SQLAlchemy / Alembic
- PyJWT (HS256)
- OpenAI Python SDK (gpt-4o + conditional gpt-5+)
- pgvector
- Dodo Payments SDK + Razorpay SDK
- Sentry (Flutter + Python)
- GitHub Actions (`.github/workflows/ci.yml`)
- Cloud Run (deploy target)
- Supabase (Auth + Postgres + pgvector + Storage + Analytics dual-write)

## E. Test architecture

- **Mobile:** Flutter widget + unit; `hive_test_helper.dart` shared; ~80+ test files; 636 passing per README (with 6 dismissed per Buffy).
- **Backend:** pytest; ~378 tests per README.
- **Coverage discipline:** use `flutter test --coverage` for mobile; `pytest --cov` for backend. Test data is real where possible (representative policies), mocked where necessary (LLM API).

## F. Build / deploy topology

- **Mobile build:** Flutter multi-arch (`mobile/.dartdefine.env` for env injection). Outputs in `mobile/build/` (gitignored).
- **Backend build:** Docker (`Dockerfile`); CLI deploy via `tools/deploy_cloud_run.sh`.
- **Cloud Run service:** 1 FastAPI service.
- **Supabase:** managed Postgres + pgvector + Storage; private buckets.
- **CI:** GitHub Actions: lint → test → build → (deploy on tag/release).

## G. Observability

- **Mobile:** Sentry crash reporting; `AnalyticsService` (Riverpod notifier) → buffered events → periodic sync to Supabase analytics tables.
- **Backend:** Sentry server-side; Python logging → Cloud Logging via Cloud Run.
- **Operator dashboard:** 3 views over analytics tables; gated by Phase-0 shared secret.
- **Launch-claim registry:** tracks every public claim with enforcing test + Tier-3 evidence.

## H. Strong foundations (project-wide)

- **Layered doctrine stack** — clean precedence hierarchy.
- **40+ ADRs** with append-only update log discipline.
- **Privacy-first consent ledger** (purpose-specific, grant/revoke, audit trail).
- **Outbox-only durable-work primitive** (no background tasks).
- **Evidence substrate (4 immutable tables)** — the implementation of Constitution P2 verifiability.
- **Principal-scoped encrypted Hive** — per retro-Decision 2026-07-19-06.
- **Server-side entitlement ledger** — single source of truth for plan state.
- **Operator trust model** with audit + reason + TTL.
- **CI test discipline** + 636 mobile tests + 378 backend tests.
- **Custom design tokens** in `DESIGN.md` + verification-state signature on every generated answer.

## I. Fragile foundations (project-wide)

- **Constitution / wedge / commercial / ADR-2026-07-29-02 still Proposed** — directional only.
- **6 dismissed test failures** uninvestigated.
- **Backend state-granularity mismatch** on ProcessingStatusScreen (5 frontend stages vs 3 backend states).
- **What-If Calculator on disk** — contradicts constitution P4.
- **Coverage Details Summary 935-line god-object**.
- **Policy Detail 1,439-line god-object** (per audit).
- **32 screens vs ~15 recommended for solo launch**.
- **Legal source-of-truth duplication** between `docs/legal/` and `mobile/assets/legal/`.
- **Live deployment uncertain** — README §"Launch status" reads "not yet deployed."
- **`AGENTS.md` absent** at root or nested.

## J. Contradictory scope (project-wide)

- **Proposed vs Accepted status mismatch** for self-declared-accepted ADRs (per ADR-2026-07-29-02 §1 inventory).
- **README preserves June 2025 AWS deployment snapshot** while current target is Cloud Run.
- **Strategic assessment says scope is too big** while constitution P12 supports cut/keep/finish.
- **What-If Calculator exists** while constitution P4 forbids.

## K. Unknown scope (project-wide)

- 6 dismissed test failures' root causes (per Buffy).
- `docs/launch_claims/` content (registry exists; content unverified).
- `coverwise_native_mobile_platform_store_readiness_audit_2026-07-21.md` content (referenced; not deeply read).
- Hindi l10n audit depth (legal-risk audit included `app_hi.arb` in scope).
- Whether the in-flight 10-file refactor implements ADR-2026-07-22-02 (Riverpod for service DI) or something else.
- Live backend deployment status as of 2026-07-30.

---

## Anything else? (motto §0.1.1)

The architecture is sound for a multi-platform Flutter + FastAPI + Supabase app at this scope. The strong foundations dominate; the fragile foundations are concentrated in (a) the doctrine-stack ratification, (b) backend state-granularity honest testing, (c) the on-disk What-If contradiction, and (d) god-object screens. The most leverage is on (a) — sign-off on the doctrine stack unlocks crisp downstream decisions on (c) and (d).
