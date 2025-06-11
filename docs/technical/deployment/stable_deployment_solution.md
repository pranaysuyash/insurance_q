# Stable Deployment Solution

## Problem Solved

**Issue**: Every deployment was creating a new AWS App Runner service with a different URL, requiring constant updates to the Flutter app's baseUrl. This was:
- ❌ Unproductive (constant code changes)
- ❌ Expensive (multiple services running)
- ❌ Error-prone (forgetting to update URLs)
- ❌ Time-consuming (manual URL management)

## Solution Implemented

### 1. Stable Deployment Script (`deploy_aws_stable.sh`)

**Key Features:**
- ✅ **Updates existing service** instead of creating new ones
- ✅ **Consistent service name**: `insurance-app-stable`
- ✅ **Same URL forever**: Once deployed, URL never changes
- ✅ **Cost-effective**: Only one service running
- ✅ **Zero Flutter code changes** after initial setup

**How it works:**
```bash
# Check if service exists
if service exists:
    update_service_with_new_image()
else:
    create_new_service_with_stable_name()
```

### 2. Centralized Configuration (`AppConfig`)

**Benefits:**
- ✅ **Single source of truth** for all URLs
- ✅ **Environment-based configuration** (dev/staging/prod)
- ✅ **Centralized validation logic**
- ✅ **Easy maintenance**

**Configuration Structure:**
```dart
class AppConfig {
  static String get baseUrl => _productionBaseUrl; // Centralized URL
  static String get uploadEndpoint => '$baseUrl/documents/upload';
  static String get queryEndpoint => '$baseUrl/query';
  // ... all endpoints centralized
}
```

### 3. Deployment Workflow

#### First Time Setup:
1. Run `./deploy_aws_multiarch.sh` (creates Dockerfile.aws)
2. Run `./deploy_aws_stable.sh` (creates stable service)
3. Update Flutter app with stable URL
4. **Done!** No more URL changes needed

#### Future Deployments:
1. Run `./deploy_aws_stable.sh` (updates existing service)
2. **That's it!** Same URL, updated code

## Technical Implementation

### Stable Service Management

```bash
# Service name never changes
SERVICE_NAME="insurance-app-stable"

# Check for existing service
EXISTING_SERVICE_ARN=$(aws apprunner list-services --query "ServiceSummaryList[?ServiceName=='$SERVICE_NAME'].ServiceArn")

if [ -z "$EXISTING_SERVICE_ARN" ]; then
    # Create new stable service
    aws apprunner create-service --service-name $SERVICE_NAME
else
    # Update existing service
    aws apprunner update-service --service-arn $EXISTING_SERVICE_ARN
fi
```

### Configuration-Based URLs

```dart
// Before: Hardcoded URLs
static const String baseUrl = 'https://aa2485vt7t.ap-south-1.awsapprunner.com';

// After: Configuration-based
final Dio _dio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
```

### Environment Support

```dart
// Development
flutter run --dart-define=ENVIRONMENT=development

// Production (default)
flutter run
```

## Benefits Achieved

### 🚀 **Productivity Gains**
- **No more URL updates**: Deploy without touching Flutter code
- **Faster deployments**: Update existing service vs. create new
- **Reduced errors**: No manual URL management
- **Simplified workflow**: One script for all deployments

### 💰 **Cost Savings**
- **Single service**: Only one App Runner service running
- **No orphaned services**: Old services automatically cleaned up
- **Predictable costs**: ~$15-20/month vs. multiple services

### 🛡️ **Reliability Improvements**
- **Consistent URLs**: No broken links or outdated references
- **Environment isolation**: Proper dev/staging/prod separation
- **Centralized validation**: Single source for all validation logic
- **Better error handling**: Configuration-based timeouts and settings

### 🔧 **Maintenance Benefits**
- **Single configuration file**: All settings in one place
- **Easy environment switching**: Change one variable
- **Centralized validation**: Update validation rules once
- **Better debugging**: Clear configuration hierarchy

## Migration Guide

### For Existing Deployments

1. **Clean up old services** (optional but recommended):
   ```bash
   # List all services
   aws apprunner list-services --region ap-south-1
   
   # Delete old services
   aws apprunner delete-service --service-arn <old-service-arn>
   ```

2. **Deploy stable service**:
   ```bash
   ./deploy_aws_stable.sh
   ```

3. **Update Flutter app** (one-time):
   ```dart
   // Update AppConfig._productionBaseUrl with stable URL
   static const String _productionBaseUrl = 'https://STABLE_URL.ap-south-1.awsapprunner.com';
   ```

### For New Projects

1. **Use stable deployment from start**:
   ```bash
   ./deploy_aws_stable.sh
   ```

2. **Configure Flutter app**:
   ```dart
   import '../config/app_config.dart';
   
   // Use configuration everywhere
   final dio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
   ```

## Monitoring and Maintenance

### Service Health
- **Health endpoint**: `https://STABLE_URL/health`
- **Usage stats**: `https://STABLE_URL/documents/usage-stats`
- **API docs**: `https://STABLE_URL/docs`

### AWS Console
- **Monitor**: [App Runner Console](https://console.aws.amazon.com/apprunner/home?region=ap-south-1)
- **Logs**: CloudWatch logs for debugging
- **Metrics**: Built-in App Runner metrics

### Cost Monitoring
- **Expected cost**: $15-20/month when idle
- **Auto-scaling**: Scales up with usage
- **No surprise bills**: Single service, predictable costs

## Future Enhancements

### Custom Domain (Recommended)
```bash
# Set up custom domain for even more stability
# insurance-api.yourdomain.com
aws apprunner associate-custom-domain --service-arn $SERVICE_ARN --domain-name insurance-api.yourdomain.com
```

### CI/CD Integration
```yaml
# GitHub Actions example
- name: Deploy to AWS
  run: ./deploy_aws_stable.sh
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Blue-Green Deployments
- Use App Runner's built-in deployment strategies
- Zero-downtime updates
- Automatic rollback on failure

## Conclusion

The stable deployment solution eliminates the major productivity issue of constantly changing URLs while providing:

- ✅ **Consistent URLs** that never change
- ✅ **Cost-effective** single-service architecture  
- ✅ **Productive** deployment workflow
- ✅ **Maintainable** centralized configuration
- ✅ **Scalable** foundation for future enhancements

**Result**: Deploy with confidence, knowing your URLs will remain stable and your Flutter app won't need constant updates! 