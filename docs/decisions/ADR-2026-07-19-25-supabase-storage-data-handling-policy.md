# ADR-2026-07-19-25: Supabase Storage data-handling policy — user documents stored in Supabase Storage in the operator's region, encrypted at rest, no public access

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Supabase Storage service that the product uses for user document storage (policies, claim documents, etc.) handles user data in the form of PDFs, images, and other files. The data-handling policy is explicit:** (1) the operator's Supabase account is bound by Supabase's terms of service and data-handling policy; (2) the data is stored in the operator's region (e.g. AWS Mumbai for Indian users); (3) the data is encrypted at rest using Supabase's encryption; (4) the data is not publicly accessible; all access is via authenticated, authorized API calls; (5) the data is transmitted over TLS; (6) the data is subject to Row Level Security (RLS) — every access is checked against the user's principal_id; (7) the launch-claim registry entry: "CoverWise stores user documents in Supabase Storage in the operator's region; the data is encrypted at rest; access is via authenticated, authorized API calls with RLS; the operator's Supabase account is bound by Supabase's data-handling policy." A CI test scans the Supabase client code for any code path that bypasses RLS, exposes a public URL, or sends data to a non-operator-region endpoint. The policy is the engineering answer to the audit's question of how the product uses third-party storage services.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** the Supabase Storage data-handling policy: operator's Supabase account is bound by Supabase's terms; data in operator's region; encrypted at rest using Supabase's AES-256; no public access (buckets are private); Row Level Security (RLS) per-document owner check; TLS in transit. The launch-claim registry entry is "CoverWise stores user documents in Supabase Storage in the operator's region; the data is encrypted at rest; access is via authenticated, authorized API calls with RLS; the operator's Supabase account is bound by Supabase's data-handling policy." A CI test scans the Supabase client code for non-TLS endpoints, public URL generation, RLS bypass, or non-operator-region endpoints. Implementation may begin in dependency order: bucket privacy verification → RLS verification → region verification → CI test → launch-claim registry entry. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-16](./ADR-2026-07-19-16-value-add-partnerships-framework.md) (the "data-handling policy per third-party integration" pattern), [ADR-2026-07-19-23](./ADR-2026-07-19-23-llm-provider-data-handling-policy.md) (the precedent), [ADR-2026-07-19-24](./ADR-2026-07-19-24-qdrant-vector-database-data-handling-policy.md) (the precedent).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Supabase Storage handles user documents. The data-handling policy: operator's account bound by Supabase's policy, data in operator's region, encrypted at rest, no public access, RLS, TLS in transit. The launch-claim registry entry. A CI test. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The Supabase Storage data-handling policy: operator's Supabase account is bound by Supabase's terms; data in operator's region; encrypted at rest using Supabase's AES-256; no public access (buckets are private); Row Level Security (RLS) per-document owner check; TLS in transit. The launch-claim registry entry is "CoverWise stores user documents in Supabase Storage in the operator's region; the data is encrypted at rest; access is via authenticated, authorized API calls with RLS; the operator's Supabase account is bound by Supabase's data-handling policy." A CI test scans the Supabase client code for non-TLS endpoints, public URL generation, RLS bypass, or non-operator-region endpoints. Implementation may begin in dependency order: bucket privacy verification → RLS verification → region verification → CI test → launch-claim registry entry.


---

## Context

The product uses Supabase Storage for user document storage. The documents are:
- Policy PDFs (uploaded by the user)
- Policy images (photographed by the user)
- Claim documents (per ADR-08 #3, the Claim Document Vault)
- Other files

The Supabase Storage data-handling policy is a first-class concern. The audit's question (per the security audit) is how the product uses third-party storage services and what guarantees the product has about the data.

This ADR defines the Supabase Storage data-handling policy. The policy is the engineering answer to the audit's question.

---

## The policy in detail

### 1. The operator's account is bound by Supabase's policy

- The operator has a Supabase account. The account is bound by Supabase's terms of service and data-handling policy.
- The policy is documented at supabase.com/privacy. The policy covers data retention, data access, data deletion, data residency, encryption.

**Verification:** the operator's Supabase account is reviewed. The policy is documented in the launch-claim registry entry.

### 2. Data stored in the operator's region

- The Supabase project is in the operator's region (e.g. AWS Mumbai for Indian users). The region is configurable; the default is the operator's primary region.
- The launch-claim registry entry names the region. The user can see the region in the settings page.

**Verification:** the Supabase client test asserts the project's region. The test fails if the region is not the operator's primary region.

### 3. Encrypted at rest

- The data is encrypted at rest using Supabase's encryption (AES-256). The encryption is enabled by default for all Supabase Storage buckets.
- The encryption keys are managed by Supabase (the operator does not manage the keys). The keys are rotated per Supabase's policy.

**Verification:** the Supabase project settings assert encryption-at-rest is enabled. The test fails if encryption is disabled.

### 4. No public access

- The Supabase Storage buckets are private. No public URLs are generated. All access is via authenticated, authorized API calls.
- The CI test scans the Supabase client code for any code path that generates a public URL (e.g. `createSignedUrl` with a long expiry, `getPublicUrl`). The test fails if a public URL is generated.

**Verification:** the Supabase project settings assert all buckets are private. The CI test scans for public URL generation.

### 5. Row Level Security (RLS)

- Every Supabase Storage access is checked against RLS. The RLS policy is: a user can read/write their own documents (where `owner_id = current_setting('app.current_principal_id')::uuid`).
- The RLS policy is enforced at the database level. The product's API code cannot bypass RLS (the database rejects the access).

**Verification:** the RLS policy is tested. The test fails if a user can read/write another user's documents.

### 6. TLS in transit

- All Supabase API calls are over HTTPS (TLS 1.2 or higher). The Supabase client enforces TLS.

**Verification:** the Supabase client test asserts that all API calls are over HTTPS.

### 7. The launch-claim registry entry

- "CoverWise stores user documents in Supabase Storage in the operator's region; the data is encrypted at rest; access is via authenticated, authorized API calls with RLS; the operator's Supabase account is bound by Supabase's data-handling policy."
- The entry names the region, the encryption, the RLS policy.

### 8. The CI test (the boundary)

- A CI test scans the Supabase client code for:
  - Non-TLS endpoints — the test fails.
  - Public URL generation — the test fails.
  - Code paths that bypass RLS — the test fails.
  - Non-operator-region endpoints — the test fails.
- The test is a release guard. A regression is caught before the launch.

---

## What ships in the meantime (the "minimum-viable privacy stance" for the Supabase Storage integration)

1. **TLS in transit** is enforced.
2. **Encrypted at rest** is enforced (Supabase's default).
3. **No public access** is enforced (buckets are private).
4. **RLS** is enforced (per-document owner check).
5. **The launch-claim registry entry** is added.
6. **The CI test** is added.

**What is deferred (when the operator revisits):**
1. The full Supabase data-handling policy review (the legal review is a separate workstream)
2. The user-facing explanation (a settings page that explains the Supabase data handling in plain language)
3. The per-document encryption (per ADR-15, the Claim Document Vault's per-document DEKs; this is a hardening, not a replacement for Supabase's encryption)

**When the operator revisits:** the three deferred components are the implementation checklist. The effort is S. 0.5-1 week.

---

## Anything else flagged

The "data-handling policy per third-party integration" pattern is now applied to:
- LLM providers (ADR-23, proposed)
- Qdrant vector database (ADR-24, proposed)
- Supabase Storage (this ADR, proposed)
- Value-Add Partnerships (ADR-16, accepted)

The pattern is well-established. Each ADR follows the same shape: explicit data-handling policy, no-share rule (where applicable), launch-claim registry entry, CI test. The full set is the third-party data-handling workstream.

The "data-handling policy per third-party integration" pattern is the engineering answer to the user's right to know who sees their data. The product's contract with the user is: "we will tell you who sees your data, and we will tell you how they handle it." The pattern enforces the contract.

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | **Reaffirmed per [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md).** Data-handling policy unchanged. Aligns with constitution Principle 5 (one principal owns complete information graph) and Principle 6. No semantic change. | Operator direction: layered doctrine stack. |


---

## Doctrine reconciliation note (2026-07-29)

> Append-only note added 2026-07-29. This section does not modify any prior
> content in this ADR; the original decision, reasoning, and existing update
> logs above remain intact and authoritative for their date.

- **Date:** 2026-07-29
- **Governing ADR:** [ADR-2026-07-29-02 (doctrine stack reconciliation)](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
- **What changed:** [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) establishes a layered doctrine stack. The [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) (`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`) now sits above feature ADRs, with a five-gate stack (Gates A-E: Outcome, Truth, Product role, Lifecycle, Strategy/commercial). Reaffirmed: data-handling policy unchanged. Aligns with constitution Principle 5 (one principal owns complete information graph) and Principle 6. No semantic change.
- **Why:** Operator direction to unify two competing uncommitted first-principles documents into one layered stack before any boundary-shaped code changes.
- **What triggered it:** Discovery that the repository held conflicting uncommitted doctrine (Principles vs Wedge) and that ADR-2026-07-29-01 self-declared "Accepted" without sign-off evidence.
- **What original reasoning remains valid:** All prior reasoning in this ADR is preserved unchanged. This note only constrains surface semantics where they intersect the constitution's gates.
- **Status change for this ADR:** None (this ADR's own status is unchanged by this note).
- **Operator sign-off:** None required for this note; it records the reconciliation linkage. The reconciliation ADR itself remains Proposed pending operator sign-off.
- **Code authorization:** None. No code, route, entitlement, pricing, comparison, claims, renewal, camera, demo, or onboarding change is authorized by this note.
