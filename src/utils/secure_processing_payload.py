"""Authenticated encryption for sensitive durable-processing inputs."""

from __future__ import annotations

import base64
import hashlib
import json
import os
from typing import Any

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


_VERSION = "v1"
_NONCE_BYTES = 12
_MIN_SECRET_LENGTH = 32


def _key() -> bytes:
    secret = os.getenv("PROCESSING_PAYLOAD_ENCRYPTION_KEY", "").strip()
    if len(secret) < _MIN_SECRET_LENGTH:
        raise RuntimeError(
            "PROCESSING_PAYLOAD_ENCRYPTION_KEY must be at least 32 characters"
        )
    return hashlib.sha256(secret.encode("utf-8")).digest()


def encrypt_processing_inputs(
    *,
    document_id: str,
    pdf_password: str | None,
    on_device_ocr_text: str | None,
) -> str | None:
    if not pdf_password and not on_device_ocr_text:
        return None
    plaintext = json.dumps(
        {
            "pdf_password": pdf_password,
            "on_device_ocr_text": on_device_ocr_text,
        },
        separators=(",", ":"),
    ).encode("utf-8")
    nonce = os.urandom(_NONCE_BYTES)
    ciphertext = AESGCM(_key()).encrypt(
        nonce, plaintext, document_id.encode("utf-8")
    )
    encode = lambda value: base64.urlsafe_b64encode(value).decode("ascii")
    return f"{_VERSION}.{encode(nonce)}.{encode(ciphertext)}"


def decrypt_processing_inputs(*, document_id: str, envelope: str) -> dict[str, Any]:
    try:
        version, encoded_nonce, encoded_ciphertext = envelope.split(".", 2)
        if version != _VERSION:
            raise ValueError("unsupported processing-input envelope version")
        nonce = base64.urlsafe_b64decode(encoded_nonce.encode("ascii"))
        ciphertext = base64.urlsafe_b64decode(encoded_ciphertext.encode("ascii"))
        plaintext = AESGCM(_key()).decrypt(
            nonce, ciphertext, document_id.encode("utf-8")
        )
        payload = json.loads(plaintext.decode("utf-8"))
    except Exception as error:
        raise ValueError("processing-input envelope could not be decrypted") from error
    if not isinstance(payload, dict):
        raise ValueError("processing-input envelope is not an object")
    return {
        "pdf_password": payload.get("pdf_password"),
        "on_device_ocr_text": payload.get("on_device_ocr_text"),
    }
