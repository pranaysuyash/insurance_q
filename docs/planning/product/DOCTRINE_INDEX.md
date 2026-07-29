# Doctrine Index — precedence and quick navigation

**Status:** Proposed, awaiting operator sign-off on [ADR-2026-07-29-02](../../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
**Date:** 2026-07-29
**Purpose:** A new agent should understand the doctrine hierarchy and the comparison/claims boundary within five minutes.

---

## The doctrine stack (top wins conflicts)

```text
1. motto_v4.md                                        Operating rules (always top)
   └─ 2. Product constitution                         What the product IS and refuses to be
        └─ 3. First-principles wedge & strategy        Current strategy and wedge
             └─ 4. Free vs paid commercial boundary     Packaging and pricing (Proposed)
                  └─ 5. Feature ADRs                    Per-feature decisions
                       └─ 6. Architecture, code, tests, ops, launch claims
```

A lower layer may not contradict a higher layer. Where a lower layer currently does, the higher layer governs and the lower layer is corrected by dated addendum.

---

## Layer 1 — Operating rules

- [`motto_v4.md`](../../../motto_v4.md) — engineering/agent operating rules, evidence tiers, ADR schema, decision-record requirements.

## Layer 2 — Product constitution (Proposed)

- [`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`](./PRODUCT_FIRST_PRINCIPLES.md) — canonical product statement, the five-gate stack (Gates A-E), twelve principles, the wedge table, the product decision test, anti-principles.

## Layer 3 — Strategy & current wedge (Proposed)

- [`docs/architecture/FIRST_PRINCIPLES_WEDGE.md`](../../architecture/FIRST_PRINCIPLES_WEDGE.md) — comprehension outcome, onboarding-friction reframing, coverage-summary-first hypothesis, cut/keep/finish summary. Subordinate to the constitution.

## Layer 4 — Commercial & packaging (Proposed)

- [`docs/architecture/FREE_VS_PAID_BOUNDARY.md`](../../architecture/FREE_VS_PAID_BOUNDARY.md) — free baseline, paid candidates, tier definitions, per-feature classification. All exact prices/limits are Proposed hypotheses pending operator approval + sourcing. Does NOT redefine the product boundary.

## Layer 5 — Feature ADRs

- [`docs/decisions/README.md`](../../decisions/README.md) — decision index.
- Reconciliation ADR: [`ADR-2026-07-29-02`](../../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md) (Proposed) — establishes this stack and resolves conflicts between the older Principles/Wedge drafts.

## Layer 6 — Architecture, journey, claims

- [`docs/architecture/coverwise_canonical_architecture.md`](../../architecture/coverwise_canonical_architecture.md) — the system map.
- [`docs/user_experience/coverwise_user_journey_map.md`](../../user_experience/coverwise_user_journey_map.md) — the journey map.
- [`docs/launch_claims/README.md`](../../launch_claims/README.md) — launch-claim registry (claims are contracts with tests, not adjectives).

---

## The five-minute boundary test

If you only read three things before making a product-boundary decision:

1. **[Product Constitution §1](./PRODUCT_FIRST_PRINCIPLES.md)** — the canonical statement ("private, source-verifiable... does not recommend, quote, underwrite, broker, transact, or represent claims").
2. **[Product Constitution §3 Gate C](./PRODUCT_FIRST_PRINCIPLES.md)** — does the activity stay within explanation/evidence/organisation/retrieval/reminders/recordkeeping?
3. **[ADR-2026-07-29-02 §4](../../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md)** — the thirteen conflict resolutions (especially §4.1 comparison and §4.4 claims).

### Quick boundary rules

- **"Not found" is never "not covered."** (Gate B; §4.3)
- **Neutral owned-policy comparison is IN; shopping comparison is OUT.** (§4.1)
- **Claims = policy-stated process + contacts + user records; NOT filing/representation/adjudication.** (§4.4)
- **Renewal = factual reminders; NOT "Start renewal" transactions.** (§4.5)
- **Comprehension is the free baseline; convenience/depth are paid candidates; exact prices are Proposed.** (§4.6, §4.7)
- **Demo policy and camera-first are strategy decisions (rejected for launch), not permanent principles.** (§4.9, §4.10)

---

## Update log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | Initial doctrine index created. Maps the layered stack and provides the five-minute boundary test. Status Proposed pending ADR-2026-07-29-02 sign-off. | ADR-2026-07-29-02 Phase 8 deliverable. |
