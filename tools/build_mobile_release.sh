#!/usr/bin/env bash
# Build a CoverWise store artifact only with explicit, live public endpoints.
set -euo pipefail

required=(
  COVERWISE_API_BASE_URL
  COVERWISE_PRIVACY_POLICY_URL
  COVERWISE_TERMS_OF_SERVICE_URL
  COVERWISE_SUPPORT_EMAIL
  COVERWISE_PRIVACY_POLICY_VERSION
  SUPABASE_URL
  SUPABASE_PUBLISHABLE_KEY
  REVENUECAT_API_KEY
)

for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "missing required release configuration: ${name}" >&2
    exit 2
  fi
done

# Optional mobile-local assistant configuration. The model is selected at
# build time so the store artifact has an explicit, reviewable model source;
# the app never guesses a model or contacts a model provider on its own.
on_device_inference_enabled="${COVERWISE_ON_DEVICE_INFERENCE_ENABLED:-false}"
on_device_model_url="${COVERWISE_ON_DEVICE_MODEL_URL:-}"
if [[ "${on_device_inference_enabled}" != "true" && "${on_device_inference_enabled}" != "false" ]]; then
  echo "COVERWISE_ON_DEVICE_INFERENCE_ENABLED must be true or false" >&2
  exit 2
fi
if [[ "${on_device_inference_enabled}" == "true" && "${on_device_model_url}" != https://* ]]; then
  echo "COVERWISE_ON_DEVICE_MODEL_URL must be an HTTPS URL when on-device inference is enabled" >&2
  exit 2
fi

for url_name in COVERWISE_API_BASE_URL COVERWISE_PRIVACY_POLICY_URL COVERWISE_TERMS_OF_SERVICE_URL; do
  if [[ "${!url_name}" != https://* ]]; then
    echo "${url_name} must start with https://" >&2
    exit 2
  fi
done

for public_value_name in COVERWISE_API_BASE_URL COVERWISE_PRIVACY_POLICY_URL COVERWISE_TERMS_OF_SERVICE_URL SUPABASE_URL SUPABASE_PUBLISHABLE_KEY REVENUECAT_API_KEY; do
  public_value="${!public_value_name}"
  if [[ "${public_value}" == *"..."* || "${public_value}" == *"example.com"* || "${public_value}" == *"your-"* || "${public_value}" == *"project.supabase.co"* ]]; then
    echo "${public_value_name} contains a placeholder value" >&2
    exit 2
  fi
done
if [[ "${SUPABASE_URL}" != https://* ]]; then
  echo "SUPABASE_URL must start with https://" >&2
  exit 2
fi
if [[ "${REVENUECAT_API_KEY}" == sk_* || "${REVENUECAT_API_KEY}" == atk_* ]]; then
  echo "REVENUECAT_API_KEY must be a public SDK key, not a secret or OAuth credential" >&2
  exit 2
fi

if [[ ! "${COVERWISE_SUPPORT_EMAIL}" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
  echo "COVERWISE_SUPPORT_EMAIL must be a valid email address" >&2
  exit 2
fi

repo_root=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
mobile_root="$repo_root/mobile"
python3 "$repo_root/tools/validate_legal_release_assets.py"
python3 "$repo_root/tools/verify_hosted_legal_documents.py" \
  --privacy-url "$COVERWISE_PRIVACY_POLICY_URL" \
  --terms-url "$COVERWISE_TERMS_OF_SERVICE_URL"
cd "$mobile_root"

# A production artifact must never silently fall back to the debug keystore.
# The historical root-level android/key.properties is not a valid signing
# source for this Flutter module and must be rotated/removed separately.
for tracked_key_properties in \
  "$repo_root/android/key.properties" \
  "$mobile_root/android/key.properties"; do
  relative_key_properties="${tracked_key_properties#"$repo_root/"}"
  if git -C "$repo_root" ls-files --error-unmatch "$relative_key_properties" >/dev/null 2>&1; then
    echo "refusing release: tracked ${relative_key_properties} must be rotated and removed from version control" >&2
    exit 2
  fi
done
if [[ ! -f "$mobile_root/android/key.properties" ]]; then
  echo "refusing release: mobile/android/key.properties is required for production signing" >&2
  exit 2
fi
export COVERWISE_RELEASE_BUILD=true
flutter analyze
flutter test
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=BOOTSTRAP_POLICY_DEMO=false \
  --dart-define=API_BASE_URL="${COVERWISE_API_BASE_URL}" \
  --dart-define=PRIVACY_POLICY_URL="${COVERWISE_PRIVACY_POLICY_URL}" \
  --dart-define=TERMS_OF_SERVICE_URL="${COVERWISE_TERMS_OF_SERVICE_URL}" \
  --dart-define=SUPPORT_EMAIL="${COVERWISE_SUPPORT_EMAIL}" \
  --dart-define=PRIVACY_POLICY_VERSION="${COVERWISE_PRIVACY_POLICY_VERSION}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY}" \
  --dart-define=REVENUECAT_API_KEY="${REVENUECAT_API_KEY}" \
  --dart-define=ON_DEVICE_INFERENCE_ENABLED="${on_device_inference_enabled}" \
  --dart-define=ON_DEVICE_MODEL_URL="${on_device_model_url}"
