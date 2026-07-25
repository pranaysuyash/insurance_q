#!/usr/bin/env python3
"""Fail release preflight when packaged legal assets are incomplete or drift."""

from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LEGAL_SOURCES = (
    (
        REPO_ROOT / "docs" / "legal" / "privacy_policy.md",
        REPO_ROOT / "mobile" / "assets" / "legal" / "privacy_policy.md",
    ),
    (
        REPO_ROOT / "docs" / "legal" / "terms_of_service.md",
        REPO_ROOT / "mobile" / "assets" / "legal" / "terms_of_service.md",
    ),
)
UNRESOLVED_MARKERS = (
    "[Jurisdiction]",
    "[Company Name]",
    "[Controller Name]",
    "[Legal Entity]",
)
DISALLOWED_PRODUCT_ROLE_PHRASES = {
    "terms_of_service.md": ("information broker",),
}


def validation_errors() -> list[str]:
    """Return publishable-asset errors without exposing any customer data."""
    errors: list[str] = []
    for publishable, packaged in LEGAL_SOURCES:
        if not publishable.is_file() or not packaged.is_file():
            errors.append(f"missing required legal source: {publishable.name}")
            continue
        publishable_text = publishable.read_text(encoding="utf-8")
        if publishable.read_bytes() != packaged.read_bytes():
            errors.append(
                f"packaged legal asset differs from publishable source: {publishable.name}"
            )
        for marker in UNRESOLVED_MARKERS:
            if marker in publishable_text:
                errors.append(
                    f"unresolved legal placeholder in {publishable.name}: {marker}"
                )
        for phrase in DISALLOWED_PRODUCT_ROLE_PHRASES.get(publishable.name, ()):
            if phrase in publishable_text.lower():
                errors.append(
                    f"disallowed product-role wording in {publishable.name}: {phrase}"
                )
    return errors


def main() -> int:
    errors = validation_errors()
    if errors:
        print("legal release assets are not ready:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("legal release assets are complete and match the packaged documents.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
