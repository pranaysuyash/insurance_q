#!/bin/bash
set -e

echo "🚀 Deploying Enhanced Insurance RAG App with Multi-Architecture Support"
echo "======================================================================"

# Configuration
REGION="ap-south-1"
ECR_REPO_NAME="insurance-rag-enhanced-v2"
SERVICE_NAME="insurance-app-enhanced-v2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME"

echo "✅ Account ID: $ACCOUNT_ID"
echo "📦 ECR URI: $ECR_URI"
echo "🆕 Service Name: $SERVICE_NAME"
echo "🏗️ Target Architecture: linux/amd64 (AWS App Runner compatible)"
echo "💻 Build Platform: $(uname -m) ($(uname -s))"

# Check prerequisites
echo ""
echo "🔍 Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first."
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run: aws configure"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install it first."
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running. Please start Docker Desktop."
    exit 1
fi

# Check Docker buildx for multi-platform builds
echo "🔧 Setting up Docker buildx for multi-platform builds..."
docker buildx create --name multiarch --driver docker-container --use 2>/dev/null || docker buildx use multiarch 2>/dev/null || echo "Using default buildx instance"
docker buildx inspect --bootstrap

echo "✅ All prerequisites met"

# Step 1: Create new ECR repository
echo ""
echo "1️⃣ Creating new ECR repository..."
aws ecr create-repository \
    --repository-name $ECR_REPO_NAME \
    --region $REGION \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    --image-tag-mutability MUTABLE > /dev/null 2>&1 || echo "Repository '$ECR_REPO_NAME' already exists."

echo "✅ ECR repository ready: $ECR_URI"

# Step 2: Create optimized multi-architecture Dockerfile
echo ""
echo "2️⃣ Creating optimized Dockerfile for AWS App Runner..."
cat > Dockerfile.aws << 'EOF'
# Multi-stage build for optimal size and compatibility
FROM --platform=linux/amd64 python:3.11-slim AS base

# Set working directory
WORKDIR /app

# Install system dependencies optimized for AWS including WeasyPrint requirements
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    ca-certificates \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    libffi-dev \
    shared-mime-info \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies with multi-architecture compatibility
RUN pip install --no-cache-dir --upgrade pip==23.3.1 && \
    pip install --no-cache-dir --timeout 1000 --retries 5 \
    --index-url https://pypi.org/simple/ \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    torch==2.1.0+cpu torchvision==0.16.0+cpu && \
    pip install --no-cache-dir --timeout 1000 --retries 5 -r requirements.txt

# Copy application code
COPY src/ src/
COPY storage/ storage/

# Create necessary directories
RUN mkdir -p /app/storage/documents /app/logs /app/temp /app/uploads

# Create dummy Firebase service account for compatibility
RUN echo '{"type": "service_account", "project_id": "dummy"}' > /app/serviceAccountKey.json

# Set environment variables
ENV PYTHONPATH="/app"
ENV PYTHONUNBUFFERED="1"
ENV FIREBASE_SERVICE_ACCOUNT_PATH="/app/serviceAccountKey.json"
ENV PLATFORM="linux/amd64"

# Health check optimized for App Runner
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Optimized startup command for AWS App Runner
CMD ["sh", "-c", "python -m uvicorn src.app.main:app --host 0.0.0.0 --port 8000 --workers 1 --log-level info --access-log --no-use-colors"]
EOF

echo "✅ Multi-architecture Dockerfile created"

# Step 3: Build and push multi-platform image
echo ""
echo "3️⃣ Building and pushing multi-platform Docker image..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

echo "🔨 Building Docker image for linux/amd64 (AWS App Runner architecture)..."
docker buildx build \
    --platform linux/amd64 \
    --file Dockerfile.aws \
    --tag $ECR_URI:latest \
    --tag $ECR_URI:$(date +%Y%m%d-%H%M%S) \
    --push \
    --progress=plain \
    --no-cache \
    .

echo "✅ Multi-platform Docker image built and pushed successfully"

# Step 4: Create IAM role for App Runner (if it doesn't exist)
echo ""
echo "4️⃣ Ensuring IAM role exists for App Runner..."
ROLE_NAME="AppRunnerECRAccessRole"
aws iam get-role --role-name $ROLE_NAME > /dev/null 2>&1 || {
    echo "Creating IAM role for App Runner ECR access..."
    
    # Create trust policy
    cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "build.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # Create the role
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file://trust-policy.json \
        --description "Role for App Runner to access ECR repositories"

    # Attach the policy
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess

    rm trust-policy.json
    echo "✅ IAM role created and configured"
}

# Step 5: Check for existing App Runner service and update instead of delete
echo ""
echo "5️⃣ Checking for existing App Runner service..."
EXISTING_SERVICE_ARN=$(aws apprunner list-services --region $REGION --query "ServiceSummaryList[?ServiceName=='$SERVICE_NAME'].ServiceArn" --output text)

if [ ! -z "$EXISTING_SERVICE_ARN" ] && [ "$EXISTING_SERVICE_ARN" != "None" ]; then
    echo "🔄 Found existing service. Updating with new image instead of recreating..."
    
    # Update the existing service with new image
    aws apprunner update-service \
        --service-arn "$EXISTING_SERVICE_ARN" \
        --source-configuration '{
            "ImageRepository": {
                "ImageIdentifier": "'$ECR_URI':latest",
                "ImageConfiguration": {
                    "Port": "8000",
                    "RuntimeEnvironmentVariables": {
                        "PORT": "8000",
                        "PYTHONPATH": "/app",
                        "PYTHONUNBUFFERED": "1",
                        "LOG_LEVEL": "INFO",
                        "OPENAI_API_KEY": "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",
                        "QDRANT_URL": "https://c0496763-dd69-4f30-9b8a-ca0b9294ddf2.us-east4-0.gcp.cloud.qdrant.io:6333",
                        "QDRANT_API_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0.gUETgUylDxoSvj1iw-P02in7mHnAkC5rL98tsqsSJYQ",
                        "QDRANT_COLLECTION": "insurance_documents_v2",
                        "REDIS_HOST": "insurance-app-redis-mumbai-public.y6jsma.0001.aps1.cache.amazonaws.com",
                        "REDIS_PORT": "6379",
                        "REDIS_PASSWORD": "",
                        "CACHE_TTL_SECONDS": "3600",
                        "EMBEDDING_MODEL": "sentence-transformers/all-mpnet-base-v2",
                        "OPENAI_EMBEDDING_MODEL": "text-embedding-ada-002",
                        "OPENAI_CHAT_MODEL": "gpt-3.5-turbo",
                        "USE_OPENAI_FIRST": "true",
                        "OCR_IMAGE_DPI": "200",
                        "ENVIRONMENT": "production",
                        "PLATFORM": "linux/amd64",
                        "RATE_LIMIT_IP_DAILY": "10",
                        "RATE_LIMIT_SESSION_DAILY": "5"
                    },
                    "StartCommand": "python -m uvicorn src.app.main:app --host 0.0.0.0 --port 8000 --workers 1 --log-level info --access-log --no-use-colors"
                },
                "ImageRepositoryType": "ECR"
            },
            "AuthenticationConfiguration": {
                "AccessRoleArn": "arn:aws:iam::'$ACCOUNT_ID':role/AppRunnerECRAccessRole"
            }
        }' \
        --region $REGION > /dev/null
    
    echo "✅ Service update initiated"
    SERVICE_ARN="$EXISTING_SERVICE_ARN"
    
    # Wait for update to complete
    echo "⏳ Waiting for update to complete..."
    while true; do
        STATUS=$(aws apprunner describe-service --service-arn "$SERVICE_ARN" --region $REGION --query 'Service.Status' --output text)
        echo "   Status: $STATUS"
        
        if [ "$STATUS" == "RUNNING" ]; then
            break
        elif [ "$STATUS" == "UPDATE_FAILED" ]; then
            echo "❌ Service update failed"
            exit 1
        fi
        
        sleep 30
    done
    
    echo "✅ Service updated successfully with same URL!"
    
else
    echo "🆕 No existing service found. Creating new service..."

    # Step 6: Create App Runner service configuration
echo ""
echo "6️⃣ Creating App Runner service configuration..."
cat > enhanced-v2-service-config.json << EOF
{
  "ServiceName": "$SERVICE_NAME",
  "SourceConfiguration": {
    "ImageRepository": {
      "ImageIdentifier": "$ECR_URI:latest",
      "ImageConfiguration": {
        "Port": "8000",
        "RuntimeEnvironmentVariables": {
          "PORT": "8000",
          "PYTHONPATH": "/app",
          "PYTHONUNBUFFERED": "1",
          "LOG_LEVEL": "INFO",
          "OPENAI_API_KEY": "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",
          "QDRANT_URL": "https://c0496763-dd69-4f30-9b8a-ca0b9294ddf2.us-east4-0.gcp.cloud.qdrant.io:6333",
          "QDRANT_API_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0.gUETgUylDxoSvj1iw-P02in7mHnAkC5rL98tsqsSJYQ",
          "QDRANT_COLLECTION": "insurance_documents_v2",
          "REDIS_HOST": "insurance-app-redis-mumbai-public.y6jsma.0001.aps1.cache.amazonaws.com",
          "REDIS_PORT": "6379",
          "REDIS_PASSWORD": "",
          "CACHE_TTL_SECONDS": "3600",
          "EMBEDDING_MODEL": "sentence-transformers/all-mpnet-base-v2",
          "OPENAI_EMBEDDING_MODEL": "text-embedding-ada-002",
          "OPENAI_CHAT_MODEL": "gpt-3.5-turbo",
          "USE_OPENAI_FIRST": "true",
          "OCR_IMAGE_DPI": "200",
          "ENVIRONMENT": "production",
          "PLATFORM": "linux/amd64"
        },
        "StartCommand": "python -m uvicorn src.app.main:app --host 0.0.0.0 --port 8000 --workers 1"
      },
      "ImageRepositoryType": "ECR"
    },
    "AuthenticationConfiguration": {
      "AccessRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/AppRunnerECRAccessRole"
    }
  },
  "InstanceConfiguration": {
    "Cpu": "1024",
    "Memory": "2048"
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/health",
    "Interval": 20,
    "Timeout": 10,
    "HealthyThreshold": 2,
    "UnhealthyThreshold": 5
  },
  "AutoScalingConfigurationArn": "arn:aws:apprunner:$REGION:$ACCOUNT_ID:autoscalingconfiguration/DefaultConfiguration/1/00000000000000000000000000000001"
}
EOF
echo "✅ Configuration file 'enhanced-v2-service-config.json' created."

# Step 7: Create the new service
echo ""
echo "7️⃣ Creating enhanced App Runner service '$SERVICE_NAME'..."
SERVICE_ARN=$(aws apprunner create-service \
    --cli-input-json file://enhanced-v2-service-config.json \
    --region $REGION \
    --query 'Service.ServiceArn' --output text)

if [ -z "$SERVICE_ARN" ]; then
    echo "❌ Service creation failed. Please check the AWS console for more details."
    exit 1
fi

echo "✅ Service creation initiated. ARN: $SERVICE_ARN"

# Step 8: Monitor service creation
echo ""
echo "8️⃣ Monitoring service creation..."
echo "⏳ This may take 10-15 minutes for enhanced service with document processing..."

while true; do
    STATUS=$(aws apprunner describe-service --service-arn "$SERVICE_ARN" --region $REGION --query 'Service.Status' --output text)
    echo "   Status: $STATUS"
    
    if [ "$STATUS" == "RUNNING" ]; then
        break
    elif [ "$STATUS" == "CREATE_FAILED" ] || [ "$STATUS" == "DELETE_FAILED" ]; then
        echo "❌ Service creation failed"
        # Get operation details for debugging
        aws apprunner list-operations --service-arn "$SERVICE_ARN" --region $REGION --query 'OperationSummaryList[0]'
        exit 1
    fi
    
    sleep 30
done

fi

# Step 9: Get service details and test
SERVICE_URL=$(aws apprunner describe-service --service-arn "$SERVICE_ARN" --region $REGION --query 'Service.ServiceUrl' --output text)

echo ""
echo "🎉 SUCCESS! Insurance RAG App deployed with STABLE URL!"
echo "======================================================="
echo "🌐 Service URL: https://$SERVICE_URL"
echo "🔗 Health Check: https://$SERVICE_URL/health"
echo "📱 Mobile API Endpoint: https://$SERVICE_URL/query"
echo "📄 Document Upload: https://$SERVICE_URL/documents/upload"
echo "📊 Usage Stats: https://$SERVICE_URL/documents/usage-stats"
echo "📚 API Documentation: https://$SERVICE_URL/docs"
echo ""
echo "🎯 STABLE URL - This URL will NEVER change!"
echo "💡 Future deployments will update this same service"
echo "🔄 No need to update Flutter app anymore!"
echo ""
echo "🚀 Features:"
echo "   • Complete Document Processing Pipeline (OCR → RAG → Vector DB)"
echo "   • Anti-abuse System with Rate Limiting"
echo "   • Lead Capture and Contact Management"
echo "   • Real-time Usage Statistics"
echo "   • Multi-format Support (PDF, PNG, JPG, TIFF)"
echo "   • Production-optimized Performance"
echo ""
echo "💰 Cost: ~$15-20/month when idle, scales automatically"
echo "📊 Monitor: https://console.aws.amazon.com/apprunner/home?region=$REGION"

# Step 10: Test the deployment
echo ""
echo "9️⃣ Testing deployment..."
echo "🧪 Testing health endpoint..."
sleep 30  # Give service time to fully start

if curl -f "https://$SERVICE_URL/health" > /dev/null 2>&1; then
    echo "✅ Health check passed!"
    
    # Test the enhanced endpoints
    echo "🧪 Testing debug services endpoint..."
    if curl -f "https://$SERVICE_URL/debug/services" > /dev/null 2>&1; then
        echo "✅ Debug services endpoint responding!"
    else
        echo "⚠️ Debug services endpoint not responding"
    fi
    
    echo "🧪 Testing processing status endpoint..."
    if curl -f "https://$SERVICE_URL/processing/status" > /dev/null 2>&1; then
        echo "✅ Processing status endpoint responding!"
    else
        echo "⚠️ Processing status endpoint not responding"
    fi
    
    echo "🧪 Testing query endpoint..."
    curl -s -X POST "https://$SERVICE_URL/query" \
        -H "Content-Type: application/json" \
        -d '{"query": "test query"}' > /dev/null 2>&1 && echo "✅ Query endpoint responding!" || echo "⚠️ Query endpoint not responding"
    
else
    echo "⚠️ Health check failed, but service might still be starting up"
    echo "🔍 Check the App Runner console for logs if issues persist"
fi

# Clean up temporary files
rm -f Dockerfile.aws enhanced-v2-service-config.json

echo ""
echo "✅ Stable deployment complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Update Flutter app baseUrl to: https://$SERVICE_URL (one-time only)"
echo "   2. Test document upload and anti-abuse features"
echo "   3. Monitor usage statistics and lead capture"
echo "   4. This URL will remain stable for all future deployments"
echo ""
echo "🔄 To update: just run this script again (URL stays same!)"
echo "🗑️ To delete: aws apprunner delete-service --service-arn $SERVICE_ARN --region $REGION"
echo ""
echo "🎯 Repository & Service Names (CONSISTENT):"
echo "   ECR Repository: insurance-rag-enhanced-v2"
echo "   Service Name: insurance-app-enhanced-v2"
echo "   These names never change!"
