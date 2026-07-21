"""Tests for the canonical document-intelligence runtime and CIR contract."""

from __future__ import annotations

import subprocess
import sys
from unittest.mock import AsyncMock, MagicMock
from unittest.mock import patch

from src.models.document_intelligence import (
    DocumentCapability,
    build_document_cir,
    sha256_bytes,
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
    assert [node.node_id for node in cir.nodes] == ["page-1", "page-1-text", "page-2"]
    text_node = cir.nodes[1]
    assert text_node.source_text == "Policy Number: POL-001"
    assert text_node.retrieval_text == text_node.source_text
    assert text_node.parent_id == "page-1"
    assert text_node.artifact_sha256 == sha256_bytes(page_image)


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


def test_page_artifact_persistence_keeps_cir_layout_metadata(monkeypatch):
    import asyncio

    from src.services.document_processing_service import DocumentProcessingService

    class FakeSubstrate:
        def __init__(self):
            self.layout_json = None

        async def append_page_artifact(self, **kwargs):
            self.layout_json = kwargs["layout_json"]
            return "00000000-0000-0000-0000-000000000001"

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
    ]
