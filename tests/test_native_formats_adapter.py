"""Tests for native HTML and RFC822 document observations."""

from __future__ import annotations

import pytest

from src.ocr.native_formats import extract_native_eml_document, extract_native_html_document
from src.services.document_processing_service import DocumentProcessingService


def _html_fixture() -> bytes:
    return b"""
    <html><body>
      <h1>Health Policy</h1>
      <p>Coverage is subject to the schedule.</p>
      <table><tr><th>Benefit</th><th>Limit</th></tr>
        <tr><td>Hospitalization</td><td>500000</td></tr></table>
      <img src="https://example.test/policy.png" alt="policy chart">
    </body></html>
    """


def _eml_fixture() -> bytes:
    return (
        b"From: support@example.test\n"
        b"To: user@example.test\n"
        b"Subject: Policy schedule\n"
        b"MIME-Version: 1.0\n"
        b"Content-Type: multipart/mixed; boundary=part\n\n"
        b"--part\nContent-Type: text/plain; charset=utf-8\n\n"
        b"Please review policy POL-123.\n"
        b"--part\nContent-Type: image/png\n"
        b"Content-Disposition: attachment; filename=chart.png\n"
        b"Content-Transfer-Encoding: base64\n\n"
        b"iVBORw0KGgo=\n"
        b"--part--\n"
    )


def test_native_html_adapter_preserves_structure_without_fetching_images():
    result = extract_native_html_document(_html_fixture())

    assert "Health Policy" in result["full_text"]
    assert "500000" in result["full_text"]
    node_types = {node.node_type for node in result["nodes"]}
    assert {"page", "heading", "text_block", "table", "table_cell", "figure"} <= node_types
    figure = next(node for node in result["nodes"] if node.node_type == "figure")
    assert figure.attributes["artifact_status"] == "reference_only"
    assert figure.artifact_sha256 is None


def test_native_eml_adapter_preserves_body_headers_and_attachment_hash():
    result = extract_native_eml_document(_eml_fixture())

    assert "POL-123" in result["full_text"]
    subject = next(node for node in result["nodes"] if node.node_type == "heading")
    assert subject.source_text == "Policy schedule"
    attachment = next(node for node in result["nodes"] if node.node_type == "figure")
    assert attachment.attributes["filename"] == "chart.png"
    assert len(attachment.artifact_sha256) == 64


@pytest.mark.asyncio
@pytest.mark.parametrize("filename,content,method", [
    ("policy.html", _html_fixture(), "html-native"),
    ("message.eml", _eml_fixture(), "email-native"),
])
async def test_document_service_uses_native_lightweight_format_paths(
    tmp_path, filename, content, method
):
    source = tmp_path / filename
    source.write_bytes(content)
    result = await DocumentProcessingService()._extract_text(str(source), filename)

    assert result["status"] == "completed"
    assert result["method"] == method
    assert result["cir"]["parser_profile"] == method
