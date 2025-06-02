# Azure Multi-Service Backend Deployment Guide

This guide provides step-by-step instructions for deploying the Insurance App's multi-service backend (RAG, OCR, and Frontend services) to Azure App Service. It also covers necessary prerequisites like Azure Cache for Redis and a publicly accessible Qdrant vector database.

---

## Table of Contents
1.  [Architectural Overview](#architectural-overview)
2.  [Prerequisites](#prerequisites)
    *   [Azure Setup](#azure-setup)
    *   [Qdrant Vector Database](#qdrant-vector-database)
    *   [Azure Cache for Redis](#azure-cache-for-redis)
    *   [API Keys & Tokens](#api-keys--tokens)
    *   [Docker & Code](#docker--code)
3.  [General Azure Resources Setup](#general-azure-resources-setup)
    *   [Resource Group](#resource-group)
    *   [Azure Container Registry (ACR)](#azure-container-registry-acr)
4.  [Building and Pushing the Docker Image](#building-and-pushing-the-docker-image)
5.  [Service Deployment Strategy](#service-deployment-strategy)
6.  [Phase 1: Deploying the RAG Service (`rag_service`)](#phase-1-deploying-the-rag-service-rag_service)
    *   [Create App Service for RAG](#create-app-service-for-rag)
    *   [Configure RAG Service](#configure-rag-service)
    *   [Test RAG Service](#test-rag-service)
7.  [Phase 2: Deploying the OCR Service (`ocr_service`)](#phase-2-deploying-the-ocr-service-ocr_service)
    *   [Create App Service for OCR](#create-app-service-for-ocr)
    *   [Configure OCR Service](#configure-ocr-service)
    *   [Test OCR Service](#test-ocr-service)
8.  [Phase 3: Deploying the Frontend Service (`frontend`)](#phase-3-deploying-the-frontend-service-frontend)
    *   [Create App Service for Frontend](#create-app-service-for-frontend)
    *   [Configure Frontend Service](#configure-frontend-service)
    *   [Test Frontend Service](#test-frontend-service)
9.  [Updating the Flutter Mobile App](#updating-the-flutter-mobile-app)
10. [Monitoring and Logging](#monitoring-and-logging)
11. [Troubleshooting](#troubleshooting)

---

## 1. Architectural Overview

The backend consists of three main services:
-   **`rag_service`**: Handles Retrieval Augmented Generation for answering queries. It depends on Qdrant and Redis.
-   **`ocr_service`**: Processes uploaded documents using OCR and ingests data into the RAG system. It depends on Redis and `rag_service`.
-   **`frontend`**: Provides the API layer that the mobile app interacts with. It orchestrates calls to `ocr_service` and `rag_service`.

All three services are built from the same root `Dockerfile` but run with different startup commands and configurations.

---

## 2. Prerequisites

### Azure Setup
-   An Azure account with an active subscription.
-   Azure CLI installed and logged in (`az login`).
-   Permissions to create and manage resources (Resource Groups, App Services, ACR, Cache for Redis).

### Qdrant Vector Database
-   A running Qdrant instance accessible via a public URL (e.g., `http://your-qdrant-host.com:6333` or `https://your-qdrant-host.com`).
-   **Options for Qdrant on Azure:**
    *   **Azure Container Instances (ACI):** Deploy the official Qdrant Docker image.
    *   **Azure Kubernetes Service (AKS):** For more complex setups.
    *   **Virtual Machine (VM):** Install Docker and run Qdrant.
    *   **Qdrant Cloud:** Consider using Qdrant's managed cloud offering.
-   Refer to the [official Qdrant documentation](https://qdrant.tech/documentation/cloud/ or https://qdrant.tech/documentation/guides/installation/) for setup.
-   You will need the **public hostname/IP** and **port** (default is 6333 for HTTP, 6334 for gRPC) of your Qdrant instance.

### Azure Cache for Redis
-   An Azure Cache for Redis instance. You can create one through the Azure portal or CLI.
    ```bash
    # Example: Create a Basic C0 Azure Cache for Redis (adjust name, location, sku)
    # az redis create --location eastus --name YourRedisCacheName --resource-group YourResourceGroupName --sku Basic --vm-size c0
    ```
-   You will need its **hostname** (e.g., `yourrediscachename.redis.cache.windows.net`) and an **access key** (Primary or Secondary). These can be found in the Azure portal under your Redis instance's "Access keys" section. The default port is 6379 (non-SSL) or 6380 (SSL). For simplicity, App Service can connect over non-SSL within Azure, but SSL is recommended for production.

### API Keys & Tokens
-   **OpenAI API Key**: Required by `rag_service` and `ocr_service` (if using OpenAI models).
-   **Hugging Face Token (`HF_TOKEN`)**: Potentially required by `rag_service` and `ocr_service` (if using Hugging Face models).
-   Keep these keys secure. You will configure them as Application Settings in Azure App Service.

### Docker & Code
-   Docker Desktop installed locally for building and pushing the image.
-   The application source code.

---

## 3. General Azure Resources Setup

### Resource Group
If you don't have one already, create a resource group to hold all your application's Azure resources.
```bash
az group create --name insurance-app-backend-rg --location eastus # Choose your preferred location
```
Let's use `insurance-app-backend-rg` as the resource group name for this guide.

### Azure Container Registry (ACR)
Create an ACR instance to store your Docker images.
```bash
az acr create --resource-group insurance-app-backend-rg --name insuranceappacr --sku Basic --admin-enabled true
# Note: Using the same ACR 'insuranceappacr' as in previous simple app deployment. If it exists, you can skip this.
# --admin-enabled true is useful for getting credentials easily for App Service.
```
Log in to your ACR:
```bash
az acr login --name insuranceappacr
```

---

## 4. Building and Pushing the Docker Image

All three services (`rag_service`, `ocr_service`, `frontend`) are built from the main `Dockerfile` at the project root. We will build one image and use different startup commands for each service in App Service.

**Image Name:** `insuranceappacr.azurecr.io/insurance-app-services:v1` (or your preferred tag)

```bash
# Ensure you are in the project root directory
# Build for AMD64 architecture, which Azure App Service on Linux uses
docker buildx build --platform linux/amd64 -t insuranceappacr.azurecr.io/insurance-app-services:v1 -f Dockerfile .
docker push insuranceappacr.azurecr.io/insurance-app-services:v1
```
If `docker buildx` is not set up, you might need to run `docker buildx create --use` first. For non-Apple Silicon machines, `docker build ...` might suffice, but building explicitly for `linux/amd64` is safer.

---

## 5. Service Deployment Strategy

We will deploy the services in the following order due to their dependencies:
1.  **`rag_service`**: Base service, needs Qdrant and Redis.
2.  **`ocr_service`**: Depends on Redis and the deployed `rag_service`.
3.  **`frontend`**: Depends on the deployed `ocr_service` and `rag_service`.

For each service, we will create a new Azure App Service instance on Linux.

---

## 6. Phase 1: Deploying the RAG Service (`rag_service`)

This service runs `src.rag.service:app` on port `8000`.

### Create App Service for RAG
-   **App Service Plan:** If you don't have one, create it.
    ```bash
    az appservice plan create --name insurance-app-plan --resource-group insurance-app-backend-rg --is-linux --sku B1 # Choose a suitable SKU
    # Note: Using 'insurance-app-plan' from previous simple app deployment. If it exists, you can skip this.
    ```
-   **App Service Name:** `insurance-rag-app` (choose a globally unique name)
    ```bash
    az webapp create --resource-group insurance-app-backend-rg \\
        --plan insurance-app-plan \\
        --name insurance-rag-app \\
        --deployment-container-image-name insuranceappacr.azurecr.io/insurance-app-services:v1
    ```

### Configure RAG Service
Configure container settings, startup command, port, and environment variables.

-   **Container & ACR Credentials:**
    ```bash
    ACR_USERNAME=$(az acr credential show --name insuranceappacr --query "username" -o tsv)
    ACR_PASSWORD=$(az acr credential show --name insuranceappacr --query "passwords[0].value" -o tsv)

    az webapp config container set --name insurance-rag-app --resource-group insurance-app-backend-rg \\
        --docker-custom-image-name insuranceappacr.azurecr.io/insurance-app-services:v1 \\
        --docker-registry-server-url https://insuranceappacr.azurecr.io \\
        --docker-registry-server-user "$ACR_USERNAME" \\
        --docker-registry-server-password "$ACR_PASSWORD"
    ```
-   **Startup Command & Port:**
    The `rag_service` uses `src.rag.service:app` and runs on port `8000`.
    ```bash
    az webapp config set --resource-group insurance-app-backend-rg --name insurance-rag-app \\
        --startup-command "uvicorn src.rag.service:app --host 0.0.0.0 --port 8000"
    ```
-   **Application Settings (Environment Variables):**
    Replace placeholder values with your actual service details.
    ```bash
    az webapp config appsettings set --resource-group insurance-app-backend-rg --name insurance-rag-app --settings \\
        WEBSITES_PORT="8000" \\
        PYTHONPATH="/app" \\
        PYTHONUNBUFFERED="1" \\
        QDRANT_HOST="YOUR_QDRANT_PUBLIC_HOSTNAME_OR_IP" \\
        QDRANT_PORT="6333" \\
        REDIS_HOST="YOUR_AZURE_REDIS_HOSTNAME" \\
        REDIS_PORT="6379" \\
        # For secrets, it's best to add them via Azure Portal or Azure Key Vault for production.
        # The script will set them as placeholders if you run this directly.
        OPENAI_API_KEY="YOUR_OPENAI_API_KEY_PLACEHOLDER" \\
        HF_TOKEN="YOUR_HF_TOKEN_PLACEHOLDER"
    ```
    **Important:** Go to the Azure Portal, navigate to your `insurance-rag-app` App Service -> Configuration -> Application settings, and securely set the actual values for `OPENAI_API_KEY` and `HF_TOKEN`.

### Test RAG Service
-   After configuration, the app will restart. Check the logs:
    ```bash
    az webapp log tail --resource-group insurance-app-backend-rg --name insurance-rag-app
    ```
-   Find the public URL (e.g., `https://insurance-rag-app.azurewebsites.net`) in the App Service overview page.
-   Test its health endpoint: `curl https://insurance-rag-app.azurewebsites.net/health` (or whichever health endpoint is defined in `src/rag/service.py`).

---

## 7. Phase 2: Deploying the OCR Service (`ocr_service`)

This service runs `src.ocr.service:app` on port `8001`. It depends on Redis and the `rag_service`.

### Create App Service for OCR
-   **App Service Name:** `insurance-ocr-app` (choose a globally unique name)
    ```bash
    az webapp create --resource-group insurance-app-backend-rg \\
        --plan insurance-app-plan \\
        --name insurance-ocr-app \\
        --deployment-container-image-name insuranceappacr.azurecr.io/insurance-app-services:v1
    ```

### Configure OCR Service
-   **Container & ACR Credentials:** (Similar to RAG service, just change app name)
    ```bash
    # ACR_USERNAME and ACR_PASSWORD should still be set from the RAG setup.
    az webapp config container set --name insurance-ocr-app --resource-group insurance-app-backend-rg \\
        --docker-custom-image-name insuranceappacr.azurecr.io/insurance-app-services:v1 \\
        --docker-registry-server-url https://insuranceappacr.azurecr.io \\
        --docker-registry-server-user "$ACR_USERNAME" \\
        --docker-registry-server-password "$ACR_PASSWORD"
    ```
-   **Startup Command & Port:**
    The `ocr_service` uses `src.ocr.service:app` and runs on port `8001`.
    ```bash
    az webapp config set --resource-group insurance-app-backend-rg --name insurance-ocr-app \\
        --startup-command "uvicorn src.ocr.service:app --host 0.0.0.0 --port 8001"
    ```
-   **Application Settings (Environment Variables):**
    You'll need the public URL of the `insurance-rag-app` deployed in Phase 1.
    ```bash
    RAG_SERVICE_PUBLIC_URL="https://insurance-rag-app.azurewebsites.net" # Replace if your RAG app URL is different

    az webapp config appsettings set --resource-group insurance-app-backend-rg --name insurance-ocr-app --settings \\
        WEBSITES_PORT="8001" \\
        PYTHONPATH="/app" \\
        PYTHONUNBUFFERED="1" \\
        REDIS_HOST="YOUR_AZURE_REDIS_HOSTNAME" \\
        REDIS_PORT="6379" \\
        RAG_SERVICE_URL="$RAG_SERVICE_PUBLIC_URL" \\
        OPENAI_API_KEY="YOUR_OPENAI_API_KEY_PLACEHOLDER" \\
        HF_TOKEN="YOUR_HF_TOKEN_PLACEHOLDER"
    ```
    **Important:** Securely set `OPENAI_API_KEY` and `HF_TOKEN` in the Azure Portal for `insurance-ocr-app`.

### Test OCR Service
-   Check logs: `az webapp log tail --resource-group insurance-app-backend-rg --name insurance-ocr-app`
-   Test its health endpoint: `curl https://insurance-ocr-app.azurewebsites.net/health` (or its defined health endpoint).

---

## 8. Phase 3: Deploying the Frontend Service (`frontend`)

This service runs `src.frontend.app:app` on port `8080`. It depends on `ocr_service` and `rag_service`. This will be the main endpoint for your Flutter app.

### Create App Service for Frontend
-   **App Service Name:** `insurance-frontend-app` (choose a globally unique name)
    ```bash
    az webapp create --resource-group insurance-app-backend-rg \\
        --plan insurance-app-plan \\
        --name insurance-frontend-app \\
        --deployment-container-image-name insuranceappacr.azurecr.io/insurance-app-services:v1
    ```

### Configure Frontend Service
-   **Container & ACR Credentials:** (Similar, just change app name)
    ```bash
    az webapp config container set --name insurance-frontend-app --resource-group insurance-app-backend-rg \\
        --docker-custom-image-name insuranceappacr.azurecr.io/insurance-app-services:v1 \\
        --docker-registry-server-url https://insuranceappacr.azurecr.io \\
        --docker-registry-server-user "$ACR_USERNAME" \\
        --docker-registry-server-password "$ACR_PASSWORD"
    ```
-   **Startup Command & Port:**
    The `frontend` service uses `src.frontend.app:app` and runs on port `8080`.
    ```bash
    az webapp config set --resource-group insurance-app-backend-rg --name insurance-frontend-app \\
        --startup-command "uvicorn src.frontend.app:app --host 0.0.0.0 --port 8080"
    ```
-   **Application Settings (Environment Variables):**
    You'll need the public URLs of `insurance-rag-app` and `insurance-ocr-app`.
    ```bash
    # RAG_SERVICE_PUBLIC_URL should still be set from OCR setup.
    OCR_SERVICE_PUBLIC_URL="https://insurance-ocr-app.azurewebsites.net" # Replace if your OCR app URL is different

    az webapp config appsettings set --resource-group insurance-app-backend-rg --name insurance-frontend-app --settings \\
        WEBSITES_PORT="8080" \\
        PYTHONPATH="/app" \\
        PYTHONUNBUFFERED="1" \\
        OCR_SERVICE_URL="$OCR_SERVICE_PUBLIC_URL" \\
        RAG_SERVICE_URL="$RAG_SERVICE_PUBLIC_URL"
        # Add any other specific env vars the frontend might need directly.
    ```

### Test Frontend Service
-   Check logs: `az webapp log tail --resource-group insurance-app-backend-rg --name insurance-frontend-app`
-   Test its health endpoint: `curl https://insurance-frontend-app.azurewebsites.net/health`.
-   Test other endpoints like `/` to see if the HTML page loads.

---

## 9. Updating the Flutter Mobile App

Once `insurance-frontend-app` is deployed and tested:
1.  Get its public URL: `https://insurance-frontend-app.azurewebsites.net`.
2.  Open your Flutter project: `mobile/lib/services/api_service.dart`.
3.  Update the `baseUrl` variable:
    ```dart
    // static const String baseUrl = 'http://172.21.0.237:8080'; // Old local IP
    static const String baseUrl = 'https://insurance-frontend-app.azurewebsites.net'; // Your new Azure Frontend URL
    ```
4.  Rebuild and redeploy your Flutter application. It should now communicate with your Azure-hosted backend.

---

## 10. Monitoring and Logging

-   Use **Azure Monitor** and **Application Insights** for advanced monitoring, performance tracking, and distributed tracing across your services.
-   Regularly check **App Service Logs** (accessible via Azure Portal or `az webapp log tail`) for each service, especially during deployment and testing.

---

## 11. Troubleshooting

-   **"Application Error"**: Check App Service logs. Common causes:
    *   Incorrect startup command.
    *   Application crashing due to missing environment variables or inability to connect to dependencies (Qdrant, Redis, other services).
    *   Incorrect `WEBSITES_PORT` configuration.
    *   Issues within the Docker image or application code.
-   **Image Pull Errors**: Ensure ACR admin user is enabled, credentials are correct in App Service config, and the image name/tag is exact. Check "Deployment Center" logs in App Service.
-   **CORS Issues**: If the Flutter app (when run in a browser) or other web clients can't connect, you might need to configure CORS settings on the `insurance-frontend-app` App Service. The FastAPI `CORSMiddleware` in `src/frontend/app.py` is set to allow all origins (`"*"`), which is permissive for development but should be restricted for production.
-   **Service Inter-communication**:
    *   Ensure dependent service URLs in environment variables are correct (using `https://` and the `.azurewebsites.net` domain).
    *   Check logs of both caller and callee services if one service fails to reach another.
-   **Multi-arch build issues**: The guide recommends building for `linux/amd64`. If you see manifest errors, ensure your Docker build command targets this platform.

This guide provides a comprehensive path. Take it step by step, and test each service thoroughly after deployment. 