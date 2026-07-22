# ADR-2026-07-21-07 — Reconcile the remote Supabase migration ledger before normal pushes

**Date:** 2026-07-21  
**Status:** Accepted for implementation  
**Scope:** Supabase schema release safety and rollback evidence

## Decision

Treat the live remote schema and the repository migration directory as two
separate facts until an explicit baseline reconciliation is completed. Do not
insert fabricated rows into `supabase_migrations.schema_migrations`, and do not
run an unreviewed `supabase db push` against the CoverWise project.

Until reconciliation, every remote schema change must use the documented,
reviewed Management API migration path or an equivalently reviewed database
change, and the read-only parity audit must pass before release work proceeds.

## Context

The remote project already contained the application schema, but its migration
ledger did not contain the repository's historical migration set. The current
read-only audit now confirms parity across 46 tables, added columns, public
functions, indexes, and triggers. The ledger contains only generated entries
for the migrations applied during this closure session, not a complete mirror
of the 44 repository migration files.

This is not a current table-availability failure. It is a release and rollback
failure mode: a future migration runner could attempt to replay already-applied
objects, or a rollback operator could misread the ledger as the schema's actual
provenance.

## Options considered

1. **Insert all local versions directly into migration history.** Rejected: it
   would assert execution/provenance without proving each migration's exact
   remote effect.
2. **Run `supabase db push` and resolve conflicts live.** Rejected: this is an
   uncontrolled production mutation with unclear partial-failure and rollback
   behavior.
3. **Keep applying exact reviewed migrations through the Management API while
   auditing object parity, then reconcile the baseline under review.** Chosen:
   it closes known contract gaps without fabricating history and preserves an
   auditable trail of each change.
4. **Rebuild the project from scratch.** Rejected: unnecessary data and
   identity risk while the live object surface is already correct.

## Validation performed

`tools/audit_supabase_migration_parity.py` performs a read-only comparison of
repository-declared tables, added columns, public functions, indexes, and
triggers. The current report has no missing objects. The canonical
`tools/verify_supabase_schema.py` also passes, and focused backend tests cover
the affected outbox, billing, entitlement, and deletion contracts.

## Reconciliation plan

1. Export remote object definitions, policies, constraints, and function
   definitions through a read-only connection or reviewed database export.
2. Compare them with every repository migration and record any semantic drift,
   not merely object-name parity.
3. Choose one reviewed baseline strategy: a checked-in baseline/squash for new
   environments plus an explicit remote history repair, or a fully replayable
   migration ledger with proven idempotence.
4. Apply the chosen history repair with DBA/operator approval and verify a
   clean-database replay plus an upgrade replay before re-enabling routine CLI
   pushes.

## Rollback and revisit triggers

No history repair is performed by this ADR. Each reviewed remote migration is
transactional and must be followed by the parity audit. Revisit this decision
when the baseline comparison is complete, when a clean replay is proven, or if
the remote project is replaced with a newly provisioned project whose ledger
starts from the repository baseline.

## Anything else?

Yes: object-name parity is necessary but not sufficient. The reconciliation
must also compare column types/defaults, constraints, RLS policies, grants,
function bodies/signatures, indexes, triggers, extensions, and Storage
policies. A clean migration-history count alone is not acceptance evidence.

## Related evidence

- `tools/audit_supabase_migration_parity.py`
- `tools/verify_supabase_schema.py`
- `docs/review/launch_execution_status_2026-07-21.md`
- `docs/review/exploration_map.md`

## Addendum (2026-07-21)

The live project now has 12 generated migration-history rows after the
reviewed corrective and advisor-hardening migrations; the repository contains
47 migration files. The history mismatch therefore remains open by design.
The stronger semantic checks now cover normalized function bodies, explicit
named constraints, policy identities, and live function/policy metadata. A
local clean replay produces `supabase db diff --local` → `No schema changes
found`, which is evidence for local convergence, not proof that the remote
historical provenance has been reconstructed.

The same semantic audit then found that the remote `source_spans` CHECK
constraint still used the pre-CIR vocabulary. The exact
`20260721160000_source_span_capability_types.sql` migration was applied via
the reviewed Management API path. The parity tool now compares CHECK
definitions as well as constraint names, canonicalizing PostgreSQL's
equivalent `IN`/`ANY(ARRAY[...])` rendering. Current semantic parity is green.

## Addendum (2026-07-21 — migration timestamp collision)

The local shadow replay then exposed duplicate migration versions introduced by
parallel work: three new files reused timestamps already occupied by unrelated
migrations. The migration contents were preserved and the three filenames were
renamed to unique ordered versions (`20260721260100`, `20260721260200`, and
`20260721260300`). This is a reversible filename hygiene correction, not a
schema mutation; it restores Supabase's one-version-per-migration invariant
for clean replay and future environments.

## Addendum (2026-07-21 — current remote contract closure)

The parity audit found three current repository contracts that were not yet
remote: the ordered RevenueCat pack-event function body, the service-role-only
`get_qa_pack_balance` RPC, and the anonymous-to-account ownership-transfer
function body. The exact reviewed migrations
`20260721260100_revenuecat_pack_event_ordering.sql`,
`20260721260200_qa_pack_balance_readback.sql`, and
`20260721260300_identity_pack_transfer.sql` were applied transactionally via
the Management API. Post-apply parity reports no missing or mismatched local
objects/configurations; the remote ledger now has 16 generated rows while the
repository contains 51 migration files. The ledger warning remains open and
must not be repaired by inserting fabricated history.

The extension placement and function search-path hardening were subsequently
verified with a transactional local compatibility experiment and applied as
reviewed additive migrations. Both `vector` and `pg_trgm` now live in the
existing `extensions` schema; retrieval functions use `extensions, public`.
This closes the local Supabase advisor warnings without changing the
migration-ledger reconciliation decision.
