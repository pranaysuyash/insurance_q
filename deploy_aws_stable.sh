#!/bin/bash
set -e

echo "🚀 Deploying Insurance RAG App with Stable URL"
echo "=============================================="

# Configuration - STABLE service name that never changes
REGION="ap-south-1"
ECR_REPO_NAME="insurance-rag-stable"
SERVICE_NAME="insurance-app-stable"  # This name stays consistent
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME"

echo "✅ Account ID: $ACCOUNT_ID"
echo "📦 ECR URI: $ECR_URI"
echo "🆔 Service Name: $SERVICE_NAME (STABLE - never changes)"
echo "🏗️ Target Architecture: linux/amd64"

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

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running. Please start Docker Desktop."
    exit 1
fi

echo "✅ All prerequisites met"

# Step 1: Create ECR repository if it doesn't exist
echo ""
echo "1️⃣ Ensuring ECR repository exists..."
aws ecr create-repository \
    --repository-name $ECR_REPO_NAME \
    --region $REGION \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    --image-tag-mutability MUTABLE > /dev/null 2>&1 || echo "Repository '$ECR_REPO_NAME' already exists."

echo "✅ ECR repository ready: $ECR_URI"

# Step 2: Build and push Docker image
echo ""
echo "2️⃣ Building and pushing Docker image..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Use existing Dockerfile.aws
if [ ! -f "Dockerfile.aws" ]; then
    echo "❌ Dockerfile.aws not found. Please run the full deployment script first."
    exit 1
fi

echo "🔨 Building Docker image..."
docker build -f Dockerfile.aws -t $ECR_URI:latest -t $ECR_URI:$(date +%Y%m%d-%H%M%S) .
docker push $ECR_URI:latest
docker push $ECR_URI:$(date +%Y%m%d-%H%M%S)

echo "✅ Docker image built and pushed successfully"

# Step 3: Check if service exists
echo ""
echo "3️⃣ Checking for existing App Runner service..."
EXISTING_SERVICE_ARN=$(aws apprunner list-services --region $REGION --query "ServiceSummaryList[?ServiceName=='$SERVICE_NAME'].ServiceArn" --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_SERVICE_ARN" ] || [ "$EXISTING_SERVICE_ARN" == "None" ]; then
    echo "🆕 No existing service found. Creating new stable service..."
    
    # Create IAM role if needed
    ROLE_NAME="AppRunnerECRAccessRole"
    aws iam get-role --role-name $ROLE_NAME > /dev/null 2>&1 || {
        echo "Creating IAM role for App Runner ECR access..."
        
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

        aws iam create-role \
            --role-name $ROLE_NAME \
            --assume-role-policy-document file://trust-policy.json \
            --description "Role for App Runner to access ECR repositories"

        aws iam attach-role-policy \
            --role-name $ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess

        rm trust-policy.json
        echo "✅ IAM role created"
    }
    
    # Create service configuration
    cat > stable-service-config.json << EOF
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
          "PLATFORM": "linux/amd64",
          "RATE_LIMIT_IP_DAILY": "10",
          "RATE_LIMIT_SESSION_DAILY": "5"
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
  }
}
EOF

    # Create the service
    echo "🆕 Creating new stable service..."
    SERVICE_ARN=$(aws apprunner create-service \
        --cli-input-json file://stable-service-config.json \
        --region $REGION \
        --query 'Service.ServiceArn' --output text)
    
    echo "✅ Service creation initiated. ARN: $SERVICE_ARN"
    
    # Wait for service to be running
    echo "⏳ Waiting for service to be ready..."
    while true; do
        STATUS=$(aws apprunner describe-service --service-arn "$SERVICE_ARN" --region $REGION --query 'Service.Status' --output text)
        echo "   Status: $STATUS"
        
        if [ "$STATUS" == "RUNNING" ]; then
            break
        elif [ "$STATUS" == "CREATE_FAILED" ]; then
            echo "❌ Service creation failed"
            exit 1
        fi
        
        sleep 30
    done
    
    rm stable-service-config.json
    
else
    echo "🔄 Existing service found. Updating with new image..."
    SERVICE_ARN="$EXISTING_SERVICE_ARN"
    
    # Update the service with new image
    aws apprunner update-service \
        --service-arn "$SERVICE_ARN" \
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
                    "StartCommand": "python -m uvicorn src.app.main:app --host 0.0.0.0 --port 8000 --workers 1"
                },
                "ImageRepositoryType": "ECR"
            },
            "AuthenticationConfiguration": {
                "AccessRoleArn": "arn:aws:iam::'$ACCOUNT_ID':role/AppRunnerECRAccessRole"
            }
        }' \
        --region $REGION > /dev/null
    
    echo "✅ Service update initiated"
    
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
fi

# Get service URL (this stays the same!)
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
echo "💡 No need to update Flutter app anymore!"
echo "🔄 Future deployments will update this same service"
echo ""
echo "💰 Cost: ~$15-20/month when idle, scales automatically"
echo "📊 Monitor: https://console.aws.amazon.com/apprunner/home?region=$REGION"

# Test the deployment
echo ""
echo "4️⃣ Testing deployment..."
sleep 30

if curl -f "https://$SERVICE_URL/health" > /dev/null 2>&1; then
    echo "✅ Health check passed!"
    
    echo "🧪 Testing anti-abuse endpoints..."
    if curl -f "https://$SERVICE_URL/documents/usage-stats" > /dev/null 2>&1; then
        echo "✅ Usage stats endpoint responding!"
    fi
    
    echo "🧪 Testing query endpoint..."
    curl -s -X POST "https://$SERVICE_URL/query" \
        -H "Content-Type: application/json" \
        -H "X-Session-ID: test-session" \
        -d '{"query": "test query"}' > /dev/null 2>&1 && echo "✅ Query endpoint responding!" || echo "⚠️ Query endpoint not responding"
else
    echo "⚠️ Health check failed, but service might still be starting up"
fi

echo ""
echo "✅ Stable deployment complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Update Flutter app baseUrl to: https://$SERVICE_URL"
echo "   2. Test document upload and anti-abuse features"
echo "   3. This URL will remain stable for all future deployments"
echo ""
echo "🔄 To update: just run this script again (URL stays same!)"
echo "🗑️ To delete: aws apprunner delete-service --service-arn $SERVICE_ARN --region $REGION" 