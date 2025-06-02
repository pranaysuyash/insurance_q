# 🚀 Immediate Next Steps - Azure Deployment

This is your quick reference guide for what to do once the deployment script completes.

---

## ⏱️ **Current Status**: Deployment Script Running

Check if deployment is still running:
```bash
ps aux | grep deploy_full_backend
```

---

## 📋 **Step-by-Step Execution Plan**

### **Step 1: Set API Keys** ✅ **READY**
Once deployment completes, run:
```bash
./scripts/set_api_keys.sh
```

This will automatically set your OpenAI API key for both `insurance-rag-app` and `insurance-ocr-app` services.

### **Step 2: Test Service Health**
```bash
# Test all three services
curl https://insurance-rag-app.azurewebsites.net/health
curl https://insurance-ocr-app.azurewebsites.net/health  
curl https://insurance-frontend-app.azurewebsites.net/health
```

### **Step 3: Update Flutter App**
Edit `mobile/lib/services/api_service.dart`:
```dart
// Change this line:
static const String baseUrl = 'http://172.21.0.237:8080';

// To this:
static const String baseUrl = 'https://insurance-frontend-app.azurewebsites.net';
```

### **Step 4: Test End-to-End**
```bash
# Test the main endpoint your Flutter app will use
curl -X POST https://insurance-frontend-app.azurewebsites.net/query \
  -H "Content-Type: application/json" \
  -d '{"query": "test query"}'
```

---

## 🚨 **Troubleshooting Commands**

### If Services Don't Respond
```bash
# Check service logs
az webapp log tail --resource-group insurance-app-rg --name insurance-rag-app
az webapp log tail --resource-group insurance-app-rg --name insurance-ocr-app
az webapp log tail --resource-group insurance-app-rg --name insurance-frontend-app
```

### If Qdrant Issues
```bash
# Check Qdrant container status
az container show --resource-group insurance-app-rg --name insurance-app-qdrant
```

### Verify App Settings
```bash
# Check if API keys are set correctly
az webapp config appsettings list --resource-group insurance-app-rg --name insurance-rag-app | grep OPENAI_API_KEY
az webapp config appsettings list --resource-group insurance-app-rg --name insurance-ocr-app | grep OPENAI_API_KEY
```

---

## 📱 **Mobile App Testing**

1. Update the API endpoint (Step 3 above)
2. Run the Flutter app in development mode
3. Test document upload/processing functionality
4. Verify responses are coming from Azure backend

---

## 🎯 **Success Criteria**

- ✅ All three services respond to `/health` endpoints
- ✅ API keys are configured 
- ✅ Flutter app successfully connects to Azure backend
- ✅ End-to-end document processing works

---

## 📞 **Quick Reference - Service URLs**

| Service | URL | Purpose |
|---------|-----|---------|
| **Frontend** | `https://insurance-frontend-app.azurewebsites.net` | **Main mobile app endpoint** |
| **RAG** | `https://insurance-rag-app.azurewebsites.net` | Vector search & Q&A |
| **OCR** | `https://insurance-ocr-app.azurewebsites.net` | Document processing |

---

**⏰ Estimated Time**: 5-10 minutes after deployment completes  
**🎯 Goal**: Fully functional Azure backend ready for mobile app integration 