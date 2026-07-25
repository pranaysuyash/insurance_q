# Launch claim: policy readiness and coverage overview

## Approved wording

CoverWise helps users organize uploaded policy records, see which details are
ready for review, identify questions raised by the uploaded workspace, and set
user-controlled reminders for policy dates.

## Explicit limitations

- “Policy readiness” describes the quality and currentness of the uploaded
  workspace. It does not assess household adequacy, financial protection,
  suitability, risk, or whether a user should buy insurance.
- “Not found in the uploaded workspace” does not mean the user lacks that
  coverage.
- Coverage questions may be incomplete when pages, fields, or extraction are
  incomplete. The UI must expose `not_verified` or equivalent uncertainty.
- Expiry information is a factual observation from a policy record. A
  reminder is a device/user workflow, not an insurer notice, renewal service,
  procurement action, or guarantee of continued coverage.
- The product does not act as an insurer, insurance broker, agent, claims
  representative, or recommendation service.

## Implementation owners

- Evidence/status contract: `mobile/lib/models/policy_summary.dart`
- Coverage-analysis pipeline: `mobile/lib/services/policy_extraction_service.dart`
- Readiness calculation: `mobile/lib/providers/health_score_provider.dart`
- User-facing readiness and coverage language:
  `mobile/lib/widgets/health_score_card.dart`,
  `mobile/lib/screens/coverage_gap_screen.dart`
- Reminder scheduling: `mobile/lib/services/notification_service.dart`

## Verification gates

| Face | Current evidence | Required before launch claim |
|---|---|---|
| Contract/static | Tier 1: status fields, neutral analysis rules, and copy reviewed | Keep serializer compatibility and source IDs covered by tests |
| Focused behavior | Tier 2: full mobile suite (1,028 tests) and Python suite (532 passed, 1 skipped) pass; analyzer has no compile errors | Add direct analysis tests for every evidence status |
| Authenticated flow | Unknown | Upload a representative policy and verify source-linked facts, unknown states, and persisted follow-up state end to end |
| Device/manual | Partial for scheduling plan; no device delivery proof | Verify timezone behavior, quiet hours, cancellation, and visible reminder delivery on supported devices |
| Production-like | Unknown | Verify deployed backend/provider health and representative corpus before publishing stronger claims |

## Revisit trigger

Revisit this claim if the product boundary changes, if regulated advice or
broker/insurer activity is proposed, or if a new evidence contract supports a
stronger user-facing statement.

## Anything else?

This registry entry intentionally makes the limitation part of the claim. A
clean UI or passing unit test cannot promote the claim above the highest
verified evidence tier.
