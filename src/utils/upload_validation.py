"""Canonical, bounded validation for policy-document uploads.

Extensions are user-controlled labels, not a security boundary. Every upload
entry point must use this module before persistence, OCR, or hashing so the
document pipeline only receives formats it can actually process.
"""

from __future__ import annotations

from io import BytesIO
from pathlib import Path
from typing import Final, Optional

import fitz
from PIL import Image, UnidentifiedImageError



MAX_UPLOAD_BYTES: Final = 50 * 1024 * 1024
MAX_PDF_PAGES: Final = 100
MAX_IMAGE_PIXELS: Final = 40_000_000
SUPPORTED_EXTENSIONS: Final = frozenset(
    {".pdf", ".png", ".jpg", ".jpeg", ".tiff", ".tif", ".webp"}
)
# These formats are supported by the internal text-processing path for
# fixtures, migrations, and explicitly composed non-upload workflows. They
# are intentionally not public policy-upload formats until their product
# validation and evidence UX are designed.
TEXT_FALLBACK_EXTENSIONS: Final = frozenset(
    {".txt", ".md", ".csv", ".json", ".xml", ".html"}
)


class UploadValidationError(ValueError):
    """A safe, actionable upload rejection for API clients."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def validate_upload_content(
    filename: Optional[str], file_content: bytes, *, pdf_password: Optional[str] = None
) -> str:
    """Validate format, signature, and bounded parseability; return extension."""
    extension = Path(filename or "").suffix.lower()
    if extension not in SUPPORTED_EXTENSIONS:
        raise UploadValidationError(
            "unsupported_file_type",
            "Upload a PDF, PNG, JPG, TIFF, or WebP policy document.",
        )
    if len(file_content) > MAX_UPLOAD_BYTES:
        raise UploadValidationError(
            "file_too_large",
            "This document is larger than 50 MB. Upload a smaller policy file.",
        )
    if extension == ".pdf":
        _validate_pdf(file_content, pdf_password=pdf_password)
    else:
        _validate_image(extension, file_content)
    return extension


def _validate_pdf(file_content: bytes, *, pdf_password: str | None = None) -> None:
    if not file_content.startswith(b"%PDF-"):
        raise UploadValidationError(
            "file_signature_mismatch",
            "The file does not contain a readable PDF document.",
        )
    try:
        document = fitz.open(stream=file_content, filetype="pdf")
    except Exception as error:
        raise UploadValidationError(
            "pdf_unreadable",
            "This PDF could not be opened. Check that it is a valid, readable document.",
        ) from error
    try:
        if document.page_count > MAX_PDF_PAGES:
            raise UploadValidationError(
                "pdf_too_many_pages",
                "This PDF has more than 100 pages. Upload the relevant policy pages instead.",
            )
        if document.page_count < 1:
            raise UploadValidationError(
                "pdf_empty",
                "This PDF has no pages. Upload a readable policy document.",
            )
        # Phase 0 P0-0.5 (trust audit, 2026-07-18): if the PDF is encrypted,
        # validate the supplied password in-memory and unlock for the rest of
        # the validation. The password is never logged, never persisted, and
        # never passed to the object store. The downstream processing pipeline
        # accepts the same password and re-unlocks the same way (see
        # src/utils/pdf_access.py::unlock_pdf). This closes the contradiction
        # flagged by the trust audit: previously the API exposed a password
        # field that the validator rejected and the parser used — neither
        # contract was honest. Now both validate and unlock consistently.
        if document.needs_pass:
            if not pdf_password:
                raise UploadValidationError(
                    "pdf_password_required",
                    "This PDF is password-protected. Re-upload with the password so we can read the policy.",
                )
            unlock_result = document.authenticate(password=pdf_password)
            if not unlock_result:
                raise UploadValidationError(
                    "pdf_password_invalid",
                    "The supplied password did not unlock this PDF. Re-upload with the correct password.",
                )
    finally:
        document.close()


def _validate_image(extension: str, file_content: bytes) -> None:
    if not _matches_image_signature(extension, file_content):
        raise UploadValidationError(
            "file_signature_mismatch",
            "The file contents do not match the selected image format.",
        )
    try:
        with Image.open(BytesIO(file_content)) as image:
            image.verify()
        with Image.open(BytesIO(file_content)) as image:
            width, height = image.size
            if width * height > MAX_IMAGE_PIXELS:
                raise UploadValidationError(
                    "image_too_large",
                    "This image is too large to process safely. Upload a smaller policy image.",
                )
    except Image.DecompressionBombError as error:
        raise UploadValidationError(
            "image_too_large",
            "This image is too large to process safely. Upload a smaller policy image.",
        ) from error
    except (UnidentifiedImageError, OSError, SyntaxError) as error:
        raise UploadValidationError(
            "image_unreadable",
            "This image could not be opened. Upload a readable policy image.",
        ) from error


def _matches_image_signature(extension: str, file_content: bytes) -> bool:
    if extension == ".png":
        return file_content.startswith(b"\x89PNG\r\n\x1a\n")
    if extension in {".jpg", ".jpeg"}:
        return file_content.startswith(b"\xff\xd8\xff")
    if extension in {".tif", ".tiff"}:
        return file_content.startswith((b"II*\x00", b"MM\x00*"))
    if extension == ".webp":
        return len(file_content) >= 12 and file_content.startswith(b"RIFF") and file_content[8:12] == b"WEBP"
    return False
