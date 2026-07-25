# Credential Rotation Attestation — Template

**Do not put secret values, tokens, private keys, full credential IDs, or
screenshots containing them in this document.** Store evidence in the relevant
provider account or approved secret manager and refer only to a redacted
identifier, provider, and timestamp.

## Scope

- Attestation date (UTC):
- Accountable owner:
- Independent reviewer:
- Trigger (for example, historical scanner finding or planned rotation):
- Repository revision / release candidate:

## Credential inventory

List every credential that could have appeared in the affected repository
history or deployment/configuration paths. Include credentials that have been
superseded, even when their current use is unknown.

| Provider / system | Purpose | Redacted identifier or key version | Exposure assessment | Rotation / revocation action | Completed UTC | Evidence location (non-secret) |
| --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |

## Required closure checks

- [ ] A new credential/key version was created in the provider or secret
  manager; its value was never written to this repository or this attestation.
- [ ] Every running/deployed service was updated through the approved secret
  binding mechanism.
- [ ] The previous credential was revoked, disabled, or assigned a documented
  time-bounded overlap period.
- [ ] The application’s production configuration validation passed with secret
  bindings, without printing secret values.
- [ ] A least-privilege review confirmed the replacement credential has only
  the required scopes.
- [ ] Provider audit logs or key-usage evidence were reviewed after rotation
  for unexpected use of the previous credential.

## Repository-history decision

Choose exactly one; rotation is required in either case.

- [ ] **Retain history.** Rationale, residual risk, compensating controls, and
  legal/security approver are recorded below.
- [ ] **Rewrite history.** Approved migration plan, clone/CI/cache invalidation
  plan, protected-branch coordination, and user communication are recorded
  below. Do not rewrite history without explicit authorization.

Decision rationale:

Approver and date:

## Verification record

List commands/checks, outcomes, and evidence tier. Never paste secrets or
unredacted provider output.

| Check | Outcome | Evidence tier | Date / operator | Notes |
| --- | --- | --- | --- | --- |
| Redacted repository-history secret scan |  |  |  |  |
| Current release-source secret scan |  |  |  |  |
| Deployed health / authenticated smoke |  |  |  |  |
| Previous credential inactive |  |  |  |  |

## Acceptance

I confirm that this attestation is complete to the best of my knowledge, that
no secret has been copied into this repository, and that any remaining risk is
explicitly accepted by the named accountable owner.

- Accountable owner / date:
- Security or technical reviewer / date:
- Remaining risk and next review trigger:
