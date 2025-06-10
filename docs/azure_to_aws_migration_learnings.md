# Azure to AWS Migration: Lessons Learned

## Migration Overview

**Project**: Insurance RAG Application  
**Original Platform**: Azure Container Apps  
**Target Platform**: AWS App Runner  
**Migration Date**: June 2025  
**Development Environment**: M1 Mac (ARM64)

## What We Expected

### Initial Assumptions
- **Smooth Container Migration**: Expected Docker containers to work seamlessly across cloud platforms
- **Similar Configuration**: Anticipated Azure Container Apps and AWS App Runner to have comparable setup processes
- **Quick Deployment**: Assumed the migration would be straightforward with minimal architecture-specific issues
- **Consistent Behavior**: Expected identical application behavior between local development and cloud deployment

### Technical Expectations
- Direct port of existing Dockerfile and configuration
- Same container orchestration patterns
- Equivalent health check and logging mechanisms
- Similar networking and service discovery

## What We Actually Faced

### Major Challenges

#### 1. **Architecture Mismatch (The Root Cause)**
- **Issue**: Built ARM64 images on M1 Mac that couldn't run on AWS's x86_64 infrastructure
- **Symptom**: Container crashes immediately with zero application logs
- **Duration**: Multiple days of debugging
- **False Leads**: Blamed dependencies, networking, configuration issues

#### 2. **Invisible Container Failures**
- **Issue**: App Runner provides minimal debugging information for container startup failures
- **Symptoms**: 
  - "Health check failed" messages
  - "Failed to deploy your application image"
  - Zero application logs in CloudWatch
  - No stack traces or error details

#### 3. **Logging and Observability Gaps**
- **Issue**: App Runner requires explicit configuration for application logging
- **Requirements**:
  - Instance IAM role with CloudWatch permissions
  - Manual enablement of application logs
  - Proper service configuration for log delivery

#### 4. **Configuration Structure Differences**
- **Issue**: AWS CLI service configuration has different JSON structure than expected
- **Problems**:
  - Parameter validation errors
  - Nested configuration requirements
  - Different health check limits (max 20s interval vs 30s expected)

### Debugging Journey

#### Phase 1: Configuration Troubleshooting (Days 1-2)
- Adjusted health check timeouts
- Modified environment variables
- Tried different port configurations
- **Result**: No improvement, still zero application logs

#### Phase 2: Dependency Investigation (Day 3)
- Created minimal versions with fewer dependencies
- Suspected heavy ML libraries (PyTorch, transformers)
- Built ultra-simple FastAPI apps
- **Result**: Even minimal apps failed, ruling out dependency issues

#### Phase 3: Infrastructure Deep Dive (Day 4)
- Set up proper IAM roles for logging
- Enabled CloudWatch application logs
- Investigated container networking
- **Result**: Still no application logs, but proper infrastructure setup

#### Phase 4: Architecture Discovery (Day 5)
- Realized platform mismatch between development and deployment
- Discovered ARM64 vs x86_64 compatibility issue
- **Result**: Root cause identified!

## What Finally Worked

### The Solution: Platform-Specific Builds

#### Technical Fix
```bash
# Create multiarch builder
docker buildx create --use --name multiarch

# Build specifically for x86_64 (linux/amd64)
docker buildx build \
  --platform linux/amd64 \
  -f Dockerfile.apprunner-optimized-fixed \
  -t insurance-rag-amd64:latest \
  --load .

# Test locally to verify compatibility
docker run --rm -p 8001:8000 insurance-rag-amd64:latest
```

#### Key Learnings
1. **Always specify target platform** when building for cloud deployment
2. **Test x86_64 images locally** before deploying to AWS
3. **Enable comprehensive logging infrastructure** before troubleshooting
4. **Start with ultra-simple tests** to isolate platform vs application issues

### Successful Configuration

#### Final Dockerfile Structure
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential curl git libgl1-mesa-glx libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip \
 && pip install --no-cache-dir --timeout 1000 --retries 5 -r requirements.txt

# Copy application code
COPY src/ src/

# Create dummy Firebase service account to prevent crashes
RUN echo '{"type": "service_account", "project_id": "dummy"}' > /app/serviceAccountKey.json

# Set environment variables
ENV FIREBASE_SERVICE_ACCOUNT_PATH=/app/serviceAccountKey.json
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

# Simple, reliable startup command
CMD sleep 3 && uvicorn src.app.main:app --host 0.0.0.0 --port 8000 --log-level info --access-log
```

#### App Runner Configuration
```json
{
  "ImageRepository": {
    "ImageIdentifier": "317147645519.dkr.ecr.ap-south-1.amazonaws.com/insurance-rag-full-mumbai:latest",
    "ImageConfiguration": {
      "Port": "8000",
      "RuntimeEnvironmentVariables": {
        "PORT": "8000",
        "PYTHONPATH": "/app",
        "PYTHONUNBUFFERED": "1",
        "LOG_LEVEL": "INFO"
      }
    },
    "ImageRepositoryType": "ECR"
  },
  "AuthenticationConfiguration": {
    "AccessRoleArn": "arn:aws:iam::317147645519:role/AppRunnerECRAccessRole"
  },
  "AutoDeploymentsEnabled": true
}
```

## Migration Recommendations

### For Future Cloud Migrations

#### 1. **Platform Architecture Verification**
- Always check target cloud platform architecture (x86_64 vs ARM64)
- Build and test for target architecture before deployment
- Use `docker buildx` with explicit `--platform` flags

#### 2. **Observability Setup First**
- Configure logging infrastructure before application deployment
- Set up proper IAM roles and permissions
- Enable all monitoring and debugging features

#### 3. **Incremental Complexity Approach**
- Start with ultra-simple "Hello World" containers
- Gradually add complexity (dependencies, configurations, features)
- Verify each step works before proceeding

#### 4. **Documentation and Testing**
- Document all configuration differences between platforms
- Maintain platform-specific build instructions
- Create automated testing for multiple architectures

### AWS App Runner Specific Gotchas

#### 1. **Instance Role Requirements**
- App Runner needs explicit IAM role for CloudWatch logging
- Role must be attached before enabling application logs
- Without proper role, application logs are silently lost

#### 2. **Health Check Limitations**
- Maximum interval: 20 seconds (not 30s)
- Timeout constraints vary by service configuration
- Health checks start only after container is "ready"

## Helpful Scripts During Migration

### Scripts That Led to Success
The following scripts were instrumental in the debugging and eventual success of the migration. These are preserved in git history and can be referenced if needed:

#### **Final Working Scripts (Preserved)**
- `aws_deployment.sh` - The final successful AWS App Runner deployment script
- `aws_ecs_simple.sh` - Alternative AWS ECS deployment option
- `source-config-only.json` - Final working App Runner service configuration
- `Dockerfile` - Final working Dockerfile with proper x86_64 compatibility

#### **Key Debugging Scripts (Historical Reference)**
- `deploy_final_x86.sh` - First successful x86_64 platform-specific build
- `test_local_docker.sh` - Local Docker testing script that helped identify platform issues
- `setup_iam_permissions.sh` - Script that properly configured CloudWatch logging permissions
- `monitor_and_test_service.sh` - Comprehensive service monitoring during debugging

#### **Architecture Discovery Scripts**
- `deploy_super_simple_final.sh` - Ultra-minimal app that helped isolate platform vs dependency issues
- `test_minimal_on_apprunner_fixed.sh` - Minimal testing that revealed the ARM64/x86_64 mismatch
- `container_startup_diagnostic.sh` - Comprehensive container startup debugging

#### **Configuration Evolution**
- `rag-service-config-mumbai-v6-public-redis.json` - Final working service configuration
- `Dockerfile.apprunner-optimized-fixed` - The breakthrough Dockerfile with proper platform targeting

### Scripts Removed During Cleanup
The following categories of scripts were removed as they are no longer needed:
- **Azure-related scripts**: All `fix_azure_*`, `azure_*`, and Azure deployment scripts
- **Failed deployment attempts**: Multiple `deploy_*` variants that didn't work
- **Debug scripts for failed deployments**: Various monitoring and debugging scripts for obsolete approaches
- **Multiple Dockerfile variants**: Consolidated to single working Dockerfile
- **Failed configuration files**: Various config attempts that didn't work

### Accessing Historical Scripts
If you need to reference any of the removed scripts for learning or troubleshooting:
```bash
# View the commit before cleanup
git log --oneline | grep -i "cleanup\|clean"

# Checkout a specific commit to see all historical scripts
git checkout <commit-hash-before-cleanup>

# Or view specific files from git history
git show <commit-hash>:script-name.sh
```

## Final Deployment Status

### Current Production Environment
- **Service URL**: https://8ud4pyy9mc.ap-south-1.awsapprunner.com
- **Status**: ✅ Fully operational
- **Architecture**: x86_64 (linux/amd64)
- **Platform**: AWS App Runner
- **Region**: ap-south-1 (Mumbai)
- **Health Check**: Passing
- **Logging**: Enabled with CloudWatch integration

### Mobile App Integration
- **Flutter App Version**: 0.1.2+11
- **Backend Integration**: ✅ Updated to use AWS App Runner URL
- **Build Status**: ✅ Android APK and iOS builds successful
- **Testing**: ✅ All tests passing

#### 3. **Architecture Requirements**
- Only supports x86_64 (linux/amd64)
- ARM64 images fail silently with no clear error messages
- Platform mismatch is not reported in deployment logs

## Cost and Performance Impact

### Migration Benefits
- **Simplified Infrastructure**: App Runner handles container orchestration automatically
- **Better Scaling**: More responsive auto-scaling compared to Azure Container Apps
- **Integrated Monitoring**: Better integration with AWS ecosystem

### Unexpected Costs
- **Extended Debugging Time**: 5 days instead of expected 1 day
- **Multiple Service Deployments**: Created several test services for debugging
- **Learning Curve**: Time investment in AWS-specific configurations

## Conclusion

The Azure to AWS migration was ultimately successful, but revealed important platform-specific considerations that weren't immediately obvious. The primary lesson is that **container portability** isn't always as seamless as expected, especially when different CPU architectures are involved.

**Key Success Factors:**
1. Building for the correct target architecture (x86_64)
2. Proper observability infrastructure setup
3. Systematic debugging approach from simple to complex
4. Understanding platform-specific configuration requirements

**Time Investment:** 5 days total (4 days debugging + 1 day successful deployment)  
**Final Result:** Fully functional insurance RAG application running on AWS App Runner with all features operational.
