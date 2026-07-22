#!/usr/bin/env bash
# Deploy the canonical durable-work consumer as a dedicated Cloud Run service.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required=(
  COVERWISE_GCP_PROJECT
  COVERWISE_CLOUD_RUN_REGION
  COVERWISE_RUNTIME_ENV_FILE
  COVERWISE_OPENAI_SECRET
  COVERWISE_SUPABASE_SERVICE_ROLE_SECRET
  COVERWISE_PROCESSING_PAYLOAD_SECRET
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "missing required worker deployment configuration: ${name}" >&2
    exit 2
  fi
done

if [[ ! -f "$COVERWISE_RUNTIME_ENV_FILE" ]]; then
  echo "runtime env file does not exist: $COVERWISE_RUNTIME_ENV_FILE" >&2
  exit 2
fi
if ! command -v uv >/dev/null 2>&1 || [[ ! -x "$repo_root/.venv/bin/python" ]]; then
  echo "worker deployment preflight requires uv and the project .venv" >&2
  exit 2
fi

uv run --python "$repo_root/.venv/bin/python" python "$repo_root/tools/validate_production_config.py" \
  --profile worker \
  --env-file "$COVERWISE_RUNTIME_ENV_FILE" \
  --secret-bound OPENAI_API_KEY \
  --secret-bound SUPABASE_SERVICE_ROLE_KEY \
  --secret-bound PROCESSING_PAYLOAD_ENCRYPTION_KEY

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required; install and authenticate it before deployment" >&2
  exit 2
fi

service_name="${COVERWISE_OUTBOX_WORKER_SERVICE:-coverwise-outbox-worker}"
memory="${COVERWISE_OUTBOX_WORKER_MEMORY:-2Gi}"
timeout="${COVERWISE_OUTBOX_WORKER_TIMEOUT:-3600}"
min_instances="${COVERWISE_OUTBOX_WORKER_MIN_INSTANCES:-1}"
max_instances="${COVERWISE_OUTBOX_WORKER_MAX_INSTANCES:-3}"
secret_bindings="OPENAI_API_KEY=${COVERWISE_OPENAI_SECRET}:latest,SUPABASE_SERVICE_ROLE_KEY=${COVERWISE_SUPABASE_SERVICE_ROLE_SECRET}:latest,PROCESSING_PAYLOAD_ENCRYPTION_KEY=${COVERWISE_PROCESSING_PAYLOAD_SECRET}:latest"

gcloud run deploy "$service_name" \
  --project="$COVERWISE_GCP_PROJECT" \
  --region="$COVERWISE_CLOUD_RUN_REGION" \
  --source="$repo_root" \
  --command=python \
  --args=-m,src.workers.outbox_worker \
  --env-vars-file="$COVERWISE_RUNTIME_ENV_FILE" \
  --set-secrets="$secret_bindings" \
  --memory="$memory" \
  --timeout="$timeout" \
  --concurrency=1 \
  --min-instances="$min_instances" \
  --max-instances="$max_instances" \
  --no-cpu-throttling \
  --port=8080 \
  --ingress=internal \
  --no-allow-unauthenticated

echo "Outbox worker deployment complete: $service_name"
