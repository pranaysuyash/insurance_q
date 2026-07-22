from types import SimpleNamespace

from src.services.policy_slot_reservation_service import (
    PolicySlotReservationService,
    production_policy_slot_reservations_enabled,
)


class _Client:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.calls = []

    def rpc(self, name, params):
        self.calls.append((name, params))
        response = next(self.responses)
        return SimpleNamespace(execute=lambda: SimpleNamespace(data=response))


def test_reservation_adapter_requires_an_explicit_rpc_decision():
    client = _Client([{"allowed": True, "reservation_id": "r-1"}])
    service = PolicySlotReservationService(client)

    result = service.reserve(owner_id="owner-1", source_hash="hash-1")

    assert result["allowed"] is True
    assert client.calls == [
        (
            "reserve_policy_upload_slot",
            {"p_owner_id": "owner-1", "p_source_hash": "hash-1"},
        )
    ]


def test_reservation_finalize_and_release_are_owner_scoped():
    client = _Client([True, True])
    service = PolicySlotReservationService(client)

    service.finalize(
        reservation_id="r-1", owner_id="owner-1", document_id="doc-1"
    )
    service.release(reservation_id="r-2", owner_id="owner-1")

    assert client.calls == [
        (
            "finalize_policy_upload_slot",
            {
                "p_reservation_id": "r-1",
                "p_owner_id": "owner-1",
                "p_document_id": "doc-1",
            },
        ),
        (
            "release_policy_upload_slot",
            {"p_reservation_id": "r-2", "p_owner_id": "owner-1"},
        ),
    ]


def test_reservations_are_enabled_only_for_production_supabase(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("DOCUMENT_REPOSITORY_BACKEND", "supabase")
    assert production_policy_slot_reservations_enabled() is True

    monkeypatch.setenv("DOCUMENT_REPOSITORY_BACKEND", "sqlite")
    assert production_policy_slot_reservations_enabled() is False
