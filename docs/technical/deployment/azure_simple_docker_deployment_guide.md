# Simple Azure Deployment Guide (No Kubernetes)

This guide explains how to deploy the Insurance App backend to Azure using only Docker and Azure App Service for Containers (no Kubernetes), and how to connect your Flutter mobile app. This is ideal for small, single-functionality apps.

---

## Table of Contents
1. [Backend Deployment to Azure App Service](#backend-deployment-to-azure-app-service)
2. [Mobile App Deployment to Play Store](#mobile-app-deployment-to-play-store)
3. [Syncing Mobile App with Azure Backend](#syncing-mobile-app-with-azure-backend)
4. [API Key Security & Best Practices](#api-key-security--best-practices)
5. [References & Further Reading](#references--further-reading)

---

## Backend Deployment to Azure App Service

### 1. Prerequisites
- Azure account with permissions
- Azure CLI installed
- Docker installed
- Source code access

### 2. Build Docker Image
- In your project root, build the Docker image:
  ```sh
  docker build -t insurance-app-api:latest .
  ```

### 3. Push Image to Azure Container Registry (ACR)
- Create a resource group (if not already):
  ```sh
  az group create --name insurance-app-rg --location eastus
  ```
- Create ACR:
  ```sh
  az acr create --resource-group insurance-app-rg --name insuranceappacr --sku Basic
  ```
- Log in and tag your image:
  ```sh
  az acr login --name insuranceappacr
  docker tag insurance-app-api:latest insuranceappacr.azurecr.io/insurance-app-api:latest
  docker push insuranceappacr.azurecr.io/insurance-app-api:latest
  ```

### 4. Create Azure App Service for Containers
- Create an App Service plan:
  ```sh
  az appservice plan create --name insurance-app-plan --resource-group insurance-app-rg --is-linux --sku B1
  ```
- Create the Web App:
  ```sh
  az webapp create --resource-group insurance-app-rg --plan insurance-app-plan --name <your-app-name> --deployment-container-image-name insuranceappacr.azurecr.io/insurance-app-api:latest
  ```
- Configure ACR authentication for the Web App:
  ```sh
  az webapp config container set --name <your-app-name> --resource-group insurance-app-rg \
    --docker-custom-image-name insuranceappacr.azurecr.io/insurance-app-api:latest \
    --docker-registry-server-url https://insuranceappacr.azurecr.io \
    --docker-registry-server-user <ACR-USERNAME> \
    --docker-registry-server-password <ACR-PASSWORD>
  ```
  - Get credentials with:
    ```sh
    az acr credential show --name insuranceappacr
    ```

### 5. Configure Environment Variables & Secrets
- In Azure Portal, go to your Web App > Configuration > Application settings.
- Add environment variables (API keys, DB URLs, etc.).
- **Never hardcode secrets in your code or Dockerfile.**

### 6. Enable HTTPS
- By default, Azure App Service provides HTTPS. Enforce HTTPS in the portal (TLS/SSL settings).

### 7. Get Your API Endpoint
- Find your app's public URL in the Azure Portal (e.g., `https://<your-app-name>.azurewebsites.net`).

---

## Mobile App Deployment to Play Store

_Same as in the main guide:_

1. Prepare your Flutter app for release (signing, build, test).
2. Upload the `.aab` file to the Google Play Console.
3. Fill in store listing, privacy policy, etc.
4. Publish.

See [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android) for details.

---

## Syncing Mobile App with Azure Backend

1. In your Flutter app, set the API base URL to your Azure App Service public URL.
   ```dart
   const String apiBaseUrl = 'https://<your-app-name>.azurewebsites.net/';
   ```
2. Use environment variables or config files for endpoint management.
3. For dev/testing, use a separate config or `.env` file.
4. Ensure CORS is enabled for your mobile app's domain (see backend CORS settings).
5. Test connectivity from a real device.

---

## API Key Security & Best Practices

- **Never embed API keys or secrets in the mobile app.**
- Store all sensitive keys in Azure App Service configuration or Azure Key Vault.
- Use HTTPS for all API calls.
- Authenticate users via secure tokens (JWT, Firebase, etc.).
- Rotate and monitor keys regularly.
- See [`security_considerations.md`](../implementation/security_considerations.md) for more.

---

## References & Further Reading
- [Azure App Service for Containers](https://learn.microsoft.com/en-us/azure/app-service/containers/)
- [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/)
- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Security Considerations](../implementation/security_considerations.md)

---

**This guide is for small-scale, single-functionality apps. For scaling, monitoring, and advanced features, see the main Azure deployment guide.** 