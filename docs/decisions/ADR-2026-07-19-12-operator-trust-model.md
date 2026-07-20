# ADR-2026-07-19-12: Operator trust model — server-enforced RBAC + audit trail + reason-required

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The operator is a real role, not a token.** The system has six roles: `customer` (default), `support`, `security`, `analytics`, `billing`, `deletion_worker`. Each role has a server-enforced scope. Each privileged action is checked against a server-side RBAC table. Each privileged action requires a reason. Each privileged action is logged in an immutable audit trail. The current `X-Operator-Token` is replaced by a per-role operator session with a TTL. The launch-claim registry records the claim "every privileged action is logged and reason-required" and links to the tests that gate it.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** The operator trust model is the 6-role RBAC + audit trail + reason-required + TTL + revocation system. Static token for the launch; OIDC deferred. The wider wedge from ADR-2026-07-19-08 revision 2 (Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault) adds more privileged actions: support reading new-surface content with reason, security auditing partnership opt-ins, the deletion_worker managing the new durable work. The RBAC table grows. The Claim Document Vault is the most sensitive surface — it may contain medical records (discharge summaries, diagnosis info). A future ADR ("Claim Document Vault privacy policy") will define the medical-data handling: consent purpose, retention, encryption at rest, support-operator access rules, user's right to export and delete. The 6 roles still apply; the RBAC table is the implementation. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-09](./ADR-2026-07-19-09-evidence-backed-release-grade-definition.md), [ADR-2026-07-19-11](./ADR-2026-07-19-11-substrate-as-primary-deliverable.md), [canonical architecture doc](../../architecture/coverwise_canonical_architecture.md), `docs/audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md` §10.6, P0-08, T-8-5, T-8-8.

---

## Update log

- **2026-07-19 (original)**: Initial proposal. 6 roles, server-enforced RBAC, audit trail, reason-required, TTL, revocation. OIDC deferred. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** The operator reviewed and signed off. The wider wedge from ADR-2026-07-19-08 revision 2 (Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault) adds more privileged actions:

  - **Support role**: reads Coverage Check-in observations, Coverage Adequacy answers, Family Coverage Map per-member observations, Claim Document Vault documents — all with reason logged. The Claim Document Vault is the most sensitive: it may contain medical records (discharge summaries, diagnosis info, treatment details). A future ADR ("Claim Document Vault privacy policy") will define the medical-data handling: consent purpose (`medical_records`), retention period (e.g. 7 years per Indian medical record retention norms), encryption at rest (already covered by the substrate's evidence_strength + the principal encryption from ADR-2026-07-19-06), support-operator access rules (read-only, with reason, audit-logged), user's right to export (PDF) and delete (per the existing deletion flow, extended for medical data).
  - **Security role**: audits Value-Add Partnerships opt-ins, reads the consent ledger (per ADR-2026-07-19-07), enforces consent withdrawal (e.g. if the user withdraws partnership opt-in, the system propagates the withdrawal to the partner webhook).
  - **Analytics role**: still reads `/analytics/*` only. The new surfaces generate more analytics events (Coverage Check-in completions, Coverage Adequacy scenario answers, Family Coverage Map views, Claim Document Vault uploads) — these are aggregate, not individual, and are within the analytics role's existing scope.
  - **Billing role**: still reads billing data, but the Q&A packs finish-properly (per ADR-08 #10) means the billing role will be exercised more (entitlement checks, refund flows, restore flows). The role is unchanged; the volume is higher.
  - **Deletion role**: now has more durable work to manage (Claim Document Vault deletions, Family member deletions, Coverage Check-in observation deletions). The deletion_worker handles the durable deletion jobs. The deletion-worker role is unchanged; the volume is higher.
  - **Customer role**: now has more data to delete (all of the above). The customer's right to delete is unchanged; the data is more.

  The RBAC table grows to cover the new privileged actions. The audit trail captures every action. The reason requirement is enforced by the middleware. The TTL and revocation are unchanged. The 6 roles are the contract; the RBAC table is the implementation. The Claim Document Vault privacy policy is a future ADR; the audit log + reason requirement + RBAC are the foundation that the future ADR builds on.

---

## Context

The current state, from the code archaeology pass and the audits:

- **`/analytics/*` requires only a user bearer.** Any customer can read `/analytics/summary`, `/analytics/health`, `/analytics/errors`. The data is aggregate but may include PII in error strings. (Security audit P0-08, current-state §2.5.)
- **`X-Operator-Token` is a placeholder.** A single token, checked with constant-time compare, grants access to every privileged endpoint. No role separation. No audit trail. No reason required. No TTL. No revocation. (Security audit §10.6.)
- **The consent ledger (ADR-2026-07-19-07) is a storage primitive with no enforcement.** The consent purpose is recorded but not enforced. A user can withdraw consent but the withdrawal is not propagated to the systems that use the data. (Security audit P0-17.)
- **Account deletion is a 200-returning path.** The synchronous deletion returns 200 even when source files, Redis, anti-abuse tracking, and analytics rows survive. The deletion is not durable; it is not server-enforced; it is not audited. (Security audit P0-04, P0-05, T-8-1.)
- **The privacy policy is not enforced by the system.** The policy says "we delete your data when you ask" but the system does not enforce the deletion. The policy says "we honor your consent" but the system does not enforce the consent. (Security audit §10.6, current-state §2.5.)

The audits converge on a single fix: **the operator is a role, not a token.** Each role has a scope. Each privileged action is checked. Each privileged action is logged. Each privileged action requires a reason. The current `X-Operator-Token` is replaced by a per-role session with a TTL.

This ADR defines the operator trust model: the roles, the RBAC table, the audit trail, the reason requirement, the TTL, the revocation.

---

## Options considered

### Option A: Keep `X-Operator-Token`, add an audit log. REJECTED.

- **How it works:** the operator continues to use a single token for every privileged endpoint. The audit log records every privileged action. The reason is required. The token has a TTL.
- **Why rejected:** the audit log is a check, not a fix. The `X-Operator-Token` is still a single token that grants access to every privileged endpoint. The role separation is missing. A support operator can read `/analytics/*`; a security operator can trigger a deletion. The audit log records the action but does not prevent the action. The audit's T-8-8 is "Operator authorization beyond bearer token (RBAC + audit trail)." The "beyond bearer token" is the missing piece.
- **Mitigation that was considered and rejected:** add a role claim to the token (`X-Operator-Token: <role>:<token>`). The role is in the token but is not server-validated. The mitigation is good, but the role separation is still in the token, not in the system. A stolen token is still a single token.

### Option B: Per-role operator sessions with server-enforced RBAC. CHOSEN.

- **How it works:** the operator logs in with an OIDC provider (or a static token for the first version). The login returns a session with a role claim. The session has a TTL. Every privileged endpoint checks the session's role against the RBAC table. Every check is logged. Every privileged action requires a reason. The reason is logged.
- **Why chosen:** the audit's T-8-8 is "Operator authorization beyond bearer token (RBAC + audit trail)." The RBAC is the server-enforced role separation. The audit trail is the check. The reason is the accountability. The TTL is the revocation.
- **Cost:** 2-3 weeks of work: the RBAC table, the session model, the audit trail, the reason middleware, the OIDC integration (or static token for the first version), the tests.
- **Quality:** every privileged action is role-checked, reason-required, and audited. The operator cannot exceed their scope. The audit trail is queryable by the security role.

### Option C: Per-role operator sessions with OIDC and short-lived tokens. DEFERRED.

- **How it works:** the operator logs in with an OIDC provider (Google Workspace, Okta, etc.). The session is a short-lived JWT (e.g. 15 min). The refresh token is held by the operator's device. The session is revoked by the OIDC provider.
- **Why deferred:** OIDC is the right answer for a multi-operator team. The first version has one operator (Pranay). The static-token version (Option B with a static token) is sufficient for the launch. The OIDC version is a future workstream.
- **Cost:** the deferred work is 1-2 weeks of OIDC integration. The launch does not wait.

---

## The operator trust model

### The six roles

| Role | Scope | Privileged actions | Reason required |
|---|---|---|---|
| `customer` | The user's own data | Read/write own data; delete own data; withdraw own consent | No (default) |
| `support` | The user's data, for support purposes | Read user policy, read user questions, read user consent, read user billing | Yes |
| `security` | All data, for security purposes | Read user data, read audit log, revoke operator session, force re-auth | Yes |
| `analytics` | Aggregate data, no individual users | Read `/analytics/*` | Yes |
| `billing` | User billing data, for billing purposes | Read user entitlement, read user billing events, trigger refund | Yes |
| `deletion_worker` | Durable deletion, for deletion purposes | Trigger durable deletion, re-queue outbox event, cancel outbox event | Yes |

The roles are server-enforced. The client cannot grant itself a role. The role is set at login time and persisted in the session.

### The RBAC table

The RBAC table is a server-side table that maps (role, resource, action) to (allowed, denied, reason-required). The table is:

```sql
CREATE TABLE rbac_policy (
    role TEXT NOT NULL,
    resource TEXT NOT NULL,
    action TEXT NOT NULL,
    allowed BOOLEAN NOT NULL,
    reason_required BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (role, resource, action)
);
```

The table is seeded with the default policy. The security role can update the policy (with an audit log entry). The table is versioned (every change is a new row, the old row is preserved).

### The session model

The session is a server-side record:

```sql
CREATE TABLE operator_sessions (
    id UUID PRIMARY KEY,
    operator_id UUID NOT NULL,
    role TEXT NOT NULL,
    issued_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    ip_address INET,
    user_agent TEXT
);
```

The session has a TTL (default 8 hours, configurable per role). The session is revoked by the security role or by the TTL expiry. The session is queryable by the security role.

### The audit trail

The audit trail is an immutable log:

```sql
CREATE TABLE operator_audit_log (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL,
    operator_id UUID NOT NULL,
    role TEXT NOT NULL,
    action TEXT NOT NULL,
    resource TEXT NOT NULL,
    reason TEXT NOT NULL,
    result TEXT NOT NULL,  -- 'allowed', 'denied', 'error'
    error_message TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- The audit log is append-only. No UPDATE or DELETE.
CREATE RULE no_audit_update AS ON UPDATE TO operator_audit_log DO INSTEAD NOTHING;
CREATE RULE no_audit_delete AS ON DELETE TO operator_audit_log DO INSTEAD NOTHING;
```

The audit trail is queryable by the security role. The audit trail is exported to the launch-claim registry (per ADR-2026-07-19-09) as a release-gated test: the test asserts that every privileged action has an audit log entry.

### The reason middleware

Every privileged endpoint requires a reason. The reason is passed as a header (`X-Operator-Reason: <reason>`) for HTTP endpoints, or as a parameter for CLI tools. The reason is required (HTTP 400 if missing). The reason is logged.

The reason is a free-text string. The reason is not validated. The reason is queryable. The security role can flag a reason as insufficient and revoke the session.

### The TTL

The default TTL is 8 hours. The TTL is configurable per role. The TTL is enforced at the session level: every privileged action checks the session's `expires_at`. Expired sessions are rejected (HTTP 401).

The security role can revoke a session at any time. The revocation is logged. The revoked session is added to a denylist (cached in memory for 5 minutes).

### The OIDC integration (deferred)

The first version uses a static token for the operator. The static token is a long-lived secret stored in the operator's password manager. The static token is replaced by an OIDC session in a future workstream. The RBAC table, the audit trail, the reason middleware, and the TTL are unchanged.

The deferred OIDC work is documented in the launch playbook (per ADR-2026-07-19-09) as a post-launch workstream.

---

## The contract in detail

Every privileged endpoint follows the same pattern:

1. **Authenticate**: extract the session from the `Authorization` header (Bearer token) or the cookie.
2. **Check session validity**: the session is not expired, not revoked, not in the denylist.
3. **Check RBAC**: the session's role is allowed to perform the action on the resource.
4. **Check reason**: the `X-Operator-Reason` header is present and non-empty.
5. **Perform the action**: the endpoint runs.
6. **Log the audit entry**: the session, role, action, resource, reason, result, IP, user-agent are logged.

The pattern is enforced by a middleware (`src/middleware/operator_auth.py` new). The middleware is applied to every privileged endpoint. The middleware is tested by a unit test that asserts every privileged endpoint uses the middleware.

The pattern fails closed: if any step fails, the request is rejected. The failure is logged.

---

## Chosen path

**The operator is a real role, not a token.** The six roles are server-enforced. The RBAC table, the session model, the audit trail, the reason middleware, the TTL, and the revocation are the implementation. The launch-claim registry records the claim "every privileged action is logged and reason-required" and links to the tests that gate it.

The work to implement:

1. **RBAC table + migration** — 0.5 day. The `rbac_policy` table.
2. **Session model + migration** — 0.5 day. The `operator_sessions` table.
3. **Audit trail + migration** — 0.5 day. The `operator_audit_log` table with the append-only rules.
4. **Operator auth middleware** — 1-2 days. The `src/middleware/operator_auth.py` middleware.
5. **Apply middleware to privileged endpoints** — 1-2 days. The `/analytics/*`, deletion, billing, and consent endpoints.
6. **Reason middleware** — 0.5 day. The `X-Operator-Reason` header check.
7. **TTL enforcement** — 0.5 day. The `expires_at` check.
8. **Revocation** — 0.5 day. The denylist cache.
9. **Operator CLI** — 1-2 days. The `tools/operator_admin.py` CLI for the security role (revoke session, query audit log, update RBAC).
10. **Launch-claim registry entry** — 0.5 day. The entry records the claim and links to the tests.
11. **Canonical doc update** — 0.5 day. The doc defines the operator trust model.
12. **CI gate** — 0.5 day. The release-claim-gated test.

**Effort:** 2-3 weeks. The RBAC is the bulk; the OIDC is deferred.

**Sequence:**
1. RBAC table + migration (the foundation for the rest).
2. Session model + migration (the session is the auth unit).
3. Audit trail + migration (the audit is the check).
4. Operator auth middleware (the middleware is the enforcement).
5. Apply middleware to privileged endpoints (the migration is the work).
6. Reason middleware (the reason is the accountability).
7. TTL enforcement (the TTL is the revocation).
8. Revocation (the denylist is the immediate revocation).
9. Operator CLI (the tool for the security role).
10. Launch-claim registry entry (the claim is recorded).
11. Canonical doc update (the doc is current).
12. CI gate (the test is the release guard).

The release happens after the launch-claim registry entry is in place and the launch playbook's Step 8 (real-device end-to-end) validates the operator trust model.

---

## Why this path

### 1st-principle argument

The operator is a human who needs to do specific things. The system must allow the specific things and prevent the others. The RBAC table is the allow/deny. The audit trail is the check. The reason is the accountability. The TTL is the revocation. The operator is a role, not a token, because a role has a scope and a token does not.

### Anti-lying-UI argument (motto v3 §0.7, trust audit NO-GO)

The privacy policy says "we honor your consent" and "we delete your data when you ask." If the operator can bypass the consent check or the deletion, the policy is a lie. The operator trust model is the engineering answer to the policy: the system enforces the policy, the operator is bounded by the policy, the audit trail records the enforcement.

### Anti-single-actor argument (motto v3 §0.4 acceptance contract)

A single actor (one operator, one token) is a single point of failure. A role-based actor (six roles, six scopes) is a distributed actor. The acceptance contract for "ship a feature" includes "the feature is operable by the right people and not by the wrong people." The RBAC is the contract.

### Anti-unsigned-action argument (motto v3 §0.10 observability is delivery)

The audit trail is the observability for the operator side. Every privileged action is recorded. The security role can query the trail. The trail is the basis for incident response, audit, and compliance.

### Operator-decision-required argument

This ADR is **proposed, not accepted**. The six roles are a recommendation. The RBAC table, the audit trail, the reason middleware, the TTL, and the revocation are recommendations. The operator may want different roles, different scopes, different reasons, different TTLs. The reason this is an ADR and not a code change is that the operator trust model is load-bearing and the operator should sign off on it.

---

## Tradeoffs

- **The static-token version (Option B) is less secure than OIDC (Option C).** A static token is a long-lived secret. If the secret is compromised, the attacker has the operator's role until the TTL expires. The mitigation is the OIDC deferred work; the static-token version is sufficient for the launch.
- **The audit trail is a new table with new writes.** Every privileged action adds a row. The cost is small (single-row insert) but it is per-action. The mitigation is the audit's T-2-3 budget: the audit write is in the per-action budget.
- **The reason middleware requires every privileged endpoint to be updated.** The migration is 1-2 days of work. The mitigation is the middleware: the endpoint is updated once, the middleware enforces forever.
- **The operator CLI is a new tool.** The operator must learn the CLI. The mitigation is the existing tools pattern (e.g. the outbox admin CLI in ADR-2026-07-19-10).
- **The six roles may not be the right set.** A future ADR can add or remove roles. The RBAC table is the source of truth.
- **The 8-hour TTL may not be the right TTL.** A future ADR can change the TTL per role. The session model is the source of truth.

---

## Assumptions

- **The six roles are the right set for the launch.** The launch has one operator (Pranay) with multiple hats. The roles reflect the hats. A multi-operator team may need more roles. The operator may want a different set; the ADR is the place to discuss.
- **The RBAC table is the source of truth for authorization.** The endpoint code does not hardcode the authorization; the endpoint queries the table. The mitigation is the unit test that asserts every privileged endpoint queries the table.
- **The audit trail is append-only.** The rules (`no_audit_update`, `no_audit_delete`) are enforced at the database level. The mitigation is the launch-claim registry test: the test asserts the rules are in place.
- **The static token is stored in the operator's password manager.** The mitigation is the launch playbook: the token is rotated quarterly.
- **The OIDC integration is deferred.** The first version uses a static token. A future workstream integrates OIDC. The mitigation is the launch-claim registry: the OIDC work is a post-launch claim.
- **The reason is a free-text string.** The reason is not validated. The security role can flag a reason as insufficient. The mitigation is the launch-claim registry: the reason format is a future claim.

---

## Risks

- **The operator disagrees with a role or scope.** This is a feature of the decisions-first process, not a bug. The mitigation is to make the six roles explicit and easy to revisit.
- **The static token is compromised.** The mitigation is the OIDC deferred work + the quarterly rotation.
- **The audit trail is not queried.** The mitigation is the security role's tooling: a daily report of privileged actions, an alert on suspicious patterns.
- **The reason middleware is bypassed.** The mitigation is the CI test: the test asserts every privileged endpoint uses the middleware.
- **The RBAC table is not updated when a new endpoint is added.** The mitigation is the CI test: the test asserts every new endpoint has a default-deny RBAC row.
- **The TTL is too long or too short.** The mitigation is the per-role TTL: the TTL is configurable per role.
- **The six roles are not picked up.** 2-3 weeks of work is a lot. The mitigation is the launch-claim registry: the operator trust model cannot be deployed until the six roles pass.

---

## Validation plan

- **For the RBAC table:** a migration test that asserts the table exists with the default policy.
- **For the session model:** a unit test that asserts the session is created on login, expires after the TTL, and is revoked by the security role.
- **For the audit trail:** a unit test that asserts every privileged action adds a row, the row is immutable, and the row is queryable by the security role.
- **For the operator auth middleware:** a unit test that asserts the middleware enforces the 6-step pattern (authenticate, check session, check RBAC, check reason, perform, log).
- **For the privileged endpoints:** an integration test that asserts every privileged endpoint uses the middleware, requires a reason, and logs the audit entry.
- **For the reason middleware:** a unit test that asserts the `X-Operator-Reason` header is required and non-empty.
- **For the TTL:** a unit test that asserts an expired session is rejected.
- **For the revocation:** a unit test that asserts a revoked session is rejected, and the denylist is updated.
- **For the operator CLI:** a unit test that asserts the CLI can revoke a session, query the audit log, and update the RBAC.
- **For the launch-claim registry:** a CI test that asserts the registry entry exists and links to the tests.
- **For the canonical doc:** a doc-lint test that asserts the operator trust model is defined.
- **End-to-end:** the launch playbook's Step 8 (real-device end-to-end) runs after the operator trust model is implemented. The validation includes: operator logs in → reads user data with reason → audit entry is created → operator revokes their own session → revoked session is rejected.

---

## Rollback or migration path

The operator trust model is additive. The RBAC table, the session model, the audit trail, the reason middleware, the TTL, and the revocation are new components. The `X-Operator-Token` is replaced by the session model. The replacement is local: the middleware handles both during the transition.

If a component turns out to be wrong:
- The RBAC table can be reverted to a default-deny policy.
- The session model can be replaced by a different auth mechanism.
- The audit trail can be made writable (the rules are removed).
- The reason middleware can be relaxed (the header is optional).
- The TTL can be increased.
- The revocation can be disabled.

The launch-claim registry entry is updated when a component changes. The CI gate fails if the entry is not updated.

---

## What would cause this decision to be revisited

- **The operator wants different roles.** A future ADR can add or remove roles. The RBAC table is the source of truth.
- **The OIDC integration lands.** A future ADR can replace the static token with OIDC. The session model is unchanged.
- **A multi-operator team is hired.** A future ADR can add an operator-management UI. The RBAC table is unchanged.
- **The reason format is standardized.** A future ADR can add a structured reason format. The middleware is unchanged.
- **The audit trail is exported to a SIEM.** A future ADR can add a SIEM integration. The audit trail is the source.
- **The market changes.** A competitor claims "GDPR-compliant" without an audit trail. The operator may decide to publish the audit trail. The launch-claim registry entry is updated.

---

## Links

- **Affected files (this ADR, after operator sign-off):**
  - `supabase/migrations/2026_07_19_operator_trust_model.sql` (new: the RBAC, session, audit tables)
  - `src/middleware/operator_auth.py` (new: the 6-step middleware)
  - `src/middleware/reason_required.py` (new: the reason header check)
  - `src/api/analytics.py` (apply middleware)
  - `src/api/deletion.py` (apply middleware, when it lands)
  - `src/api/billing.py` (apply middleware, when it lands)
  - `src/api/consent.py` (apply middleware)
  - `src/api/operator.py` (new: the operator login, session, revocation endpoints)
  - `tools/operator_admin.py` (new: the operator CLI)
  - `tests/test_rbac_table.py` (new: the migration test)
  - `tests/test_operator_session.py` (new: the session model test)
  - `tests/test_audit_trail.py` (new: the audit immutability test)
  - `tests/test_operator_auth_middleware.py` (new: the 6-step pattern test)
  - `tests/test_reason_middleware.py` (new: the reason header test)
  - `tests/test_ttl_enforcement.py` (new: the TTL test)
  - `tests/test_revocation.py` (new: the revocation test)
  - `tests/test_operator_admin_cli.py` (new: the CLI test)
  - `docs/launch_claims/operator-trust-model.md` (new: the launch-claim registry entry)
  - `docs/architecture/coverwise_canonical_architecture.md` (add the operator trust model to the doc)
  - `docs/decisions/README.md` (add this ADR to the index)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-09](./ADR-2026-07-19-09-evidence-backed-release-grade-definition.md) (the launch-claim registry pattern)
  - [ADR-2026-07-19-11](./ADR-2026-07-19-11-substrate-as-primary-deliverable.md) (the substrate visibility that the operator can see)
  - [ADR-2026-07-19-10](./ADR-2026-07-19-10-outbox-only-durable-work-primitive.md) (the outbox that the deletion_worker can manage)
  - [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) (the cuts and finishes that this ADR depends on)
  - [Canonical architecture doc](../../architecture/coverwise_canonical_architecture.md) (target of the doc update)
  - `docs/audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md` §10.6, P0-08, P0-17, T-8-1, T-8-5, T-8-8 (the audit findings)
- **Related code (current state):**
  - `src/middleware/` (new directory for the operator auth middleware)
  - `src/api/analytics.py` (the `/analytics/*` endpoints that need the middleware)
  - `src/api/consent.py` (the consent endpoints that need the middleware)
  - `src/api/document.py:611-658` (the `POST /capture-lead` that needs the middleware, when it lands)
  - `src/services/consent_ledger_service.py` (the consent ledger that the operator can query)
- **Motto v3 alignment:** §0.4 (acceptance contract; the operator trust model is the contract for the operator side), §0.5 (evidence tiers; the audit trail is a tier), §0.7 (AI output boundary; the operator is bounded by the RBAC), §0.10 (observability is delivery; the audit trail is the observability for the operator side), §0.11 (customer-facing claims; the privacy policy is enforced by the operator trust model), §0.12 (this document).
