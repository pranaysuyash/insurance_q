"""
Persistent document storage using SQLite.
Replaces the in-memory DOCUMENTS list in document.py.
"""
import sqlite3
import json
import os
import logging
from typing import Optional, Dict, Any, List
from datetime import datetime

logger = logging.getLogger(__name__)

DB_PATH = os.environ.get("COVERWISE_DB_PATH", "storage/coverwise.db")


def init_db():
    """Initialize the SQLite database."""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            filename TEXT NOT NULL,
            document_type TEXT,
            insurer TEXT,
            status TEXT DEFAULT 'pending',
            session_id TEXT,
            owner_id TEXT,
            uploaded_at TEXT,
            metadata_json TEXT,
            file_path TEXT,
            file_size INTEGER
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS document_summaries (
            document_id TEXT PRIMARY KEY,
            summary_json TEXT NOT NULL,
            extracted_at TEXT,
            FOREIGN KEY (document_id) REFERENCES documents(id)
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS leads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT,
            email TEXT,
            phone TEXT,
            document_id TEXT,
            captured_at TEXT
        )
    """)
    conn.commit()
    logger.info("SQLite database initialized at %s", DB_PATH)
    return conn


_db_conn = None


def get_db():
    """Get the singleton database connection."""
    global _db_conn
    if _db_conn is None:
        _db_conn = init_db()
    return _db_conn


def store_document(doc_id: str, filename: str, session_id: str,
                   document_type: str = None, insurer: str = None,
                   file_path: str = None, file_size: int = None,
                   owner_id: str = None, metadata: dict = None) -> bool:
    """Store a document record."""
    conn = get_db()
    try:
        conn.execute(
            """INSERT OR REPLACE INTO documents 
               (id, filename, document_type, insurer, status, session_id, owner_id,
                uploaded_at, metadata_json, file_path, file_size)
               VALUES (?, ?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?)""",
            (doc_id, filename, document_type, insurer, session_id, owner_id,
             datetime.utcnow().isoformat(),
             json.dumps(metadata or {}), file_path, file_size)
        )
        conn.commit()
        return True
    except Exception as e:
        logger.error("Failed to store document: %s", e)
        return False


def update_document_status(doc_id: str, status: str,
                           document_type: str = None, insurer: str = None) -> bool:
    """Update a document's processing status and type."""
    conn = get_db()
    try:
        if document_type or insurer:
            conn.execute(
                "UPDATE documents SET status = ?, document_type = COALESCE(?, document_type), insurer = COALESCE(?, insurer) WHERE id = ?",
                (status, document_type, insurer, doc_id)
            )
        else:
            conn.execute("UPDATE documents SET status = ? WHERE id = ?", (status, doc_id))
        conn.commit()
        return True
    except Exception as e:
        logger.error("Failed to update document status: %s", e)
        return False


def get_document(doc_id: str) -> Optional[Dict[str, Any]]:
    """Get a single document by ID."""
    conn = get_db()
    row = conn.execute("SELECT * FROM documents WHERE id = ?", (doc_id,)).fetchone()
    if row:
        doc = dict(row)
        doc["metadata"] = json.loads(doc.get("metadata_json") or "{}")
        return doc
    return None


def get_documents_by_session(session_id: str) -> List[Dict[str, Any]]:
    """Get all documents for a session."""
    conn = get_db()
    rows = conn.execute("SELECT * FROM documents WHERE session_id = ? ORDER BY uploaded_at DESC", (session_id,)).fetchall()
    return [dict(row) for row in rows]


def get_documents_by_owner(owner_id: str) -> List[Dict[str, Any]]:
    """Get all documents for an owner."""
    conn = get_db()
    rows = conn.execute("SELECT * FROM documents WHERE owner_id = ? ORDER BY uploaded_at DESC", (owner_id,)).fetchall()
    return [dict(row) for row in rows]


def delete_document(doc_id: str) -> bool:
    """Delete a document record."""
    conn = get_db()
    try:
        conn.execute("DELETE FROM documents WHERE id = ?", (doc_id,))
        conn.execute("DELETE FROM document_summaries WHERE document_id = ?", (doc_id,))
        conn.commit()
        return True
    except Exception as e:
        logger.error("Failed to delete document: %s", e)
        return False


def store_summary(doc_id: str, summary: dict) -> bool:
    """Store a policy summary for a document."""
    conn = get_db()
    try:
        conn.execute(
            "INSERT OR REPLACE INTO document_summaries (document_id, summary_json, extracted_at) VALUES (?, ?, ?)",
            (doc_id, json.dumps(summary), datetime.utcnow().isoformat())
        )
        conn.commit()
        return True
    except Exception as e:
        logger.error("Failed to store summary: %s", e)
        return False


def get_summary(doc_id: str) -> Optional[Dict[str, Any]]:
    """Get a stored policy summary."""
    conn = get_db()
    row = conn.execute("SELECT * FROM document_summaries WHERE document_id = ?", (doc_id,)).fetchone()
    if row:
        return json.loads(row["summary_json"])
    return None


def get_all_summaries() -> List[Dict[str, Any]]:
    """Get all stored policy summaries."""
    conn = get_db()
    rows = conn.execute("SELECT * FROM document_summaries").fetchall()
    return [json.loads(row["summary_json"]) for row in rows]