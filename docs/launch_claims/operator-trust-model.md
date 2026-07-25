# Launch claim: operator trust model (RBAC + audit trail)

**Source ADR:** [ADR-2026-07-19-12](../decisions/ADR-2026-07-19-12-operator-trust-model.md)

## Approved wording

Every privileged action by a CoverWise operator is logged with a reason, the
operator's role, and the action's result. The operator cannot exceed their
role's scope.

## Explicit limitations

- "Every privileged action" means actions by operators with the `support`,
  `security`, `analytics`, `billing`, or `deletion_worker` roles. Customer
  actions (the `customer` role) are not covered by this claim; they are covered
  by the consent ledger.
- The first version uses a static operator token, not OIDC. Token rotation and
  revocation are manual (operator password manager).
- The audit trail is append-only at the database level. It is not a SIEM export
  or real-time alert system.
- The reason is a free-text string. It is not validated against a structured
  format.
- The six roles (`customer`, `support`, `security`, `analytics`, `billing`,
  `deletion_worker`) are the launch set. Future roles may be added.

## Implementation owners

- RBAC table: `supabase/migrations/2026_07_19_operator_trust_model.sql`
- Session model: `src/models/operator_session.py`
- Audit trail: `supabase/migrations/2026_07_19_operator_trust_model.sql`, append-only rules
- Operator auth middleware: `src/middleware/operator_auth.py`
- Reason middleware: `src/middleware/reason_required.py`
- Operator CLI: `tools/operator_admin.py`

## Verification gates

| Component | Current evidence | Required before launch claim |
|-----------|-----------------|------------------------------|
| RBAC table | Tier 0: not migrated | Migration applied, default policy seeded |
| Session model | Tier 0: not implemented | Session create/expire/revoke tested |
| Audit trail | Tier 0: not implemented | Append-only enforced, queryable by security role |
| Auth middleware | Tier 0: not implemented | 6-step pattern enforced on every privileged endpoint |
| Reason middleware | Tier 0: not implemented | Header required on every privileged endpoint |
| TTL enforcement | Tier 0: not implemented | Expired sessions rejected |
| Revocation | Tier 0: not implemented | Denylist cache, immediate revocation |
| Operator CLI | Tier 0: not implemented | Revoke, query, update RBAC |
| Composite | No integration test | Launch playbook Step 8: operator login → read → audit → revoke |

## Revisit trigger

Revisit if a new role is added, if OIDC integration replaces the static token,
if the reason format is standardized, or if the audit trail is exported to a
SIEM.

## Anything else?

The operator trust model is the engineering answer to the privacy policy
enforcement. The RBAC table is the policy. The audit trail is the check.
