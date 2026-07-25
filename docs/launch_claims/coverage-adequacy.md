# Launch claim: per-scenario coverage adequacy fields

**Source ADR:** [ADR-2026-07-19-17](../decisions/ADR-2026-07-19-17-coverage-adequacy-substrate-extension.md)

## Approved wording

CoverWise can answer specific coverage questions, such as whether maternity,
dental, OPD, day care, ICU sub-limits, pre-existing disease waiting periods,
and network hospital lists are covered by an uploaded policy.

## Explicit limitations

- Coverage answers are substrate-grounded: they depend on the extracted fields
  from the uploaded policy document. If the document does not contain the
  relevant clause, the answer is "not found in the uploaded workspace."
- The 7 per-scenario fields are extracted by a mix of deterministic regex
  extractors (4) and LLM extractors (3). LLM-extracted values carry the
  `evidence_strength` from the parser's honesty check.
- "Not found" does not mean the user lacks that coverage — it means the
  uploaded policy does not mention it.
- The four-face evidence-backed contract applies to coverage adequacy answers.

## Implementation owners

- Substrate fields: 7 new columns in `extracted_fields` table
- Parser pipeline v3: `src/services/evidence_pipeline.py`
- Deterministic extractors: 4 regex-based
- LLM extractors: 3 LLM-based
- UI surface: Coverage Adequacy tool (per ADR-08 #2)

## Verification gates

| Component | Current evidence | Required before launch claim |
|-----------|-----------------|------------------------------|
| Migration | Tier 0: not applied | 7 new columns in `extracted_fields` |
| 4 deterministic extractors | Tier 0: not implemented | Regex tests for each |
| 3 LLM extractors | Tier 0: not implemented | Honesty check + evidence_strength |
| Parser pipeline v3 | Tier 0: not implemented | All 7 extractors integrated |
| Four-face contract | Per evidence-backed.md | All four faces pass |

## Revisit trigger

Revisit if a new per-scenario field is added, if an extractor type changes
(regex → LLM or vice versa), or if the four-face contract is updated.
