"""Typed models for the evidence substrate (Trust Phase 1).

The substrate is the source of truth for everything claim-shaped in
CoverWise. This module defines the value-object types that flow
through evidence_substrate_service.py and into the policy detail
view. Every value here is what the user can see, what the API can
return, and what the SQL schema can store. The three layers
(raw, normalized, display) are kept distinct on purpose: conflating
them is the root cause of citation lies in the previous version.
"""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator


class SpanType(str, Enum):
    TEXT_BLOCK = "text_block"
    SENTENCE = "sentence"
    PARAGRAPH = "paragraph"
    HEADING = "heading"
    LINE = "line"
    WORD = "word"
    TABLE_CELL = "table_cell"
    TABLE = "table"
    FORMULA = "formula"
    FORM_FIELD = "form_field"
    CAPTION = "caption"
    ANNOTATION = "annotation"
    HEADER = "header"
    FOOTER = "footer"
    LIST_ITEM = "list_item"
    OTHER = "other"


class ValueType(str, Enum):
    STRING = "string"
    NUMBER = "number"
    DATE = "date"
    CURRENCY = "currency"
    ENUM = "enum"
    CLAUSE_TEXT = "clause_text"


class ParserKind(str, Enum):
    DETERMINISTIC_REGEX = "deterministic_regex"
    DETERMINISTIC_LOOKUP = "deterministic_lookup"
    LLM_EXTRACT = "llm_extract"


class ExtractedValue(BaseModel):
    """The three-layer value wrapper for an extracted field.

    raw:        the exact text the parser saw, byte-for-byte.
    normalized: the parsed, typed value. e.g. for a currency, the
                number in the smallest unit (paise for INR). For a
                date, the ISO 8601 string. The UI never shows this
                directly; it shows display.
    display:    the human-readable string the UI shows. e.g. for a
                currency, "₹5,00,000". For a date, "15 Aug 2025".

    The three are kept distinct because the raw text is the
    citation, the normalized value is what code reasons about, and
    the display string is what the user sees. Conflating them is
    the source of the "AI made up a number" failure mode.
    """

    raw: str = Field(min_length=1)
    normalized: Any
    display: str = Field(min_length=1)


class SourceSpan(BaseModel):
    """A logical region within a page, as produced by the layout
    parser. bbox_json is the page-relative bounding box in PDF
    points: {x, y, w, h, page_w, page_h}. A future renderer can
    overlay a highlight on the page image using these coords.
    """

    span_text: str = Field(min_length=1)
    bbox_json: dict
    span_type: SpanType
    confidence: float = Field(ge=0.0, le=1.0)
    parser_version: str = Field(min_length=1)

    @field_validator("bbox_json")
    @classmethod
    def _bbox_must_have_keys(cls, v: dict) -> dict:
        for key in ("x", "y", "w", "h", "page_w", "page_h"):
            if key not in v:
                raise ValueError(f"bbox_json missing required key: {key}")
        return v


class FieldCitation(BaseModel):
    """The shape of a row from v_field_citations. Returned to the
    policy detail screen in one query. The UI never joins this
    shape; it renders it as-is."""

    document_id: str
    field_name: str
    value: ExtractedValue
    value_type: ValueType
    field_confidence: float = Field(ge=0.0, le=1.0)
    parser_kind: ParserKind
    cite_string: str
    evidence_strength: float = Field(ge=0.0, le=1.0)
    page_number: int = Field(ge=1)
    image_uri: str
    page_sha256: str


class ExtractionCostRecord(BaseModel):
    """One row in evidence_extraction_costs. LLM calls write one
    of these per extracted_field; deterministic calls write one
    with cost_usd=0."""

    document_id: str
    extracted_field_id: Optional[str] = None
    parser_kind: ParserKind
    model: Optional[str] = None
    prompt_tokens: Optional[int] = None
    completion_tokens: Optional[int] = None
    cost_usd: Optional[float] = None


class PageArtifact(BaseModel):
    """Returned by get_page_artifact and get_page_artifacts_for_document.
    Mirrors the public.page_artifacts table."""

    id: str
    document_id: str
    page_number: int
    image_uri: str
    ocr_text: Optional[str] = None
    layout_json: Optional[dict] = None
    sha256: str
    created_at: datetime


class SourceSpanRecord(BaseModel):
    """Returned by get_source_spans_for_page. Mirrors public.source_spans."""

    id: str
    page_artifact_id: str
    span_text: str
    bbox_json: dict
    span_type: SpanType
    confidence: float
    parser_version: str
    created_at: datetime


class ExtractedFieldRecord(BaseModel):
    """Returned by get_extracted_fields_for_document. Mirrors
    public.extracted_fields."""

    id: str
    document_id: str
    field_name: str
    value: ExtractedValue
    value_type: ValueType
    confidence: float
    parser_version: str
    parser_kind: ParserKind
    created_at: datetime
