# Analytics Tracking Readiness Audit (Detailed)

**Date:** 2026-07-24
**Branch / Scope:** `/Users/pranay/Projects/medpiper/insurance_app`
**Type:** Analysis / Research documentation (historical baseline + implementation follow-up)
**Owner:** Codex

## 0) Why this document exists

You asked for a full analysis that is documented before moving to any implementation. This document is the durable output for that request, covering:

- what was discussed,
- what was inspected,
- what was found,
- what is missing,
- what is still blocking decision-quality,
- what should be added/updated/removed next.

## 1) What we discussed in this thread (scope and intent)

1. You asked whether analytics work existed in a “detail/app/user” way that could support future product decisions.
2. We confirmed substantial instrumentation exists but found mismatches between emitted behavior and schema/contracts.
3. You provided three analytics-focused skill references and requested a documentation-first approach.
4. I confirmed those skills are appropriate and recommended sequence:
   - use tracking framework first,
   - stabilize schema/governance,
   - use business analysis for decision recommendations.
5. You correctly pushed back that analysis should be fully documented by default.

This document is the explicit answer to that requirement.

### Status note (2026-07-24 follow-up)

The inventory below is the original audit baseline. Since this file was first created, contract parity work was completed in:

- `mobile/lib/services/analytics_schema.dart`
- `mobile/test/analytics_schema_test.dart`
- `docs/analysis/analytics_full_decision_readiness_report_2026-07-24.md`
- `docs/analysis/analytics_tracking_action_register_2026-07-24.md`
- `docs/monitoring/coverwise_analytics_dashboard.json`

Use this audit as context, and use current governance docs for contract status:
- `docs/analysis/analytics_tracking_event_registry.md`
- `docs/analysis/analytics_conversion_plan.md`
- `docs/analysis/analytics_detail_flow_matrix.md`
- `docs/analysis/analytics_full_decision_readiness_report_2026-07-24.md`

Addendum (2026-07-24): `cta_impression` is no longer emitted at runtime and is now explicitly treated as deprecated/schema-only for governance.

## 2) Analysis objective

Evaluate whether current analytics implementation is decision-ready for **what to add, update, or remove** across product, UX, and growth decisions.

## 3) Method and provenance

- Static code and docs inspection across mobile and backend analytics paths.
- Event instrumentation discovery at callsites.
- Schema coverage check by comparing emitted event names against declared schema names.
- API contract and operator read-path review.
- Dashboard artifact and privacy/governance document review.

No runtime execution of app/backend was performed in this pass.

## 4) Files inspected

### Mobile

- `mobile/lib/services/analytics_service.dart`
- `mobile/lib/services/analytics_schema.dart`
- `mobile/lib/screens/documents_screen.dart`
- `mobile/lib/screens/qa_screen.dart`
- `mobile/lib/services/auth_service.dart`
- `mobile/lib/services/billing_adapter.dart`
- `mobile/lib/screens/privacy_security_screen.dart`
- `mobile/lib/screens/paywall_screen.dart`
- `mobile/lib/screens/upgrade_screen.dart`
- `mobile/lib/widgets/dashboard/*`
- `mobile/lib/widgets/shared/*`

### Backend / platform

- `src/api/analytics.py`
- `src/services/analytics_identity.py`
- `src/services/analytics_retention_service.py`
- `src/services/processing_event_service.py`

### Tests

- `mobile/test/analytics_schema_test.dart`
- `tests/test_analytics_event_identity.py`
- `tests/test_analytics_benchmark.py`

### Docs / governance

- `docs/review/coverwise_analytics_event_spec.md`
- `docs/launch_claims/analytics-privacy.md`
- `docs/monitoring/coverwise_analytics_dashboard.json`
- `docs/DASHBOARD_SCREEN_AUDIT.md`

## 5) What currently exists (strong positives)

### 5.1 App-side analytics service

- Central `AnalyticsService` API with queue + periodic flush.
- Anonymous session binding from app session ID.
- Consent gate controls emission through ledger state.
- Local persisted fallback buffer is used when offline/holding.
- Debug-mode schema validation path is already wired.

### 5.2 Server-side ingestion + observability

- `/analytics/events` endpoint accepts batched events and binds user identity server-side.
- Event ID calculation includes deterministic idempotency inputs.
- `/analytics/summary`, `/analytics/health`, `/analytics/errors` endpoints exist.
- Operator visibility guard is present via operator token dependency.
- Retention service and RPC path exist for purge workflows.

### 5.3 Governance and privacy posture

- Launch claim documents explicitly state no-policy-content analytics and consent gating.
- Consent can affect event emission behavior in code paths.
- Error events include bounded/truncated summary fields and no raw exception dump in response path.

## 6) Detailed event instrumentation gap analysis

### 6.1 Event inventory (as of 2026-07-24 follow-up)

- Schema-declared events (top-level in `analytics_schema.dart`): **63**
- Emitted events found via `Analytics` callsites in `mobile/lib` + internal notifier `app_session_started`: **48**

#### Emitted and undocumented (as baseline snapshot)

`(resolved; no longer present after follow-up contract fix)`.

#### In schema but no matching current emission usage

`account_deletion_completed`, `account_deletion_initiated`, `entitlement_cap_reached`, `feature_used`, `plan_upgraded`, `processing_stalled`, `refund_issued`, `screen_viewed`, `subscription_cancelled`, `subscription_expired`, `subscription_renewed`, `subscription_started`

### 6.2 Impact of this gap

- Reporting and dashboard signals can be selectively blind or inconsistent.
- Engineering and analyst teams cannot prove complete event lineage without external investigation.
- Decision quality drops when conversion funnels include undocumented behavior.

## 7) “Detail app / user” coverage status

- Screen list names are defined at routing level, including detail-like screens.
- Instrumentation exists for major flows (uploads, QA, billing, claims, dashboard interactions).
- However, there is no fully normalized, documented, per-detail-user journey schema that covers all meaningful policy-detail interactions with explicit decision semantics.

In practice: you can observe some detail-related interactions indirectly, but not a clean, standardized decision-grade “detail funnel.”

## 8) Event spec vs implementation drift

- Event spec and implementation are now aligned for emitted and schema-only events through the registry + spec + action register chain.
- Newer emitted events are now reflected in canonical docs with explicit change control references.
- Remaining mismatch risk is operational (dashboard KPI governance and queue-cap policy), not schema/spec mismatch.

## 9) Readiness score (using your cited framework)

### Measurement Readiness & Signal Quality Index (0-100)

- Decision Alignment: **17/25**
- Event Model Clarity: **13/20**
- Data Accuracy & Integrity: **16/20**
- Conversion Definition Quality: **12/15**
- Attribution & Context: **7/10**
- Governance & Maintenance: **8/10**

**Total: 73/100 (Decision-ready with follow-up governance hardening)**

Interpretation: data is now suitable for high-confidence product planning, with remaining risk focused on governance automation and operator KPI view hardening.

## 10) Risks identified

### Risk A — Decision drift
Without mapped event definitions, analysts may infer retention or monetization trends from inconsistent event sets.

### Risk B — Over/under-optimization
Adding/removing features based on non-governed event definitions can move product in the wrong direction.

### Risk C — Governance debt
Schema and spec drift creates recurrent confusion between dev, analytics, and leadership interpretations.

### Risk D — Compliance ambiguity
Any mismatch between consent behavior and event inventory must be treated as a trust/ privacy risk until validated continuously.

## 11) Recommended “where to act first” plan

### Priority 1 (foundation)
1. Publish canonical tracking registry and remove ambiguity on event contract.
2. Ensure every emitted event is schema-registered with properties and decision mapping.
3. Introduce a non-passing gate or test check for undocumented events.
4. Update the event spec and privacy notes to match implemented event set.

### Priority 2 (decision model)
1. Define conversion events explicitly (what counts as success at each funnel stage).
2. Standardize counting semantics: session/user/event/period granularity.
3. Define attribution context retention (source/campaign/variant where relevant).

### Priority 3 (detail workflow)
1. Map policy-detail, family, and document-detail journey events.
2. Add only events that represent real intent/completion, not cosmetic interactions.

### Priority 4 (operational reporting)
1. Rebuild dashboard panels to consume only contract-aligned events.
2. Document caveats and known blind spots.
3. Add periodic drift audit report.

## 12) Add / Update / Remove matrix (decision-ready)

### Add
- Contract enforcement artifact (documented event registry + schema parity checks)
- Explicit conversion definitions and funnel dictionary
- Detail-screen journey event model where decision-critical

### Update
- Event spec and launch documentation to include current event set + deprecation plan
- Dashboard source mapping to prevent undocumented metrics exposure
- Schema test coverage to fail on undocumented event calls

### Remove / defer
- Non-decision-supporting or exploratory events that do not map to an owner + action.
- Duplicate/confusing event names where one normalized event can represent the same signal.

## 13) What is useful right now from the analysis

- Existing implementation is a functional analytics base with strong pieces in ingestion, consent, and operator read paths.
- It is now a **reliable product-decision backbone** for event-level interpretation, with remaining risk in governance automation and KPI hardening.
- The highest-value next move is operational hardening (owner cadence + queue-cap policy) before expanding dashboard decision controls.

## 14) Exact artifact location

This expanded documented analysis is now at:

- [docs/analysis/analytics_tracking_audit_2026-07-24.md](/Users/pranay/Projects/medpiper/insurance_app/docs/analysis/analytics_tracking_audit_2026-07-24.md)
