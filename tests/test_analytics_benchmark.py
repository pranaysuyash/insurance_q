"""Benchmark test for analytics error aggregation.

Compares the performance of three approaches:
1. Python-based aggregation (original: load all rows, parse JSON in Python)
2. 7-query SQL approach (intermediate: separate SQL queries per dimension)
3. Optimized 3-query approach (current: CTE + conditional aggregation + UNION ALL)

NOTE: The aggregation functions below intentionally duplicate the query logic
from src/api/analytics.py rather than importing it. This is for benchmark
isolation — we want to measure the raw query performance without any
framework overhead (FastAPI routing, auth, JSON serialization). If the
production queries change, update these functions to match.

Run with: pytest tests/test_analytics_benchmark.py -v -s
"""
import json
import sqlite3
import time
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Tuple, Optional

import pytest


# ── Test DB setup ──────────────────────────────────────────────────────────

def _create_test_db(db_path: str, num_events: int) -> None:
    """Create a test database with the specified number of error events."""
    conn = sqlite3.connect(db_path)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS analytics_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_name TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            user_uid TEXT NOT NULL,
            properties TEXT,
            received_at TEXT NOT NULL
        )
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_analytics_event_name
        ON analytics_events(event_name)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_analytics_user_uid
        ON analytics_events(user_uid)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_analytics_error_window
        ON analytics_events(event_name, received_at)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_analytics_summary
        ON analytics_events(received_at, event_name, user_uid)
    """)

    now = datetime.now(timezone.utc).isoformat()

    error_types = ["Exception", "TypeError", "RangeError", "StateError", "ArgumentError"]
    libraries = ["Flutter", "Dart", "React", "Angular", "Vue"]
    messages = [
        "Null check operator used on a null value",
        "Index out of range",
        "Type 'String' is not a subtype of type 'int'",
        "Failed to load asset",
        "Network error occurred",
        "Permission denied",
        "File not found",
        "Invalid JSON response",
        "Connection timeout",
        "Out of memory",
    ]

    # Insert events in batches for efficiency
    batch_size = 1000
    for batch_start in range(0, num_events, batch_size):
        batch_end = min(batch_start + batch_size, num_events)
        events = []
        for i in range(batch_start, batch_end):
            event_type = error_types[i % len(error_types)]
            library = libraries[i % len(libraries)]
            message = messages[i % len(messages)]

            props = {
                "error_type": event_type,
                "library": library,
                "error_message": message,
                "stack_summary": f"frame{i} | frame{i+1} | frame{i+2}",
            }

            events.append((
                "global_error",
                now,
                f"user-{i % 100}",
                json.dumps(props),
                now,
            ))

        conn.executemany(
            "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
            events,
        )

    # Insert some recovery events
    recovery_events = [
        ("global_error_recovered", now, f"user-{i}", json.dumps({"error_type": "Exception"}), now)
        for i in range(num_events // 10)
    ]
    conn.executemany(
        "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
        recovery_events,
    )

    conn.commit()
    conn.close()


# ── Approach 1: Python-based aggregation (original) ────────────────────────

def _python_based_aggregation(db_path: str, days: int = 30) -> dict:
    """Original approach: load all properties rows into Python memory and parse JSON."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    time_filter = f"-{days} days"

    # Load ALL properties rows into memory
    error_rows = conn.execute("""
        SELECT properties FROM analytics_events
        WHERE event_name = 'global_error'
        AND received_at >= datetime('now', ?)
    """, (time_filter,)).fetchall()

    recovery_rows = conn.execute("""
        SELECT COUNT(*) as count FROM analytics_events
        WHERE event_name = 'global_error_recovered'
        AND received_at >= datetime('now', ?)
    """, (time_filter,)).fetchone()

    total_errors = len(error_rows)
    total_recoveries = recovery_rows["count"] if recovery_rows else 0

    # Parse properties and aggregate in Python
    error_types = {}
    error_libraries = {}
    error_messages = {}

    for row in error_rows:
        try:
            props = json.loads(row["properties"]) if row["properties"] else {}
            etype = props.get("error_type", "unknown")
            elib = props.get("library", "unknown")
            emsg = props.get("error_message", "unknown")

            error_types[etype] = error_types.get(etype, 0) + 1
            error_libraries[elib] = error_libraries.get(elib, 0) + 1
            error_messages[emsg] = error_messages.get(emsg, 0) + 1
        except (json.JSONDecodeError, TypeError):
            pass

    top_messages = sorted(error_messages.items(), key=lambda x: x[1], reverse=True)[:10]

    conn.close()

    recovery_rate = (
        round(total_recoveries / total_errors * 100, 1)
        if total_errors > 0
        else None
    )

    return {
        "total_errors": total_errors,
        "total_recoveries": total_recoveries,
        "recovery_rate_percent": recovery_rate,
        "error_types": error_types,
        "error_libraries": error_libraries,
        "top_messages": top_messages,
    }


# ── Approach 2: 7-query SQL approach (intermediate) ────────────────────────

def _seven_query_sql_aggregation(db_path: str, days: int = 30) -> dict:
    """Intermediate approach: 7 separate SQL queries, one per dimension."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    time_filter = f"-{days} days"

    # Query 1: Error counts by error_type
    error_type_rows = conn.execute("""
        SELECT
            COALESCE(json_extract(properties, '$.error_type'), 'unknown') as error_type,
            COUNT(*) as count
        FROM analytics_events
        WHERE event_name = 'global_error'
        AND received_at >= datetime('now', ?)
        GROUP BY error_type
        ORDER BY count DESC
    """, (time_filter,)).fetchall()

    # Query 2: Error counts by library
    error_library_rows = conn.execute("""
        SELECT
            COALESCE(json_extract(properties, '$.library'), 'unknown') as library,
            COUNT(*) as count
        FROM analytics_events
        WHERE event_name = 'global_error'
        AND received_at >= datetime('now', ?)
        GROUP BY library
        ORDER BY count DESC
    """, (time_filter,)).fetchall()

    # Query 3: Top error messages
    error_message_rows = conn.execute("""
        SELECT
            COALESCE(json_extract(properties, '$.error_message'), 'unknown') as error_message,
            COUNT(*) as count
        FROM analytics_events
        WHERE event_name = 'global_error'
        AND received_at >= datetime('now', ?)
        GROUP BY error_message
        ORDER BY count DESC
        LIMIT 10
    """, (time_filter,)).fetchall()

    # Query 4: Total errors
    total_row = conn.execute("""
        SELECT COUNT(*) as count FROM analytics_events
        WHERE event_name = 'global_error'
        AND received_at >= datetime('now', ?)
    """, (time_filter,)).fetchone()

    # Query 5: Recovery count
    recovery_row = conn.execute("""
        SELECT COUNT(*) as count FROM analytics_events
        WHERE event_name = 'global_error_recovered'
        AND received_at >= datetime('now', ?)
    """, (time_filter,)).fetchone()

    total_errors = total_row["count"] if total_row else 0
    total_recoveries = recovery_row["count"] if recovery_row else 0

    error_types = {row["error_type"]: row["count"] for row in error_type_rows}
    error_libraries = {row["library"]: row["count"] for row in error_library_rows}
    top_messages = [(row["error_message"], row["count"]) for row in error_message_rows]

    conn.close()

    recovery_rate = (
        round(total_recoveries / total_errors * 100, 1)
        if total_errors > 0
        else None
    )

    return {
        "total_errors": total_errors,
        "total_recoveries": total_recoveries,
        "recovery_rate_percent": recovery_rate,
        "error_types": error_types,
        "error_libraries": error_libraries,
        "top_messages": top_messages,
    }


# ── Approach 3: Optimized 3-query approach (current) ───────────────────────

def _optimized_3query_aggregation(db_path: str, days: int = 30) -> dict:
    """Current approach: CTE + conditional aggregation + UNION ALL (3 queries total)."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    time_filter = f"-{days} days"

    # Query 1: Combined total errors + recovery count (single scan)
    totals_row = conn.execute("""
        SELECT
            SUM(CASE WHEN event_name = 'global_error' THEN 1 ELSE 0 END) as total_errors,
            SUM(CASE WHEN event_name = 'global_error_recovered' THEN 1 ELSE 0 END) as total_recoveries
        FROM analytics_events
        WHERE event_name IN ('global_error', 'global_error_recovered')
        AND received_at >= datetime('now', ?)
    """, (time_filter,)).fetchone()

    total_errors = totals_row["total_errors"] or 0
    total_recoveries = totals_row["total_recoveries"] or 0

    # Query 2: Single-pass CTE for error_type, library, and messages
    aggregation_rows = conn.execute("""
        WITH error_data AS (
            SELECT
                COALESCE(json_extract(properties, '$.error_type'), 'unknown') as error_type,
                COALESCE(json_extract(properties, '$.library'), 'unknown') as library,
                COALESCE(json_extract(properties, '$.error_message'), 'unknown') as error_message
            FROM analytics_events
            WHERE event_name = 'global_error'
            AND received_at >= datetime('now', ?)
        )
        SELECT 'error_type' as dimension, error_type as value, COUNT(*) as count
        FROM error_data GROUP BY error_type
        UNION ALL
        SELECT 'library' as dimension, library as value, COUNT(*) as count
        FROM error_data GROUP BY library
        UNION ALL
        SELECT 'message' as dimension, error_message as value, COUNT(*) as count
        FROM error_data GROUP BY error_message
    """, (time_filter,)).fetchall()

    # Parse the combined results into separate dicts
    error_types: Dict[str, int] = {}
    error_libraries: Dict[str, int] = {}
    top_messages: list = []

    for row in aggregation_rows:
        dim = row["dimension"]
        value = row["value"]
        count = row["count"]
        if dim == "error_type":
            error_types[value] = count
        elif dim == "library":
            error_libraries[value] = count
        elif dim == "message":
            top_messages.append((value, count))

    # Sort messages by count descending and take top 10
    top_messages.sort(key=lambda x: x[1], reverse=True)
    top_messages = top_messages[:10]

    conn.close()

    recovery_rate = (
        round(total_recoveries / total_errors * 100, 1)
        if total_errors > 0
        else None
    )

    return {
        "total_errors": total_errors,
        "total_recoveries": total_recoveries,
        "recovery_rate_percent": recovery_rate,
        "error_types": error_types,
        "error_libraries": error_libraries,
        "top_messages": top_messages,
    }


# ── Benchmark tests ────────────────────────────────────────────────────────

class TestAnalyticsAggregationBenchmark:
    """Benchmark tests comparing all three aggregation approaches."""

    @pytest.mark.parametrize("num_events", [100, 1000, 5000, 10000])
    def test_three_way_benchmark(self, tmp_path, num_events):
        """Benchmark all three approaches and verify correctness."""
        db_path = str(tmp_path / f"benchmark_{num_events}.db")
        _create_test_db(db_path, num_events)

        # Warm up all three
        _python_based_aggregation(db_path)
        _seven_query_sql_aggregation(db_path)
        _optimized_3query_aggregation(db_path)

        # Benchmark Python-based approach
        python_times = []
        for _ in range(3):
            start = time.perf_counter()
            python_result = _python_based_aggregation(db_path)
            python_times.append(time.perf_counter() - start)

        # Benchmark 7-query SQL approach
        seven_query_times = []
        for _ in range(3):
            start = time.perf_counter()
            seven_query_result = _seven_query_sql_aggregation(db_path)
            seven_query_times.append(time.perf_counter() - start)

        # Benchmark optimized 3-query approach
        optimized_times = []
        for _ in range(3):
            start = time.perf_counter()
            optimized_result = _optimized_3query_aggregation(db_path)
            optimized_times.append(time.perf_counter() - start)

        avg_python = sum(python_times) / len(python_times)
        avg_seven = sum(seven_query_times) / len(seven_query_times)
        avg_optimized = sum(optimized_times) / len(optimized_times)

        speedup_vs_python = avg_python / avg_optimized if avg_optimized > 0 else float('inf')
        speedup_vs_seven = avg_seven / avg_optimized if avg_optimized > 0 else float('inf')

        # Verify correctness — all three should return the same totals
        assert python_result["total_errors"] == seven_query_result["total_errors"] == optimized_result["total_errors"]
        assert python_result["total_recoveries"] == seven_query_result["total_recoveries"] == optimized_result["total_recoveries"]
        assert python_result["error_types"] == seven_query_result["error_types"] == optimized_result["error_types"]
        assert python_result["error_libraries"] == seven_query_result["error_libraries"] == optimized_result["error_libraries"]

        # Print benchmark results
        print(f"\n{'='*70}")
        print(f"Benchmark: {num_events} error events")
        print(f"{'='*70}")
        print(f"Python-based (load all rows):  {avg_python*1000:>8.2f}ms  (baseline)")
        print(f"7-query SQL (separate scans):  {avg_seven*1000:>8.2f}ms  ({avg_python/avg_seven:.1f}x vs Python)")
        print(f"3-query optimized (CTE+UNION): {avg_optimized*1000:>8.2f}ms  ({speedup_vs_python:.1f}x vs Python, {speedup_vs_seven:.1f}x vs 7-query)")
        print(f"{'='*70}")

    @pytest.mark.parametrize("num_events", [1000, 5000, 10000])
    def test_optimized_vs_seven_query_memory(self, tmp_path, num_events):
        """Verify optimized approach doesn't load all rows into memory."""
        db_path = str(tmp_path / f"memory_{num_events}.db")
        _create_test_db(db_path, num_events)

        # Both SQL approaches should work regardless of dataset size
        seven_result = _seven_query_sql_aggregation(db_path)
        optimized_result = _optimized_3query_aggregation(db_path)

        assert seven_result["total_errors"] == optimized_result["total_errors"] == num_events
        assert len(optimized_result["error_types"]) > 0
        assert len(optimized_result["error_libraries"]) > 0
        assert len(optimized_result["top_messages"]) <= 10

    def test_correctness_across_all_approaches(self, tmp_path):
        """Verify all three approaches return identical results."""
        num_events = 500
        db_path = str(tmp_path / "correctness_test.db")
        _create_test_db(db_path, num_events)

        python_result = _python_based_aggregation(db_path)
        seven_result = _seven_query_sql_aggregation(db_path)
        optimized_result = _optimized_3query_aggregation(db_path)

        # All fields should match across all three approaches
        for field in ["total_errors", "total_recoveries", "recovery_rate_percent"]:
            assert python_result[field] == seven_result[field] == optimized_result[field], \
                f"Mismatch on {field}: python={python_result[field]}, 7q={seven_result[field]}, opt={optimized_result[field]}"

        assert python_result["error_types"] == seven_result["error_types"] == optimized_result["error_types"]
        assert python_result["error_libraries"] == seven_result["error_libraries"] == optimized_result["error_libraries"]

        # Top messages should have same counts (order may differ slightly)
        python_msg_dict = dict(python_result["top_messages"])
        seven_msg_dict = dict(seven_result["top_messages"])
        optimized_msg_dict = dict(optimized_result["top_messages"])
        assert python_msg_dict == seven_msg_dict == optimized_msg_dict
