#!/usr/bin/env python3
"""Final candidate-term verification: confirm each search phrase hits BODY text
(not the TOC) and show a clean snippet, for all 6 PDFs."""
from __future__ import annotations
import fitz
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORPUS = ROOT / "corpus_global"

TARGETS = {
    ("au", "property", "axa__home-policy-wording.pdf"): [
        "Your policy covers the buildings for loss or damage resulting from",
        "If your keys are lost or stolen we will pay",
        "Any loss or damage caused by wear and tear",
        "Accidental Damage (optional extra) Your policy schedule will show",
        "reasonable cost of alternative accommodation",
        "the maximum contents cover limit",
    ],
    ("ca", "motor", "rbc__auto-policy-ontario.pdf"): [
        "Collision or Upset - we will pay for losses caused",
        "Comprehensive - we will pay for losses",
        "we will pay the amount of damages",
        "deductible will be",
        "war activities",
        "we will not pay",
        "Accident Benefits",
    ],
    ("uk", "liability", "axa__public-liability-wording.pdf"): [
        "accidental 1 bodily injury to any person",
        "territorial limits Great Britain",
        "Personal liability cover At your request, we will pay the amount of damages",
        "We will not pay",
        "claim costs in connection with a claim",
    ],
    ("uk", "travel", "axa__travel-policy-wording-131.pdf"): [
        "We will pay you up to the Emergency medical and repatriation limit",
        "Policy excess Under most sections",
        "waiting to receive, or have received treatment",
        "We will pay you up to the Personal Possessions",
        "Covered if the appropriate winter sports premium has been paid",
        "We will pay you up to the Cancelling your trip",
    ],
    ("uk", "travel", "axa__travel-policy-wording-v2.pdf"): [
        "Emergency medical",
        "excess",
        "not covered",
        "personal liability",
        "baggage",
        "cancellation",
        "We will pay you",
    ],
    ("uk", "travel", "wearetravelinsurance__travel-ipid.pdf"): [
        "excess",
        "not covered",
        "medical",
        "cancellation",
        "territory",
        "We will pay",
        "limit",
    ],
}


def first_hit(doc, term, width=320):
    for i in range(doc.page_count):
        text = doc[i].get_text("text")
        idx = text.lower().find(term.lower())
        if idx != -1:
            start = max(0, idx - width // 4)
            end = min(len(text), idx + width)
            snip = " ".join(text[start:end].split())
            return i + 1, snip
    return None, None


def main() -> int:
    for (market, lob, name), terms in TARGETS.items():
        pdf = CORPUS / market / lob / name
        doc = fitz.open(str(pdf))
        print(f"\n### {market}/{lob}/{name} (pages={doc.page_count})")
        for term in terms:
            page, snip = first_hit(doc, term)
            print(f"\n  {term!r} -> p{page}\n    {snip}")
        doc.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
