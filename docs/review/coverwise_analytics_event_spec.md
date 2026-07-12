# CoverWise Analytics Event Spec

**Version:** 1.0  
**Date:** 2026-07-12  
**Principle:** measure user value and operational health without collecting policy contents or unnecessary personal data.

## Events

| Event | When | Safe properties |
|---|---|---|
| `landing_view` | Marketing page becomes usable | `page`, `referrer_group`, `campaign` |
| `demo_upload_started` | User selects or submits a document | `file_type`, `file_size_bucket` |
| `document_processing_succeeded` | Processing returns a usable result | `file_type`, `page_count_bucket`, `processing_time_bucket` |
| `document_processing_failed` | Processing fails | `failure_stage`, `error_class`, `retryable` |
| `question_submitted` | User submits a policy question | `question_length_bucket` |
| `answer_rendered` | Answer is visible | `answer_source_count_bucket`, `confidence_bucket`, `latency_bucket` |
| `answer_feedback_submitted` | User provides feedback | `sentiment`, `has_comment` |
| `support_intent` | User clicks support/help | `source_surface`, `reason` |
| `store_cta_clicked` | User clicks the app/store CTA | `platform`, `campaign` |

## Do not collect

- Uploaded filenames.
- Policy text, OCR text, questions, answers, page images, or extracted values.
- Government identifiers, payment details, email addresses, phone numbers, or free-form feedback text.
- Exact document sizes, page counts, or timestamps when a bucket is sufficient.

## Operational dashboards

- Funnel: `landing_view` -> `demo_upload_started` -> `document_processing_succeeded` -> `question_submitted` -> `answer_rendered`.
- Reliability: processing success rate, failure stage, retryable failure rate, answer latency bucket.
- Trust: feedback sentiment, support intent rate, repeated questions after an answer.
- Acquisition: campaign and referrer group by successful processing, not just page views.

## Acceptance criteria

- Events are emitted only after the corresponding UI state is true.
- Failed processing is distinguishable from abandoned upload.
- No event payload contains document content or free-form user text.
- Provider configuration is documented before production activation.
- A test property or local event inspector confirms every event and property name.
