#!/usr/bin/env bash
# Build a CoverWise store artifact only with explicit, live public endpoints.
set -euo pipefail

required=(
  COVERWISE_API_BASE_URL
  COVERWISE_PRIVACY_POLICY_URL
  COVERWISE_TERMS_OF_SERVICE_URL
  COVERWISE_SUPPORT_EMAIL
  COVERWISE_PRIVACY_POLICY_VERSION
)

for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "missing required release configuration: ${name}" >&2
    exit 2
  fi
done

for url_name in COVERWISE_API_BASE_URL COVERWISE_PRIVACY_POLICY_URL COVERWISE_TERMS_OF_SERVICE_URL; do
  if [[ "${!url_name}" != https://* ]]; then
    echo "${url_name} must start with https://" >&2
    exit 2
  fi
done

if [[ ! "${COVERWISE_SUPPORT_EMAIL}" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
  echo "COVERWISE_SUPPORT_EMAIL must be a valid email address" >&2
  exit 2
fi

cd "$(dirname "$0")/../mobile"
flutter analyze
flutter test
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=BOOTSTRAP_POLICY_DEMO=false \
  --dart-define=API_BASE_URL="${COVERWISE_API_BASE_URL}" \
  --dart-define=PRIVACY_POLICY_URL="${COVERWISE_PRIVACY_POLICY_URL}" \
  --dart-define=TERMS_OF_SERVICE_URL="${COVERWISE_TERMS_OF_SERVICE_URL}" \
  --dart-define=SUPPORT_EMAIL="${COVERWISE_SUPPORT_EMAIL}"
  --dart-define=PRIVACY_POLICY_VERSION="${COVERWISE_PRIVACY_POLICY_VERSION}"
