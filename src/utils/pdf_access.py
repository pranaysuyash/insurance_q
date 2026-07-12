"""Request-scoped access checks for password-protected PDFs.

The password is deliberately never retained here: callers pass it only while
the already-open document is being unlocked, then discard it before storage,
OCR, indexing, logging, or background status updates.
"""

from __future__ import annotations

from typing import Optional


class PdfPasswordError(ValueError):
    """A user-actionable failure to unlock a password-protected PDF."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def unlock_pdf(document: object, password: Optional[str]) -> None:
    """Unlock an open PyMuPDF document or raise a safe user-facing error."""
    if not getattr(document, "needs_pass", False):
        return
    if not password:
        raise PdfPasswordError(
            "pdf_password_required",
            "This PDF is password protected. Enter its password to continue.",
        )
    if not document.authenticate(password):
        raise PdfPasswordError(
            "pdf_password_invalid",
            "That PDF password did not unlock this document. Try again.",
        )
