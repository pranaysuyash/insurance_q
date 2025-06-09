# Azure Deployment Commands Reference

## Service URLs
- **Frontend**: https://insurance-frontend-app.azurewebsites.net
- **OCR**: https://insurance-ocr-app.azurewebsites.net  
- **RAG**: https://insurance-rag-app.azurewebsites.net

## Working Azure App Service Configurations

### Startup Commands (Fixed)
```bash
# Frontend Service
uvicorn src.frontend.app:app --host 0.0.0.0 --port 8000

# OCR Service  
uvicorn src.ocr.service:app --host 0.0.0.0 --port 8000

# RAG Service
uvicorn src.rag.service:app --host 0.0.0.0 --port 8000
```

### Environment Variables Set
```bash
# Set OpenAI API Key for all services
az webapp config appsettings set --resource-group insurance-app-rg --name insurance-frontend-app --settings OPENAI_API_KEY="sk-..."
az webapp config appsettings set --resource-group insurance-app-rg --name insurance-ocr-app --settings OPENAI_API_KEY="sk-..."
az webapp config appsettings set --resource-group insurance-app-rg --name insurance-rag-app --settings OPENAI_API_KEY="sk-..."

# Set Python Path for module resolution
az webapp config appsettings set --resource-group insurance-app-rg --name insurance-frontend-app --settings PYTHONPATH="/app"
az webapp config appsettings set --resource-group insurance-app-rg --name insurance-ocr-app --settings PYTHONPATH="/app"
az webapp config appsettings set --resource-group insurance-app-rg --name insurance-rag-app --settings PYTHONPATH="/app"
```

### Force Restart Commands
```bash
az webapp restart --resource-group insurance-app-rg --name insurance-frontend-app
az webapp restart --resource-group insurance-app-rg --name insurance-ocr-app  
az webapp restart --resource-group insurance-app-rg --name insurance-rag-app
```

### Health Check Commands
```bash
curl https://insurance-frontend-app.azurewebsites.net/health
curl https://insurance-ocr-app.azurewebsites.net/health
curl https://insurance-rag-app.azurewebsites.net/health
```

## Current Service Status

### ✅ Frontend (Healthy)
```json
{"status":"healthy"}
```

### ⚠️ OCR (Degraded - Redis Issue)
```json
{
  "status":"unhealthy",
  "ocr_pipeline":"available",
  "redis":"unavailable"
}
```

### ⚠️ RAG (Degraded - Initialization Issue)  
```json
{
  "status":"degraded",
  "message":"RAG service initialized with warnings"
}
```

## Critical Fixes Applied

1. **Startup Command Syntax**: Changed `${PORT:-8000}` to `--port 8000`
2. **Module Paths**: Fixed incorrect `src.api.*` paths to actual module locations
3. **Python Path**: Added `PYTHONPATH="/app"` for module resolution
4. **API Key**: Set OpenAI API key from local .env file
5. **Cache Clearing**: Force restarted services to clear configuration cache

## Outstanding Issues

1. **RAG Service**: "RAG service is not fully initialized" - preventing AI queries
2. **Redis**: OCR service can't connect to Redis (caching disabled)
3. **Resource Allocation**: May need to check Azure service plans for AI workloads 