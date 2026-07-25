# CoverWise Analytics Event Spec

**Version:** 2.0
**Date:** 2026-07-24
**Status:** current decision reference, supersedes prior `2026-07-12` baseline
**Principle:** measure user value and operational health without collecting policy contents or unnecessary personal data.

This document must be treated as a _derived_ view of the runtime registry.
For contract truth, use `docs/analysis/analytics_tracking_event_registry.md`.

## 1) Active contract set

**Active event count:** 48

- `app_session_started`
- `identity_created`
- `account_created`
- `claim_initiated`
- `claim_succeeded`
- `claim_failed`
- `analytics_consent_re_enabled`
- `paywall_viewed`
- `free_tier_limit_hit`
- `plan_purchase_started`
- `plan_purchase_completed`
- `plan_purchase_failed`
- `qa_pack_purchase_started`
- `qa_pack_purchase_completed`
- `qa_pack_purchase_failed`
- `qa_pack_balance_reconciled`
- `qa_question_blocked_no_budget`
- `question_submitted`
- `answer_rendered`
- `answer_feedback_submitted`
- `dashboard_first_upload_cta_tapped`
- `first_upload_started`
- `document_processing_succeeded`
- `document_processing_failed`
- `first_value_delivered`
- `batch_upload_started`
- `batch_upload_completed`
- `dashboard_activity_item_tapped`
- `dashboard_coverage_type_tapped`
- `dashboard_emergency_shortcut_tapped`
- `dashboard_family_member_tapped`
- `dashboard_health_score_expanded`
- `dashboard_policy_tapped`
- `dashboard_preventive_tip_dismissed`
- `dashboard_preventive_tips_dismiss_all`
- `dashboard_quick_action_tapped`
- `dashboard_recent_claim_tapped`
- `dashboard_recent_claims_tapped`
- `cta_clicked`
- `cta_dismissed`
- `phone_capture_shown`
- `phone_capture_dismissed`
- `phone_otp_requested`
- `phone_otp_verified`
- `support_intent`
- `global_error`
- `global_error_recovered`
- `subscription_state_synced`

## 2) Deprecated / deferred schema-only events

These are still in `analytics_schema.dart` for compatibility but currently not emitted by mobile run-time paths:

- `cta_impression`
- `account_deletion_initiated`
- `account_deletion_completed`
- `consent_changed`
- `document_uploaded`
- `document_deleted`
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

## 3) Change control

1. New events must be:
   - added to `analytics_schema.dart` with required properties,
   - included in schema tests,
   - reflected in `docs/analysis/analytics_tracking_event_registry.md`, and
   - assigned a conversion stage in `docs/analysis/analytics_conversion_plan.md`.
2. Any schema-only event removed from runtime must be documented as either `deprecated` or `retired` with review rationale.
3. This file is updated when `analytics_tracking_event_registry.md` changes, not independently.

## 4) Do not collect

- Policy text, OCR text, or extracted values.
- Government identifiers, payment details, email addresses, phone numbers, or free-form question feedback text.
- Exact document contents or unbounded filenames.

## 5) Decision reference links

- Registry: `docs/analysis/analytics_tracking_event_registry.md`
- Conversion definitions: `docs/analysis/analytics_conversion_plan.md`
- Detail funnel matrix: `docs/analysis/analytics_detail_flow_matrix.md`
- Action register: `docs/analysis/analytics_tracking_action_register_2026-07-24.md`
