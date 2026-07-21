"""Durable guest-to-account identity linking.

The link is created before ownership transfer and completed afterwards. A
retry therefore reuses the same anonymous owner and does not create a second
identity relationship. Production requires the Supabase table; development
can use SQLite so local tests remain self-contained.
"""

from __future__ import annotations

import os
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache


DB_PATH = "insurance_app.db"


@dataclass(frozen=True)
class IdentityLink:
    anonymous_uid: str
    account_uid: str
    status: str
    transferred_documents: int


@lru_cache(maxsize=1)
def _supabase_client():
    url = os.getenv("SUPABASE_URL", "").strip()
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        return None
    from supabase import create_client

    return create_client(url, key)


def _production() -> bool:
    return os.getenv("ENVIRONMENT", "development").lower() == "production"


def _local_fallback_allowed() -> bool:
    """Allow self-contained development tests without weakening production."""
    return not _production()


def _init_sqlite() -> None:
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS identity_aliases (
                anonymous_uid TEXT PRIMARY KEY,
                account_uid TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                transferred_documents INTEGER NOT NULL DEFAULT 0,
                last_error_class TEXT,
                created_at TEXT NOT NULL,
                completed_at TEXT,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.commit()
    finally:
        conn.close()


def _row(data: dict) -> IdentityLink:
    return IdentityLink(
        anonymous_uid=str(data["anonymous_uid"]),
        account_uid=str(data["account_uid"]),
        status=str(data["status"]),
        transferred_documents=int(data.get("transferred_documents") or 0),
    )


def begin(anonymous_uid: str, account_uid: str) -> IdentityLink:
    """Create or resume a pending link, rejecting account mismatches."""
    client = _supabase_client()
    if client is not None:
        try:
            response = (
                client.table("identity_aliases")
                .select("anonymous_uid,account_uid,status,transferred_documents")
                .eq("anonymous_uid", anonymous_uid)
                .limit(1)
                .execute()
            )
            if response.data:
                existing = _row(response.data[0])
                if existing.account_uid != account_uid:
                    raise ValueError("Anonymous identity is already linked to another account")
                return existing
            response = (
                client.table("identity_aliases")
                .insert({
                    "anonymous_uid": anonymous_uid,
                    "account_uid": account_uid,
                    "status": "pending",
                })
                .execute()
            )
            if not response.data:
                raise RuntimeError("Identity link was not created")
            return _row(response.data[0])
        except ValueError:
            raise
        except Exception:
            if not _local_fallback_allowed():
                raise

    if _production():
        raise RuntimeError("Supabase identity_aliases is required in production")

    _init_sqlite()
    now = datetime.now(timezone.utc).isoformat()
    conn = sqlite3.connect(DB_PATH)
    try:
        row = conn.execute(
            "SELECT anonymous_uid, account_uid, status, transferred_documents "
            "FROM identity_aliases WHERE anonymous_uid = ?",
            (anonymous_uid,),
        ).fetchone()
        if row:
            existing = IdentityLink(*row)
            if existing.account_uid != account_uid:
                raise ValueError("Anonymous identity is already linked to another account")
            return existing
        conn.execute(
            "INSERT INTO identity_aliases "
            "(anonymous_uid, account_uid, status, created_at, updated_at) "
            "VALUES (?, ?, 'pending', ?, ?)",
            (anonymous_uid, account_uid, now, now),
        )
        conn.commit()
        return IdentityLink(anonymous_uid, account_uid, "pending", 0)
    finally:
        conn.close()


def complete(anonymous_uid: str, account_uid: str, transferred_documents: int) -> IdentityLink:
    """Mark a link complete after the ownership transfer succeeds."""
    client = _supabase_client()
    now = datetime.now(timezone.utc).isoformat()
    if client is not None:
        try:
            response = (
                client.table("identity_aliases")
                .update({
                    "status": "completed",
                    "transferred_documents": transferred_documents,
                    "completed_at": now,
                    "updated_at": now,
                    "last_error_class": None,
                })
                .eq("anonymous_uid", anonymous_uid)
                .eq("account_uid", account_uid)
                .execute()
            )
            if not response.data:
                raise RuntimeError("Identity link completion was not persisted")
            return _row(response.data[0])
        except Exception:
            if not _local_fallback_allowed():
                raise

    _init_sqlite()
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute(
            "UPDATE identity_aliases SET status='completed', transferred_documents=?, "
            "completed_at=?, updated_at=?, last_error_class=NULL "
            "WHERE anonymous_uid=? AND account_uid=?",
            (transferred_documents, now, now, anonymous_uid, account_uid),
        )
        conn.commit()
        return IdentityLink(anonymous_uid, account_uid, "completed", transferred_documents)
    finally:
        conn.close()


def fail(anonymous_uid: str, account_uid: str, error_class: str) -> None:
    """Record a failed attempt without exposing exception details."""
    now = datetime.now(timezone.utc).isoformat()
    safe_class = error_class[:120]
    client = _supabase_client()
    if client is not None:
        try:
            client.table("identity_aliases").update({
                "status": "failed",
                "last_error_class": safe_class,
                "updated_at": now,
            }).eq("anonymous_uid", anonymous_uid).eq("account_uid", account_uid).execute()
            return
        except Exception:
            if not _local_fallback_allowed():
                return
    if _production():
        return
    _init_sqlite()
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute(
            "UPDATE identity_aliases SET status='failed', last_error_class=?, updated_at=? "
            "WHERE anonymous_uid=? AND account_uid=?",
            (safe_class, now, anonymous_uid, account_uid),
        )
        conn.commit()
    finally:
        conn.close()


def clear_cache() -> None:
    _supabase_client.cache_clear()
