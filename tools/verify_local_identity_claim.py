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


def _parse_payload(raw: str) -> object:
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def _is_local_supabase_url(url: str) -> bool:
    return url.startswith(("http://127.0.0.1:", "http://localhost:"))


def _random_password() -> str:
    alphabet = string.ascii_letters + string.digits + "-_!"
    return "Cw-" + "".join(secrets.choice(alphabet) for _ in range(28))


def _field(payload: object, name: str) -> str | None:
    return payload.get(name) if isinstance(payload, dict) and isinstance(payload.get(name), str) else None


def _nested_field(payload: object, parent: str, name: str) -> str | None:
    nested = payload.get(parent) if isinstance(payload, dict) else None
    return _field(nested, name)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--api-url", default=os.getenv("COVERWISE_API_BASE_URL", "http://127.0.0.1:8005"))
    parser.add_argument("--supabase-url", default=os.getenv("SUPABASE_URL", "http://127.0.0.1:54321"))
    args = parser.parse_args()

    supabase_url = args.supabase_url.rstrip("/")
    api_url = args.api_url.rstrip("/")
    publishable_key = os.getenv("SUPABASE_PUBLISHABLE_KEY", "").strip()
    server_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        or os.getenv("SUPABASE_SECRET_KEY", "").strip()
    )
    if not _is_local_supabase_url(supabase_url):
        print("FAIL local-only guard: SUPABASE_URL must point to localhost", file=sys.stderr)
        return 2
    if not publishable_key or not server_key:
        print("FAIL configuration: Supabase publishable and server keys are required", file=sys.stderr)
        return 2

    email = f"coverwise-e2e-{secrets.token_hex(8)}@example.com"
    password = _random_password()
    user_id: str | None = None
    auth_headers = {"apikey": publishable_key}
    admin_headers = {"apikey": server_key, "Authorization": f"Bearer {server_key}"}
    checks: list[tuple[str, bool, str]] = []
    try:
        signup = _json_request(
            f"{supabase_url}/auth/v1/signup",
            method="POST",
            headers=auth_headers,
            payload={"email": email, "password": password},
        )
        user_id = (
            _field(signup.payload, "id")
            or _field(signup.payload, "user_id")
            or _nested_field(signup.payload, "user", "id")
        )
        access_token = _field(signup.payload, "access_token")
        checks.append(("local Supabase account signup", signup.status in {200, 201} and bool(user_id), f"HTTP {signup.status}"))
        if not user_id or not access_token:
            print("FAIL account signup did not return a usable local session", file=sys.stderr)
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
    finally:
        if user_id:
            cleanup = _json_request(
                f"{supabase_url}/auth/v1/admin/users/{user_id}",
                method="DELETE",
                headers=admin_headers,
            )
            if cleanup.status not in {200, 204}:
                print(f"WARNING synthetic account cleanup returned HTTP {cleanup.status}", file=sys.stderr)


def _report(checks: list[tuple[str, bool, str]]) -> int:
    for name, ok, detail in checks:
        print(f"{'PASS' if ok else 'FAIL'} {name}: {detail}")
    return 0 if checks and all(ok for _, ok, _ in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
