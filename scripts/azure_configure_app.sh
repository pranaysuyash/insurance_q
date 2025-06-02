#!/bin/bash
set -e

RESOURCE_GROUP="insurance-app-rg"
APP_NAME="insurance-policy-app"
ACR_NAME="insuranceappacr"
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
IMAGE_NAME="${ACR_LOGIN_SERVER}/insurance-app-simple:v2"

echo "Fetching ACR credentials..."
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

echo "Setting ACR password explicitly as app setting..."
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --settings DOCKER_REGISTRY_SERVER_PASSWORD="$ACR_PASSWORD"

echo "Setting container image and registry URL + username..."
az webapp config container set \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --container-image-name $IMAGE_NAME \
  --container-registry-url "https://${ACR_LOGIN_SERVER}" \
  --container-registry-user $ACR_USERNAME

echo "Enabling detailed logging..."
az webapp log config \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --application-logging filesystem \
  --level verbose \
  --detailed-error-messages true \
  --failed-request-tracing true

echo "Restarting the Azure App Service..."
az webapp restart --resource-group $RESOURCE_GROUP --name $APP_NAME

echo "Done. Use 'az webapp log tail --resource-group $RESOURCE_GROUP --name $APP_NAME' to view logs." 