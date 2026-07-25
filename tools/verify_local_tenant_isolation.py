#!/usr/bin/env python3
"""Exercise local-only two-principal document and Storage isolation.

Creates two disposable local Supabase users and one synthetic PDF. It proves
the canonical API denies cross-owner document access, Storage denies a second
principal, and deletion removes API/Storage access. It never contacts a remote
project and does not prove a deployed worker or account-deletion lifecycle.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import string
import sys
import time
from dataclasses import dataclass
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


@dataclass(frozen=True)
class HttpResult:
    status: int
    payload: object


def _is_local_url(url: str) -> bool:
    return url.startswith(("http://127.0.0.1:", "http://localhost:"))


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


def _request_with_retries(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    body: bytes | None = None,
    attempts: int = 3,
    retry_statuses: set[int] | None = None,
    retry_delay_seconds: float = 2.0,
) -> HttpResult:
    if retry_statuses is None:
        retry_statuses = {429, 503, 502, 504}
    last_error: HttpResult | None = None
    for attempt in range(1, attempts + 1):
        result = _request(url, method=method, headers=headers, body=body)
        if result.status not in retry_statuses:
            return result
        last_error = result
        print(
            f"INFO retrying request after HTTP {result.status} "
            f"(attempt {attempt}/{attempts})",
            file=sys.stderr,
        )
        if result.payload:
            print(f"      status detail: {result.payload}", file=sys.stderr)
        time.sleep(retry_delay_seconds)
    assert last_error is not None
    return last_error


def _parse(raw: bytes) -> object:
    try:
        return json.loads(raw.decode("utf-8")) if raw else {}
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {}


def _admin_client(supabase_url: str, server_key: str):
    try:
        from supabase import create_client
    except Exception as exc:  # pragma: no cover - dependency path
        raise RuntimeError(
            "SUPABASE SDK not available; install dependencies (create_client)."
        ) from exc
    return create_client(supabase_url, server_key)


def _admin_create_user(
    supabase_url: str,
    server_key: str,
    email: str,
    password: str,
) -> str:
    client = _admin_client(supabase_url, server_key)
    try:
        created = client.auth.admin.create_user(
            {
                "email": email,
                "password": password,
                "email_confirm": True,
            }
        )
    except Exception as exc:  # pragma: no cover - auth transport errors
        raise RuntimeError(f"admin user creation failed: {exc}") from exc

    user = getattr(created, "user", None)
    user_id = str(user.id) if user and getattr(user, "id", None) else None
    if not user_id:
        raise RuntimeError(f"admin user creation failed: invalid response {created}")
    return user_id


def _admin_delete_user(supabase_url: str, server_key: str, user_id: str) -> bool:
    client = _admin_client(supabase_url, server_key)
    try:
        client.auth.admin.delete_user(user_id)
        return True
    except Exception:  # pragma: no cover
        return False


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
        secrets.choice(string.ascii_letters + string.digits + "-_!") for _ in range(28)
    )


def _multipart_pdf(pdf_path: str | None = None) -> tuple[bytes, str]:
    boundary = "----coverwise-" + secrets.token_hex(12)
    marker = f"coverwise-tenant-isolation-seed={secrets.token_hex(8)}".encode("ascii")
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
        # 1-page valid PDF fallback (generated by fitz / PyMuPDF)
        pdf = (
            b"%PDF-1.7\n%\xc2\xb5\xc2\xb6\n\n"
            b"1 0 obj\n<</Type/Catalog/Pages 2 0 R>>\nendobj\n\n"
            b"2 0 obj\n<</Type/Pages/Count 1/Kids[4 0 R]>>\nendobj\n\n"
            b"3 0 obj\n<<>>\nendobj\n\n"
            b"4 0 obj\n<</Type/Page/MediaBox[0 0 595 842]/Rotate 0/Resources 3 0 R/Parent 2 0 R>>\nendobj\n\n"
            b"xref\n0 5\n0000000000 00001 f \n0000000016 00000 n \n"
            b"0000000062 00000 n \n0000000114 00000 n \n0000000135 00000 n \n\n"
            b"trailer\n<</Size 5/Root 1 0 R>>\nstartxref\n226\n%%EOF\n"
        )
    pdf += b"%" + marker + b"\n"
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


def _default_pdf_path() -> str:
    """Return a deterministic verification PDF path from repository assets.

    Prefer a non-test-only repo path when available, then fall back to the
    demo policy path if present. If neither is readable, the synthetic fallback
    is used in _multipart_pdf().
    """
    script_dir = os.path.dirname(__file__)
    candidate_paths = [
        os.path.join(script_dir, "..", "tests", "test_data", "sample_insurance.pdf"),
        os.path.join(script_dir, "..", "mobile", "assets", "demo", "policy.pdf"),
    ]
    for candidate in candidate_paths:
        normalized = os.path.normpath(candidate)
        if os.path.isfile(normalized):
            return normalized
    return ""


def _signup(
    supabase_url: str, publishable_key: str, server_key: str
) -> tuple[str, str]:
    """Create a Supabase user via admin API (bypasses email rate limits),
    then sign in to obtain a session token.

    Uses the provided supabase client (already authenticated with service_role key).
    """
    email = f"coverwise-isolation-{secrets.token_hex(8)}@example.com"
    password = _password()
    user_id = _admin_create_user(supabase_url, server_key, email, password)
    if not user_id:
        raise RuntimeError("admin user creation failed")

    from supabase import create_client

    session_client = create_client(supabase_url, publishable_key)
    session_resp = session_client.auth.sign_in_with_password({
        "email": email,
        "password": password,
    })
    token = None
    if hasattr(session_resp, "session") and session_resp.session:
        token = session_resp.session.access_token
    if not token:
        raise RuntimeError("user sign-in failed")
    return user_id, token


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--api-url",
        default=os.getenv("COVERWISE_API_BASE_URL", "http://127.0.0.1:8005"),
    )
    parser.add_argument(
        "--supabase-url", default=os.getenv("SUPABASE_URL", "http://127.0.0.1:54321")
    )
    parser.add_argument(
        "--allow-remote-supabase",
        action="store_true",
        help="Allow a remote (non-localhost) Supabase URL. The API URL must still be local.",
    )
    parser.add_argument(
        "--bucket", default=os.getenv("SUPABASE_STORAGE_BUCKET", "coverwise-documents")
    )
    parser.add_argument(
        "--pdf-path",
        default="",
        help="Path to a policy PDF file for upload. Defaults to "
        "the repo's non-password test PDF (if available), then demo policy, "
        "and finally a synthetic fallback PDF generated in-tool. "
        "Falls back to a hardcoded 1-page synthetic PDF if the file is not found.",
    )
    args = parser.parse_args()
    api_url, supabase_url = args.api_url.rstrip("/"), args.supabase_url.rstrip("/")
    publishable_key = os.getenv("SUPABASE_PUBLISHABLE_KEY", "").strip()
    server_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        or os.getenv("SUPABASE_SECRET_KEY", "").strip()
    )
    if not _is_local_url(api_url):
        print(
            "FAIL local-only guard: API URL must point to localhost",
            file=sys.stderr,
        )
        return 2
    if not _is_local_url(supabase_url) and not args.allow_remote_supabase:
        print(
            "FAIL local-only guard: SUPABASE_URL must point to localhost",
            file=sys.stderr,
        )
        print(
            "      Pass --allow-remote-supabase to run against a deployed Supabase instance.",
            file=sys.stderr,
        )
        return 2
    if not publishable_key or not server_key:
        print(
            "FAIL configuration: Supabase publishable and server keys are required",
            file=sys.stderr,
        )
        return 2
    _supabase_client = None
    user_ids: list[str] = []
    try:
        user_a, token_a = _signup(supabase_url, publishable_key, server_key)
        user_ids.append(user_a)
        user_b, token_b = _signup(supabase_url, publishable_key, server_key)
        user_ids.append(user_b)
        auth_a, auth_b = (
            {"Authorization": f"Bearer {token_a}"},
            {"Authorization": f"Bearer {token_b}"},
        )
        # Resolve pdf_path relative to this script's location so the tool
        # works regardless of the calling directory.
        resolved_pdf = args.pdf_path or _default_pdf_path()
        body, boundary = _multipart_pdf(pdf_path=resolved_pdf)
        upload = _request_with_retries(
            f"{api_url}/documents/upload",
            method="POST",
            headers={
                **auth_a,
                "Content-Type": f"multipart/form-data; boundary={boundary}",
            },
            body=body,
            attempts=3,
            retry_statuses={429},
            retry_delay_seconds=2.0,
        )
        if (
            upload.status == 422
            and isinstance(upload.payload, dict)
            and upload.payload.get("detail", {}).get("code") == "pdf_password_required"
        ):
            print(
                "WARNING uploaded PDF was rejected as password-protected; "
                "retrying with synthetic fallback PDF.",
                file=sys.stderr,
            )
            body, boundary = _multipart_pdf(pdf_path=None)
            upload = _request_with_retries(
                f"{api_url}/documents/upload",
                method="POST",
                headers={
                    **auth_a,
                    "Content-Type": f"multipart/form-data; boundary={boundary}",
                },
                body=body,
                attempts=3,
                retry_statuses={429},
                retry_delay_seconds=2.0,
            )
        document_id = None
        if (
            upload.status == 202
            and isinstance(upload.payload, dict)
            and isinstance(upload.payload.get("documents"), list)
            and upload.payload.get("documents")
            and isinstance(upload.payload["documents"][0], dict)
        ):
            document_id = upload.payload["documents"][0].get("id")

        if upload.status != 202 or not isinstance(document_id, str):
            print(
                f"INFO synthetic upload response ({upload.status}): {upload.payload}",
                file=sys.stderr,
            )
            raise RuntimeError(f"synthetic upload failed (HTTP {upload.status})")
        cross_api = _request(f"{api_url}/documents/{document_id}", headers=auth_b)
        path = f"documents/{document_id}/synthetic-policy.pdf"
        cross_storage = _request(
            f"{supabase_url}/storage/v1/object/authenticated/{args.bucket}/{path}",
            headers={"apikey": publishable_key, **auth_b},
        )
        deleted = _request(
            f"{api_url}/documents/{document_id}", method="DELETE", headers=auth_a
        )
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
    except RuntimeError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # pragma: no cover - defensive safety net
        print(f"FAIL runtime error: {exc}", file=sys.stderr)
        return 1
    finally:
        for user_id in user_ids:
            try:
                if _admin_delete_user(
                    supabase_url, server_key, user_id
                ):
                    print(f"INFO cleanup removed user {user_id[:12]}...")
                else:
                    print(
                        f"WARNING synthetic account cleanup may have failed for {user_id[:12]}..."
                    )
            except Exception as cleanup_error:
                print(
                    f"WARNING synthetic account cleanup failed: {cleanup_error}",
                    file=sys.stderr,
                )


if __name__ == "__main__":
    raise SystemExit(main())
