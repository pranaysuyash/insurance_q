"""Canonical metadata repository for policy documents.

The API must never use process memory as the source of truth for customer
documents. Local development uses SQLite; production uses Supabase Postgres
unless an older adapter is explicitly selected. All implementations enforce owner-scoped reads at
the repository boundary, so route code cannot accidentally list another
principal's documents after a restart or scale-out event.
"""

from __future__ import annotations

import json
import os
import sqlite3
import threading
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable, Optional

from src.models.document import Document


class DocumentRepository:
    def create(self, document: Document) -> None:
        raise NotImplementedError

    def get(self, document_id: str, owner_id: str) -> Optional[Document]:
        raise NotImplementedError

    def find_by_source_hash(self, owner_id: str, source_hash: str) -> Optional[Document]:
        raise NotImplementedError

    def list_for_owner(self, owner_id: str) -> list[Document]:
        raise NotImplementedError

    def update(self, document: Document) -> None:
        raise NotImplementedError

    def delete(self, document_id: str, owner_id: str) -> bool:
        raise NotImplementedError

    def transfer_owner(self, from_owner: str, to_owner: str) -> int:
        """Atomically reassign documents during anonymous-to-account upgrade."""
        raise NotImplementedError

    def list_recoverable_processing(self) -> list[Document]:
        raise NotImplementedError

    def claim_processing(self, document_id: str, owner_id: str, lease_seconds: int) -> bool:
        """Atomically lease a received or stale-processing document."""
        raise NotImplementedError


class SQLiteDocumentRepository(DocumentRepository):
    """Restart-safe local repository used only outside production."""

    def __init__(self, database_path: str):
        path = Path(database_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(str(path), check_same_thread=False)
        self._connection.row_factory = sqlite3.Row
        self._lock = threading.Lock()
        with self._lock, self._connection:
            self._connection.execute(
                """
                CREATE TABLE IF NOT EXISTS documents (
                    id TEXT PRIMARY KEY,
                    owner_id TEXT NOT NULL,
                    payload TEXT NOT NULL
                )
                """
            )
            self._connection.execute(
                "CREATE INDEX IF NOT EXISTS documents_owner_id_idx ON documents(owner_id)"
            )

    @staticmethod
    def _serialize(document: Document) -> str:
        return document.model_dump_json()

    @staticmethod
    def _deserialize(payload: str) -> Document:
        return Document.model_validate_json(payload)

    def create(self, document: Document) -> None:
        with self._lock, self._connection:
            self._connection.execute(
                "INSERT INTO documents (id, owner_id, payload) VALUES (?, ?, ?)",
                (document.id, document.user_uid, self._serialize(document)),
            )

    def get(self, document_id: str, owner_id: str) -> Optional[Document]:
        with self._lock:
            row = self._connection.execute(
                "SELECT payload FROM documents WHERE id = ? AND owner_id = ?",
                (document_id, owner_id),
            ).fetchone()
        return self._deserialize(row["payload"]) if row else None

    def find_by_source_hash(self, owner_id: str, source_hash: str) -> Optional[Document]:
        # Local payload storage favors fidelity over query optimization. The
        # production adapter uses an indexed column for this lookup.
        for document in self.list_for_owner(owner_id):
            if document.source_hash == source_hash:
                return document
        return None

    def list_for_owner(self, owner_id: str) -> list[Document]:
        with self._lock:
            rows = self._connection.execute(
                "SELECT payload FROM documents WHERE owner_id = ?", (owner_id,)
            ).fetchall()
        return [self._deserialize(row["payload"]) for row in rows]

    def update(self, document: Document) -> None:
        with self._lock, self._connection:
            cursor = self._connection.execute(
                "UPDATE documents SET payload = ? WHERE id = ? AND owner_id = ?",
                (self._serialize(document), document.id, document.user_uid),
            )
        if cursor.rowcount != 1:
            raise KeyError(f"Document {document.id} no longer exists for its owner")

    def delete(self, document_id: str, owner_id: str) -> bool:
        with self._lock, self._connection:
            cursor = self._connection.execute(
                "DELETE FROM documents WHERE id = ? AND owner_id = ?",
                (document_id, owner_id),
            )
        return cursor.rowcount == 1

    def transfer_owner(self, from_owner: str, to_owner: str) -> int:
        if from_owner == to_owner:
            return 0
        with self._lock, self._connection:
            rows = self._connection.execute(
                "SELECT id, payload FROM documents WHERE owner_id = ?",
                (from_owner,),
            ).fetchall()
            for row in rows:
                document = self._deserialize(row["payload"])
                document.user_uid = to_owner
                self._connection.execute(
                    "UPDATE documents SET owner_id = ?, payload = ? WHERE id = ? AND owner_id = ?",
                    (to_owner, self._serialize(document), row["id"], from_owner),
                )
        return len(rows)

    def list_recoverable_processing(self) -> list[Document]:
        with self._lock:
            rows = self._connection.execute(
                "SELECT payload FROM documents"
            ).fetchall()
        now = datetime.now(timezone.utc)
        documents = [self._deserialize(row["payload"]) for row in rows]
        return [
            document
            for document in documents
            if document.status == "received"
            or (
                document.status == "processing"
                and document.processing_lease_expires_at is not None
                and document.processing_lease_expires_at <= now
            )
        ]

    def claim_processing(self, document_id: str, owner_id: str, lease_seconds: int) -> bool:
        now = datetime.now(timezone.utc)
        with self._lock, self._connection:
            row = self._connection.execute(
                "SELECT payload FROM documents WHERE id = ? AND owner_id = ?",
                (document_id, owner_id),
            ).fetchone()
            if not row:
                return False
            document = self._deserialize(row["payload"])
            stale = (
                document.status == "processing"
                and document.processing_lease_expires_at is not None
                and document.processing_lease_expires_at <= now
            )
            if document.status != "received" and not stale:
                return False
            document.status = "processing"
            document.processing_attempts += 1
            document.processing_started_at = now
            document.processing_lease_expires_at = now + timedelta(seconds=lease_seconds)
            self._connection.execute(
                "UPDATE documents SET payload = ? WHERE id = ? AND owner_id = ?",
                (self._serialize(document), document_id, owner_id),
            )
        return True


class DynamoDBDocumentRepository(DocumentRepository):
    """Production repository backed by a DynamoDB table keyed by id.

    A conditional owner expression is used for updates/deletes; a separate
    owner index named ``owner_id-index`` is required for lists.
    """

    def __init__(self, table_name: str, region_name: Optional[str] = None):
        try:
            import boto3
            from boto3.dynamodb.conditions import Key
        except ImportError as error:  # pragma: no cover - deployment dependency
            raise RuntimeError("boto3 is required for DynamoDB document storage") from error
        self._table = boto3.resource("dynamodb", region_name=region_name).Table(table_name)
        self._key = Key

    @staticmethod
    def _item(document: Document) -> dict[str, str]:
        return {
            "id": document.id,
            "owner_id": document.user_uid,
            "payload": document.model_dump(mode="json"),
        }

    @staticmethod
    def _document(item: dict) -> Document:
        return Document.model_validate(item["payload"])

    def create(self, document: Document) -> None:
        self._table.put_item(Item=self._item(document), ConditionExpression="attribute_not_exists(id)")

    def get(self, document_id: str, owner_id: str) -> Optional[Document]:
        response = self._table.get_item(Key={"id": document_id})
        item = response.get("Item")
        if not item or item.get("owner_id") != owner_id:
            return None
        return self._document(item)

    def find_by_source_hash(self, owner_id: str, source_hash: str) -> Optional[Document]:
        raise RuntimeError("DynamoDB source-hash lookup is unsupported; use the canonical Supabase backend")

    def list_for_owner(self, owner_id: str) -> list[Document]:
        response = self._table.query(
            IndexName="owner_id-index",
            KeyConditionExpression=self._key("owner_id").eq(owner_id),
        )
        items = response.get("Items", [])
        while response.get("LastEvaluatedKey"):
            response = self._table.query(
                IndexName="owner_id-index",
                KeyConditionExpression=self._key("owner_id").eq(owner_id),
                ExclusiveStartKey=response["LastEvaluatedKey"],
            )
            items.extend(response.get("Items", []))
        return [self._document(item) for item in items]

    def update(self, document: Document) -> None:
        self._table.put_item(
            Item=self._item(document),
            ConditionExpression="owner_id = :owner",
            ExpressionAttributeValues={":owner": document.user_uid},
        )

    def delete(self, document_id: str, owner_id: str) -> bool:
        response = self._table.delete_item(
            Key={"id": document_id},
            ConditionExpression="owner_id = :owner",
            ExpressionAttributeValues={":owner": owner_id},
            ReturnValues="ALL_OLD",
        )
        return bool(response.get("Attributes"))

    def transfer_owner(self, from_owner: str, to_owner: str) -> int:
        raise RuntimeError("DynamoDB ownership transfer is unsupported; use the canonical Supabase backend")

    def list_recoverable_processing(self) -> list[Document]:
        # DynamoDB is a compatibility adapter, not the canonical launch store.
        # Avoid a table scan hidden behind the production API.
        raise RuntimeError("DynamoDB recovery is unsupported; use the canonical Supabase backend")

    def claim_processing(self, document_id: str, owner_id: str, lease_seconds: int) -> bool:
        raise RuntimeError("DynamoDB claims are unsupported; use the canonical Supabase backend")


class SupabaseDocumentRepository(DocumentRepository):
    """Owner-scoped document metadata stored in Supabase Postgres."""

    def __init__(self, url: str, service_role_key: str, table_name: str = "documents"):
        if not url or not service_role_key:
            raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required")
        try:
            from supabase import create_client
        except ImportError as error:  # pragma: no cover - deployment dependency
            raise RuntimeError("supabase is required for Supabase document storage") from error
        self._client = create_client(url, service_role_key)
        self._table_name = table_name

    @staticmethod
    def _row(document: Document) -> dict:
        return {
            "id": document.id,
            "owner_id": document.user_uid,
            "payload": document.model_dump(mode="json"),
            "status": document.status,
            "object_reference": document.file_path,
            "source_hash": document.source_hash,
            "processing_attempts": document.processing_attempts,
            "processing_started_at": document.processing_started_at.isoformat()
            if document.processing_started_at
            else None,
            "processing_lease_expires_at": document.processing_lease_expires_at.isoformat()
            if document.processing_lease_expires_at
            else None,
        }

    @staticmethod
    def _document(row: dict) -> Document:
        return Document.model_validate(row["payload"])

    def create(self, document: Document) -> None:
        response = self._client.table(self._table_name).insert(self._row(document)).execute()
        if not response.data:
            raise RuntimeError("Supabase did not create document metadata")

    def get(self, document_id: str, owner_id: str) -> Optional[Document]:
        response = (
            self._client.table(self._table_name)
            .select("payload")
            .eq("id", document_id)
            .eq("owner_id", owner_id)
            .limit(1)
            .execute()
        )
        return self._document(response.data[0]) if response.data else None

    def find_by_source_hash(self, owner_id: str, source_hash: str) -> Optional[Document]:
        response = (
            self._client.table(self._table_name)
            .select("payload")
            .eq("owner_id", owner_id)
            .eq("source_hash", source_hash)
            .limit(1)
            .execute()
        )
        return self._document(response.data[0]) if response.data else None

    def list_for_owner(self, owner_id: str) -> list[Document]:
        response = (
            self._client.table(self._table_name)
            .select("payload")
            .eq("owner_id", owner_id)
            .order("created_at", desc=True)
            .execute()
        )
        return [self._document(row) for row in (response.data or [])]

    def update(self, document: Document) -> None:
        response = (
            self._client.table(self._table_name)
            .update(self._row(document))
            .eq("id", document.id)
            .eq("owner_id", document.user_uid)
            .execute()
        )
        if not response.data:
            raise KeyError(f"Document {document.id} no longer exists for its owner")

    def delete(self, document_id: str, owner_id: str) -> bool:
        response = (
            self._client.table(self._table_name)
            .delete()
            .eq("id", document_id)
            .eq("owner_id", owner_id)
            .execute()
        )
        return bool(response.data)

    def transfer_owner(self, from_owner: str, to_owner: str) -> int:
        response = self._client.rpc(
            "claim_anonymous_documents",
            {"p_anonymous_owner": from_owner, "p_account_owner": to_owner},
        ).execute()
        return int(response.data or 0)

    def list_recoverable_processing(self) -> list[Document]:
        response = (
            self._client.table(self._table_name)
            .select("payload")
            .in_("status", ["received", "processing"])
            .execute()
        )
        now = datetime.now(timezone.utc)
        documents = [self._document(row) for row in (response.data or [])]
        return [
            document
            for document in documents
            if document.status == "received"
            or (
                document.processing_lease_expires_at is not None
                and document.processing_lease_expires_at <= now
            )
        ]

    def claim_processing(self, document_id: str, owner_id: str, lease_seconds: int) -> bool:
        response = self._client.rpc(
            "claim_document_processing",
            {
                "p_document_id": document_id,
                "p_owner_id": owner_id,
                "p_lease_seconds": lease_seconds,
            },
        ).execute()
        return bool(response.data)


def create_document_repository() -> DocumentRepository:
    """Create the only supported metadata store for the active environment."""
    environment = os.getenv("ENVIRONMENT", "development").lower()
    backend = os.getenv(
        "DOCUMENT_REPOSITORY_BACKEND", "supabase" if environment == "production" else "sqlite"
    ).lower()
    if backend == "sqlite":
        if environment == "production":
            raise RuntimeError("SQLite document metadata is not allowed in production")
        return SQLiteDocumentRepository(
            os.getenv("DOCUMENT_METADATA_DB_PATH", "storage/document_metadata.db")
        )
    if backend == "dynamodb":
        table_name = os.getenv("DOCUMENT_METADATA_TABLE", "").strip()
        if not table_name:
            raise RuntimeError("DOCUMENT_METADATA_TABLE is required for DynamoDB document storage")
        return DynamoDBDocumentRepository(table_name, os.getenv("AWS_REGION"))
    if backend == "supabase":
        return SupabaseDocumentRepository(
            os.getenv("SUPABASE_URL", "").strip(),
            os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip(),
            os.getenv("SUPABASE_DOCUMENTS_TABLE", "documents").strip(),
        )
    raise RuntimeError(f"Unsupported DOCUMENT_REPOSITORY_BACKEND: {backend}")
