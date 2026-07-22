import pytest
from pydantic import ValidationError

from src.models.document_intelligence import (
    DocumentCapability,
    CIRNode,
    build_document_cir,
    classify_capabilities,
    sha256_bytes,
)


def test_cir_preserves_page_order_text_and_image_lineage():
    source_hash = sha256_bytes(b"policy")
    cir = build_document_cir(
        filename="policy.pdf",
        source_artifact_sha256=source_hash,
        file_type=".pdf",
        page_texts={2: "second page", 1: "first page"},
        page_images={1: b"page-one-image"},
        parser_profile="native_pdf_text",
    )

    assert cir.schema_version == "cir.v1"
    assert cir.source_artifact_sha256 == source_hash
    assert cir.capabilities == [DocumentCapability.NATIVE_TEXT, DocumentCapability.LAYOUT]
    assert [node.node_id for node in cir.nodes] == [
        "page-1",
        "page-1-text",
        "page-1-sentence-0",
        "page-2",
        "page-2-text",
        "page-2-sentence-0",
    ]
    assert cir.nodes[1].source_text == "first page"
    assert cir.nodes[1].retrieval_text == "first page"
    assert cir.nodes[0].artifact_sha256 == sha256_bytes(b"page-one-image")
    assert cir.nodes[2].artifact_sha256 == cir.nodes[0].artifact_sha256


def test_capability_classifier_does_not_infer_unobserved_specialist_features():
    capabilities = classify_capabilities(
        file_type="pdf",
        page_texts={1: "Coverage table and formula language"},
        page_numbers=[1],
    )

    assert DocumentCapability.NATIVE_TEXT in capabilities
    assert DocumentCapability.LAYOUT in capabilities
    assert DocumentCapability.TABLE not in capabilities
    assert DocumentCapability.FORMULA not in capabilities
    assert DocumentCapability.FORM not in capabilities


def test_cir_rejects_malformed_source_hash():
    with pytest.raises(ValidationError):
        build_document_cir(
            filename="policy.pdf",
            source_artifact_sha256="x" * 64,
            file_type="pdf",
            page_texts={1: "Policy"},
            parser_profile="pymupdf_native",
        )


def test_cir_rejects_malformed_page_artifact_hash():
    with pytest.raises(ValidationError):
        CIRNode(
            node_id="page-1",
            node_type="page",
            page_number=1,
            artifact_sha256="X" * 64,
            parser_name="pymupdf_native",
            parser_version="v1",
        )
