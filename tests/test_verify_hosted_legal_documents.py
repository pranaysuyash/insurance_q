from hashlib import sha256

from tools import verify_hosted_legal_documents as verifier


class FakeResponse:
    def __init__(
        self,
        body: str,
        source_hash: str,
        *,
        cache_control: str = "no-store",
        status: int = 200,
    ) -> None:
        self._body = body.encode("utf-8")
        self._status = status
        self.headers = {
            verifier.HASH_HEADER: source_hash,
            "Cache-Control": cache_control,
        }

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def geturl(self) -> str:
        return "https://coverwise.example/privacy"

    def getcode(self) -> int:
        return self._status

    def read(self, size: int = -1) -> bytes:
        return self._body if size < 0 else self._body[:size]


def test_rejects_non_https_url_without_requesting_it():
    called = False

    def opener(*_args, **_kwargs):
        nonlocal called
        called = True
        raise AssertionError("non-HTTPS URLs must not be requested")

    result = verifier.verify_document("privacy", "http://example.com/privacy", opener=opener)

    assert not called
    assert result.errors == ["URL must be an absolute https:// URL"]


def test_accepts_hosted_page_with_exact_source_and_hash():
    source = verifier.LEGAL_DOCUMENTS["privacy"].read_text(encoding="utf-8")
    expected_hash = sha256(source.encode("utf-8")).hexdigest()
    body = (
        '<meta name="legal-document-sha256" '
        f'content="{expected_hash}">{source.replace("&", "&amp;")}'
    )

    result = verifier.verify_document(
        "privacy",
        "https://coverwise.example/privacy",
        opener=lambda *_args, **_kwargs: FakeResponse(body, expected_hash),
    )

    assert result.passed


def test_rejects_body_or_hash_drift():
    result = verifier.verify_document(
        "terms",
        "https://coverwise.example/terms",
        opener=lambda *_args, **_kwargs: FakeResponse("wrong body", "not-a-hash"),
    )

    assert f"{verifier.HASH_HEADER} does not match the canonical source" in result.errors
    assert "Cache-Control does not include no-store" not in result.errors
    assert "legal-document-sha256 page metadata does not match the canonical source" in result.errors
    assert "decoded response body does not match the canonical source" in result.errors


def test_rejects_oversized_hosted_page():
    source_hash = "a" * 64
    oversized_body = "x" * (verifier.MAX_RESPONSE_BYTES + 1)

    result = verifier.verify_document(
        "privacy",
        "https://coverwise.example/privacy",
        opener=lambda *_args, **_kwargs: FakeResponse(oversized_body, source_hash),
    )

    assert result.errors == ["hosted page exceeds the 1 MB verification limit"]
