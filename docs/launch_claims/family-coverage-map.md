# Launch claim: Family Coverage Map per-member observations

**Source ADRs:** [ADR-2026-07-19-14](../decisions/ADR-2026-07-19-14-family-coverage-map-substrate-extension.md), [ADR-2026-07-19-20](../decisions/ADR-2026-07-19-20-family-coverage-map-privacy-policy.md)

## Approved wording

CoverWise can show which family members are covered by which policies, their
individual sum insured, exclusions, and whether they can hold their own policy.

## Explicit limitations

- Per-member observations are substrate-grounded: they depend on three
  per-member extracted fields (`member_sum_insured`, `member_exclusions`,
  `member_can_have_own_policy`).
- The three fields are extracted by a mix of deterministic extractors (2) and
  an LLM extractor (1). LLM-extracted values carry `evidence_strength`.
- The four-face evidence-backed contract applies to per-member observations.
- Per-member observations are **never shared with partners, insurers, or third
  parties**.
- Per-member data is encrypted at rest using the principal encryption.
- The privacy policy is the minimum-viable stance: user can dismiss observations,
  export and delete their data. Formal consent purpose (`family_data`), retention
  enforcement, and per-policy encryption are deferred.
- Support-operator access is disabled in the meantime. When enabled, it will be
  read-only, with reason, audit-logged, and user-notified.

## Implementation owners

- Substrate extension: 3 new columns in `extracted_fields` table
- Deterministic extractors: 2 regex-based
- LLM extractor: 1 LLM-based
- Parser pipeline v2: `src/services/evidence_pipeline.py`
- UI surface: Family Coverage Map (per ADR-08 #6)
- Privacy policy: In-app disclosure card

## Verification gates

| Component | Current evidence | Required before launch claim |
|-----------|-----------------|------------------------------|
| Migration | Tier 0: not applied | 3 new columns in `extracted_fields` |
| 2 deterministic extractors | Tier 0: not implemented | Regex tests for each |
| LLM extractor | Tier 0: not implemented | Honesty check + evidence_strength |
| Parser pipeline v2 | Tier 0: not implemented | All 3 extractors integrated |
| Four-face contract | Per evidence-backed.md | All four faces pass |
| Privacy policy disclosure | Tier 0: not implemented | In-app disclosure card |
| No-share CI test | Tier 0: not implemented | Scans for data sharing outside Family Coverage Map |

## Revisit trigger

Revisit if a new per-member field is added, if the privacy policy is
strengthened (formal consent, retention enforcement), or if support-operator
access is enabled.
