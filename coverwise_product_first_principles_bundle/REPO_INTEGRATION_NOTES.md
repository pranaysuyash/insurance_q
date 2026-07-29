# Repository integration notes

Prepared against `pranaysuyash/insurance_q` `main` at:

```text
755df24be171b87fc1d5f66eceb25d3909d2784d
```

No repository mutation was performed while preparing this bundle.

## Destination paths

Copy the files to:

```text
docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md
docs/decisions/ADR-2026-07-28-03-product-first-principles-and-boundary.md
```

## Before committing

1. Re-check `main`, because parallel work may have landed.
2. Confirm `ADR-2026-07-28-03` is still unused. At the inspected head, only `ADR-2026-07-28-01` and `ADR-2026-07-28-02` existed.
3. If `03` has been taken, rename the ADR to the next free sequence and update:
   - its title;
   - the product document's `Decision record` link;
   - the decision-index entry below.
4. Review and sign off the ADR. Until then its status should remain `Proposed`.
5. Preserve existing ADR history. Add update-log entries to conflicting ADRs instead of rewriting their original decisions.

## Suggested decision-index entry

Add the following to `docs/decisions/README.md` after confirming the final ADR number:

```markdown
| ADR-2026-07-28-03 | 2026-07-28 | Adopt one canonical product-first-principles doctrine: private, source-verifiable understanding and organization of user-owned policies; no advice, quoting, underwriting, claims representation, ranking, selling, or transaction facilitation by default | Proposed, awaiting operator sign-off | [link](./ADR-2026-07-28-03-product-first-principles-and-boundary.md) |
```

## Suggested canonical cross-links

Add a short link to `PRODUCT_FIRST_PRINCIPLES.md` from:

```text
README.md
docs/architecture/coverwise_canonical_architecture.md
docs/user_experience/coverwise_user_journey_map.md
docs/review/exploration_map.md
```

## Suggested commit message after sign-off

```text
docs: establish canonical product first principles and boundary
```

The implementation and surface-gating work should be separate gated commits, as described in the ADR.
