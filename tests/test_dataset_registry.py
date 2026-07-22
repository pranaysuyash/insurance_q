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


@pytest.mark.parametrize(
    "kwargs",
    [
        {"source_document_id": str(uuid4())},
        {"owner_id": "user-1", "source_document_id": str(uuid4())},
        {"source_chunk_id": 17},
    ],
)
def test_source_linkage_requires_complete_consent_and_document_identity(kwargs):
    registry, _ = _registry()
    with pytest.raises(DatasetRegistryError):
        asyncio.run(registry.add_item(uuid4(), "question", "manual review", **kwargs))


def test_source_linkage_binds_document_and_consent_to_owner():
    client = MagicMock()
    registry = DatasetRegistry("", "", client=client)
    release_id = uuid4()
    client.table.side_effect = lambda name: {
        "dataset_releases": _table_with_rows([{
            "status": "draft",
            "purpose": "evaluation",
            "consent_policy_version": "eval-v1",
        }]),
        "documents": _table_with_rows([{"owner_id": "owner-1"}]),
        "v_current_consent": _table_with_rows([{
            "id": "consent-1",
            "user_id": "owner-1",
            "consent_type": "evaluation_dataset",
            "granted": True,
            "policy_version": "eval-v1",
        }]),
        "dataset_items": _table_with_rows([{"id": str(uuid4())}]),
    }[name]

    item_id = asyncio.run(registry.add_item(
        release_id,
        "What is covered?",
        "consented review",
        owner_id="owner-1",
        source_document_id=str(uuid4()),
        consent_record_id="consent-1",
    ))
    assert isinstance(item_id, UUID)


def test_customer_item_requires_current_purpose_bound_consent():
    client = MagicMock()
    registry = DatasetRegistry("", "", client=client)
    client.table.side_effect = lambda name: {
        "dataset_releases": _table_with_rows([{
            "status": "draft",
            "purpose": "evaluation",
            "consent_policy_version": "eval-v1",
        }]),
        "documents": _table_with_rows([{"owner_id": "owner-1"}]),
        "v_current_consent": _table_with_rows([{
            "id": "old-consent",
            "user_id": "owner-1",
            "consent_type": "document_processing",
            "granted": True,
            "policy_version": "processing-v1",
        }]),
    }[name]

    with pytest.raises(DatasetRegistryError, match="current consent"):
        asyncio.run(registry.add_item(
            uuid4(),
            "What is covered?",
            "consented evaluation",
            owner_id="owner-1",
            source_document_id=str(uuid4()),
            consent_record_id="old-consent",
        ))


def test_customer_item_requires_release_consent_policy_version():
    client = MagicMock()
    registry = DatasetRegistry("", "", client=client)
    client.table.side_effect = lambda name: {
        "dataset_releases": _table_with_rows([{
            "status": "draft",
            "purpose": "evaluation",
            "consent_policy_version": None,
        }]),
    }[name]

    with pytest.raises(DatasetRegistryError, match="consent_policy_version"):
        asyncio.run(registry.add_item(
            uuid4(),
            "What is covered?",
            "consented evaluation",
            owner_id="owner-1",
            consent_record_id="consent-1",
        ))


def _table_with_rows(rows):
    table = MagicMock()
    table.select.return_value = table
    table.eq.return_value = table
    table.limit.return_value = table
    table.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = rows
    table.insert.return_value.execute.return_value.data = rows
    return table


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


def test_materialize_manifest_requires_approval_and_hashes_active_items():
    registry, client = _registry()
    client.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
        {"id": "r1", "name": "gold", "version": "v1", "purpose": "evaluation", "status": "approved", "manifest_hash": None}
    ]
    client.table.return_value.select.return_value.eq.return_value.eq.return_value.order.return_value.execute.return_value.data = [
        {"id": "i1", "prompt": "Q", "expected_answer": "A", "expected_citations": [], "source_snapshot": {}, "source_document_id": None, "source_chunk_id": None}
    ]
    manifest = asyncio.run(registry.materialize_manifest(uuid4()))
    assert manifest["items"][0]["prompt"] == "Q"
    assert len(manifest["manifest_hash"]) == 64
