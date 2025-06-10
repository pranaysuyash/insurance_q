#!/bin/bash
set -e

USER_NAME="insurance_app_runner"
REGION="ap-south-1"

echo "🔐 Setting up IAM Permissions for Redis/VPC Operations"
echo "====================================================="
echo "User: $USER_NAME"
echo "Region: $REGION"
echo ""

# Step 1: Create policy for ElastiCache operations
echo "1️⃣ Creating ElastiCache policy..."

cat > elasticache-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "elasticache:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name ElastiCacheFullAccess \
    --policy-document file://elasticache-policy.json \
    --description "Full access to ElastiCache for Redis setup" || echo "Policy may already exist"

echo "✅ ElastiCache policy created"

# Step 2: Create policy for VPC operations
echo ""
echo "2️⃣ Creating VPC policy..."

cat > vpc-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:CreateSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:DeleteSecurityGroup",
                "ec2:DescribeAvailabilityZones"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name VPCLimitedAccess \
    --policy-document file://vpc-policy.json \
    --description "Limited VPC access for ElastiCache setup" || echo "Policy may already exist"

echo "✅ VPC policy created"

# Step 3: Get account ID and attach policies to user
echo ""
echo "3️⃣ Attaching policies to user..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Attach ElastiCache policy
aws iam attach-user-policy \
    --user-name $USER_NAME \
    --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/ElastiCacheFullAccess" || echo "ElastiCache policy may already be attached"

# Attach VPC policy
aws iam attach-user-policy \
    --user-name $USER_NAME \
    --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/VPCLimitedAccess" || echo "VPC policy may already be attached"

echo "✅ Policies attached to user"

# Step 4: List current user policies
echo ""
echo "4️⃣ Current user policies:"
aws iam list-attached-user-policies --user-name $USER_NAME --output table

echo ""
echo "🎉 IAM permissions setup complete!"
echo ""
echo "The user '$USER_NAME' now has permissions for:"
echo "✅ ElastiCache operations (create, manage Redis clusters)"
echo "✅ VPC operations (describe VPCs, manage security groups)"
echo ""
echo "You can now run the Redis setup script:"
echo "bash setup_aws_redis.sh"

# Cleanup
rm -f elasticache-policy.json vpc-policy.json 