#!/bin/bash

# Variables — update these as needed
RESOURCE_GROUP="insurance-app-rg"
APP_NAME="insurance-policy-app"
ACR_NAME="insuranceappacr"
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
IMAGE_NAME="${ACR_LOGIN_SERVER}/insurance-app-simple:v2"

# Fetch ACR admin user credentials
echo "Fetching ACR admin username and password..."
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

echo "ACR Username: $ACR_USERNAME"
# Do not echo password for security reasons

# Configure App Service to use container image and ACR credentials
echo "Setting container configuration on App Service..."
az webapp config container set \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --container-image-name $IMAGE_NAME \
  --container-registry-url "https://${ACR_LOGIN_SERVER}" \
  --container-registry-user $ACR_USERNAME \
  --container-registry-password "$ACR_PASSWORD"

# Enable verbose logging and detailed error messages
echo "Enabling detailed logging..."
az webapp log config \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --application-logging filesystem \
  --level verbose \
  --detailed-error-messages true \
  --failed-request-tracing true

# Restart the App Service to apply changes
echo "Restarting App Service..."
az webapp restart --resource-group $RESOURCE_GROUP --name $APP_NAME

echo "Setup complete. Use 'az webapp log tail' to view live logs." 