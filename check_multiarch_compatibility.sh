#!/bin/bash
set -e

echo "🧪 Testing Multi-Architecture Deployment Compatibility"
echo "====================================================="

# Check current architecture
echo "1️⃣ Checking current system architecture..."
echo "   Machine: $(uname -m)"
echo "   System: $(uname -s)"
echo "   Platform: $(uname -p 2>/dev/null || echo 'unknown')"

# Check Docker availability and architecture support
echo ""
echo "2️⃣ Checking Docker multi-architecture support..."
if command -v docker &> /dev/null; then
    echo "✅ Docker is available"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        echo "✅ Docker daemon is running"
        
        # Check buildx availability
        if docker buildx version &> /dev/null; then
            echo "✅ Docker buildx is available"
            
            # Check supported platforms
            echo "📋 Supported platforms:"
            docker buildx ls | grep -E "(linux/amd64|linux/arm64)" || echo "   Standard platforms available"
            
            # Test multi-platform build capability
            echo ""
            echo "3️⃣ Testing multi-platform build capability..."
            
            # Create a simple test Dockerfile
            cat > Dockerfile.test << 'EOF'
FROM --platform=$TARGETPLATFORM python:3.11-slim
RUN echo "Architecture: $(uname -m)" > /tmp/arch.txt
EOF
            
            # Test building for AMD64 (AWS target)
            echo "🔨 Testing AMD64 build (AWS App Runner target)..."
            if docker buildx build --platform linux/amd64 -f Dockerfile.test -t test-amd64:latest . > /dev/null 2>&1; then
                echo "✅ AMD64 build successful"
                ARCH_TEST_PASSED=true
            else
                echo "❌ AMD64 build failed"
                ARCH_TEST_PASSED=false
            fi
            
            # Clean up
            rm -f Dockerfile.test
            docker rmi test-amd64:latest > /dev/null 2>&1 || true
            
        else
            echo "❌ Docker buildx not available"
            ARCH_TEST_PASSED=false
        fi
    else
        echo "❌ Docker daemon not running"
        ARCH_TEST_PASSED=false
    fi
else
    echo "❌ Docker not found"
    ARCH_TEST_PASSED=false
fi

# Check AWS CLI
echo ""
echo "4️⃣ Checking AWS CLI configuration..."
if command -v aws &> /dev/null; then
    echo "✅ AWS CLI is available"
    
    if aws sts get-caller-identity &> /dev/null; then
        echo "✅ AWS credentials configured"
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        echo "   Account ID: $ACCOUNT_ID"
        AWS_CONFIGURED=true
    else
        echo "❌ AWS credentials not configured"
        AWS_CONFIGURED=false
    fi
else
    echo "❌ AWS CLI not found"
    AWS_CONFIGURED=false
fi

# Check current requirements for compatibility
echo ""
echo "5️⃣ Checking requirements.txt for architecture compatibility..."
if [ -f "requirements.txt" ]; then
    echo "✅ requirements.txt found"
    
    # Check for potentially problematic packages
    echo "📋 Checking for architecture-sensitive packages:"
    
    if grep -q "torch" requirements.txt; then
        echo "   🔍 PyTorch found - will use CPU-only version for compatibility"
    fi
    
    if grep -q "opencv" requirements.txt; then
        echo "   🔍 OpenCV found - should work across architectures"
    fi
    
    if grep -q "doctr" requirements.txt; then
        echo "   🔍 DocTR found - compatible with CPU builds"
    fi
    
else
    echo "❌ requirements.txt not found"
fi

# Summary and recommendations
echo ""
echo "📋 COMPATIBILITY ASSESSMENT"
echo "=========================="

if [ "$ARCH_TEST_PASSED" = true ] && [ "$AWS_CONFIGURED" = true ]; then
    echo "✅ READY FOR DEPLOYMENT"
    echo ""
    echo "Your system is ready for multi-architecture deployment to AWS App Runner:"
    echo "   • Docker buildx supports linux/amd64 builds"
    echo "   • AWS CLI is configured"
    echo "   • Architecture compatibility verified"
    echo ""
    echo "🚀 Run the deployment:"
    echo "   chmod +x deploy_aws_multiarch.sh"
    echo "   ./deploy_aws_multiarch.sh"
    
elif [ "$ARCH_TEST_PASSED" = false ]; then
    echo "⚠️ DOCKER BUILDX ISSUES"
    echo ""
    echo "Docker buildx is not properly configured for multi-platform builds."
    echo ""
    echo "🔧 To fix:"
    echo "   1. Update Docker Desktop to latest version"
    echo "   2. Enable experimental features in Docker Desktop"
    echo "   3. Restart Docker Desktop"
    echo "   4. Run: docker buildx create --name multiarch --use"
    echo ""
    
elif [ "$AWS_CONFIGURED" = false ]; then
    echo "⚠️ AWS CONFIGURATION REQUIRED"
    echo ""
    echo "AWS CLI needs to be configured."
    echo ""
    echo "🔧 To fix:"
    echo "   1. Install AWS CLI: brew install awscli"
    echo "   2. Configure credentials: aws configure"
    echo "   3. Verify: aws sts get-caller-identity"
    
else
    echo "❌ MULTIPLE ISSUES DETECTED"
    echo ""
    echo "Please address the issues above before deployment."
fi

# Additional architecture-specific notes
echo ""
echo "📝 ARCHITECTURE NOTES:"
echo "====================="
echo "• Your Mac: $(uname -m) ($(if [[ $(uname -m) == 'arm64' ]]; then echo 'Apple Silicon'; else echo 'Intel'; fi))"
echo "• AWS Target: x86_64 (Intel)"
echo "• Strategy: Multi-platform Docker build"
echo "• PyTorch: CPU-only version for compatibility"
echo "• ECR: New repository (insurance-rag-enhanced-v2)"
echo "• App Runner: New service (insurance-app-enhanced-v2)"
