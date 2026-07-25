# Launch claim: user can verify every citation

**Source ADR:** [ADR-2026-07-19-11](../decisions/ADR-2026-07-19-11-substrate-as-primary-deliverable.md)

## Approved wording

Every citation in a CoverWise answer includes a source name, page number, and
source excerpt. The user can tap "open page" to see the actual OCR'd page text
and verify the claim.

## Explicit limitations

- Citations may quote only `source_text` (the immutable OCR'd page text), not
  `retrieval_text` (the LLM-augmented contextualized chunk).
- The "open page" action requires the source page to have been OCR'd. If OCR is
  incomplete, the page may not be navigable.
- Citations are verified by the citation face (substring match after whitespace
  normalization). A quote that fails verification is dropped from the answer.
- The five-layer substrate contract (source_text, retrieval_text, page_artifact,
  document, owner) is the engineering foundation. All five layers must be
  present for the claim to hold.

## Implementation owners

- Substrate five-layer contract: `src/models/rag.py`, `src/services/evidence_substrate_service.py`
- Citation verifier: `src/services/citation_verifier.py`
- UI citation card: `mobile/lib/widgets/field_citations_card.dart`
- Answer verification badge: `mobile/lib/widgets/answer_verification_badge.dart`

## Verification gates

| Layer | Current evidence | Required before launch claim |
|-------|-----------------|------------------------------|
| Source text (`source_text`) | Tier 2: stored per chunk | Full immutable contract verified |
| Retrieval text (`retrieval_text`) | Tier 2: stored per chunk | Must not be quoted in citations |
| Page artifact (`page_artifact`) | Tier 2: stored per page | Full page-preview navigable |
| Document | Tier 2: stored in repository | Owner-scoped, deletion-capable |
| Owner | Tier 2: bearer-verified | Cross-owner isolation tested |
| Citation verifier | Tier 2: 16 tests passing — 5‑condition contract (source_match, quote_normalization, page_exists, no_contradiction, rejection_on_fail) | 5-condition contract + tests |
| UI (open page) | Tier 2: widget exists | Full screen with page navigation |

## Revisit trigger

Revisit if the five-layer contract changes, if a new extraction pipeline
produces citations differently, or if page-preview navigation is extended to
mobile web.

## Anything else?

The "user can verify" claim is the customer's right. The substrate is the
engineering answer. The citation face is the runtime check.
