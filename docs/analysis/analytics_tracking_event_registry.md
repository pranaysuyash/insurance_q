# Analytics Event Registry (v2026-07-24)

**Date:** 2026-07-24
**Path:** `docs/analysis/analytics_tracking_event_registry.md`
**Related:** `docs/analysis/analytics_tracking_audit_2026-07-24.md`, `mobile/lib/services/analytics_schema.dart`, `mobile/test/analytics_schema_test.dart`
**Goal:** single source of truth for event ownership, lifecycle, and decision usage.

## Scope

- `mobile/lib/services/analytics_schema.dart` has **63** registered event names.
- Runtime emits **48** event names after startup path (`AnalyticsService.track` + `app_session_started`).
- No new runtime event names are currently unregistered.

## Registry format

- **Status**: `active`, `deprecated`, or `retired`.
- **Lifecycle**: what product phase this event belongs to.
- **Decision support**: which decisions this event informs.

## Active emitted events (implemented + used)

| Event | Status | Properties | Lifecycle owner | Decision support |
|---|---|---|---|---|
| `app_session_started` | active | `install_id`, `session_id`, `platform`, `app_version`, `days_since_install`, `is_reinstall`, `install_referrer_*` | Analytics Platform + Mobile | onboarding quality, cohorting, install campaign effectiveness |
| `identity_created` | active | `identity_type`, `install_id` | Auth + Analytics Platform | identity and anonymous-to-account conversion tracking |
| `account_created` | active | `install_id`, `auth_method` | Auth + Analytics Platform | conversion from anonymous to account flows |
| `claim_initiated` | active | `anonymous_token_age_hours_bucket` | Auth + Product | claim-path drop-off and completion health |
| `claim_succeeded` | active | `transferred_count` | Auth + Claims Product | claims journey success |
| `claim_failed` | active | `error_class`, `transferred_count` | Auth + Product | claims path failure diagnostics |
| `analytics_consent_re_enabled` | active | _none_ | Product + UX | consent restore tracking and compliance audit |
| `paywall_viewed` | active | `cap_type`, `cap_value`, `user_actions_remaining` | Revenue + UX | paywall exposure and gating pressure |
| `free_tier_limit_hit` | active | `limit_type` | Entitlement + Product | monetization pressure and friction |
| `plan_purchase_started` | active | `plan_tier`, `billing_cycle` | Billing + Product | intent-to-pay, checkout conversion funnel |
| `plan_purchase_completed` | active | `plan_tier` | Billing + Product | paid conversion completion |
| `plan_purchase_failed` | active | `plan_tier`, `reason` | Billing + Product | payment failure reasons |
| `qa_pack_purchase_started` | active | `pack_type` | Billing + Product | pack interest and conversion intent |
| `qa_pack_purchase_completed` | active | `pack_type` | Billing + Product | pack conversion completion |
| `qa_pack_purchase_failed` | active | `pack_type`, `reason` | Billing + Product | billing failure + pack funnel drop-off |
| `subscription_state_synced` | active | `plan_tier`, `is_active` | Billing + Mobile | retention and active entitlement state |
| `qa_pack_balance_reconciled` | active | `pack_count`, `questions_remaining` | Entitlement + Product | billing reconciliation reliability |
| `qa_question_blocked_no_budget` | active | `plan_tier`, `subscription_remaining`, `pack_remaining` | Product + UX | budget friction and quota-pressure behavior |
| `question_submitted` | active | `question_length_bucket` | QA Product | top of QA funnel denominator |
| `answer_rendered` | active | `confidence_bucket`, `answer_source_count_bucket` | QA Product | QA solve completion quality |
| `answer_feedback_submitted` | active | `sentiment` | QA Product | user satisfaction loop |
| `dashboard_first_upload_cta_tapped` | active | _none_ | Dashboard UX + Product | first-value activation path proxy |
| `first_upload_started` | active | `file_type` | Document flow + Analytics | onboarding into upload funnel |
| `document_processing_succeeded` | active | `file_type`, `status` | Document processing + Product | processing reliability |
| `document_processing_failed` | active | `error_class` | Document processing + Reliability | failure mode telemetry |
| `first_value_delivered` | active | `document_id` | Product + Analytics | first usable extraction proxy |
| `batch_upload_started` | active | `file_count` | Document flow + Product | batch upload intent |
| `batch_upload_completed` | active | `completed`, `failed`, `total` | Document flow + Product | batch execution quality |
| `dashboard_activity_item_tapped` | active | `activity_type` | Dashboard UX + Product | dashboard interaction quality |
| `dashboard_coverage_type_tapped` | active | `type_name`, `document_count` | Dashboard UX + Product | coverage exploration behavior |
| `dashboard_emergency_shortcut_tapped` | active | _none_ | Dashboard UX + Safety | emergency path usage |
| `dashboard_family_member_tapped` | active | `is_manual` | Policy graph + Trust UX | family-member review usage |
| `dashboard_health_score_expanded` | active | `current_score` | Dashboard UX + Product | health-score engagement |
| `dashboard_policy_tapped` | active | `policy_type`, `status` | Dashboard + Policy UX | policy depth navigation intent |
| `dashboard_preventive_tip_dismissed` | active | `tip_id` | Dashboard UX + Trust | mitigation signal for advisory noise |
| `dashboard_preventive_tips_dismiss_all` | active | _none_ | Dashboard UX + Trust | same |
| `dashboard_quick_action_tapped` | active | `action_type` | Dashboard UX + Product | quick action usage ranking |
| `dashboard_recent_claim_tapped` | active | `claim_id`, `status` | Dashboard + Claims UX | claims follow-through behavior |
| `dashboard_recent_claims_tapped` | active | `action` | Dashboard + Claims UX | claim workflow navigation |
| `cta_clicked` | active | `cta_id`, `cta_title` | UX + Growth | CTA conversion participation |
| `cta_dismissed` | active | `cta_id` | UX + Growth | ad fatigue / intrusive CTA pressure |
| `phone_capture_shown` | active | `prompt_number` | Trust + Support UX | contact capture readiness |
| `phone_capture_dismissed` | active | _none_ | Trust + Support UX | contact capture drop-off |
| `phone_otp_requested` | active | `otp_channel` | Support + Trust | phone verification request rate |
| `phone_otp_verified` | active | `otp_channel` | Support + Trust | phone verification success rate |
| `support_intent` | active | `source_surface` | UX + Ops | support demand by surface |
| `global_error` | active | `error_type`, `error_code`, `library` | SRE + Sentry/Analytics | reliability and incident triage |
| `global_error_recovered` | active | `error_type`, `error_code`, `library` | SRE + Analytics | recovery effectiveness |

## Schema-only / deferred events (registered but no current runtime emission)

These events are intentionally not emitted in current mobile callsites and are deferred for explicit product review.

| Event | Status | Reason | Decision dependency |
|---|---|---|---|
| `cta_impression` | deprecated | render-time CTA impression telemetry was decision-noisy with high cardinality and low ownership | UX/Growth |
| `account_deletion_initiated` | retired | no deletion-onboarding flow in mobile now | delete-account roadmap |
| `account_deletion_completed` | retired | dependent feature not shipped | delete-account roadmap |
| `document_uploaded` | retired | upload event now represented by `first_upload_started` / batch events | confirm schema consolidation |
| `document_deleted` | deprecated | deletion behavior is not explicit in current UI flow | document lifecycle review |
| `screen_viewed` | retired | no route-level event emission strategy in this app version | screen-behavior policy |
| `feature_used` | retired | superseded by specific feature events | taxonomy cleanup |
| `plan_upgraded` | deprecated | replaced by `subscription_state_synced` + purchase events | billing event simplification |
| `entitlement_cap_reached` | deprecated | replaced by paywall `free_tier_limit_hit` + balance events | quota instrumentation review |
| `processing_stalled` | retired | no active timed-stall detection in mobile UX path | processing worker observability review |
| `refund_issued` | deprecated | no mobile-side refund emit path; server-owned process only | finance operations |
| `consent_changed` | retired | replaced by purpose-specific consent ledger + explicit consent UI | legal/consent policy |
| `subscription_started` | deprecated | backend-owned lifecycle not exposed on mobile events | billing event simplification |
| `subscription_renewed` | deprecated | backend-owned lifecycle not exposed on mobile events | billing event simplification |
| `subscription_cancelled` | deprecated | backend-owned lifecycle not exposed on mobile events | billing event simplification |
| `subscription_expired` | deprecated | backend-owned lifecycle not exposed on mobile events | billing event simplification |

## Governance rules

1. Event removal from runtime must either:
   - be represented by a more specific event in this registry, or
   - stay in `deprecated` with explicit business approval.
2. New events start as `active` only when schema + decision owner + owner acceptance are in place.
3. All active events must pass static schema gate in `mobile/test/analytics_schema_test.dart`.
4. If an event is retired, keep a date and rationale in this table until sunset complete.
