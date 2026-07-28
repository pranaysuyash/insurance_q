"""Prometheus instrumentation for the CoverWise backend.

Provides request-level and business-process metrics that operators can
scrape via the /metrics endpoint (exposed by PrometheusMiddleware).

Label cardinality is deliberately kept low — path templates rather than
individual request paths, and only business-metric labels that map to
dashboard-level slices.

Usage:
    app.add_middleware(PrometheusMiddleware)
    app.add_route("/metrics", metrics_endpoint)
"""

import time

from prometheus_client import (
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)
from prometheus_client import CONTENT_TYPE_LATEST
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response


# ── Request-level metrics ──────────────────────────────────────────

# Histogram: HTTP request duration in seconds bucketed by method + path template.
# Labels: method, path, status_code (grouped: 2xx, 3xx, 4xx, 5xx).
REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    labelnames=["method", "path", "status_group"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)

# Counter: total HTTP requests by method, path template, and status group.
REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total HTTP requests",
    labelnames=["method", "path", "status_group"],
)

# Counter: errors (5xx responses) by method + path template.
ERRORS_TOTAL = Counter(
    "http_errors_total",
    "Total HTTP 5xx responses",
    labelnames=["method", "path"],
)


# ── Runtime metrics ───────────────────────────────────────────────

# Gauge: number of in-flight requests at any instant.
IN_FLIGHT_REQUESTS = Gauge(
    "http_in_flight_requests",
    "Number of HTTP requests currently being processed",
)

# Gauge: process uptime in seconds (set at process start).
_start_time = time.time()


def _uptime_seconds() -> float:
    return time.time() - _start_time


UPTIME = Gauge("process_uptime_seconds", "Process uptime in seconds")


# ── Business metrics ──────────────────────────────────────────────

# Counter: documents uploaded, extracted, and failed.
DOCUMENTS_UPLOADED = Counter(
    "documents_uploaded_total",
    "Total documents uploaded",
    labelnames=["file_type"],
)

DOCUMENTS_PROCESSED = Counter(
    "documents_processed_total",
    "Total documents successfully processed through extraction pipeline",
    labelnames=["processing_mode"],
)

DOCUMENTS_FAILED = Counter(
    "documents_failed_total",
    "Total documents that failed processing",
    labelnames=["error_class"],
)

# Histogram: document processing duration in seconds.
DOCUMENT_PROCESSING_DURATION = Histogram(
    "document_processing_duration_seconds",
    "Document processing latency in seconds",
    labelnames=["processing_mode"],
    buckets=(0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 120.0, 300.0),
)

# Counter: RAG queries (includes streaming queries).
RAG_QUERIES_TOTAL = Counter(
    "rag_queries_total",
    "Total RAG query requests",
    labelnames=["result"],  # 'success' | 'error' | 'budget_exhausted'
)

# Histogram: RAG query end-to-end latency.
RAG_QUERY_DURATION = Histogram(
    "rag_query_duration_seconds",
    "RAG query end-to-end latency in seconds",
    buckets=(0.5, 1.0, 2.5, 5.0, 10.0, 15.0, 30.0, 60.0),
)

# Counter: embedding generation calls (proxy for model activity).
EMBEDDING_CALLS_TOTAL = Counter(
    "embedding_calls_total",
    "Total embedding generation calls",
    labelnames=["provider"],  # 'openai' | 'ollama' | 'fallback'
)


# ── Middleware ─────────────────────────────────────────────────────

class PrometheusMiddleware(BaseHTTPMiddleware):
    """ASGI middleware that instruments HTTP requests with Prometheus metrics.

    Adds:
      - http_request_duration_seconds  (histogram)
      - http_requests_total             (counter)
      - http_errors_total               (counter)
      - http_in_flight_requests         (gauge)
      - process_uptime_seconds          (gauge)

    Excludes the /metrics endpoint itself to avoid recursion.
    """

    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        if request.url.path == "/metrics":
            return await call_next(request)

        # Clean path: abstract away user IDs and document IDs.
        path = _normalize_path(request.url.path)

        # Bump uptime gauge on every request so it stays visible.
        UPTIME.set(_uptime_seconds())

        IN_FLIGHT_REQUESTS.inc()
        start = time.monotonic()
        status_group = "2xx"
        try:
            response = await call_next(request)
            status_code = response.status_code
            if status_code >= 500:
                status_group = "5xx"
                ERRORS_TOTAL.labels(method=request.method, path=path).inc()
            elif status_code >= 400:
                status_group = "4xx"
            elif status_code >= 300:
                status_group = "3xx"
            else:
                status_group = "2xx"
            return response
        except Exception:
            status_group = "5xx"
            ERRORS_TOTAL.labels(method=request.method, path=path).inc()
            raise
        finally:
            elapsed = time.monotonic() - start
            REQUEST_DURATION.labels(
                method=request.method, path=path, status_group=status_group
            ).observe(elapsed)
            REQUESTS_TOTAL.labels(
                method=request.method, path=path, status_group=status_group
            ).inc()
            IN_FLIGHT_REQUESTS.dec()


def _normalize_path(path: str) -> str:
    """Abstract dynamic path segments into template parameters.

    Maps:
      /documents/abc-123/status  →  /documents/{id}/status
      /user/abc-123              →  /user/{id}
      /healthz                   →  /healthz  (unchanged)
    """
    parts = path.rstrip("/").split("/")
    cleaned: list[str] = []
    for part in parts:
        if not part:
            continue
        # UUID v4 or similar base-16 identifier
        if len(part) == 36 and part.count("-") == 4:
            cleaned.append("{id}")
        elif part.isdigit():
            cleaned.append("{id}")
        else:
            cleaned.append(part)
    result = "/" + "/".join(cleaned)
    # Ensure consistent label: no trailing slash (except root)
    return result if result != "/" else "/"


# ── Sentry custom metric helper ───────────────────────────────────


def _sentry_incr(key: str, tags: dict | None = None) -> None:
    """Emit a business metric to Sentry if the SDK is active.

    Safe to call unconditionally — silently no-ops when the Sentry SDK
    has not been initialised (e.g. local development without SENTRY_DSN).

    Uses ``sentry_sdk.metrics.count()`` — the replacement for the
    removed ``metrics.incr()`` API in sentry-sdk >= 2.0.
    """
    try:
        import sentry_sdk

        sentry_sdk.metrics.count(key=key, value=1.0, tags=tags or {})
    except Exception:
        pass


# ── Metrics endpoint ──────────────────────────────────────────────


def metrics_endpoint(_request: Request) -> Response:
    """Expose Prometheus metrics for scraping.

    Uses the default registry. In multi-process deployments (gunicorn +
    uvicorn workers), configure PROMETHEUS_MULTIPROC_DIR env var and
    uncomment the multi-process collector below.
    """
    data = generate_latest()
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)
