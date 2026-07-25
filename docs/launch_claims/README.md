# Launch-claim registry

Every customer-facing claim that CoverWise makes about its product must be
registered here with its approved wording, explicit limitations, implementation
owners, and verification gates. A claim may not be used in marketing, onboarding,
or UI copy unless its highest verified evidence tier is at least Tier 3 for
high-risk claims (privacy, security, billing, health) or Tier 2 for
medium/low-risk claims.

## Registry entries

| # | Claim | Registry file | Evidence tier | Status |
|---|-------|---------------|---------------|--------|
| 1 | Policy readiness and coverage overview | [`policy-readiness-and-coverage-overview.md`](policy-readiness-and-coverage-overview.md) | Tier 2 (focused tests) | ✅ Active |
| 2 | Evidence-backed answers (four-face contract) | [`evidence-backed.md`](evidence-backed.md) | Tier 2 (focused tests) | ✅ Active |
| 3 | User can verify every citation | [`substrate-citations.md`](substrate-citations.md) | Tier 2 (focused tests) | ✅ Active |
| 3a | Citation verifier (Face 2) | [`substrate-citations.md`](substrate-citations.md) | Tier 2 (16 tests) | ✅ Active |
| 4 | Operator trust model (RBAC + audit trail) | [`operator-trust-model.md`](operator-trust-model.md) | Tier 1 (ADR accepted) | ⏳ Pending implementation |
| 5 | Per-scenario coverage adequacy fields | [`coverage-adequacy.md`](coverage-adequacy.md) | Tier 1 (ADR accepted) | ⏳ Pending implementation |
| 6 | Family Coverage Map per-member observations | [`family-coverage-map.md`](family-coverage-map.md) | Tier 1 (ADR accepted) | ⏳ Pending implementation |
| 7 | Claim Document Vault auto-extracted fields | [`claim-document-vault.md`](claim-document-vault.md) | Tier 1 (ADR accepted) | ⏳ Pending implementation |
| 8 | Qdrant vector database data handling | [`qdrant-vector-database.md`](qdrant-vector-database.md) | Tier 1 (ADR accepted) | ⏳ Pending implementation |
| 9 | Analytics event data handling | [`analytics-privacy.md`](analytics-privacy.md) | Tier 2 (focused tests) | ✅ Active |
| 10 | Value-Add Partnerships: no-share rule | [`value-add-partnerships.md`](value-add-partnerships.md) | Tier 1 (ADR accepted) | ⏳ Pending implementation |

## Evidence tiers

| Tier | Definition | Example |
|------|------------|---------|
| 0 | No evidence / not implemented | ADR accepted, code not written |
| 1 | Static inspection | Code review, file inspection |
| 2 | Focused tests | Unit/widget tests passing |
| 3 | Authenticated runtime | Verified against deployed backend |
| 4 | Device/manual | Physical device or simulator verification |
| 5 | Production-like | Verified with production credentials, real corpus |

## Revisit trigger

Revisit the registry when:
- A claim's implementation changes (code, tests, or deployed behavior)
- A claim's evidence tier improves (new tests pass, new runtime verification)
- A new ADR adds or modifies a customer-facing claim
- The launch boundary changes (new feature, new surface, new partnership)
- An audit or review identifies a gap between claim and reality

## CI gate

A CI test asserts that every entry in this registry exists on disk and links to
its implementation owner. The test fails if a referenced file is missing or if
a registry entry is stale (last updated > 90 days).
