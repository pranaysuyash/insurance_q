#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration - USER TO UPDATE THESE VALUES --- #
AZURE_RESOURCE_GROUP="insurance-app-rg"                # Using existing resource group from simple app
AZURE_LOCATION="eastus"                               # Your Azure region
AZURE_ACR_NAME="insuranceappacr"                      # Using existing ACR from simple app
AZURE_APP_SERVICE_PLAN="insurance-app-plan"           # Using existing App Service Plan from simple app

# Docker Image Details
DOCKER_IMAGE_NAME="insurance-app-services"            # Name of the image in ACR
DOCKER_IMAGE_TAG="v1"                                 # Tag for the image
FULL_IMAGE_URI="${AZURE_ACR_NAME}.azurecr.io/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"

# Service Names (ensure these are globally unique for Azure App Service)
RAG_APP_NAME="insurance-rag-app"                      # App Service name for RAG service
OCR_APP_NAME="insurance-ocr-app"                      # App Service name for OCR service
FRONTEND_APP_NAME="insurance-frontend-app"            # App Service name for Frontend service

# External Service URLs & Keys (USER MUST PROVIDE THESE ACTUAL VALUES)
QDRANT_PUBLIC_HOST="insurance-app-qdrant.eastus.azurecontainer.io"  # Updated with actual Qdrant FQDN
QDRANT_PORT="6333"
AZURE_REDIS_HOST="insurance-app-redis.redis.cache.windows.net"  # Updated with actual Redis hostname
# AZURE_REDIS_KEY: It's more secure to set this via Azure Portal. 
# The services are currently configured to connect to Redis without a password for simplicity if using only REDIS_HOST/PORT.
# If your Python Redis client needs a password, you'll need to ensure it's configured and add REDIS_PASSWORD to app settings.

# Secrets (These will be set as placeholders. UPDATE THEM IN AZURE PORTAL.)
OPENAI_API_KEY_PLACEHOLDER="SET_YOUR_OPENAI_API_KEY_IN_AZURE_PORTAL"
HF_TOKEN_PLACEHOLDER="SET_YOUR_HF_TOKEN_IN_AZURE_PORTAL"

# --- End of Configuration --- #

echo "Starting full backend deployment to Azure..."

# 1. General Azure Resources Setup (Create if not exists - Guide suggests doing this first)
echo "Step 1: Ensuring Resource Group, ACR, and App Service Plan exist..."

# Create Resource Group if it doesn't exist (optional, as guide has this as a prior step)
az group show --name "$AZURE_RESOURCE_GROUP" &>/dev/null || \
  (echo "Resource group '${AZURE_RESOURCE_GROUP}' not found. Creating..." && \
   az group create --name "$AZURE_RESOURCE_GROUP" --location "$AZURE_LOCATION")

# Create ACR if it doesn't exist (optional)
az acr show --name "$AZURE_ACR_NAME" --resource-group "$AZURE_RESOURCE_GROUP" &>/dev/null || \
  (echo "ACR '${AZURE_ACR_NAME}' not found. Creating..." && \
   az acr create --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_ACR_NAME" --sku Basic --admin-enabled true)

# Create App Service Plan if it doesn't exist (optional)
az appservice plan show --name "$AZURE_APP_SERVICE_PLAN" --resource-group "$AZURE_RESOURCE_GROUP" &>/dev/null || \
  (echo "App Service Plan '${AZURE_APP_SERVICE_PLAN}' not found. Creating..." && \
   az appservice plan create --name "$AZURE_APP_SERVICE_PLAN" --resource-group "$AZURE_RESOURCE_GROUP" --is-linux --sku B1)

echo "Logging into ACR: $AZURE_ACR_NAME..."
az acr login --name "$AZURE_ACR_NAME"

# 2. Building and Pushing the Docker Image
echo "Step 2: Building and pushing Docker image ${FULL_IMAGE_URI}..."
echo "Using the OCR-enabled production dependency profile with extended timeouts..."
echo "This may take 10-15 minutes due to PyTorch (865MB) download..."
echo "Ensuring docker buildx is available..."
docker buildx create --use || true # Attempt to create and use a builder, continue if it already exists

# Create optimized Dockerfile with very long timeouts for large downloads
echo "Creating Dockerfile with extended timeouts for large ML packages..."
cat > Dockerfile.full << 'EOF'
# Use Python 3.11 slim image
FROM --platform=linux/amd64 python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies including OpenCV requirements
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libfontconfig1 \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libcairo2 \
    libgdk-pixbuf-2.0-0 \
    libice6 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for better Docker caching)
COPY requirements.txt requirements-production-ocr.txt .

# Install Python dependencies with very long timeout for PyTorch download
# Timeout set to 3000 seconds (50 minutes) to handle PyTorch (865MB)
# Default connection timeout (30s) + read timeout (3000s) + 10 retries
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu \
    torch==2.1.0 torchvision==0.16.0 && \
    pip install --no-cache-dir \
    --timeout 3000 \
    --retries 10 \
    --default-timeout=3000 \
    -r requirements-production-ocr.txt

# Copy application code
COPY src/ src/
COPY docs/legal/ docs/legal/

# Create necessary directories
RUN mkdir -p /app/uploads /app/temp

# Set Python path and disable buffering
ENV PYTHONPATH="/app"
ENV PYTHONUNBUFFERED="1"

# Expose port (this will be overridden by Azure App Service)
EXPOSE 8000

# Default command (will be overridden by startup command in Azure)
CMD ["uvicorn", "src.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

echo "Starting Docker build with extended timeouts..."
echo "⏰ This will take 10-20 minutes. Please be patient..."
echo "📦 PyTorch alone is 865MB and may take 5-10 minutes to download."

# Build with longer timeout and push
docker buildx build --platform linux/amd64 -t "${FULL_IMAGE_URI}" -f Dockerfile.full . --push

# Clean up temporary Dockerfile
rm -f Dockerfile.full

echo "✅ Docker image successfully built and pushed!"

echo "Fetching ACR credentials..."
ACR_USERNAME=$(az acr credential show --name "$AZURE_ACR_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$AZURE_ACR_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --query "passwords[0].value" -o tsv)

# --- Phase 1: Deploying RAG Service --- #
echo "
Phase 1: Deploying RAG Service (${RAG_APP_NAME})..."
az webapp create --resource-group "$AZURE_RESOURCE_GROUP" \
    --plan "$AZURE_APP_SERVICE_PLAN" \
    --name "$RAG_APP_NAME" \
    --deployment-container-image-name "${FULL_IMAGE_URI}" # Initial image setup

echo "Configuring container for ${RAG_APP_NAME}..."
az webapp config container set --name "$RAG_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" \
    --docker-custom-image-name "${FULL_IMAGE_URI}" \
    --docker-registry-server-url "https://$(echo $AZURE_ACR_NAME | tr '[:upper:]' '[:lower:]').azurecr.io" \
    --docker-registry-server-user "$ACR_USERNAME"
    # Password omitted, will be set via app settings

echo "Setting startup command for ${RAG_APP_NAME}..."
az webapp config set --resource-group "$AZURE_RESOURCE_GROUP" --name "$RAG_APP_NAME" \
    --generic-configurations '{"appCommandLine":"uvicorn src.rag.service:app --host 0.0.0.0 --port 8000"}'

echo "Setting application settings for ${RAG_APP_NAME} (including ACR password)..."
az webapp config appsettings set --resource-group "$AZURE_RESOURCE_GROUP" --name "$RAG_APP_NAME" --settings \
    WEBSITES_PORT="8000" \
    PYTHONPATH="/app" \
    PYTHONUNBUFFERED="1" \
    DOCKER_REGISTRY_SERVER_PASSWORD="${ACR_PASSWORD}" \
    QDRANT_HOST="${QDRANT_PUBLIC_HOST}" \
    QDRANT_PORT="${QDRANT_PORT}" \
    REDIS_HOST="${AZURE_REDIS_HOST}" \
    REDIS_PORT="6379" \
    OPENAI_API_KEY="${OPENAI_API_KEY_PLACEHOLDER}" \
    HF_TOKEN="${HF_TOKEN_PLACEHOLDER}"
echo "IMPORTANT: Manually update OPENAI_API_KEY and HF_TOKEN for ${RAG_APP_NAME} in Azure Portal."
RAG_SERVICE_PUBLIC_URL="https://${RAG_APP_NAME}.azurewebsites.net"
echo "RAG Service will be available at: ${RAG_SERVICE_PUBLIC_URL}"

# --- Phase 2: Deploying OCR Service --- #
echo "
Phase 2: Deploying OCR Service (${OCR_APP_NAME})..."
az webapp create --resource-group "$AZURE_RESOURCE_GROUP" \
    --plan "$AZURE_APP_SERVICE_PLAN" \
    --name "$OCR_APP_NAME" \
    --deployment-container-image-name "${FULL_IMAGE_URI}" # Initial image setup

echo "Configuring container for ${OCR_APP_NAME}..."
az webapp config container set --name "$OCR_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" \
    --docker-custom-image-name "${FULL_IMAGE_URI}" \
    --docker-registry-server-url "https://$(echo $AZURE_ACR_NAME | tr '[:upper:]' '[:lower:]').azurecr.io" \
    --docker-registry-server-user "$ACR_USERNAME"
    # Password omitted, will be set via app settings

echo "Setting startup command for ${OCR_APP_NAME}..."
az webapp config set --resource-group "$AZURE_RESOURCE_GROUP" --name "$OCR_APP_NAME" \
    --generic-configurations '{"appCommandLine":"uvicorn src.ocr.service:app --host 0.0.0.0 --port 8001"}'

echo "Setting application settings for ${OCR_APP_NAME} (including ACR password)..."
az webapp config appsettings set --resource-group "$AZURE_RESOURCE_GROUP" --name "$OCR_APP_NAME" --settings \
    WEBSITES_PORT="8001" \
    PYTHONPATH="/app" \
    PYTHONUNBUFFERED="1" \
    DOCKER_REGISTRY_SERVER_PASSWORD="${ACR_PASSWORD}" \
    REDIS_HOST="${AZURE_REDIS_HOST}" \
    REDIS_PORT="6379" \
    RAG_SERVICE_URL="${RAG_SERVICE_PUBLIC_URL}" \
    OPENAI_API_KEY="${OPENAI_API_KEY_PLACEHOLDER}" \
    HF_TOKEN="${HF_TOKEN_PLACEHOLDER}"
echo "IMPORTANT: Manually update OPENAI_API_KEY and HF_TOKEN for ${OCR_APP_NAME} in Azure Portal."
OCR_SERVICE_PUBLIC_URL="https://${OCR_APP_NAME}.azurewebsites.net"
echo "OCR Service will be available at: ${OCR_SERVICE_PUBLIC_URL}"

# --- Phase 3: Deploying Frontend Service --- #
echo "
Phase 3: Deploying Frontend Service (${FRONTEND_APP_NAME})..."
az webapp create --resource-group "$AZURE_RESOURCE_GROUP" \
    --plan "$AZURE_APP_SERVICE_PLAN" \
    --name "$FRONTEND_APP_NAME" \
    --deployment-container-image-name "${FULL_IMAGE_URI}" # Initial image setup

echo "Configuring container for ${FRONTEND_APP_NAME}..."
az webapp config container set --name "$FRONTEND_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" \
    --docker-custom-image-name "${FULL_IMAGE_URI}" \
    --docker-registry-server-url "https://$(echo $AZURE_ACR_NAME | tr '[:upper:]' '[:lower:]').azurecr.io" \
    --docker-registry-server-user "$ACR_USERNAME"
    # Password omitted, will be set via app settings

echo "Setting startup command for ${FRONTEND_APP_NAME}..."
az webapp config set --resource-group "$AZURE_RESOURCE_GROUP" --name "$FRONTEND_APP_NAME" \
    --generic-configurations '{"appCommandLine":"uvicorn src.frontend.app:app --host 0.0.0.0 --port 8080"}'

echo "Setting application settings for ${FRONTEND_APP_NAME} (including ACR password)..."
az webapp config appsettings set --resource-group "$AZURE_RESOURCE_GROUP" --name "$FRONTEND_APP_NAME" --settings \
    WEBSITES_PORT="8080" \
    PYTHONPATH="/app" \
    PYTHONUNBUFFERED="1" \
    DOCKER_REGISTRY_SERVER_PASSWORD="${ACR_PASSWORD}" \
    OCR_SERVICE_URL="${OCR_SERVICE_PUBLIC_URL}" \
    RAG_SERVICE_URL="${RAG_SERVICE_PUBLIC_URL}"

FRONTEND_SERVICE_PUBLIC_URL="https://${FRONTEND_APP_NAME}.azurewebsites.net"
echo "Frontend Service (for mobile app) will be available at: ${FRONTEND_SERVICE_PUBLIC_URL}"

echo "
🎉 Deployment script finished successfully!"
echo ""
echo "📋 Next Steps:"
echo "1. IMPORTANT: Set API keys by running: ./scripts/set_api_keys.sh"
echo "2. Test each service's /health endpoint:"
echo "   - RAG: ${RAG_SERVICE_PUBLIC_URL}/health"
echo "   - OCR: ${OCR_SERVICE_PUBLIC_URL}/health"
echo "   - Frontend: ${FRONTEND_SERVICE_PUBLIC_URL}/health"
echo "3. Update your Flutter app in 'mobile/lib/services/api_service.dart' to use: ${FRONTEND_SERVICE_PUBLIC_URL}"
echo "4. Monitor logs via: az webapp log tail --resource-group ${AZURE_RESOURCE_GROUP} --name <app-name>"
echo ""
echo "🚀 All three services should now be fully functional with OCR capabilities!"
