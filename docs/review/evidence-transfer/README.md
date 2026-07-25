# BR-14 Evidence Transfer Folder (Owner Input Zone)

Purpose
- Central, owner-controlled drop point for transaction-readiness artifacts.
- Keeps ownership documentation and transfer evidence separate from the operational command logs.

Structure
- `source/` — repo ownership and handoff evidence (repo hash, branch/tag, transfer notes).
- `mobile/` — store IDs, signing/certificate notes, release notes, and metadata links.
- `supabase/` — Supabase project handoff docs (project ID, migration exports, policy snapshots).
- `ownership/` — entity and IP continuity packet scaffold and founder authority references.
- `domains/` — registrar export, DNS records, renewal calendar.
- `analytics/` — KPI definitions, dashboards, and trend extracts.
- `dependencies/` — SBOM/license metadata and OSS obligation evidence.
- `legal/` — final Terms/Privacy and policy/version history references.
- `operations/` — support and incident process handoff docs.
- `billing/` — Revenuecat/provider and billing transfer matrix.
- `commercial/` — commercial signal and liabilities continuity packet scaffold.

Current session status (2026-07-25)
- Draft evidence pack exists and is linked from:
  - `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`
- Some repo-local non-sensitive evidence is already present:
  - `docs/legal/privacy_policy.md`
  - `docs/legal/terms_of_service.md`
  - `docs/review/PLAY_STORE_*` launch assets references
  - `mobile/assets/legal/privacy_policy.md`
  - `mobile/assets/legal/terms_of_service.md`
- `docs/review/evidence-transfer/legal/legal_evidence_bundle_2026-07-25.md` (checksummed legal/docs manifest)
 - `docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md` (checksummed analytics manifest)
 - `docs/review/evidence-transfer/analytics/production-dependencies-sbom-2026-07-25.json` (CycloneDX SBOM with pip-audit no-known-vulnerabilities output)
 - `docs/review/evidence-transfer/dependencies/dependencies_oss_obligations_bundle_2026-07-25.md` (dependency/OSS obligations bundle + approval ledger)
 - `docs/review/evidence-transfer/mobile/mobile_transfer_packet_2026-07-25.md` (packet scaffold)
 - `docs/review/evidence-transfer/supabase/supabase_transfer_packet_2026-07-25.md` (packet scaffold)
 - `docs/review/evidence-transfer/domains/domains_transfer_packet_2026-07-25.md` (packet scaffold)
 - `docs/review/evidence-transfer/operations/operations_transfer_packet_2026-07-25.md` (packet scaffold)
- `docs/review/evidence-transfer/billing/billing_transfer_packet_2026-07-25.md` (packet scaffold)
 - `docs/review/evidence-transfer/ownership/ownership_ip_transfer_packet_2026-07-25.md` (packet scaffold)
 - `docs/review/evidence-transfer/commercial/commercial_liabilities_transfer_packet_2026-07-25.md` (packet scaffold)

How this is used
1. Attach artifact path, timestamp, hash/checksum (where feasible), and owner sign-off in each folder.
2. Keep sensitive or private files out of the folder if sharing constraints apply; store path-only references plus checksum attestation instead.
3. In `TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`, mark each BR-14 matrix row as `ready` only after review-ready evidence is attached.

Notes
- This folder is owner-owned and non-enterprise by design; no external governance dependency is required unless explicitly requested.

Current manifest status (one-item handoff view)
- Source-code: `source/source_handover_notes_2026-07-25.md` → `Attached` (non-secret metadata snapshot).
- Legal/docs: `legal/legal_evidence_bundle_2026-07-25.md` → `Attached`.
- Dependencies/OSS: `dependencies/dependencies_oss_obligations_bundle_2026-07-25.md` → `Attached`.
- Analytics: `analytics/analytics_evidence_bundle_2026-07-25.md` → `In progress` (non-secret definitions + SBOM links).
- Ownership/IP: `ownership/ownership_ip_transfer_packet_2026-07-25.md` → `Prepared`.
- Commercial/liabilities: `commercial/commercial_liabilities_transfer_packet_2026-07-25.md` → `Prepared`.
- Mobile/apps: `mobile/mobile_transfer_packet_2026-07-25.md` → `Prepared`.
- Supabase: `supabase/supabase_transfer_packet_2026-07-25.md` → `Prepared`.
- Domains: `domains/domains_transfer_packet_2026-07-25.md` → `Prepared`.
- Operations: `operations/operations_transfer_packet_2026-07-25.md` → `Prepared`.
- Billing/vendor: `billing/billing_transfer_packet_2026-07-25.md` → `Prepared`.

Last manifest status refresh: `2026-07-25T11:15:00+05:30` (status-only, non-secret).
