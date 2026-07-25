import pytest

from src.utils.secure_processing_payload import (
    decrypt_processing_inputs,
    encrypt_processing_inputs,
)


def test_processing_inputs_round_trip_is_authenticated(monkeypatch):
    monkeypatch.setenv("PROCESSING_PAYLOAD_ENCRYPTION_KEY", "k" * 32)
    envelope = encrypt_processing_inputs(
        document_id="doc-1",
        pdf_password="private-password",
        on_device_ocr_text="private OCR text",
    )
    assert envelope is not None
    assert "private-password" not in envelope
    assert "private OCR text" not in envelope
    assert decrypt_processing_inputs(document_id="doc-1", envelope=envelope) == {
        "pdf_password": "private-password",
        "on_device_ocr_text": "private OCR text",
    }


def test_processing_inputs_are_bound_to_document_and_key(monkeypatch):
    monkeypatch.setenv("PROCESSING_PAYLOAD_ENCRYPTION_KEY", "k" * 32)
    envelope = encrypt_processing_inputs(
        document_id="doc-1", pdf_password="secret", on_device_ocr_text=None
    )
    assert envelope is not None
    with pytest.raises(ValueError, match="could not be decrypted"):
        decrypt_processing_inputs(document_id="doc-2", envelope=envelope)

    monkeypatch.setenv("PROCESSING_PAYLOAD_ENCRYPTION_KEY", "different" * 4)
    with pytest.raises(ValueError, match="could not be decrypted"):
        decrypt_processing_inputs(document_id="doc-1", envelope=envelope)


def test_sensitive_processing_input_requires_an_encryption_key(monkeypatch):
    monkeypatch.delenv("PROCESSING_PAYLOAD_ENCRYPTION_KEY", raising=False)
    with pytest.raises(RuntimeError, match="at least 32"):
        encrypt_processing_inputs(
            document_id="doc-1", pdf_password="secret", on_device_ocr_text=None
        )


def test_empty_processing_inputs_do_not_create_an_envelope(monkeypatch):
    monkeypatch.delenv("PROCESSING_PAYLOAD_ENCRYPTION_KEY", raising=False)
    assert encrypt_processing_inputs(
        document_id="doc-1", pdf_password=None, on_device_ocr_text=None
    ) is None


def test_processing_payload_key_length_is_measured_in_utf8_bytes(monkeypatch):
    monkeypatch.setenv("PROCESSING_PAYLOAD_ENCRYPTION_KEY", "🔐" * 8)

    envelope = encrypt_processing_inputs(
        document_id="doc-1", pdf_password="password", on_device_ocr_text=None
    )

    assert envelope is not None
    assert decrypt_processing_inputs(document_id="doc-1", envelope=envelope)[
        "pdf_password"
    ] == "password"
