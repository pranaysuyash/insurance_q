# ADR-2026-07-24-07: Refund reversal restores a currently valid entitlement

## Status

Accepted for implementation.

## Decision

Treat RevenueCat `REFUND_REVERSED` as an entitlement-restoring lifecycle event,
but only when the provider-reported expiration is still in the future (or the
provider supplies no expiration). `EXPIRATION` remains the event that revokes
access. Apply the same decision in the local compatibility webhook handler and
the canonical Supabase ledger function.

## Context

The local webhook handler classified `REFUND_REVERSED` as a revocation event.
The Supabase ledger function fell through to inactive for that event type. This
could deny a paid user access after a provider reverses a prior refund. It also
made the local and remote paths disagree on whether active lifecycle events
must honor an already-past provider expiration.

RevenueCat's current webhook documentation describes `REFUND_REVERSED` as a
refund being reversed and identifies provider timestamps as the ordering
signal. A refund reversal does not authorize CoverWise to invent an access
period, so the existing provider expiry remains the gate.

## Options considered

1. Continue treating `REFUND_REVERSED` as revoked. Rejected: it contradicts
   the provider lifecycle meaning and can deny valid paid access.
2. Always restore access on `REFUND_REVERSED`. Rejected: it can revive an
   already-expired entitlement when a delayed event carries an expired period.
3. Restore only through a future/no-expiry provider entitlement and preserve
   provider timestamp ordering. Chosen.

## Implementation and validation

- `src/api/subscription.py` now classifies `REFUND_REVERSED` as active only
  through the reported expiration; all active lifecycle events use the same
  expiry rule in the local compatibility path.
- New forward migration
  `supabase/migrations/20260724000000_revenuecat_refund_reversal_semantics.sql`
  replaces the canonical ledger function without rewriting historical
  migrations.
- A webhook regression test covers future-expiry restoration and past-expiry
  non-restoration. Billing ledger, webhook/outbox, and QA usage contracts
  plus migration-parity contracts report **30 passed** locally (Tier 2).

## Risks, rollback and revisit

This remains local/provider-contract evidence. A real store and RevenueCat
sandbox exercise must confirm the received event payload, timestamp ordering,
ledger writeback, and user-visible entitlement after a platform-supported
refund reversal. If provider documentation or observed payload semantics
change, revisit this ADR and update the explicit event classification rather
than adding a client-side override.

Rollback requires a new reviewed forward migration and a corresponding handler
change; do not edit or remove an already applied ledger migration. Owner:
engineering with RevenueCat/store account-owner verification.

Provider references:
[RevenueCat webhook event types and fields](https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields)
and [common webhook flows](https://www.revenuecat.com/docs/integrations/webhooks/event-flows).
