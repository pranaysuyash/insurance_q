# ADR-2026-07-22-08: Identity + RAG platform strategy (managed Supabase first, open-source paths next)

**Status:** Accepted (2026-07-22)
**Owner:** Codex session 2026-07-22  

## Decision

For this phase, CoverWise will use **managed Supabase as the canonical identity + data + storage platform** (Auth, Postgres/pgvector, Storage, RPC/RLS), and **not** use Firebase as a production identity/data source. We will keep open-source migration paths explicit and testable:

1. Primary: managed Supabase + Supabase Auth + managed Postgres/Storage (current code path).
2. Open-source parity path: self-hosted Supabase stack (OSS components with the same API contract) when operational control, compliance posture, or cost pressure requires it.
3. Alternative split path (future only): Postgres/pgvector + separate open-source auth and vector service when the product outgrows Supabase's integrated control plane and can absorb the migration work.

## Context

- The current architecture is contract-driven around:
  - Supabase `auth.uid()`-based RLS policies on business tables,
  - SQL RPC boundaries for retrieval, analytics, subscriptions, and auth lifecycle,
  - append-only consent and evidence lineage in Postgres.
- Firebase Auth would introduce a second identity plane and a deterministic mapping layer to the same Postgres-owned ownership model, creating a durable migration seam for every account path, document ownership check, and consent update.
- The product objective is not "one-vendor forever" but **one durable production control plane now** with a controlled transition plan.

## Options considered

### Option A — Firebase Auth + Supabase/Postgres (rejected for now)

Pros: strong mobile-native ecosystem, robust auth features, known docs.

Cons:

- Identity plane becomes second-system (`Firebase UID -> internal user mapping`) and cannot reuse current RLS assumptions without adapter code.
- Additional data-loss and replay risks around anonymous-to-account transfer and consent propagation.
- Retrieval/training contracts stay in Postgres, but auth events and policy scope now span two systems.

### Option B — Managed Supabase only (chosen)

Pros:

- One control plane for auth, ownership scope, RPCs, storage policy, and durable lineage.
- No additional identity migration layer for existing code paths.
- Existing retrieval and training tables (pgvector + FTS + candidate/evidence tables) are already implemented on this control plane.
- Strong evidence for the user/operator story: same request path, single audit boundary.

Cons:
- Vendor dependency for managed operations.
- Cost predictability depends on project-specific Supabase pricing and growth.

### Option C — Self-hosted Supabase stack (OSS parity path)

Pros:
- Same contract model as Option B (Auth, Postgres, Storage, PostgREST) when run with the official OSS stack.
- Operational and regional control retained.

Cons:
- Required operations work (db upgrades, backup posture, scaling, SMTP, networking, observability).
- Migration from managed to self-hosted needs a controlled cutover runbook to avoid auth and RLS drift.

### Option D — Split OSS architecture (Postgres/pgvector + separate auth/vector service)

Pros:
- Maximum component independence and vendor portability.

Cons:
- Requires explicit rewrites in auth verification, storage policy enforcement, and query contracts.
- Harder to guarantee the same RLS and outbox semantics without re-implementing them at the service layer.
- Increased blast radius for feature velocity on retrieval/search and training rollout.

## Why this path

The long-term requirement is not “avoid all managed dependencies”; it is to preserve correctness for auth ownership, retrieval evidence, and user-owned deletion while allowing progressive control-plane migration later.

Managed Supabase currently gives the strongest correctness-to-speed ratio:

1. Fastest path to full launch controls (Auth+RLS+Storage+pgvector) in one plane.
2. Lowest architecture refactor debt for the current canonical code.
3. A clear, staged migration path to self-hosted OSS that reuses the same SQL and job contracts.

## Tradeoffs

- We accept vendor coupling in managed operations to remove integration risk now.
- Migration complexity is deferred, but documented as a first-class future path.
- Firebase auth code can remain as compatibility-only and must not become the source of truth for web/product policy flows.

## Assumptions

1. The team can tolerate managed dependency risk for launch.
2. Retrieval/search and training remain centered on Postgres contracts already implemented in this codebase.
3. The product will not run regulated workflows that force immediate full on-prem control.

## Risks

- Vendor policy or pricing changes can alter unit economics.
- If auth volume grows quickly, rate limits or regional constraints may require earlier migration to a control plane you host.
- The split OSS architecture is a meaningful refactor and should only be executed if it reduces net risk, not as a side-project.

## Validation plan

- This ADR is a product-strategy decision; implementation validity is verified in product readiness checks:
  - auth/account conversion evidence,
  - retrieval retrieval evidence (hybrid FTS + pgvector),
  - consent withdrawal propagation,
  - outbox recovery.
- A future platform migration plan must include an identity parity audit and RLS parity replay before cutover.

## Rollback / migration path

- Rollback for this decision is not code-level; it is platform-level:
  - stay on managed Supabase if self-hosted migration is not completed cleanly,
  - or revert to Firebase-only experimentation only in non-production migration branches, with no production user traffic.
- Migration to self-hosted Supabase requires:
  1) identity export/import rehearsal,
  2) policy/RLS parity replay,
  3) storage migration validation,
  4) billing/event/webhook replay test.

## Revisit triggers

- Revisit when one of these becomes true:
  - managed Supabase cost or compliance constraints dominate launch economics,
  - data residency or ops policy requires self-hosted control plane,
  - auth/authorization requirements expand beyond current Supabase Auth envelope.

## Related evidence and links

- `docs/architecture/coverwise_canonical_architecture.md`
- `docs/review/coverwise_supabase_gap_register_2026-07-16.md`
- `docs/review/coverwise_supabase_cutover_report_2026-07-21.md`
- `docs/decisions/ADR-2026-07-21-03-guest-first-account-conversion.md`
- `docs/decisions/ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md`

## Anything else

No Firebase production-path contract is accepted in this ADR. Existing Firebase references are compatibility or migration history and must not be treated as authoritative product contracts.

## Update log

No entries yet — original decision.

## Update log (2026-07-22)

- **2026-07-22 22:00 IST** — Decision locked for implementation planning as the production baseline:
  - **Accepted architecture:** managed Supabase as the canonical control plane for identity, retrieval, storage, and async ownership.
  - **Firebase position:** historical compatibility/migration context only; not an active production contract.
  - **Next constraint:** close P0/P1 evidence gates (auth lifecycle, retrieval/embedding contract, and training/lineage execution) before user-facing launch claims expand.
