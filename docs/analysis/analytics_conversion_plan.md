# Analytics Conversion Dictionary (2026-07-24)

**Date:** 2026-07-24
**Owner:** Product Analytics + Mobile Lead
**Scope:** decision-grade funnels for `mobile/lib` runtime events

## Purpose

This document maps live events to conversion stages and denominator logic so feature prioritization uses comparable, defensible definitions.

## Conventions

- **event_id**: event name in `docs/analysis/analytics_tracking_event_registry.md`
- **unit**: `per_session`, `per_user`, `once_per_user`, `per_document`, `per_install`
- **success**: terminal positive state
- **drop**: explicit negative or failure state

## Conversion definitions

### A) Onboarding activation and retention

#### A1) Activation intent
- **Start event**: `app_session_started`
- **Success event**: `identity_created`
- **Alternative success**: `account_created` (higher commitment signal)
- **Unit**: `per_install`
- **Formula**: count of unique installs with at least one activation event / total installs
- **Decision use**: activation health and onboarding regressions

#### A2) Privacy/consent completion
- **Start event**: `app_session_started`
- **Success event**: `analytics_consent_re_enabled`
- **Unit**: `per_session`
- **Formula**: users with consent re-enable within session / users entering session
- **Decision use**: consent friction and retention risk

### B) First-upload value funnel

#### B1) First upload journey
- **Start event**: `first_upload_started`
- **Success event**: `first_value_delivered`
- **Interim events**: `document_processing_succeeded`, `document_processing_failed`
- **Drop event**: `document_processing_failed`
- **Unit**: `per_document`
- **Formula**: count of documents with `first_value_delivered` / count of documents with `first_upload_started`
- **Decision use**: first-value quality and onboarding-to-value performance

#### B2) Batch upload quality
- **Start event**: `batch_upload_started`
- **Success event**: `batch_upload_completed` where `failed = 0`
- **Drop**: `batch_upload_completed` with `failed > 0`
- **Unit**: `per_batch`
- **Formula**: successful batches / total batches
- **Decision use**: robustness of large upload UX and queue behavior

### C) QA conversion funnel

#### C1) QA solve
- **Start event**: `question_submitted`
- **Success event**: `answer_rendered`
- **Micro conversion**: `answer_feedback_submitted`
- **Drop**: no `answer_rendered` within 30 min of `question_submitted` (session-bounded)
- **Unit**: `per_document` or `per_question`
- **Formula**: answered questions / submitted questions
- **Decision use**: product trust, UI/latency impact, and support overhead

#### C2) Budget friction
- **Watch event**: `qa_question_blocked_no_budget`
- **Recovery path**: follow-up in 24h includes `qa_pack_purchase_started` or `plan_purchase_started`
- **Unit**: `per_user`
- **Decision use**: whether paywalls are blocking high-value QA paths

### D) Claims path

#### D1) Claims conversion
- **Start event**: `claim_initiated`
- **Success event**: `claim_succeeded`
- **Drop event**: `claim_failed`
- **Unit**: `per_claim`
- **Formula**: claim_succeeded / claim_initiated
- **Decision use**: extraction-to-assistance reliability and claims workflow confidence

### E) Monetization and state transitions

#### E1) plan-based conversion
- **Start event**: `plan_purchase_started`
- **Success event**: `plan_purchase_completed`
- **Drop event**: `plan_purchase_failed`
- **Unit**: `per_user`
- **Formula**: completed / started
- **Decision use**: pricing quality and checkout conversion

#### E2) pack conversion
- **Start event**: `qa_pack_purchase_started`
- **Success event**: `qa_pack_purchase_completed`
- **Drop event**: `qa_pack_purchase_failed`
- **Unit**: `per_user`
- **Formula**: completed / started
- **Decision use**: low-friction revenue expansion for occasional users

#### E3) entitlement state retention
- **Signal**: `subscription_state_synced`
- **Unit**: `per_user`
- **Decision use**: active/renewal confidence and stale entitlement risk

## Ownership and review

- **Owner**: Product Analytics
- **Review cadence**: weekly
- **Change control**: update `analytics_tracking_event_registry.md` and this document together when any event definition changes.
