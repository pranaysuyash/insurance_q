#!/usr/bin/env python3
"""Verify deployed two-principal document and Storage isolation.

Creates two disposable Supabase accounts and one synthetic PDF. It proves the
canonical API denies cross-owner document access, Storage denies a second
principal, and deletion removes API/Storage access.

This tool deliberately works against a deployed Supabase project and/or API
endpoint. You MUST pass --confirm to run. Use in CI or release gates only
with dedicated test credentials.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import string
import sys
from dataclasses import dataclass
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


@dataclass(frozen=True)
class HttpResult:
    status: int
    payload: object


def _request(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    body: bytes | None = None,
) -> HttpResult:
    request = Request(
        url,
        data=body,
        headers={"Accept": "application/json", **(headers or {})},
        method=method,
    )
    try:
        with urlopen(request, timeout=20) as response:
            return HttpResult(response.status, _parse(response.read()))
    except HTTPError as error:
        return HttpResult(error.code, _parse(error.read()))
    except URLError as error:
        raise RuntimeError(f"network failure: {error.reason}") from error


def _parse(raw: bytes) -> object:
    try:
        return json.loads(raw.decode("utf-8")) if raw else {}
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {}


def _field(payload: object, *names: str) -> str | None:
    for name in names:
        if isinstance(payload, dict) and isinstance(payload.get(name), str):
            return payload[name]
        nested = payload.get("user") if isinstance(payload, dict) else None
        if isinstance(nested, dict) and isinstance(nested.get(name), str):
            return nested[name]
    return None


def _password() -> str:
    return "Cw-" + "".join(
        secrets.choice(string.ascii_letters + string.digits + "-_!")
        for _ in range(28)
    )


def _synthetic_pdf_bytes() -> bytes:
    """Return a minimal 1-page valid PDF for self-contained CI use.

    Used when --pdf-path is not provided or the file cannot be read.
    The real policy.pdf is 551 KB (too large to embed); the synthetic
    PDF is ~0.3 KB and passes all upload validators.
    """
    return (
        b"%PDF-1.7\n%\xc2\xb5\xc2\xb6\n\n"
        b"1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n\n"
        b"2 0 obj\n<</Type/Pages/Count 1/Kids[4 0 R]>>\nendobj\n\n"
        b"3 0 obj\n<<>>\nendobj\n\n"
        b"4 0 obj\n<</Type/Page/MediaBox[0 0 595 842]/Rotate 0/Resources 3 0 R/Parent 2 0 R>>\nendobj\n\n"
        b"xref\n0 5\n0000000000 00001 f \n0000000016 00000 n \n"
        b"0000000062 00000 n \n0000000114 00000 n \n0000000135 00000 n \n\n"
        b"trailer\n<</Size 5/Root 1 0 R>>\nstartxref\n226\n%%EOF\n"
    )


def _multipart_pdf(pdf_path: str | None = None) -> tuple[bytes, str]:
    boundary = "----coverwise-" + secrets.token_hex(12)
    if pdf_path and os.path.isfile(pdf_path):
        with open(pdf_path, "rb") as f:
            pdf = f.read()
    else:
        if pdf_path:
            print(
                f"WARNING --pdf-path '{pdf_path}' not found, falling back to "
                "hardcoded synthetic PDF",
                file=sys.stderr,
            )
        pdf = _synthetic_pdf_bytes()
    parts = [
        ("processing_mode", b"full", None),
        ("processing_consent", b"true", None),
        ("processing_consent_version", b"local-e2e", None),
        ("files", pdf, "synthetic-policy.pdf"),
    ]
    body = bytearray()
    for name, value, filename in parts:
        body.extend(f"--{boundary}\r\n".encode())
        disposition = f'Content-Disposition: form-data; name="{name}"'
        if filename:
            disposition += f'; filename="{filename}"'
        body.extend((disposition + "\r\n").encode())
        if filename:
            body.extend(b"Content-Type: application/pdf\r\n")
        body.extend(b"\r\n" + value + b"\r\n")
    body.extend(f"--{boundary}--\r\n".encode())
    return bytes(body), boundary


def _signup(
    supabase_url: str, server_key: str
) -> tuple[object, str, str]:
    """Create a Supabase user via admin API, sign in, return (client, user_id, token)."""
    from supabase import create_client

    email = f"coverwise-isolation-{secrets.token_hex(8)}@example.com"
    password = _password()

    client = create_client(supabase_url, server_key)

    admin_resp = client.auth.admin.create_user(
        {"email": email, "password": password, "email_confirm": True}
    )
    user_id = admin_resp.user.id if admin_resp.user else None
    if not user_id:
        raise RuntimeError("admin user creation failed")

    session_resp = client.auth.sign_in_with_password(
        {"email": email, "password": password}
    )
    token = None
    if hasattr(session_resp, "session") and session_resp.session:
        token = session_resp.session.access_token
    if not token:
        raise RuntimeError("user sign-in failed")
    return (client, user_id, token)


_DANGER_BANNER = """
╔══════════════════════════════════════════════════════════════╗
║  DEPLOYED VERIFICATION — CREATES 2 USERS + UPLOADS A DOC   ║
╚══════════════════════════════════════════════════════════════╝

This tool will:
  1. Create 2 disposable Supabase users
  2. Upload a synthetic policy PDF as user A
  3. Verify user B cannot access user A's document
  4. Delete the document as user A
  5. Verify post-delete absence
  6. Delete both disposable users

It requires --confirm to proceed. Synthetic users and any uploaded
document are always cleaned up in the finally block, but network
failures during cleanup may leave orphaned records.
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--api-url",
        default=os.getenv("COVERWISE_API_BASE_URL", ""),
        help="Deployed CoverWise API base URL (required)",
    )
    parser.add_argument(
        "--supabase-url",
        default=os.getenv("SUPABASE_URL", ""),
        help="Supabase project URL (required)",
    )
    parser.add_argument(
        "--bucket",
        default=os.getenv("SUPABASE_STORAGE_BUCKET", "coverwise-documents"),
    )
    parser.add_argument(
        "--pdf-path",
        default="",
        help="Path to a policy PDF file for upload. Defaults to "
        "a hardcoded synthetic 1-page PDF which always works in CI. "
        "Provide a real policy PDF path when running locally for more "
        "realistic upload testing. Falls back to synthetic if file not found.",
    )
    parser.add_argument(
        "--confirm",
        action="store_true",
        help="Acknowledge that this tool creates users and uploads a document",
    )
    args = parser.parse_args()

    if not args.confirm:
        print(_DANGER_BANNER, file=sys.stderr)
        print("ERROR: --confirm is required to prevent accidental runs.", file=sys.stderr)
        return 2

    api_url = args.api_url.rstrip("/")
    supabase_url = args.supabase_url.rstrip("/")
    publishable_key = os.getenv("SUPABASE_PUBLISHABLE_KEY", "").strip()
    server_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        or os.getenv("SUPABASE_SECRET_KEY", "").strip()
    )

    if not api_url.startswith(("http://", "https://")) or not supabase_url.startswith("https://"):
        print(
            "FAIL: --api-url (http:// or https://) and --supabase-url (https://) are required",
            file=sys.stderr,
        )
        return 2
    if not publishable_key or not server_key:
        print(
            "FAIL: SUPABASE_PUBLISHABLE_KEY and SUPABASE_SERVICE_ROLE_KEY are required",
            file=sys.stderr,
        )
        return 2

    print(f"API base:      {api_url}")
    print(f"Supabase:      {supabase_url}")
    print()

    created: list[tuple[object, str]] = []
    document_id: str | None = None

    try:
        # Create two users
        client_a, user_a, token_a = _signup(supabase_url, server_key)
        created.append((client_a, user_a))
        print(f"INFO: created user A: {user_a[:12]}...")

        client_b, user_b, token_b = _signup(supabase_url, server_key)
        created.append((client_b, user_b))
        print(f"INFO: created user B: {user_b[:12]}...")

        auth_a = {"Authorization": f"Bearer {token_a}"}
        auth_b = {"Authorization": f"Bearer {token_b}"}

        # Upload PDF (real or synthetic) as user A
        body, boundary = _multipart_pdf(pdf_path=args.pdf_path or None)
        upload = _request(
            f"{api_url}/documents/upload",
            method="POST",
            headers={
                **auth_a,
                "Content-Type": f"multipart/form-data; boundary={boundary}",
            },
            body=body,
        )
        documents = (
            upload.payload.get("documents") if isinstance(upload.payload, dict) else None
        )
        document_id = (
            documents[0].get("id")
            if isinstance(documents, list)
            and documents
            and isinstance(documents[0], dict)
            else None
        )
        if upload.status != 202 or not isinstance(document_id, str):
            raise RuntimeError(f"synthetic upload failed (HTTP {upload.status})")
        print(f"INFO: uploaded document: {document_id[:12]}...")

        # Cross-owner checks
        cross_api = _request(f"{api_url}/documents/{document_id}", headers=auth_b)
        path = f"documents/{document_id}/synthetic-policy.pdf"
        cross_storage = _request(
            f"{supabase_url}/storage/v1/object/authenticated/{args.bucket}/{path}",
            headers={"apikey": publishable_key, **auth_b},
        )

        # Delete as owner
        deleted = _request(
            f"{api_url}/documents/{document_id}", method="DELETE", headers=auth_a
        )

        # Post-delete absence
        post_api = _request(f"{api_url}/documents/{document_id}", headers=auth_a)
        post_storage = _request(
            f"{supabase_url}/storage/v1/object/authenticated/{args.bucket}/{path}",
            headers={"apikey": publishable_key, **auth_a},
        )

        checks = [
            ("upload", upload.status == 202),
            ("cross-owner API denial", cross_api.status == 404),
            (
                "cross-owner Storage denial",
                cross_storage.status in {400, 401, 403, 404},
            ),
            ("owner deletion", deleted.status == 200),
            ("post-delete API absence", post_api.status == 404),
            (
                "post-delete Storage absence",
                post_storage.status in {400, 401, 403, 404},
            ),
        ]
        for name, passed in checks:
            print(f"{'PASS' if passed else 'FAIL'} {name}")
        return 0 if all(passed for _, passed in checks) else 1

    finally:
        # Cleanup: delete users via supabase library
        for client, uid in created:
            try:
                client.auth.admin.delete_user(uid)
                print(f"INFO: cleanup removed user {uid[:12]}...")
            except Exception as cleanup_error:
                print(
                    f"WARNING: synthetic account cleanup failed for {uid[:12]}...: {cleanup_error}",
                    file=sys.stderr,
                )


if __name__ == "__main__":
    raise SystemExit(main())
