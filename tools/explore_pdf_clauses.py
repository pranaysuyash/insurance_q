#!/usr/bin/env python3
"""
explore_pdf_clauses.py
=====================
Dev aid: given a policy PDF and a list of search terms, print the first page
(1-indexed) each term appears on, plus a text snippet around the match. Used to
ground gold-labeled eval examples to real page numbers before authoring them.

Usage:
    python tools/explore_pdf_clauses.py --pdf corpus_global/uk/motor/axa__car-policy-wording.pdf \
        --terms "accidental damage" "windscreen" "drive other cars" "excess"
"""
from __future__ import annotations

import argparse
import fitz
from pathlib import Path


def snippet_around(page, term: str, width: int = 600) -> str:
    text = page.get_text("text")
    low = text.lower()
    idx = low.find(term.lower())
    if idx == -1:
        return "(term not found on this page)"
    start = max(0, idx - width // 3)
    end = min(len(text), idx + width)
    return text[start:end].strip().replace("\n", " ")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pdf", required=True, type=Path)
    ap.add_argument("--terms", required=True, help="comma-separated search terms")
    ap.add_argument("--width", type=int, default=700)
    args = ap.parse_args()

    doc = fitz.open(args.pdf)
    terms = [t.strip() for t in args.terms.split(",") if t.strip()]
    print(f"# {args.pdf.name}  pages={doc.page_count}")
    for term in terms:
        found = False
        for i in range(doc.page_count):
            if term.lower() in doc[i].get_text("text").lower():
                print(f"\n## term={term!r}  page={i+1}")
                print("   ", snippet_around(doc[i], term, args.width)[: args.width])
                found = True
                break
        if not found:
            print(f"\n## term={term!r}  NOT FOUND in document")
    doc.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
