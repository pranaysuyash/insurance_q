#!/bin/bash
set -e

echo "🔧 Fixing Azure App Services - Multi-Service Port Configuration"

RESOURCE_GROUP="insurance-app-rg"
ACR_NAME="insuranceappacr"

# Get ACR credentials
echo "📋 Getting ACR credentials..."
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "passwords[0].value" -o tsv)

# Update each service with correct port configuration
echo ""
echo "🎯 Fixing RAG Service (insurance-rag-app)..."
if az webapp show --name insurance-rag-app --resource-group $RESOURCE_GROUP &>/dev/null; then
    # RAG Service should use port 8000 (the default for Azure)
    az webapp config set \
        --resource-group $RESOURCE_GROUP \
        --name insurance-rag-app \
        --startup-file "uvicorn src.rag.service:app --host 0.0.0.0 --port 8000"
    
    # Set port to 8000 for Azure App Service
    az webapp config appsettings set \
        --resource-group $RESOURCE_GROUP \
        --name insurance-rag-app \
        --settings WEBSITES_PORT="8000"
    
    echo "✅ RAG Service configured for port 8000"
else
    echo "❌ insurance-rag-app not found"
fi

echo ""
echo "🎯 Fixing OCR Service (insurance-ocr-app)..."
if az webapp show --name insurance-ocr-app --resource-group $RESOURCE_GROUP &>/dev/null; then
    # OCR Service should ALSO use port 8000 (Azure App Service default)
    # Each Azure App Service gets its own port 8000 internally
    az webapp config set \
        --resource-group $RESOURCE_GROUP \
        --name insurance-ocr-app \
        --startup-file "uvicorn src.ocr.service:app --host 0.0.0.0 --port 8000"
    
    # Set port to 8000 for Azure App Service  
    az webapp config appsettings set \
        --resource-group $RESOURCE_GROUP \
        --name insurance-ocr-app \
        --settings WEBSITES_PORT="8000"
    
    # Update service URL to point to RAG service
    az webapp config appsettings set \
        --resource-group $RESOURCE_GROUP \
        --name insurance-ocr-app \
        --settings RAG_SERVICE_URL="https://insurance-rag-app.azurewebsites.net"
    
    echo "✅ OCR Service configured for port 8000"
else
    echo "❌ insurance-ocr-app not found"
fi

echo ""
echo "🎯 Fixing Frontend Service (insurance-frontend-app)..."
if az webapp show --name insurance-frontend-app --resource-group $RESOURCE_GROUP &>/dev/null; then
    # Frontend Service should ALSO use port 8000 (Azure App Service default)
    az webapp config set \
        --resource-group $RESOURCE_GROUP \
        --name insurance-frontend-app \
        --startup-file "uvicorn src.frontend.app:app --host 0.0.0.0 --port 8000"
    
    # Set port to 8000 for Azure App Service
    az webapp config appsettings set \
        --resource-group $RESOURCE_GROUP \
        --name insurance-frontend-app \
        --settings WEBSITES_PORT="8000"
    
    # Update service URLs to point to other services
    az webapp config appsettings set \
        --resource-group $RESOURCE_GROUP \
        --name insurance-frontend-app \
        --settings \
            OCR_SERVICE_URL="https://insurance-ocr-app.azurewebsites.net" \
            RAG_SERVICE_URL="https://insurance-rag-app.azurewebsites.net"
    
    echo "✅ Frontend Service configured for port 8000"
else
    echo "❌ insurance-frontend-app not found"
fi

echo ""
echo "🎯 Checking legacy single service (insurance-policy-app)..."
if az webapp show --name insurance-policy-app --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "ℹ️  Found legacy insurance-policy-app - this can be deleted if multi-services work"
    echo "   URL: https://insurance-policy-app.azurewebsites.net"
else
    echo "ℹ️  No legacy single service found"
fi

echo ""
echo "🔄 Restarting all services..."
for APP in insurance-rag-app insurance-ocr-app insurance-frontend-app; do
    if az webapp show --name $APP --resource-group $RESOURCE_GROUP &>/dev/null; then
        echo "🔄 Restarting $APP..."
        az webapp restart --resource-group $RESOURCE_GROUP --name $APP
    fi
done

echo ""
echo "✅ Multi-service configuration fixed!"
echo ""
echo "🌐 Service URLs (each runs on port 8000 internally):"
echo "   RAG Service:      https://insurance-rag-app.azurewebsites.net/health"
echo "   OCR Service:      https://insurance-ocr-app.azurewebsites.net/health"  
echo "   Frontend Service: https://insurance-frontend-app.azurewebsites.net/health"
echo ""
echo "📱 Update your Flutter app to use: https://insurance-frontend-app.azurewebsites.net"
echo ""
echo "🔍 Monitor logs with:"
echo "   az webapp log tail --resource-group $RESOURCE_GROUP --name insurance-rag-app"
echo "   az webapp log tail --resource-group $RESOURCE_GROUP --name insurance-ocr-app"
echo "   az webapp log tail --resource-group $RESOURCE_GROUP --name insurance-frontend-app"
echo ""
echo "⏱️  Wait 2-3 minutes for services to restart, then test the health endpoints." 