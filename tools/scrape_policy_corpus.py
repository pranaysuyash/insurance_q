#!/usr/bin/env python3
"""
scrape_policy_corpus.py
=======================

Resilient, manifest-driven downloader for a GLOBAL insurance-policy corpus.

First-principles design
-----------------------
1. Manifest-driven, not code-driven.
   A single JSON file (`corpus_global/manifest.json`) lists every target as
   {market, lob, insurer, product, url, license_class, mirror?}. Adding a new
   market or line-of-business requires ZERO code changes -- just append a row.

2. Global by construction.
   `market` is an ISO-3166 alpha-2-ish bucket (us, uk, eu, au, ca, in, ...).
   `lob` is a line of business (health, cyber, marine, motor, travel, property,
   liability, life, ...). Layout on disk:
       corpus_global/<market>/<lob>/<insurer>__<product_slug>.pdf
   CoverWise is a GLOBAL product: the corpus must reflect that people everywhere
   buy policies and want to understand them.

3. Legal / redistribution safety is a first-class concern.
   `license_class` is one of:
     - "regulator" : government / regulator standard form (NAIC, FCA, FSRAO,
                     APRA, ASIC, EIOPA, IRDAI, ...). Public domain / openly
                     licensed -> redistribution-safe.
     - "industry"  : industry-body sample wording (e.g. III sample forms).
                     Usually openly published -> redistribution-safe.
     - "insurer"   : a specific insurer's copyrighted wording. Downloaded for
                     LOCAL EVALUATION ONLY. Must NOT be redistributed. The
                     corpus ships with a NOTICE file stating this.
   The script never auto-publishes anything. It only writes to local disk.

4. Resilience.
   - Follows redirects, retries with exponential backoff.
   - Validates the %PDF magic bytes; anything else (HTML bot-block page,
     wrong content-type, tiny payload) is quarantined as `.blocked.html` and
     recorded as status="bot_blocked" rather than silently saved as a PDF.
   - SSL: a small number of public hosts serve valid docs behind cert chains
     the sandboxed Python cannot verify. For the curated manifest we retry such
     URLs once with certificate validation disabled (we still validate the
     bytes are a real PDF, so this is safe in practice).
   - Idempotent: skips a target whose PDF already exists and is valid.
   - A single failure never aborts the batch.

5. Observable.
   Writes `corpus_global/_scrape_results.json` (machine) and prints a human
   summary (successes / bot-blocks / failures) plus a per-target log.

Usage
-----
    python tools/scrape_policy_corpus.py --manifest corpus_global/manifest.json
    python tools/scrape_policy_corpus.py --manifest corpus_global/manifest.json --dry-run
    python tools/scrape_policy_corpus.py --manifest corpus_global/manifest.json --only us,uk,ca

Exit code is 0 on successful completion of the batch (even if some targets were
bot-blocked). A non-zero exit means a usage / IO error.
"""
from __future__ import annotations

import argparse
import json
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
VALID_LICENSE_CLASSES = {"regulator", "industry", "insurer"}
PDF_MAGIC = b"%PDF"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)
MIN_PDF_BYTES = 2048  # anything smaller than this is almost certainly a block page


# ---------------------------------------------------------------------------
# Manifest entry
# ---------------------------------------------------------------------------
@dataclass
class Target:
    market: str
    lob: str
    insurer: str
    product: str
    url: str
    license_class: str
    mirror: str | None = None
    note: str = ""

    def slug(self) -> str:
        s = re.sub(r"[^a-z0-9]+", "-", self.product.lower()).strip("-")
        ins = re.sub(r"[^a-z0-9]+", "-", self.insurer.lower()).strip("-")
        return f"{ins}__{s}"

    def out_path(self, root: Path) -> Path:
        return root / self.market / self.lob / f"{self.slug()}.pdf"

    @classmethod
    def from_dict(cls, d: dict) -> "Target":
        missing = {"market", "lob", "insurer", "product", "url", "license_class"} - set(d)
        if missing:
            raise ValueError(f"manifest entry missing fields: {sorted(missing)} -> {d}")
        if d["license_class"] not in VALID_LICENSE_CLASSES:
            raise ValueError(
                f"license_class must be one of {sorted(VALID_LICENSE_CLASSES)}, "
                f"got {d['license_class']!r}"
            )
        return cls(
            market=d["market"].strip().lower(),
            lob=d["lob"].strip().lower(),
            insurer=d["insurer"].strip(),
            product=d["product"].strip(),
            url=d["url"].strip(),
            license_class=d["license_class"].strip().lower(),
            mirror=(d.get("mirror") or "").strip() or None,
            note=d.get("note", ""),
        )


# ---------------------------------------------------------------------------
# Download core
# ---------------------------------------------------------------------------
def _fetch(url: str, timeout: int = 30, verify: bool = True) -> tuple[bytes, str]:
    """Return (body, content_type). Raises on hard network failure.

    `verify=False` retries a curated URL with certificate validation disabled.
    Some public insurer/regulator hosts serve valid public docs behind cert
    chains the sandboxed Python cannot verify; for a curated manifest this is an
    acceptable fallback (we validate the bytes are a real PDF anyway).
    """
    ctx = None
    if not verify:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:  # nosec B310 manifest
        ctype = resp.headers.get("Content-Type", "")
        body = resp.read()
    return body, ctype


def _fetch_with_fallback(src: str, timeout: int = 30) -> tuple[bytes, str]:
    """Fetch a curated URL, retrying once without cert verification if the
    host's certificate chain cannot be validated locally. SSL errors arrive
    wrapped inside `urllib.error.URLError`, so we inspect `.reason`."""
    try:
        return _fetch(src, timeout, verify=True)
    except urllib.error.URLError as e:
        if isinstance(getattr(e, "reason", None), ssl.SSLError):
            return _fetch(src, timeout, verify=False)
        raise


def _classify(body: bytes, ctype: str) -> str:
    """Decide what we got."""
    head = body[:512].lstrip()
    if body[:4] == PDF_MAGIC and len(body) >= MIN_PDF_BYTES:
        return "pdf"
    lowered = ctype.lower()
    if "html" in lowered or head.startswith(b"<!doctype") or head.startswith(b"<html"):
        return "html"
    if len(body) < MIN_PDF_BYTES:
        return "too_small"
    return "unknown"


def download_one(t: Target, root: Path, dry_run: bool = False) -> dict:
    out = t.out_path(root)
    rec = {
        "market": t.market,
        "lob": t.lob,
        "insurer": t.insurer,
        "product": t.product,
        "url": t.url,
        "license_class": t.license_class,
        "out": str(out),
        "status": "",
        "bytes": 0,
        "detail": "",
    }

    # Idempotency: valid PDF already present?
    if out.exists() and out.stat().st_size >= MIN_PDF_BYTES and out.read_bytes()[:4] == PDF_MAGIC:
        rec["status"] = "skip_existing"
        rec["bytes"] = out.stat().st_size
        rec["detail"] = "valid PDF already present"
        return rec

    if dry_run:
        rec["status"] = "dry_run"
        rec["detail"] = "would download"
        return rec

    out.parent.mkdir(parents=True, exist_ok=True)
    last_err = ""
    last_blocked = None  # (detail, bytes) from a non-PDF response
    sources = [t.url] + ([t.mirror] if t.mirror else [])
    for src in sources:
        for retry in range(3):
            try:
                body, ctype = _fetch_with_fallback(src)
                kind = _classify(body, ctype)
                if kind == "pdf":
                    out.write_bytes(body)
                    rec["status"] = "ok"
                    rec["bytes"] = len(body)
                    rec["detail"] = f"downloaded from {src}"
                    return rec
                # Non-PDF (HTML bot-block / wrong ctype / tiny payload): quarantine
                # for inspection, then KEEP TRYING the next source (e.g. mirror)
                # rather than giving up on the whole target.
                blocked = out.with_suffix(".blocked.html")
                blocked.write_bytes(body[:200_000])
                last_blocked = (
                    f"{src} returned {kind} (ctype={ctype}); quarantined",
                    len(body),
                )
                break
            except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError) as e:
                last_err = f"{src} attempt {retry}: {e}"
                time.sleep(2 ** retry)

    if last_blocked is not None:
        rec["status"] = "bot_blocked"
        rec["bytes"] = last_blocked[1]
        rec["detail"] = last_blocked[0]
    else:
        rec["status"] = "failed"
        rec["detail"] = last_err or "unknown failure"
    return rec


# ---------------------------------------------------------------------------
# Manifest IO
# ---------------------------------------------------------------------------
def load_manifest(path: Path) -> list[Target]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        data = data.get("targets", [])
    return [Target.from_dict(d) for d in data]


def write_results(root: Path, results: list[dict]) -> Path:
    p = root / "_scrape_results.json"
    p.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    return p


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Resilient global policy-corpus downloader")
    here = Path(__file__).resolve().parent
    default_manifest = here.parent / "corpus_global" / "manifest.json"
    ap.add_argument("--manifest", default=str(default_manifest), type=Path)
    ap.add_argument("--root", default=None, type=Path,
                    help="override output root (default: manifest's parent dir)")
    ap.add_argument("--only", default="", help="comma-separated markets to restrict to")
    ap.add_argument("--dry-run", action="store_true", help="validate + plan, do not download")
    args = ap.parse_args(argv)

    if not args.manifest.exists():
        print(f"ERROR: manifest not found: {args.manifest}", file=sys.stderr)
        return 2
    targets = load_manifest(args.manifest)
    root = args.root or args.manifest.parent
    root.mkdir(parents=True, exist_ok=True)

    only = {m.strip().lower() for m in args.only.split(",") if m.strip()} if args.only else set()
    if only:
        targets = [t for t in targets if t.market in only]

    print(f"[scrape] manifest={args.manifest} targets={len(targets)} "
          f"dry_run={args.dry_run} only={sorted(only) or 'all'}")
    results = [download_one(t, root, dry_run=args.dry_run) for t in targets]

    write_results(root, results)

    by_status: dict[str, int] = {}
    for r in results:
        by_status[r["status"]] = by_status.get(r["status"], 0) + 1
    print("[scrape] summary:", json.dumps(by_status))
    for r in results:
        if r["status"] not in ("ok", "skip_existing", "dry_run"):
            print(f"  ! {r['status']:>12} {r['market']}/{r['lob']}/{r['insurer']}: {r['detail']}")
    print(f"[scrape] wrote {root / '_scrape_results.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
