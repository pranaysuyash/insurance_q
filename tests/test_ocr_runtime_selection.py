"""Regression coverage for the local OCR input-selection contract."""

import io

import pytest
from PIL import Image, ImageDraw


class _Prediction:
    def export(self):
        return {
            "pages": [
                {
                    "blocks": [
                        {
                            "lines": [
                                {"words": [{"value": "Policy"}, {"value": "CW-1"}]}
                            ]
                        }
                    ]
                }
            ]
        }


class _Predictor:
    def __call__(self, pages):
        assert pages[0].ndim == 3
        return _Prediction()


@pytest.mark.asyncio
async def test_ocr_prefers_untouched_rgb_page_when_it_is_readable(monkeypatch):
    from src.ocr.pipeline import OCRPipeline

    image = Image.new("RGB", (240, 100), "white")
    ImageDraw.Draw(image).text((10, 30), "Policy CW-1", fill="black")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")

    pipeline = OCRPipeline.__new__(OCRPipeline)
    pipeline.doctr_predictor = _Predictor()

    def preprocessing_should_not_run(_image):
        raise AssertionError("preprocessing should be a fallback for unreadable RGB OCR")

    monkeypatch.setattr(pipeline, "_preprocess_image", preprocessing_should_not_run)

    text = await pipeline._get_ocr_text_for_image(buffer.getvalue(), 1)

    assert text == "Policy CW-1"


@pytest.mark.asyncio
async def test_ocr_pipeline_rejects_empty_scan_as_an_error(monkeypatch):
    from src.ocr import pipeline as ocr_module
    from src.ocr.pipeline import OCRPipeline

    monkeypatch.setattr(ocr_module.settings, "docling_enabled", False)
    pipeline = OCRPipeline.__new__(OCRPipeline)
    pipeline.doc_qa_model_name = "test-model"

    async def convert(_content, _file_type):
        return [{"page_num": 1, "image_bytes": b"scan"}]

    async def extract(_image_bytes, _page_num):
        return ""

    pipeline._convert_file_to_images_bytes = convert
    pipeline._get_ocr_text_for_image = extract

    result = await pipeline.process_document(b"scan", "png", "blank.png")

    assert result["status"] == "error"
    assert result["error_code"] == "no_text_extracted"
    assert result["capability"] == "scanned_ocr"


@pytest.mark.asyncio
async def test_document_service_rejects_completed_empty_ocr_adapter(tmp_path):
    from src.services.document_processing_service import DocumentProcessingService

    source = tmp_path / "blank-scan.pdf"
    import fitz
    pdf = fitz.open()
    pdf.new_page()
    pdf.save(source)
    pdf.close()

    class EmptyPDFProcessor:
        def process_pdf(self, _file_path):
            return {"status": "completed", "full_text": "", "method": "ocr_pipeline"}

    service = DocumentProcessingService()
    service._ocr_pipeline = object()
    service.pdf_processor = EmptyPDFProcessor()

    result = await service._extract_text(str(source), source.name)

    assert result["status"] == "failed"
    assert result["error_code"] == "no_text_extracted"
    assert result["full_text"] == ""
