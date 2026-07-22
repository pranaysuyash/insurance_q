"""Tests for safe remote Supabase schema diagnostics."""

from tools.verify_supabase_schema import _error_label


class CodedError(Exception):
    code = "PGRST205"


class StatusError(Exception):
    status = 401


def test_error_label_prefers_safe_provider_code():
    assert _error_label(CodedError("table missing")) == "PGRST205"


def test_error_label_reports_http_status_without_error_payload():
    assert _error_label(StatusError("credential details must not be printed")) == "HTTP_401"


def test_error_label_has_type_fallback():
    assert _error_label(RuntimeError("internal details")) == "RuntimeError"
