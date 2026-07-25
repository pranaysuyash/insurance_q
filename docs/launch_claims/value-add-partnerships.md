# Launch claim: Value-Add Partnerships — no-share rule

**Source ADR:** [ADR-2026-07-19-16](../decisions/ADR-2026-07-19-16-value-add-partnerships-framework.md)

## Approved wording

CoverWise does not share user documents, substrate fields, or Claim Document
Vault contents with partners. The product shares only a single boolean opt-in
signal ("this user opted in to partnership offers") when the user explicitly
enables it.

## Explicit limitations

- The no-share rule applies to **all** non-user, non-partner-opt-in parties.
- The user's opt-in signal is a single boolean. The product shares nothing else.
- The user can opt out at any time. The opt-out is propagated to the partner
  within 24 hours.
- The boundary is enforced by a CI test that scans the production code for any
  code path that shares user data without the correct consent.
- The partner-vetting policy is a marketing site page that names the criteria a
  partner must meet (regulatory standing, data handling, no resale, no
  unsolicited contact, opt-out honored, etc.).

## Implementation owners

- Partnership opt-in toggle: Consent ledger with purpose `partnership_offers`
- Partner webhook: Server-enrolled opt-in webhook
- No-share CI test: Scans production code for data sharing paths
- Partner-vetting policy: Marketing site page

## Verification gates

| Requirement | Current evidence | Required before launch claim |
|-------------|-----------------|------------------------------|
| Opt-in toggle | Tier 0: not implemented | In-app toggle + consent ledger |
| Opt-out propagation | Tier 0: not implemented | 24-hour propagation to partner |
| No-share CI test | Tier 0: not implemented | Scanning for unauthorized data sharing |
| Partner-vetting policy | Tier 0: not published | Marketing site page |

## Revisit trigger

Revisit if a new partnership is added, if the data-sharing boundary changes, or
if the opt-in/opt-out propagation mechanism changes.
