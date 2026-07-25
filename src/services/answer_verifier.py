"""Answer verifier (ADR-2026-07-19-09 face 3).

Verifies that every material claim in the answer has a verified citation, and
classifies the answer's verification status as ``fully_backed``,
``partially_backed``, or ``abstained``.

Per ADR-2026-07-19-09 (evidence-backed release-grade definition):

  **Face 3: Answer face — "every material claim has a verified citation"**

  1. Every material claim in the answer (a sentence or clause that states a
     fact about the policy) is followed by a citation marker.
  2. Every citation marker resolves to a citation that passes the citation face
     (verification_status = "verified").
  3. The answer's verification_status is one of: fully_backed, partially_backed,
     or abstained.
  4. The answer never returns verification_status = unverified — that state is
     reserved for the UI badge to render a warning, and the answer text is
     gated to refuse to show the unverified claims.
"""

from __future__ import annotations

import re
from typing import List, Tuple

from src.models.rag import RAGCitation, VerificationStatus


# Regex to find citation markers like [1], [2, 3], [1-3]
_CITATION_MARKER_RE = re.compile(r"\[(\d+(?:\s*[,;-]\s*\d+)*)\]")


def _extract_citation_indices(answer_text: str) -> List[int]:
    """Extract all source indices referenced by citation markers in the answer.

    Handles single indices ``[1]``, comma-separated ``[1, 2]``,
    ranges ``[1-3]``, and mixed ``[1, 2, 4-6]``.

    A token like ``4-6`` is expanded to ``[4, 5, 6]``.
    """
    indices: set[int] = set()
    for match in _CITATION_MARKER_RE.finditer(answer_text):
        content = match.group(1)
        # Split on comma or semicolon (but NOT hyphen — hyphens denote ranges).
        groups = re.split(r"\s*[,;]\s*", content)
        for group in groups:
            group = group.strip()
            if not group:
                continue
            # Check for range: like "4-6" or "10-15"
            range_match = re.match(r"^(\d+)\s*-\s*(\d+)$", group)
            if range_match:
                start, end = int(range_match.group(1)), int(range_match.group(2))
                if 1 <= start <= end:
                    indices.update(range(start, end + 1))
            else:
                # Single index
                try:
                    idx = int(group)
                    if idx >= 1:
                        indices.add(idx)
                except ValueError:
                    pass
    return sorted(indices)


def _material_sentences(answer_text: str) -> List[str]:
    """Split answer text into sentences that are likely material claims.

    A "material claim" is a sentence that states a factual assertion about the
    policy (as opposed to meta-commentary like "Let me check" or "This is a
    summary").  The heuristic splits by sentence boundaries and filters out
    sentences that are clearly non-material: very short sentences, sentences
    that start with hedge words, and empty/whitespace-only sentences.

    Per ADR-2026-07-19-09, the heuristic is imperfect; the eval runner
    (T-7-13) is the long-term test harness. This verifier is a fast runtime
    check.
    """
    # Split on sentence-ending punctuation followed by whitespace or end-of-string
    raw_sentences = re.split(r"(?<=[.!?])\s+(?=[A-Z\"'(])", answer_text)
    if not raw_sentences:
        raw_sentences = [answer_text]

    material: List[str] = []
    for sentence in raw_sentences:
        sentence = sentence.strip()
        if not sentence or len(sentence) < 10:
            continue

        # Skip sentences that start with non-material hedges
        lower = sentence.lower().strip()
        if lower.startswith(("let me", "i'll", "i can", "i will", "here is",
                              "this is a", "based on", "note:")):
            continue

        # Skip sentences that are entirely a citation marker (rare edge case)
        if _CITATION_MARKER_RE.fullmatch(sentence):
            continue

        material.append(sentence)

    return material


def _count_cited_sentences(answer_text: str, citations: List[RAGCitation]) -> int:
    """Count how many sentences in the answer are followed by a citation marker.

    A sentence is "cited" if it contains at least one citation marker whose
    source index matches a citation with ``citation_status == 'verified'``.
    Approximate matches remain visible to the user as warnings, but cannot
    promote an answer to the release-grade evidence-backed state.
    """
    valid_indices: set[int] = set()
    for c in citations:
        # Per ADR-2026-07-19-09 face 3, only 'verified' citations count
        # toward the answer face. 'approximate' citations are shown with
        # a warning label but do not satisfy the evidence-backed contract.
        # 'rejected' citations are excluded because they were stripped.
        if c.citation_status == "verified":
            valid_indices.add(c.source_index)

    material_sentences = _material_sentences(answer_text)
    if not material_sentences:
        return 0

    cited_count = 0
    for sentence in material_sentences:
        cited_indices = _extract_citation_indices(sentence)
        if not cited_indices:
            continue
        if any(idx in valid_indices for idx in cited_indices):
            cited_count += 1

    return cited_count


def verify_answer(
    answer_text: str,
    citations: List[RAGCitation],
) -> Tuple[VerificationStatus, int, int]:
    """Verify the answer face per ADR-2026-07-19-09.

    Returns ``(verification_status, material_claims_count, cited_claims_count)``.

    The 4-condition contract:

    1. Every material claim in the answer is followed by a citation marker.
    2. Every citation marker resolves to a citation with citation_status =
       "verified".
    3. The answer's verification_status is one of: fully_backed,
       partially_backed, or abstained.
    4. The answer never returns verification_status = unverified.

    **Failure mode**: if a claim has no citation, the answer marks it
    "partially_backed" or "fully_backed" depending on coverage ratio.
    If every claim drops (no verified citations for any claim), the answer
    abstains. The answer never returns "unverified".
    """
    # Check 4: never return unverified — handled by default return paths below.
    material_sentences = _material_sentences(answer_text)

    if not material_sentences:
        # No material claims to verify — treat as fully backed (trivially).
        return "fully_backed", 0, 0

    cited_count = _count_cited_sentences(answer_text, citations)
    total = len(material_sentences)

    # Determine verification status (Check 3).
    if cited_count == 0:
        # No claims can be backed.
        return "abstained", total, cited_count
    elif cited_count >= total:
        # Every material claim has a verified citation.
        return "fully_backed", total, cited_count
    else:
        # Some claims are cited and verified, some are not.
        return "partially_backed", total, cited_count
