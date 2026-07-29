# Monitoring Stack Operations Guide

> **Status:** ✅ Operational (local development)
> **Last updated:** 2026-07-29
> **Related:** [Sentry Setup Approach](../analysis/sentry_setup_approach.md),
>   [Analytics Event Registry](../analysis/analytics_tracking_event_registry.md),
>   [Grafana Dashboard JSON](../monitoring/coverwise_prometheus_grafana_dashboard.json)

---

## Stack Overview

CoverWise uses three monitoring tiers:

| Tier | Tool | What It Monitors | Access |
|------|------|-----------------|--------|
| Prometheus | Local (Homebrew v3.13.1) | Infrastructure metrics: request rate, error rate, latency, business counters | `http://localhost:9090` |
| Grafana | Local (Homebrew v13.1.1) | Visual dashboard overlaying Prometheus + JSON API | `http://localhost:3000` |
| Sentry | Cloud (Sentry.io) | Error tracking, custom business metrics, performance traces | [Sentry Dashboard ↗](https://pranaysuyash.sentry.io/dashboard/8903909/) |
| Ops Dashboard | Built into API | HTML dashboard querying `/analytics/*` endpoints | `http://localhost:8080/ops/dashboard` |

---

## 1. API Metrics Endpoint

The backend exposes Prometheus-format metrics at `/metrics`. This is the data source for Prometheus scraping, the ops HTML dashboard, and any external monitoring.

### Verify it's running

```bash
curl http://localhost:8080/healthz
# → {"status":"live","version":"2.0.0"}
```

### View all metrics

```bash
curl http://localhost:8080/metrics | head -50
```

### Business counters exposed

| Metric | Labels | Description |
|--------|--------|-------------|
| `documents_uploaded_total` | `file_type` (pdf, jpg, png) | Total documents uploaded |
| `documents_processed_total` | `processing_mode` (full, fast) | Documents successfully extracted |
| `documents_failed_total` | `error_class` | Documents that failed processing |
| `rag_queries_total` | `result` (success, error, budget_exhausted) | Total RAG query requests |
| `embedding_calls_total` | `provider` (openai, ollama, fallback) | Embedding generation calls |
| `http_requests_total` | `method`, `path`, `status_group` | HTTP request count |
| `http_errors_total` | `method`, `path` | HTTP 5xx errors |
| `http_in_flight_requests` | — | Current concurrent requests |
| `process_uptime_seconds` | — | Process uptime |

### Start the API

```bash
cd /Users/pranay/Projects/medpiper/insurance_app
.venv/bin/uvicorn src.app.main:app --host 127.0.0.1 --port 8080
```

The API is the data source for **all** monitoring tiers — no metrics flow without it running.

---

## 2. Prometheus

### Status

```bash
# Check if running
curl http://localhost:9090/api/v1/status/config

# Or via Homebrew
brew services list | grep prometheus
```

### Start / Stop / Restart

```bash
# Start
brew services start prometheus

# Stop
brew services stop prometheus

# Restart (pick one)
brew services restart prometheus
# OR use the Homebrew LaunchAgent directly:
launchctl kickstart -k gui/$(id -u)/homebrew.mxcl.prometheus
```

### Config File

```
Location: /opt/homebrew/etc/prometheus.yml
```

Current configuration:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'coverwise-api'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: /metrics
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

> **⚠️ Known issue:** The Prometheus config targets `localhost:8000` but the API currently runs on **port 8080**. Update the config to `localhost:8080` before starting Prometheus, or start the API on port 8000.

### Verify scraping

After starting Prometheus, check targets are healthy:

```bash
curl http://localhost:9090/api/v1/targets
```

All targets should show `health: "up"`.

### Trigger-based queries

Once Prometheus is scraping, you can query metrics directly:

```bash
# Request rate over 5 minutes
curl 'http://localhost:9090/api/v1/query?query=rate(http_requests_total[5m])'

# Business counter values
curl 'http://localhost:9090/api/v1/query?query=documents_uploaded_total'

# Error rate
curl 'http://localhost:9090/api/v1/query?query=rate(http_errors_total[5m])'
```

---

## 3. Grafana

### Status

```bash
brew services list | grep grafana
```

### Start / Stop / Restart

```bash
# Start
brew services start grafana

# Stop
brew services stop grafana

# Restart
brew services restart grafana
```

### Access

- **URL:** `http://localhost:3000`
- **Default login:** `admin` / `admin` (prompts to change on first login)

### Provisioned Dashboards

| Dashboard | Panels | Data Sources | Description |
|-----------|--------|--------------|-------------|
| **CoverWise Full-Stack Monitoring** | 50 | Prometheus + JSON API | Uptime, request rate, error rate, p50/p95/p99 latency, document processing metrics, business counters, RAG performance, system health |
| **CoverWise Analytics Dashboard** | 18 | JSON API | Event summary, error tracking, user analytics |

Dashboards are provisioned from files at:
```
/opt/homebrew/etc/grafana/provisioning/dashboards/
├── coverwise.json          # CoverWise Full-Stack Monitoring (50 panels)
├── dashboards.yml          # Provisioning provider config
```

Data sources are provisioned from:
```
/opt/homebrew/etc/grafana/provisioning/datasources/
├── datasources.yml          # Prometheus + JSON API datasources
```

### Datasource Configuration

Current datasources (`/opt/homebrew/etc/grafana/provisioning/datasources/datasources.yml`):

```yaml
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090      # ⚠️ Docker hostname, not localhost
    isDefault: true

  - name: JSON API
    type: grafana-json-datasource
    url: http://host.docker.internal:8000  # ⚠️ Docker hostname, not localhost
```

> **⚠️ Known issue:** Both datasource URLs use Docker-internal hostnames (`prometheus:9090`, `host.docker.internal:8000`). Since Prometheus and Grafana are installed natively via Homebrew (not Docker), these URLs won't resolve. To fix:
>
> 1. Edit `/opt/homebrew/etc/grafana/provisioning/datasources/datasources.yml`
> 2. Change `http://prometheus:9090` → `http://localhost:9090`
> 3. Change `http://host.docker.internal:8000` → `http://localhost:8080`
> 4. Restart Grafana: `brew services restart grafana`

### Manual Dashboard Import

If you create or modify dashboards in the Grafana UI and want to export them:

1. In Grafana → Dashboard → Share → Export → "Save to file"
2. Save the JSON to `docs/monitoring/coverwise_prometheus_grafana_dashboard.json`
3. Copy it to the provisioning directory:
   ```bash
   cp docs/monitoring/coverwise_prometheus_grafana_dashboard.json /opt/homebrew/etc/grafana/provisioning/dashboards/
   brew services restart grafana
   ```

---

## 4. Sentry

### Status

Sentry is cloud-hosted at [sentry.io](https://sentry.io). No local services to start/stop.

### Dashboards

| Dashboard | URL | Widgets |
|-----------|-----|---------|
| **CoverWise Business Metrics** | [View ↗](https://pranaysuyash.sentry.io/dashboard/8903909/) | 5 big-number widgets for docs uploaded, processed, failed, RAG queries, embedding calls |

### Verify metrics are flowing

```bash
cd /Users/pranay/Projects/medpiper/insurance_app
.venv/bin/python -c "
from src.utils.metrics import _sentry_incr
_sentry_incr('documents.uploaded', {'file_type': 'pdf'})
print('Test metric sent — check dashboard after ~1 minute')
"
```

Then check the [Sentry Dashboard](https://pranaysuyash.sentry.io/dashboard/8903909/) — numbers should update within 1-2 minutes.

### Sentry CLI

The Sentry CLI is installed at `/Users/pranay/.local/bin/sentry` and authenticated:

```bash
sentry auth status
# → ✓ Authenticated as Pranay Suyash (pranay.suyash@gmail.com)
```

Useful commands:

```bash
# List dashboards
sentry dashboard list

# Explore custom metrics
sentry explore pranaysuyash/python-fastapi-coverwise --dataset metrics -F metric -F 'sum(value,documents.uploaded,counter,none)' --period 24h

# View issues
sentry issue list
```

---

## 5. Ops Dashboard (HTML)

The built-in ops dashboard requires **no external services** — it queries the API's `/analytics/*` endpoints directly.

### Access

```
http://localhost:8080/ops/dashboard
```

Or from the admin landing page:

```
http://localhost:8080/ops/
```

### Authentication

You need two credentials to access the ops dashboard:

1. **API Bearer Token** — Get from: `curl http://localhost:8080/user/anonymous` (the `access_token` field)
2. **Operator Token** — The `OPERATOR_DASHBOARD_TOKEN` configured on the server (development default: `test-operator-secret`)

### What it shows

| Section | Data Source | Description |
|---------|-------------|-------------|
| Total Events | `/analytics/summary` | Event count and unique users |
| Business Metrics | `/metrics` (parsed in-browser) | Cumulative totals for docs, RAG, embeddings |
| Infrastructure Metrics | `/metrics` | Request rate, error rate, in-flight, uptime |
| Errors by Endpoint | `/metrics` | 5xx errors grouped by path |
| Document Processing | `/metrics` | Processed/failed counts by label |
| Error Trend | `/analytics/errors` | 24h hourly error trend chart |
| Event Summary | `/analytics/summary` | Events by name with bar chart |
| Event Cleanup | `/analytics/events` (DELETE) | Delete events by age/name |

---

## 6. Quick Start & Stop Sequences

### Full startup (all tiers)

```bash
# 1. Start the API (metrics source)
cd /Users/pranay/Projects/medpiper/insurance_app
.venv/bin/uvicorn src.app.main:app --host 127.0.0.1 --port 8080 &
sleep 8

# 2. Start Prometheus
brew services start prometheus
sleep 5

# 3. Start Grafana (already running — verify)
brew services start grafana

# 4. Verify everything
curl http://localhost:8080/healthz       # API
curl http://localhost:9090/api/v1/targets  # Prometheus targets
curl http://localhost:3000/api/health    # Grafana

echo "Ops dashboard: http://localhost:8080/ops/dashboard"
echo "Grafana:       http://localhost:3000"
echo "Prometheus:    http://localhost:9090"
echo "Sentry:        https://pranaysuyash.sentry.io/dashboard/8903909/"
```

### Full shutdown

```bash
# 1. Stop Grafana
brew services stop grafana

# 2. Stop Prometheus
brew services stop prometheus

# 3. Stop API
kill $(lsof -ti :8080)
```

---

## 7. Health Check Quick Reference

| Service | Endpoint | Expected |
|---------|----------|----------|
| API | `http://localhost:8080/healthz` | `{"status":"live"}` |
| API (deep) | `http://localhost:8080/readyz` | `{"status":"ready"}` |
| API metrics | `http://localhost:8080/metrics` | Prometheus exposition format |
| Prometheus | `http://localhost:9090/api/v1/targets` | Targets with `health: "up"` |
| Grafana | `http://localhost:3000/api/health` | `{"database": "ok"}` |
| Sentry | [Sentry Dashboard](https://pranaysuyash.sentry.io/dashboard/8903909/) | Widgets show data |

---

## 8. Troubleshooting

### Problem: Prometheus targets show "down"

Most likely a port mismatch. Check the Prometheus config:

```bash
cat /opt/homebrew/etc/prometheus.yml
# Verify the 'targets' line matches the API port
```

The API runs on port **8080**. If config says `8000`, edit:

```bash
sed -i '' 's/localhost:8000/localhost:8080/' /opt/homebrew/etc/prometheus.yml
brew services restart prometheus
```

### Problem: Grafana dashboards show "No data"

1. Check Prometheus is running: `curl http://localhost:9090/api/v1/targets`
2. Check Grafana datasource URLs point to the right hosts (Docker hostnames won't work for native install)
3. Check the API is running: `curl http://localhost:8080/healthz`
4. Restart Grafana after fixing datasources: `brew services restart grafana`

### Problem: Sentry Dashboard widgets show 0

1. Verify API is running with `SENTRY_DSN` set: `grep SENTRY_DSN .env`
2. Send a test metric: `.venv/bin/python -c "from src.utils.metrics import _sentry_incr; _sentry_incr('test', {'env':'dev'}); print('sent')"`
3. Wait 1-2 minutes for Sentry to index
4. Check the [Sentry Dashboard](https://pranaysuyash.sentry.io/dashboard/8903909/)

### Problem: Can't log into Grafana

Default credentials: `admin` / `admin`. If changed and forgotten, reset:

```bash
brew services stop grafana
# Delete the user database to force re-provisioning
rm /opt/homebrew/var/lib/grafana/grafana.db
brew services start grafana
# Now login with admin/admin again
```

---

## 9. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — complete monitoring stack operations guide | T5: Document monitoring stack procedure |
