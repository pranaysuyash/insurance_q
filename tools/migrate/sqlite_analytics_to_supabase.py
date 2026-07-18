"""
One-shot migration: CoverWise analytics_events from SQLite -> Supabase Postgres.

Date: 2026-07-18
Phase: R1.3
Risk classification (motto v3 §0.6): MEDIUM. Data migration from a live source.
The SQLite table is currently being written to by the running FastAPI. We must
not lose events and must not double-write.

Usage:
    # 1. Inspect what would happen (no writes)
    python tools/migrate/sqlite_analytics_to_supabase.py --dry-run

    # 2. Run live
    python tools/migrate/sqlite_analytics_to_supabase.py

    # 3. Verify parity after the run
    python tools/migrate/sqlite_analytics_to_supabase.py --verify

Environment:
    SUPABASE_URL          : Supabase project URL (https://xxx.supabase.co)
    SUPABASE_SERVICE_ROLE_KEY : service-role key (NOT anon key)
    SQLITE_PATH           : path to insurance_app.db (default: insurance_app.db)
    MIGRATION_BATCH_SIZE  : rows per insert batch (default: 500)

Behavior:
    - Reads all rows from SQLite analytics_events table
    - Inserts into public.analytics_events in Supabase with ON CONFLICT
      (received_at, event_name, user_uid) DO NOTHING
    - Reports: source row count, target row count (before), inserted count,
      skipped (duplicate) count, failed count
    - Does NOT delete the SQLite table
    - Idempotent: safe to re-run

After 30 days of verified parity, run the final cleanup:
    tools/migrate/sqlite_analytics_to_supabase.py --drop-sqlite
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sqlite3
import sys
import time
from dataclasses import dataclass, field
from typing import Iterator

logger = logging.getLogger("migrate.analytics")


@dataclass
class MigrationResult:
    source_rows: int = 0
    target_rows_before: int = 0
    target_rows_after: int = 0
    inserted: int = 0
    skipped: int = 0
    failed: int = 0
    errors: list[str] = field(default_factory=list)
    elapsed_seconds: float = 0.0

    @property
    def parity(self) -> bool:
        """True if target row count grew by exactly `inserted`."""
        return self.target_rows_after == self.target_rows_before + self.inserted


def _count_sqlite_rows(sqlite_path: str) -> int:
    conn = sqlite3.connect(sqlite_path)
    try:
        cur = conn.execute("SELECT COUNT(*) FROM analytics_events")
        return int(cur.fetchone()[0])
    finally:
        conn.close()


def _count_supabase_rows(client) -> int:
    res = client.table("analytics_events").select("id", count="exact").limit(0).execute()
    return int(res.count or 0)


def _iter_sqlite_rows(sqlite_path: str) -> Iterator[dict]:
    conn = sqlite3.connect(sqlite_path)
    conn.row_factory = sqlite3.Row
    try:
        cur = conn.execute(
            """
            SELECT event_name, timestamp, user_uid, properties, received_at
            FROM analytics_events
            ORDER BY id ASC
            """
        )
        for row in cur:
            yield {
                "event_name": row["event_name"],
                "timestamp": row["timestamp"],
                "user_uid": row["user_uid"],
                "properties": row["properties"],  # may be JSON string or None
                "received_at": row["received_at"],
            }
    finally:
        conn.close()


def _to_supabase_row(src: dict) -> dict:
    """Normalize a SQLite row to a Supabase insert payload.

    The Supabase analytics_events table has the same column shape, plus three
    new nullable columns (install_id, session_id, is_reinstall) which default
    to NULL / false. We do not backfill them — that is impossible from the
    existing schema. Phase R1.6 populates them for new events going forward.
    """
    props = src.get("properties")
    if isinstance(props, str) and props:
        try:
            json.loads(props)  # validate; Supabase will store as jsonb
        except json.JSONDecodeError:
            logger.warning("Skipping malformed properties JSON for event %s", src.get("event_name"))
            props = None
    return {
        "event_name": src["event_name"],
        "timestamp": src["timestamp"],
        "user_uid": src["user_uid"],
        "properties": props,
        "received_at": src["received_at"],
    }


def run_migration(
    sqlite_path: str,
    supabase_url: str,
    service_role_key: str,
    batch_size: int = 500,
    dry_run: bool = False,
) -> MigrationResult:
    result = MigrationResult()
    started = time.monotonic()

    # Connect to Supabase
    from supabase import create_client

    client = create_client(supabase_url, service_role_key)

    # Count source
    result.source_rows = _count_sqlite_rows(sqlite_path)
    logger.info("Source SQLite row count: %d", result.source_rows)

    # Count target (before)
    result.target_rows_before = _count_supabase_rows(client)
    logger.info("Target Supabase row count (before): %d", result.target_rows_before)

    if dry_run:
        logger.info("[DRY RUN] Would migrate up to %d rows in batches of %d", result.source_rows, batch_size)
        result.elapsed_seconds = time.monotonic() - started
        return result

    # Migrate in batches
    batch: list[dict] = []
    for src in _iter_sqlite_rows(sqlite_path):
        batch.append(_to_supabase_row(src))
        if len(batch) >= batch_size:
            _flush_batch(client, batch, result)
            batch = []
    if batch:
        _flush_batch(client, batch, result)

    # Count target (after)
    result.target_rows_after = _count_supabase_rows(client)
    logger.info("Target Supabase row count (after): %d", result.target_rows_after)

    result.elapsed_seconds = time.monotonic() - started
    return result


def _flush_batch(client, batch: list[dict], result: MigrationResult) -> None:
    """Insert a batch with ON CONFLICT DO NOTHING semantics.

    The Supabase Python client uses PostgREST. ON CONFLICT is not directly
    exposed; we use upsert with ignore_duplicates=True which translates to
    INSERT ... ON CONFLICT DO NOTHING on the unique constraint.
    """
    try:
        res = client.table("analytics_events").upsert(
            batch, ignore_duplicates=True
        ).execute()
        # PostgREST upsert with ignore_duplicates returns the inserted rows.
        # If a row conflicted, it is not in the response. We can't directly
        # count skipped from the response, so we infer by delta.
        if res.data:
            result.inserted += len(res.data)
    except Exception as e:
        result.failed += len(batch)
        result.errors.append(f"batch of {len(batch)} failed: {e!r}")
        logger.exception("Batch insert failed")


def verify_parity(sqlite_path: str, supabase_url: str, service_role_key: str) -> bool:
    """Compare per-(event_name, received_at) row counts between source and target.

    This is a stricter check than simple row-count parity. Two rows with the
    same (received_at, event_name, user_uid) tuple are considered duplicates;
    a row that exists in SQLite but not in Supabase indicates a missing insert.
    """
    from supabase import create_client

    client = create_client(supabase_url, service_role_key)

    # Read source distinct (received_at, event_name, user_uid) tuples
    src_conn = sqlite3.connect(sqlite_path)
    try:
        src_rows = src_conn.execute(
            """
            SELECT event_name, received_at, user_uid, COUNT(*) as c
            FROM analytics_events
            GROUP BY event_name, received_at, user_uid
            """
        ).fetchall()
    finally:
        src_conn.close()

    src_total = sum(int(r[3]) for r in src_rows)
    logger.info("Source distinct-tuple count: %d, total rows: %d", len(src_rows), src_total)

    # Read target in pages (Supabase caps rows per request at 1000 by default)
    # For a one-time migration this is fine; production datasets may need batching.
    target: set[tuple] = set()
    page_size = 1000
    offset = 0
    while True:
        res = (
            client.table("analytics_events")
            .select("event_name,received_at,user_uid")
            .range(offset, offset + page_size - 1)
            .execute()
        )
        if not res.data:
            break
        for r in res.data:
            target.add((r["event_name"], r["received_at"], r["user_uid"]))
        offset += len(res.data)
        if len(res.data) < page_size:
            break

    src_set = {(r[0], r[1], r[2]) for r in src_rows}
    missing = src_set - target
    extra = target - src_set

    logger.info("Target distinct-tuple count: %d", len(target))
    if missing:
        logger.error("MISSING in target: %d tuples", len(missing))
        for m in list(missing)[:5]:
            logger.error("  missing: %s", m)
    if extra:
        logger.warning("EXTRA in target (not in source): %d tuples (likely new events received during migration)", len(extra))

    return not missing


def drop_sqlite_table(sqlite_path: str, confirm: bool = False) -> None:
    """Final cleanup: drop the SQLite analytics_events table.

    Only run after 30 days of verified parity. Cannot be undone.
    """
    if not confirm:
        logger.error("Refusing to drop SQLite table without --confirm flag")
        sys.exit(1)
    conn = sqlite3.connect(sqlite_path)
    try:
        conn.execute("DROP TABLE IF EXISTS analytics_events")
        conn.commit()
        logger.info("Dropped analytics_events from %s", sqlite_path)
    finally:
        conn.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sqlite-path", default=os.environ.get("SQLITE_PATH", "insurance_app.db"))
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", ""))
    parser.add_argument("--service-role-key", default=os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""))
    parser.add_argument("--batch-size", type=int, default=int(os.environ.get("MIGRATION_BATCH_SIZE", "500")))
    parser.add_argument("--dry-run", action="store_true", help="Count rows and report; do not write")
    parser.add_argument("--verify", action="store_true", help="Compare source vs target tuple sets")
    parser.add_argument("--drop-sqlite", action="store_true", help="Final cleanup: drop SQLite table")
    parser.add_argument("--confirm", action="store_true", help="Required with --drop-sqlite")
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"])
    args = parser.parse_args()

    logging.basicConfig(
        level=args.log_level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    if args.drop_sqlite:
        drop_sqlite_table(args.sqlite_path, confirm=args.confirm)
        return 0

    if args.verify:
        if not args.supabase_url or not args.service_role_key:
            logger.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for --verify")
            return 1
        ok = verify_parity(args.sqlite_path, args.supabase_url, args.service_role_key)
        return 0 if ok else 2

    if not args.supabase_url or not args.service_role_key:
        logger.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required")
        logger.error("Set them in the environment or pass --supabase-url / --service-role-key")
        return 1

    result = run_migration(
        sqlite_path=args.sqlite_path,
        supabase_url=args.supabase_url,
        service_role_key=args.service_role_key,
        batch_size=args.batch_size,
        dry_run=args.dry_run,
    )

    # Final report (machine-parseable)
    report = {
        "source_rows": result.source_rows,
        "target_rows_before": result.target_rows_before,
        "target_rows_after": result.target_rows_after,
        "inserted": result.inserted,
        "skipped_duplicates": result.source_rows - result.inserted - result.failed,
        "failed": result.failed,
        "parity_ok": result.parity,
        "elapsed_seconds": round(result.elapsed_seconds, 2),
        "dry_run": args.dry_run,
    }
    print(json.dumps(report, indent=2))

    if result.failed > 0:
        logger.error("Migration completed with %d failures", result.failed)
        for err in result.errors[:10]:
            logger.error("  %s", err)
        return 3

    if not result.parity:
        logger.warning(
            "Parity check failed: target grew by %d, expected %d",
            result.target_rows_after - result.target_rows_before,
            result.inserted,
        )
        return 4

    return 0


if __name__ == "__main__":
    sys.exit(main())
