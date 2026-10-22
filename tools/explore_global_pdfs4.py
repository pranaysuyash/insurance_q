#!/usr/bin/env python3
"""Verify final short, body-only search phrases (avoid TOC + line-break issues)."""
from __future__ import annotations
import fitz
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORPUS = ROOT / "corpus_global"

TARGETS = {
    ("ca", "motor", "rbc__auto-policy-ontario.pdf"): [
        "pay on your behalf", "Losses Due to War", "Income Replacement",
        "less the deductible specified", "Uninsured Automobile Coverage",
    ],
    ("uk", "liability", "axa__public-liability-wording.pdf"): [
        "Territorial Limits", "amount of damages for which", "General Exclusion",
        "claim costs", "indemnity",
    ],
    ("uk", "travel", "axa__travel-policy-wording-131.pdf"): [
        "Emergency medical and repatriation", "Policy excess",
        "waiting to receive", "winter sports premium has been paid",
        "cutting short your trip",
    ],
    ("uk", "travel", "axa__travel-policy-wording-v2.pdf"): [
        "Cancellation or Cutting Short your Trip", "No excess is applicable",
        "Personal Liability", "Emergency medical", "Personal Baggage",
    ],
    ("uk", "travel", "wearetravelinsurance__travel-ipid.pdf"): [
        "Emergency Medical Expenses", "Pre-existing medical conditions",
        "Personal Baggage", "Personal Money",
    ],
}


def first_hit(doc, term, width=300):
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
            tag = "OK" if page and page > 3 else ("TOC?" if page else "NONE")
            print(f"  [{tag}] {term!r} -> p{page}\n    {snip}")
        doc.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
