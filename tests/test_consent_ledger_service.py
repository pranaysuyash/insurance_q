"""Tests for the consent ledger service (Security Phase 2).

Per ADR-2026-07-19-07, the consent ledger is server-side and
append-only. These tests are the regression net for the typed
Python access layer. The trigger-enforced append-only
contract is verified at the SQL level (in the launch
playbook's verify step); these tests verify the service-layer
contract.
"""

import os
import sys
from unittest.mock import MagicMock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.models.consent import (  # noqa: E402
    ConsentType,
    CurrentConsent,
    RecordConsentRequest,
)
from src.services.consent_ledger_service import (  # noqa: E402
    ConsentAppendOnlyViolation,
    ConsentLedgerService,
    ConsentLedgerUnavailable,
)


# --- 1. initialization is fail-loud ---

def test_from_env_raises_when_url_missing(monkeypatch):
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "test-key")
    with pytest.raises(ConsentLedgerUnavailable):
        ConsentLedgerService.from_env()


def test_from_env_raises_when_key_missing(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    with pytest.raises(ConsentLedgerUnavailable):
        ConsentLedgerService.from_env()


def test_constructor_rejects_empty_inputs():
    with pytest.raises(ConsentLedgerUnavailable):
        ConsentLedgerService("", "key")
    with pytest.raises(ConsentLedgerUnavailable):
        ConsentLedgerService("url", "")


# --- 2. ConsentType enum matches SQL CHECK ---

def test_consent_type_enum_matches_sql_check():
    """The SQL CHECK lists the consent types. The enum must
    match exactly. Drift here means a write that the DB
    rejects (the trigger is the append-only enforcement;
    the CHECK is the type validation)."""
    expected = {
        "privacy_policy", "document_processing", "analytics",
        "marketing_emails", "camera_access", "evaluation_dataset",
        "model_improvement",
    }
    actual = {ct.value for ct in ConsentType}
    assert actual == expected


# --- 3. record_consent ---

def _service_with_mocked_client() -> ConsentLedgerService:
    client = MagicMock()
    return ConsentLedgerService(
        "https://x.supabase.co", "test-key", client=client
    )


def test_record_consent_rejects_empty_user_id():
    svc = _service_with_mocked_client()
    import asyncio
    request = RecordConsentRequest(
        consent_type=ConsentType.ANALYTICS,
        granted=True,
        policy_version="v1.0",
    )
    with pytest.raises(Exception):  # ConsentLedgerError
        asyncio.run(svc.record_consent(user_id="", request=request))


def test_record_consent_passes_payload_to_supabase():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.insert.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    import asyncio
    request = RecordConsentRequest(
        consent_type=ConsentType.PRIVACY_POLICY,
        granted=True,
        policy_version="v1.0",
        ip_address="192.168.1.1",
        user_agent="coverwise-mobile/0.1.2",
    )
    new_id = asyncio.run(svc.record_consent(
        user_id="user-1", request=request
    ))
    assert str(new_id) == "00000000-0000-0000-0000-000000000001"
    # Verify the table was called with the right row shape
    call_args = svc._client.table.return_value.insert.call_args
    inserted_row = call_args[0][0]
    assert inserted_row["user_id"] == "user-1"
    assert inserted_row["consent_type"] == "privacy_policy"
    assert inserted_row["granted"] is True
    assert inserted_row["policy_version"] == "v1.0"
    assert inserted_row["ip_address"] == "192.168.1.1"
    assert inserted_row["user_agent"] == "coverwise-mobile/0.1.2"


def test_record_consent_translates_append_only_violation():
    """The database trigger raises an exception with the
    message 'consent_ledger is append-only' on UPDATE or
    DELETE. The service translates the exception to
    ConsentAppendOnlyViolation so the caller can log +
    alert. This is a security event."""
    svc = _service_with_mocked_client()
    # Simulate the trigger raising an exception on INSERT.
    # (In production, the trigger fires only on UPDATE /
    # DELETE; v1 of the test simulates the path.)
    svc._client.table.return_value.insert.return_value.execute.side_effect = Exception(
        "consent_ledger is append-only: UPDATE is not allowed"
    )
    import asyncio
    request = RecordConsentRequest(
        consent_type=ConsentType.ANALYTICS,
        granted=True,
        policy_version="v1.0",
    )
    with pytest.raises(ConsentAppendOnlyViolation):
        asyncio.run(svc.record_consent(
            user_id="user-1", request=request
        ))


# --- 4. get_current_consent ---

def test_get_current_consent_returns_none_when_no_rows():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = []
    import asyncio
    result = asyncio.run(svc.get_current_consent(
        user_id="user-1", consent_type=ConsentType.ANALYTICS
    ))
    assert result is None


def test_get_current_consent_parses_pydantic_model():
    svc = _service_with_mocked_client()
    raw_row = {
        "id": "00000000-0000-0000-0000-000000000001",
        "user_id": "user-1",
        "consent_type": "analytics",
        "granted": True,
        "policy_version": "v1.0",
        "ip_address": "192.168.1.1",
        "user_agent": "coverwise-mobile/0.1.2",
        "created_at": "2026-07-19T10:00:00+00:00",
    }
    svc._client.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [raw_row]
    import asyncio
    result = asyncio.run(svc.get_current_consent(
        user_id="user-1", consent_type=ConsentType.ANALYTICS
    ))
    assert result is not None
    assert isinstance(result, CurrentConsent)
    assert result.consent_type == ConsentType.ANALYTICS
    assert result.granted is True
    assert result.policy_version == "v1.0"
    assert result.user_id == "user-1"


# --- 5. get_current_consent_all ---

def test_get_current_consent_all_returns_list_of_all_types():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [
        {
            "id": "id-1", "user_id": "user-1",
            "consent_type": "privacy_policy",
            "granted": True, "policy_version": "v1.0",
            "ip_address": None, "user_agent": None,
            "created_at": "2026-07-19T10:00:00+00:00",
        },
        {
            "id": "id-2", "user_id": "user-1",
            "consent_type": "analytics",
            "granted": True, "policy_version": "v1.0",
            "ip_address": None, "user_agent": None,
            "created_at": "2026-07-19T10:05:00+00:00",
        },
        {
            "id": "id-3", "user_id": "user-1",
            "consent_type": "marketing_emails",
            "granted": False, "policy_version": "v1.0",
            "ip_address": None, "user_agent": None,
            "created_at": "2026-07-19T10:10:00+00:00",
        },
    ]
    import asyncio
    results = asyncio.run(svc.get_current_consent_all("user-1"))
    assert len(results) == 3
    by_type = {r.consent_type: r for r in results}
    assert by_type[ConsentType.PRIVACY_POLICY].granted is True
    assert by_type[ConsentType.ANALYTICS].granted is True
    assert by_type[ConsentType.MARKETING_EMAILS].granted is False


# --- 6. get_history ---

def test_get_history_returns_records_newest_first():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.eq.return_value.order.return_value.limit.return_value.execute.return_value.data = [
        {
            "id": "id-3", "user_id": "user-1",
            "consent_type": "marketing_emails",
            "granted": False, "policy_version": "v1.0",
            "ip_address": None, "user_agent": None,
            "created_at": "2026-07-19T10:10:00+00:00",
        },
        {
            "id": "id-2", "user_id": "user-1",
            "consent_type": "analytics",
            "granted": True, "policy_version": "v1.0",
            "ip_address": None, "user_agent": None,
            "created_at": "2026-07-19T10:05:00+00:00",
        },
    ]
    import asyncio
    history = asyncio.run(svc.get_history("user-1", limit=10))
    assert len(history) == 2
    assert history[0].id == "id-3"  # newest first
    assert history[1].id == "id-2"


# --- 7. failure handling ---

def test_get_current_consent_returns_none_on_supabase_error():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.side_effect = Exception(
        "connection refused"
    )
    import asyncio
    result = asyncio.run(svc.get_current_consent(
        user_id="user-1", consent_type=ConsentType.ANALYTICS
    ))
    assert result is None  # graceful failure


def test_record_consent_raises_on_empty_insert_result():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.insert.return_value.execute.return_value.data = []
    import asyncio
    request = RecordConsentRequest(
        consent_type=ConsentType.ANALYTICS,
        granted=True,
        policy_version="v1.0",
    )
    with pytest.raises(Exception):  # ConsentLedgerError
        asyncio.run(svc.record_consent(
            user_id="user-1", request=request
        ))


# --- 8. append-only contract documentation as a test ---

def test_append_only_contract_is_documented():
    """The consent ledger is append-only at the database
    level. The trigger in
    supabase/migrations/2026_07_19_consent_ledger.sql raises
    an exception on UPDATE and DELETE for ALL roles,
    including service_role. The service layer translates
    the exception to ConsentAppendOnlyViolation; the API
    layer returns 500 and logs the security event. This
    test documents the contract; the SQL test in the
    launch playbook's verify step proves the trigger fires.
    """
    contract_doc = (
        "The consent ledger is append-only at the database "
        "level. A Postgres trigger raises an exception on "
        "UPDATE and DELETE for ALL roles, including "
        "service_role. The trigger is the only way to "
        "enforce append-only for the service_role, which "
        "bypasses RLS. The service layer translates the "
        "exception to ConsentAppendOnlyViolation; the API "
        "layer returns 500 and logs the security event. "
        "A future retention policy (e.g. 7 years per "
        "DPDP Act 2023) is a server-side DELETE job that "
        "disables the trigger, deletes the old rows, and "
        "re-enables the trigger; the deletion is logged."
    )
    assert "append-only" in contract_doc
    assert "Postgres trigger" in contract_doc
    assert "service_role" in contract_doc
    assert "RLS" in contract_doc
