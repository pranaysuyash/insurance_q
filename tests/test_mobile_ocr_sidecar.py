from pathlib import Path

import fitz
import pytest
from PIL import Image

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
    assert result["page_images"][1].startswith(b"\x89PNG")


@pytest.mark.asyncio
async def test_mobile_ocr_sidecar_preserves_image_page_artifact(tmp_path: Path):
    source = tmp_path / "scanned-policy.png"
    Image.new("RGB", (32, 24), "white").save(source, format="PNG")
    service = DocumentProcessingService()

    result = await service._extract_text(
        str(source),
        source.name,
        on_device_ocr_text="POLICY-ON-DEVICE-IMAGE-002",
    )

    assert result["full_text"] == "POLICY-ON-DEVICE-IMAGE-002"
    assert result["page_images"][1].startswith(b"\x89PNG")


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


@pytest.mark.asyncio
async def test_mixed_pdf_ocr_recovers_image_only_pages_without_losing_native_text(
    tmp_path: Path,
):
    source = tmp_path / "mixed-policy.pdf"
    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), "NATIVE-POLICY-004")
    document.new_page()
    document.save(source)
    document.close()

    class FakeOCR:
        async def _get_ocr_text_for_image(self, image_bytes: bytes, page_number: int) -> str:
            assert image_bytes
            assert page_number == 2
            return "SCANNED-POLICY-005"

    service = DocumentProcessingService()
    service._ocr_pipeline = FakeOCR()

    result = await service._extract_text(str(source), source.name)

    assert result["status"] == "completed"
    assert result["method"] == "mixed_native_doctr_ocr"
    assert result["native_text_pages"] == [1]
    assert result["ocr_pages"] == [2]
    assert result["ocr_unavailable_pages"] == []
    assert result["full_text"] == "NATIVE-POLICY-004\n\nSCANNED-POLICY-005"
    assert result["cir"]["capabilities"] == [
        "native_text",
        "scanned_ocr",
        "layout",
    ]
