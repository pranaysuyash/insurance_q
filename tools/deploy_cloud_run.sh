#!/usr/bin/env bash
# Deploy the one canonical CoverWise Cloud Run service. Secrets stay in Secret
# Manager; the runtime env file must contain only non-secret values.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required=(
  COVERWISE_GCP_PROJECT
  COVERWISE_CLOUD_RUN_REGION
  COVERWISE_RUNTIME_ENV_FILE
  COVERWISE_OPENAI_SECRET
  COVERWISE_SUPABASE_SERVICE_ROLE_SECRET
  COVERWISE_ANON_AUTH_SIGNING_SECRET
  COVERWISE_PROCESSING_PAYLOAD_SECRET
  COVERWISE_REVENUECAT_WEBHOOK_SECRET
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "missing required deployment configuration: ${name}" >&2
    exit 2
  fi
done

if [[ ! -f "$COVERWISE_RUNTIME_ENV_FILE" ]]; then
  echo "runtime env file does not exist: $COVERWISE_RUNTIME_ENV_FILE" >&2
  exit 2
fi

if ! command -v uv >/dev/null 2>&1 || [[ ! -x "$repo_root/.venv/bin/python" ]]; then
  echo "deployment preflight requires uv and the project .venv" >&2
  exit 2
fi

uv run --python "$repo_root/.venv/bin/python" python "$repo_root/tools/validate_production_config.py" \
  --env-file "$COVERWISE_RUNTIME_ENV_FILE" \
  --secret-bound OPENAI_API_KEY \
  --secret-bound SUPABASE_SERVICE_ROLE_KEY \
  --secret-bound ANONYMOUS_AUTH_SIGNING_KEY \
  --secret-bound PROCESSING_PAYLOAD_ENCRYPTION_KEY \
  --secret-bound REVENUECAT_WEBHOOK_AUTHORIZATION

service_name="${COVERWISE_CLOUD_RUN_SERVICE:-coverwise-api}"
# The OCR runtime is now part of the customer-facing image. Keep an explicit
# 4Gi default so model initialization/inference does not compete with the API
# process for the old slim-image memory budget; operators may tune this only
# after a measured production-like benchmark.
memory="${COVERWISE_CLOUD_RUN_MEMORY:-4Gi}"
timeout="${COVERWISE_CLOUD_RUN_TIMEOUT:-300}"
concurrency="${COVERWISE_CLOUD_RUN_CONCURRENCY:-4}"
min_instances="${COVERWISE_CLOUD_RUN_MIN_INSTANCES:-0}"
max_instances="${COVERWISE_CLOUD_RUN_MAX_INSTANCES:-10}"
secret_bindings="OPENAI_API_KEY=${COVERWISE_OPENAI_SECRET}:latest,SUPABASE_SERVICE_ROLE_KEY=${COVERWISE_SUPABASE_SERVICE_ROLE_SECRET}:latest,ANONYMOUS_AUTH_SIGNING_KEY=${COVERWISE_ANON_AUTH_SIGNING_SECRET}:latest,PROCESSING_PAYLOAD_ENCRYPTION_KEY=${COVERWISE_PROCESSING_PAYLOAD_SECRET}:latest,REVENUECAT_WEBHOOK_AUTHORIZATION=${COVERWISE_REVENUECAT_WEBHOOK_SECRET}:latest"
if [[ -n "${COVERWISE_ANON_AUTH_PREVIOUS_KEYS_SECRET:-}" ]]; then
  secret_bindings+=",ANONYMOUS_AUTH_PREVIOUS_SIGNING_KEYS=${COVERWISE_ANON_AUTH_PREVIOUS_KEYS_SECRET}:latest"
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required; install and authenticate it before deployment" >&2
  exit 2
fi

gcloud run deploy "$service_name" \
  --project="$COVERWISE_GCP_PROJECT" \
  --region="$COVERWISE_CLOUD_RUN_REGION" \
  --source="$repo_root" \
  --env-vars-file="$COVERWISE_RUNTIME_ENV_FILE" \
  --set-secrets="$secret_bindings" \
  --memory="$memory" \
  --timeout="$timeout" \
  --concurrency="$concurrency" \
  --min-instances="$min_instances" \
  --max-instances="$max_instances" \
  --port=8080 \
  --ingress=all \
  --allow-unauthenticated

echo "Deployment complete. The API is publicly invokable for mobile clients; policy routes remain protected by the application bearer boundary. Bind an approved custom domain, then run deployed acceptance checks."
