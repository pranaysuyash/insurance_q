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

## UI Layout Fixes

### Document Selection Dialog Overflow
- **Issue**: On smaller screens, the document list in the selection dialog could overflow and cause layout errors
- **Fix**:
  - Added a ConstrainedBox with a maximum height based on device screen size to limit the list height
  - Set the max height to 40% of the screen to ensure the dialog fits on smaller devices

### QA Answer Display Improvements
- **Issue**: Using Expanded widgets in certain layouts could cause Flutter layout errors when multiple conditions were true
- **Fix**:
  - Replaced Expanded widget with a Container having a fixed height based on screen size
  - Set the height to 50% of the screen height for better display of answers

### Null Safety Improvements 
- **Issue**: The QaSource.fromJson factory method wasn't handling null values correctly for the score property
- **Fix**:
  - Updated the score conversion to properly check if the value is a number type before conversion
  - Replaced `(json['score'] as num?)?.toDouble() ?? 0.0` with more robust `(json['score'] is num) ? (json['score'] as num).toDouble() : 0.0`

### Document Limit Messaging Improvements
- **Issue**: The document limit messaging was too alarming with text like "oldest will be removed"
- **Fix**:
  - Changed the message from "X/5 documents (oldest will be removed when limit reached)" to "X/5 documents (free storage limit)"
  - Applied this change in both the documents list screen and document selection dialog
  - Made the messaging more friendly while still conveying the limit

### Document Selection Improvements
- **Issue**: The QA screen didn't properly default to a sensible document when first loaded
- **Fix**:
  - Added a more sophisticated document selection algorithm that tries multiple options in priority order:
    1. Use explicit initial document ID if provided via navigation
    2. Use the previously selected document ID from recent session
    3. Use the most recently viewed document
    4. Use the last uploaded document
    5. Auto-select the only document if there's just one
  - Added storage for the most recently viewed document ID
  - Improved the document loading sequence to ensure documents are loaded before selection logic runs

## Dashboard Implementation

### Home Screen Development
- **Enhancement**: Created a comprehensive dashboard/home screen as the app's central hub
- **Implementation**:
  - Developed a modular architecture with separate widget methods for each component
  - Integrated Riverpod for efficient state management
  - Implemented asynchronous data loading with error handling
  - Created a responsive design that adapts to various screen sizes

### Dashboard Components
- **Welcome Card**:
  - Personalized greeting with document library status summary
  - Call-to-action for new users without documents
  - Clear, concise information presentation

- **Document Type Summary**:
  - Horizontal scrollable list of document type cards
  - Color-coded icons for different insurance categories
  - Dynamic display of document counts by type
  - Visual differentiation between categories with and without documents

- **Quick Actions**:
  - Grid layout of common functions
  - Direct navigation to upload, QA, and comparison features
  - Visual design with icon and color differentiation
  - Integration with insurance terminology dialog

- **Recent Activities**:
  - Chronological display of user interactions
  - Sections for recently uploaded documents and questions
  - Limited to most recent items to prevent information overload
  - Appropriate empty state handling

## Educational Content Integration

### Insurance Terminology Reference
- **Enhancement**: Added comprehensive insurance terminology education
- **Implementation**:
  - Created a complete glossary document with alphabetically organized terms
  - Integrated quick reference card on the dashboard with common terms
  - Implemented an interactive terminology dialog accessible from multiple points
  - Designed for progressive disclosure (common terms visible, comprehensive list available on demand)

### Terminology Dialog Features
- **UI Components**:
  - Alphabetical organization with letter headers
  - Clean presentation of terms and definitions
  - Scrollable interface for exploring all terms
  - Clean dialog design with proper navigation

- **Integration Points**:
  - Accessible from dashboard quick actions
  - Available through "View All" button on terminology card
  - Button to navigate to the full glossary documentation

## Storage Optimization Features

### Duplicate Document Detection
- **Issue**: Users could accidentally upload the same document multiple times, wasting their limited storage quota
- **Fix**:
  - Added duplicate document detection that checks both exact filename matches and similar filenames (ignoring version numbers or timestamps)
  - Implemented a confirmation dialog when duplicates are found with three options:
    1. Cancel: Abort the upload entirely
    2. Replace: Delete the existing document first, then upload the new one
    3. Keep Both: Continue with the upload, keeping both documents
  - The dialog shows information about the existing document (filename and upload date) to help users make informed decisions
  - Prevents users from accidentally wasting their 5-document storage limit

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
5. The Family Management and More screens need full implementation
6. Policy comparison functionality needs to be developed
7. Document filtering and sorting capabilities should be implemented

## RAG Answer Quality Debugging (May 2025)

- Added detailed debug logging to the RAG pipeline to log:
  - The top retrieved context chunks (with their text and metadata) for each query
  - The final prompt sent to the LLM
- This helps diagnose whether poor answers are due to retrieval, chunking, or prompt construction issues
- Next steps: Analyze logs for queries like "What is my policy number?" to see if the right context is being retrieved and sent to the LLM 