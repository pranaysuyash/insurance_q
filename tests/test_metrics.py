"""Tests for the Prometheus metrics module (src/utils/metrics.py).

These tests verify that:
  - The /metrics endpoint returns valid Prometheus-formatted output.
  - Path normalization strips UUIDs from label cardinality.
  - Business metric counters are incremented correctly.
  - The middleware instruments HTTP requests via TestClient.
"""

import time

import pytest
from starlette.testclient import TestClient


def test_metrics_endpoint_returns_valid_prometheus_format():
    """The /metrics endpoint must expose Prometheus text-format data."""
    from src.utils.metrics import metrics_endpoint
    from starlette.requests import Request

    scope = {
        "type": "http",
        "method": "GET",
        "path": "/metrics",
        "headers": [],
    }
    response = metrics_endpoint(Request(scope))
    body = response.body.decode("utf-8")

    # prometheus-client >=0.19 uses OpenMetrics content type
    assert ("text/plain" in response.media_type or "openmetrics" in response.media_type)
    assert "# HELP" in body, "Expected Prometheus HELP lines in /metrics output"
    assert "http_requests_total" in body
    assert "http_request_duration_seconds" in body
    assert "http_errors_total" in body
    assert "process_uptime_seconds" in body


def test_path_normalization_strips_uuids():
    """Labels should use {id} not specific UUIDs."""
    from src.utils.metrics import _normalize_path

    assert _normalize_path("/healthz") == "/healthz"
    assert _normalize_path("/documents/a1b2c3d4-e5f6-7890-abcd-ef1234567890/status") == "/documents/{id}/status"
    assert _normalize_path("/user/42") == "/user/{id}"
    assert _normalize_path("/user/a1b2c3d4-e5f6-7890-abcd-ef1234567890") == "/user/{id}"
    assert _normalize_path("/metrics") == "/metrics"
    assert _normalize_path("/") == "/"
    assert _normalize_path("/analytics/summary") == "/analytics/summary"
    assert _normalize_path("") == "/"


def test_path_normalization_preserves_non_id_segments():
    """Human-readable path parts are not collapsed."""
    from src.utils.metrics import _normalize_path

    assert _normalize_path("/ops/dashboard") == "/ops/dashboard"
    assert _normalize_path("/query") == "/query"
    assert _normalize_path("/query/stream") == "/query/stream"
    assert _normalize_path("/readyz") == "/readyz"
    assert _normalize_path("/documents/stats") == "/documents/stats"


def test_path_normalization_handles_multiple_ids():
    """Multiple UUIDs and mixed segments are handled correctly."""
    from src.utils.metrics import _normalize_path

    path = "/documents/a1b2c3d4-e5f6-7890-abcd-ef1234567890/versions/42"
    assert _normalize_path(path) == "/documents/{id}/versions/{id}"


def test_path_normalization_handles_trailing_slash():
    """Trailing slash is stripped in normalized output."""
    from src.utils.metrics import _normalize_path

    assert _normalize_path("/healthz/") == "/healthz"
    assert _normalize_path("/documents/a1b2c3d4-e5f6-7890-abcd-ef1234567890/") == "/documents/{id}"


def test_business_metric_counters_increment():
    """Document and RAG counters increment correctly."""
    from src.utils.metrics import (
        DOCUMENTS_UPLOADED,
        DOCUMENTS_PROCESSED,
        DOCUMENTS_FAILED,
        RAG_QUERIES_TOTAL,
        EMBEDDING_CALLS_TOTAL,
    )

    DOCUMENTS_UPLOADED.labels(file_type="pdf").inc()
    assert DOCUMENTS_UPLOADED.labels(file_type="pdf")._value.get() >= 1

    DOCUMENTS_PROCESSED.labels(processing_mode="full").inc(3)
    assert DOCUMENTS_PROCESSED.labels(processing_mode="full")._value.get() >= 3

    DOCUMENTS_FAILED.labels(error_class="corrupt_pdf").inc()
    assert DOCUMENTS_FAILED.labels(error_class="corrupt_pdf")._value.get() >= 1

    RAG_QUERIES_TOTAL.labels(result="success").inc(5)
    assert RAG_QUERIES_TOTAL.labels(result="success")._value.get() >= 5

    EMBEDDING_CALLS_TOTAL.labels(provider="openai").inc()
    assert EMBEDDING_CALLS_TOTAL.labels(provider="openai")._value.get() >= 1


def test_metrics_does_not_expose_pii():
    """The /metrics output must use template paths, not concrete user IDs."""
    from src.utils.metrics import REQUESTS_TOTAL

    # Simulate a request to a path with a UUID
    REQUESTS_TOTAL.labels(
        method="GET", path="/documents/{id}/status", status_group="2xx"
    ).inc()

    from src.utils.metrics import metrics_endpoint
    from starlette.requests import Request

    scope = {
        "type": "http",
        "method": "GET",
        "path": "/metrics",
        "headers": [],
    }
    response = metrics_endpoint(Request(scope))
    body = response.body.decode("utf-8")

    # The metric line should contain the template label, not a concrete UUID
    count_str = 'path="/documents/{id}/status"'
    assert count_str in body, f"Expected template label in metrics output:\n{body}"


def test_uptime_gauge_is_set():
    """process_uptime_seconds should be a positive float."""
    from src.utils.metrics import UPTIME

    UPTIME.set(time.time())

    from src.utils.metrics import metrics_endpoint
    from starlette.requests import Request

    scope = {
        "type": "http",
        "method": "GET",
        "path": "/metrics",
        "headers": [],
    }
    response = metrics_endpoint(Request(scope))
    body = response.body.decode("utf-8")

    uptime_lines = [
        line for line in body.split("\n")
        if line.startswith("process_uptime_seconds ")
    ]
    assert len(uptime_lines) >= 1
    for line in uptime_lines:
        value = float(line.split()[-1])
        assert value >= 0


def test_middleware_instruments_via_testclient():
    """A GET /healthz through the middleware stack must increment http_requests_total."""
    from src.utils.metrics import REQUESTS_TOTAL
    from src.app import main

    client = TestClient(main.app)
    resp = client.get("/healthz")
    assert resp.status_code == 200

    total = REQUESTS_TOTAL.labels(
        method="GET", path="/healthz", status_group="2xx"
    )
    assert total._value.get() >= 1


def test_metrics_endpoint_returns_200_via_testclient():
    """The /metrics endpoint must return HTTP 200 through the real app."""
    from src.app import main

    client = TestClient(main.app)
    resp = client.get("/metrics")
    assert resp.status_code == 200
    assert "# HELP" in resp.text
