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

# Prompt for secrets securely
echo ""
echo "🔐 Please provide the following secrets for deployment:"
read -sp 'Enter your OpenAI API Key: ' OPENAI_API_KEY
echo
read -p 'Enter your Qdrant URL: ' QDRANT_URL
read -sp 'Enter your Qdrant API Key: ' QDRANT_API_KEY
echo
read -p 'Enter path to Firebase service account JSON file: ' FIREBASE_SERVICE_ACCOUNT_PATH
echo

# Validate Firebase service account file
if [ ! -f "$FIREBASE_SERVICE_ACCOUNT_PATH" ]; then
    echo "❌ Firebase service account file not found: $FIREBASE_SERVICE_ACCOUNT_PATH"
    exit 1
fi

# Convert Firebase service account to base64 for environment variable
FIREBASE_SERVICE_ACCOUNT_B64=$(base64 -i "$FIREBASE_SERVICE_ACCOUNT_PATH")
echo "✅ Firebase service account loaded"

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
      value: "$OPENAI_API_KEY"
    - name: QDRANT_URL
      value: "$QDRANT_URL"
    - name: QDRANT_API_KEY
      value: "$QDRANT_API_KEY"
    - name: FIREBASE_SERVICE_ACCOUNT_B64
      value: "$FIREBASE_SERVICE_ACCOUNT_B64"
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
          "OPENAI_API_KEY": "$OPENAI_API_KEY",
          "QDRANT_URL": "$QDRANT_URL",
          "QDRANT_API_KEY": "$QDRANT_API_KEY",
          "FIREBASE_SERVICE_ACCOUNT_B64": "$FIREBASE_SERVICE_ACCOUNT_B64",
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
