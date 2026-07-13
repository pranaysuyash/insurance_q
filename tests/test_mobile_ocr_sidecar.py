from pathlib import Path

import fitz
import pytest

from src.services.document_processing_service import DocumentProcessingService


def _pdf(path: Path, text: str | None = None) -> None:
    document = fitz.open()
    page = document.new_page()
    if text:
        page.insert_text((72, 72), text)
    document.save(path)
    document.close()


@pytest.mark.asyncio
async def test_mobile_ocr_sidecar_recovers_an_image_only_pdf(tmp_path: Path):
    source = tmp_path / "scanned-policy.pdf"
    _pdf(source)
    service = DocumentProcessingService()

    result = await service._extract_text(
        str(source),
        source.name,
        on_device_ocr_text="[Page 1]\nPOLICY-ON-DEVICE-001",
    )

    assert result["full_text"] == "[Page 1]\nPOLICY-ON-DEVICE-001"
    assert result["method"] == "mobile_mlkit_text_recognition"
    assert result["provenance"] == "client_on_device_ocr_sidecar"


@pytest.mark.asyncio
async def test_embedded_pdf_text_remains_authoritative_over_mobile_ocr(tmp_path: Path):
    source = tmp_path / "digital-policy.pdf"
    _pdf(source, "SOURCE-POLICY-002")
    service = DocumentProcessingService()

    result = await service._extract_text(
        str(source),
        source.name,
        on_device_ocr_text="UNTRUSTED-REPLACEMENT-003",
    )

    assert result["full_text"] == "SOURCE-POLICY-002"
    assert result["method"] == "direct_text"
