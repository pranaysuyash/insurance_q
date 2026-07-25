#!/usr/bin/env python3
"""Compare configured HTTPS legal pages with the canonical tracked sources."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from hashlib import sha256
from html import unescape
from pathlib import Path
import re
from typing import Callable
from urllib.error import URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
LEGAL_DOCUMENTS = {
    "privacy": REPOSITORY_ROOT / "docs/legal/privacy_policy.md",
    "terms": REPOSITORY_ROOT / "docs/legal/terms_of_service.md",
}
HASH_HEADER = "X-CoverWise-Legal-SHA256"
MAX_RESPONSE_BYTES = 1_000_000
HASH_META_PATTERN = re.compile(
    r'<meta\s+name=["\']legal-document-sha256["\']\s+'
    r'content=["\'](?P<hash>[0-9a-f]{64})["\']',
    re.IGNORECASE,
)


@dataclass(frozen=True)
class VerificationResult:
    document: str
    url: str
    errors: list[str]

    @property
    def passed(self) -> bool:
        return not self.errors


def _https_url_error(url: str) -> str | None:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.netloc:
        return "URL must be an absolute https:// URL"
    return None


def verify_document(
    document: str,
    url: str,
    *,
    timeout_seconds: float = 15.0,
    opener: Callable[..., object] = urlopen,
) -> VerificationResult:
    """Verify one hosted legal page without logging its body or request data."""
    errors: list[str] = []
    url_error = _https_url_error(url)
    if url_error:
        return VerificationResult(document=document, url=url, errors=[url_error])

    source_path = LEGAL_DOCUMENTS[document]
    source_text = source_path.read_text(encoding="utf-8")
    expected_hash = sha256(source_text.encode("utf-8")).hexdigest()
    request = Request(url, headers={"Accept": "text/html, text/plain;q=0.9"})

    try:
        with opener(request, timeout=timeout_seconds) as response:
            final_url = response.geturl()
            status = response.getcode()
            headers = response.headers
            body_bytes = response.read(MAX_RESPONSE_BYTES + 1)
    except (OSError, URLError, UnicodeDecodeError) as error:
        return VerificationResult(
            document=document,
            url=url,
            errors=[f"hosted page could not be read: {type(error).__name__}"],
        )

    if len(body_bytes) > MAX_RESPONSE_BYTES:
        return VerificationResult(
            document=document,
            url=url,
            errors=["hosted page exceeds the 1 MB verification limit"],
        )
    try:
        body = body_bytes.decode("utf-8")
    except UnicodeDecodeError as error:
        return VerificationResult(
            document=document,
            url=url,
            errors=[f"hosted page could not be read: {type(error).__name__}"],
        )

    if status != 200:
        errors.append(f"expected HTTP 200, got {status}")
    if _https_url_error(final_url):
        errors.append("final response URL is not https://")
    if "no-store" not in headers.get("Cache-Control", "").lower():
        errors.append("Cache-Control does not include no-store")
    if headers.get(HASH_HEADER) != expected_hash:
        errors.append(f"{HASH_HEADER} does not match the canonical source")
    meta_match = HASH_META_PATTERN.search(body)
    if not meta_match or meta_match.group("hash").lower() != expected_hash:
        errors.append("legal-document-sha256 page metadata does not match the canonical source")
    if source_text not in unescape(body):
        errors.append("decoded response body does not match the canonical source")

    return VerificationResult(document=document, url=url, errors=errors)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify hosted Privacy and Terms pages against tracked legal sources."
    )
    parser.add_argument("--privacy-url", required=True)
    parser.add_argument("--terms-url", required=True)
    parser.add_argument("--timeout-seconds", type=float, default=15.0)
    arguments = parser.parse_args()

    results = [
        verify_document(
            "privacy", arguments.privacy_url, timeout_seconds=arguments.timeout_seconds
        ),
        verify_document(
            "terms", arguments.terms_url, timeout_seconds=arguments.timeout_seconds
        ),
    ]
    for result in results:
        if result.passed:
            print(f"{result.document}: hosted page matches canonical source")
        else:
            print(f"{result.document}: verification failed")
            for error in result.errors:
                print(f"- {error}")
    return 0 if all(result.passed for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
