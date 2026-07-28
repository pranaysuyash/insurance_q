# Analytics Landscape Exploration — CoverWise

**Date:** 2026-07-26
**Scope:** Comprehensive exploration of ALL analytics dimensions across mobile, backend, infrastructure, and governance.
**Status:** Exploration complete. Implementation decisions can follow from this document.
**Principle:** Document everything before implementing. No analytics changes without documented context.

---

## 1. What This Document Covers

Every analytics dimension in the CoverWise ecosystem:

| Dimension | Status | Section |
|-----------|--------|---------|
| Mobile event tracking | ✅ Implemented | §2 |
| Backend event ingestion | ✅ Implemented | §3 |
| Error / crash tracking | ✅ Implemented (Sentry) | §4 |
| Consent & privacy gating | ✅ Implemented | §5 |
| Governance & documentation | ✅ Implemented | §6 |
| Operational logging | ⚠️ Partial (structlog in 1 service) | §7 |
| Health / monitoring endpoints | ✅ Implemented | §8 |
| Infrastructure metrics (CPU, memory, uptime) | ✅ Implemented | §9 |
| Distributed tracing / APM | ❌ Not implemented | §9 |
| Product / cohort analytics | ⚠️ Schema exists, not operationalized | §9 |
| Business intelligence dashboards | ❌ Not implemented | §9 |
| A/B testing framework | ❌ Not implemented | §9 |
| Performance monitoring | ❌ Not implemented | §9 |
| Session replay / UX analysis | ❌ Not implemented | §9 |

---

## 2. Mobile Event Tracking (Client-Side)

### 2.1 Architecture

The mobile analytics system is a **local-queue, periodic-flush** architecture:

```
Screen/Widget → AnalyticsService.track(name, props)
                        │
                        ▼
                 ConsentGate ───(denied)──→ silently dropped
                        │
                   (granted)
                        │
                        ▼
              AnalyticsNotifier._buffer
               (List<Map>, in-memory)
                        │
                        ▼
              Hive persistence (crash-safe)
                        │
              Timer.periodic(5 min) or at 50 events
                        │
                        ▼
              POST /analytics/events (batch)
                        │
                        ▼
               Server-side ingestion (§3)
```

**Files:**
- `mobile/lib/services/analytics_service.dart` — Core service + `AnalyticsNotifier`
- `mobile/lib/services/analytics_schema.dart` — Schema-enforced event definitions
- `mobile/lib/services/consent_ledger.dart` — Consent gating

### 2.2 Event Count

| Metric | Value |
|--------|-------|
| Registered schema events | **63** (in `kEventSchemas`) |
| Actively emitted at runtime | **48** (found in codebase via grep) |
| Deprecated/retired (schema-only) | **15** |
| Dashboard interaction events | **16** (dashboard_*) |
| Revenue/billing events | **14** (plan_*, qa_pack_*, subscription_*) |
| Document/processing events | **10** (first_upload_*, document_processing_*, batch_upload_*) |
| Error events | **2** (global_error, global_error_recovered) |
| Support/trust events | **7** (phone_*, support_intent, cta_*) |
| QA events | **4** (question_, answer_, feedback_) |

### 2.3 Where Events Are Fired (Call Sites)

| Screen/Widget | Events | Count |
|--------------|--------|-------|
| `qa_screen.dart` | `question_submitted`, `answer_rendered`, `answer_feedback_submitted`, `qa_question_blocked_no_budget` | ~8 |
| `documents_screen.dart` | `first_upload_started`, `document_processing_succeeded/failed`, `first_value_delivered`, `batch_upload_started/completed` | ~10 |
| `dashboard/` (6 widget files) | `dashboard_*` (16 events), `cta_*`, `support_intent` | ~40 |
| `upgrade_screen.dart` | `plan_purchase_started/completed/failed` | ~3 |
| `qa_packs_screen.dart` | `qa_pack_purchase_*` | ~3 |
| `paywall_screen.dart` | `free_tier_limit_hit`, `paywall_viewed` | ~2 |
| `privacy_security_screen.dart` | `analytics_consent_re_enabled` | ~1 |
| `help_support_screen.dart` | `support_intent` | ~1 |
| `phone_capture_sheet.dart` | `phone_capture_*`, `phone_otp_*` | ~5 |
| `contextual_cta_card.dart` | `cta_clicked`, `cta_dismissed` | ~2 |
| `global_error_boundary.dart` | `global_error`, `global_error_recovered` | ~2 |
| `app_session_started` (notifier init) | `identity_created`, `app_session_started` | ~2 |

### 2.4 Schema Enforcement

Every event in `analytics_schema.dart` has typed property schemas using `AnalyticsPropertyType` (string/number/boolean):

```dart
'question_submitted': {
  'question_length_bucket': AnalyticsPropertyType.string,
},
```

The `validateAnalyticsEvent()` function:
- Rejects unknown event names
- Validates property types match schema
- Flags potential PII (email, phone, name, address, SSN, Aadhaar patterns)
- Runs only in `kDebugMode` (no runtime cost in release)

### 2.5 Key Design Decisions

| Decision | Current State | Impact |
|----------|--------------|--------|
| **Consent gate** | Events dropped client-side if consent not granted | No server-side enforcement needed; user can revoke locally |
| **Local buffer** | Persisted to Hive, survives app kill | Crash-safe, events not lost on force-close |
| **Periodic flush** | 5-minute timer OR at 50 events | Acceptable latency for product analytics; not real-time |
| **Session binding** | `uid` = session ID (not user ID) | Enables anonymous-to-authenticated analysis via install_id |
| **No screen_viewed** | Retired — no route-level instrumentation | Misses navigation funnel data |
| **No policy_detail events** | Zero instrumentation on detail screen | Cannot measure detail-screen engagement |

---

## 3. Backend Event Ingestion (Server-Side)

### 3.1 Architecture

```
POST /analytics/events
    │
    ▼
Auth: Depends(get_current_user)  ← server-enforced UID
    │
    ▼
Event ID: stable_event_id(event_name, ts, user_uid, props, ...)
    │
    ├── Production path: Supabase table "analytics_events"
    │   ├── upsert with ignore_duplicates=True
    │   └── Idempotent — retries are safe
    │
    └── Development path: SQLite (insurance_app.db)
        ├── Optional dual-write to Supabase
        └── DUAL_WRITE_ANALYTICS env var controls this
```

**Files:**
- `src/api/analytics.py` — All 4 endpoints (ingest, summary, health, errors)
- `src/services/analytics_identity.py` — Event ID computation
- `src/services/analytics_retention_service.py` — Purge workflow

### 3.2 Endpoints

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/analytics/events` | POST | Bearer token | Ingest batch of events |
| `/analytics/summary` | GET | Bearer + X-Operator-Token | Event counts by name, unique users |
| `/analytics/health` | GET | Bearer + X-Operator-Token | Table/index existence, row counts |
| `/analytics/errors` | GET | Bearer + X-Operator-Token | Error aggregation, trends, recovery rate |

### 3.3 Schema (Supabase)

The `analytics_events` table:

```sql
event_id      TEXT PRIMARY KEY  -- deterministic, replay-safe
event_name    TEXT NOT NULL     -- e.g. 'question_submitted'
timestamp     TEXT NOT NULL     -- ISO 8601 from client
user_uid      TEXT NOT NULL     -- server-enforced (overrides client)
properties    JSONB             -- typed event properties
received_at   TEXT NOT NULL     -- server timestamp
install_id    TEXT              -- UUID per install
session_id    TEXT              -- UUID per app launch
is_reinstall  BOOLEAN           -- true if install_id seen before
```

Indexes: `event_name`, `user_uid`, `(event_name, received_at)`, `(received_at, event_name, user_uid)`, partial indexes on `install_id`/`session_id`.

### 3.4 Idempotency

Event ID is computed from: `event_name + timestamp + user_uid + properties + install_id + session_id + is_reinstall`. This means:
- Natural retries from network failures are safe
- Two different users cannot share an event ID
- Server time (received_at) is deliberately excluded

### 3.5 Operator Auth

Reader endpoints require **two layers** of auth:
1. Standard `Bearer` token (user auth)
2. `X-Operator-Token` header (shared secret from env var `OPERATOR_DASHBOARD_TOKEN`)

This prevents ordinary users from reading global analytics. Security Phase 1 will replace the shared secret with a JWT role claim.

---

## 4. Error & Crash Tracking

### 4.1 Mobile: Sentry Flutter

**Status:** ✅ Wired, not configured for production

```dart
// main.dart
if (AppConfig.hasSentryConfig) {
  await SentryFlutter.init(
    (options) {
      options.dsn = AppConfig.sentryDsn;
      options.environment = AppConfig.environment;
      options.release = AppConfig.appVersion;
      options.tracesSampleRate = AppConfig.isProduction ? 0.1 : 1.0;
    },
    appRunner: () async {
      await _startup();
    },
  );
} else {
  await _startup();  // DSN empty → Sentry skipped
}
```

**Key facts:**
- DSN injected via `--dart-define=SENTRY_DSN=...`
- Silently disabled when DSN is empty (safe for dev builds)
- Traces sample rate: 10% in production, 100% in dev
- Wraps all startup code (Hive, auth, workspace init) in Sentry error zone
- `ScreenErrorBoundary` widget isolates per-screen crashes
- `GlobalErrorBoundary` catches root-level errors

**Missing:**
- No production DSN configured (needs Sentry account)
- No `SENTRY_DSN` in `.env` (build-time arg only)
- No Sentry release tracking configured
- No User feedback / crash report dialog

### 4.2 Mobile: Analytics Error Events

Two schema-enforced events complement Sentry:
- `global_error` — fired from `GlobalErrorBoundary` when a widget error is caught
  - Properties: `error_type`, `error_code` (stable hash), `library`
  - No PII, no stack trace, no raw error messages
- `global_error_recovered` — fired when the app recovers from an error
  - Properties: `error_type`, `error_code`, `library`

### 4.3 Backend: Log-Based Error Tracking

All backend services use Python's `logging` module:
- Standard `logging.getLogger(__name__)` across all modules
- `log.exception()`, `log.error()`, `log.warning()`, `log.info()`, `log.debug()`
- Frontend service (`src/frontend/app.py`) uses structlog with JSON rendering
- No Sentry SDK on the backend
- No error aggregation service (no Sentry, no Datadog, no Grafana)

---

## 5. Consent & Privacy Gating

### 5.1 Consent Architecture

```
┌──────────────────┐
│   ConsentLedger   │  ← Local Hive box (encrypted)
│  (append-only)    │
└────────┬─────────┘
         │
         ├── AnalyticsService.track() → checks consent before emitting
         │
         ├── DocumentsScreen._ensureConsent() → blocks upload without consent
         │
         └── ConsentSyncService → syncs local decisions to server
                                    │
                                    ▼
                            ServerConsentService
                            POST /consent (server API)
```

### 5.2 Consent Purposes (8 total)

| Purpose | Scope | UI Surface |
|---------|-------|-----------|
| `documentProcessing` | Required for uploads | `LeadCaptureDialog` / `DocumentsScreen` |
| `analytics` | Optional — controls event tracking | Onboarding page 4, Privacy & Security screen |
| `privacyPolicy` | Required — ToS acceptance | Onboarding |
| `marketingEmails` | Optional — newsletter | `NewsletterSignupSheet` / `LeadCaptureDialog` |
| `cameraAccess` | Optional — photo capture | Claim wizard, phone capture |
| `evaluationDataset` | Deferred | Not in current UI |
| `modelImprovement` | Deferred | Not in current UI |

### 5.3 Consent Lifecycle

```
Record consent (grant/revoke)
  → Hive persist
  → AnalyticsService.track() checks consent before each event
  → ConsentsyncService.syncAll() (on startup + connectivity restore)
     → ServerConsentService.recordConsent() / getCurrentConsent()
```

### 5.4 Privacy Properties

- No policy text, OCR text, or extracted values in analytics events
- No government identifiers, payment details, emails, phone numbers
- No exact document contents or unbounded filenames
- All properties are bucketed (e.g., `file_size_bucket`, `question_length_bucket`)
- `error_code` is a stable hash, not the raw exception
- Consent ledger is append-only and user-visible in Settings

---

## 6. Governance & Documentation

### 6.1 Document Inventory

| Document | Path | Content |
|----------|------|---------|
| **Event Registry** | `docs/analysis/analytics_tracking_event_registry.md` | Every event with status, properties, lifecycle owner, decision support |
| **Conversion Plan** | `docs/analysis/analytics_conversion_plan.md` | Funnel definitions (onboarding, first-upload, QA, claims, monetization) |
| **Detail Flow Matrix** | `docs/analysis/analytics_detail_flow_matrix.md` | Policy/document detail funnel gaps and proposed events |
| **Full Readiness Report** | `docs/analysis/analytics_full_decision_readiness_report_2026-07-24.md` | Comprehensive readiness analysis with score (88/100) |
| **Audit** | `docs/analysis/analytics_tracking_audit_2026-07-24.md` | Initial audit with gap analysis and recommendations |
| **Action Register** | `docs/analysis/analytics_tracking_action_register_2026-07-24.md` | 13 AR items (all completed) |
| **Event Spec** | `docs/review/coverwise_analytics_event_spec.md` | Versioned event specification with governance rules |
| **Evidence Bundle** | `docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md` | BR-14 evidence for buyer readiness |
| **Dashboard Definition** | `docs/monitoring/coverwise_analytics_dashboard.json` | Grafana/compatible dashboard JSON |

### 6.2 Governance Rules

From the event spec:
1. New events must be: added to schema, tested, registered, assigned conversion stage
2. Schema-only events removed from runtime must be `deprecated` or `retired` with rationale
3. All active events must pass static schema gate in tests
4. Retired events keep date + rationale until sunset complete

### 6.3 Change Control Sequence

```
1. Add event name + properties to mobile/lib/services/analytics_schema.dart
2. Update mobile/test/analytics_schema_test.dart
3. Add emission call at appropriate screen/widget
4. Update docs/analysis/analytics_tracking_event_registry.md
5. Update docs/analysis/analytics_conversion_plan.md (if funnel-relevant)
6. Update docs/review/coverwise_analytics_event_spec.md (active set)
```

---

## 7. Operational Logging

### 7.1 Current State

| Service | Logger | Format | Structured? |
|---------|--------|--------|------------|
| Main API (`src/app/main.py`) | Python `logging` | Plain text | ❌ |
| Frontend (`src/frontend/app.py`) | `structlog` | JSON | ✅ |
| OCR (`src/ocr/service.py`) | Python `logging` | Plain text | ❌ |
| RAG (`src/rag/pipeline.py`) | Python `logging` | Plain text | ❌ |
| Document Processing | Python `logging` | Plain text | ❌ |
| Job Outbox | Python `logging` | Plain text | ❌ |
| Evidence Pipeline | Python `logging` | Plain text | ❌ |
| Workers | Python `logging` | Plain text | ❌ |

### 7.2 Log Coverage

The backend has good debug/info/warning/error logging across all services — approximately **200+ log statements** across the codebase. However:
- No structured JSON logs (except frontend service)
- No log aggregation (no Cloud Logging, no Loki, no ELK)
- No log-level configuration (INFO is hard-coded in many places)
- No auth event audit trail (CSO finding F8, not implemented)
- No request IDs for tracing
- No centralized log format

### 7.3 CSO Finding F8 (Structured Audit Logging)

The security audit recommended implementing structured audit logging with auth event tracking:
- **Status:** ❌ Not implemented
- **Priority:** INFO (CSO categorisation)
- **Requirement:** Implement structured logging using existing structlog dependency across all services, with auth event tracking and PII redaction

---

## 8. Health & Monitoring Endpoints

### 8.1 Endpoint Inventory

| Service | Liveness (`/healthz`) | Readiness (`/readyz`) | Health (`/health`) |
|---------|----------------------|----------------------|-------------------|
| Main API | ✅ `GET /healthz` | ✅ `GET /readyz` | ✅ `GET /health` |
| OCR Service | ❌ | ❌ | ✅ `GET /health` |
| RAG Service | ❌ | ❌ | ✅ `GET /health` |
| Frontend | ❌ | ❌ | ✅ `GET /health` |
| Outbox Worker | ✅ (`/healthz` on worker port) | ✅ (`/readyz` on worker port) | ❌ |
| Analytics | ❌ | ❌ | ✅ `GET /analytics/health` (operator-only) |

### 8.2 Health Contract

From `test_production_health.py`:
- `/healthz` — Cheap process-liveness check, never calls external services
- `/readyz` — Checks core service availability, rejects when uninitialized
- `/health` — Reports detailed health status, never exposes secrets
- CORS — OPTIONS handler must respect `Access-Control-Allow-Origin`

### 8.3 Missing Monitoring Infrastructure

| Component | Status | Impact |
|-----------|--------|--------|
| Prometheus metrics endpoint | ✅ | `/metrics` endpoint live with request-level, business, and infrastructure metrics |
| Grafana dashboard | ✅ | Dual-datasource dashboard (analytics JSON API + Prometheus), 50 panels covering CPU, memory, request rate, error rate, RAG latency, document processing |
| Uptime monitoring | ❌ | No external monitoring service |
| Alerting | ❌ | No pager, no Slack alerts |
| Log aggregation | ❌ | Logs only on local disk |
| Distributed tracing | ❌ | Can't trace request across services |
| APM | ❌ | No performance profiles |
| SLO tracking | ❌ | No uptime/latency targets |

---

## 9. Gap Analysis — What's Missing

### 9.1 Gap Classification

| Priority | Gap | Category | Effort | Business Impact |
|----------|-----|----------|--------|----------------|
| **P0** | Sentry DSN not configured for production | Error tracking | 30 min | Can't see production crashes |
| **P0** | No backend error tracking (Sentry/APM) | Error tracking | 2 hours | Blind to backend failures |
| **P1** | ~~No infrastructure metrics (Prometheus)~~ | ✅ Done | — | Prometheus endpoint at `/metrics`, business counters wired, Grafana JSON + HTML dashboard sections created |
| **P1** | No log aggregation | Logging | 1 day | Can't search production logs |
| **P1** | No product analytics dashboard for founder | BI | 2 days | Can't see user behaviour trends |
| **P1** | Policy detail screen has zero instrumentation | Event tracking | 1 day | Can't measure detail engagement |
| **P2** | No cohort/retention analysis | Product analytics | 2 days | Can't measure retention |
| **P2** | CSO F8: structured audit logging | Logging | 1 day | Security gap |
| **P2** | No performance monitoring | Performance | 2 days | Can't detect regressions |
| **P3** | No A/B testing framework | Growth | 5 days | Can't experiment |
| **P3** | No session replay | UX | 3 days | Can't watch user sessions |
| **P3** | No business intelligence reports | BI | 5 days | Can't share metrics with stakeholders |

### 9.2 What Exists but Is Not Operationalized

These components are built/schema'd but not actively producing value:

| Component | Location | Current State |
|-----------|----------|--------------|
| `install_id` / `session_id` tracking | Every event | Schema present, not used for cohort analysis |
| `is_reinstall` flag | Every event | Schema present, not used for retention analysis |
| Conversion definitions | `docs/analysis/analytics_conversion_plan.md` | Documented but not implemented as dashboard KPIs |
| Analytics dashboard JSON | `docs/monitoring/` | File exists but no live Grafana deployment |
| Retention service | `src/services/analytics_retention_service.py` | Code exists, not wired to any schedule |

---

## 10. Recommendations (Highest Impact First)

### Do Now (Before Launch)
1. **Set up Sentry for production** — Create Sentry account, get DSN, inject at build time. This is critical for post-launch crash visibility.
2. **Add backend Sentry SDK** — Install `sentry-sdk` for Python and wire into all services. Currently backend errors are invisible.
3. **Configure log aggregation** — Set up aerts/loki/grafana stack or use managed service to aggregate production logs.

### Do Within 2 Weeks (First Iteration)
4. **Deploy analytics dashboard** — Use the existing `coverwise_analytics_dashboard.json` with the /analytics endpoints to get live product metrics.
5. **Add policy_detail instrumentation** — 5 events from the detail flow matrix to close the largest event gap.
6. **Set up uptime monitoring** — Use Pingdom, UptimeRobot, or Grafana Cloud to monitor /health.

### Do Within 1 Month
7. **Implement cohort/retention analysis** — Use existing `install_id` + `app_session_started` data to build retention cohorts.
8. **CSO F8: structured audit logging** — Implement structlog across all services with auth event tracking.
9. **~~Infrastructure metrics~~** ✅ **Done** — Prometheus endpoint at `/metrics` with request, business, RAG, and embedding counters. Grafana JSON with 50 panels. HTML ops dashboard section.

---

## Appendix A: File Map

### Mobile Analytics
| File | Purpose |
|------|---------|
| `mobile/lib/services/analytics_service.dart` | Core tracking service + queue + flush |
| `mobile/lib/services/analytics_schema.dart` | 63 typed event schemas |
| `mobile/lib/services/consent_ledger.dart` | Local consent ledger |
| `mobile/lib/services/consent_sync_service.dart` | Consent sync to server |
| `mobile/lib/services/server_consent_service.dart` | Server consent API client |
| `mobile/lib/test/analytics_schema_test.dart` | Schema validation tests |
| `mobile/lib/config/app_config.dart` | Sentry DSN, environment config |

### Backend Analytics
| File | Purpose |
|------|---------|
| `src/api/analytics.py` | All 4 analytics endpoints |
| `src/services/analytics_identity.py` | Event ID computation |
| `src/services/analytics_retention_service.py` | Purge workflow |
| `src/services/processing_event_service.py` | Processing event history |

### Governance Docs
| File | Purpose |
|------|---------|
| `docs/analysis/analytics_tracking_event_registry.md` | Event registry |
| `docs/analysis/analytics_conversion_plan.md` | Funnel definitions |
| `docs/analysis/analytics_detail_flow_matrix.md` | Detail screen gaps |
| `docs/analysis/analytics_full_decision_readiness_report_2026-07-24.md` | Full readiness |
| `docs/analysis/analytics_tracking_audit_2026-07-24.md` | Original audit |
| `docs/analysis/analytics_tracking_action_register_2026-07-24.md` | Action register |
| `docs/review/coverwise_analytics_event_spec.md` | Event spec |
| `docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md` | BR-14 evidence |
| `docs/monitoring/coverwise_analytics_dashboard.json` | Dashboard definition |

### Tests
| File | Purpose |
|------|---------|
| `mobile/test/analytics_schema_test.dart` | Schema validation |
| `tests/test_analytics_event_identity.py` | Event ID tests |
| `tests/test_analytics_event_idempotency.py` | Idempotency tests |
| `tests/test_analytics_errors.py` | Error aggregation tests |
| `tests/test_analytics_retention_service.py` | Retention/purge tests |

---

## Appendix B: Event Taxonomy (48 Active Events)

### User Lifecycle (4)
`app_session_started`, `identity_created`, `account_created`, `analytics_consent_re_enabled`

### Claims (3)
`claim_initiated`, `claim_succeeded`, `claim_failed`

### Dashboard (16)
`dashboard_first_upload_cta_tapped`, `dashboard_activity_item_tapped`, `dashboard_coverage_type_tapped`, `dashboard_emergency_shortcut_tapped`, `dashboard_family_member_tapped`, `dashboard_health_score_expanded`, `dashboard_policy_tapped`, `dashboard_preventive_tip_dismissed`, `dashboard_preventive_tips_dismiss_all`, `dashboard_quick_action_tapped`, `dashboard_recent_claim_tapped`, `dashboard_recent_claims_tapped`

### Document Flow (7)
`first_upload_started`, `document_processing_succeeded`, `document_processing_failed`, `first_value_delivered`, `batch_upload_started`, `batch_upload_completed`

### Monetization (8)
`paywall_viewed`, `free_tier_limit_hit`, `plan_purchase_started/completed/failed`, `qa_pack_purchase_started/completed/failed`, `subscription_state_synced` + `qa_pack_balance_reconciled`, `qa_question_blocked_no_budget`

### QA (4)
`question_submitted`, `answer_rendered`, `answer_feedback_submitted`

### Support/Trust (7)
`phone_capture_shown/dismissed`, `phone_otp_requested/verified`, `support_intent`, `cta_clicked/dismissed`

### Reliability (2)
`global_error`, `global_error_recovered`

---

*End of analytics landscape exploration. This document is the source of truth for all subsequent analytics decisions.*
