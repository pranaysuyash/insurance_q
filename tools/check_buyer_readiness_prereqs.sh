#!/usr/bin/env bash
set -euo pipefail

timestamp="$(date -Iseconds)"
failures=0
missing=()
docker_socket_path="${HOME}/.docker/run/docker.sock"
worker_socket_link="/var/run/docker.sock"

echo "BR-04/BR-05 readiness check"
echo "Timestamp: ${timestamp}"
echo

# 1) Runtime socket health
if [[ -S "${docker_socket_path}" ]]; then
  if [[ -L "${worker_socket_link}" ]]; then
    linked_target="$(readlink "${worker_socket_link}")"
    echo "INFO: ${worker_socket_link} symlink target: ${linked_target}"
  fi
  if timeout 5s docker version --format 'DockerVersion={{.Client.Version}};Server={{.Server.Version}}' >/tmp/buyer_readiness_docker_version.txt 2>&1; then
    cat /tmp/buyer_readiness_docker_version.txt
    rm -f /tmp/buyer_readiness_docker_version.txt
  else
    if [[ -s /tmp/buyer_readiness_docker_version.txt ]]; then
      echo "  detail: $(cat /tmp/buyer_readiness_docker_version.txt)"
      rm -f /tmp/buyer_readiness_docker_version.txt
    fi
    echo "FAIL: docker socket exists but docker daemon check failed"
    ((failures+=1))
  fi
else
  echo "FAIL: docker socket missing at ${docker_socket_path}"
  ((failures+=1))
fi

echo

# 2) required env vars for local identity/tenant verification
# Backward-compatible alias: many runtime setups use SUPABASE_SECRET_KEY as the
# canonical server credential and do not populate SUPABASE_SERVICE_ROLE_KEY
# separately.
if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" && -n "${SUPABASE_SECRET_KEY:-}" ]]; then
  export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SECRET_KEY}"
  echo "INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY."
fi

required_vars=(
  "SUPABASE_URL"
  "SUPABASE_PUBLISHABLE_KEY"
  "SUPABASE_SERVICE_ROLE_KEY"
)

resolved_api_url="${COVERWISE_API_URL:-${COVERWISE_API_BASE_URL:-}}"
if [[ -n "${resolved_api_url}" ]]; then
  export COVERWISE_API_URL="${resolved_api_url}"
  required_vars+=("COVERWISE_API_URL")
fi

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    missing+=("$var")
    ((failures+=1))
  fi
done

if ((${#missing[@]} > 0)); then
  echo "FAIL: required env vars missing: ${missing[*]}"
else
  echo "OK: required env vars present (redacted values):"
  echo "  SUPABASE_URL=${SUPABASE_URL:-(unset)}"
  echo "  COVERWISE_API_URL=${COVERWISE_API_URL:-(unset)}"
  echo "  SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY:0:12}…"
  echo "  SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY:0:12}…"
fi

echo

# 3) local endpoint health probes (only when set)
if [[ -n "${COVERWISE_API_URL:-}" ]]; then
  if curl -fsSL --max-time 3 "${COVERWISE_API_URL%/}/healthz" >/tmp/buyer_readiness_api_health.txt 2>&1; then
    echo "OK: COVERWISE_API_URL health probe passed"
    rm -f /tmp/buyer_readiness_api_health.txt
  else
    echo "FAIL: COVERWISE_API_URL health probe failed"
    echo "  target: ${COVERWISE_API_URL%/}/healthz"
    if [[ -s /tmp/buyer_readiness_api_health.txt ]]; then
      echo "  detail: $(cat /tmp/buyer_readiness_api_health.txt)"
      rm -f /tmp/buyer_readiness_api_health.txt
    fi
    ((failures+=1))
  fi
fi

if [[ -n "${SUPABASE_URL:-}" ]]; then
  if curl -fsSL --max-time 3 "${SUPABASE_URL%/}/rest/v1/" >/tmp/buyer_readiness_supabase_rest.txt 2>&1; then
    echo "OK: SUPABASE_URL REST probe passed"
    rm -f /tmp/buyer_readiness_supabase_rest.txt
  else
    echo "WARN: SUPABASE_URL REST probe failed"
    echo "  target: ${SUPABASE_URL%/}/rest/v1/"
    if [[ -s /tmp/buyer_readiness_supabase_rest.txt ]]; then
      echo "  detail: $(cat /tmp/buyer_readiness_supabase_rest.txt)"
      rm -f /tmp/buyer_readiness_supabase_rest.txt
    fi
    ((failures+=1))
  fi
fi

echo
if (( failures == 0 )); then
  echo "READY: BR-04/BR-05 local verification prerequisites are satisfied."
  exit 0
else
  echo "BLOCKED: BR-04/BR-05 readiness check failed with ${failures} item(s)."
  exit 1
fi
