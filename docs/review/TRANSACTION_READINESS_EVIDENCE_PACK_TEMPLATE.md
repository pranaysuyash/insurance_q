# CoverWise transaction-readiness evidence pack

**Status:** template — completion evidence has not been supplied.  
**Owner:** Solo founder/operator.  
**Use:** populate this pack before representing CoverWise as an operating
business or offering it for sale. Do not place credentials, private keys,
customer documents, access tokens, or personal data in this repository.

## Purpose and boundary

This pack separates a transferable software asset from a transferable
operating business. Repository code, local tests, and planning documents do
not prove ownership, account transferability, revenue, customer consent,
liabilities, or operational continuity.

The current product boundary is a personal policy-organising and
evidence-backed document-understanding tool. It is not an insurer, broker,
policy seller, claims administrator, or financial adviser. Any buyer-facing
description must keep that boundary intact.

## 1. Corporate, IP, and people

For each item, attach a redacted or externally stored reference, responsible
owner, date checked, and transfer constraint.

| Evidence | Required proof | Status | Owner | Reference / notes |
|---|---|---|---|---|
| Selling entity and authority | Entity registration, board/founder authority, tax status | Open | Founder/legal | |
| Source-code ownership | Founder, employee, contractor, and agency assignment agreements | Open | Founder/legal | |
| Open-source obligations | Approved licence policy, SBOM, exception register | Open | Engineering/legal | |
| Brand and domain rights | Domain registrant/export lock, trademark status, social handles | Open | Founder | |
| Third-party content/model rights | Provider terms, model/API contracts, document/test-corpus rights | Open | Founder/legal | |

## 2. Transferable technical estate

| Asset | Required proof | Status | Transfer approach |
|---|---|---|---|
| Source repository | Named canonical repository, protected-branch/export evidence, reproducible revision | Open | Buyer receives verified archive/transfer after diligence |
| Dependency supply chain | Current locked dependency graph, SBOM, vulnerability and licence review | Partially prepared | Use the canonical production lock and generated SBOM; founder review remains open |
| Cloud hosting | Cloud project inventory, billing owner, regions, deploy/runbook, transfer method | Open | Account owner confirms project transfer or rebuild plan |
| Supabase | Project ownership, migration parity, storage inventory, RLS verification, transfer method | Open | Account owner performs controlled access transfer; never export service keys into this pack |
| Mobile distribution | Apple/Google account ownership, signing provenance, package IDs, store listing/export plan | Open | Transfer through the platform’s official process |
| Observability and support | Sentry/alerting/support account inventory, retention, owner/on-call handover | Open | Rotate invites and verify alert delivery |
| Domains, email, SMS, payments | Account inventory, renewal dates, billing owner, offboarding plan | Open | Transfer/replace under controlled cutover |

## 3. Customer, commercial, and liability evidence

Provide aggregates and legally permitted exports; do not include customer
documents or credentials in this pack.

| Metric or obligation | Required evidence | Status | Notes |
|---|---|---|---|
| Acquisition | Channel, spend, installs, activation cohorts, attribution limits | Open | Distinguish measured facts from forecasts |
| Retention | D1/D7/D30 cohorts, active users, cancellation/deletion rate | Open | State cohort definition and data-start date |
| Revenue | Provider export, MRR/ARR, refunds, chargebacks, taxes, deferred revenue | Open | Reconcile to bank/accounting records |
| Unit economics | Hosting/model/support cost, gross margin, owner compensation assumptions | Open | Separate cash cost from founder labour |
| Support and quality | Support volume/SLA, incidents, privacy requests, unresolved defects | Open | Include material known issues and remediation status |
| Customer agreements | Terms/privacy versions, consent and retention evidence, data-processing commitments | Open | Founder confirms the published wording and operational commitments |
| Pending liabilities | Refunds, credits, chargebacks, disputes, regulatory notices, vendor minimums | Open | Disclose zero only with supporting records |

## 4. Security, privacy, and continuity

- Record credential rotation/revocation using
  `docs/review/CREDENTIAL_ROTATION_ATTESTATION_TEMPLATE.md`; store provider
  evidence outside the repository.
- Record the live two-principal and deletion checks required by BR-04/BR-05.
- Attach deployment, worker-recovery, payment-webhook, and real-device/store
  evidence only after it has been observed in the named environment.
- Create a buyer-access plan with least privilege, time-bounded access, an
  audit log, and a cutover/rollback owner. Do not hand over the seller’s
  personal credentials.

## 5. Handover rehearsal

Before closing, run a controlled rehearsal in a non-production or agreed
staging environment:

1. Buyer receives the approved source revision and reproduces the documented
   local verification baseline.
2. Buyer assumes least-privilege access to a non-production cloud/Supabase
   project and verifies the deployment and migration runbook.
3. Seller demonstrates account ownership transfer or a documented rebuild
   path for every non-transferable service.
4. Seller and buyer reconcile customer-data, deletion, support, refund, and
   outstanding-liability inventories.
5. Both parties sign the final asset/account inventory, cutover time, and
   rollback contacts.

## Acceptance record

| Gate | Evidence date | Reviewer | Result | Residual risk / closure action |
|---|---|---|---|---|
| IP and entity authority | | | Open | |
| Account/domain/store transferability | | | Open | |
| Security/privacy and credential cutover | | | Open | |
| Commercial and liability reconciliation | | | Open | |
| Reproducible technical handover | | | Open | |
| Buyer cutover rehearsal | | | Open | |

## Evidence tier

This template is Tier 1 process preparation only. It becomes transaction
evidence only when the named owner attaches current, reviewable proof and the
acceptance record is signed. It does not establish valuation by itself.
