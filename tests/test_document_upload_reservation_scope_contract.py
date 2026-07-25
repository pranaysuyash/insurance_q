"""Protect the upload rollback path from reservation-scope regressions."""

from pathlib import Path


def test_persisted_document_rollback_releases_the_outer_reservation_binding():
    source = (Path(__file__).parents[1] / "src" / "api" / "document.py").read_text(
        encoding="utf-8"
    )
    rollback = source.split("def rollback_persisted_document() -> None:", 1)[1].split(
        "# Production durable work uses the outbox", 1
    )[0]

    assert "nonlocal policy_reservation_id" in rollback
    assert "policy_slot_service.release(" in rollback
    assert "policy_reservation_id = None" in rollback
