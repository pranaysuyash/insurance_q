"""Canonical encrypted source-document store.

Local files are permitted only for development. Production uses an S3 bucket
and requires KMS encryption, which prevents an App Runner filesystem from
becoming an accidental customer-document database.
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Optional


class DocumentObjectStore:
    def put(self, document_id: str, owner_id: str, filename: str, content: bytes) -> str:
        raise NotImplementedError

    def delete(self, object_reference: str) -> None:
        raise NotImplementedError


def _safe_filename(filename: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", filename)[:180] or "document"


class LocalDocumentObjectStore(DocumentObjectStore):
    def __init__(self, directory: str):
        self._directory = Path(directory)
        self._directory.mkdir(parents=True, exist_ok=True)

    def put(self, document_id: str, owner_id: str, filename: str, content: bytes) -> str:
        path = self._directory / f"{document_id}_{_safe_filename(filename)}"
        path.write_bytes(content)
        return str(path)

    def delete(self, object_reference: str) -> None:
        path = Path(object_reference)
        if path.exists():
            path.unlink()


class S3DocumentObjectStore(DocumentObjectStore):
    def __init__(self, bucket: str, kms_key_id: str, region_name: Optional[str] = None):
        try:
            import boto3
        except ImportError as error:  # pragma: no cover - deployment dependency
            raise RuntimeError("boto3 is required for S3 document storage") from error
        self._bucket = bucket
        self._client = boto3.client("s3", region_name=region_name)
        self._kms_key_id = kms_key_id

    @staticmethod
    def _key(document_id: str, owner_id: str, filename: str) -> str:
        # UUID documents are only addressable through owner-scoped metadata;
        # do not put raw owner identities or source filenames in object keys.
        return f"documents/{document_id}/{_safe_filename(filename)}"

    def put(self, document_id: str, owner_id: str, filename: str, content: bytes) -> str:
        key = self._key(document_id, owner_id, filename)
        self._client.put_object(
            Bucket=self._bucket,
            Key=key,
            Body=content,
            ServerSideEncryption="aws:kms",
            SSEKMSKeyId=self._kms_key_id,
            Metadata={"document-id": document_id},
        )
        return f"s3://{self._bucket}/{key}"

    def delete(self, object_reference: str) -> None:
        prefix = f"s3://{self._bucket}/"
        if not object_reference.startswith(prefix):
            raise ValueError("Object reference does not belong to configured document bucket")
        self._client.delete_object(Bucket=self._bucket, Key=object_reference.removeprefix(prefix))


def create_document_object_store() -> DocumentObjectStore:
    environment = os.getenv("ENVIRONMENT", "development").lower()
    backend = os.getenv("DOCUMENT_OBJECT_STORE_BACKEND", "s3" if environment == "production" else "local").lower()
    if backend == "local":
        if environment == "production":
            raise RuntimeError("Local document object storage is not allowed in production")
        return LocalDocumentObjectStore(os.getenv("DOCUMENT_STORAGE_DIR", "storage/documents"))
    if backend == "s3":
        bucket = os.getenv("DOCUMENT_STORAGE_BUCKET", "").strip()
        kms_key_id = os.getenv("DOCUMENT_STORAGE_KMS_KEY_ID", "").strip()
        if not bucket or not kms_key_id:
            raise RuntimeError(
                "DOCUMENT_STORAGE_BUCKET and DOCUMENT_STORAGE_KMS_KEY_ID are required for S3 document storage"
            )
        return S3DocumentObjectStore(bucket, kms_key_id, os.getenv("AWS_REGION"))
    raise RuntimeError(f"Unsupported DOCUMENT_OBJECT_STORE_BACKEND: {backend}")
