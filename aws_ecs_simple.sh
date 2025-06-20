#!/bin/bash
set -ex

echo "🚀 AWS ECS Fargate Deployment for Insurance App"
echo "==============================================="

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
CLUSTER_NAME="$APP_NAME-cluster"
SERVICE_NAME="$APP_NAME-service"
TASK_FAMILY="$APP_NAME-task"

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

# Step 3: Create ECS Cluster
echo ""
echo "3️⃣ Creating ECS cluster..."
aws ecs describe-clusters --clusters $CLUSTER_NAME --region $REGION 2>/dev/null || \
aws ecs create-cluster --cluster-name $CLUSTER_NAME --region $REGION

echo "✅ ECS cluster ready: $CLUSTER_NAME"

# Get default VPC and subnets
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text --region $REGION)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text --region $REGION)

# Create security group for ECS tasks first
ECS_SG_ID=$(aws ec2 create-security-group \
  --group-name "$APP_NAME-ecs-sg" \
  --description "Security group for $APP_NAME ECS tasks" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' --output text 2>/dev/null || \
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$APP_NAME-ecs-sg" \
    --query 'SecurityGroups[0].GroupId' --output text --region $REGION)

# Step 4: Create ElastiCache for Redis instance
echo ""
echo "4️⃣ Creating AWS ElastiCache for Redis..."
REDIS_NODE_TYPE="cache.t2.micro" # Smallest, most cost-effective option
REDIS_CLUSTER_ID="$APP_NAME-redis-cluster"

# Create ElastiCache subnet group
aws elasticache describe-cache-subnet-groups --cache-subnet-group-name $SUBNET_GROUP_NAME --region $REGION 2>/dev/null || \
aws elasticache create-cache-subnet-group \
    --cache-subnet-group-name $SUBNET_GROUP_NAME \
    --description "Subnet group for $APP_NAME Redis" \
    --subnet-ids $SUBNET_IDS \
    --region $REGION

# Create security group for ElastiCache
REDIS_SG_ID=$(aws ec2 create-security-group \
  --group-name "$APP_NAME-redis-sg" \
  --description "Security group for $APP_NAME Redis" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' --output text 2>/dev/null || \
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$APP_NAME-redis-sg" \
    --query 'SecurityGroups[0].GroupId' --output text --region $REGION)

# Allow inbound Redis traffic from the ECS tasks
aws ec2 authorize-security-group-ingress \
  --group-id $REDIS_SG_ID \
  --protocol tcp \
  --port 6379 \
  --source-group $ECS_SG_ID \
  --region $REGION 2>/dev/null || true

# Create the Redis cluster
aws elasticache describe-cache-clusters --cache-cluster-id $REDIS_CLUSTER_ID --region $REGION 2>/dev/null || \
aws elasticache create-cache-cluster \
    --cache-cluster-id $REDIS_CLUSTER_ID \
    --engine redis \
    --cache-node-type $REDIS_NODE_TYPE \
    --num-cache-nodes 1 \
    --cache-subnet-group-name $SUBNET_GROUP_NAME \
    --security-group-ids $REDIS_SG_ID \
    --region $REGION

echo "⏳ Waiting for Redis cluster to become available..."
aws elasticache wait cache-cluster-available --cache-cluster-id $REDIS_CLUSTER_ID --region $REGION

REDIS_ENDPOINT=$(aws elasticache describe-cache-clusters \
    --cache-cluster-id $REDIS_CLUSTER_ID \
    --show-cache-node-info \
    --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
    --output text --region $REGION)

echo "✅ Redis cluster ready: $REDIS_ENDPOINT"

# Step 5: Create Task Definition
echo ""
echo "5️⃣ Creating task definition..."

# Use a heredoc to create the task definition with variables
cat > task-definition.json << EOF
{
  "family": "$TASK_FAMILY",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::$ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "$APP_NAME-container",
      "image": "$ECR_URI:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        { "name": "PORT", "value": "8000" },
        { "name": "OPENAI_API_KEY", "value": "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" },
        { "name": "QDRANT_URL", "value": "https://c0496763-dd69-4f30-9b8a-ca0b9294ddf2.us-east4-0.gcp.cloud.qdrant.io:6333" },
        { "name": "QDRANT_API_KEY", "value": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0.gUETgUylDxoSvj1iw-P02in7mHnAkC5rL98tsqsSJYQ" },
        { "name": "PYTHONPATH", "value": "/app" },
        { "name": "REDIS_HOST", "value": "$REDIS_ENDPOINT" },
        { "name": "REDIS_PORT", "value": "6379" },
        { "name": "REDIS_PASSWORD", "value": "" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/$APP_NAME",
          "awslogs-region": "$REGION",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

# Create CloudWatch log group
aws logs create-log-group --log-group-name "/ecs/$APP_NAME" --region $REGION 2>/dev/null || true

# Register task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json --region $REGION

echo "✅ Task definition registered"

# Step 6: Create Application Load Balancer
echo ""
echo "6️⃣ Creating Application Load Balancer..."

# Get default VPC and subnets
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text --region $REGION)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text --region $REGION)
SUBNET_ARRAY=($SUBNET_IDS)

echo "🌐 Using VPC: $VPC_ID"
echo "🌐 Using subnets: ${SUBNET_ARRAY[@]}"

# Create security group for ALB
ALB_SG_ID=$(aws ec2 create-security-group \
  --group-name "$APP_NAME-alb-sg" \
  --description "Security group for $APP_NAME ALB" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' --output text 2>/dev/null || \
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$APP_NAME-alb-sg" \
    --query 'SecurityGroups[0].GroupId' --output text --region $REGION)

# Allow HTTP traffic to ALB
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region $REGION 2>/dev/null || true

# Create security group for ECS tasks
ECS_SG_ID=$(aws ec2 create-security-group \
  --group-name "$APP_NAME-ecs-sg" \
  --description "Security group for $APP_NAME ECS tasks" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' --output text 2>/dev/null || \
  aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$APP_NAME-ecs-sg" \
    --query 'SecurityGroups[0].GroupId' --output text --region $REGION)

# Allow traffic from ALB to ECS tasks
aws ec2 authorize-security-group-ingress \
  --group-id $ECS_SG_ID \
  --protocol tcp \
  --port 8000 \
  --source-group $ALB_SG_ID \
  --region $REGION 2>/dev/null || true

# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name "$APP_NAME-alb" \
  --subnets ${SUBNET_ARRAY[@]} \
  --security-groups $ALB_SG_ID \
  --region $REGION \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || \
  aws elbv2 describe-load-balancers \
    --names "$APP_NAME-alb" \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text --region $REGION)

# Create target group
TG_ARN=$(aws elbv2 create-target-group \
  --name "$APP_NAME-tg" \
  --protocol HTTP \
  --port 8000 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-path "/health" \
  --region $REGION \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || \
  aws elbv2 describe-target-groups \
    --names "$APP_NAME-tg" \
    --query 'TargetGroups[0].TargetGroupArn' --output text --region $REGION)

# Create listener
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN \
  --region $REGION 2>/dev/null || true

echo "✅ Load balancer created"

# Step 7: Create ECS Service
echo ""
echo "7️⃣ Creating ECS service..."

cat > service-definition.json << EOF
{
  "serviceName": "$SERVICE_NAME",
  "cluster": "$CLUSTER_NAME",
  "taskDefinition": "$TASK_FAMILY",
  "desiredCount": 1,
  "launchType": "FARGATE",
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": ["${SUBNET_ARRAY[0]}", "${SUBNET_ARRAY[1]}"],
      "securityGroups": ["$ECS_SG_ID"],
      "assignPublicIp": "ENABLED"
    }
  },
  "loadBalancers": [
    {
      "targetGroupArn": "$TG_ARN",
      "containerName": "$APP_NAME-container",
      "containerPort": 8000
    }
  ]
}
EOF

aws ecs create-service --cli-input-json file://service-definition.json --region $REGION 2>/dev/null || \
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition $TASK_FAMILY --region $REGION

echo "✅ ECS service created"

# Step 8: Wait for service to be ready
echo ""
echo "8️⃣ Waiting for service to be ready..."
echo "⏳ This may take 5-10 minutes..."

while true; do
    RUNNING_COUNT=$(aws ecs describe-services \
      --cluster $CLUSTER_NAME \
      --services $SERVICE_NAME \
      --region $REGION \
      --query 'services[0].runningCount' --output text)
    
    echo "   Running tasks: $RUNNING_COUNT/1"
    
    if [ "$RUNNING_COUNT" = "1" ]; then
        break
    fi
    
    sleep 30
done

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --region $REGION \
  --query 'LoadBalancers[0].DNSName' --output text)

echo ""
echo "🎉 SUCCESS! Your insurance app is deployed!"
echo "============================================"
echo "🌐 Frontend URL: http://$ALB_DNS"
echo "🔗 Health Check: http://$ALB_DNS/health"
echo "📱 Mobile App Endpoint: http://$ALB_DNS/query"
echo ""
echo "💰 Cost: ~$36/month (predictable pricing)"
echo "📊 Monitor: https://console.aws.amazon.com/ecs/home?region=$REGION"

# Test the deployment
echo ""
echo "9️⃣ Testing deployment..."
echo "🧪 Testing health endpoint..."
curl -f "http://$ALB_DNS/health" || echo "⚠️ Health check failed, but service might still be starting"

echo ""
echo "✅ AWS ECS deployment complete!"
echo "🔄 To update: aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment --region $REGION"
echo "🗑️ To delete: aws ecs delete-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force --region $REGION"

# Clean up temporary files
rm -f task-definition.json service-definition.json
