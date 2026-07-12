#!/bin/bash
set -e

# Load secrets from .env if present (never hardcode secrets in this file)
if [ -f .env ]; then set -a; source .env; set +a; fi
: "${OPENAI_API_KEY:?OPENAI_API_KEY must be set in .env or environment}"
: "${QDRANT_API_KEY:?QDRANT_API_KEY must be set in .env or environment}"

echo "🚀 Deploying Enhanced Insurance RAG App with Document Processing"
echo "============================================================="

# Configuration
REGION="ap-south-1"
ECR_REPO_NAME="insurance-rag-enhanced"
SERVICE_NAME="insurance-app-enhanced"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME"

echo "✅ Account ID: $ACCOUNT_ID"
echo "📦 ECR URI: $ECR_URI"
echo "🆕 Service Name: $SERVICE_NAME"
echo "🔧 Features: OCR + RAG + Document Processing Pipeline"

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

# Step 1: Create ECR repository if it doesn't exist
echo ""
echo "1️⃣ Ensuring ECR repository exists..."
aws ecr create-repository \
    --repository-name $ECR_REPO_NAME \
    --region $REGION \
    --image-scanning-configuration scanOnPush=false \
    --encryption-configuration encryptionType=AES256 > /dev/null 2>&1 || echo "Repository '$ECR_REPO_NAME' already exists. Skipping creation."

# Step 2: Build and push image
echo ""
echo "2️⃣ Building and pushing Docker image..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

echo "🔨 Building Docker image with enhanced document processing..."
docker build -f Dockerfile -t $ECR_REPO_NAME:latest .
docker tag $ECR_REPO_NAME:latest $ECR_URI:latest

echo "📤 Pushing to ECR..."
docker push $ECR_URI:latest
echo "✅ Docker image pushed successfully"

# Step 3: Create IAM role for App Runner (if it doesn't exist)
echo ""
echo "3️⃣ Ensuring IAM role exists for App Runner..."
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

# Step 4: Create App Runner service configuration
echo ""
echo "4️⃣ Creating App Runner service configuration..."
cat > enhanced-service-config.json << EOF
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
          "OPENAI_API_KEY": "$OPENAI_API_KEY",
          "QDRANT_URL": "https://c0496763-dd69-4f30-9b8a-ca0b9294ddf2.us-east4-0.gcp.cloud.qdrant.io:6333",
          "QDRANT_API_KEY": "$QDRANT_API_KEY",
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
          "ENVIRONMENT": "production"
        },
        "StartCommand": "uvicorn src.app.main:app --host 0.0.0.0 --port 8000"
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
echo "✅ Configuration file 'enhanced-service-config.json' created."

# Step 5: Delete existing service if it exists
echo ""
echo "5️⃣ Checking for existing service..."
EXISTING_SERVICE_ARN=$(aws apprunner list-services --region $REGION --query "ServiceSummaryList[?ServiceName=='$SERVICE_NAME'].ServiceArn" --output text)

if [ ! -z "$EXISTING_SERVICE_ARN" ] && [ "$EXISTING_SERVICE_ARN" != "None" ]; then
    echo "🗑️ Found existing service. Deleting it first..."
    aws apprunner delete-service --service-arn "$EXISTING_SERVICE_ARN" --region $REGION
    
    echo "⏳ Waiting for service deletion to complete..."
    while true; do
        STATUS=$(aws apprunner describe-service --service-arn "$EXISTING_SERVICE_ARN" --region $REGION --query 'Service.Status' --output text 2>/dev/null || echo "DELETED")
        if [ "$STATUS" == "DELETED" ] || [ "$STATUS" == "None" ]; then
            break
        fi
        echo "   Current status: $STATUS"
        sleep 30
    done
    echo "✅ Existing service deleted successfully"
fi

# Step 6: Create the new service
echo ""
echo "6️⃣ Creating enhanced App Runner service '$SERVICE_NAME'..."
SERVICE_ARN=$(aws apprunner create-service \
    --cli-input-json file://enhanced-service-config.json \
    --region $REGION \
    --query 'Service.ServiceArn' --output text)

if [ -z "$SERVICE_ARN" ]; then
    echo "❌ Service creation failed. Please check the AWS console for more details."
    exit 1
fi

echo "✅ Service creation initiated. ARN: $SERVICE_ARN"

# Step 7: Monitor service creation
echo ""
echo "7️⃣ Monitoring service creation..."
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

# Step 8: Get service details and test
SERVICE_URL=$(aws apprunner describe-service --service-arn "$SERVICE_ARN" --region $REGION --query 'Service.ServiceUrl' --output text)

echo ""
echo "🎉 SUCCESS! Enhanced Insurance RAG App is deployed!"
echo "======================================================="
echo "🌐 Service URL: https://$SERVICE_URL"
echo "🔗 Health Check: https://$SERVICE_URL/health"
echo "📱 Mobile API Endpoint: https://$SERVICE_URL/query"
echo "📄 Document Upload: https://$SERVICE_URL/documents/upload"
echo "🔍 Processing Status: https://$SERVICE_URL/processing/status"
echo ""
echo "🚀 New Features:"
echo "   • Complete Document Processing Pipeline (OCR → RAG → Vector DB)"
echo "   • Real-time Processing Status Tracking"
echo "   • Enhanced Document Upload with Background Processing"
echo "   • Actual Document Querying (not dummy responses)"
echo "   • Support for PDF, PNG, JPG, TIFF formats"
echo ""
echo "💰 Cost: ~$10-15/month when idle, scales automatically"
echo "📊 Monitor: https://console.aws.amazon.com/apprunner/home?region=$REGION"

# Step 9: Test the deployment
echo ""
echo "8️⃣ Testing deployment..."
echo "🧪 Testing health endpoint..."
sleep 20  # Give service time to fully start

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
    
else
    echo "⚠️ Health check failed, but service might still be starting up"
    echo "🔍 Check the App Runner console for logs if issues persist"
fi

# Clean up temporary files
rm -f enhanced-service-config.json

echo ""
echo "✅ Enhanced AWS deployment complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Test document upload using the mobile app or API"
echo "   2. Upload a PDF document and check processing status"
echo "   3. Try querying the uploaded document"
echo "   4. Monitor processing logs in App Runner console"
echo ""
echo "🔄 To update: just run this script again"
echo "🗑️ To delete: aws apprunner delete-service --service-arn $SERVICE_ARN --region $REGION"
