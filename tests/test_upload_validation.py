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


def test_rejects_encrypted_pdf_without_password(tmp_path):
    """Phase 0 P0-0.5 (trust audit, 2026-07-18): if a PDF is password-protected
    and the user did not supply a password, the validator must return
    `pdf_password_required` so the UI can prompt for it. The password is
    never stored, logged, or persisted at this stage.
    """
    path = tmp_path / "locked.pdf"
    document = fitz.open()
    document.new_page()
    document.save(path, encryption=fitz.PDF_ENCRYPT_AES_256, user_pw="secret")
    document.close()

    with pytest.raises(UploadValidationError) as error:
        validate_upload_content("locked.pdf", path.read_bytes())
    assert error.value.code == "pdf_password_required"


def test_rejects_encrypted_pdf_with_wrong_password(tmp_path):
    path = tmp_path / "locked.pdf"
    document = fitz.open()
    document.new_page()
    document.save(path, encryption=fitz.PDF_ENCRYPT_AES_256, user_pw="secret")
    document.close()

    with pytest.raises(UploadValidationError) as error:
        validate_upload_content(
            "locked.pdf", path.read_bytes(), pdf_password="not-the-password"
        )
    assert error.value.code == "pdf_password_invalid"


def test_accepts_encrypted_pdf_with_correct_password(tmp_path):
    """Phase 0 P0-0.5: validator unlocks in memory and the upload proceeds
    to the page-count checks. The password is not retained by the validator
    (it lives only in the function call frame) and is not echoed back.
    """
    path = tmp_path / "locked.pdf"
    document = fitz.open()
    document.new_page()
    document.save(path, encryption=fitz.PDF_ENCRYPT_AES_256, user_pw="secret")
    document.close()

    # Should NOT raise — the validator unlocks and validates page count.
    result = validate_upload_content(
        "locked.pdf", path.read_bytes(), pdf_password="secret"
    )
    assert result == ".pdf"


def test_does_not_echo_password_in_error_message(tmp_path):
    """Password must not appear in any error message the user might see."""
    path = tmp_path / "locked.pdf"
    document = fitz.open()
    document.new_page()
    document.save(path, encryption=fitz.PDF_ENCRYPT_AES_256, user_pw="secret-12345")
    document.close()

    with pytest.raises(UploadValidationError) as error:
        validate_upload_content(
            "locked.pdf", path.read_bytes(), pdf_password="wrong-password-xyz"
        )
    assert "secret" not in str(error.value)
    assert "wrong-password" not in str(error.value)
