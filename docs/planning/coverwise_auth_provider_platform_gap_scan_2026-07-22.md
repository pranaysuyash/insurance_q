# CoverWise auth-provider platform gap scan (2026-07-22)

**Date:** 2026-07-22  
**Scope:** Auth + retrieval + training + portability evidence; docs-vs-runtime alignment in one place  
**Primary control plane:** `docs/architecture/coverwise_canonical_architecture.md` + `docs/decisions/ADR-2026-07-22-08-auth-and-provider-platform-strategy.md`

## 1) Plan lock (docs-first pass completed)

Before touching runtime behavior, we lock documentation behavior in four lanes:

1. **Auth contract lane** — ensure only Supabase Auth is active source-of-truth in user-facing/docs.
2. **Auth evidence lane** — close live auth lifecycle proof gaps.
3. **Retrieval lane** — close hybrid retrieval + embedding-contract proof gaps.
4. **Portability lane** — document self-hosted/OSS migration and cutover runbook only after above are stable.

This pass is documented and constrained; no runtime architecture change is proposed in this document.

## 2) What is still active vs historical (doc coherence audit)

The following references were found to either:
- claim Firebase as an active auth contract,
- or carry mixed historical/active signals that can mislead future implementation decisions.

### 2.1 Active-auth confusion candidates (needs canonical annotation)

| Doc | Line(s) to normalize | Why it is a problem |
|---|---|---|
| *(none remain after this pass)* | — | — |

### 2.2 Historical-but-needs-a-clearer-legacy-callout files

- These are intentionally historical for architecture-learning context; keep a one-line legacy status at each section boundary where Firebase appears:
  - `docs/planning/product/security/mobile_security_architecture.md`
  - `docs/planning/product/technology_stack_recommendation.md`
  - `docs/reference/api_documentation/api_specification.md`
  - `docs/technical/system_architecture/comprehensive_architecture.md`
  - `docs/technical/architecture/current_system_architecture.md`

This pass has closed the two user-facing active-auth confusion candidates in this list:

- `docs/planning/product/implementation_roadmap.md`
- `docs/planning/prd_insurance_policy_app.md`

### 2.3 Already-canonical/historical mismatch reminders (no new work)

- `docs/technical/system_architecture/comprehensive_architecture.md`, `docs/technical/architecture/current_system_architecture.md`, `docs/technical/modern_stack_overview.md` are historical snapshots but contain legacy claims. They now should only be used for provenance and migration learning.
- `docs/technical/data_storage/data_storage_and_management.md` and `docs/planning/product/technology_stack_recommendation.md` contain historical references that should remain but be scoped as legacy context.

## 3) Runtime closure gaps (evidence-first)

### 3.1 P0 gaps

| ID | Capability | What must be proven | Current status |
|---|---|---|---|
| AUTH-01 | Supabase auth lifecycle | Live matrix for sign-up, confirm, sign-in, refresh, claim-transfer, sign-out, recovery, delete, export on a configured project | **Open** |
| RETR-01 | Hybrid retrieval parity | Representative-corpus dense+FTS run + precision/latency delta + duplicate handling | **Open** |
| RETR-02 | Embedding contract safety | Provider/model family compatibility gate + fail-closed behavior on mismatched dimensions + re-embed rollback checkpoint | **Open** |

### 3.2 P1 gaps

| ID | Capability | What must be proven | Current status |
|---|---|---|---|
| TRAIN-01 | Provider execution/training | Credentialed run + manifest + artifact checksums + evaluator output package | **Open** |
| ASYNC-01 | Async paths + deletion lifecycle | Reproducible recovery for `qa_response`, `claim_verification`, `renewal_diff` + account deletion/storage/consent postconditions | **Open** |

### 3.3 P2 gaps

| ID | Capability | What must be proven | Current status |
|---|---|---|---|
| PORT-01 | Portability playbook | Self-hosted Supabase rehearsal: auth export/import, RLS parity replay, storage restore, rollback/failback notes | **Open** |

## 4) Ordered close sequence (no architecture debt)

1. **Close doc coherence first** (this doc and addendums).
2. **AUTH-01** live auth evidence.
3. **RETR-01 + RETR-02** parity and embedding contract evidence.
4. **TRAIN-01 + ASYNC-01** operational evidence.
5. **PORT-01** portability runbook after above are stable.

## 5) Evidence contract for this doc

- **Authoritative sources for decision**:
  - `docs/decisions/ADR-2026-07-22-08-auth-and-provider-platform-strategy.md`
  - `docs/planning/coverwise_auth_and_provider_execution_plan_2026-07-22.md`
  - `docs/planning/coverwise_auth_provider_platform_gap_map_2026-07-22.md`
  - `docs/review/coverwise_supabase_gap_register_2026-07-16.md`
  - `docs/review/coverwise_supabase_cutover_report_2026-07-21.md`
- **Do-not-accept proofs**:
  - Static file presence only, without live run logs.
  - Any claim that references Firebase auth as current production contract.
- **Close condition per closed item**: evidence entry added to gap register + referenced canonical run artifact.
