#!/usr/bin/env python3
"""Deeper, body-level exploration of the 6 global PDFs with specific clause
phrases (avoids landing on TOC pages) to craft accurate gold examples."""
from __future__ import annotations
import fitz
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORPUS = ROOT / "corpus_global"

# (market, lob, file, [search terms]) — terms are body-level phrases expected to
# hit the actual clause, not the table of contents.
TARGETS = [
    ("au", "property", "axa__home-policy-wording.pdf", [
        "We will pay you up to the maximum buildings cover limit",
        "If your keys are lost or stolen",
        "wear and tear",
        "Gradual",
        "Personal Possessions",
        "flood",
        "accidental damage",
        "business, trade, profession",
        "theft of or from",
    ]),
    ("ca", "motor", "rbc__auto-policy-ontario.pdf", [
        "we will pay for damages",
        "The Deductible",
        "Outside Ontario",
        "Losses Due to War Activities Not Covered",
        "Accident Benefits Coverage",
        "Excluded Drivers and Driving Without Permission",
        "Direct Compensation",
        "collision or upset",
        "Comprehensive",
    ]),
    ("uk", "liability", "axa__public-liability-wording.pdf", [
        "Personal liability cover At your request, we will pay",
        "accidental bodily injury to any person",
        "loss of or damage to material property",
        "territorial limits Great Britain",
        "General Exclusion",
        "conduct of any negotiation",
        "indemnity",
    ]),
    ("uk", "travel", "axa__travel-policy-wording-131.pdf", [
        "We will pay you up to the Emergency medical and repatriation limit",
        "Policy excess Under most sections",
        "waiting to receive, or have received treatment",
        "Personal liability",
        "Personal Possessions and baggage",
        "winter sports",
        "cancelling your trip",
    ]),
    ("uk", "travel", "axa__travel-policy-wording-v2.pdf", [
        "Emergency medical",
        "excess",
        "not covered",
        "personal liability",
        "baggage",
        "cancellation",
        "territorial",
    ]),
    ("uk", "travel", "wearetravelinsurance__travel-ipid.pdf", [
        "covered",
        "excess",
        "not covered",
        "medical",
        "cancellation",
        "territory",
        "limit",
    ]),
]


def first_hit(doc, term, width=500):
    for i in range(doc.page_count):
        text = doc[i].get_text("text")
        low = text.lower()
        idx = low.find(term.lower())
        if idx != -1:
            start = max(0, idx - width // 4)
            end = min(len(text), idx + width)
            snip = " ".join(text[start:end].split())
            return i + 1, snip
    return None, None


def main() -> int:
    for market, lob, name, terms in TARGETS:
        pdf = CORPUS / market / lob / name
        doc = fitz.open(str(pdf))
        print(f"\n{'='*80}\n### {market}/{lob}/{name} (pages={doc.page_count})\n{'='*80}")
        for term in terms:
            page, snip = first_hit(doc, term)
            if page:
                print(f"\n  TERM: {term!r}  -> p{page}")
                print(f"    {snip}")
        doc.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
