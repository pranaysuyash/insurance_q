# Azure Portal UI Guide: Post-Deployment Configuration

This guide walks you through the Azure Portal UI steps needed after running the deployment script. These steps include configuring environment variables, enabling HTTPS, and setting up monitoring.

---

## Prerequisites
✅ You've run the `scripts/deploy_to_azure.sh` script successfully  
✅ Your app is deployed and running  
✅ You have the app URL from the script output  

---

## Step 1: Configure Environment Variables & Secrets

### 1.1 Navigate to Your App Service
1. Go to [Azure Portal](https://portal.azure.com)
2. Search for "App Services" in the top search bar
3. Click on your app service (default name: `insurance-policy-app`)

### 1.2 Add Application Settings
1. In the left sidebar, click **"Configuration"**
2. Click **"+ New application setting"**
3. Add these environment variables one by one:

| Name | Value | Description |
|------|-------|-------------|
| `OPENAI_API_KEY` | `your-openai-api-key` | Your OpenAI API key |
| `FIREBASE_CREDENTIALS` | `your-firebase-json` | Firebase service account JSON |
| `DATABASE_URL` | `your-db-connection-string` | Database connection string |
| `REDIS_URL` | `your-redis-connection` | Redis connection string |
| `ENVIRONMENT` | `production` | Environment indicator |

4. Click **"Save"** at the top after adding all variables
5. Click **"Continue"** when prompted (this will restart your app)

### 1.3 Secure Secrets (Recommended)
For sensitive values, use **Key Vault references**:
1. Create an Azure Key Vault (if you don't have one)
2. Store secrets in Key Vault
3. Reference them in App Settings like: `@Microsoft.KeyVault(SecretUri=https://your-vault.vault.azure.net/secrets/your-secret/)`

---

## Step 2: Enable HTTPS Enforcement

### 2.1 Configure TLS/SSL Settings
1. In your App Service, go to **"TLS/SSL settings"** in the left sidebar
2. Under **"HTTPS Only"**, toggle to **"On"**
3. Under **"Minimum TLS Version"**, select **"1.2"**
4. Click **"Save"**

### 2.2 Test HTTPS Access
1. Go to your app URL: `https://your-app-name.azurewebsites.net`
2. Verify it loads without certificate warnings
3. Test an API endpoint: `https://your-app-name.azurewebsites.net/health`

---

## Step 3: Configure CORS for Mobile App

### 3.1 Set CORS Origins
1. In your App Service, go to **"CORS"** in the left sidebar
2. Under **"Allowed Origins"**, add:
   - `*` (for development/testing)
   - Your specific domain (for production)
3. Check **"Enable Access-Control-Allow-Credentials"** if needed
4. Click **"Save"**

---

## Step 4: Set Up Monitoring & Logging

### 4.1 Enable Application Insights
1. In your App Service, go to **"Application Insights"** in the left sidebar
2. Click **"Turn on Application Insights"**
3. Choose **"Create new resource"** or select existing one
4. Click **"Apply"**

### 4.2 Configure Log Stream
1. Go to **"Log stream"** in the left sidebar
2. This shows real-time logs from your app
3. Keep this open while testing to see live activity

### 4.3 Set Up Alerts (Optional)
1. Go to **"Alerts"** in the left sidebar
2. Click **"+ New alert rule"**
3. Set up alerts for:
   - HTTP 5xx errors
   - High response time
   - High CPU usage

---

## Step 5: Test Your Deployment

### 5.1 Test API Endpoints
1. Open your browser or Postman
2. Test these endpoints:
   - `GET https://your-app-name.azurewebsites.net/health`
   - `GET https://your-app-name.azurewebsites.net/documents`

### 5.2 Check Logs
1. Go to **"Log stream"** in your App Service
2. Make API calls and watch for log entries
3. Look for any errors or warnings

---

## Step 6: Update Your Flutter App

### 6.1 Update API Endpoint
In your Flutter app, update the API base URL:

```dart
// In your API service file (e.g., lib/services/api_service.dart)
const String apiBaseUrl = 'https://your-app-name.azurewebsites.net/';
```

### 6.2 Test Mobile App Connectivity
1. Build and run your Flutter app
2. Test document upload/download functionality
3. Verify API calls work from the mobile app

---

## Step 7: Production Checklist

Before going live, verify:

- [ ] All environment variables are set correctly
- [ ] HTTPS is enforced and working
- [ ] CORS is configured properly
- [ ] Application Insights is enabled
- [ ] Mobile app can connect to the backend
- [ ] All API endpoints respond correctly
- [ ] Log monitoring is working
- [ ] Secrets are stored securely (preferably in Key Vault)

---

## Troubleshooting Common Issues

### App Won't Start
1. Check **"Log stream"** for error messages
2. Verify environment variables are set correctly
3. Check that Docker image was pushed successfully

### CORS Errors from Mobile App
1. Verify CORS settings in App Service
2. Check that mobile app is using HTTPS URLs
3. Ensure credentials are enabled if needed

### Environment Variables Not Loading
1. Make sure you clicked "Save" in Configuration
2. Check that app restarted after adding variables
3. Verify variable names match what your code expects

---

## Next Steps
- Set up CI/CD pipeline for automatic deployments
- Configure backup and disaster recovery
- Set up staging environment
- Monitor costs and optimize resources

---

**Your app should now be fully deployed and configured! 🎉** 