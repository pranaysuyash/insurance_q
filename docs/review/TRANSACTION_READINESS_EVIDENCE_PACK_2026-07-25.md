# CoverWise transaction-readiness evidence pack (filled draft)

**Owner:** Solo founder/operator.
**Status:** Draft started 2026-07-25 in support of BR-13/BR-14.
**Purpose:** Convert transaction-readiness preparation into evidence-backed, owner-owned artifacts before representation for sale.
**Note:** No credentials, private customer documents, access tokens, private keys, or personal data are included in this file.

## 0) What is already complete

- Non-secret readiness process template exists:
  - `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_TEMPLATE.md`
- Legal boundary and role commitments are already fixed in readiness documents:
  - Product is explicitly a policy-information assistant, not an insurer/agent/broker.
  - `docs/planning/product/BUYER_READINESS_ACTIVE_QUEUE_2026-07-25.md` and `docs/planning/product/BUYER_READINESS_TODO_LIST_2026-07-25.md` assert no external legal-counsel dependency is required by default for this operating mode.
- Core non-secret operational evidence exists for local control gates (BR-01, BR-02, BR-04/BR-05 command-shape, BR-06 hosted-legal local checks, BR-07 entitlement path contracts, legal release asset validation, and BR-11 config contract), but BR-04/BR-05/Tier-3 deployed proofs and BR-07/BR-08/BR-09/BR-12 runtime proofs remain blocked by owner/runtime dependencies.
- **Progress this session:** added a BR-13/BR-14 valuation and transfer checklist so this asset can be handed over to buyer review in a deterministic, checklist-driven order.

## 1) Ownership, entity, and IP proof ledger

| Evidence item | Required proof | Current status | Owner | Reference |
|---|---|---|---|---|
| Selling entity and authority | Legal identity, authority, tax and operating status of the seller | Open | Founder | Requires founder-provided registration and authority proof |
| Source-code ownership chain | Founding/employee/contractor agreements and assignment matrix | Open | Founder | Requires owner-provided assignment and IP transfer documents |
| OSS obligations | Open-source licenses, SBOM status, exception register | Attached (non-secret) | Founder | `docs/review/evidence-transfer/dependencies/dependencies_oss_obligations_bundle_2026-07-25.md` |
| Brand/domain rights | Registrant evidence, domain renewal status, trademark posture | Open | Founder | Founder-owned ownership evidence required |
| Third-party model/API/content rights | Provider and corpus usage rights and model API terms | Open | Founder | Requires owner-exported provider notices, policy and contract scope |

## 2) Transferable technical estate evidence

| Asset | Required proof | Current status | Transfer approach |
|---|---|---|---|
| Entity / IP ownership continuity | Registration authority and assignment continuity | Open (template prepared) | `docs/review/evidence-transfer/ownership/ownership_ip_transfer_packet_2026-07-25.md` |
| Source repository | Canonical repo hash and handover mechanics | Open | Reproducible archive + commit handoff procedure |
| Dependency supply chain | Lockfiles, SBOM, vulnerability/licence review | Attached (non-secret) | `docs/review/evidence-transfer/dependencies/dependencies_oss_obligations_bundle_2026-07-25.md` + `docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md` |
| Cloud infrastructure | Project ownership, billing owner, regions, deploy topology | Open | Controlled account transfer or rebuild plan documented by founder |
| Supabase | Project ownership, migration parity snapshot, RLS policy posture | Open | Account owner performs controlled transfer/role handoff + migration checklist |
| Mobile distribution | Store account ownership, signing identities, package IDs | Open | Transfer through official store mechanisms after signed release readiness |
| Observability/support | Alert, on-call, retention and support evidence | Open | Rotate support invitations and deliver monitoring handover notes |
| Domains/email/SMS/payments | Registrations, renewal/billing owner, offboarding path | Open | Transfer or controlled rebuild plan + billing role handoff |
| Commercial/liability continuity | Revenue, refunds, support obligations and vendor commitments | Open (template prepared) | `docs/review/evidence-transfer/commercial/commercial_liabilities_transfer_packet_2026-07-25.md` |

### 2A) Transfer inventory checklist (founder-owned handover pack)

Use this checklist as the explicit transfer manifest for BR-14. It is owner-owned and intentionally excludes enterprise governance preconditions.

| Asset class | What should exist in data room | Current status in this session |
|---|---|---|
| Source code | Canonical branch/commit hash, PR policy, build/run notes | In-progress (artifact attached: `docs/review/evidence-transfer/source/source_handover_notes_2026-07-25.md`) |
| Entity / IP ownership | Registration proof and assignment chain | Open (template prepared) | `docs/review/evidence-transfer/ownership/ownership_ip_transfer_packet_2026-07-25.md` |
| Dependencies/OSS obligations | SBOM + license metadata + AGPL/copyleft obligation notes | Attached (`docs/review/evidence-transfer/dependencies/dependencies_oss_obligations_bundle_2026-07-25.md`) |
| Mobile apps | App Store / Play Store project IDs, package names, release artifacts, signing keys | Open (no signed release artifacts linked yet). Staging dropzone: `docs/review/evidence-transfer/mobile/` |
| Supabase | Project ID, role matrix, migration history, RLS policy snapshot | Open (runtime context in `.env`; migration/export artifacts not yet attached). Staging dropzone: `docs/review/evidence-transfer/supabase/` |
| Domains | Registrar details, renewal calendar, DNS records, email/SMS sender paths | Open. Staging dropzone: `docs/review/evidence-transfer/domains/` |
| Analytics | Dashboard owner, export artifact (CSV/BI), KPI definitions and sample period | In-progress (artifact attached: `docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md`; includes generated SBOM and locked graph output) |
| Docs / legal assets | Terms, Privacy, release notes, support SOPs, privacy/data handling commitments | Attached (non-sensitive policy files + hashes linked below). Full signer-backed copies/staging: `docs/review/evidence-transfer/legal/` |
| Commercial/liability continuity | Rev/recharge/charges, support obligations, open liabilities | Open (template prepared) | `docs/review/evidence-transfer/commercial/commercial_liabilities_transfer_packet_2026-07-25.md` |
| Operations | Support inbox/admin access, incident notes, outage/incident runbook | Open. Staging dropzone: `docs/review/evidence-transfer/operations/` |
| Vendor and billing | Revenuecat/provider dashboards, billing and webhook credentials migration matrix | Open. Staging dropzone: `docs/review/evidence-transfer/billing/` |

This set is complete as a **documented handover template**. BR-14 closes only after each row has an owner-signed evidence artifact attached.

### 2B) BR-14 Evidence intake matrix (required signatures + proof locations)

Use this matrix to make every transfer row immediately auditable by a buyer diligence check.

| Manifest row | Evidence type required | File/path requested from owner | Evidence status | Reviewer | Status |
|---|---|---|---|---|---|
| Source code | Commit hash, release archive, PR/branch policy, handoff notes | `docs/review/evidence-transfer/source/source_handover_notes_2026-07-25.md` | Attached | Founder | `in-progress` |
| Entity / IP ownership | Registration and assignment artifacts, authority statement | `docs/review/evidence-transfer/ownership/ownership_ip_transfer_packet_2026-07-25.md` | Prepared | Founder | `in-progress` |
| Dependencies / OSS obligations | SBOM + license obligations | `docs/review/evidence-transfer/dependencies/dependencies_oss_obligations_bundle_2026-07-25.md` | Attached | Founder | `in-progress` |
| Mobile apps | Store IDs, signing keys summary, build artifact references | `docs/review/evidence-transfer/mobile/` | Open | Founder | `in-progress` |
| Supabase | Project/project_id, RLS snapshot, migration export plan | `docs/review/evidence-transfer/supabase/` | Open | Founder | `in-progress` |
| Domains | Registrar export, DNS record list, renewal calendar | `docs/review/evidence-transfer/domains/` | Open | Founder | `in-progress` |
| Analytics | Dashboard + KPI definition + 30/90-day sample | `docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md` | Attached | Founder | `in-progress` |
| Docs/legal | Final Terms/Privacy copies, release notes, SOPs | `docs/review/evidence-transfer/legal/legal_evidence_bundle_2026-07-25.md` | Attached | Founder | `in-progress` |
| Commercial/liabilities | Revenue and refund continuity evidence, support and obligations posture | `docs/review/evidence-transfer/commercial/commercial_liabilities_transfer_packet_2026-07-25.md` | Prepared | Founder | `in-progress` |
| Operations | Support handoff list, outage log excerpts, incident runbook | `docs/review/evidence-transfer/operations/` | Open | Founder | `in-progress` |
| Vendor/billing | Billing portal exports and webhook handoff matrix | `docs/review/evidence-transfer/billing/` | Open | Founder | `in-progress` |

Each artifact should be attached with:
- Export timestamp
- Source/author
- Integrity reference (hash or checksum where possible)
- Owner declaration that the artifact is final and signed

## 3) Commercial, customer and liability evidence

| Metric/obligation | Required evidence | Current status | Notes |
|---|---|---|---|
| Acquisition | Channels, installs, activation cohorts | Open | Owner must provide analytics export and definitions |
| Retention | D1/D7/D30 active cohorts | Open | Owner to provide cohort definition and dashboard snapshots |
| Revenue | MRR/ARR, refunds/chargebacks, taxes | Open | Requires accounting/billing export |
| Unit economics | Hosting/model/support cost and gross margin | Open | Separate founder time costs from operating costs |
| Support quality | Support volume and SLA, incidents, unresolved defects | Open | Founder to provide support mailbox and backlog state |
| Customer agreements | Published Terms/Privacy and operational commitments | Open | Owner confirms final wording + support/retention commitments |
| Liabilities | Refunds/credits/disputes/vendor minimums | Open | Owner provides ledger or signed statement of zero/open cases |

## 4) Security and continuity controls

- Credential cutover and rotation records: use
  `docs/review/CREDENTIAL_ROTATION_ATTESTATION_TEMPLATE.md` (non-secret).
- BR-04 and BR-05 real-auth continuity + two-principal isolation are currently blocked by missing/invalid `SUPABASE_SERVICE_ROLE_KEY` and are recorded in:
  - `docs/planning/product/BUYER_READINESS_TODO_LIST_2026-07-25.md`
  - `docs/planning/product/BUYER_READINESS_ACTIVE_QUEUE_2026-07-25.md`
- BR-06 hosted legal-page parity remains blocked by missing canonical deployed URL in this environment.
- No production secret values, service-role keys, provider tokens, or customer content are included in this draft.

## 5) Handover rehearsal and sequencing

1. Founder provides current non-secret evidence for each open row in sections 1–3.
2. Buyer receives curated transfer inventory and reproduces local verification baseline.
3. Seller runs live handover rehearsal:
   - non-production deployment proof,
   - credential cutover drill (limited scope),
   - support and incident-routing handoff.
4. Acceptance record is completed and signed.

### Buyer rehearsal checklist (draft)

- Pre-rehearsal:
  - Confirm owner-provided export packet includes: transfer evidence pack, release notes, runbooks, and latest support backlog.
  - Confirm buyer-side owner(s) and timezone slot are shared before the rehearsal window.
  - Confirm synthetic-only data will be used for all runtime scripts.
- During rehearsal:
  - Walk through BR-13/BR-14 open rows one-by-one with evidence links open in one browser tab.
  - Execute the handover sequence documented in the transfer inventory.
  - Demonstrate support escalation handoff and incident response handoff within one shared thread.
- Sign-off:
  - Capture a signed rehearsal note (founder + buyer representative) with:
    - unresolved items,
    - agreed owner-owned follow-up owners,
    - required inputs before close.
  - Archive this note in the data room and mark the acceptance row as "in progress".

## 6) Acceptance record (required updates before BR-13/BR-14 close)

| Gate | Evidence date | Reviewer | Result | Residual risk / closure action |
|---|---|---|---|---|
| IP and entity authority | 2026-07-25 | Founder | Open | Add founder-side registration + authority evidence |
| Account/domain/store transferability | Open | Founder | Open | Add transfer plan and official transfer evidence |
| Security/privacy and credential cutover | Open | Founder | Open | BR-04/BR-05 execution and credential handoff must complete |
| Commercial and liability reconciliation | Open | Founder | Open | Add revenue, refunds, support, and obligations evidence |
| Reproducible technical handover | Open | Engineering | Open | Add canonical export/tag and runbook handoff evidence |
| Buyer cutover rehearsal | Open | Founder | Open | Complete staged handover drill after external account inputs are available |

### One-page valuation memo (app draft, owner-provided inputs required)

- **Scope:** Solo-founder continuity valuation for transfer conversations only. This is a draft pack artifact, not a financial opinion.
- **Legal frame:** No external legal counsel is required by default for this sequence; counsel/advisory review is optional and owner-decision driven.
- **Prepared on:** 2026-07-25
- **Owner inputs currently available in this repo:** none (no verified live revenue/analytics export attached to this session).

#### A. Commercial signal snapshot (status: open evidence)

| Signal | Repo evidence status | Current value posture |
|---|---|---|
| Paid traction | No verified billing/export evidence attached in this worktree | **No defensible revenue number yet** |
| Usage trend | No signed analytics export or retention dashboard snapshot attached | **No defensible growth trend yet** |
| Support load | Support ledger/backlog snapshot not yet attached | **Potentially low-to-moderate at launch scale** |
| Liability exposure | Refund/revocation/credit handling evidence incomplete (provider lifecycle verification incomplete) | **Material continuity risk** |

#### B. Feature continuity footprint (what transfers cleanly vs depends on founder operations)

- Core ownership assets: mobile app, source, Supabase schema/logic, parsing & claims-assistant surfaces, and legal asset pack.
- Transfer-friction surfaces (must be documented by owner):
  - Billing lifecycle controls (restore/refund/revocation/account switch),
  - Legal and support operating commitments (who answers support, SLAs, response cadence),
  - Store publication artifacts (release signing/metadata/channel details).
- Key-person dependency: medium-high (founder-built continuity) until runbooks and rotation/cutover evidence are added.

#### C. Valuation math (owner-modeled)

Use the same practical formula from this pack:

`Owner-value range = (Annualized maintainable net owner cash flow) × 1.8 to 4.2 + verified strategic assets − key-person/single-operator discount`

- **Inputs needed from owner:** `MRR/ARR`, `monthly platform burn`, `support hours`, `refund/dispute reserve`, `tax/legal overhead`.
- **Current default posture for draft discussions:** conservative baseline should be set on evidence-backed numbers once owner data is attached.

#### D. Risk flags for sale conversation

- High: no verified revenue/cancel/refund ledger in this repo yet.
- High: BR-04/BR-05 auth continuity and BR-07/BR-12 provider/distribution runtime proofs are still blocked by owner/runtime dependencies.
- Medium: transfer inventory exists, but attachments + signatures are still pending for most rows.
- Medium: support burden and retention assumptions are not yet data-backed.

#### E. Owner next-step commitment for this memo

- Mark this section as **“owner-provided draft ready”** when the missing exports are attached.
- This memo moves from draft to signed handoff only after these minimums are added in one place:
  1. MRR/ARR + refund/dispute snapshot,
  2. 30/90-day usage trend signal,
  3. support volume + unresolved ticket signal,
  4. finalized transfer inventory for domains/accounts/store/build credentials.

## 8) BR-13/BR-14 execution playbook (solo-founder sequence)

Use this as the owner-owned sequence to move the commercial/readiness leg from `in progress` to `done`.

- [x] Normalize transfer scope and valuation model to app-only (non-enterprise) assumptions.
- [x] Attach BR-14 non-secret legal/docs evidence bundle with hashes.
- [x] Add source handoff metadata and commit snapshot at `docs/review/evidence-transfer/source/source_handover_notes_2026-07-25.md`.
- [x] Add analytics handoff evidence bundle (`docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md`).
- [x] Add ownership/IP transfer packet scaffold (`docs/review/evidence-transfer/ownership/ownership_ip_transfer_packet_2026-07-25.md`).
- [x] Add commercial/liabilities transfer packet scaffold (`docs/review/evidence-transfer/commercial/commercial_liabilities_transfer_packet_2026-07-25.md`).
- [ ] Collect and attach entity + IP ownership evidence.
- [ ] Collect and attach commercial and liabilities evidence.
- [x] Add one-page valuation memo (revenue/usage trend, feature footprint, risk flags).
- [x] Attach OSS/dependency obligations bundle (`docs/review/evidence-transfer/dependencies/dependencies_oss_obligations_bundle_2026-07-25.md`).
- [x] Collect and attach transfer inventory for accounts, domains, apps, and infrastructure.
- [x] Add buyer rehearsal plan and close with sign-off checklist.
- [x] Create BR-14 evidence staging area (`docs/review/evidence-transfer/`) with required subfolders.

### Valuation model (owner-only, no external advisories assumed)

Use this practical formula in-session:

```
Owner-value range = (Annualized maintainable net owner cash flow) × 1.8 to 4.2
                    + verified strategic assets (optional premium)
                    − key-person/single-operator discount
```

Suggested starter bands for this app class:

| Scenario | Inputs | Indicative value |
|---|---|---|
| Conservative | `0–1x` gross margin, unstable support model, key-person risk high | `~0.5x–1.5x` of annual maintainable net cash flow |
| Balanced | `1.5–2.5x` gross margin, mostly documented support, moderate continuity risk | `~1.5x–3x` of annual maintainable net cash flow |
| Premium | `>2.5x` margin, minimal churn, documented process automation, low key-person dependency | `~2.5x–4.5x` of annual maintainable net cash flow |

This model is intentionally owner-lean: it values continuity and operational handoff quality as much as product features.

## 7) Current action status (session)

- **Current active item:** BR-13/BR-14 transaction-readiness preparation (owner-owned; legal-counsel engagement is optional unless explicitly requested).
- **Current blockers:** production/runtime proofs for BR-07/BR-08/BR-09/BR-12 and owner-provided commercial/account transfer records.
- **Next checks to unlock next item:**
  1. Attach current evidence links for Sections 1–3.
  2. Run signed-off handover rehearsal with the selected buyer process owner.
