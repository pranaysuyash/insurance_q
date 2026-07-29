# Sentry Backend Integration: Architecture and Approach

> **Status:** Implemented (backend services), Configured (Flutter app via wizard)
> **Date:** 2026-07-29
> **Source session:** Analytics P0 gap closure — wire backend Sentry for error tracking and custom metrics
> **Evidence tier:** Implementation verified against source code (Tier 1)
> **Related:** [Analytics Landscape](ANALYTICS_LANDSCAPE_EXPLORATION.md), [Analytics Event Registry](analytics_tracking_event_registry.md)

---

## 1. What Was Done

Sentry was wired into the Python backend across 5 services:
1. **Main API** (`src/app/main.py`) — global Sentry SDK init with performance tracing
2. **OCR service** (`src/ocr/pipeline.py`, `src/ocr/service.py`, `src/ocr/image_processor.py`, `src/ocr/pdf_processor.py`) — Sentry capture_exception for OCR failures
3. **RAG service** (`src/rag/service.py`, `src/rag/pipeline.py`) — Sentry tracing for query spans
4. **Document processing** (`src/services/document_processing_job.py`) — error capture during doc processing
5. **Metrics** (`src/utils/metrics.py`) — Sentry metric `incr()` calls for 5 business counters

Additionally, the **Flutter app** was configured via the Sentry wizard:
- SDK added to `pubspec.yaml`
- `main.dart` patched with `SentryFlutter.init()`
- Example error verify button available but not committed to production build

## 2. Architecture

### Backend Sentry Setup

```
Application Layer
├── src/app/main.py
│   └── sentry_sdk.init(
│         dsn=SENTRY_DSN (from env),
│         traces_sample_rate=0.25,    # 25% for cost/performance balance
│         profiles_sample_rate=0.1,   # 10% profiling
│         environment=ENVIRONMENT
│       )
│
├── OCR Pipeline
│   └── try/except in pipeline.py
│         → sentry_sdk.capture_exception()
│
├── RAG Pipeline
│   └── sentry_sdk.start_transaction(op="rag_query")
│         → metrics.incr counters
│
├── Document Processing
│   └── sentry_sdk.capture_exception() on failure
│
└── Metrics Module
    └── metrics.incr("documents_uploaded_total", ...)
```

### Key Configuration Decisions

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `traces_sample_rate` | 0.25 | Catches errors without overwhelming the free tier quota |
| `profiles_sample_rate` | 0.1 | CPU profiling on a subset of traces |
| DSN storage | Environment variable (`SENTRY_DSN`) | Not hardcoded — configured per environment |
| Fallback behavior | Graceful degradation | If `SENTRY_DSN` is empty or invalid, init is skipped. App continues without Sentry. |

### DSN Configuration

The Python backend DSN and Flutter DSN are different Sentry projects:
- **Flutter DSN** (from Sentry wizard): `https://f8ec8cec2bf5dab81446af6c2c00573d@o4509668248780800.ingest.us.sentry.io/4511807264063488`
- **Python DSN** (requires creating a Python project in Sentry): set as `SENTRY_DSN` in `.env`

The Flutter app DSN is configured via `--dart-define=SENTRY_DSN=...` at build time.

## 3. Custom Business Metrics (Sentry Metrics)

5 counters were wired via `src/utils/metrics.py`:

| Counter | Where It's Incremented | Status |
|---------|------------------------|--------|
| `documents_uploaded_total` | Document upload handler | ✅ Wired |
| `documents_processed_total` | Document processing completion | ✅ Wired |
| `documents_failed_total` | Document processing failure | ✅ Wired |
| `rag_queries_total` | RAG query handler (with result label) | ✅ Wired |
| `embedding_calls_total` | Embedding generation | ✅ Wired |

These are sent to Sentry Metrics (via `sentry_sdk.metrics.incr()`) and also exposed as Prometheus metrics at the `/metrics` endpoint.

## 4. What the Flutter App Has

- `sentry_flutter` package added to `pubspec.yaml`
- `SentryFlutter.init()` called in `main.dart`
- DSN from build-time `--dart-define`
- Automatic error capture (dart errors, Flutter errors, native crashes)
- Performance tracing for widget build times
- **Not yet:** manual breadcrumbs for analytics events, user identification for error attribution

## 5. Monitoring Dashboard

The Prometheus `/metrics` endpoint is exposed at the backend API and can be scraped by:
- **Grafana** (via Prometheus datasource) — dashboard JSON at `docs/monitoring/coverwise_prometheus_grafana_dashboard.json`
- **Sentry Dashboard** (via Sentry Metrics) — metrics appear in the Sentry Performance section
- **Ops Dashboard** (`/ops/dashboard`) — HTML dashboard that queries `/analytics/*` endpoints

## 6. Known Gaps

| Gap | Impact | Fix |
|-----|--------|-----|
| Python DSN not yet set in .env | Custom metrics not flowing to Sentry dashboard | Founder: create Python project in Sentry, paste DSN into .env |
| Flutter error tracking not yet verified | Release builds may not report crashes | Build a release APK and test with a thrown error |
| No user identification in Sentry | Errors can't be attributed to specific users | Add `Sentry.configureScope()` with user ID after auth |
| No release tracking | Can't tell which version an error came from | Pass `--dart-define=SENTRY_RELEASE=...` at build time |

## 7. Relation to Other Documents

This document describes the infrastructure approach. For the analytics event system (which is separate from Sentry), see:
- [Analytics Landscape](ANALYTICS_LANDSCAPE_EXPLORATION.md) — overall analytics strategy
- [Analytics Event Registry](analytics_tracking_event_registry.md) — 63 registered events
- [Prometheus/Grafana Dashboard](../monitoring/coverwise_prometheus_grafana_dashboard.json) — ops dashboard

## 8. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — Sentry architecture and setup documented | Exhaustive documentation audit per §0.3.1 |
