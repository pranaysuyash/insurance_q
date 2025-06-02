#!/bin/bash

# Azure Deployment Script for Insurance App (Simple Docker Deployment)
# Run this script after starting Docker and configuring Azure CLI

set -e  # Exit on any error

# Configuration
RESOURCE_GROUP="insurance-app-rg"
LOCATION="eastus"
ACR_NAME="insuranceappacr"
APP_SERVICE_PLAN="insurance-app-plan"
WEB_APP_NAME="insurance-policy-app"  # Change this to your preferred name
IMAGE_NAME="insurance-app-api"

echo "🚀 Starting Azure deployment..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

# Check if Azure CLI is logged in
if ! az account show > /dev/null 2>&1; then
    echo "❌ Not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Step 1: Build Docker image
echo "📦 Building Docker image..."
docker build -t ${IMAGE_NAME}:latest .

# Step 2: Create resource group
echo "🏗️ Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Step 3: Create Azure Container Registry
echo "📋 Creating Azure Container Registry..."
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic

# Step 4: Log in to ACR and push image
echo "🔐 Logging into ACR..."
az acr login --name $ACR_NAME

echo "🏷️ Tagging and pushing image..."
docker tag ${IMAGE_NAME}:latest ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest
docker push ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest

# Step 5: Get ACR credentials
echo "🔑 Getting ACR credentials..."
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value --output tsv)

# Step 6: Create App Service plan
echo "📱 Creating App Service plan..."
az appservice plan create --name $APP_SERVICE_PLAN --resource-group $RESOURCE_GROUP --is-linux --sku B1

# Step 7: Create Web App
echo "🌐 Creating Web App..."
az webapp create \
    --resource-group $RESOURCE_GROUP \
    --plan $APP_SERVICE_PLAN \
    --name $WEB_APP_NAME \
    --deployment-container-image-name ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest

# Step 8: Configure ACR authentication
echo "🔧 Configuring ACR authentication..."
az webapp config container set \
    --name $WEB_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --docker-custom-image-name ${ACR_NAME}.azurecr.io/${IMAGE_NAME}:latest \
    --docker-registry-server-url https://${ACR_NAME}.azurecr.io \
    --docker-registry-server-user $ACR_USERNAME \
    --docker-registry-server-password $ACR_PASSWORD

# Step 9: Get the app URL
APP_URL=$(az webapp show --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP --query defaultHostName --output tsv)

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📍 Your app is deployed at: https://${APP_URL}"
echo ""
echo "🔧 Next steps (to be done in Azure Portal):"
echo "   1. Configure environment variables and secrets"
echo "   2. Enable HTTPS enforcement"
echo "   3. Set up monitoring and logs"
echo ""
echo "📱 Update your Flutter app's API endpoint to: https://${APP_URL}"
echo "" 