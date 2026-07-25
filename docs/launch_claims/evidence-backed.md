# Launch claim: evidence-backed answers (four-face contract)

**Source ADR:** [ADR-2026-07-19-09](../decisions/ADR-2026-07-19-09-evidence-backed-release-grade-definition.md)

## Approved wording

CoverWise answers are "evidence-backed" when every material claim in the answer
can be traced to a specific source, the quote is verified against the source
text, and the user can see the verification state.

## Explicit limitations

- "Evidence-backed" applies **only** to answers where all four faces pass:
  substrate (extracted field with confidence ≥ 0.7), citation (quote exists in
  source), answer (every material claim has a verified citation), and UI
  (verification state is visible).
- Answers with `verification_status = partially_backed` are NOT "evidence-backed."
  The UI renders these as "some of this answer is verified, some is not."
- Answers with `verification_status = abstained` are NOT "evidence-backed."
  The system declined to answer.
- A field with `evidence_strength < 0.7` is excluded from the substrate face
  and shown as "not yet verified."
- Citations use a fuzzy substring match after whitespace normalization. A
  quote with significant character differences (hyphen vs. em-dash, etc.) may
  fail verification.
- The 0.7 substrate threshold is field-type-agnostic. Future ADRs may set
  per-field-type thresholds.

## Implementation owners

- Substrate face: `src/services/evidence_substrate_service.py` (✅ `is_substrate_backed()` with 5-condition contract + 8 tests)
- Citation face: `src/services/citation_verifier.py` (✅ `verify_citation()` with 5-condition contract + 16 unit tests + 6 integration tests)
- Answer face: `src/services/answer_verifier.py` (✅ `verify_answer()` with 4-condition contract + 24 tests)
- UI face: `mobile/lib/widgets/answer_verification_badge.dart` (✅ `AnswerVerificationBadge` with 4-status enum + 11 widget tests + unsupported-claims visual distinction)

## Verification gates

| Face | Current evidence | Required before launch claim |
|------|-----------------|------------------------------|
| Substrate | ✅ **Full 5-condition contract** — `is_substrate_backed()` with `parser_version`, `owner`, `field_evidence` checks + 8 tests | Full 5-condition check + tests |
| Citation | ✅ **Full 5-condition contract** — `verify_citation()` with source existence, quote-presence, quote-substring-match (whitespace-normalized), fuzzy-match score ≥ 0.8, and label assertions + 22 tests (16 unit + 6 integration) | New module with 5-condition contract + tests |
| Answer | ✅ **Module implemented** — `src/services/answer_verifier.py` with 24 tests | New module with 4-condition contract + tests |
| UI | ✅ **Badge widget + unsupported-claims visual distinction** — `answer_verification_badge.dart` (12 tests) + rejected citations greyed-out with "Verify in your policy" label in `qa_screen.dart` | New widget + widget tests + greyed-out rejected citations |
| Composite | ✅ **Integration test — 7 tests passing** — `tests/test_composite_evidence_face.py` simulates upload → extract → verify → badge flow with mocked substrate (Face 1) + real citation verifier (Face 2) + real answer verifier (Face 3). All 7 tests pass alongside the 60 unit tests across all four faces. | 7 integration tests covering happy path, rejected-citation cascade, abstention, substrate-failure block, owner mismatch, empty source, and unverified prohibition |

## Revisit trigger

Revisit this claim if the four-face contract changes, if the substrate
threshold is modified per-field-type, if the fuzzy-match threshold changes, or
if the eval runner (T-7-13) produces new benchmarks that shift the thresholds.

## Anything else?

This registry entry intentionally records the four-face contract as the
definition. The marketing claim "evidence-backed" is a function of the four
faces, not a separate thing. The CI gate fails if any face regresses.
