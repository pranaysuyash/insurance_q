from io import BytesIO

import fitz
import pytest
from PIL import Image

from src.utils.upload_validation import UploadValidationError, validate_upload_content


def _image_bytes(image_format: str = "PNG") -> bytes:
    output = BytesIO()
    Image.new("RGB", (24, 16), color="white").save(output, format=image_format)
    return output.getvalue()


def _pdf_bytes(page_count: int = 1) -> bytes:
    document = fitz.open()
    for _ in range(page_count):
        document.new_page()
    output = document.tobytes()
    document.close()
    return output


def test_accepts_a_parseable_image_with_matching_signature():
    assert validate_upload_content("policy.png", _image_bytes()) == ".png"


def test_rejects_an_image_extension_with_non_image_content():
    with pytest.raises(UploadValidationError) as error:
        validate_upload_content("policy.png", b"not an image")
    assert error.value.code == "file_signature_mismatch"


def test_rejects_unsupported_office_documents_instead_of_binary_fallback():
    with pytest.raises(UploadValidationError) as error:
        validate_upload_content("policy.docx", b"PK\x03\x04")
    assert error.value.code == "unsupported_file_type"


def test_rejects_pdf_over_the_page_budget():
    with pytest.raises(UploadValidationError) as error:
        validate_upload_content("long-policy.pdf", _pdf_bytes(page_count=101))
    assert error.value.code == "pdf_too_many_pages"


def test_rejects_encrypted_pdf_without_storing_a_password(tmp_path):
    path = tmp_path / "locked.pdf"
    document = fitz.open()
    document.new_page()
    document.save(path, encryption=fitz.PDF_ENCRYPT_AES_256, user_pw="secret")
    document.close()

    with pytest.raises(UploadValidationError) as error:
        validate_upload_content("locked.pdf", path.read_bytes())
    assert error.value.code == "encrypted_pdf_not_supported"
