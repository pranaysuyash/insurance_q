import pytest
from fastapi import HTTPException

from src.utils.runtime_access import require_nonproduction


def test_diagnostics_are_hidden_in_production(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")

    with pytest.raises(HTTPException) as error:
        require_nonproduction()

    assert error.value.status_code == 404


def test_diagnostics_remain_available_outside_production(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "staging")

    assert require_nonproduction() is None
