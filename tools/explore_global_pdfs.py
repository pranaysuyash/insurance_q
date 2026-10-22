#!/usr/bin/env python3
"""Explore 6 remaining global corpus PDFs to ground gold eval examples.

For each target, prints (term -> first 1-indexed page + 220-char snippet around
the term) for a set of coverage-relevant anchor terms. Used to author
corpus_global/<market>/<lob>/coverage.jsonl rows with accurate expected_page.
"""
from __future__ import annotations
import fitz
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORPUS = ROOT / "corpus_global"

TARGETS = [
    ("au", "property", "axa__home-policy-wording.pdf"),
    ("ca", "motor", "rbc__auto-policy-ontario.pdf"),
    ("uk", "liability", "axa__public-liability-wording.pdf"),
    ("uk", "travel", "axa__travel-policy-wording-131.pdf"),
    ("uk", "travel", "axa__travel-policy-wording-v2.pdf"),
    ("uk", "travel", "wearetravelinsurance__travel-ipid.pdf"),
]

# Anchor terms likely to mark real coverage clauses in these LOBs.
TERMS = [
    "we will pay", "we will cover", "we cover", "covered", "not covered",
    "excluded", "exclusion", "excess", "deductible", "limit", "maximum",
    "territory", "territorial", "waiting", "condition", "warranty",
    "personal liability", "third party", "emergency", "cancellation",
    "baggage", "medical", "glass", "windscreen", "theft", "fire",
    "flood", "storm", "accidental", "uninsured", "no claims", "endorsement",
]


def first_hit(doc, term, width=220):
    for i in range(doc.page_count):
        text = doc[i].get_text("text")
        low = text.lower()
        idx = low.find(term.lower())
        if idx != -1:
            start = max(0, idx - width // 3)
            end = min(len(text), idx + width)
            snip = " ".join(text[start:end].split())
            return i + 1, snip
    return None, None


def main() -> int:
    for market, lob, name in TARGETS:
        pdf = CORPUS / market / lob / name
        if not pdf.exists():
            print(f"\n### MISSING {pdf}")
            continue
        doc = fitz.open(str(pdf))
        print(f"\n{'='*80}\n### {market}/{lob}/{name}  (pages={doc.page_count})\n{'='*80}")
        for term in TERMS:
            page, snip = first_hit(doc, term)
            if page:
                print(f"  [{term}] p{page}: {snip}")
        doc.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
