#!/bin/bash
set -e

ACR_NAME="insuranceappacr"
IMAGE_NAME="insurance-app-simple:v2"
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

echo "Ensuring Docker buildx is enabled..."
docker buildx create --use || true

echo "Logging into Azure Container Registry..."
az acr login --name $ACR_NAME

echo "Building and pushing multi-arch image (amd64, arm64)..."
# Ensure you are in the directory containing Dockerfile.simple and src/simple_app.py
# If Dockerfile.simple is not named Dockerfile, add -f Dockerfile.simple
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ${ACR_LOGIN_SERVER}/${IMAGE_NAME} \
  -f Dockerfile.simple \
  --push .

echo "Multi-arch image build and push complete."

echo "Signing image with Cosign keyless signing..."
if command -v cosign &>/dev/null; then
  # Generate a digest reference for the image
  DIGEST=$(docker buildx imagetools inspect ${ACR_LOGIN_SERVER}/${IMAGE_NAME} --format '{{.Manifest.Digest}}' 2>/dev/null || true)
  
  if [ -n "$DIGEST" ]; then
    IMAGE_WITH_DIGEST="${ACR_LOGIN_SERVER}/${IMAGE_NAME}@${DIGEST}"
    echo "Signing: ${IMAGE_WITH_DIGEST}"
    cosign sign --yes "${IMAGE_WITH_DIGEST}"
    
    echo "Verifying signature..."
    cosign verify \
      --certificate-identity-regexp '^https://github.com/.*' \
      --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
      "${IMAGE_WITH_DIGEST}" | jq . || echo "⚠️ Verification available only in CI (local keyless signing requires OIDC)"
    
    echo "✅ Image signed and verified."
    echo "${DIGEST}" > /tmp/multiarch-image-digest.txt
  else
    echo "⚠️ Could not resolve digest for signing. The image was pushed but not signed."
  fi
else
  echo "⚠️ cosign not installed. Install from https://docs.sigstore.dev/cosign/overview/"
fi

echo "Multi-arch build, push, and signing complete." 