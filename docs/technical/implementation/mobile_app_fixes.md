# Mobile App Implementation: Issues and Fixes

## Android Build Issues

### File Picker Plugin Issues
- **Issue**: File_picker plugin was causing build errors due to v1 Android embedding references
- **Fix**: 
  - Updated to newer version (10.1.9)
  - Switched to file_selector package
  - Modified code to use file_selector's API
  - Updated compileSdk and targetSdk to 35

### Android Manifest Issues
- **Issue**: Multiple Android manifest errors
- **Fix**:
  - Added component declarations inside <application> tag
  - Fixed permissions structure
  - Updated MainActivity reference to use io.flutter.embedding.android.FlutterActivity

## API Connectivity Issues

### Backend API Implementation
- **Issue**: 404 errors when calling /documents endpoint
- **Fix**:
  - Created Document model in src/models/document.py
  - Implemented document API router in src/api/document.py
  - Added /documents endpoint to frontend service

### URL Configuration
- **Issue**: Mobile app couldn't connect to the API server
- **Fix**:
  - For emulator testing: Set URL to 10.0.2.2:8080
  - For physical device testing: Set URL to the WiFi IP address of the development machine (e.g., 192.168.1.12:8080)

## Docker Integration

### Docker Service Configuration
- **Issue**: Needed to connect mobile app to Docker-based services
- **Solution**:
  - Verified Docker containers are running correctly
  - Exposed necessary ports in docker-compose.yml
  - Updated API endpoint in mobile app to point to the correct Docker service

## QA Functionality Issues

### Question Formatting Issues
- **Issue**: Standard questions were resulting in 500 errors from the RAG service
- **Fix**:
  - Enhanced standard questions with more specific formatting to help the model
  - Added fallback to mock responses when API calls fail
  - Fixed QA screen to properly handle initial document selection

### Model Response Handling
- **Issue**: QaSource model didn't match the API's response format
- **Fix**:
  - Updated the QaSource.fromJson factory to accept both 'page_number' and 'page' fields
  - Improved error handling in the queryDocument method

## Offline Capability

### Local Storage Implementation
- **Feature**: Added ability to store and retrieve documents locally
- **Implementation**:
  - Created LocalStorageService for managing document storage
  - Updated document model to support JSON serialization/deserialization
  - Added UUID package for unique document ID generation

## Known Issues and Future Improvements

1. The QA functionality still sometimes falls back to mock responses when the backend RAG service encounters errors
2. Document uploads should implement progress indicators and better error handling
3. Local storage should be better integrated with remote storage with sync capabilities
4. Need to implement proper pagination for document lists when they grow large 