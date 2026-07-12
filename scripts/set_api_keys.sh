#!/bin/bash
set -e

# Load secrets from .env if present (never hardcode secrets in this file)
if [ -f .env ]; then set -a; source .env; set +a; fi

# Configuration
AZURE_RESOURCE_GROUP="insurance-app-rg"
RAG_APP_NAME="insurance-rag-app"
OCR_APP_NAME="insurance-ocr-app"

# API Keys: read from environment (set via .env or shell env, never hardcoded)
: "${OPENAI_API_KEY:?OPENAI_API_KEY must be set in .env or environment}"
HF_TOKEN="${HF_TOKEN:-your-huggingface-token-here}"  # Update this if you have a Hugging Face token

echo "Setting API keys for deployed Azure services..."

# Function to check if app service exists
check_service_exists() {
    local app_name=$1
    echo "Checking if $app_name exists..."
    if az webapp show --resource-group "$AZURE_RESOURCE_GROUP" --name "$app_name" &>/dev/null; then
        echo "✅ $app_name exists"
        return 0
    else
        echo "❌ $app_name not found"
        return 1
    fi
}

# Function to set API keys for a service
set_api_keys_for_service() {
    local app_name=$1
    echo "Setting API keys for $app_name..."
    
    if check_service_exists "$app_name"; then
        az webapp config appsettings set \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --name "$app_name" \
            --settings OPENAI_API_KEY="$OPENAI_API_KEY"
        
        # Only set HF_TOKEN if it's not the placeholder
        if [[ "$HF_TOKEN" != "your-huggingface-token-here" ]]; then
            az webapp config appsettings set \
                --resource-group "$AZURE_RESOURCE_GROUP" \
                --name "$app_name" \
                --settings HF_TOKEN="$HF_TOKEN"
            echo "✅ Set OPENAI_API_KEY and HF_TOKEN for $app_name"
        else
            echo "✅ Set OPENAI_API_KEY for $app_name (HF_TOKEN skipped - update script if needed)"
        fi
    else
        echo "⚠️  Skipping $app_name - service not found. Make sure deployment completed successfully."
    fi
}

# Set API keys for RAG service
echo "=== Setting API keys for RAG Service ==="
set_api_keys_for_service "$RAG_APP_NAME"

echo ""

# Set API keys for OCR service  
echo "=== Setting API keys for OCR Service ==="
set_api_keys_for_service "$OCR_APP_NAME"

echo ""
echo "✅ API key configuration completed!"
echo ""
echo "Next steps:"
echo "1. Test the service endpoints:"
echo "   curl https://insurance-rag-app.azurewebsites.net/health"
echo "   curl https://insurance-ocr-app.azurewebsites.net/health"
echo "   curl https://insurance-frontend-app.azurewebsites.net/health"
echo ""
echo "2. Monitor logs if needed:"
echo "   az webapp log tail --resource-group $AZURE_RESOURCE_GROUP --name insurance-rag-app"
echo "   az webapp log tail --resource-group $AZURE_RESOURCE_GROUP --name insurance-ocr-app"
echo "   az webapp log tail --resource-group $AZURE_RESOURCE_GROUP --name insurance-frontend-app" 