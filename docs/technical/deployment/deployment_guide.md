# Historical AWS Deployment Guide

> **SUPERSEDED for the CoverWise solo launch.** This document is preserved for
> migration history only. The current canonical plan is
> [`docs/planning/deployment_decision_2026-07-12.md`](../../planning/deployment_decision_2026-07-12.md).
> Do not run the AWS scripts, use the AWS URL, or treat the cost/status claims
> below as current.

## Single Deployment Script

**Use this script for all deployments**: `./deploy_aws_multiarch.sh`

### Consistent Names (Never Change)
- **ECR Repository**: `insurance-rag-enhanced-v2`
- **Service Name**: `insurance-app-enhanced-v2`
- **Region**: `ap-south-1` (Mumbai)

## How It Works

### First Deployment
```bash
./deploy_aws_multiarch.sh
```
- Creates ECR repository: `insurance-rag-enhanced-v2`
- Creates App Runner service: `insurance-app-enhanced-v2`
- Generates a stable URL that **never changes**

### Subsequent Deployments
```bash
./deploy_aws_multiarch.sh
```
- Updates the **same service** with new code
- **Same URL** - no Flutter app changes needed
- Zero downtime deployment

## Key Benefits

✅ **Stable URL**: Once deployed, URL never changes  
✅ **Single Script**: One script for all deployments  
✅ **Consistent Names**: Same repository and service names always  
✅ **No Confusion**: No multiple scripts or repositories  
✅ **Cost Effective**: Only one service running  

## Deployment Process

1. **Build**: Creates optimized Docker image with Dockerfile.aws
2. **Push**: Uploads to ECR repository `insurance-rag-enhanced-v2`
3. **Deploy**: Updates existing service or creates new one
4. **Test**: Validates all endpoints are working

## Service Configuration

- **CPU**: 1024 (1 vCPU)
- **Memory**: 2048 MB (2 GB)
- **Auto-scaling**: Enabled
- **Health Check**: `/health` endpoint
- **Cost**: ~$15-20/month when idle

## Environment Variables

All production environment variables are configured automatically:
- OpenAI API keys
- Qdrant vector database
- Redis cache
- Rate limiting settings
- Anti-abuse configuration

## Monitoring

- **AWS Console**: [App Runner Dashboard](https://console.aws.amazon.com/apprunner/home?region=ap-south-1)
- **Health Check**: `https://YOUR_URL/health`
- **Usage Stats**: `https://YOUR_URL/documents/usage-stats`
- **API Docs**: `https://YOUR_URL/docs`

## Flutter App Configuration

**One-time setup** in `mobile/lib/config/app_config.dart`:
```dart
static const String _productionBaseUrl = 'https://YOUR_STABLE_URL.ap-south-1.awsapprunner.com';
```

**That's it!** No more URL updates needed.

## Troubleshooting

### Build Issues
- Ensure Docker Desktop is running
- Check AWS credentials: `aws sts get-caller-identity`

### Deployment Issues
- Check AWS Console for detailed logs
- Verify IAM permissions for App Runner

### Service Issues
- Check health endpoint: `curl https://YOUR_URL/health`
- Review CloudWatch logs in AWS Console

## Cost Management

- **Single Service**: Only one App Runner service running
- **Auto-scaling**: Scales down when not in use
- **Predictable**: ~$15-20/month base cost
- **No Surprises**: No orphaned services from multiple deployments

## Migration from Old Approach

If you have old services running:

1. **List services**: `aws apprunner list-services --region ap-south-1`
2. **Delete old services**: `aws apprunner delete-service --service-arn <old-arn>`
3. **Use single script**: `./deploy_aws_multiarch.sh`

## Summary

- ✅ **One script**: `./deploy_aws_multiarch.sh`
- ✅ **Consistent names**: `insurance-rag-enhanced-v2` / `insurance-app-enhanced-v2`
- ✅ **Stable URL**: Never changes after first deployment
- ✅ **Simple process**: Build → Deploy → Done
- ✅ **Cost effective**: Single service, predictable costs

**No more confusion, no more changing URLs, no more multiple repositories!** 
