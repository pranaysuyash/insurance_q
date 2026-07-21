import asyncio
from pathlib import Path

from src.services.document_processing_service import DocumentProcessingService


def test_processing_copy_is_ephemeral_and_not_storage_documents(tmp_path, monkeypatch):
    temp_dir = tmp_path / "processing"
    monkeypatch.setenv("PROCESSING_TEMP_DIR", str(temp_dir))
    service = DocumentProcessingService()
    path = asyncio.run(service._save_file(b"payload", "policy.pdf", "doc-1"))
    assert Path(path).read_bytes() == b"payload"
    assert str(tmp_path / "storage" / "documents") not in path
    service._cleanup_temp_file(path)
    assert not Path(path).exists()
