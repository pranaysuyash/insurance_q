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