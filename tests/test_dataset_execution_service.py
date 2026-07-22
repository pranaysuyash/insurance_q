import asyncio
import hashlib
from unittest.mock import MagicMock, AsyncMock
from uuid import uuid4

import pytest

from src.services.dataset_execution_service import DatasetExecutionService


def test_evaluation_records_hash_only_results_and_metrics():
    client = MagicMock()
    registry = MagicMock()
    lineage = MagicMock()
    release_id = uuid4()
    run_id = uuid4()
    registry.materialize_manifest = AsyncMock(return_value={
        "manifest_hash": "m" * 64,
        "items": [{"id": str(uuid4()), "prompt": "Q", "expected_answer": "A"}],
    })
    lineage.start_run = AsyncMock(return_value=run_id)
    lineage.record_artifact = AsyncMock()
    lineage.finish_run = AsyncMock()
    service = DatasetExecutionService(registry, lineage, client=client)

    async def evaluator(item):
        return {
            "status": "passed", "score": 1, "output": "private answer",
            "metrics": {"latency_ms": 12, "label": "ok"},
        }

    result = asyncio.run(service.execute_evaluation(
        release_id,
        provider="test",
        model_name="evaluator",
        config={"temperature": 0},
        created_by="operator",
        evaluator=evaluator,
    ))

    assert result["passed"] == 1
    payload = client.table.return_value.upsert.call_args.args[0]
    assert payload["output_hash"]
    assert "private answer" not in str(payload)
    assert payload["metrics"] == {"latency_ms": 12, "label": "ok"}
    lineage.finish_run.assert_awaited_once()


def test_manifest_artifact_failure_finalizes_run_as_failed():
    client = MagicMock()
    registry = MagicMock()
    lineage = MagicMock()
    release_id = uuid4()
    run_id = uuid4()
    registry.materialize_manifest = AsyncMock(return_value={
        "manifest_hash": "m" * 64,
        "items": [],
    })
    lineage.start_run = AsyncMock(return_value=run_id)
    lineage.record_artifact = AsyncMock(
        side_effect=RuntimeError("artifact store unavailable")
    )
    lineage.finish_run = AsyncMock()
    service = DatasetExecutionService(registry, lineage, client=client)

    async def evaluator(_item):
        return {"status": "passed", "score": 1}

    with pytest.raises(RuntimeError, match="artifact store unavailable"):
        asyncio.run(service.execute_evaluation(
            release_id,
            provider="test",
            model_name="evaluator",
            config={},
            created_by="operator",
            evaluator=evaluator,
        ))

    lineage.finish_run.assert_awaited_once_with(
        run_id, "failed", {"error_class": "RuntimeError"}
    )


def test_invalid_output_hash_is_recorded_as_error_without_persisting_raw_value():
    client = MagicMock()
    registry = MagicMock()
    lineage = MagicMock()
    release_id = uuid4()
    run_id = uuid4()
    item_id = str(uuid4())
    registry.materialize_manifest = AsyncMock(return_value={
        "manifest_hash": "m" * 64,
        "items": [{"id": item_id, "prompt": "Q"}],
    })
    lineage.start_run = AsyncMock(return_value=run_id)
    lineage.record_artifact = AsyncMock()
    lineage.finish_run = AsyncMock()
    service = DatasetExecutionService(registry, lineage, client=client)

    async def evaluator(_item):
        return {"status": "passed", "output_hash": "raw private answer"}

    result = asyncio.run(service.execute_evaluation(
        release_id,
        provider="test",
        model_name="evaluator",
        config={},
        created_by="operator",
        evaluator=evaluator,
    ))

    assert result["errors"] == 1
    payloads = [call.args[0] for call in client.table.return_value.upsert.call_args_list]
    assert payloads[-1]["status"] == "error"
    assert payloads[-1]["error_class"] == "DatasetExecutionError"
    assert all("raw private answer" not in str(payload) for payload in payloads)


def test_output_hash_must_match_present_output():
    client = MagicMock()
    registry = MagicMock()
    lineage = MagicMock()
    release_id = uuid4()
    run_id = uuid4()
    item_id = str(uuid4())
    registry.materialize_manifest = AsyncMock(return_value={
        "manifest_hash": "m" * 64,
        "items": [{"id": item_id, "prompt": "Q"}],
    })
    lineage.start_run = AsyncMock(return_value=run_id)
    lineage.record_artifact = AsyncMock()
    lineage.finish_run = AsyncMock()
    service = DatasetExecutionService(registry, lineage, client=client)

    async def evaluator(_item):
        return {
            "status": "passed",
            "output": {"answer": "stable"},
            "output_hash": "0" * 64,
        }

    result = asyncio.run(service.execute_evaluation(
        release_id,
        provider="test",
        model_name="evaluator",
        config={},
        created_by="operator",
        evaluator=evaluator,
    ))

    assert result["errors"] == 1
    payloads = [call.args[0] for call in client.table.return_value.upsert.call_args_list]
    assert payloads[-1]["error_class"] == "DatasetExecutionError"


def test_structured_output_hash_is_canonical():
    from src.services.dataset_execution_service import _output_hash

    first = {"output": {"b": 2, "a": 1}}
    second = {"output": {"a": 1, "b": 2}}
    assert _output_hash(first) == _output_hash(second)
    assert _output_hash(first) == hashlib.sha256(
        b'{"a":1,"b":2}'
    ).hexdigest()
