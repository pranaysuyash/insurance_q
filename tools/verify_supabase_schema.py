"""Non-mutating remote Supabase schema and Auth contract probe."""

from __future__ import annotations

import json
import os
import urllib.request

from supabase import create_client


REQUIRED_TABLES = (
    "documents",
    "document_chunks",
    "job_outbox",
    "identity_aliases",
    "billing_subscription_states",
    "model_runs",
    "model_artifacts",
    "model_run_results",
)


def main() -> int:
    url = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
    secret = (
        os.environ.get("SUPABASE_SECRET_KEY", "").strip()
        or os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    )
    publishable = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "").strip()
    if not url or not secret or not publishable:
        raise SystemExit("SUPABASE_URL, SUPABASE_SECRET_KEY, and SUPABASE_PUBLISHABLE_KEY are required")

    service = create_client(url, secret)
    tables: dict[str, str] = {}
    for table in REQUIRED_TABLES:
        try:
            service.table(table).select("*").limit(0).execute()
            tables[table] = "present"
        except Exception as error:
            tables[table] = f"missing_or_unqueryable:{type(error).__name__}"

    request = urllib.request.Request(
        f"{url}/auth/v1/settings",
        headers={"apikey": publishable},
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        settings = json.loads(response.read().decode("utf-8"))
    external = settings.get("external") or {}
    result = {
        "tables": tables,
        "auth_http_status": 200,
        "email_enabled": bool(external.get("email")),
        "anonymous_enabled": bool(external.get("anonymous_users")),
        "mailer_autoconfirm": bool(settings.get("mailer_autoconfirm")),
    }
    print(json.dumps(result, sort_keys=True))
    return 0 if all(value == "present" for value in tables.values()) else 2


if __name__ == "__main__":
    raise SystemExit(main())
