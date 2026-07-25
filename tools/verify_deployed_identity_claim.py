#!/usr/bin/env python3
"""Verify the deployed guest-to-account identity claim contract.

Creates a synthetic Supabase account via the Admin API (bypasses email rate
limits), then exercises the anonymous identity, claim-anonymous, and profile
endpoints. Removes the synthetic account before exit.

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


def _parse_payload(raw: str) -> object:
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def _random_password() -> str:
    alphabet = string.ascii_letters + string.digits + "-_!"
    return "Cw-" + "".join(secrets.choice(alphabet) for _ in range(28))


def _field(payload: object, name: str) -> str | None:
    return (
        payload.get(name)
        if isinstance(payload, dict) and isinstance(payload.get(name), str)
        else None
    )


_DANGER_BANNER = """
╔══════════════════════════════════════════════════════════════╗
║  DEPLOYED VERIFICATION — CREATES AND DELETES SUPABASE USER ║
╚══════════════════════════════════════════════════════════════╝

This tool will:
  1. Create a disposable Supabase user (email + password)
  2. Create an anonymous identity via the API
  3. Claim the anonymous identity to the account
  4. Verify the account profile
  5. Delete the disposable user

It requires --confirm to proceed. The synthetic user is always
cleaned up in the finally block, but network failures during
cleanup may leave orphaned records.
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
        "--confirm",
        action="store_true",
        help="Acknowledge that this tool will create/delete a real Supabase user",
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

    email = f"coverwise-e2e-{secrets.token_hex(8)}@example.com"
    password = _random_password()
    user_id: str | None = None
    access_token: str | None = None
    _supabase = None
    checks: list[tuple[str, bool, str]] = []
    try:
        # Use supabase Python library (handles JWT internally via service_role key)
        from supabase import create_client

        _supabase = create_client(supabase_url, server_key)

        # Create user via admin API (bypasses email rate limits)
        admin_resp = _supabase.auth.admin.create_user(
            {
                "email": email,
                "password": password,
                "email_confirm": True,
            }
        )
        created_user = admin_resp.user
        user_id = created_user.id if created_user else None
        checks.append(("admin user creation", bool(user_id), "via supabase lib"))
        if not user_id:
            print("FAIL: admin user creation did not return a user ID", file=sys.stderr)
            return 1

        # Sign in to get a session token
        session_resp = _supabase.auth.sign_in_with_password(
            {"email": email, "password": password}
        )
        if hasattr(session_resp, "session") and session_resp.session:
            access_token = session_resp.session.access_token
        elif isinstance(session_resp, dict):
            access_token = session_resp.get("access_token")
        checks.append(("user sign-in", bool(access_token), "via supabase lib"))
        if not access_token:
            print("FAIL: user sign-in did not return an access token", file=sys.stderr)
            return 1

        # Anonymous identity via API
        guest = _json_request(f"{api_url}/user/anonymous", method="POST")
        guest_token = _field(guest.payload, "access_token")
        guest_uid = _field(
            guest.payload.get("user") if isinstance(guest.payload, dict) else {}, "uid"
        )
        checks.append(
            (
                "anonymous identity",
                guest.status == 200 and bool(guest_token and guest_uid),
                f"HTTP {guest.status}",
            )
        )
        if not guest_token or not guest_uid:
            return _report(checks)

        # Claim anonymous to account
        claim = _json_request(
            f"{api_url}/user/claim-anonymous",
            method="POST",
            headers={"Authorization": f"Bearer {access_token}"},
            payload={"anonymous_token": guest_token},
        )
        claim_status = (
            claim.status == 200
            and isinstance(claim.payload, dict)
            and claim.payload.get("identity_link_status") == "completed"
        )
        checks.append(("guest-to-account claim", claim_status, f"HTTP {claim.status}"))

        # Profile check
        profile = _json_request(
            f"{api_url}/user/profile",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        profile_ok = (
            profile.status == 200
            and isinstance(profile.payload, dict)
            and profile.payload.get("uid") == user_id
            and profile.payload.get("identity_type") == "account"
        )
        checks.append(("account profile", profile_ok, f"HTTP {profile.status}"))
        return _report(checks)
    finally:
        if user_id:
            try:
                if _supabase is not None:
                    _supabase.auth.admin.delete_user(user_id)
                    print(f"INFO: cleanup removed user {user_id[:12]}...")
            except Exception as cleanup_error:
                print(
                    f"WARNING: synthetic account cleanup failed: {cleanup_error}",
                    file=sys.stderr,
                )


def _report(checks: list[tuple[str, bool, str]]) -> int:
    for name, ok, detail in checks:
        print(f"{'PASS' if ok else 'FAIL'} {name}: {detail}")
    return 0 if checks and all(ok for _, ok, _ in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
