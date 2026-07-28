#!/usr/bin/env bash
set -euo pipefail

# Analytics pipeline live audit
# Starts the API with OPERATOR_DASHBOARD_TOKEN, fires test events, verifies endpoints.

PORT="${1:-8005}"
TOKEN="test-operator-token-2026"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="/tmp/coverwise_api_audit.log"
PID_FILE="/tmp/coverwise_api_audit.pid"

cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
}
trap cleanup EXIT

echo "=== Starting API on port $PORT ==="
cd "$PROJECT_DIR"

# Kill any existing process on the port
lsof -ti :"$PORT" 2>/dev/null | xargs kill 2>/dev/null || true
sleep 1

# Start API with operator token
OPERATOR_DASHBOARD_TOKEN="$TOKEN" \
ENVIRONMENT=development \
    nohup .venv/bin/uvicorn src.app.main:app \
    --host 127.0.0.1 \
    --port "$PORT" \
    --log-level info > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

echo "Waiting for API to be ready..."
for i in $(seq 1 15); do
    if curl -s "http://127.0.0.1:$PORT/healthz" 2>/dev/null | grep -q '"status"'; then
        echo "API ready after ${i}s"
        break
    fi
    if [ "$i" -eq 15 ]; then
        echo "ERROR: API did not start. Log output:"
        tail -20 "$LOG_FILE"
        exit 1
    fi
    sleep 1
done

echo ""
echo "=== Running analytics audit ==="
OPERATOR_DASHBOARD_TOKEN="$TOKEN" \
    .venv/bin/python "$SCRIPT_DIR/run_analytics_audit.py" --port "$PORT"
AUDIT_EXIT=$?

echo ""
echo "=== Audit complete (exit: $AUDIT_EXIT) ==="
echo "API logs saved to: $LOG_FILE"
exit $AUDIT_EXIT
