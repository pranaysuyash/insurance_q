# Onboarding Funnel: Install → Upload → First Q&A → Return

**Date:** 2026-07-29
**Status:** Active
**Related:** `mobile/lib/services/analytics_schema.dart`, `src/api/analytics.py` (GET `/analytics/funnel`)

---

## 1. Funnel Stages

The onboarding funnel measures the user's journey from install to sustained engagement:

```
Install → Onboarded → Uploaded → Processed → First Q&A → Returned (Engaged)
  |            |           |           |            |            |
  v            v           v           v            v            v
 100%         ?%          ?%          ?%           ?%           ?%
```

### Stage Definitions

| # | Stage | Event | Definition | What It Tells Us |
|---|-------|-------|------------|-----------------|
| 1 | **Install** | `app_session_started` with `days_since_install = 0` | User opened the app for the first time. | How many new users arrived in the window. |
| 2 | **Onboarded** | `onboarding_completed` | User swiped through onboarding and tapped "Add my first policy." | Onboarding completion rate. If this is low, onboarding is confusing or too long. |
| 3 | **Uploaded** | `first_upload_started` | User selected a file and tapped upload. | Upload initiation rate. If this is low after onboarding, users can't find or don't have a policy PDF. |
| 4 | **Processed** | `document_processing_succeeded` | Upload completed and processing succeeded. | Processing reliability. If this is low relative to uploads, the PDF/image pipeline has issues. |
| 5 | **First Q&A** | `first_question_asked` | User asked their first question (install-level dedup). | First value moment. If this is low after successful upload, the Q&A interface or results don't meet expectations. |
| 6 | **Returned (Engaged)** | `app_session_started` with `days_since_install >= 1` AND user also uploaded | User came back on a different day after having uploaded a policy. | Sustained engagement. If this is low, users don't find enough ongoing value to return. |

### Conversion Rates Computed

| Rate | Formula | What It Measures |
|------|---------|-----------------|
| Install → Onboarded | onboarded / install | How many new users complete onboarding |
| Onboarded → Uploaded | uploaded / onboarded | How many onboarded users attempt an upload |
| Uploaded → Processed | processed / uploaded | Upload pipeline reliability |
| Processed → First Q&A | first_question / processed | How many users reach their first value moment |
| Uploaded → Returned | returned_engaged / uploaded | Sustained engagement rate |

---

## 2. How to Query

### Via the API

```bash
# 30-day funnel (default)
curl -X GET 'https://api.coverwise.app/analytics/funnel?days=30' \
  -H 'Authorization: Bearer <operator-token>'

# 7-day funnel (for weekly check-in)
curl -X GET 'https://api.coverwise.app/analytics/funnel?days=7' \
  -H 'Authorization: Bearer <operator-token>'
```

### Via Direct SQL (SQLite local dev)

```sql
-- Cohort: install_ids whose first session was within the last 30 days
WITH cohort AS (
    SELECT DISTINCT install_id
    FROM analytics_events
    WHERE event_name = 'app_session_started'
      AND install_id IS NOT NULL AND install_id != ''
      AND json_extract(properties, '$.days_since_install') = 0
      AND received_at >= datetime('now', '-30 days')
)
SELECT
    (SELECT COUNT(*) FROM cohort) AS install,
    (SELECT COUNT(DISTINCT install_id) FROM analytics_events WHERE event_name = 'onboarding_completed' AND install_id IN cohort) AS onboarded,
    (SELECT COUNT(DISTINCT install_id) FROM analytics_events WHERE event_name = 'first_upload_started' AND install_id IN cohort) AS uploaded,
    (SELECT COUNT(DISTINCT install_id) FROM analytics_events WHERE event_name = 'document_processing_succeeded' AND install_id IN cohort) AS processed,
    (SELECT COUNT(DISTINCT install_id) FROM analytics_events WHERE event_name = 'first_question_asked' AND install_id IN cohort) AS first_question,
    (SELECT COUNT(DISTINCT e.install_id) FROM analytics_events e WHERE e.event_name = 'app_session_started' AND e.install_id IN cohort AND json_extract(e.properties, '$.days_since_install') >= 1 AND e.install_id IN (SELECT install_id FROM analytics_events WHERE event_name = 'first_upload_started' AND install_id IN cohort)) AS returned_engaged
```

### Via Supabase (production)

The `GET /analytics/funnel` endpoint handles the Supabase path automatically via in-app filtering. For ad-hoc Supabase queries:

```sql
WITH cohort AS (
    SELECT DISTINCT install_id
    FROM analytics_events
    WHERE event_name = 'app_session_started'
      AND install_id IS NOT NULL AND install_id != ''
      AND properties->>'days_since_install' = '0'
      AND received_at >= NOW() - INTERVAL '30 days'
)
SELECT ...  -- same pattern as SQLite above, using -> for JSON access
```

---

## 3. Event Contract (Mobile)

The funnel depends on these events being emitted correctly by the mobile app:

| Event | Where It Fires | Properties | Status |
|-------|---------------|------------|--------|
| `app_session_started` | `main.dart` on every cold start | `install_id`, `session_id`, `days_since_install`, `platform`, `app_version` | ✅ Active |
| `onboarding_completed` | `onboarding_screen.dart` on completion | `analytics_consent`, `total_steps` | ✅ Added 2026-07-28 |
| `first_upload_started` | `documents_screen.dart` on first upload | `file_type` | ✅ Active |
| `document_processing_succeeded` | `documents_screen.dart` on processing success | `file_type`, `status` | ✅ Active |
| `first_question_asked` | `qa_screen.dart` on first question (SharedPreferences dedup) | `question_length_bucket` | ✅ Added 2026-07-28 |

### Critical: `install_id` Must Be Present

Every event above must carry a non-null `install_id` for the funnel to work. The `app_session_started` event sets this automatically from `InstallService.getInstallId()`. All other events inherit it from the AnalyticsService buffer.

If `install_id` is null or empty, the event is **excluded** from the funnel query.

---

## 4. Decision Framework

### What Each Stage Drop-Off Means

| Drop-Off Point | Diagnosis | Action |
|----------------|-----------|--------|
| Install → Onboarded: low (<60%) | Onboarding is losing users. | Review onboarding screens for length, clarity, value prop. |
| Onboarded → Uploaded: low (<40%) | Users can't find or don't have a policy PDF to upload. | Add share-sheet import, email forwarding, WhatsApp import. Consider a clearer CTA. |
| Uploaded → Processed: low (<80%) | Upload pipeline has reliability issues. | Check OCR pipeline, file size limits, processing timeouts. |
| Processed → First Q&A: low (<50%) | Users don't ask questions after upload. | The coverage summary or detail screen may be sufficient for their needs. This may be fine — not every user needs Q&A. |
| Uploaded → Returned: low (<20%) | Users don't come back after uploading. | Need ongoing engagement hooks: renewal reminders, gap alerts, content feed. |

### What's NOT Measured

The funnel does NOT measure:
- **Day 7 / Day 30 retention** (use `app_session_started` with `days_since_install` instead)
- **Revenue conversion** (use `paywall_viewed` → `plan_purchase_completed` funnel)
- **Feature-specific engagement** (use `feature_used` or per-feature events)
- **User satisfaction** (use `answer_feedback_submitted` sentiment)

---

## 5. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document created | Founder directive: "Set up the onboarding funnel tracking — install → upload → first Q&A → return" |

---

*This document is the operational reference for the onboarding funnel. For the backend implementation, see `src/api/analytics.py` (GET `/analytics/funnel`). For the event schemas, see `mobile/lib/services/analytics_schema.dart`.*
