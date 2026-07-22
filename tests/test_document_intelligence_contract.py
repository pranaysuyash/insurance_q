"""Tests for the canonical document-intelligence runtime and CIR contract."""

from __future__ import annotations

import subprocess
import sys
from unittest.mock import AsyncMock, MagicMock
from unittest.mock import patch

import pytest

from src.models.document_intelligence import (
    CIRNode,
    DocumentCapability,
    build_document_cir,
    detect_script_families,
    sha256_bytes,
    split_source_sentences,
)


def test_cir_preserves_source_and_page_artifact_lineage():
    source = b"policy-source"
    page_image = b"page-image"

    cir = build_document_cir(
        filename="policy.pdf",
        source_artifact_sha256=sha256_bytes(source),
        file_type="pdf",
        page_texts={1: "Policy Number: POL-001", 2: ""},
        page_images={1: page_image, 2: b"blank-page"},
        parser_profile="native_pdf_text",
    )

    assert cir.schema_version == "cir.v1"
    assert cir.source_artifact_sha256 == sha256_bytes(source)
    assert DocumentCapability.NATIVE_TEXT in cir.capabilities
    assert DocumentCapability.LAYOUT in cir.capabilities
    assert [node.node_id for node in cir.nodes] == [
        "page-1",
        "page-1-text",
        "page-1-sentence-0",
        "page-2",
    ]
    text_node = cir.nodes[1]
    assert text_node.source_text == "Policy Number: POL-001"
    assert text_node.retrieval_text == text_node.source_text
    assert text_node.parent_id == "page-1"
    assert text_node.artifact_sha256 == sha256_bytes(page_image)
    sentence_node = cir.nodes[2]
    assert sentence_node.node_type == "sentence"
    assert sentence_node.parent_id == "page-1-text"
    assert sentence_node.source_text == "Policy Number: POL-001"
    assert sentence_node.attributes["char_start"] == 0
    assert sentence_node.attributes["char_end"] == len("Policy Number: POL-001")


def test_sentence_segmentation_preserves_exact_substrings_and_offsets():
    source = "First sentence. Second sentence!\nThird clause."

    segments = split_source_sentences(source)

    assert [segment[0] for segment in segments] == [
        "First sentence.",
        "Second sentence!",
        "Third clause.",
    ]
    assert all(source[start:end] == sentence for sentence, start, end in segments)


def test_multilingual_signal_observes_scripts_without_claiming_accuracy():
    assert detect_script_families(["Policy हिंदी"]) == {"devanagari", "latin"}

    cir = build_document_cir(
        filename="bilingual.pdf",
        source_artifact_sha256=sha256_bytes(b"bilingual"),
        file_type="pdf",
        page_texts={1: "Policy हिंदी"},
        parser_profile="native_pdf_text",
    )

    assert DocumentCapability.MULTILINGUAL in cir.capabilities
    assert cir.metadata["observed_script_families"] == ["devanagari", "latin"]
    assert cir.metadata["script_detection"] == "unicode_name_observation.v1"


def test_scan_without_text_is_marked_for_ocr_not_semantic_guessing():
    cir = build_document_cir(
        filename="scan.png",
        source_artifact_sha256=sha256_bytes(b"scan"),
        file_type="png",
        page_texts={},
        page_images={1: b"scan-page"},
        parser_profile="intake_quality_gate",
    )

    assert DocumentCapability.SCANNED_OCR in cir.capabilities
    assert DocumentCapability.IMAGE_ARTIFACT in cir.capabilities
    assert DocumentCapability.NATIVE_TEXT not in cir.capabilities
    assert all(node.node_type != "table" for node in cir.nodes)


def test_ocr_profile_is_not_mislabeled_as_native_text():
    cir = build_document_cir(
        filename="scan.pdf",
        source_artifact_sha256=sha256_bytes(b"scan-pdf"),
        file_type="pdf",
        page_texts={1: "Recovered OCR text"},
        page_images={1: b"scan-page"},
        parser_profile="local_doctr_ocr",
    )

    assert DocumentCapability.SCANNED_OCR in cir.capabilities
    assert DocumentCapability.NATIVE_TEXT not in cir.capabilities


def test_mixed_native_and_ocr_pages_preserve_both_capabilities():
    cir = build_document_cir(
        filename="mixed-pages.pdf",
        source_artifact_sha256=sha256_bytes(b"mixed-pages"),
        file_type="pdf",
        page_texts={1: "Native page", 2: "OCR page"},
        page_images={1: b"page-1", 2: b"page-2"},
        parser_profile="mixed_native_doctr_ocr",
        native_text_pages={1},
        ocr_pages={2},
    )

    assert DocumentCapability.NATIVE_TEXT in cir.capabilities
    assert DocumentCapability.SCANNED_OCR in cir.capabilities


def test_cir_promotes_observed_specialist_nodes_to_capabilities():
    observed = [
        CIRNode(
            node_id="table-1",
            node_type="table",
            page_number=1,
            parser_name="pymupdf_native",
            parser_version="pymupdf-native.v1",
        ),
        CIRNode(
            node_id="figure-1",
            node_type="figure",
            page_number=1,
            parser_name="pymupdf_native",
            parser_version="pymupdf-native.v1",
        ),
    ]
    cir = build_document_cir(
        filename="mixed.pdf",
        source_artifact_sha256=sha256_bytes(b"mixed"),
        file_type="pdf",
        page_texts={1: "native text"},
        parser_profile="native_pdf_text",
        observed_nodes=observed,
    )

    assert DocumentCapability.TABLE in cir.capabilities
    assert DocumentCapability.FIGURE in cir.capabilities


def test_ocr_module_import_does_not_require_doctr_at_module_import_time():
    """A slim API image can import the module before a scan needs OCR."""

    script = (
        "import builtins; "
        "real_import = builtins.__import__; "
        "builtins.__import__ = lambda name, *a, **k: (_ for _ in ()).throw(ImportError('blocked doctr')) if name == 'doctr' or name.startswith('doctr.') else real_import(name, *a, **k); "
        "import src.ocr.pipeline; print('module-imported')"
    )
    result = subprocess.run(
        [sys.executable, "-c", script],
        check=True,
        capture_output=True,
        text=True,
    )
    assert "module-imported" in result.stdout


def test_rag_only_mode_does_not_require_an_ocr_result():
    import asyncio

    from src.services.document_processing_service import DocumentProcessingService

    service = DocumentProcessingService(rag_pipeline=MagicMock())
    service._save_file = AsyncMock(return_value="/tmp/rag-only-placeholder.txt")
    service._cleanup_temp_file = MagicMock()
    service._ingest_into_rag = AsyncMock(
        return_value={"status": "completed", "text_blocks_count": 1}
    )

    result = asyncio.run(
        service.process_document_full(
            b"source",
            "policy.txt",
            processing_mode="rag_only",
        )
    )

    assert result["stages"]["rag_ingestion"]["status"] == "completed"
    service._ingest_into_rag.assert_awaited_once()


@pytest.mark.asyncio
async def test_text_fallback_rejects_unsupported_structured_formats(tmp_path):
    from src.services.document_processing_service import DocumentProcessingService

    source = tmp_path / "policy.xlsx"
    source.write_bytes(b"PK\x03\x04\x14\x00binary-office-content")

    result = await DocumentProcessingService()._extract_text(str(source), source.name)

    assert result["status"] == "failed"
    assert result["error_code"] == "unsupported_file_type"
    assert result["full_text"] == ""


@pytest.mark.asyncio
async def test_text_fallback_rejects_binary_content_and_invalid_utf8(tmp_path):
    from src.services.document_processing_service import DocumentProcessingService

    binary_source = tmp_path / "policy.txt"
    binary_source.write_bytes(b"policy\x00binary")
    invalid_source = tmp_path / "policy.csv"
    invalid_source.write_bytes(b"policy\xffvalue")
    service = DocumentProcessingService()

    binary_result = await service._extract_text(str(binary_source), binary_source.name)
    invalid_result = await service._extract_text(str(invalid_source), invalid_source.name)

    assert binary_result["error_code"] == "binary_content"
    assert invalid_result["error_code"] == "text_unreadable"


@pytest.mark.asyncio
async def test_text_fallback_preserves_supported_utf8_text(tmp_path):
    from src.services.document_processing_service import DocumentProcessingService

    source = tmp_path / "policy.txt"
    source.write_text("Policy Number: TXT-001\nInsurer: TestCorp", encoding="utf-8")

    result = await DocumentProcessingService()._extract_text(str(source), source.name)

    assert result["status"] == "completed"
    assert result["method"] == "text_fallback"
    assert "TXT-001" in result["full_text"]


def test_page_artifact_persistence_keeps_cir_layout_metadata(monkeypatch):
    import asyncio

    from src.services.document_processing_service import DocumentProcessingService

    class FakeSubstrate:
        def __init__(self):
            self.layout_json = None
            self.source_spans = []

        async def append_page_artifact(self, **kwargs):
            self.layout_json = kwargs["layout_json"]
            return "00000000-0000-0000-0000-000000000001"

        async def append_source_spans(self, page_artifact_id, spans):
            self.source_spans.extend(spans)
            return ["00000000-0000-0000-0000-000000000002" for _ in spans]

    fake_substrate = FakeSubstrate()
    rag = MagicMock()
    rag.ingest_document_data = AsyncMock(return_value={"status": "completed"})
    service = DocumentProcessingService(rag_pipeline=rag)
    service._extract_entity_blocks = AsyncMock(return_value=[])
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "service-key")

    cir = build_document_cir(
        filename="policy.pdf",
        source_artifact_sha256=sha256_bytes(b"source"),
        file_type="pdf",
        page_texts={1: "Policy Number: POL-001"},
        page_images={1: b"page"},
        parser_profile="native_pdf_text",
    ).model_dump(mode="json")

    with patch(
        "src.services.evidence_substrate_service.EvidenceSubstrateService.from_env",
        return_value=fake_substrate,
    ):
        result = asyncio.run(
            service._ingest_into_rag(
                "00000000-0000-0000-0000-000000000001",
                "Policy Number: POL-001",
                "policy.pdf",
                owner_id="owner-1",
                page_texts={1: "Policy Number: POL-001"},
                page_images={1: b"page"},
                cir=cir,
            )
        )

    assert result["status"] == "completed"
    assert fake_substrate.layout_json["schema_version"] == "cir.v1"
    assert fake_substrate.layout_json["parser_profile"] == "native_pdf_text"
    assert [node["node_id"] for node in fake_substrate.layout_json["nodes"]] == [
        "page-1",
        "page-1-text",
        "page-1-sentence-0",
    ]
    assert fake_substrate.source_spans == []


def test_page_artifact_persistence_writes_only_bounded_source_spans(monkeypatch):
    import asyncio

    from src.services.document_processing_service import DocumentProcessingService

    class FakeSubstrate:
        def __init__(self):
            self.source_spans = []

        async def append_page_artifact(self, **kwargs):
            return "00000000-0000-0000-0000-000000000001"

        async def append_source_spans(self, page_artifact_id, spans):
            self.source_spans.extend(spans)
            return ["00000000-0000-0000-0000-000000000002" for _ in spans]

    fake_substrate = FakeSubstrate()
    rag = MagicMock()
    rag.ingest_document_data = AsyncMock(return_value={"status": "completed"})
    service = DocumentProcessingService(rag_pipeline=rag)
    service._extract_entity_blocks = AsyncMock(return_value=[])
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "service-key")

    cir = build_document_cir(
        filename="policy.pdf",
        source_artifact_sha256=sha256_bytes(b"source"),
        file_type="pdf",
        page_texts={1: "Policy Number: POL-001"},
        page_images={1: b"page"},
        parser_profile="native_pdf_text",
        observed_nodes=[
            CIRNode(
                node_id="page-1-layout-0",
                node_type="layout_block",
                page_number=1,
                source_text="Policy Number: POL-001",
                bbox={"x": 1, "y": 2, "w": 100, "h": 12, "page_w": 612, "page_h": 792},
                parser_name="pymupdf_native",
                parser_version="pymupdf-native.v1",
            ),
            CIRNode(
                node_id="page-1-table-0-cell-0-0",
                node_type="table_cell",
                page_number=1,
                source_text="POL-001",
                bbox={"x": 1, "y": 20, "w": 50, "h": 12, "page_w": 612, "page_h": 792},
                confidence=0.0,
                parser_name="pymupdf_native",
                parser_version="pymupdf-native.v1",
            ),
        ],
    ).model_dump(mode="json")

    with patch(
        "src.services.evidence_substrate_service.EvidenceSubstrateService.from_env",
        return_value=fake_substrate,
    ):
        asyncio.run(
            service._ingest_into_rag(
                "00000000-0000-0000-0000-000000000001",
                "Policy Number: POL-001",
                "policy.pdf",
                owner_id="owner-1",
                page_texts={1: "Policy Number: POL-001"},
                page_images={1: b"page"},
                cir=cir,
            )
        )

    assert [span.span_text for span in fake_substrate.source_spans] == [
        "Policy Number: POL-001",
        "POL-001",
    ]
    assert [span.span_type.value for span in fake_substrate.source_spans] == [
        "text_block",
        "table_cell",
    ]
    assert fake_substrate.source_spans[1].confidence == 0.0
