# Analytics Tracking Action Register

**Date:** 2026-07-24
**Product:** CoverWise / medpiper insurance app
**Author:** Codex
**Status:** Post-audit execution ledger with AR-011 completed; runtime/schema parity locked and schema-only policy questions closed. Remaining work is governance automation and queue-cap policy.
**Scope:** Decision-ready instrumentation and measurement hardening before product/app optimization decisions.

## Objective

Convert the audit findings into an explicit, staged execution plan so feature decisions are not made on unstable analytics signals.

## Baseline summary (from `docs/analysis/analytics_tracking_audit_2026-07-24.md`)

- 48 emitted event names via `AnalyticsService.track(...)` + internal notifier call
- 63 registered schema event names in `kEventSchemas`
- Significant mismatch between emitted and registered names.
- P0 contract mismatch has been resolved in this pass.
- Event spec and implementation are now fully synced; launch/readiness docs and schema-only decisions are now aligned.
- Measurement readiness estimated at 88/100 (useful for planning; governance cadence pending).

## Execution snapshot (as of 2026-07-24)

- **Not yet complete for full decision use:** periodic governance cadence and queue-cap enforcement policy remain.
- **Ready for monitoring/debug:** queueing, endpoint routing, operator guards, idempotency path, and baseline retention tests.
- **Open decisions from prior pass closed:**
  - schema-only `subscription_*`, `refund_issued`, and `entitlement_cap_reached` are explicitly deprecated until backend-owned emission is in active use.
  - `phone_capture_*` stays active as trust/support friction telemetry.
  - `cta_impression` stays deprecated as decorative-noise telemetry.
  - owner-level conversion definitions are documented in `docs/analysis/analytics_conversion_plan.md`.

For the consolidated current state and the exact event-by-event gap matrix, see:
- `docs/analysis/analytics_full_decision_readiness_report_2026-07-24.md`

## Execution model

- **Decision criterion:** each action must increase trust, reduce ambiguity, or map events to a decision.
- **Completion condition:** every implemented action must be auditable in file-level evidence.
- **Priority bands:** P0 (do now), P1 (next), P2 (later).

## Action register (decision table)

| ID | Priority | Type | Status | Action | Why this is needed | Owner | Files | Evidence requirement (pass criteria) | Risk / dependency |
|---|---|---|---|---|---|---|---|---|---|
| AR-001 | P0 | Add | **Done** | Create canonical `analytics_tracking_event_registry.md` with event-by-event contract (name, properties, event lifecycle, decision support). | Aligns current tracking with single source of truth and prevents drift. | Product Analytics + Mobile Lead | `docs/analysis/analytics_tracking_event_registry.md` (new), `docs/analysis/analytics_tracking_audit_2026-07-24.md` | Registry includes all emitted names and complete status (`active/retired/deprecated`). | Approved by Product in this pass and linked to schema gate. |
| AR-002 | P0 | Add | **Done** | Add missing emitted events to `kEventSchemas` or explicitly deprecate them. | Current schema missed decision-relevant behavior (`cta_*`, dashboard interactions, phone/otp, document lifecycle events). | Mobile Analytics owner | `mobile/lib/services/analytics_schema.dart`, `mobile/test/analytics_schema_test.dart` | `runtimeEmittedEventNames` is subset-checked against `kEventSchemas`; tests assert schema field coverage. | Must define minimal schema fields and decide if event still needed. |
| AR-003 | P0 | Add | **Done** | Mark stale/unused schema-only items with status, retention decision, and sunset rule: `account_deletion_*`, `entitlement_cap_reached`, `plan_upgraded`, `processing_stalled`, `refund_issued`, `subscription_*`, `screen_viewed`, `feature_used`, `document_deleted`, `document_uploaded`, `consent_changed`. | Schema-only events with no current emission and unclear current runtime path. | Product Owner + Backend + Mobile | `docs/analysis/analytics_tracking_action_register_2026-07-24.md`, `docs/analysis/analytics_tracking_event_registry.md` | Each event now has one status and explicit ownership for future reactivation or deletion. | If these appear in runtime outside scanned paths, action reopens immediately. |
| AR-004 | P0 | Add | **Done** | Replace `global_error` and `global_error_recovered` schema/property expectations so server summary keys and event contract match exactly. | Error aggregation relies on allowlisted fields for correctness and privacy. | Backend + Mobile Error handling owner | `mobile/lib/services/analytics_schema.dart`, `mobile/lib/widgets/shared/global_error_boundary.dart`, `mobile/test/analytics_schema_test.dart`, `src/api/analytics.py` | Single canonical error field contract documented and enforced in both emitter + aggregation assumptions. | Potential behavior change in debug validation output only; monitor after docs update. |
| AR-005 | P1 | Add | **Done** | Introduce explicit conversion definitions and funnel semantics in a decision doc for: onboarding activation, first upload value, QA solve flow, claims start/success, subscription state transitions. | Current events are action-oriented but now mapped to comparable conversion definitions. | Product Analytics | `docs/analysis/analytics_conversion_plan.md` (new), `docs/analysis/analytics_tracking_event_registry.md` | Conversion plan includes denominators, success/drop definitions, and review cadence. | Stakeholder review still needed on threshold tuning and 30-min QA timeout heuristic. |
| AR-006 | P1 | Add | **Done** | Define detail-flow tracking matrix for policy/document detail surfaces, and require event additions only for decision-grade actions. | Current system lacks standardized detail journey instrumentation suitable for product optimization. | Mobile + UX + Product | `mobile/lib/screens/policy_detail_screen.dart`, `mobile/lib/screens/documents_screen.dart`, `docs/analysis/analytics_detail_flow_matrix.md` | Matrix documents zero current policy-detail instrumentation and a minimal event set for next cycle. | Scope is intentionally limited to detail-open + section + action completion events only. |
| AR-007 | P1 | Add | **Done** | Add lightweight event-documentation references in code at high-volume modules (one doc comment header with event contract note) to reduce future drift. | Reduces recurrence of unmodeled events. | Mobile Platform Team | `mobile/lib/services/analytics_service.dart`, `mobile/lib/screens/documents_screen.dart`, `mobile/lib/widgets/shared/contextual_cta_card.dart` | New comments added where core event families are emitted: core service, documents flow, and CTA flow. | Documentation debt reduced; no runtime behavior change. |
| AR-008 | P1 | Update | **Done** | Refresh event spec to current implementation and replace with versioned release date + deprecation notes. | Current event spec did not reflect active event set. | Analytics + Docs | `docs/review/coverwise_analytics_event_spec.md` | Added sections: “active set”, “deprecated set”, and change control. | Cross-linked to registry and action register. |
| AR-009 | P1 | Update | **Done** | Align dashboard datasource panel list (`coverwise_analytics_dashboard.json`) to contracted events only and annotate unknown/derived metrics. | Prevents operators seeing mixed or undocumented metrics. | Analytics Ops | `docs/monitoring/coverwise_analytics_dashboard.json` | Dashboard queries include required headers and operator variables. | Dashboard-only change can break historic chart expectations; add changelog note. |
| AR-010 | P1 | Add | **Done** | Add a CI or test gate that fails when `AnalyticsService.track()` uses undocumented event names. | Prevents recurrence and protects future analytics correctness. | Mobile CI/QA owner | `mobile/test` (updated test suite) | Event usage set is asserted against `kEventSchemas`. | Test stability; requires deterministic extraction of call-sites. |
| AR-011 | P2 | Remove | **Done** | Remove event noise where usage is decorative and non-decision (`cta_impression`) while retaining decision-grade actions (`cta_clicked`, `cta_dismissed`) and dashboard touchpoints. | Noise dilutes funnel interpretations. | Product Analytics | `mobile/lib/widgets/shared/contextual_cta_card.dart`, `mobile/lib/widgets/dashboard/*`, `mobile/lib/services/analytics_schema.dart`, `docs/analysis/analytics_tracking_event_registry.md`, `docs/review/coverwise_analytics_event_spec.md`, `mobile/test/analytics_schema_test.dart` | `cta_impression` removed from runtime emission, marked deprecated in schema/registry, and removed from active event inventory. | Ensure no user-behavior signal loss from decorative impression surfaces. |
| AR-012 | P2 | Remove | **Done** | Remove stale/unused retention/metrics assumptions from docs that imply active coverage not present. | Documentation trust issues in readiness reviews. | Docs + Product | `docs/launch_claims/analytics-privacy.md` | Claim text now reflects current events and links to registry/spec. | Requires periodic review for future event changes. |
| AR-013 | P1 | Add | **Done** | Publish explicit policy for all remaining schema-only events and mark the pending planning lane as follow-up (dashboard KPI ownership + queue-cap guard). | Prevents ambiguous planning due to unresolved analytics ownership assumptions. | Product Analytics | `docs/analysis/analytics_full_decision_readiness_report_2026-07-24.md`, `docs/analysis/analytics_tracking_audit_2026-07-24.md`, `docs/analysis/analytics_tracking_event_registry.md`, `docs/review/coverwise_analytics_event_spec.md`, `docs/analysis/analytics_conversion_plan.md` | All schema-only events now have explicit status and each decision owner lane is documented. | If event ownership changes, reopen this action with a new decision date. |

## Evidence matrix (quick)

### Keep/retain events currently emitted and documented
`(none after this pass)`  
All runtime-emitted names are now in `kEventSchemas`.

### Schema-only events currently not emitted in scanned scope

`account_deletion_completed`, `account_deletion_initiated`, `consent_changed`, `document_deleted`, `document_uploaded`, `entitlement_cap_reached`, `feature_used`, `plan_upgraded`, `processing_stalled`, `refund_issued`, `screen_viewed`, `subscription_cancelled`, `subscription_expired`, `subscription_renewed`, `subscription_started`

## Gating criteria (accept before feature decisions)

- P0 actions complete.
- Event registry and schema parity lock established.
- Conversion definitions approved by product owner.
- Dashboard consumes only approved event set.
- Event drift check included in CI/test path.

Only after gate closure should feature prioritization use analytics-derived priorities.

## Suggested order (next 10 working days)

1. **Day 1–2:** AR-013 closure handoff and queue-cap governance decision.
2. **Day 3–4:** AR-009 refinement to KPI-first dashboard views with explicit denominators.
3. **Day 5–6:** AR-007 maintenance (governance cadence and review automation).

## References

- Audit document: `docs/analysis/analytics_tracking_audit_2026-07-24.md`
- Implementation points: `mobile/lib/services/analytics_schema.dart`, `mobile/lib/services/analytics_service.dart`, `src/api/analytics.py`
