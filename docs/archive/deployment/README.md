# Archived Deployment Material

This directory is the preservation index for deployment guidance from earlier
product phases. No historical document has been deleted. These records explain
previous decisions and may contain useful migration evidence, but they are not
the current launch instructions.

## Canonical current guidance

Use [`docs/planning/coverwise_long_term_platform_decision_2026-07-12.md`](../../planning/coverwise_long_term_platform_decision_2026-07-12.md)
for the CoverWise solo launch. The earlier Firestore proposal is preserved in
[`docs/planning/coverwise_platform_architecture_decision_2026-07-12.md`](../../planning/coverwise_platform_architecture_decision_2026-07-12.md),
and the earlier Railway comparison is preserved in
[`docs/planning/deployment_decision_2026-07-12.md`](../../planning/deployment_decision_2026-07-12.md)
with an explicit supersession addendum.

## Preserved historical records

- [`docs/technical/deployment/deployment_guide.md`](../../technical/deployment/deployment_guide.md): former AWS App Runner deployment procedure.
- [`docs/technical/deployment/aws_migration_complete.md`](../../technical/deployment/aws_migration_complete.md): 2025 Azure-to-AWS migration history.
- [`docs/technical/deployment/solo_founder_cost_optimization_2026-07-11.md`](../../technical/deployment/solo_founder_cost_optimization_2026-07-11.md): prior App Runner cost-reduction direction, superseded by the Railway decision.
- Other Azure/AWS troubleshooting and migration documents in `docs/technical/deployment/`: historical investigation material unless a document explicitly links back to the current decision.

## Agent rule

When deployment questions arise, read the current decision first. Read archived
documents only to understand prior constraints or recover evidence. Do not copy
old provider names, URLs, scripts, prices, credentials, or “production ready”
claims into new work without re-validating them against the current deployment
decision and live environment.

## Why this archive exists

The earlier AWS/Azure work is valuable engineering history and may contain
migration lessons, cost assumptions, and rollback context. It is kept intact
so future agents can understand what changed without mistaking historical state
for the current solo-product architecture.
