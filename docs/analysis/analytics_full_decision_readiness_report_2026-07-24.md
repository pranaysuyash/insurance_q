# Analytics Readiness — Full Decision Report

**Date:** 2026-07-24
**Scope:** `/Users/pranay/Projects/medpiper/insurance_app`
**Type:** comprehensive analysis before feature decisions
**Status:** Decision-focused documentation artifact with implementation closure and follow-up scope narrowed

## 1) What this report is

This is the consolidated answer to your request for full analysis before any next analytics/product action.

It captures:
- what analytics is currently implemented,
- what is documented vs what is actually emitted,
- what is missing for decision-grade usage,
- what should be added / updated / removed, and
- what is still missing before this system can be used to drive feature priorities.

It supersedes `coverwise_analytics_event_spec.md` as current decision context, but does not erase historical context.

## 2) What we discussed and what is already preserved in repo

We have already reviewed and documented these in prior notes:
- `docs/analysis/analytics_tracking_audit_2026-07-24.md`
- `docs/analysis/analytics_tracking_action_register_2026-07-24.md`
- `docs/review/coverwise_analytics_event_spec.md`
- `docs/launch_claims/analytics-privacy.md`

This report expands them with end-to-end consistency checks and a concrete completion matrix.

## 3) Scope and source-of-truth rule used

Decisioning is made from live code first, not stale docs:
- analytics client and flush behavior: `mobile/lib/services/analytics_service.dart`
- schema validation: `mobile/lib/services/analytics_schema.dart`
- backend ingestion and operator read endpoints: `src/api/analytics.py`
- retention and identity helpers: `src/services/analytics_retention_service.py`, `src/services/analytics_identity.py`
- processing events service and operator surfaces: `src/services/processing_event_service.py`, `docs/monitoring/coverwise_analytics_dashboard.json`
- tests:
  - `mobile/test/analytics_schema_test.dart`
  - `tests/test_analytics_event_identity.py`
  - `tests/test_analytics_event_idempotency.py`
  - `tests/test_analytics_errors.py`
  - `tests/test_analytics_benchmark.py`
  - `tests/test_analytics_retention_service.py`

## 4) Event inventory (as of this analysis)

### 4.1 Emitted event set discovered in app callsites

`AnalyticsService.track(...)` and equivalent direct calls in app runtime produce these event names:

- `account_created`
- `analytics_consent_re_enabled`
- `answer_feedback_submitted`
- `answer_rendered`
- `app_session_started`
- `batch_upload_completed`
- `batch_upload_started`
- `claim_failed`
- `claim_initiated`
- `claim_succeeded`
- `cta_clicked`
- `cta_dismissed`
- `dashboard_activity_item_tapped`
- `dashboard_coverage_type_tapped`
- `dashboard_emergency_shortcut_tapped`
- `dashboard_family_member_tapped`
- `dashboard_first_upload_cta_tapped`
- `dashboard_health_score_expanded`
- `dashboard_policy_tapped`
- `dashboard_preventive_tip_dismissed`
- `dashboard_preventive_tips_dismiss_all`
- `dashboard_quick_action_tapped`
- `dashboard_recent_claim_tapped`
- `dashboard_recent_claims_tapped`
- `document_processing_failed`
- `document_processing_succeeded`
- `first_upload_started`
- `first_value_delivered`
- `free_tier_limit_hit`
- `global_error`
- `global_error_recovered`
- `identity_created`
- `paywall_viewed`
- `phone_capture_dismissed`
- `phone_capture_shown`
- `phone_otp_requested`
- `phone_otp_verified`
- `plan_purchase_completed`
- `plan_purchase_failed`
- `plan_purchase_started`
- `qa_pack_balance_reconciled`
- `qa_pack_purchase_completed`
- `qa_pack_purchase_failed`
- `qa_pack_purchase_started`
- `qa_question_blocked_no_budget`
- `question_submitted`
- `subscription_state_synced`
- `support_intent`

### 4.2 Registered schema set in `kEventSchemas`

This list is **63 events as of 2026-07-24**:

- `account_created`
- `account_deletion_completed`
- `account_deletion_initiated`
- `analytics_consent_re_enabled`
- `answer_feedback_submitted`
- `answer_rendered`
- `app_session_started`
- `batch_upload_completed`
- `batch_upload_started`
- `claim_failed`
- `claim_initiated`
- `claim_succeeded`
- `consent_changed`
- `cta_clicked`
- `cta_dismissed`
- `dashboard_activity_item_tapped`
- `dashboard_coverage_type_tapped`
- `dashboard_emergency_shortcut_tapped`
- `dashboard_family_member_tapped`
- `dashboard_first_upload_cta_tapped`
- `dashboard_health_score_expanded`
- `dashboard_policy_tapped`
- `dashboard_preventive_tip_dismissed`
- `dashboard_preventive_tips_dismiss_all`
- `dashboard_quick_action_tapped`
- `dashboard_recent_claim_tapped`
- `dashboard_recent_claims_tapped`
- `document_deleted`
- `document_processing_failed`
- `document_processing_succeeded`
- `document_uploaded`
- `entitlement_cap_reached`
- `feature_used`
- `first_upload_started`
- `first_value_delivered`
- `free_tier_limit_hit`
- `global_error`
- `global_error_recovered`
- `identity_created`
- `paywall_viewed`
- `phone_capture_dismissed`
- `phone_capture_shown`
- `phone_otp_requested`
- `phone_otp_verified`
- `plan_purchase_completed`
- `plan_purchase_failed`
- `plan_purchase_started`
- `plan_upgraded`
- `processing_stalled`
- `qa_pack_balance_reconciled`
- `qa_pack_purchase_completed`
- `qa_pack_purchase_failed`
- `qa_pack_purchase_started`
- `qa_question_blocked_no_budget`
- `question_submitted`
- `refund_issued`
- `screen_viewed`
- `subscription_cancelled`
- `subscription_expired`
- `subscription_renewed`
- `subscription_started`
- `subscription_state_synced`
- `support_intent`

### 4.3 Gap matrix

**Unregistered but currently emitted (document and decide immediately):**
- none after this pass (all runtime emitted names are now in schema)

**Schema-only but currently not emitted in scanned callsites:**
- `account_deletion_completed`
- `account_deletion_initiated`
- `consent_changed`
- `document_deleted`
- `document_uploaded`
- `entitlement_cap_reached`
- `feature_used`
- `plan_upgraded`
- `processing_stalled`
- `refund_issued`
- `screen_viewed`
- `subscription_cancelled`
- `subscription_expired`
- `subscription_renewed`
- `subscription_started`

## 5) What is currently good (decision-positive)

1. **Capture path exists and is stable**
   - Local queue + flush exists in `AnalyticsNotifier`.
   - Consent-aware tracking gate exists.
   - Identity fields are included in emitted payloads (`session_id`, `install_id`, `is_reinstall`) for attribution and install cohorting.

2. **Server identity + idempotency is in place**
   - `analytics_event_id` uses canonical user UID and properties; retries do not duplicate rows on canonical inserts.

3. **Operational operator endpoints exist**
   - `/analytics/summary`, `/analytics/health`, `/analytics/errors` are present and guarded.

4. **Retention service path and benchmarking are covered**
   - `AnalyticsRetentionService.purge_before` exists.
   - `tests/test_analytics_benchmark.py` and `tests/test_analytics_retention_service.py` exist for performance and RPC validation.

## 6) What is blocking decision-grade confidence right now

### 6.1 Contract drift is now resolved
- Schema and implementation are aligned for emitted event names.
- `validateAnalyticsEvent()` now returns errors for unknown event names.
- Tests now include explicit coverage checks that every runtime emitted event has a schema entry.

### 6.2 Governance/doc/spec mismatch
- Event spec has a synchronized follow-up version (`coverwise_analytics_event_spec.md` now includes active/deprecated sets + governance).
- `docs/launch_claims/analytics-privacy.md` has been aligned with current event contract status and registry references.

### 6.3 Dashboard/operator integration
- Auth mismatch is now fixed: `docs/monitoring/coverwise_analytics_dashboard.json` includes both `Authorization` and `X-Operator-Token`.
- Dashboard has event-level visibility; decision-grade KPI definitions and owner sign-off remain a follow-up hardening lane.

### 6.4 Field-level and recovery contract mismatch
- `global_error` and `global_error_recovered` now align on `error_type`, `error_code`, `library`.
- The schema test enforces the contract.

## 7) Decision readiness per user/app/business analytics

### 7.1 User analytics quality today
- Good for **observability** and event inventory.
- Good for **product prioritization** at the event level because a conversion dictionary now exists (`docs/analysis/analytics_conversion_plan.md`).
- Remaining quality gap is execution cadence (ownership sign-off, dashboard KPI definitions, and periodic governance cadence), not missing schema-level conversion logic.

### 7.2 Detail/app analytics quality
- Policy detail screen currently has no dedicated event-level instrumentation and uses navigation entry points only; dashboard/document touchpoints are still only partially normalized.
- This gap is now documented in `docs/analysis/analytics_detail_flow_matrix.md` for next-cycle implementation.

### 7.3 Business analytics quality
- Revenue/billing lifecycle data is partly present (`plan_purchase_*`, `subscription_state_synced`) but major lifecycle events in schema (`subscription_*`, `refund_issued`, `entitlement_cap_reached`) are not visibly produced in scanned paths.
- Conversion tie-ins for question/answer and monetization funnels are documented, but dashboard-level KPI ownership and periodic review are still not fully operationalized.

## 8) What is complete vs incomplete now

### Complete (safe to use for decision work)
- Event send queue, ingest endpoint, idempotency, and basic operator-only error summary APIs.
- Baseline schema tests and identity idempotency stability tests.
- Canonical registry, conversion definitions, and detail-flow matrix for planning decisions.
- Schema-only event decisions are closed: noisy/deprecated vs active vs retired status is explicit across governing docs.

### Incomplete / risky for planning decisions
- Governance and dashboard hardening remain, specifically periodic owner review cadence and queue-cap enforcement.

## 9) Immediate closure plan (do next before feature prioritization)

**P0 (now):**
1. Register all emitted undocumented events in schema or deprecate them formally. **Done**
2. Add runtime guard/tests that fail on undocumented emissions. **Done**
3. Normalize `global_error` / `global_error_recovered` property contract and error aggregation assumptions. **Done**
4. Update dashboard datasource queries for operator token. **Done**

**P1 (next):**
1. AR-011 noise-cleanup for `cta_impression` is complete.
2. Productionizing AR-006 next-cycle detail events if the team green-lights event-addition scope.

**P2 (follow-up):**
1. Add periodic owner sign-off loop for schema-only events (no open questions remain today).
2. Shift dashboard to KPI-first operational views with explicit denominators.
3. Confirm max queue-cap behavior and add enforcement path.

## 10) Open technical/behavioral questions before adding anything new

1. Confirm queue-cap enforcement policy and place in analytics runbook (no longer a schema-only semantics decision).

## 11) Summary answer to “what's left”

**Short answer:** Analytics is now contract-governed and interpretation-ready for core decisions.

**What is left by impact:**
- implement governance automation: periodic registry/spec review cadence and queue-cap policy (operational hardening).

---

## 12) Artifact map

- Full decision output: this file
- Action register: `docs/analysis/analytics_tracking_action_register_2026-07-24.md`
- Audit details: `docs/analysis/analytics_tracking_audit_2026-07-24.md`
- Event registry and decision docs: `docs/analysis/analytics_tracking_event_registry.md`, `docs/analysis/analytics_conversion_plan.md`, `docs/analysis/analytics_detail_flow_matrix.md`
- Event spec (governed): `docs/review/coverwise_analytics_event_spec.md`
