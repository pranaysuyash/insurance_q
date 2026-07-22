#!/usr/bin/env python3
"""Launch smoke verifier for a deployed CoverWise API.

The default checks are non-mutating. The optional identity-isolation probe
creates two anonymous identities and therefore requires explicit operator
authorization. It never uploads a policy or prints bearer tokens.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


@dataclass(frozen=True)
class Result:
    name: str
    ok: bool
    detail: str


def request(base_url: str, path: str, *, method: str = "GET", token: str | None = None,
            origin: str | None = None) -> tuple[int, dict[str, str], object]:
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if origin:
        headers["Origin"] = origin
    body = b"" if method == "OPTIONS" else None
    if method == "OPTIONS":
        headers["Access-Control-Request-Method"] = "GET"
    req = Request(f"{base_url.rstrip('/')}{path}", data=body, headers=headers, method=method)
    try:
        with urlopen(req, timeout=15) as response:
            payload = response.read().decode("utf-8")
            if not payload:
                parsed: object = {}
            else:
                try:
                    parsed = json.loads(payload)
                except json.JSONDecodeError:
                    parsed = {}
            return response.status, dict(response.headers.items()), parsed
    except HTTPError as error:
        payload = error.read().decode("utf-8")
        try:
            parsed: object = json.loads(payload)
        except json.JSONDecodeError:
            parsed = {}
        return error.code, dict(error.headers.items()), parsed
    except URLError as error:
        raise RuntimeError(f"network failure: {error.reason}") from error


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True, help="Deployed HTTPS API URL")
    parser.add_argument(
        "--worker-url",
        help="Optional internal URL for the durable outbox worker health listener",
    )
    parser.add_argument("--origin", help="Expected public web origin for CORS verification")
    parser.add_argument(
        "--allow-identity-creation",
        action="store_true",
        help="Authorize creation of two anonymous identities for owner-isolation checks",
    )
    args = parser.parse_args()
    base_url = args.base_url.rstrip("/")
    results: list[Result] = []

    try:
        status, _, payload = request(base_url, "/healthz")
        results.append(Result("liveness", status == 200 and payload == {"status": "live", "version": "2.0.0"}, f"HTTP {status}"))

        status, _, payload = request(base_url, "/readyz")
        results.append(Result("readiness", status == 200 and payload.get("status") == "ready" if isinstance(payload, dict) else False, f"HTTP {status}"))

        status, _, payload = request(base_url, "/health")
        # The canonical FastAPI contract returns ``status: ok`` for a healthy
        # integrated service and ``status: degraded``/503 when its embedding
        # probe fails. Do not broaden this to any arbitrary 2xx response.
        health_ok = (
            status == 200
            and isinstance(payload, dict)
            and payload.get("status") == "ok"
        )
        results.append(Result("service health", health_ok, f"HTTP {status}"))

        if args.worker_url:
            worker_status, _, worker_payload = request(
                args.worker_url.rstrip("/"), "/readyz"
            )
            worker_ok = (
                worker_status == 200
                and isinstance(worker_payload, dict)
                and worker_payload.get("status") == "ready"
                and worker_payload.get("worker") == "outbox"
            )
            results.append(
                Result("durable outbox worker readiness", worker_ok,
                       f"HTTP {worker_status}")
            )

        status, _, _ = request(base_url, "/documents?page=1&limit=10")
        results.append(Result("unauthenticated document rejection", status == 401, f"HTTP {status}"))

        if args.allow_identity_creation:
            identities: list[tuple[str, str]] = []
            for index in range(2):
                status, _, payload = request(base_url, "/user/anonymous", method="POST")
                token = payload.get("access_token") if isinstance(payload, dict) else None
                uid = payload.get("user", {}).get("uid") if isinstance(payload, dict) else None
                results.append(Result(f"anonymous identity {index + 1}", status == 200 and isinstance(token, str) and isinstance(uid, str), f"HTTP {status}"))
                if isinstance(token, str) and isinstance(uid, str):
                    identities.append((token, uid))

            for index, (token, expected_uid) in enumerate(identities):
                status, _, profile = request(base_url, "/user/profile", token=token)
                profile_ok = status == 200 and isinstance(profile, dict) and profile.get("uid") == expected_uid
                results.append(Result(f"identity {index + 1} profile", profile_ok, f"HTTP {status}"))
                status, _, documents = request(base_url, "/documents?page=1&limit=10", token=token)
                list_ok = status == 200 and isinstance(documents, dict) and isinstance(documents.get("documents"), list)
                results.append(Result(f"identity {index + 1} owner-scoped list", list_ok, f"HTTP {status}"))

            if len(identities) == 2:
                results.append(Result("distinct anonymous owners", identities[0][1] != identities[1][1], "subjects compared"))
        else:
            results.append(Result("anonymous owner-isolation probe", True, "SKIP: pass --allow-identity-creation to authorize test identities"))

        if args.origin:
            status, headers, _ = request(base_url, "/healthz", method="OPTIONS", origin=args.origin)
            cors_value = headers.get("access-control-allow-origin", "")
            results.append(Result("CORS allowlist", status in {200, 204} and cors_value == args.origin, f"HTTP {status}, origin={cors_value or 'absent'}"))
    except RuntimeError as error:
        print(f"launch verifier failed before checks: {error}", file=sys.stderr)
        return 2

    for result in results:
        print(f"{'PASS' if result.ok else 'FAIL'} {result.name}: {result.detail}")
    return 0 if results and all(result.ok for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
