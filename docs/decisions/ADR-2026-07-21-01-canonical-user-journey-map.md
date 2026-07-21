# ADR-2026-07-21-01: Canonical CoverWise user journey map

**Status:** Accepted for documentation and exploration
**Date:** 2026-07-21
**Owner / next reviewer:** Pranay

## Decision

The canonical journey-shaped source of truth is [`docs/user_experience/coverwise_user_journey_map.md`](../user_experience/coverwise_user_journey_map.md).

The document separates:

- ideal behavior inside CoverWise’s permanent non-regulated boundary;
- current code/runtime behavior with evidence tiers;
- approved future journeys;
- exploratory journeys requiring a separate decision;
- rejected or parked journeys;
- happy, non-happy, optional, alternate, retry, privacy, and operator paths.

`docs/review/exploration_map.md` remains the strategic product-boundary and opportunity map. `docs/architecture/coverwise_canonical_architecture.md` remains the canonical system architecture map. `docs/planning/product/user_experience_flows.md` and `docs/user_experience/user_flows.md` remain historical/planning inputs until they are reconciled; they are not current implementation contracts.

## Context

CoverWise has accumulated several flow documents written at different product stages. Some describe a generic insurance policy manager, while later decisions establish a narrower information-broking product: understand and organize policies already owned, with evidence and neutral guidance. Without a canonical journey map, future work can accidentally revive purchase, recommendation, renewal, claims-representation, medical, or lead-generation behavior.

The current repository also contains meaningful runtime and architecture evidence, but the evidence is uneven: some screens have targeted tests, the launch audit has Tier 4 observations for the early flow, and several high-risk paths have only static or targeted-test evidence. The journey map must preserve that distinction.

## Options considered

### Option A — Keep all existing flow documents equally authoritative

Rejected. They represent different product boundaries and implementation eras, so equal authority creates parallel narratives and drift.

### Option B — Replace the old documents with one rewritten flow document

Rejected. Historical planning context and prior decisions are useful evidence and must be preserved. Silent rewrites would erase provenance.

### Option C — Add a canonical living journey map with explicit source-of-truth boundaries

Chosen. This preserves history, gives future exploration one routing document, and keeps architecture and strategy artifacts distinct.

## Consequences

- Future journey discussions append to the living map’s update log and update the relevant inventory row.
- A behavior change must update the current-state evidence and the relevant tests/runtime proof.
- A boundary or business-model change requires a new decision record before the journey is promoted from exploratory to approved.
- The map is not a substitute for product requirements, architecture, privacy policy, or release evidence; it links to them and exposes their gaps.
- Existing planning docs should receive dated addenda that point to this map as the current journey reference, without deleting historical content.

## Validation plan

1. Reconcile each future journey with the permanent boundary in `docs/review/exploration_map.md`.
2. Trace each current journey to mobile screens, backend routes, storage/evidence paths, tests, and runtime evidence.
3. Require Tier 3+ evidence before calling auth, deletion, billing, document processing, evidence, or customer-facing protection language production-ready.
4. Re-run the missed-anything sweep whenever a journey is added: duplicate route, duplicate pipeline, silent fallback, operator recovery, privacy, legal wording, and stale documentation.

## Anything else?

Yes: a journey map becomes dangerous if it only lists screens. The canonical map therefore treats state transitions, evidence, data lifecycle, failure recovery, and operator visibility as part of the user journey.

## Update log

- **2026-07-21:** Accepted the canonical journey-map location and source-of-truth boundaries. Created the baseline map from current code, architecture, exploration, planning, and runtime-audit evidence.
