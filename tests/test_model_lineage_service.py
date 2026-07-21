import asyncio
from unittest.mock import MagicMock
from uuid import uuid4

import pytest

from src.services.model_lineage_service import ModelLineageError, ModelLineageService


def test_model_run_requires_approved_release():
    client = MagicMock()
    client.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
        {"status": "draft", "purpose": "training"}
    ]
    service = ModelLineageService("", "", client=client)
    with pytest.raises(ModelLineageError, match="approved"):
        asyncio.run(service.start_run(uuid4(), "training", "openai", "model", {}, "operator"))


def test_artifact_checksum_is_recorded():
    client = MagicMock()
    client.table.return_value.upsert.return_value.execute.return_value.data = [
        {"id": str(uuid4())}
    ]
    service = ModelLineageService("", "", client=client)
    artifact_id = asyncio.run(service.record_artifact(uuid4(), "manifest", "supabase://artifact", b"abc"))
    assert artifact_id
    row = client.table.return_value.upsert.call_args.args[0]
    assert row["byte_size"] == 3
    assert row["checksum_sha256"].startswith("ba7816bf")
