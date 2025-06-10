#!/bin/bash
set -e

echo "🚀 AWS App Runner Deployment for Insurance App"
echo "=============================================="

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first:"
    echo "   brew install awscli"
    echo "   aws configure"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run:"
    echo "   aws configure"
    exit 1
fi

# Set variables
APP_NAME="insurance-app"
REGION="us-east-1"
ECR_REPO_NAME="insurance-app-repo"

echo "✅ AWS CLI configured"
echo "📍 Region: $REGION"
echo "📦 App Name: $APP_NAME"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME"

echo "🔑 Account ID: $ACCOUNT_ID"

# Step 1: Create ECR repository
echo ""
echo "1️⃣ Creating ECR repository..."
aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $REGION 2>/dev/null || \
aws ecr create-repository --repository-name $ECR_REPO_NAME --region $REGION

echo "✅ ECR repository ready: $ECR_URI"

# Step 2: Build and push Docker image
echo ""
echo "2️⃣ Building and pushing Docker image..."

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

# Build the image
echo "🔨 Building Docker image..."
docker build -t $ECR_REPO_NAME .

# Tag and push
docker tag $ECR_REPO_NAME:latest $ECR_URI:latest
echo "📤 Pushing to ECR..."
docker push $ECR_URI:latest

echo "✅ Docker image pushed successfully"

# Step 3: Create App Runner service
echo ""
echo "3️⃣ Creating App Runner service..."

# Create apprunner.yaml configuration
cat > apprunner.yaml << EOF
version: 1.0
runtime: docker
build:
  commands:
    build:
      - echo "Using pre-built image"
run:
  runtime-version: latest
  command: uvicorn src.frontend.app:app --host 0.0.0.0 --port 8000
  network:
    port: 8000
    env: PORT
  env:
    - name: PORT
      value: "8000"
    - name: OPENAI_API_KEY
      value: "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"
    - name: QDRANT_URL
      value: "https://c0496763-dd69-4f30-9b8a-ca0b9294ddf2.us-east4-0.gcp.cloud.qdrant.io:6333"
    - name: QDRANT_API_KEY
      value: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0.gUETgUylDxoSvj1iw-P02in7mHnAkC5rL98tsqsSJYQ"
    - name: PYTHONPATH
      value: "/app"
EOF

# Create App Runner service configuration
cat > service-config.json << EOF
{
  "ServiceName": "$APP_NAME-frontend",
  "SourceConfiguration": {
    "ImageRepository": {
      "ImageIdentifier": "$ECR_URI:latest",
      "ImageConfiguration": {
        "Port": "8000",
        "RuntimeEnvironmentVariables": {
          "PORT": "8000",
          "OPENAI_API_KEY": "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",
          "QDRANT_URL": "https://c0496763-dd69-4f30-9b8a-ca0b9294ddf2.us-east4-0.gcp.cloud.qdrant.io:6333",
          "QDRANT_API_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0.gUETgUylDxoSvj1iw-P02in7mHnAkC5rL98tsqsSJYQ",
          "PYTHONPATH": "/app"
        },
        "StartCommand": "uvicorn src.frontend.app:app --host 0.0.0.0 --port 8000"
      },
      "ImageRepositoryType": "ECR"
    },
    "AutoDeploymentsEnabled": false
  },
  "InstanceConfiguration": {
    "Cpu": "0.25 vCPU",
    "Memory": "0.5 GB"
  }
}
EOF

# Create the App Runner service
echo "🚀 Creating App Runner service..."
SERVICE_ARN=$(aws apprunner create-service --cli-input-json file://service-config.json --region $REGION --query 'Service.ServiceArn' --output text)

echo "✅ App Runner service created: $SERVICE_ARN"

# Wait for service to be ready
echo ""
echo "4️⃣ Waiting for service to be ready..."
echo "⏳ This may take 5-10 minutes..."

while true; do
    STATUS=$(aws apprunner describe-service --service-arn $SERVICE_ARN --region $REGION --query 'Service.Status' --output text)
    echo "   Status: $STATUS"
    
    if [ "$STATUS" = "RUNNING" ]; then
        break
    elif [ "$STATUS" = "CREATE_FAILED" ] || [ "$STATUS" = "DELETE_FAILED" ]; then
        echo "❌ Service creation failed"
        exit 1
    fi
    
    sleep 30
done

# Get service URL
SERVICE_URL=$(aws apprunner describe-service --service-arn $SERVICE_ARN --region $REGION --query 'Service.ServiceUrl' --output text)

echo ""
echo "🎉 SUCCESS! Your insurance app is deployed!"
echo "============================================"
echo "🌐 Frontend URL: https://$SERVICE_URL"
echo "🔗 Health Check: https://$SERVICE_URL/health"
echo "📱 Mobile App Endpoint: https://$SERVICE_URL/query"
echo ""
echo "💰 Cost: ~$5/month when idle, scales automatically"
echo "📊 Monitor: https://console.aws.amazon.com/apprunner/home?region=$REGION"

# Test the deployment
echo ""
echo "5️⃣ Testing deployment..."
echo "🧪 Testing health endpoint..."
curl -f "https://$SERVICE_URL/health" || echo "⚠️ Health check failed, but service might still be starting"

echo ""
echo "✅ AWS deployment complete!"
echo "🔄 To update: just run this script again"
echo "🗑️ To delete: aws apprunner delete-service --service-arn $SERVICE_ARN --region $REGION"

# Clean up temporary files
rm -f apprunner.yaml service-config.json
