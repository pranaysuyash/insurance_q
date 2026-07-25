# ADR-2026-07-23-01: Evidence-backed policy readiness and coverage overview

## Status

Accepted for implementation in stages.

## Decision

CoverWise will retain its dashboard overview, coverage insights, tracked follow-up questions, and renewal reminders. These capabilities will be strengthened around a neutral, evidence-backed contract rather than removed.

The dashboard score becomes a measure of **policy workspace readiness**: how well the uploaded policy record is current, readable, extracted, and ready for the user to review. It is not a measure of whether a household has enough insurance, is financially protected, or should buy a product.

Coverage insights remain useful, but every insight must distinguish among:

- present in an uploaded policy, with a source citation where available;
- not found in the uploaded workspace, which is not proof that the user lacks coverage;
- not verified because extraction, pages, or fields are incomplete;
- conflicting values requiring user confirmation; and
- factual timing state such as expiring or expired.

The product may provide neutral next steps such as reviewing the source page, confirming a value, or asking the insurer a question. It must not recommend purchasing insurance, riders, amounts, or renewal as an insurance transaction. Reminder scheduling remains in scope, with copy that clearly describes a user-device reminder rather than an insurer notice or procurement workflow.

“Policy information assistant” is the canonical product role description. “Information broker” (when scoped to the user’s own policy information) is permitted in internal planning context only. It must not appear in user-facing copy or marketing materials. The product must not imply it is an insurance broker, agent, insurer, claims representative, recommendation service, or commission relationship.

## Context and first-principles reasoning

The durable product boundary is: user-owned policy -> extract -> cite -> explain -> organize -> remind. The user value is not reduced by refusing unsupported conclusions; it increases when the app shows what it knows, what it cannot verify, and what the user can do next.

The existing health score and coverage-gap surfaces contain valuable workflow structure, but some labels and rules infer adequacy or absence from incomplete workspace evidence. Removing the surfaces would discard useful organization and follow-through. Keeping them unchanged would weaken trust and create customer-facing claims the product cannot support. The correct long-term shape is to preserve the workflow while changing the contracts and data provenance underneath it.

## Options considered

1. Remove the health score and coverage-gap surfaces. Rejected: loses at-a-glance orientation, tracking, and reminder value.
2. Keep the current semantics. Rejected: absence from an upload is not proof of absence from the user’s life, and the score does not measure adequacy.
3. Preserve the surfaces and migrate them to evidence-backed readiness and coverage facts. Chosen: retains user and operational value while aligning with the product boundary.

## Derived implementation scope

- Rename dashboard language and factor semantics from coverage health/adequacy to policy workspace readiness.
- Add explicit evidence status and source identifiers to coverage insights without breaking stable follow-up IDs.
- Replace purchase/rider/renewal recommendations with neutral review or insurer-question next steps.
- Preserve expiry facts and reminder scheduling as observable, user-controlled workflow state.
- Add tests for unknown-versus-absent, incomplete extraction, conflicts, expiry, and stable resolution tracking.
- Update the public-claim review surface and durable product exploration map with the chosen contract.

## Validation and evidence plan

- Tier 1: static audit of all callers, copy, serializers, and policy-analysis rules.
- Tier 2: focused Flutter tests for readiness scoring, evidence states, serialization, and resolution persistence; analyzer/type checks for touched Dart files.
- Tier 3: authenticated mobile/API flow proving an uploaded policy produces citations, neutral unknown states, persisted follow-up state, and reminders.
- Tier 4: manual device review of dashboard language, accessibility semantics, reminder delivery, and failure/retry presentation.
- Tier 5 remains required before launch claims: deployed environment, real provider health, migration state, and representative document corpus.

## Risks and rollback

The main migration risk is stale serialized coverage data or callers expecting recommendation text. Keep fields backward-compatible during migration, map old values to neutral display semantics, and preserve stable `gapId` generation. Roll back a stage by reverting that stage’s UI/provider/data-contract commit while retaining the decision record; do not restore unsupported customer claims.

## Revisit triggers and owner

Revisit this decision if the product boundary changes, if regulated advice or broker/insurer activity is proposed, if a new evidence contract supports a stronger claim, or if user research shows the neutral language fails to explain the workflow. Owner: CoverWise product/engineering review.

## Anything else?

The next implementation slice should start with the shared evidence contract and coverage-analysis rules, then migrate the readiness score and UI copy. Runtime provider, device-notification, and production-corpus evidence must remain separately reported; passing focused tests does not close those gates.
