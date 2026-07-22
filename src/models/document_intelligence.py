"""Canonical document-intelligence representation and deterministic routing hints.

The CIR is an in-memory, source-preserving projection of a processing run. It
does not replace the evidence substrate or the original uploaded artifact. It
gives every parser profile one stable shape for page/block/artifact lineage
before persistence and downstream extraction are expanded.
"""

from __future__ import annotations

import hashlib
import re
import unicodedata
from enum import Enum
from typing import Any, Iterable, Optional

from pydantic import BaseModel, Field


class DocumentCapability(str, Enum):
    """Capabilities observed or requested by the deterministic intake gate."""

    NATIVE_TEXT = "native_text"
    SCANNED_OCR = "scanned_ocr"
    IMAGE_ARTIFACT = "image_artifact"
    LAYOUT = "layout"
    TABLE = "table"
    FORM = "form"
    FORMULA = "formula"
    FIGURE = "figure"
    MULTILINGUAL = "multilingual"


class CIRNode(BaseModel):
    """One source-linked node in the canonical intermediate representation."""

    node_id: str = Field(min_length=1)
    node_type: str = Field(min_length=1)
    page_number: int = Field(ge=1)
    source_text: Optional[str] = None
    retrieval_text: Optional[str] = None
    bbox: Optional[dict[str, float]] = None
    reading_order: Optional[int] = Field(default=None, ge=0)
    parent_id: Optional[str] = None
    artifact_sha256: Optional[str] = Field(
        default=None,
        min_length=64,
        max_length=64,
        pattern=r"^[0-9a-f]{64}$",
    )
    confidence: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    parser_name: str = Field(min_length=1)
    parser_version: str = Field(min_length=1)
    evidence_reference: Optional[str] = None
    attributes: dict[str, Any] = Field(default_factory=dict)


class DocumentCIR(BaseModel):
    """Versioned source-preserving projection emitted by document processing."""

    schema_version: str = "cir.v1"
    document_id: Optional[str] = None
    filename: str = Field(min_length=1)
    source_artifact_sha256: str = Field(
        min_length=64,
        max_length=64,
        pattern=r"^[0-9a-f]{64}$",
    )
    parser_profile: str = Field(min_length=1)
    parser_version: str = Field(min_length=1)
    capabilities: list[DocumentCapability] = Field(default_factory=list)
    nodes: list[CIRNode] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


def sha256_bytes(content: bytes) -> str:
    """Return the immutable source hash used for parser lineage."""

    return hashlib.sha256(content).hexdigest()


_SENTENCE_END = re.compile(r"[.!?。！？](?=\s|$)")


def split_source_sentences(text: str) -> list[tuple[str, int, int]]:
    """Split source text conservatively while retaining exact offsets.

    This is a structural segmentation aid, not a language-understanding or
    sentence-accuracy claim. It only cuts at sentence punctuation followed by
    whitespace/end-of-input and keeps the original substring unchanged.
    Callers can therefore cite the parent source block even when specialist
    multilingual segmentation is later substituted.
    """

    sentences: list[tuple[str, int, int]] = []
    start = 0
    for match in _SENTENCE_END.finditer(text):
        end = match.end()
        candidate = text[start:end].strip()
        if candidate:
            segment = text[start:end]
            left = start + len(segment) - len(segment.lstrip())
            right = start + len(segment.rstrip())
            sentences.append((text[left:right], left, right))
        start = end

    tail = text[start:]
    candidate = tail.strip()
    if candidate:
        left = start + len(tail) - len(tail.lstrip())
        right = start + len(tail.rstrip())
        sentences.append((text[left:right], left, right))
    return sentences


def detect_script_families(texts: Iterable[str]) -> set[str]:
    """Observe Unicode script families present in source text.

    This is a routing signal only. It does not establish language identity,
    OCR accuracy, translation quality, or field-extraction correctness.
    """

    families: set[str] = set()
    for text in texts:
        for character in text:
            if not character.isalpha():
                continue
            name = unicodedata.name(character, "")
            family = next(
                (
                    candidate
                    for marker, candidate in (
                        ("LATIN", "latin"),
                        ("DEVANAGARI", "devanagari"),
                        ("ARABIC", "arabic"),
                        ("CYRILLIC", "cyrillic"),
                        ("HEBREW", "hebrew"),
                        ("GREEK", "greek"),
                        ("HIRAGANA", "japanese"),
                        ("KATAKANA", "japanese"),
                        ("HANGUL", "korean"),
                        ("CJK", "cjk"),
                    )
                    if marker in name
                ),
                "other",
            )
            families.add(family)
    return families


def classify_capabilities(
    *,
    file_type: str,
    page_texts: dict[int, str],
    page_numbers: Iterable[int],
    parser_profile: Optional[str] = None,
    native_text_pages: Optional[Iterable[int]] = None,
    ocr_pages: Optional[Iterable[int]] = None,
) -> list[DocumentCapability]:
    """Classify observable input capabilities without guessing semantics.

    This deliberately does not infer that a document contains a table, form,
    or formula from a keyword. Those capabilities require a parser observation
    or an explicit benchmark/profile request; false capability claims would
    route sensitive documents to the wrong extractor.
    """

    normalized_type = file_type.lower().lstrip(".")
    capabilities: list[DocumentCapability] = []
    has_pages = any(True for _ in page_numbers)
    has_text = any(bool(text and text.strip()) for text in page_texts.values())
    script_families = detect_script_families(page_texts.values())

    profile = (parser_profile or "").lower()
    is_ocr_profile = "ocr" in profile or "scan" in profile
    native_pages = set(native_text_pages or ())
    ocr_page_set = set(ocr_pages or ())
    has_native_text = bool(native_pages) if native_text_pages is not None else (
        has_text and not is_ocr_profile
    )
    has_ocr_text = bool(ocr_page_set) if ocr_pages is not None else (
        has_pages and (not has_text or is_ocr_profile)
    )
    if has_native_text:
        capabilities.append(DocumentCapability.NATIVE_TEXT)
    if has_ocr_text or (has_pages and not has_text):
        capabilities.append(DocumentCapability.SCANNED_OCR)
    if normalized_type in {"png", "jpg", "jpeg", "tiff", "tif", "bmp", "webp"}:
        capabilities.append(DocumentCapability.IMAGE_ARTIFACT)
    if normalized_type == "pdf" and has_pages:
        capabilities.append(DocumentCapability.LAYOUT)
    if len(script_families) > 1:
        capabilities.append(DocumentCapability.MULTILINGUAL)

    return capabilities


def build_document_cir(
    *,
    filename: str,
    source_artifact_sha256: str,
    file_type: str,
    page_texts: dict[int, str],
    page_images: Optional[dict[int, bytes]] = None,
    parser_profile: str,
    parser_version: str = "coverwise.document-intelligence.v1",
    document_id: Optional[str] = None,
    metadata: Optional[dict[str, Any]] = None,
    observed_nodes: Optional[list[CIRNode]] = None,
    native_text_pages: Optional[Iterable[int]] = None,
    ocr_pages: Optional[Iterable[int]] = None,
) -> DocumentCIR:
    """Build page and text-block nodes without destroying source bytes.

    Tables, figures, formulas, and form nodes can be added by specialist
    adapters later; this function intentionally emits only observations that
    the current canonical pipeline can prove.
    """

    image_map = page_images or {}
    page_numbers = sorted(set(page_texts) | set(image_map))
    capabilities = classify_capabilities(
        file_type=file_type,
        page_texts=page_texts,
        page_numbers=page_numbers,
        parser_profile=parser_profile,
        native_text_pages=native_text_pages,
        ocr_pages=ocr_pages,
    )
    nodes: list[CIRNode] = []

    for reading_order, page_number in enumerate(page_numbers):
        page_id = f"page-{page_number}"
        image_bytes = image_map.get(page_number)
        image_hash = sha256_bytes(image_bytes) if image_bytes else None
        nodes.append(
            CIRNode(
                node_id=page_id,
                node_type="page",
                page_number=page_number,
                artifact_sha256=image_hash,
                parser_name=parser_profile,
                parser_version=parser_version,
                reading_order=reading_order,
            )
        )
        page_text = page_texts.get(page_number, "")
        if page_text.strip():
            text_node_id = f"{page_id}-text"
            nodes.append(
                CIRNode(
                    node_id=text_node_id,
                    node_type="text_block",
                    page_number=page_number,
                    source_text=page_text,
                    retrieval_text=page_text,
                    parent_id=page_id,
                    artifact_sha256=image_hash,
                    parser_name=parser_profile,
                    parser_version=parser_version,
                    reading_order=reading_order,
                    attributes={"source": "page_text"},
                )
            )
            for sentence_index, (sentence, start, end) in enumerate(
                split_source_sentences(page_text)
            ):
                nodes.append(
                    CIRNode(
                        node_id=f"{page_id}-sentence-{sentence_index}",
                        node_type="sentence",
                        page_number=page_number,
                        source_text=sentence,
                        retrieval_text=sentence,
                        parent_id=text_node_id,
                        artifact_sha256=image_hash,
                        reading_order=reading_order + sentence_index + 1,
                        parser_name=parser_profile,
                        parser_version=parser_version,
                        attributes={
                            "source": "conservative_sentence_segmenter",
                            "char_start": start,
                            "char_end": end,
                            "segmentation_status": "structural_only",
                        },
                    )
                )

    observed = observed_nodes or []
    observed_capabilities = {
        "table": DocumentCapability.TABLE,
        "table_cell": DocumentCapability.TABLE,
        "form": DocumentCapability.FORM,
        "form_field": DocumentCapability.FORM,
        "formula": DocumentCapability.FORMULA,
        "figure": DocumentCapability.FIGURE,
    }
    for node in observed:
        capability = observed_capabilities.get(node.node_type)
        if capability and capability not in capabilities:
            capabilities.append(capability)
    nodes.extend(observed)

    cir_metadata = dict(metadata or {})
    script_families = sorted(detect_script_families(page_texts.values()))
    if script_families:
        cir_metadata["observed_script_families"] = script_families
        cir_metadata["script_detection"] = "unicode_name_observation.v1"

    return DocumentCIR(
        document_id=document_id,
        filename=filename,
        source_artifact_sha256=source_artifact_sha256,
        parser_profile=parser_profile,
        parser_version=parser_version,
        capabilities=capabilities,
        nodes=nodes,
        metadata=cir_metadata,
    )
