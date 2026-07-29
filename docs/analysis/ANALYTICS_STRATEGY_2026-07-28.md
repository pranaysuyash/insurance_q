# Analytics Strategy

**Date:** 2026-07-28
**Status:** current
**Principle:** track only what enables a product decision. If an event doesn't inform a specific decision, don't emit it.

---

## 1) First-Principles: Why Analytics Exists

The only reason to track anything: **to make better product decisions.**

We don't track to have dashboards. We don't track to feel data-driven. We track so that when a user churns, we know *where* they dropped and *why* the app failed them.

### Decisions analytics must enable

| Decision | Event(s) that inform it |
|----------|------------------------|
| Is onboarding losing users? | `onboarding_started` → `onboarding_step_[N]_viewed` → `onboarding_completed` |
| Can users upload successfully? | `first_upload_started` → `document_processing_succeeded` / `document_processing_failed` |
| Do users reach value? | `first_value_delivered` → `question_submitted` → `answer_rendered` |
| Do users come back? | `app_session_started` with `days_since_install` |
| Where do users spend time? | `screen_viewed` on every screen transition |
| Do users talk about us? | No event — this is a Play Store review / referral question, not analytics |
| Is the app reliable? | `global_error` / `global_error_recovered` |
| Do users pay? | `paywall_viewed` → `plan_purchase_started` → `plan_purchase_completed/failed` |

---

## 2) Funnel: Install → Value → Retention

```
Install → app_session_started[days_since_install=0]
  → Splash → No track event (transient)
    → onboarding_started
      → onboarding_step_1_viewed
      → onboarding_step_2_viewed
      → onboarding_step_3_viewed
      → onboarding_completed
    → Dashboard (empty) → dashboard_viewed
      → first_upload_started
        → document_processing_succeeded
        → first_value_delivered
      → qa_screen_viewed
        → question_submitted
        → answer_rendered
    → Day 2+ → app_session_started[days_since_install>0]
```

Each step is a drop-off point. If we see `onboarding_started` but not `onboarding_completed`, onboarding is the problem. If we see `first_upload_started` but not `document_processing_succeeded`, upload/processing is the problem.

---

## 3) Current Coverage (2026-07-28)

### ✅ Adequately covered
- Sessions: `app_session_started` with install/session metadata
- Identity lifecycle: `identity_created`, `account_created`, `claim_succeeded/failed`
- Upload flow: `first_upload_started` → `document_processing_succeeded/failed` → `first_value_delivered`
- Q&A: `question_submitted` → `answer_rendered` → `answer_feedback_submitted`
- Policy detail: `policy_detail_opened`, `policy_detail_section_opened`, `policy_detail_source_preview_opened`, `policy_detail_shared`, `policy_detail_coverage_gap_tapped`, `policy_detail_claim_assist_tapped`
- Dashboard interactions: `dashboard_policy_tapped`, `dashboard_quick_action_tapped`, `dashboard_coverage_type_tapped`, `dashboard_activity_item_tapped`, `dashboard_first_upload_cta_tapped`, `dashboard_health_score_expanded`, `dashboard_preventive_tip_dismissed`, `dashboard_preventive_tips_dismiss_all`, `dashboard_family_member_tapped`, `dashboard_recent_claim_tapped`, `dashboard_recent_claims_tapped`, `dashboard_emergency_shortcut_tapped`
- Revenue: `paywall_viewed`, `plan_purchase_started/completed/failed`, `qa_pack_*`, `subscription_state_synced`
- Purchase flow: `free_tier_limit_hit`, `paywall_viewed`, `plan_purchase_started/completed/failed`
- Phone capture: `phone_capture_shown/dismissed`, `phone_otp_requested/verified`
- Support: `support_intent`, `cta_clicked/dismissed`
- Errors: `global_error`, `global_error_recovered`
- Batch processing: `batch_upload_started`, `batch_upload_completed`

### ❌ Missing (being added)
- **Onboarding funnel**: `onboarding_started`, `onboarding_step_[N]_viewed`, `onboarding_completed`
- **Screen views**: `screen_viewed` on dashboard, documents, Q&A, settings, family, claims, upgrade
- **Document deletion**: `document_deleted` (defined in schema, never emitted)
- **Workspace identity change**: No event for when workspace changes mid-session

### ❌ Schema-only (defined but never emitted — consider removing or implementing)
- `document_uploaded` — deprecated, superseded by `first_upload_started` + `document_processing_succeeded`
- `document_deleted` — needs implementation
- `screen_viewed` — being implemented now
- `feature_used` — generic, no decision it enables
- `plan_upgraded` — superseded by `plan_purchase_completed`
- `consent_changed` — privacy screen does `analytics_consent_re_enabled` instead
- `processing_stalled` — backend check, not mobile
- `entitlement_cap_reached` — superseded by `free_tier_limit_hit`
- `refund_issued` — backend-only, no mobile trigger
- `subscription_*` (started/renewed/cancelled/expired) — RevenueCat webhook, not mobile
- `account_deletion_*` — deletion flow not instrumented

---

## 4) Event Contract Rules (from motto_v4)

1. **Every event must enable a specific product decision.** If you can't state the decision, don't add the event.
2. **Don't track PII.** No email, phone, name, address, SSN, Aadhaar, policy text, OCR text, or extracted values.
3. **Schema-enforced first.** Add to `kEventSchemas` in `analytics_schema.dart` before emitting. The `validateAnalyticsEvent()` guard in debug mode catches violations.
4. **Tests prove it works.** Every new event must have a test that verifies `AnalyticsService.track` is called with the correct properties.
5. **Document after implementing.** This doc and `docs/review/coverwise_analytics_event_spec.md` must reflect runtime reality.
6. **Remove what's unused.** Schema-only events that are never emitted and have no implementation plan should be retired.

---

## 5) Decision Registry

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-28 | Add onboarding funnel events | Without these, cannot diagnose install-to-registration drop |
| 2026-07-28 | Add screen_viewed to all major screens | Without this, cannot trace user paths through the app |
| 2026-07-28 | Add document_deleted emission | Without this, cannot measure storage churn |
| 2026-07-28 | Remove schema-only events with no plan | Reduce tech debt; unused schema misleads future developers |
