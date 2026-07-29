# ADR-2026-07-24-02: Claims are a personal log, not insurer workflow

## Status

Accepted for implementation.

## Decision

CoverWise records a user's private, self-reported claim notes and status
history. It does not submit claims, obtain insurer updates, adjudicate a
claim, guarantee payment, or act through an insurance adviser or agent.

Every customer-visible claim status is labelled `Recorded as ...`, and the
timeline is explicitly a user-recorded history. The API rejects agent
provenance fields, normalizes historical rows before returning them, and the
database migration fences new agent-originated rows while preserving historical
columns and data for compatibility.

## Context

The original claims API and migration described agent-initiated claims and
displayed bare `Approved` and `Paid` states. Those semantics could reasonably
be interpreted as CoverWise or an insurer operating a claim workflow. That is
outside the product boundary and cannot be supported with the available
insurer integrations or evidence.

## Options considered

1. Keep agent-originated records and bare decision labels. Rejected: implies a
   regulated workflow and insurer-sourced truth that CoverWise does not have.
2. Remove the complete claim-log feature. Rejected: users still benefit from a
   private log of documents, reference numbers and their own follow-up notes.
3. Preserve the claim log, make provenance explicit, and fence unsupported
   workflow semantics. Chosen.

## Implementation and validation

- `src/api/claims.py` owns only self-reported records and discards retired
  agent provenance from responses.
- `src/models/claim.py` rejects agent fields in create requests.
- `supabase/migrations/20260724010000_claim_log_boundary.sql` prevents new
  agent-originated rows without rewriting old data.
- The mobile log, status picker, timeline and dashboard chips use
  `Recorded as ...` labels.
- Tier 2 evidence: 13 focused backend checks and 41 focused Flutter checks
  pass; targeted Flutter analysis is clean.
- Tier 3 remains open: run an authenticated account sync against the deployed
  backend and confirm a user can create, amend and delete only their own log.

## Risks, rollback and revisit

The main migration risk is legacy rows with agent fields. The new check is
`NOT VALID`, so existing history is preserved while every new or updated row
must meet the user-only contract. Roll back by reverting the application
deployment and migration only if the personal-log flow is broken; do not
restore agent/broker semantics without a separately approved insurer workflow,
legal review, source-of-truth integration and audit trail.

Revisit if CoverWise obtains a contractual insurer integration with authoritative
status events, consent, role controls, idempotency, auditability and legal
approval. Owner: product and engineering.

## Anything else?

No local label makes a user-entered record insurer truth. The device and API
must continue to distinguish personal notes from verified external events.

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | **Reaffirmed per [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) §4.4.** Personal claim log boundary stands: user-entered records with `Recorded as ...` states; not insurer status, claim management, filing, adjudication, or representation (Gate C). Original reasoning preserved. | Operator direction: layered doctrine stack. |


---

## Doctrine reconciliation note (2026-07-29)

> Append-only note added 2026-07-29. This section does not modify any prior
> content in this ADR; the original decision, reasoning, and existing update
> logs above remain intact and authoritative for their date.

- **Date:** 2026-07-29
- **Governing ADR:** [ADR-2026-07-29-02 (doctrine stack reconciliation)](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
- **What changed:** [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) establishes a layered doctrine stack. The [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) (`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`) now sits above feature ADRs, with a five-gate stack (Gates A-E: Outcome, Truth, Product role, Lifecycle, Strategy/commercial). Reaffirmed (§4.4): personal claim log boundary stands - user-entered records with 'Recorded as ...' states; not insurer status, claim management, filing, adjudication, or representation (Gate C).
- **Why:** Operator direction to unify two competing uncommitted first-principles documents into one layered stack before any boundary-shaped code changes.
- **What triggered it:** Discovery that the repository held conflicting uncommitted doctrine (Principles vs Wedge) and that ADR-2026-07-29-01 self-declared "Accepted" without sign-off evidence.
- **What original reasoning remains valid:** All prior reasoning in this ADR is preserved unchanged. This note only constrains surface semantics where they intersect the constitution's gates.
- **Status change for this ADR:** None (this ADR's own status is unchanged by this note).
- **Operator sign-off:** None required for this note; it records the reconciliation linkage. The reconciliation ADR itself remains Proposed pending operator sign-off.
- **Code authorization:** None. No code, route, entitlement, pricing, comparison, claims, renewal, camera, demo, or onboarding change is authorized by this note.
