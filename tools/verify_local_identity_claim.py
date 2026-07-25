#!/usr/bin/env python3
"""Verify the local guest-to-account identity claim contract.

This is deliberately local-only and creates then removes a synthetic Supabase
account. It proves the real Auth, API, identity-link, and profile boundaries;
it does not upload a document or print credentials.
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


def _json_request(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    payload: object | None = None,
) -> HttpResult:
    request_headers = {"Accept": "application/json", **(headers or {})}
    body = None
    if payload is not None:
        request_headers["Content-Type"] = "application/json"
        body = json.dumps(payload).encode("utf-8")
    request = Request(url, data=body, headers=request_headers, method=method)
    try:
        with urlopen(request, timeout=15) as response:
            raw = response.read().decode("utf-8")
            return HttpResult(response.status, _parse_payload(raw))
    except HTTPError as error:
        raw = error.read().decode("utf-8")
        return HttpResult(error.code, _parse_payload(raw))
    except URLError as error:
        raise RuntimeError(f"network failure: {error.reason}") from error


def _admin_client(supabase_url: str, server_key: str):
    try:
        from supabase import create_client
    except Exception as exc:  # pragma: no cover - dependency path
        raise RuntimeError(
            "SUPABASE SDK not available; install dependencies (create_client)."
        ) from exc
    return create_client(supabase_url, server_key)


def _admin_create_user(
    supabase_url: str, server_key: str, email: str, password: str
) -> str:
    client = _admin_client(supabase_url, server_key)
    try:
        created = client.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": True,
        })
    except Exception as exc:  # pragma: no cover - auth transport errors
        raise RuntimeError(f"admin user creation failed: {exc}") from exc

    payload = _admin_payload(created)
    user_id = _field(payload, "id")
    if not user_id:
        raise RuntimeError(f"admin user creation failed: invalid response {payload}")
    return user_id


def _admin_delete_user(supabase_url: str, server_key: str, user_id: str) -> bool:
    client = _admin_client(supabase_url, server_key)
    try:
        client.auth.admin.delete_user(user_id)
        return True
    except Exception:  # pragma: no cover - delete transport errors
        return False


def _parse_payload(raw: str) -> object:
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def _is_local_url(url: str) -> bool:
    return url.startswith(("http://127.0.0.1:", "http://localhost:"))


def _random_password() -> str:
    alphabet = string.ascii_letters + string.digits + "-_!"
    return "Cw-" + "".join(secrets.choice(alphabet) for _ in range(28))


def _field(payload: object, name: str) -> str | None:
    return payload.get(name) if isinstance(payload, dict) and isinstance(payload.get(name), str) else None


def _nested_field(payload: object, parent: str, name: str) -> str | None:
    nested = payload.get(parent) if isinstance(payload, dict) else None
    return _field(nested, name)


def _admin_payload(admin_result: object) -> object:
    if not admin_result:
        return {}
    if isinstance(admin_result, dict):
        return admin_result
    user = getattr(admin_result, "user", None)
    if user is None:
        return {}
    return user.__dict__ if hasattr(user, "__dict__") else {"id": str(user.id) if getattr(user, "id", None) else None}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-url", default=os.getenv("COVERWISE_API_BASE_URL", "http://127.0.0.1:8005"))
    parser.add_argument("--supabase-url", default=os.getenv("SUPABASE_URL", "http://127.0.0.1:54321"))
    parser.add_argument(
        "--allow-remote-supabase",
        action="store_true",
        help="Allow a remote (non-localhost) Supabase URL. The API URL must still be local.",
    )
    args = parser.parse_args()

    supabase_url = args.supabase_url.rstrip("/")
    api_url = args.api_url.rstrip("/")
    publishable_key = os.getenv("SUPABASE_PUBLISHABLE_KEY", "").strip()
    server_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        or os.getenv("SUPABASE_SECRET_KEY", "").strip()
    )
    if not _is_local_url(supabase_url) and not args.allow_remote_supabase:
        print("FAIL local-only guard: SUPABASE_URL must point to localhost", file=sys.stderr)
        print("      Pass --allow-remote-supabase to run against a deployed Supabase instance.", file=sys.stderr)
        return 2
    if not _is_local_url(api_url):
        print("FAIL local-only guard: API URL must point to localhost", file=sys.stderr)
        return 2
    if not publishable_key or not server_key:
        print("FAIL configuration: Supabase publishable and server keys are required", file=sys.stderr)
        return 2

    email = f"coverwise-e2e-{secrets.token_hex(8)}@example.com"
    password = _random_password()
    user_id: str | None = None
    access_token: str | None = None
    _supabase = None
    checks: list[tuple[str, bool, str]] = []
    try:
        # Use supabase Python library (handles JWT internally via service_role key)
        from supabase import create_client

        _supabase = create_client(supabase_url, publishable_key)

        # Create user via admin API (bypasses email rate limits)
        user_id = _admin_create_user(supabase_url, server_key, email, password)
        checks.append(("admin user creation", bool(user_id), "via supabase admin client"))
        if not user_id:
            return 1

        # Sign in to get a session token
        session_resp = _supabase.auth.sign_in_with_password({
            "email": email,
            "password": password,
        })
        session = session_resp
        if hasattr(session, "session") and session.session:
            access_token = session.session.access_token
        elif isinstance(session, dict):
            access_token = session.get("access_token")
        checks.append(("user sign-in", bool(access_token), "via supabase lib"))
        if not access_token:
            print("FAIL user sign-in did not return an access token", file=sys.stderr)
            return 1

        guest = _json_request(f"{api_url}/user/anonymous", method="POST")
        guest_token = _field(guest.payload, "access_token")
        guest_uid = _field(guest.payload.get("user") if isinstance(guest.payload, dict) else {}, "uid")
        checks.append(("anonymous identity", guest.status == 200 and bool(guest_token and guest_uid), f"HTTP {guest.status}"))
        if not guest_token or not guest_uid:
            return _report(checks)

        claim = _json_request(
            f"{api_url}/user/claim-anonymous",
            method="POST",
            headers={"Authorization": f"Bearer {access_token}"},
            payload={"anonymous_token": guest_token},
        )
        claim_status = claim.status == 200 and isinstance(claim.payload, dict) and claim.payload.get("identity_link_status") == "completed"
        checks.append(("guest-to-account claim", claim_status, f"HTTP {claim.status}"))

        profile = _json_request(
            f"{api_url}/user/profile",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        profile_ok = profile.status == 200 and isinstance(profile.payload, dict) and profile.payload.get("uid") == user_id and profile.payload.get("identity_type") == "account"
        checks.append(("account profile", profile_ok, f"HTTP {profile.status}"))
        return _report(checks)
    except RuntimeError as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # pragma: no cover - defensive safety net
        print(f"FAIL runtime error: {exc}", file=sys.stderr)
        return 1
    finally:
        if user_id:
            try:
                if _supabase is not None and _admin_delete_user(supabase_url, server_key, user_id):
                    print(f"INFO cleanup removed user {user_id[:12]}...")
                elif _supabase is not None:
                    print(f"WARNING synthetic account cleanup returned non-success for {user_id[:12]}...")
            except Exception as cleanup_error:
                print(
                    f"WARNING synthetic account cleanup failed: {cleanup_error}",
                    file=sys.stderr,
                )


def _report(checks: list[tuple[str, bool, str]]) -> int:
    for name, ok, detail in checks:
        print(f"{'PASS' if ok else 'FAIL'} {name}: {detail}")
    return 0 if checks and all(ok for _, ok, _ in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
