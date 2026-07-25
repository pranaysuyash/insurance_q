"""Canonical encrypted source-document store.

Local files are permitted only for development. Production uses Supabase
Storage. The historical S3 adapter remains available only when selected
explicitly, so a Cloud Run filesystem cannot become a customer-document store.
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Optional

from src.utils.runtime_config import supabase_server_key


class DocumentObjectStore:
    def put(self, document_id: str, owner_id: str, filename: str, content: bytes) -> str:
        raise NotImplementedError

    def delete(self, object_reference: str) -> None:
        raise NotImplementedError

    def get(self, object_reference: str) -> bytes:
        raise NotImplementedError

    def create_download_url(self, object_reference: str, expires_seconds: int = 900) -> str | None:
        """Return a short-lived private download URL when supported."""
        raise NotImplementedError

    def put_page_image(self, document_id: str, page_number: int, image_bytes: bytes) -> None:
        raise NotImplementedError

    def page_image_reference(self, document_id: str, page_number: int) -> str:
        raise NotImplementedError

    def get_page_image(self, document_id: str, page_number: int) -> bytes:
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

    def get(self, object_reference: str) -> bytes:
        return Path(object_reference).read_bytes()

    def create_download_url(self, object_reference: str, expires_seconds: int = 900) -> str | None:
        return None

    def put_page_image(self, document_id: str, page_number: int, image_bytes: bytes) -> None:
        path = self._directory / "_pages" / document_id / f"{page_number}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(image_bytes)

    def page_image_reference(self, document_id: str, page_number: int) -> str:
        return str(self._directory / "_pages" / document_id / f"{page_number}.png")

    def get_page_image(self, document_id: str, page_number: int) -> bytes:
        path = self._directory / "_pages" / document_id / f"{page_number}.png"
        return path.read_bytes()


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

    def get(self, object_reference: str) -> bytes:
        prefix = f"s3://{self._bucket}/"
        if not object_reference.startswith(prefix):
            raise ValueError("Object reference does not belong to configured document bucket")
        response = self._client.get_object(Bucket=self._bucket, Key=object_reference.removeprefix(prefix))
        return response["Body"].read()

    def create_download_url(self, object_reference: str, expires_seconds: int = 900) -> str | None:
        prefix = f"s3://{self._bucket}/"
        if not object_reference.startswith(prefix):
            raise ValueError("Object reference does not belong to configured document bucket")
        return self._client.generate_presigned_url(
            "get_object",
            Params={"Bucket": self._bucket, "Key": object_reference.removeprefix(prefix)},
            ExpiresIn=expires_seconds,
        )

    def put_page_image(self, document_id: str, page_number: int, image_bytes: bytes) -> None:
        key = f"_pages/{document_id}/{page_number}.png"
        self._client.put_object(
            Bucket=self._bucket,
            Key=key,
            Body=image_bytes,
            ContentType="image/png",
        )

    def page_image_reference(self, document_id: str, page_number: int) -> str:
        return f"s3://{self._bucket}/_pages/{document_id}/{page_number}.png"

    def get_page_image(self, document_id: str, page_number: int) -> bytes:
        key = f"_pages/{document_id}/{page_number}.png"
        response = self._client.get_object(Bucket=self._bucket, Key=key)
        return response["Body"].read()


class SupabaseDocumentObjectStore(DocumentObjectStore):
    """Durable source documents in a private Supabase Storage bucket."""

    def __init__(self, url: str, service_role_key: str, bucket: str):
        if not url or not service_role_key or not bucket:
            raise RuntimeError(
                "SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and SUPABASE_STORAGE_BUCKET are required"
            )
        try:
            from src.utils.supabase_client import create_client
        except ImportError as error:  # pragma: no cover - deployment dependency
            raise RuntimeError("supabase is required for Supabase document storage") from error
        self._client = create_client(url, service_role_key)
        self._bucket = bucket

    @staticmethod
    def _path(document_id: str, filename: str) -> str:
        return f"documents/{document_id}/{_safe_filename(filename)}"

    def put(self, document_id: str, owner_id: str, filename: str, content: bytes) -> str:
        path = self._path(document_id, filename)
        self._client.storage.from_(self._bucket).upload(
            path,
            content,
            {"content-type": "application/pdf", "upsert": "false"},
        )
        return f"supabase://{self._bucket}/{path}"

    def delete(self, object_reference: str) -> None:
        prefix = "supabase://"
        if not object_reference.startswith(prefix):
            raise ValueError("Object reference does not belong to configured Supabase bucket")
        bucket_and_path = object_reference.removeprefix(prefix)
        bucket, path = bucket_and_path.split("/", 1)
        if bucket != self._bucket:
            raise ValueError("Object reference belongs to a different Supabase bucket")
        self._client.storage.from_(self._bucket).remove([path])

    def get(self, object_reference: str) -> bytes:
        prefix = f"supabase://{self._bucket}/"
        if not object_reference.startswith(prefix):
            raise ValueError("Object reference belongs to a different Supabase bucket")
        return self._client.storage.from_(self._bucket).download(object_reference.removeprefix(prefix))

    def create_download_url(self, object_reference: str, expires_seconds: int = 900) -> str | None:
        prefix = f"supabase://{self._bucket}/"
        if not object_reference.startswith(prefix):
            raise ValueError("Object reference belongs to a different Supabase bucket")
        response = self._client.storage.from_(self._bucket).create_signed_url(
            object_reference.removeprefix(prefix), expires_seconds
        )
        if isinstance(response, dict):
            return response.get("signedURL") or response.get("signedUrl")
        return None

    def put_page_image(self, document_id: str, page_number: int, image_bytes: bytes) -> None:
        path = f"_pages/{document_id}/{page_number}.png"
        self._client.storage.from_(self._bucket).upload(
            path,
            image_bytes,
            {"content-type": "image/png", "upsert": "true"},
        )

    def page_image_reference(self, document_id: str, page_number: int) -> str:
        return f"supabase://{self._bucket}/_pages/{document_id}/{page_number}.png"

    def get_page_image(self, document_id: str, page_number: int) -> bytes:
        path = f"_pages/{document_id}/{page_number}.png"
        return self._client.storage.from_(self._bucket).download(path)


def create_document_object_store() -> DocumentObjectStore:
    environment = os.getenv("ENVIRONMENT", "development").lower()
    backend = os.getenv("DOCUMENT_OBJECT_STORE_BACKEND", "supabase" if environment == "production" else "local").lower()
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
    if backend == "supabase":
        return SupabaseDocumentObjectStore(
            os.getenv("SUPABASE_URL", "").strip(),
            supabase_server_key(),
            os.getenv("SUPABASE_STORAGE_BUCKET", "coverwise-documents").strip(),
        )
    raise RuntimeError(f"Unsupported DOCUMENT_OBJECT_STORE_BACKEND: {backend}")
