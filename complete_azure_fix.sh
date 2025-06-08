#!/bin/bash
set -e

echo "🔧 COMPLETE AZURE FIX - Addressing All Critical Issues"

RESOURCE_GROUP="insurance-app-rg"
ACR_NAME="insuranceappacr"
IMAGE_TAG="v$(date +%Y%m%d-%H%M%S)"

echo ""
echo "📋 Issues being fixed:"
echo "1. 🔐 Docker authentication (unauthorized errors)"
echo "2. 🏗️ Docker image architecture (linux/amd64 manifest)"
echo "3. ⚙️ Environment variables (all showing as null)"
echo "4. 🚀 Startup commands and port configuration"

# Step 0: Log Docker into Azure Container Registry
echo ""
echo "🔐 Step 0: Logging Docker into Azure Container Registry..."
az acr login --name $ACR_NAME

# Step 1: Rebuild and push Docker image with correct architecture
echo ""
echo "🏗️ Step 1: Building new Docker image with correct architecture..."

# Create temporary Dockerfile with proper multi-arch support
# Using requirements-azure.txt to ensure a faster, more reliable build for this critical fix
cat > Dockerfile.azure-fixed << 'EOF'
FROM --platform=linux/amd64 python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    software-properties-common \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --timeout 600 -r requirements.txt

# Copy application code
COPY src/ src/

# Create necessary directories
RUN mkdir -p /app/uploads /app/temp

# Set environment variables
ENV PYTHONPATH="/app"
ENV PYTHONUNBUFFERED="1"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

# Default command
CMD ["uvicorn", "src.rag.service:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

echo "🔨 Building Docker image for linux/amd64..."
docker buildx create --use --name azure-builder 2>/dev/null || docker buildx use azure-builder
docker buildx build \
    --platform linux/amd64 \
    -f Dockerfile.azure-fixed \
    -t $ACR_NAME.azurecr.io/insurance-app-services:$IMAGE_TAG \
    --push .

echo "✅ New image built and pushed: $ACR_NAME.azurecr.io/insurance-app-services:$IMAGE_TAG"

# Step 2: Get proper ACR credentials
echo ""
echo "🔑 Step 2: Getting ACR credentials..."
az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "username" -o tsv
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "passwords[0].value" -o tsv)

echo "Username: $ACR_USERNAME"
echo "Password length: ${#ACR_PASSWORD} characters"

# Step 3: Fix each service completely
fix_service_complete() {
    local SERVICE_NAME=$1
    local SERVICE_MODULE=$2
    local SERVICE_SETTINGS=$3
    
    echo ""
    echo "🔧 Completely fixing $SERVICE_NAME..."
    
    # Update to new image
    echo "   📦 Setting new Docker image..."
    az webapp config container set \
        --name $SERVICE_NAME \
        --resource-group $RESOURCE_GROUP \
        --container-image-name "$ACR_NAME.azurecr.io/insurance-app-services:$IMAGE_TAG" \
        --container-registry-url "https://$ACR_NAME.azurecr.io" \
        --container-registry-user "$ACR_USERNAME" \
        --container-registry-password "$ACR_PASSWORD"
    
    # Set startup command
    echo "   🚀 Setting startup command..."
    az webapp config set \
        --resource-group $RESOURCE_GROUP \
        --name $SERVICE_NAME \
        --startup-file "uvicorn $SERVICE_MODULE --host 0.0.0.0 --port \${PORT:-8000} --workers 1"
    
    # Set environment variables properly (using individual commands)
    echo "   ⚙️  Setting environment variables individually..."
    
    # Core settings
    az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings WEBSITES_PORT=8000
    az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings PYTHONPATH=/app
    az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings PYTHONUNBUFFERED=1
    az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings WEBSITES_ENABLE_APP_SERVICE_STORAGE=false
    az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings WEBSITES_CONTAINER_START_TIME_LIMIT=1800
    
    # Service-specific settings
    if [[ $SERVICE_SETTINGS == *"QDRANT"* ]]; then
        az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings QDRANT_HOST=insurance-app-qdrant.eastus.azurecontainer.io
        az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings QDRANT_PORT=6333
    fi
    
    if [[ $SERVICE_SETTINGS == *"REDIS"* ]]; then
        az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings REDIS_HOST=insurance-app-redis.redis.cache.windows.net
        az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings REDIS_PORT=6379
    fi
    
    if [[ $SERVICE_SETTINGS == *"RAG_SERVICE_URL"* ]]; then
        az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings RAG_SERVICE_URL=https://insurance-rag-app.azurewebsites.net
    fi
    
    if [[ $SERVICE_SETTINGS == *"OCR_SERVICE_URL"* ]]; then
        az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $SERVICE_NAME --settings OCR_SERVICE_URL=https://insurance-ocr-app.azurewebsites.net
    fi
    
    echo "   ✅ $SERVICE_NAME configuration complete!"
}

# Fix all services
fix_service_complete "insurance-rag-app" "src.rag.service:app" "QDRANT REDIS"
fix_service_complete "insurance-ocr-app" "src.ocr.service:app" "REDIS RAG_SERVICE_URL"
fix_service_complete "insurance-frontend-app" "src.frontend.app:app" "OCR_SERVICE_URL RAG_SERVICE_URL"

# Step 4: Restart services in dependency order
echo ""
echo "🔄 Step 4: Restarting services in dependency order..."

for SERVICE in insurance-rag-app insurance-ocr-app insurance-frontend-app; do
    echo "🔄 Restarting $SERVICE..."
    az webapp restart --resource-group $RESOURCE_GROUP --name $SERVICE
    echo "   ⏱️  Waiting 45 seconds for $SERVICE to start..."
    sleep 45
done

# Step 5: Create monitoring script
echo ""
echo "📊 Step 5: Creating monitoring script..."

cat > monitor_services.sh << 'EOF'
#!/bin/bash

echo "🔍 Monitoring Azure App Services..."

SERVICES=("insurance-rag-app" "insurance-ocr-app" "insurance-frontend-app")

for i in {1..10}; do
    echo ""
    echo "=== Check #$i ==="
    
    for SERVICE in "${SERVICES[@]}"; do
        URL="https://$SERVICE.azurewebsites.net/health"
        echo -n "$SERVICE: "
        
        if curl -f -s -m 15 "$URL" > /dev/null; then
            echo "✅ HEALTHY"
        else
            echo "❌ NOT RESPONDING"
        fi
    done
    
    if [ $i -lt 10 ]; then
        echo "Waiting 30 seconds before next check..."
        sleep 30
    fi
done

echo ""
echo "🏁 Final test with response details:"
for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "=== $SERVICE ==="
    curl -s "https://$SERVICE.azurewebsites.net/health" | head -5 || echo "No response"
done
EOF

chmod +x monitor_services.sh

# Cleanup
rm -f Dockerfile.azure-fixed

echo ""
echo "✅ COMPLETE FIX APPLIED!"
echo ""
echo "🕐 Services are restarting. This process takes 5-10 minutes."
echo "📊 Monitor progress: ./monitor_services.sh"
echo ""
echo "🔍 Manual checks in 5 minutes:"
echo "   curl https://insurance-rag-app.azurewebsites.net/health"
echo "   curl https://insurance-ocr-app.azurewebsites.net/health"
echo "   curl https://insurance-frontend-app.azurewebsites.net/health"
echo ""
echo "📋 If issues persist, check logs:"
echo "   az webapp log tail --resource-group $RESOURCE_GROUP --name [service-name]"
echo ""
echo "🔑 Remember to set API keys in Azure Portal:"
echo "   - OPENAI_API_KEY"
echo "   - HF_TOKEN (if using Hugging Face models)" 