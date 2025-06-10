#!/bin/bash
set -e

echo "🚀 AWS App Runner - FULL RAG SERVICE DEPLOYMENT (MUMBAI)"
echo "=========================================================="
echo "🎯 Deploying complete RAG service to ap-south-1"

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install it first:"
    echo "   brew install awscli"
    echo "   aws configure"
    exit 1
fi

# Set variables
AWS_PROFILE_OPT=""
if [ -n "$AWS_PROFILE" ]; then
  AWS_PROFILE_OPT="--profile $AWS_PROFILE"
  echo "👤 Using AWS Profile: $AWS_PROFILE"
fi

# Check AWS credentials
if ! aws sts get-caller-identity --region ap-south-1 $AWS_PROFILE_OPT &> /dev/null; then
    echo "❌ AWS credentials not configured for ap-south-1. Please run:"
    echo "   aws configure --profile <your-profile-name>"
    echo "Then run the script with: AWS_PROFILE=<your-profile-name> bash deploy_mumbai_rag_final.sh"
    exit 1
fi

APP_NAME="insurance-rag-service-mumbai"
REGION="ap-south-1"
ECR_REPO_NAME="insurance-rag-full-mumbai"

echo "✅ AWS CLI configured"
echo "📍 Region: $REGION"
echo "📦 App Name: $APP_NAME"

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text $AWS_PROFILE_OPT)
ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME"

echo "🔑 Account ID: $ACCOUNT_ID"

# Step 1: Create ECR repository
echo ""
echo "1️⃣ Creating ECR repository..."
aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $REGION $AWS_PROFILE_OPT 2>/dev/null || \
aws ecr create-repository --repository-name $ECR_REPO_NAME --region $REGION $AWS_PROFILE_OPT

echo "✅ ECR repository ready: $ECR_URI"

# Step 2: Create production-ready Dockerfile
echo ""
echo "2️⃣ Creating production-ready Dockerfile..."

cat > Dockerfile.production << 'EOF'
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies for production
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    software-properties-common \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies with production settings
# Using --timeout to handle potential network issues during pip install
RUN pip install --upgrade pip && \
    pip install --no-cache-dir --timeout 1000 --retries 5 -r requirements.txt

# Copy application code
COPY src/ src/

# Create necessary directories
RUN mkdir -p /app/uploads /app/temp /app/logs

# Set environment variables for production
ENV PYTHONPATH="/app"
ENV PYTHONUNBUFFERED=1
ENV LOG_LEVEL=INFO

# Add health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Run the full RAG service
CMD ["uvicorn", "src.rag.service:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--log-level", "info"]
EOF

echo "✅ Production Dockerfile created"

# Step 3: Use existing requirements.txt
echo ""
echo "3️⃣ Using existing requirements.txt for production..."
if [ ! -f "requirements.txt" ]; then
    echo "❌ requirements.txt not found! Please ensure it exists and contains all necessary packages."
    exit 1
fi
echo "✅ Found requirements.txt"


# Step 4: Build and push Docker image
echo ""
echo "4️⃣ Building and pushing full production Docker image..."

# Login to ECR
aws ecr get-login-password --region $REGION $AWS_PROFILE_OPT | docker login --username AWS --password-stdin $ECR_URI

# Build the production image
echo "🔨 Building production Docker image with all dependencies..."
docker build -f Dockerfile.production -t $ECR_REPO_NAME .

# Tag and push
docker tag $ECR_REPO_NAME:latest $ECR_URI:latest
echo "📤 Pushing to ECR..."
docker push $ECR_URI:latest

echo "✅ Full production Docker image pushed successfully"

# Step 5: Create App Runner service configuration file
echo ""
echo "5️⃣ Creating App Runner service configuration file (rag-service-config-mumbai.json)..."
echo "IMPORTANT: You must fill in the placeholder values in this file before proceeding."

cat > rag-service-config-mumbai.json << 'EOF'
{
  "ServiceName": "insurance-rag-service-mumbai",
  "SourceConfiguration": {
    "ImageRepository": {
      "ImageIdentifier": "YOUR_ECR_URI_PLACEHOLDER",
      "ImageConfiguration": {
        "Port": "8000",
        "RuntimeEnvironmentVariables": {
          "PORT": "8000",
          "PYTHONPATH": "/app",
          "PYTHONUNBUFFERED": "1",
          "LOG_LEVEL": "INFO",
          "OPENAI_API_KEY": "YOUR_OPENAI_API_KEY",
          "QDRANT_URL": "YOUR_QDRANT_URL",
          "QDRANT_API_KEY": "YOUR_QDRANT_API_KEY",
          "QDRANT_COLLECTION": "insurance_documents_v3_mumbai",
          "REDIS_HOST": "YOUR_REDIS_HOST",
          "REDIS_PORT": "6379",
          "REDIS_PASSWORD": "YOUR_REDIS_PASSWORD",
          "CACHE_TTL_SECONDS": "3600",
          "EMBEDDING_MODEL": "sentence-transformers/all-mpnet-base-v2",
          "OPENAI_EMBEDDING_MODEL": "text-embedding-ada-002",
          "OPENAI_CHAT_MODEL": "gpt-4-turbo",
          "USE_OPENAI_FIRST": "true"
        }
      },
      "ImageRepositoryType": "ECR"
    },
    "AutoDeploymentsEnabled": true
  },
  "InstanceConfiguration": {
    "Cpu": "2 vCPU",
    "Memory": "4 GB"
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/health",
    "Interval": 20,
    "Timeout": 10,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  }
}
EOF

# Replace placeholder for ECR URI
sed -i.bak "s|YOUR_ECR_URI_PLACEHOLDER|$ECR_URI:latest|" rag-service-config-mumbai.json && rm rag-service-config-mumbai.json.bak

echo "✅ App Runner configuration created: rag-service-config-mumbai.json"
echo "🛑 PLEASE EDIT rag-service-config-mumbai.json and replace placeholder values for:"
echo "   - OPENAI_API_KEY"
echo "   - QDRANT_URL"
echo "   - QDRANT_API_KEY"
echo "   - REDIS_HOST"
echo "   - REDIS_PASSWORD (if any, otherwise it can be an empty string)"
echo ""
echo "After editing, you can create or update the service by running:"
echo "aws apprunner create-service --cli-input-json file://rag-service-config-mumbai.json --region ap-south-1 $AWS_PROFILE_OPT"
echo "or for updates:"
echo "aws apprunner update-service --service-arn <your-service-arn> --source-configuration file://rag-service-config-mumbai.json --region ap-south-1 $AWS_PROFILE_OPT"

# Step 6: Deploy to App Runner (Commented out by default)
# echo ""
# echo "6️⃣ Deploying to App Runner..."
# echo "If you have filled the config file, uncomment the following lines to deploy."
#
# SERVICE_ARN_EXISTS=$(aws apprunner list-services --region $REGION --query "ServiceSummaryList[?ServiceName=='$APP_NAME'].ServiceArn" --output text $AWS_PROFILE_OPT)
#
# if [ -z "$SERVICE_ARN_EXISTS" ]; then
#   echo "🚀 Creating new App Runner service..."
#   aws apprunner create-service --cli-input-json file://rag-service-config-mumbai.json --region $REGION $AWS_PROFILE_OPT
# else
#    echo "🚀 Updating existing App Runner service..."
#    aws apprunner update-service --service-arn $SERVICE_ARN_EXISTS --source-configuration file://rag-service-config-mumbai.json --region $REGION $AWS_PROFILE_OPT
# fi
#
# echo "✅ Deployment command executed. Check the AWS console for status."

echo "✅ Script finished. Manual deployment step is next." 