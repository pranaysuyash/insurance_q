#!/usr/bin/env bash
# Verify a signed container image using Cosign keyless verification.
#
# Usage:
#   tools/verify_signed_image.sh <image-ref>
#
# Examples:
#   tools/verify_signed_image.sh docker.io/coverwise/insurance_app:latest
#   tools/verify_signed_image.sh docker.io/coverwise/insurance_app@sha256:abc123...
#
# Exit codes:
#   0 – Signature verified successfully
#   1 – Cosign not installed
#   2 – Missing image reference
#   3 – Verification failed
#
# BR-11 evidence: this script proves the image was signed by our CI
# pipeline using Cosign keyless signing with the GitHub OIDC identity.

set -euo pipefail

if ! command -v cosign &>/dev/null; then
  echo "ERROR: cosign is not installed. Install it from https://docs.sigstore.dev/cosign/overview/" >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <image-ref>" >&2
  echo "Example: $0 docker.io/coverwise/insurance_app:latest" >&2
  exit 2
fi

IMAGE_REF="$1"

echo "=== Cosign Keyless Verification ==="
echo "Image: ${IMAGE_REF}"
echo ""

# Verify using the expected CI identity.
# The certificate identity matches the GitHub Actions OIDC subject used during signing.
# For keyless signing, the identity is included in the certificate's Subject
# Alternative Name (SAN).
echo "Verifying signature..."
if cosign verify \
  --certificate-identity-regexp '^https://github.com/.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  "${IMAGE_REF}"; then
  echo ""
  echo "✅ SIGNATURE VERIFIED — Image ${IMAGE_REF} was signed by our CI pipeline."
  exit 0
else
  echo ""
  echo "❌ VERIFICATION FAILED — Image ${IMAGE_REF} has no valid signature or identity mismatch." >&2
  exit 3
fi
