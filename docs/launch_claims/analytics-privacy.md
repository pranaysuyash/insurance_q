# Launch claim: analytics event data handling

**Source ADR:** [ADR-2026-07-19-08](../decisions/ADR-2026-07-19-08-cut-keep-finish-half-built-features.md)

## Approved wording

CoverWise stores analytics events in Supabase. The events are aggregate, not
individual, and do not include user documents.

## Explicit limitations

- Analytics events may include user actions and interaction outcomes (for example,
  uploads, QA, dashboard taps, errors), but not policy text, document contents,
or personal identifiers beyond an anonymous install/session identifier and standard app context.
- The analytics events are stored in Supabase and controlled by Supabase policy.
- The operator account is bound by Supabase role policy.
- Analytics consent is tracked in the consent ledger. Events are only emitted when the user has granted analytics consent.
- The analytics buffer is capped at 10,000 events. Oldest events are dropped
  when the buffer is full.
- Schema-only events still present in schema are **deferred** and emit nothing until explicitly reactivated.

## Implementation owners

- Analytics service: `mobile/lib/services/analytics_service.dart`
- Consent ledger: `mobile/lib/services/consent_ledger_service.dart`
- Server analytics: `src/api/analytics.py`
- Analytics buffer cap: `mobile/lib/services/analytics_service.dart`
- Event governance: `docs/analysis/analytics_tracking_event_registry.md`

## Verification gates

| Requirement | Current evidence | Required before launch claim |
|-------------|-----------------|------------------------------|
| No document content in events | Tier 2: focused tests | CI test scanning event schemas |
| Consent-gated emission | Tier 2: 5 consent gate tests | Live consent-gated analytics flow |
| Buffer cap | Tier 2: implemented | Test verifying cap enforcement |
| Aggregate-only server endpoints | Tier 2: RBAC-scoped | Operator RBAC enforced |
| Contract/spec synchronization | Added in `analytics_tracking_event_registry.md` and `coverwise_analytics_event_spec.md` | Weekly review + owner update |

## Revisit trigger

Revisit if any new analytics event type is added, if analytics retention policy or consent handling changes, or if a provider migration occurs.
