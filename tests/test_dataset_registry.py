import asyncio
from unittest.mock import MagicMock
from uuid import UUID, uuid4

import pytest

from src.services.dataset_registry import DatasetRegistry, DatasetRegistryError


def _registry():
    client = MagicMock()
    client.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
        {"status": "draft", "purpose": "evaluation"}
    ]
    return DatasetRegistry("", "", client=client), client


def test_customer_item_requires_consent_reference():
    registry, _ = _registry()
    with pytest.raises(DatasetRegistryError, match="consent_record_id"):
        asyncio.run(registry.add_item(uuid4(), "question", "manual review", owner_id="user-1"))


def test_release_and_item_are_typed_and_purpose_bound():
    registry, client = _registry()
    client.table.return_value.insert.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    release_id = asyncio.run(registry.create_release("gold", "v1", "evaluation", "operator-1"))
    item_id = asyncio.run(registry.add_item(
        release_id,
        "What is covered?",
        "operator-authored benchmark",
        expected_answer="Hospitalization",
    ))
    assert isinstance(release_id, UUID)
    assert isinstance(item_id, UUID)


def test_invalid_purpose_is_rejected():
    registry, _ = _registry()
    with pytest.raises(DatasetRegistryError, match="invalid dataset purpose"):
        asyncio.run(registry.create_release("gold", "v1", "production", "operator-1"))


def test_approved_release_rejects_new_items():
    registry, client = _registry()
    client.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
        {"status": "approved", "purpose": "evaluation"}
    ]
    with pytest.raises(DatasetRegistryError, match="draft releases"):
        asyncio.run(registry.add_item(uuid4(), "What is covered?", "approved benchmark"))


def test_revoke_release_persists_reason():
    registry, client = _registry()
    client.table.return_value.update.return_value.in_.return_value.select.return_value.execute.return_value.data = [
        {"id": str(uuid4())}
    ]

    asyncio.run(registry.revoke_release(uuid4(), "customer withdrawal"))

    payload = client.table.return_value.update.call_args.args[0]
    assert payload["status"] == "revoked"
    assert payload["revoked_reason"] == "customer withdrawal"
