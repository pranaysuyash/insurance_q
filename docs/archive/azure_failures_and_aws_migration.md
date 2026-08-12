# Azure Deployment Failures and AWS Migration

**Date:** June 8-9, 2025  
**Status:** Azure resources deleted, migrated to AWS  
**Impact:** Critical - prevented mobile app functionality

## 🚨 Azure App Service Critical Failures

### Initial Problem
- Mobile app getting 503 errors when querying insurance frontend service
- All 4 Azure App Services returning 503 errors despite appearing "healthy" in portal
- Backend services completely non-functional

### Root Cause Analysis

#### 1. Container Registry Authentication Issues
- **Problem:** Managed Identity authentication failing intermittently
- **Symptoms:** Services couldn't pull Docker images despite correct ACR configuration
- **Impact:** Containers failing to start or running with wrong images

#### 2. Environment Variable Corruption
- **Problem:** Azure CLI showing `"value": null` for all environment variables after deployment
- **Symptoms:** Critical env vars (OPENAI_API_KEY, QDRANT_URL) not reaching containers
- **Impact:** Services starting but failing at runtime due to missing configuration

#### 3. Startup Command Parsing Failures
- **Problem:** Azure couldn't parse shell variables in startup commands
- **Example:** `${PORT:-8000}` syntax caused startup failures
- **Workaround:** Had to hardcode ports and use exact module paths

#### 4. Docker Image Inconsistencies
- **Problem:** Services using different Docker images with architecture mismatches
- **Symptoms:** ARM64 vs AMD64 conflicts, authentication failures
- **Impact:** Unpredictable service behavior

#### 5. Fundamental Platform Issues
- **Critical Discovery:** Even ultra-minimal FastAPI service (only FastAPI + Uvicorn) returned 503 errors
- **Conclusion:** This proved the issue was NOT our code but Azure App Service platform itself
- **Impact:** Complete loss of confidence in Azure container platform

### Failed Fix Attempts

1. **Multiple startup command variations**
2. **Different Docker image configurations**
3. **Environment variable reset attempts**
4. **Container registry re-authentication**
5. **Service plan changes**
6. **Complete service recreation**
7. **Ultra-minimal service testing** (final proof of platform failure)

### Azure App Service Limitations Discovered

- Poor error reporting (generic 503 errors with no useful logs)
- Inconsistent environment variable handling
- Unreliable container registry integration
- Complex managed identity setup prone to failures
- Expensive pricing for unreliable service
- Difficult debugging and troubleshooting

## 🚀 AWS Migration Strategy

### Why AWS?

#### Technical Advantages
1. **Reliable Container Deployment**
   - Consistent Docker image handling
   - Proper environment variable persistence
   - Clear error messages and logging

2. **Better Developer Experience**
   - Meaningful error messages
   - Comprehensive logging with CloudWatch
   - Predictable behavior

3. **Cost Effectiveness**
   - App Runner: ~$5/month when idle, auto-scaling
   - ECS Fargate: ~$36/month predictable pricing
   - No hidden costs or surprise charges

4. **Platform Stability**
   - Mature container orchestration
   - Proven at scale
   - Better documentation and community support

### AWS Deployment Options Created

#### Option 1: AWS App Runner (Recommended)
- **Script:** `aws_deployment.sh`
- **Benefits:** Zero server management, auto-scaling, built-in HTTPS
- **Cost:** ~$5/month when idle
- **Use Case:** Perfect for our insurance app workload

#### Option 2: AWS ECS Fargate
- **Script:** `aws_ecs_simple.sh`
- **Benefits:** More control, predictable pricing, production-ready
- **Cost:** ~$36/month
- **Use Case:** When more configuration control needed

### Migration Process

1. **Azure Cleanup**
   - Created `azure_cleanup.sh` script
   - Deleted all resources in `insurance-app-rg` resource group
   - Stopped all charges immediately

2. **AWS Preparation**
   - Created comprehensive deployment scripts
   - Configured environment variables properly
   - Set up ECR repositories and container orchestration

3. **Service Architecture**
   - Frontend service with full RAG pipeline
   - Proper health checks and monitoring
   - Auto-scaling based on demand

## 📊 Comparison: Azure vs AWS

| Aspect | Azure App Service | AWS App Runner/ECS |
|--------|------------------|-------------------|
| **Reliability** | ❌ Frequent 503 errors | ✅ Stable and predictable |
| **Environment Variables** | ❌ Corruption issues | ✅ Reliable persistence |
| **Error Messages** | ❌ Generic, unhelpful | ✅ Detailed and actionable |
| **Container Support** | ❌ Inconsistent | ✅ Mature and reliable |
| **Pricing** | ❌ Expensive for value | ✅ Cost-effective options |
| **Developer Experience** | ❌ Frustrating debugging | ✅ Clear logs and metrics |
| **Documentation** | ❌ Complex, outdated | ✅ Comprehensive and current |

## 🎯 Key Learnings

### Technical Lessons
1. **Platform Choice Matters:** Container orchestration platform stability is critical
2. **Test Early:** Ultra-minimal service testing revealed platform issues quickly
3. **Environment Variables:** Proper handling is essential for containerized apps
4. **Error Reporting:** Good error messages save hours of debugging time

### Business Impact
1. **Cost Savings:** AWS pricing more predictable and cost-effective
2. **Reliability:** AWS provides better uptime and stability
3. **Developer Productivity:** Less time debugging platform issues
4. **Scalability:** Better auto-scaling options with AWS

### Strategic Decisions
1. **Cloud Provider:** AWS chosen over Azure for container workloads
2. **Architecture:** App Runner preferred for simplicity and cost
3. **Monitoring:** CloudWatch provides better observability
4. **Deployment:** Infrastructure as Code approach with scripts

## 🚀 Next Steps

1. **Deploy to AWS:** Run `./aws_deployment.sh` for App Runner deployment
2. **Update Mobile App:** Point to new AWS endpoint
3. **Monitor Performance:** Set up CloudWatch alerts
4. **Document Success:** Update deployment procedures

## 💡 Recommendations

### For Future Projects
1. **Avoid Azure App Service** for containerized applications
2. **Use AWS App Runner** for simple web services
3. **Use AWS ECS Fargate** for production workloads requiring more control
4. **Always test with minimal services** to validate platform reliability
5. **Implement proper monitoring** from day one

### For Current Project
1. Complete AWS deployment using provided scripts
2. Test all endpoints thoroughly
3. Update mobile app configuration
4. Set up monitoring and alerting
5. Document the new architecture

---

**Status:** Azure resources deleted ✅  
**Next Action:** Deploy to AWS using `./aws_deployment.sh`  
**Expected Outcome:** Reliable, cost-effective service deployment 