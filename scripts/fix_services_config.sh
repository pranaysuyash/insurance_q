#!/bin/bash
set -e

# Configuration
AZURE_RESOURCE_GROUP="insurance-app-rg"
RAG_APP_NAME="insurance-rag-app"
OCR_APP_NAME="insurance-ocr-app"
FRONTEND_APP_NAME="insurance-frontend-app"
AZURE_ACR_NAME="insuranceappacr"

echo "🔧 Fixing all service configurations..."

# Get ACR credentials
echo "Getting ACR credentials..."
ACR_USERNAME=$(az acr credential show --name "$AZURE_ACR_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$AZURE_ACR_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --query "passwords[0].value" -o tsv)

# Get Redis password
echo "Getting Redis password..."
REDIS_PASSWORD=$(az redis list-keys --name insurance-app-redis --resource-group insurance-app-rg --query primaryKey -o tsv)

# OpenAI API Key
OPENAI_API_KEY="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"

echo "=== Configuring RAG Service ==="
# Fix RAG service startup command
az webapp config set --resource-group "$AZURE_RESOURCE_GROUP" --name "$RAG_APP_NAME" \
    --generic-configurations '{"appCommandLine":"uvicorn src.rag.app:app --host 0.0.0.0 --port 8000"}'

# Set RAG service app settings
az webapp config appsettings set --resource-group "$AZURE_RESOURCE_GROUP" --name "$RAG_APP_NAME" --settings \
    WEBSITES_PORT="8000" \
    PYTHONPATH="/app" \
    PYTHONUNBUFFERED="1" \
    DOCKER_REGISTRY_SERVER_URL="https://insuranceappacr.azurecr.io" \
    DOCKER_REGISTRY_SERVER_USERNAME="$ACR_USERNAME" \
    DOCKER_REGISTRY_SERVER_PASSWORD="$ACR_PASSWORD" \
    QDRANT_HOST="insurance-app-qdrant.eastus.azurecontainer.io" \
    QDRANT_PORT="6333" \
    REDIS_HOST="insurance-app-redis.redis.cache.windows.net" \
    REDIS_PORT="6380" \
    REDIS_PASSWORD="$REDIS_PASSWORD" \
    OPENAI_API_KEY="$OPENAI_API_KEY"

echo "=== Configuring OCR Service ==="
# Fix OCR service startup command
az webapp config set --resource-group "$AZURE_RESOURCE_GROUP" --name "$OCR_APP_NAME" \
    --generic-configurations '{"appCommandLine":"uvicorn src.ocr.app:app --host 0.0.0.0 --port 8001"}'

# Set OCR service app settings
az webapp config appsettings set --resource-group "$AZURE_RESOURCE_GROUP" --name "$OCR_APP_NAME" --settings \
    WEBSITES_PORT="8001" \
    PYTHONPATH="/app" \
    PYTHONUNBUFFERED="1" \
    DOCKER_REGISTRY_SERVER_URL="https://insuranceappacr.azurecr.io" \
    DOCKER_REGISTRY_SERVER_USERNAME="$ACR_USERNAME" \
    DOCKER_REGISTRY_SERVER_PASSWORD="$ACR_PASSWORD" \
    REDIS_HOST="insurance-app-redis.redis.cache.windows.net" \
    REDIS_PORT="6380" \
    REDIS_PASSWORD="$REDIS_PASSWORD" \
    RAG_SERVICE_URL="https://insurance-rag-app.azurewebsites.net" \
    OPENAI_API_KEY="$OPENAI_API_KEY"

echo "=== Configuring Frontend Service ==="
# Fix Frontend service startup command
az webapp config set --resource-group "$AZURE_RESOURCE_GROUP" --name "$FRONTEND_APP_NAME" \
    --generic-configurations '{"appCommandLine":"uvicorn src.frontend.app:app --host 0.0.0.0 --port 8080"}'

# Set Frontend service app settings
az webapp config appsettings set --resource-group "$AZURE_RESOURCE_GROUP" --name "$FRONTEND_APP_NAME" --settings \
    WEBSITES_PORT="8080" \
    PYTHONPATH="/app" \
    PYTHONUNBUFFERED="1" \
    DOCKER_REGISTRY_SERVER_URL="https://insuranceappacr.azurecr.io" \
    DOCKER_REGISTRY_SERVER_USERNAME="$ACR_USERNAME" \
    DOCKER_REGISTRY_SERVER_PASSWORD="$ACR_PASSWORD" \
    OCR_SERVICE_URL="https://insurance-ocr-app.azurewebsites.net" \
    RAG_SERVICE_URL="https://insurance-rag-app.azurewebsites.net"

echo "=== Restarting all services ==="
az webapp restart --name "$RAG_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" &
az webapp restart --name "$OCR_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" &
az webapp restart --name "$FRONTEND_APP_NAME" --resource-group "$AZURE_RESOURCE_GROUP" &

wait

echo "✅ All services configured and restarted!"
echo ""
echo "Services will be available at:"
echo "- RAG Service: https://insurance-rag-app.azurewebsites.net"
echo "- OCR Service: https://insurance-ocr-app.azurewebsites.net"
echo "- Frontend Service: https://insurance-frontend-app.azurewebsites.net"
echo ""
echo "Wait 2-3 minutes for services to fully start, then test with:"
echo "curl https://insurance-frontend-app.azurewebsites.net/health" 