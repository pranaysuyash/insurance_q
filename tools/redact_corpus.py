#!/usr/bin/env python3
"""redact_corpus.py — safe redaction front-end for FULL real insurance policies.

WHY THIS EXISTS (motto_v5 §0.3, Documentation-as-Delivery):
    The eval corpus needs REAL policy wording, but real policies carry PII on their
    schedule/endorsement pages. This CLI turns a (possibly encrypted) policy PDF, or
    a directory of them, into redacted artifacts that can be ingested into the eval
    corpus WITHOUT shipping raw customer PII.

LEGAL / COPYRIGHT NOTICE — READ BEFORE USE:
    Insurer policy *wordings* are copyrighted third-party material. The redacted
    output of this tool is for LOCAL EVALUATION ONLY and MUST NOT be redistributed,
    committed to a public repo, or shipped in a product. (motto_v5 §0.3.)
    This tool NEVER emits real PII: every detected token is replaced by a [TAG].

EVIDENCE TIER (motto_v5 §0.5 / Confidence Honesty §0.2):
    HEURISTIC. Redaction is best-effort, not a guarantee of PII removal.
    - RELIABLY masked: emails, phone-like strings, postcodes, policy/claim/IBAN
      numbers, DOB dates, labelled/detected street addresses, Title+Name persons.
    - WEAK / best-effort: free-text person names without a title, org names without
      a label, unusual address/phone formats. Output must be human-reviewed before
      any ingestion of sensitive material.

USAGE:
    python tools/redact_corpus.py PATH [PATH ...] -o OUTDIR [--jsonl] [--password P]

    PATH may be a .pdf file or a directory (recursively scanned for *.pdf).
    Writes <stem>.redacted.txt per PDF, plus <stem>.redacted.jsonl when --jsonl is
    given (coverage-ready: one ingest record per redacted page block).

SAFETY: default OUTDIR is ./redacted_corpus; pass --outdir /tmp/... for throwaway
runs. No real PII is ever written — only [TAG] placeholders.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Reuse the canonical, already-reviewed redaction logic (single source of truth).
# live_fixture.py owns extract_policy_pages / _mask_pii / chunk_pages.
_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent))  # repo root, so `tests.evals.live_fixture` imports
from tests.evals.live_fixture import extract_policy_pages, chunk_pages  # noqa: E402


def _iter_pdfs(paths):
    for p in paths:
        pp = Path(p)
        if pp.is_dir():
            yield from sorted(pp.rglob("*.pdf"))
        elif pp.is_file():
            yield pp
        else:
            print(f"[warn] skipping unknown path: {p}", file=sys.stderr)


def redact_one(pdf_path: Path, outdir: Path, make_jsonl: bool, password: str | None):
    pages = extract_policy_pages(pdf_path, password or "")
    outdir.mkdir(parents=True, exist_ok=True)

    txt_path = outdir / f"{pdf_path.stem}.redacted.txt"
    txt_path.write_text(
        "\n\n".join(f"--- PAGE {no} ---\n{text}" for no, text in pages),
        encoding="utf-8",
    )
    dropped = sum(1 for _, t in pages if t.startswith("[REDACTED POLICY SCHEDULE"))
    print(f"[ok] {pdf_path.name}: {len(pages)} pages, {dropped} dropped as schedule/PII -> {txt_path}")

    if make_jsonl:
        blocks = chunk_pages(pages)
        jsonl_path = outdir / f"{pdf_path.stem}.redacted.jsonl"
        with jsonl_path.open("w", encoding="utf-8") as fh:
            for b in blocks:
                b = dict(b)
                b["filename"] = pdf_path.name
                fh.write(json.dumps(b, ensure_ascii=False) + "\n")
        print(f"[ok] {pdf_path.name}: {len(blocks)} ingest blocks -> {jsonl_path}")


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="redact_corpus.py",
        description="Best-effort redact FULL real insurance policies for local eval ingestion.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    ap.add_argument("paths", nargs="+", help="PDF file(s) and/or directory(ies) of PDFs")
    ap.add_argument("-o", "--outdir", default="./redacted_corpus", help="output directory for redacted artifacts")
    ap.add_argument("--jsonl", action="store_true", help="also emit coverage-ready .redacted.jsonl (ingest blocks)")
    ap.add_argument("--password", default=None, help="password for encrypted PDFs (prefer env over CLI)")
    args = ap.parse_args(argv)

    outdir = Path(args.outdir)
    pdfs = list(_iter_pdfs(args.paths))
    if not pdfs:
        ap.error("no PDF files found in the given path(s)")
    for pdf in pdfs:
        try:
            redact_one(pdf, outdir, args.jsonl, args.password)
        except Exception as exc:  # one bad PDF must not abort the batch
            print(f"[error] {pdf.name}: {exc}", file=sys.stderr)
    print("[done] redaction complete. Local-eval-only; do NOT redistribute (copyright + residual-PII risk).")


if __name__ == "__main__":
    main()
