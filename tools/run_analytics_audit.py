#!/usr/bin/env python3
"""Analytics pipeline live audit — fire test events and verify they appear.

Usage:
    # Start API with operator token then run audit
    OPERATOR_DASHBOARD_TOKEN='test-operator-token-2026' \\
        .venv/bin/uvicorn src.app.main:app --host 127.0.0.1 --port 8005 &
    python3 tools/run_analytics_audit.py --port 8005

Or use the shell wrapper:
    bash tools/run_analytics_audit.sh [port]
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

DEFAULT_PORT = 8005
DEFAULT_OPERATOR_TOKEN = os.environ.get(
    "OPERATOR_DASHBOARD_TOKEN", "test-operator-token-2026"
)


def api_url(port: int, path: str) -> str:
    return f"http://127.0.0.1:{port}{path}"


def request(
    port: int,
    method: str,
    path: str,
    data: dict | None = None,
    bearer: str | None = None,
    operator_token: str | None = None,
) -> tuple[int, dict]:
    """Make an HTTP request and return (status_code, parsed_json)."""
    url = api_url(port, path)
    headers: dict[str, str] = {
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if bearer:
        headers["Authorization"] = f"Bearer {bearer}"
    if operator_token:
        headers["X-Operator-Token"] = operator_token
    body = json.dumps(data).encode("utf-8") if data else None

    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        try:
            detail = json.loads(e.read().decode("utf-8"))
        except (json.JSONDecodeError, AttributeError):
            detail = {"detail": str(e)}
        return e.code, detail
    except urllib.error.URLError as e:
        return 0, {"detail": f"Connection failed: {e.reason}"}


def step(label: str) -> None:
    print(f"\n{'=' * 70}")
    print(f"  {label}")
    print(f"{'=' * 70}")


def ok(msg: str) -> None:
    print(f"  ✅ {msg}")


def fail(msg: str) -> None:
    print(f"  ❌ {msg}")


def warn(msg: str) -> None:
    print(f"  ⚠️  {msg}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run analytics pipeline audit")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="API port")
    parser.add_argument(
        "--start-api", action="store_true", help="Start API if not running"
    )
    parser.add_argument(
        "--operator-token",
        type=str,
        default=DEFAULT_OPERATOR_TOKEN,
        help="Operator dashboard token",
    )
    args = parser.parse_args()

    port = args.port
    operator_token = args.operator_token
    result_status = 0  # tracks overall audit pass/fail

    # ── Step 0: Check if API is running ──
    step("Step 0: Check API availability")

    status, health = request(port, "GET", "/healthz")
    if status == 200:
        ok(f"API is live on port {port} (version: {health.get('version', '?')})")
    elif args.start_api:
        warn(f"API not reachable on port {port}. Attempting to start...")
        env = os.environ.copy()
        env["OPERATOR_DASHBOARD_TOKEN"] = operator_token
        proc = subprocess.Popen(
            [
                sys.executable,
                "-m",
                "uvicorn",
                "src.app.main:app",
                "--host",
                "127.0.0.1",
                "--port",
                str(port),
            ],
            cwd=os.path.join(os.path.dirname(__file__), ".."),
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(5)
        status, health = request(port, "GET", "/healthz")
        if status == 200:
            ok(f"API started on port {port} (PID {proc.pid})")
        else:
            fail(
                f"Could not start API: {health.get('detail', 'unknown')}"
            )
            return 1
    else:
        fail(f"API not reachable on port {port}. Start it first with:")
        fail(
            f"  OPERATOR_DASHBOARD_TOKEN='{operator_token}'"
            f" uv run uvicorn src.app.main:app --port {port}"
        )
        return 1

    # ── Step 1: Get anonymous auth token ──
    step("Step 1: Get anonymous auth token")

    status, token_resp = request(port, "POST", "/user/anonymous", data={})
    if status == 200 and "access_token" in token_resp:
        bearer = token_resp["access_token"]
        ok(f"Anonymous token obtained (prefix: {bearer[:20]}...)")
    else:
        fail(
            f"Could not get auth token: {json.dumps(token_resp, indent=2)[:200]}"
        )
        return 1

    # ── Step 2: Fire test analytics events ──
    step("Step 2: Fire test analytics events")
    now_ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    test_events = [
        {
            "event": "test_audit_event",
            "ts": now_ts,
            "uid": bearer[:16],
            "props": {"source": "analytics_audit", "test_id": "001"},
            "install_id": "audit-install-2026-07",
            "session_id": "audit-session-001",
        },
        {
            "event": "test_audit_checkin",
            "ts": now_ts,
            "uid": bearer[:16],
            "props": {"source": "analytics_audit", "stage": "ingest"},
            "install_id": "audit-install-2026-07",
            "session_id": "audit-session-001",
        },
        {
            "event": "test_audit_error",
            "ts": now_ts,
            "uid": bearer[:16],
            "props": {
                "source": "analytics_audit",
                "error_type": "synthetic_error",
                "library": "test_harness",
                "error_message":
                    "This is a synthetic test error for analytics pipeline audit",
            },
            "install_id": "audit-install-2026-07",
            "session_id": "audit-session-001",
        },
        {
            "event": "global_error",
            "ts": now_ts,
            "uid": bearer[:16],
            "props": {
                "error_type": "synthetic_error",
                "library": "test_harness",
                "error_message":
                    "Synthetic global_error for analytics audit",
                "error_code": "SYNTHETIC_001",
            },
            "install_id": "audit-install-2026-07",
            "session_id": "audit-session-001",
        },
        {
            "event": "global_error_recovered",
            "ts": now_ts,
            "uid": bearer[:16],
            "props": {
                "error_type": "synthetic_error",
                "library": "test_harness",
                "error_code": "SYNTHETIC_001",
            },
            "install_id": "audit-install-2026-07",
            "session_id": "audit-session-001",
        },
    ]

    events_ingested = 0
    for evt in test_events:
        code, resp = request(
            port, "POST", "/analytics/events", data={"events": [evt]}, bearer=bearer
        )
        if code in (200, 202) and resp.get("status") == "accepted":
            events_ingested += 1
        else:
            warn(
                f"Failed to ingest {evt['event']}: HTTP {code}:"
                f" {json.dumps(resp)[:100]}"
            )

    ok(f"{events_ingested}/{len(test_events)} test events ingested")
    if events_ingested < len(test_events):
        result_status = 1

    # ── Step 3: Check SQLite database directly ──
    step("Step 3: Check SQLite database")

    try:
        import sqlite3

        db_path = "insurance_app.db"
        conn = sqlite3.connect(db_path)
        count = conn.execute(
            "SELECT COUNT(*) FROM analytics_events"
            " WHERE event_name LIKE 'test_%' OR event_name LIKE 'global_%'"
        ).fetchone()[0]
        conn.close()
        if count >= events_ingested:
            ok(f"SQLite verified: {count} audit events stored in {db_path}")
        else:
            warn(
                f"SQLite shows only {count} audit events (expected"
                f" {events_ingested}). DB may be in a different location."
            )
    except Exception as e:
        warn(f"Could not check SQLite: {e}")

    # ── Step 4: Verify via /analytics/summary ──
    step("Step 4: Verify via /analytics/summary")

    summary_ok = False
    try:
        code, summary = request(
            port, "GET", "/analytics/summary?days=1",
            bearer=bearer, operator_token=operator_token,
        )
        if code == 200:
            summary_ok = True
            total = summary.get("total_events", 0)
            users = summary.get("unique_users", 0)
            ok(f"Summary endpoint accessible (total_events={total}, users={users})")
            events_by_name = summary.get("events_by_name", {})
            for name, count in sorted(
                events_by_name.items(), key=lambda x: -x[1]
            ):
                if "test" in name or "global" in name:
                    ok(
                        f"Event '{name}' appears in summary:"
                        f" {count} occurrences"
                    )
        else:
            fail(
                f"Summary endpoint HTTP {code}:"
                f" {json.dumps(summary)[:200]}"
            )
            result_status = 1
    except Exception as e:
        fail(f"Summary endpoint failed: {e}")
        result_status = 1

    # ── Step 5: Verify via /analytics/errors ──
    step("Step 5: Verify via /analytics/errors")

    errors_ok = False
    try:
        code, errors = request(
            port, "GET", "/analytics/errors?days=1",
            bearer=bearer, operator_token=operator_token,
        )
        if code == 200:
            errors_ok = True
            print(f"     Total errors: {errors.get('total_errors', '?')}")
            print(
                f"     Recovery rate:"
                f" {errors.get('recovery_rate_percent', '?')}%"
            )
            for err_type, count in errors.get("error_types", {}).items():
                ok(f"Error type '{err_type}': {count} occurrences")
        else:
            warn(
                f"Errors endpoint HTTP {code}:"
                f" {json.dumps(errors)[:200]}"
            )
    except Exception as e:
        warn(f"Errors endpoint failed: {e}")

    # ── Step 6: Verify via /analytics/health ──
    step("Step 6: Verify via /analytics/health")

    health_ok = False
    try:
        code, health_data = request(
            port, "GET", "/analytics/health",
            bearer=bearer, operator_token=operator_token,
        )
        if code == 200:
            health_ok = True
            print(f"     Table exists: {health_data.get('table_exists')}")
            print(f"     Row count: {health_data.get('row_count')}")
            print(f"     Events (24h): {health_data.get('recent_events_24h')}")
            print(f"     Indexes: {len(health_data.get('indexes', []))}")
            ok(f"Health endpoint accessible")
        else:
            warn(
                f"Health endpoint HTTP {code}:"
                f" {json.dumps(health_data)[:200]}"
            )
    except Exception as e:
        warn(f"Health endpoint failed: {e}")

    # ── Summary ──
    step("📊 Audit Summary")
    print(f"  API port:     {port}")
    print(f"  Events fired: {len(test_events)}")
    print(f"  Ingested:     {events_ingested}/{len(test_events)}")
    print(
        f"  Summary:      {'✅ accessible' if summary_ok else '❌ blocked'}"
    )
    print(
        f"  Errors:       {'✅ accessible' if errors_ok else '❌ blocked'}"
    )
    print(
        f"  Health:       {'✅ accessible' if health_ok else '❌ blocked'}"
    )

    return result_status


if __name__ == "__main__":
    sys.exit(main())
