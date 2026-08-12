# README — Historical AWS App Runner section (archived 2026-08-12)

> Archived from README.md lines 71–143. Self-labeled historical (June 2025); explicit note in original: do not use the AWS URL, scripts, service names, or cost claims for the CoverWise solo launch.

## Historical company-era status: AWS App Runner

> Historical snapshot from June 2025. Do not use the AWS URL, scripts, service
> names, or cost claims below for the CoverWise solo launch.

**Last Updated**: June 11, 2025  
**Deployment Status**: ✅ **Fully Operational on AWS App Runner**  
**Mobile App**: v0.1.2+11 - Updated and tested with AWS backend  

### Quick Links
- **Production Service**: https://nrmmvtpyaf.ap-south-1.awsapprunner.com ✅ **Fully Operational**
- **Mobile App**: Android APK ready with updated AWS integration
- **Migration Documentation**: [docs/technical/deployment/aws_migration_complete.md](docs/technical/deployment/aws_migration_complete.md)
- **Deployment Scripts**: `deploy_aws_multiarch.sh` (multi-platform), `aws_deployment.sh` (legacy)

## 📱 Features

### Core Functionality ✅
- **Document Upload**: Upload insurance policies (PDF, JPG, PNG)
- **OCR Processing**: Extract text from insurance documents
- **Intelligent Q&A**: Ask questions about your policies
- **Document Management**: View and organize your insurance documents
- **Offline Mode**: Full functionality without internet connection

### Technical Features ✅
- **Cross-Platform**: Flutter app for Android and iOS
- **Cloud Backend**: AWS App Runner with reliable container deployment
- **AI/ML Integration**: OpenAI GPT for intelligent responses
- **Vector Search**: Qdrant cloud for semantic document search
- **Local Storage**: SQLite for offline document management
- **Caching**: Redis cloud for performance optimization

## 🏗️ Architecture

### Backend Services (AWS)
- **App Runner Service**: Complete RAG pipeline with OCR, Q&A, and document management ✅ **Fully Operational**
- **Vector Database**: Qdrant cloud for semantic search ✅ **Operational**
- **Cache Layer**: Redis cloud for performance optimization ✅ **Operational**
- **Container Registry**: AWS ECR for Docker image management ✅ **Operational**
- **Monitoring**: CloudWatch for logging and observability ✅ **Operational**

### Mobile App (Flutter)
- **Cross-platform**: Android and iOS support
- **Offline-first**: Local storage with cloud sync
- **Modern UI**: Material Design with custom theming
- **Performance**: Optimized builds (50MB APK, 31MB iOS)
- **Version**: 0.1.2+11 with AWS backend integration

## 🚀 Deployment Status

### ✅ Completed (AWS Migration)
- [x] AWS App Runner infrastructure deployed
- [x] Complete RAG service running and accessible
- [x] Flutter app updated for AWS backend (v0.1.2+11)
- [x] Release builds created (Android APK + iOS)
- [x] API integration tested and working
- [x] Documentation updated with migration learnings
- [x] All deployment issues resolved (June 10, 2025)
- [x] Qdrant cloud vector database operational
- [x] Redis cloud caching operational
- [x] Codebase cleaned of obsolete scripts

### 🎯 Current Status
- **Backend**: 100% operational on AWS App Runner
- **Mobile App**: Ready for distribution
- **Testing**: All tests passing
- **Documentation**: Complete with migration guide

### 📦 Build Artifacts
- **Android APK**: `mobile/build/app/outputs/flutter-apk/app-release.apk` (50MB)
- **iOS App**: `mobile/build/ios/iphoneos/Runner.app` (31MB)
- **Deployment Scripts**: `aws_deployment.sh`, `aws_ecs_simple.sh`

