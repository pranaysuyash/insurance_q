#!/usr/bin/env python3
"""
author_global_dataset.py
========================
Turns `tools/global_dataset_specs.json` into gold-labeled coverage datasets,
co-located with each PDF:

    corpus_global/<market>/<lob>/coverage.jsonl

For every example it:
  * re-locates the clause via the `search` term in the PDF and confirms (or
    overrides) the `expected_page` so grounding is always accurate;
  * extracts a short clause snippet from the matched page;
  * writes a row matching the eval schema used by `tests/evals/run_evals.py`
    (id, lob, product, insurer, clause, question, gold_reading, gold_rationale,
     gold, expected_citation, expected_page).

Usage:
    python tools/author_global_dataset.py
    python tools/author_global_dataset.py --specs tools/global_dataset_specs.json
"""
from __future__ import annotations

import argparse
import fitz
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# PyMuPDF inserts newline characters inside text, which breaks substring matching
# for multi-word search terms. Normalise all whitespace to single spaces before
# searching so a clause phrase matches regardless of PDF line wrapping.
_WS = re.compile(r"\s+")


def norm(text: str) -> str:
    return _WS.sub(" ", text).strip()


def locate_page(doc, term: str) -> int:
    """1-indexed page of first case-insensitive match, else -1."""
    tn = norm(term).lower()
    for i in range(doc.page_count):
        if tn in norm(doc[i].get_text("text")).lower():
            return i + 1
    return -1


def snippet(doc, page1: int, term: str, width: int = 400) -> str:
    if page1 <= 0:
        return ""
    text = norm(doc[page1 - 1].get_text("text"))
    idx = text.lower().find(norm(term).lower())
    if idx == -1:
        return text[:width].strip()
    start = max(0, idx - width // 4)
    end = min(len(text), idx + width)
    return text[start:end].strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--specs", default=str(ROOT / "tools" / "global_dataset_specs.json"), type=Path)
    ap.add_argument("--root", default=str(ROOT / "corpus_global"), type=Path)
    args = ap.parse_args()

    specs = json.loads(args.specs.read_text(encoding="utf-8"))
    total = 0
    warnings = 0
    for ds in specs:
        pdf_path = ROOT / ds["pdf"]
        doc = fitz.open(pdf_path)
        out_path = args.root / ds["market"] / ds["lob"] / "coverage.jsonl"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        rows = []
        for ex in ds["examples"]:
            found = locate_page(doc, ex["search"])
            if found == -1:
                print(f"  WARNING {ds['market']}/{ds['lob']}/{ex['id']}: "
                      f"search term {ex['search']!r} NOT FOUND")
                warnings += 1
                expected_page = ex.get("expected_page", -1)
            else:
                expected_page = found
                if ex.get("expected_page") and ex["expected_page"] != found:
                    print(f"  note {ds['market']}/{ds['lob']}/{ex['id']}: "
                          f"page overriden {ex['expected_page']} -> {found}")
            clause = snippet(doc, expected_page, ex["search"])
            rows.append({
                "id": ex["id"],
                "lob": ds["lob"],
                "product": ds["product"],
                "insurer": ds["insurer"],
                "clause": clause,
                "question": ex["question"],
                "gold_reading": ex["gold"],              # label (likely_covered/conditional/...)
                "gold_answer": ex["gold_reading"],       # plain-language answer (prose)
                "gold_rationale": ex["gold_rationale"],
                "expected_citation": ex["expected_citation"],
                "expected_page": expected_page,
            })
        doc.close()
        out_path.write_text(
            "\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n",
            encoding="utf-8",
        )
        total += len(rows)
        print(f"[author] {ds['market']}/{ds['lob']}: wrote {len(rows)} rows -> {out_path}")

    print(f"[author] total={total} warnings={warnings}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
