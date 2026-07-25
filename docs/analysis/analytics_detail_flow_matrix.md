# Policy/Document Detail Flow Tracking Matrix (2026-07-24)

**Date:** 2026-07-24
**Scope:** `mobile/lib/screens/policy_detail_screen.dart`, `mobile/lib/screens/documents_screen.dart`
**Status:** Decision and instrumentation gap map (no new event instrumentation in this pass)

## Summary

`policy_detail_screen.dart` currently has no native `AnalyticsService.track()` calls, while `documents_screen.dart` includes upload-processing lifecycle events. Decision quality for detail surfaces is therefore driven by indirect signals only.

## Current state (as implemented)

### Policy detail surface (`policy_detail_screen.dart`)

| User step | Coverage today | Decision confidence |
|---|---|---|
| Open policy detail | None | Low |
| Expand sections / deep interactions | None | Low |
| Compare claim path actions | No dedicated policy-detail event; navigation only | Medium-low |
| Contact/source actions | None from detail screen | Low |

### Document list surface (`documents_screen.dart`)

| User step | Event coverage | Decision confidence |
|---|---|---|
| Start upload | `first_upload_started` | Medium |
| Processing success | `document_processing_succeeded` | High |
| Processing failure | `document_processing_failed` | High |
| First value milestone | `first_value_delivered` | Medium |
| Batch upload start/end | `batch_upload_started`, `batch_upload_completed` | High |

## Proposed decision-grade detail funnel (next implementation cycle)

Introduce only events that map to real intent/completion:

| Stage | Proposed event | Unit | Notes |
|---|---|---|---|
| Detail view | `policy_detail_opened` | per_user | fired once per policy detail mount |
| Detail depth | `policy_detail_section_opened` | per_document | optional section keys (if implemented) |
| Decision action | `policy_detail_claim_assist_tapped` | per_document | from claim-assistance CTA |
| Coverage analysis | `policy_detail_coverage_gap_tapped` | per_document | from coverage-gap entry |
| Source audit | `policy_detail_source_preview_opened` | per_document | helps trust/product evidence workflow |
| Share | `policy_detail_shared` | per_document | outbound sharing behavior |

## Suggested minimal decision ownership model

- **Primary owner**: Mobile + Product
- **Decision support scope**:
  - detail discovery vs repeat usage,
  - evidence-demanded support actions,
  - trust/quality friction points before support calls.
- **Implementation constraint**: do not add cosmetic interaction events unless they map directly to one of the rows above.
