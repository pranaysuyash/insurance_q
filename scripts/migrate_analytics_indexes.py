#!/usr/bin/env python3
"""Standalone migration script to add composite analytics indexes.

Adds two composite indexes to the analytics_events table for query performance:
- idx_analytics_error_window (event_name, received_at) — supports /analytics/errors
- idx_analytics_summary (received_at, event_name, user_uid) — supports /analytics/summary

Safe to run on existing databases — uses IF NOT EXISTS (idempotent).

Usage:
    python scripts/migrate_analytics_indexes.py                  # default: insurance_app.db
    python scripts/migrate_analytics_indexes.py /path/to/db.db   # custom path
"""
import sqlite3
import sys
import os

DB_PATH = sys.argv[1] if len(sys.argv) > 1 else "insurance_app.db"

INDEXES = [
    (
        "idx_analytics_error_window",
        "CREATE INDEX IF NOT EXISTS idx_analytics_error_window "
        "ON analytics_events(event_name, received_at)",
        "Supports /analytics/errors endpoint (CTE, totals, trends)",
    ),
    (
        "idx_analytics_summary",
        "CREATE INDEX IF NOT EXISTS idx_analytics_summary "
        "ON analytics_events(received_at, event_name, user_uid)",
        "Supports /analytics/summary endpoint (covering index)",
    ),
]


def main() -> int:
    if not os.path.exists(DB_PATH):
        print(f"❌ Database not found: {DB_PATH}")
        return 1

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Check if the analytics_events table exists
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='analytics_events'"
    )
    if not cursor.fetchone():
        print("⚠️  analytics_events table does not exist yet — skipping migration")
        print("   (table will be created with indexes on first API call)")
        conn.close()
        return 0

    for name, sql, description in INDEXES:
        try:
            cursor.execute(sql)
            print(f"✅ {name} — {description}")
        except Exception as e:
            print(f"❌ {name} failed: {e}")
            conn.close()
            return 1

    conn.commit()
    conn.close()
    print("\n✅ All analytics indexes migrated successfully")
    return 0


if __name__ == "__main__":
    sys.exit(main())
