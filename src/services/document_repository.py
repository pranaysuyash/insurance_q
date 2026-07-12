"""Canonical metadata repository for policy documents.

The API must never use process memory as the source of truth for customer
documents. Local development uses SQLite; production requires an explicitly
configured DynamoDB table. Both implementations enforce owner-scoped reads at
the repository boundary, so route code cannot accidentally list another
principal's documents after a restart or scale-out event.
"""

from __future__ import annotations

import json
import os
import sqlite3
import threading
from pathlib import Path
from typing import Iterable, Optional

from src.models.document import Document


class DocumentRepository:
    def create(self, document: Document) -> None:
        raise NotImplementedError

    def get(self, document_id: str, owner_id: str) -> Optional[Document]:
        raise NotImplementedError

    def list_for_owner(self, owner_id: str) -> list[Document]:
        raise NotImplementedError

    def update(self, document: Document) -> None:
        raise NotImplementedError

    def delete(self, document_id: str, owner_id: str) -> bool:
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


def create_document_repository() -> DocumentRepository:
    """Create the only supported metadata store for the active environment."""
    environment = os.getenv("ENVIRONMENT", "development").lower()
    backend = os.getenv(
        "DOCUMENT_REPOSITORY_BACKEND", "dynamodb" if environment == "production" else "sqlite"
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
    raise RuntimeError(f"Unsupported DOCUMENT_REPOSITORY_BACKEND: {backend}")
