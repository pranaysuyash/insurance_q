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
