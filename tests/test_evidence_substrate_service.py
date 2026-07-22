"""Tests for the evidence substrate service (Trust Phase 1 access layer).

The substrate is the source of truth for everything claim-shaped in
CoverWise. These tests are the regression net for the typed Python
access layer that wraps the four substrate tables. They do NOT
require a live Supabase project; they exercise the in-process
validation, pydantic roundtrips, and the fail-loud contracts.

The trust audit's Phase 1 acceptance is:
  1. The service rejects malformed input before any DB call.
  2. Pydantic models roundtrip the (raw, normalized, display)
     three-layer value wrapper without loss.
  3. Bounding-box validation enforces the page-relative keys.
  4. Confidence and evidence_strength bounds are enforced at the
     model boundary, not at the DB.
  5. Missing-env initialization is fail-loud (no silent fallback
     to an in-memory store; per Trust Phase 0, the policy detail
     screen shows the 'Not yet verified' scaffold, which is the
     honest UI for an unavailable substrate).
"""

import hashlib
import os
import sys
from unittest.mock import MagicMock

import pytest

# Allow tests to run from the repo root without installing the package.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.models.evidence import (  # noqa: E402
    ExtractedValue,
    FieldCitation,
    PageArtifact,
    ParserKind,
    SourceSpan,
    SpanType,
    ValueType,
)
from src.services.evidence_substrate_service import (  # noqa: E402
    EvidenceSubstrateError,
    EvidenceSubstrateService,
    EvidenceSubstrateUnavailable,
)


# --- 1. initialization is fail-loud ---

def test_from_env_raises_when_url_missing(monkeypatch):
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "test-key")
    with pytest.raises(EvidenceSubstrateUnavailable):
        EvidenceSubstrateService.from_env()


def test_from_env_raises_when_key_missing(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    with pytest.raises(EvidenceSubstrateUnavailable):
        EvidenceSubstrateService.from_env()


def test_constructor_rejects_empty_inputs():
    with pytest.raises(EvidenceSubstrateUnavailable):
        EvidenceSubstrateService("", "key")
    with pytest.raises(EvidenceSubstrateUnavailable):
        EvidenceSubstrateService("url", "")


# --- 2. pydantic value wrapper ---

def test_extracted_value_three_layers_distinct():
    """The three layers must be distinct. Conflating them is the
    citation-lie failure mode that the trust audit flags."""
    v = ExtractedValue(raw="5,00,000", normalized=500000, display="₹5,00,000")
    assert v.raw == "5,00,000"
    assert v.normalized == 500000
    assert v.display == "₹5,00,000"
    # raw is bytes-for-bytes what the parser saw
    # normalized is what code reasons about
    # display is what the user sees
    # all three are independently required


def test_extracted_value_rejects_empty_raw():
    with pytest.raises(ValueError):
        ExtractedValue(raw="", normalized=1, display="x")


def test_extracted_value_accepts_arbitrary_normalized():
    """normalized can be any JSON-serializable type: number,
    string, list, dict. The display is always a string."""
    v1 = ExtractedValue(raw="0.5", normalized=0.5, display="50%")
    assert v1.normalized == 0.5
    v2 = ExtractedValue(raw='["a","b"]', normalized=["a", "b"], display="a, b")
    assert v2.normalized == ["a", "b"]
    v3 = ExtractedValue(raw='{"k":1}', normalized={"k": 1}, display="k=1")
    assert v3.normalized == {"k": 1}


def test_extracted_value_rejects_empty_display():
    with pytest.raises(ValueError):
        ExtractedValue(raw="x", normalized=1, display="")


# --- 3. bounding-box validation ---

def _good_bbox():
    return {"x": 100, "y": 200, "w": 50, "h": 20, "page_w": 612, "page_h": 792}


def test_source_span_accepts_well_formed_bbox():
    s = SourceSpan(
        span_text="Sum insured: 5,00,000",
        bbox_json=_good_bbox(),
        span_type=SpanType.HEADER,
        confidence=0.95,
        parser_version="layout-v1",
    )
    assert s.span_type == SpanType.HEADER
    assert s.confidence == 0.95


def test_source_span_rejects_missing_bbox_keys():
    bad = {"x": 0, "y": 0, "w": 1, "h": 1}  # missing page_w, page_h
    with pytest.raises(ValueError):
        SourceSpan(
            span_text="x",
            bbox_json=bad,
            span_type=SpanType.PARAGRAPH,
            confidence=0.5,
            parser_version="v1",
        )


def test_source_span_rejects_confidence_out_of_bounds():
    for bad in (-0.1, 1.1, 2.0):
        with pytest.raises(ValueError):
            SourceSpan(
                span_text="x",
                bbox_json=_good_bbox(),
                span_type=SpanType.PARAGRAPH,
                confidence=bad,
                parser_version="v1",
            )


def test_source_span_rejects_empty_text():
    with pytest.raises(ValueError):
        SourceSpan(
            span_text="",
            bbox_json=_good_bbox(),
            span_type=SpanType.PARAGRAPH,
            confidence=0.5,
            parser_version="v1",
        )


# --- 4. enums match the SQL CHECK constraints ---

def test_span_type_enum_matches_sql_check():
    """The typed source-span vocabulary must match the SQL CHECK constraint."""
    expected = {
        "text_block", "sentence", "paragraph", "heading", "line", "word",
        "table_cell", "table", "formula", "form_field", "caption", "annotation",
        "header", "footer", "list_item", "other",
    }
    actual = {s.value for s in SpanType}
    assert actual == expected


def test_value_type_enum_matches_sql_check():
    expected = {"string", "number", "date", "currency", "enum", "clause_text"}
    actual = {v.value for v in ValueType}
    assert actual == expected


def test_parser_kind_enum_matches_sql_check():
    expected = {
        "deterministic_regex", "deterministic_lookup", "llm_extract",
    }
    actual = {p.value for p in ParserKind}
    assert actual == expected


# --- 5. service write contracts (mocked supabase) ---

def _service_with_mocked_client():
    client = MagicMock()
    return EvidenceSubstrateService("https://x.supabase.co", "test-key", client=client)


def test_append_page_artifact_rejects_page_number_zero():
    import uuid
    svc = _service_with_mocked_client()
    import asyncio
    with pytest.raises(EvidenceSubstrateError):
        asyncio.run(
            svc.append_page_artifact(
                document_id=uuid.uuid4(),
                page_number=0,
                page_image_bytes=b"fake",
            )
        )


def test_append_page_artifact_rejects_empty_bytes():
    import uuid
    svc = _service_with_mocked_client()
    import asyncio
    with pytest.raises(EvidenceSubstrateError):
        asyncio.run(
            svc.append_page_artifact(
                document_id=uuid.uuid4(),
                page_number=1,
                page_image_bytes=b"",
            )
        )


def test_append_page_artifact_replays_same_immutable_row():
    import asyncio
    import uuid

    client = MagicMock()
    existing_id = uuid.uuid4()
    image = b"same-page"
    image_uri = "coverwise-documents/doc/pages/1.png"
    client.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [{
        "id": str(existing_id),
        "image_uri": image_uri,
        "sha256": hashlib.sha256(image).hexdigest(),
    }]
    svc = EvidenceSubstrateService("https://x.supabase.co", "test-key", client=client)

    result = asyncio.run(
        svc.append_page_artifact(
            document_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
            page_number=1,
            page_image_bytes=image,
            image_uri=image_uri,
        )
    )

    assert result == existing_id
    client.table.return_value.insert.assert_not_called()


def test_append_page_artifact_rejects_replay_with_different_bytes():
    import asyncio
    import uuid

    client = MagicMock()
    client.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [{
        "id": str(uuid.uuid4()),
        "image_uri": "coverwise-documents/doc/pages/1.png",
        "sha256": "0" * 64,
    }]
    svc = EvidenceSubstrateService("https://x.supabase.co", "test-key", client=client)

    with pytest.raises(EvidenceSubstrateError, match="page_artifact conflict"):
        asyncio.run(
            svc.append_page_artifact(
                document_id=uuid.UUID("00000000-0000-0000-0000-000000000001"),
                page_number=1,
                page_image_bytes=b"different-page",
                image_uri="coverwise-documents/doc/pages/1.png",
            )
        )


def test_append_source_spans_replays_existing_logical_spans():
    import asyncio
    import uuid

    client = MagicMock()
    span_id = uuid.uuid4()
    row = {
        "id": str(span_id),
        "span_text": "Policy number: POL-001",
        "bbox_json": {"x": 1, "y": 2, "w": 3, "h": 4, "page_w": 612, "page_h": 792},
        "span_type": "paragraph",
        "confidence": 0.9,
        "parser_version": "parser-v1",
    }
    client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [row]
    svc = EvidenceSubstrateService("https://x.supabase.co", "test-key", client=client)

    result = asyncio.run(
        svc.append_source_spans(
            uuid.UUID("00000000-0000-0000-0000-000000000001"),
            [SourceSpan(
                span_text=row["span_text"],
                bbox_json=row["bbox_json"],
                span_type=SpanType.PARAGRAPH,
                confidence=row["confidence"],
                parser_version=row["parser_version"],
            )],
        )
    )

    assert result == [span_id]
    client.table.return_value.insert.assert_not_called()


def test_append_extracted_field_rejects_empty_field_name():
    import uuid
    svc = _service_with_mocked_client()
    import asyncio
    with pytest.raises(EvidenceSubstrateError):
        asyncio.run(
            svc.append_extracted_field(
                document_id=uuid.uuid4(),
                field_name="",
                value=ExtractedValue(raw="x", normalized=1, display="x"),
                value_type=ValueType.STRING,
                confidence=0.9,
                parser_version="v1",
                parser_kind=ParserKind.DETERMINISTIC_REGEX,
            )
        )


def test_append_extracted_field_rejects_confidence_out_of_bounds():
    import uuid
    svc = _service_with_mocked_client()
    import asyncio
    with pytest.raises(EvidenceSubstrateError):
        asyncio.run(
            svc.append_extracted_field(
                document_id=uuid.uuid4(),
                field_name="sum_insured",
                value=ExtractedValue(raw="x", normalized=1, display="x"),
                value_type=ValueType.CURRENCY,
                confidence=1.5,  # out of [0,1]
                parser_version="v1",
                parser_kind=ParserKind.DETERMINISTIC_REGEX,
            )
        )


def test_link_field_evidence_rejects_empty_cite_string():
    import uuid
    svc = _service_with_mocked_client()
    import asyncio
    with pytest.raises(EvidenceSubstrateError):
        asyncio.run(
            svc.link_field_evidence(
                extracted_field_id=uuid.uuid4(),
                page_artifact_id=uuid.uuid4(),
                cite_string="",
            )
        )


# --- 6. read methods return typed Pydantic models ---

def test_get_field_citations_returns_empty_on_no_rows():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
    import uuid, asyncio
    result = asyncio.run(svc.get_field_citations(uuid.uuid4()))
    assert result == []


def test_get_field_citations_parses_pydantic_models():
    svc = _service_with_mocked_client()
    raw_row = {
        "document_id": "00000000-0000-0000-0000-000000000001",
        "field_name": "sum_insured",
        "value": {"raw": "5,00,000", "normalized": 500000, "display": "₹5,00,000"},
        "value_type": "currency",
        "field_confidence": 0.95,
        "parser_kind": "deterministic_regex",
        "cite_string": "page 4, paragraph 3",
        "evidence_strength": 1.0,
        "page_number": 4,
        "image_uri": "coverwise-documents/abc/pages/4.png",
        "page_sha256": "0" * 64,
    }
    svc._client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [raw_row]
    import uuid, asyncio
    result = asyncio.run(svc.get_field_citations(uuid.uuid4()))
    assert len(result) == 1
    cite = result[0]
    assert isinstance(cite, FieldCitation)
    assert cite.field_name == "sum_insured"
    assert cite.value.normalized == 500000
    assert cite.value.display == "₹5,00,000"
    assert cite.cite_string == "page 4, paragraph 3"
    assert cite.page_number == 4


def test_get_field_citations_filters_by_field_names():
    svc = _service_with_mocked_client()
    # Mock the chained .in_ call as well
    chain = MagicMock()
    chain.execute.return_value.data = []
    svc._client.table.return_value.select.return_value.eq.return_value.in_.return_value = chain
    import uuid, asyncio
    result = asyncio.run(
        svc.get_field_citations(uuid.uuid4(), field_names=["sum_insured"])
    )
    assert result == []
    # Verify .in_ was called with the field names filter
    svc._client.table.return_value.select.return_value.eq.return_value.in_.assert_called_once()


# --- 7. PageArtifact roundtrip ---

def test_page_artifact_parses_iso_datetime():
    """Pydantic must accept the Supabase-returned ISO datetime."""
    pa = PageArtifact.model_validate({
        "id": "00000000-0000-0000-0000-000000000001",
        "document_id": "00000000-0000-0000-0000-000000000002",
        "page_number": 1,
        "image_uri": "x.png",
        "ocr_text": None,
        "layout_json": None,
        "sha256": "abc",
        "created_at": "2026-07-18T10:00:00+00:00",
    })
    assert pa.page_number == 1
    assert pa.sha256 == "abc"
    assert pa.created_at.year == 2026
    assert pa.created_at.month == 7
    assert pa.created_at.day == 18
