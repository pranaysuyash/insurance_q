#!/usr/bin/env python3
"""
Ground truth verification tool.

Loads a ground truth JSON file, uploads the policy document to the API,
fetches the extraction summary, Q&A responses, and compares against expected values.

Usage:
    python tools/verify_ground_truth.py \\
        --ground-truth mobile/assets/ground_truth/health_01.json \\
        --api-url http://127.0.0.1:8000

    # With Supabase keys for anonymous auth:
    SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SERVICE_ROLE_KEY=... \\
    python tools/verify_ground_truth.py \\
        --ground-truth mobile/assets/ground_truth/health_01.json \\
        --api-url http://127.0.0.1:8000
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin
from urllib.request import Request, urlopen

# ── Output helpers ───────────────────────────────────────────────────────


def eprint(*args: Any, **kwargs: Any) -> None:
    print(*args, file=sys.stderr, **kwargs)


def fail(msg: str, code: int = 1) -> None:
    eprint(f"FAIL: {msg}")
    sys.exit(code)


def ok(msg: str, indent: int = 2) -> None:
    print(f"{' ' * indent}✅  {msg}")


def skip(msg: str, indent: int = 2) -> None:
    print(f"{' ' * indent}⏭️   {msg}")


def mismatch(field: str, expected: Any, actual: Any, indent: int = 4) -> None:
    print(f"{' ' * indent}❌  {field}: expected={expected!r}, actual={actual!r}")


# ── API helpers ──────────────────────────────────────────────────────────


def _anon_token(api_url: str) -> str:
    """Get an anonymous bearer token from /user/anonymous."""
    url = urljoin(api_url.rstrip("/") + "/", "user/anonymous")
    req = Request(url, method="POST", headers={"Content-Type": "application/json"})
    try:
        with urlopen(req, timeout=15) as resp:
            body = json.loads(resp.read().decode())
            token: str = body.get("access_token") or body.get("token") or ""
            if not token:
                fail("Anonymous auth returned no token")
            return token
    except HTTPError as e:
        fail(f"Anonymous auth failed (HTTP {e.code}): {e.read().decode()[:200]}")
    except URLError as e:
        fail(f"Anonymous auth network error: {e.reason}")


def _upload_doc(api_url: str, token: str, pdf_path: str, max_retries: int = 3) -> str:
    """Upload a PDF to the API. Returns the document ID. Retries on transient errors."""
    url = urljoin(api_url.rstrip("/") + "/", "documents/upload")
    boundary = "----boundary_gt_verify"
    with open(pdf_path, "rb") as f:
        pdf_bytes = f.read()

    body_preamble = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{Path(pdf_path).name}"\r\n'
        f"Content-Type: application/pdf\r\n\r\n"
    ).encode()
    body_epilogue = f"\r\n--{boundary}--\r\n".encode()
    body = body_preamble + pdf_bytes + body_epilogue

    last_error = None
    for attempt in range(1, max_retries + 1):
        try:
            req = Request(
                url,
                data=body,
                method="POST",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": f"multipart/form-data; boundary={boundary}",
                },
            )
            with urlopen(req, timeout=30) as resp:
                result = json.loads(resp.read().decode())
                doc_id = result.get("document_id")
                if not doc_id:
                    fail(f"Upload response has no document_id: {result}")
                return doc_id
        except HTTPError as e:
            if e.code >= 500 and attempt < max_retries:
                last_error = f"HTTP {e.code}"
                time.sleep(2 ** attempt)
                continue
            fail(f"Upload failed (HTTP {e.code}): {e.read().decode()[:300]}")
        except URLError as e:
            if attempt < max_retries:
                last_error = str(e.reason)
                time.sleep(2 ** attempt)
                continue
            fail(f"Upload network error: {e.reason}")

    fail(f"Upload failed after {max_retries} retries: {last_error}")


def _get_summary(api_url: str, token: str, doc_id: str) -> dict:
    """Fetch the extracted summary for a document."""
    url = urljoin(api_url.rstrip("/") + "/", f"documents/{doc_id}/summary")
    req = Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except HTTPError as e:
        eprint(f"Summary fetch failed (HTTP {e.code}): {e.read().decode()[:200]}")
        return {}


def _ask_question(api_url: str, token: str, doc_id: str, question: str) -> dict:
    """Ask a question via the Q&A endpoint."""
    url = urljoin(api_url.rstrip("/") + "/", "query")
    payload = json.dumps({
        "question": question,
        "document_ids": [doc_id],
        "stream": False,
    }).encode()
    req = Request(
        url,
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode())
    except HTTPError as e:
        eprint(f"Query failed (HTTP {e.code}): {e.read().decode()[:200]}")
        return {}


# ── Comparison helpers ───────────────────────────────────────────────────


def _compare_scalar(prefix: str, gt: dict, actual: dict, field: str) -> int:
    """Compare a single scalar/optional field. Returns 1 for pass, 0 for skip/mismatch."""
    expected = gt.get(field)
    actual_val = actual.get(field)
    if expected is None:
        return 0  # skip unknown expected values

    if actual_val == expected:
        ok(f"{prefix}.{field} matches", indent=4)
        return 1
    else:
        mismatch(field, expected, actual_val)
        return 0


def _compare_list(prefix: str, gt: list, actual: list, field: str) -> int:
    """Compare two lists ignoring order. Returns number of matching items."""
    if not gt:
        return 0
    gt_set = set(str(x).strip().lower() for x in gt)
    actual_set = set(str(x).strip().lower() for x in actual)
    matches = gt_set & actual_set
    missing = gt_set - actual_set
    if missing:
        print(f"{' ' * 4}⚠️   {field}: missing expected items: {missing}")
    return len(matches)


# ── Cleanup ──────────────────────────────────────────────────────────────


def _cleanup_doc(api_url: str, token: str, doc_id: Optional[str]) -> None:
    """Delete the uploaded document. Safe to call even if upload failed."""
    if not doc_id:
        return
    print("\n── Phase 4: Cleanup ──")
    try:
        del_url = urljoin(api_url.rstrip("/") + "/", f"documents/{doc_id}")
        req = Request(del_url, method="DELETE",
                      headers={"Authorization": f"Bearer {token}"})
        with urlopen(req, timeout=10):
            ok(f"Document {doc_id} deleted")
    except Exception as e:
        eprint(f"  ⚠️  Cleanup failed: {e}")


# ── Main ─────────────────────────────────────────────────────────────────


def main() -> None:
    parser = argparse.ArgumentParser(description="Ground truth verification tool")
    parser.add_argument(
        "--ground-truth",
        required=True,
        help="Path to the ground truth JSON file",
    )
    parser.add_argument(
        "--api-url",
        default="http://127.0.0.1:8000",
        help="Base URL of the CoverWise API",
    )
    parser.add_argument(
        "--retry-summary",
        type=int,
        default=12,
        help="How many times to retry fetching the summary (every 5s)",
    )
    args = parser.parse_args()
    api_url = args.api_url

    # ── Load ground truth ──
    gt_path = Path(args.ground_truth)
    if not gt_path.exists():
        fail(f"Ground truth file not found: {gt_path}")

    with open(gt_path) as f:
        gt = json.load(f)

    meta = gt.get("meta", {})
    pdf_relative = meta.get("policy_document", "")
    policy_type = meta.get("policy_type", "unknown")
    expected = gt.get("expected_extraction", {})
    questions = gt.get("expected_questions", {})

    # Resolve PDF path — try mobile/assets/... first, then project root
    project_root = Path(__file__).resolve().parent.parent
    pdf_path = project_root / "mobile" / pdf_relative
    if not pdf_path.exists():
        pdf_path = project_root / pdf_relative
    if not pdf_path.exists():
        fail(f"Policy document not found: tried {pdf_relative} and mobile/{pdf_relative}")

    token: str = ""
    doc_id: Optional[str] = None

    try:
        print(f"\n{'=' * 60}")
        print(f"  Ground Truth Verification")
        print(f"  Document: {pdf_relative}")
        print(f"  Type:     {policy_type}")
        print(f"  Insurer:  {meta.get('insurer', '?')}")
        print(f"{'=' * 60}\n")

        # ── Phase 1: Upload ──
        print("── Phase 1: Upload ──")
        token = _anon_token(api_url)
        ok("Anonymous token obtained")
        doc_id = _upload_doc(api_url, token, str(pdf_path))
        ok(f"Document uploaded: {doc_id}")
        print()

        # ── Phase 2: Summary extraction ──
        print("── Phase 2: Extraction Comparison ──")
        summary: dict = {}
        for attempt in range(1, args.retry_summary + 1):
            summary = _get_summary(api_url, token, doc_id)
            if summary.get("policy_number") or summary.get("insurer"):
                break
            if attempt < args.retry_summary:
                time.sleep(5)
        else:
            eprint("  ⚠️  Summary extraction did not complete within retry limit")

        passed = 0
        total = 0

        # Generic scalar fields
        for field in (
            "policy_number", "insurer", "insurer_helpline", "insurer_email",
            "document_type", "coverage_amount", "deductible", "premium_amount",
            "premium_frequency",
        ):
            total += 1
            passed += _compare_scalar("extraction", expected, summary, field)

        # List fields
        for field in ("key_benefits", "exclusions", "waiting_periods", "executive_summary"):
            total += 1
            passed += _compare_list(
                "extraction", expected.get(field, []),
                summary.get(field, []), field,
            )

        # Type-specific fields
        type_specific_expected = expected.get("type_specific", {}).get(policy_type, {})
        type_specific_actual = summary.get(f"{policy_type}_fields", {})
        if type_specific_expected:
            print(f"\n  ── Type-specific ({policy_type}) fields ──")
            for field, exp_val in type_specific_expected.items():
                if exp_val is None:
                    continue
                total += 1
                if isinstance(exp_val, list):
                    passed += _compare_list(
                        f"{policy_type}.{field}", exp_val,
                        type_specific_actual.get(field, []), field,
                    )
                else:
                    passed += _compare_scalar(
                        f"{policy_type}", type_specific_expected,
                        type_specific_actual, field,
                    )

        print()
        print(f"  Extraction comparison: {passed}/{total} fields matched")
        print()

        # ── Phase 3: Q&A spot-check ──
        print("── Phase 3: Q&A Spot Check ──")
        known_answers = questions.get("known_answers", [])
        qa_passed = 0
        if known_answers:
            for qa in known_answers:
                question = qa.get("question", "")
                expected_contains = qa.get("expected_answer_contains", "")
                expected_status = qa.get("verification_status", "")

                result = _ask_question(api_url, token, doc_id, question)
                answer_text = (
                    result.get("answer")
                    or result.get("text")
                    or result.get("content", "")
                    or ""
                ).lower()
                status = result.get("verification_status", "unverified")

                if expected_contains and expected_contains.lower() in answer_text:
                    qa_passed += 1
                    ok(f"Q: {question[:60]}...")
                    if expected_status and status == expected_status:
                        ok(f"  verification_status={status}", indent=4)
                    else:
                        skip(f"  status={status} (expected {expected_status})", indent=4)
                else:
                    skip(f"Q: {question[:60]}... answer did not contain expected text")
                    eprint(f"  expected contains: {expected_contains}")
                    eprint(f"  actual answer:     {answer_text[:200]}")

            print(f"\n  Q&A spot check: {qa_passed}/{len(known_answers)} passed")
        else:
            skip("No expected questions in ground truth")
        print()

        # ── Summary / Exit ──
        print(f"{'=' * 60}")
        total_q = len(known_answers)
        if total > 0:
            pct = (passed / total) * 100
            print(f"  Extractions: {passed}/{total} ({pct:.0f}%)")
        if total_q > 0:
            print(f"  Q&A checks:  {qa_passed}/{total_q}")
        print(f"{'=' * 60}")

        # Require at least 3 passing extractions or >= 30% pass rate
        min_pass = max(3, total // 3) if total > 0 else 0
        if passed >= min_pass and (not known_answers or qa_passed > 0):
            print("\n✅  Ground truth verification completed with passing checks.\n")
        else:
            print(f"\n❌  Ground truth verification did not meet minimum threshold "
                  f"({min_pass} passing extractions required, got {passed}).\n")
            sys.exit(1)

    finally:
        # Phase 4: Cleanup always runs
        _cleanup_doc(api_url, token, doc_id)


if __name__ == "__main__":
    main()
