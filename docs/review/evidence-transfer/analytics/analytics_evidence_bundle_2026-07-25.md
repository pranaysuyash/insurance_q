# BR-14 Evidence Bundle: Analytics (2026-07-25)

Purpose: Owner-owned transfer evidence for the Analytics row in the BR-14 matrix.
Mode: Non-secret evidence only (internal analytics spec/config references, no customer data).

## Included artifacts

| File | SHA-256 | Notes |
|---|---|---|
| `docs/monitoring/coverwise_analytics_dashboard.json` | `1e27e66da21c9bdf16afc0355c28473d4096c716392617028cebe13748f49b83` | Production analytics dashboard definition and endpoint layout (events, summaries, health, errors).
| `docs/review/coverwise_analytics_event_spec.md` | `b4fe5aa66514fb50f6eab727db1a82ab26d820d540bb542cf5d7aba4343e964e` | Event taxonomy and event-level behavior documentation for operational analytics.
| `docs/review/evidence-transfer/analytics/production-dependencies-sbom-2026-07-25.json` | `ea74643c50dcecaf8cf4da13fe04ddb81aa26b6fe9d5a7868ba12655eaaadb86` | Generated CycloneDX SBOM from the canonical production lockfile using `tools/generate_production_sbom.sh`. |

## What this row currently proves

- Analytics instrumentation schema and dashboard definition exist in-repo for continuity handoff.
- Tracking and reporting paths are documented and can be audited by buyer-side technical reviewer.
- No raw production usage data is included in this transfer packet.

## Handoff notes

- `Owner`: Solo founder.
- `Evidence status`: Attached.
- `Signature status`: Pending owner review/sign-off for transfer package.
- `Reviewer`: Founder.
- `Last updated`: 2026-07-25T10:44:03+05:30.

## Remaining actions for this row

- Provide signed KPI output export in the next phase (30/90-day sample requested in BR-14).
