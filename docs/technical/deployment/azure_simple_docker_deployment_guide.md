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
- **Note on Architecture**: If your development machine (e.g., Apple Silicon M1/M2/M3, which is ARM64) has a different architecture than your Azure App Service target (Linux on App Service is typically AMD64), you **must** build a multi-architecture image. See the "Troubleshooting & Key Considerations" section below for details on using `docker buildx`.

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
  - **Multi-arch images**: If you built a multi-arch image using `docker buildx`, the `--push` flag in the `buildx` command handles pushing the manifest and images.

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
  Ensure you replace `<your-app-name>`, `<ACR-USERNAME>`, and `<ACR-PASSWORD>` with your actual values.
  ```sh
  az webapp config container set --name <your-app-name> --resource-group insurance-app-rg \
    --docker-custom-image-name insuranceappacr.azurecr.io/insurance-app-api:latest \
    --docker-registry-server-url https://insuranceappacr.azurecr.io \
    --docker-registry-server-user <ACR-USERNAME> \
    --docker-registry-server-password <ACR-PASSWORD>
  ```
  - Get credentials with:
    ```sh
    az acr credential show --name insuranceappacr --query "{username:username, password:passwords[0].value}"
    ```
  - **Important for ACR Authentication**: While the command above is standard, it's highly recommended to set the `DOCKER_REGISTRY_SERVER_PASSWORD` as an application setting in the App Service for more reliable authentication, especially if you encounter "unauthorized" errors. See "Troubleshooting & Key Considerations".

### 5. Configure Environment Variables & Secrets
- In Azure Portal, go to your Web App > Configuration > Application settings.
- Add environment variables (API keys, DB URLs, etc.).
- **Never hardcode secrets in your code or Dockerfile.**

### 6. Enable HTTPS
- By default, Azure App Service provides HTTPS. Enforce HTTPS in the portal (TLS/SSL settings).

### 7. Get Your API Endpoint
- Find your app's public URL in the Azure Portal (e.g., `https://<your-app-name>.azurewebsites.net`).

### 8. Troubleshooting & Key Considerations

This section covers common issues and important points based on recent deployment experiences with a simple test application (`Dockerfile.simple`, `src/simple_app.py`).

- **Multi-Architecture Docker Builds**:
    - **Problem**: Azure App Service for Linux typically runs on `amd64` architecture. If your Docker image is built on a different architecture (e.g., `arm64` on Apple Silicon) and only contains a manifest for that architecture, App Service will fail to pull/run the image, often with errors like `no matching manifest for linux/amd64`.
    - **Solution**: Use `docker buildx` to build and push a multi-architecture image.
      ```bash
      # Ensure buildx is enabled (usually default on Docker Desktop)
      docker buildx create --use

      # Example: Build and push for linux/amd64 and linux/arm64
      # Replace 'your-image-name:tag' and 'your-dockerfile' as needed.
      # The '.' at the end specifies the build context (current directory).
      docker buildx build --platform linux/amd64,linux/arm64 \
        -t youracrname.azurecr.io/your-image-name:tag \
        -f YourDockerfile \
        --push .
      ```
    - For the simple test app (`insurance-app-simple:v2`), the script `scripts/build_push_multiarch.sh` was created to automate this.

- **ACR Authentication Failures**:
    - **Problem**: Even with apparently correct credentials, Azure App Service might fail to authenticate with ACR, leading to "unauthorized" errors in the logs when trying to pull the image.
    - **Solution**: Explicitly set the ACR password as an application setting in the App Service.
      1. Get your ACR password:
         ```bash
         ACR_PASSWORD=$(az acr credential show --name youracrname --query "passwords[0].value" -o tsv)
         ```
      2. Set it in App Service (replace `your-app-name`, `your-resource-group`):
         ```bash
         az webapp config appsettings set \
           --resource-group your-resource-group \
           --name your-app-name \
           --settings DOCKER_REGISTRY_SERVER_PASSWORD="$ACR_PASSWORD"
         ```
      3. Configure the container to use the ACR username but *omit* the password from the `az webapp config container set` command if you've set it via app settings. The App Service will use the `DOCKER_REGISTRY_SERVER_PASSWORD` app setting.
         ```bash
         az webapp config container set \
           --resource-group your-resource-group \
           --name your-app-name \
           --container-image-name youracrname.azurecr.io/your-image-name:tag \
           --container-registry-url https://youracrname.azurecr.io \
           --container-registry-user youracrusername
           # Password is intentionally omitted here
         ```
    - The script `scripts/azure_configure_app.sh` for the simple test app demonstrates this approach.

- **Port Configuration**:
    - Ensure your Dockerfile `EXPOSE`s the correct port (e.g., `EXPOSE 80` or `EXPOSE 8000`).
    - Ensure your application inside the container listens on that same port (e.g., Uvicorn's `--port` argument).
    - Azure App Service typically expects web apps to be listening on port 80 or 8080. If you use a different port, you might need to set the `WEBSITES_PORT` application setting in App Service to your application's port (e.g., `WEBSITES_PORT=8000`). For the simple test app, port 80 was used.

- **Startup Command**:
    - If your `Dockerfile`'s `CMD` or `ENTRYPOINT` is not being picked up correctly, or if you need to override it, you can set a "Startup Command" in the Azure App Service configuration (under Configuration > General settings > Startup Command). For a FastAPI app with Uvicorn, this might look like: `uvicorn src.app.main:app --host 0.0.0.0 --port 80` (adjust path and port as needed).

- **Logging**:
    - Enable detailed application and web server logging in Azure App Service (App Service Logs blade in the portal, or via Azure CLI) to help diagnose startup issues.
    - Use `az webapp log tail --resource-group <rg> --name <app-name>` to stream live logs.

- **Helper Scripts for Simple App Deployment**:
    - `scripts/build_push_multiarch.sh`: Automates building and pushing a multi-arch image for the simple test app (`Dockerfile.simple`).
    - `scripts/azure_configure_app.sh`: Automates configuring Azure App Service for the simple test app, including setting ACR credentials correctly and enabling logging. These scripts serve as a good reference for the full application deployment.

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