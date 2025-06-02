# Azure App Service Docker Deployment Troubleshooting

**Date:** June 2, 2025  
**Issue:** Azure App Service container deployment failing with "Application Error" despite successful local testing  
**App Name:** `insurance-policy-app`  
**Resource Group:** `insurance-app-rg`  
**Container Registry:** `insuranceappacr.azurecr.io`  

---

## Problem Summary

Despite successful Docker image builds and pushes to Azure Container Registry, the web app consistently shows "Application Error" when accessed via browser. Local Docker testing works perfectly.

---

## Successful Steps Completed

✅ **Infrastructure Setup:**
- Resource group created: `insurance-app-rg`
- Azure Container Registry created: `insuranceappacr.azurecr.io`
- App Service plan created: `insurance-app-plan` (B1 Linux)
- Web app created: `insurance-policy-app`

✅ **Docker Operations:**
- Successfully built multiple Docker images locally
- Successfully pushed images to ACR
- Local testing of containers works (confirmed with `curl localhost:8000/health`)

✅ **Azure Configuration:**
- HTTPS enforcement enabled
- Admin credentials enabled on ACR
- Multiple startup command configurations attempted

---

## Failed Attempts & Error Details

### Attempt 1: Original Complex Application
**Command Used:**
```bash
./scripts/deploy_to_azure.sh
```

**Error:** 
- Script failed at credential retrieval step
- ACR admin not enabled initially

**Fix Applied:** 
```bash
az acr update -n insuranceappacr --admin-enabled true
```

### Attempt 2: Complex App with Different Startup Commands

**Commands Tried:**
```bash
# Main FastAPI app
az webapp config set --startup-file "uvicorn src.app.main:app --host 0.0.0.0 --port 8000"

# RAG service app
az webapp config set --startup-file "uvicorn src.rag.service:app --host 0.0.0.0 --port 8000"
```

**Error:** Both resulted in "Application Error" page

### Attempt 3: Environment Variables Configuration

**Commands Applied:**
```bash
# Basic environment variables
az webapp config appsettings set --settings ENVIRONMENT=production PYTHONPATH=/app PYTHONUNBUFFERED=1

# Service URLs
az webapp config appsettings set --settings REDIS_URL="redis://localhost:6379" QDRANT_URL="http://localhost:6333" OPENAI_API_KEY="test-key"

# Port configuration
az webapp config appsettings set --settings WEBSITES_PORT="8000"
```

**Error:** Still getting "Application Error"

### Attempt 4: Port Configuration Changes

**Commands Tried:**
```bash
# Port 80 instead of 8000
az webapp config set --startup-file "uvicorn src.simple_app:app --host 0.0.0.0 --port 80"

# Remove port setting entirely
az webapp config appsettings delete --setting-names WEBSITES_PORT
```

**Error:** No change, still "Application Error"

### Attempt 5: Simplified FastAPI Application

**Created minimal app:** `src/simple_app.py`
```python
from fastapi import FastAPI

app = FastAPI(title="Simple Test API")

@app.get("/")
async def root():
    return {"message": "Hello from Azure!", "status": "ok"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "simple-test"}
```

**Dockerfile.simple:**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements-simple.txt .
RUN pip install -r requirements-simple.txt
COPY src/simple_app.py src/simple_app.py
ENV PYTHONPATH=/app
EXPOSE 80
CMD uvicorn src.simple_app:app --host 0.0.0.0 --port ${PORT:-80}
```

**Local Test Result:** ✅ Works perfectly
```bash
$ curl http://localhost:8000/health
{"status":"healthy","service":"simple-test"}
```

**Azure Result:** ❌ Still "Application Error"

---

## Current Configuration Status

**Container Image:** `insuranceappacr.azurecr.io/insurance-app-simple:v2`  
**Startup Command:** `uvicorn src.simple_app:app --host 0.0.0.0 --port 80`  
**Environment Variables:**
- `ENVIRONMENT=production`
- `PYTHONPATH=/app`
- `PYTHONUNBUFFERED=1`
- `REDIS_URL=redis://localhost:6379`
- `QDRANT_URL=http://localhost:6333`
- `OPENAI_API_KEY=test-key`

**App Service Configuration:**
- HTTPS Only: Enabled
- Minimum TLS Version: 1.2
- Container Registry Authentication: Working

---

## Diagnostic Information Attempted

### Log Analysis
```bash
# Enabled application logging
az webapp log config --application-logging filesystem --level information

# Downloaded logs
az webapp log download
```
**Result:** Logs downloaded but contained mostly permission errors and no clear application startup errors

### Container Status
- Container pulls successfully from ACR
- No obvious authentication issues with container registry
- Image exists and is accessible

---

## Potential Root Causes

1. **Port Binding Issues:**
   - Azure might expect different port configuration
   - Container might not be binding to correct interface

2. **Startup Timing:**
   - Container might be timing out during startup
   - Health checks might be failing

3. **Resource Constraints:**
   - B1 plan might have insufficient resources
   - Memory/CPU limits causing startup failures

4. **Platform-Specific Issues:**
   - Azure App Service Linux containers have specific requirements
   - Missing required Azure-specific environment variables

5. **Network Configuration:**
   - Container networking not properly configured
   - Load balancer health checks failing

---

## Recommended Next Steps for External Help

### 1. Azure Support Ticket
Create support ticket with:
- Resource group: `insurance-app-rg`
- App service: `insurance-policy-app`
- Specific error: "Application Error" with working local container

### 2. Enable Detailed Diagnostics
```bash
# Enable more detailed logging
az webapp log config --resource-group insurance-app-rg --name insurance-policy-app \
  --application-logging filesystem --level verbose \
  --detailed-error-messages true \
  --failed-request-tracing true

# Enable live log streaming
az webapp log tail --resource-group insurance-app-rg --name insurance-policy-app
```

### 3. Check Azure Service Health
- Verify no ongoing Azure App Service issues in East US region
- Check for any platform updates affecting Linux containers

### 4. Alternative Approaches to Try

**Option A: Azure Container Instances**
```bash
az container create \
  --resource-group insurance-app-rg \
  --name insurance-test-aci \
  --image insuranceappacr.azurecr.io/insurance-app-simple:v2 \
  --registry-login-server insuranceappacr.azurecr.io \
  --registry-username insuranceappacr \
  --registry-password [ACR_PASSWORD] \
  --dns-name-label insurance-test \
  --ports 80
```

**Option B: Different App Service Plan**
- Try Standard (S1) plan instead of Basic (B1)
- Test in different Azure region

### 5. Community Resources
- **Stack Overflow:** Search "Azure App Service Docker Application Error"
- **Azure Forums:** Post in Azure App Service community
- **GitHub Issues:** Check Azure/app-service-linux-docs for similar issues

---

## Files for Reference

- **Deployment Script:** `scripts/deploy_to_azure.sh`
- **Simple Dockerfile:** `Dockerfile.simple`
- **Simple App:** `src/simple_app.py`
- **Requirements:** `requirements-simple.txt`
- **Original Dockerfile:** `Dockerfile`

---

## Contact Information for Support

**Azure Subscription:** Microsoft Azure Sponsorship-1 (`e173e4af-4327-46ef-bb5b-912d6e218bf2`)  
**Tenant:** MedPiper Technologies Private Limited  
**Region:** East US  
**CLI Version:** Azure CLI 2.73.0  
**Docker Version:** 28.1.1  

---

**Status:** Issue unresolved - requires external Azure expertise or support ticket. 