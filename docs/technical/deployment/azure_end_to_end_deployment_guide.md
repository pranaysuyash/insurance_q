# End-to-End Deployment Guide: Azure Backend & Play Store Mobile App

This guide provides a step-by-step process for deploying the Insurance App backend to Microsoft Azure, publishing the Flutter mobile app to the Google Play Store, and securely connecting the two. It also covers best practices for API key management and secure integration.

---

## Table of Contents
1. [Backend Deployment to Azure](#backend-deployment-to-azure)
2. [Mobile App Deployment to Play Store](#mobile-app-deployment-to-play-store)
3. [Syncing Mobile App with Azure Backend](#syncing-mobile-app-with-azure-backend)
4. [API Key Security & Best Practices](#api-key-security--best-practices)
5. [References & Further Reading](#references--further-reading)

---

## Backend Deployment to Azure

> **For detailed infrastructure, scaling, and CI/CD, see [`azure_deployment_strategies.md`](./azure_deployment_strategies.md).**

### 1. Prerequisites
- Azure account with sufficient permissions
- Azure CLI installed
- Docker installed (for container builds)
- Source code access

### 2. Resource Provisioning (Quickstart)
- Create a resource group:
  ```sh
  az group create --name insurance-app-rg --location eastus
  ```
- Create Azure Container Registry (ACR):
  ```sh
  az acr create --resource-group insurance-app-rg --name insuranceappacr --sku Standard
  ```
- Create AKS cluster:
  ```sh
  az aks create --resource-group insurance-app-rg --name insurance-app-aks --node-count 3 --enable-managed-identity --generate-ssh-keys
  ```
- Connect AKS to ACR:
  ```sh
  az aks update -n insurance-app-aks -g insurance-app-rg --attach-acr insuranceappacr
  ```

### 3. Build & Push Docker Image
- Build and push your backend image:
  ```sh
  az acr login --name insuranceappacr
  docker build -t insuranceappacr.azurecr.io/insurance-app-api:latest .
  docker push insuranceappacr.azurecr.io/insurance-app-api:latest
  ```

### 4. Deploy to AKS
- Prepare Kubernetes manifests (`deployment.yaml`, `service.yaml`).
- Apply manifests:
  ```sh
  az aks get-credentials --resource-group insurance-app-rg --name insurance-app-aks
  kubectl apply -f kubernetes/deployment.yaml
  kubectl apply -f kubernetes/service.yaml
  ```

### 5. Expose API Endpoint
- Use a LoadBalancer service or Ingress to expose your API.
- Get the external IP:
  ```sh
  kubectl get svc
  ```
- Ensure HTTPS is enabled (use cert-manager or Azure Application Gateway for TLS).

---

## Mobile App Deployment to Play Store

### 1. Prerequisites
- Google Play Developer account
- Flutter environment set up
- Android keystore for signing

### 2. Prepare the App for Release
- Update `android/app/build.gradle`:
  - Set `applicationId`, `versionCode`, `versionName`.
- Generate a release keystore (if not already):
  ```sh
  keytool -genkey -v -keystore ~/my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
  ```
- Add keystore config to `android/key.properties` and reference in `build.gradle`.
- Run:
  ```sh
  flutter clean
  flutter build apk --release
  flutter build appbundle --release
  ```

### 3. Test the Release Build
- Install the APK on a device:
  ```sh
  flutter install
  ```
- Verify all features, especially API connectivity.

### 4. Upload to Play Console
- Go to [Google Play Console](https://play.google.com/console/)
- Create a new app or select your app
- Upload the `.aab` (Android App Bundle) file
- Fill in store listing, content rating, privacy policy, etc.
- Submit for review and publish

---

## Syncing Mobile App with Azure Backend

### 1. Configure API Endpoint
- In your Flutter app, set the API base URL to the Azure LoadBalancer/Ingress public IP or DNS.
- Use environment variables or a config file for endpoint management (e.g., `lib/services/api_service.dart`).
- For production, use the HTTPS endpoint.

#### Example (Dart):
```dart
const String apiBaseUrl = 'https://<your-azure-api-endpoint>/';
```
- For dev/testing, use a separate config or `.env` file.

### 2. Environment Switching
- Use build flavors or environment variables to switch between dev, staging, and prod endpoints.
- Example: Use `flutter_dotenv` or similar package for environment management.

### 3. Connectivity Checklist
- Ensure CORS is correctly configured on the backend (restrict origins in production).
- Test connectivity from a real device (not just emulator).
- Handle network errors gracefully in the app.

---

## API Key Security & Best Practices

### 1. Never Embed Sensitive Keys in the Mobile App
- Do **not** hardcode API keys, secrets, or credentials in the Flutter app.
- Use backend authentication (e.g., Firebase Auth, OAuth2) and issue short-lived tokens.

### 2. Use Azure Key Vault for Backend Secrets
- Store all sensitive keys (OpenAI, database, etc.) in Azure Key Vault.
- Reference secrets in your backend deployment (see [azure_deployment_strategies.md](./azure_deployment_strategies.md)).

### 3. Secure Mobile-Backend Communication
- Use HTTPS for all API calls.
- Authenticate users via secure tokens (JWT, Firebase, etc.).
- Validate tokens on the backend for every request.

### 4. Rotate and Monitor Keys
- Regularly rotate API keys and credentials.
- Monitor for suspicious access patterns.

### 5. Additional Security Resources
- See [`security_considerations.md`](../implementation/security_considerations.md) for encryption, authentication, and authorization details.

---

## References & Further Reading
- [Azure Deployment Strategies (detailed)](./azure_deployment_strategies.md)
- [Security Considerations](../implementation/security_considerations.md)
- [Flutter: Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Azure Key Vault Documentation](https://learn.microsoft.com/en-us/azure/key-vault/)
- [Kubernetes on Azure](https://learn.microsoft.com/en-us/azure/aks/)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer/)

---

**For advanced topics (scaling, monitoring, disaster recovery), see the referenced documents above.** 