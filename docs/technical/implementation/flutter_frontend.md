# Flutter Frontend Implementation

## Overview
The Flutter frontend provides a modern, intuitive interface for insurance document management and Q&A functionality.

## Key Features

### Document Management
- Upload insurance documents (PDF, images)
- View document library with metadata
- Document type detection and classification
- Offline storage with local SQLite database

### Q&A System
- Ask questions about uploaded documents
- Pre-defined question templates
- Custom question input
- Real-time answers from RAG backend

### Session Management
- UUID-based session tracking
- Rate limiting awareness
- Usage statistics display

### Lead Capture
- Optional email/phone collection
- Contact information persistence
- Lead generation workflow

## Recent Enhancements (December 2024)

### Enhanced Document Type Detection

#### Problem Solved
- Documents were showing as "Unknown" type instead of proper insurance categories
- Backend was returning correct information but Flutter app wasn't parsing it properly
- Users couldn't see if their documents were Health, Auto, Life, or other insurance types

#### Solution Implemented
1. **Improved Backend Response Parsing**
   - Enhanced `uploadFile()` method to extract document types from backend responses
   - Added fallback to filename-based inference when backend doesn't provide type
   - Better error handling and logging for document type detection

2. **Comprehensive Insurance Company Recognition**
   - Added detection for major Indian insurance companies:
     - Health: Niva Bupa, Star Health, Apollo Munich, Max Bupa, ICICI Lombard, HDFC Ergo
     - General: Bajaj Allianz, Oriental Insurance, New India Assurance, United India Insurance
   - Enhanced keyword matching for policy types (Health, Auto, Home, Life, Travel)

3. **Manual Refresh Functionality**
   - Added refresh button in Documents screen header
   - `refreshAllDocumentTypes()` method to force re-detection of all document types
   - User-friendly progress indicators and success/error messages

4. **Travel Insurance Support**
   - Added Travel Insurance as a new document type category
   - Updated UI icons and colors across all screens
   - Enhanced detection keywords for travel and overseas policies

#### Technical Implementation

**API Service Enhancements** (`mobile/lib/services/api_service.dart`):
```dart
// Enhanced document type inference with comprehensive matching
Future<String> inferDocumentTypeFromContent(String documentId) async {
  // Query backend for document type
  final result = await queryDocument(
    "What type of insurance policy is this? Please answer with just the type: Health Insurance, Auto Insurance, Home Insurance, Life Insurance, or Other Insurance.",
    documentId: documentId,
  );
  
  // Comprehensive matching including Indian insurance companies
  if (answer.contains('health') || answer.contains('niva bupa') || ...) {
    return 'Health Insurance';
  }
  // ... additional matching logic
}

// Force refresh all document types
Future<void> refreshAllDocumentTypes() async {
  final documents = await _localStorageService.getDocuments();
  for (final doc in documents) {
    final newType = await inferDocumentTypeFromContent(doc.id);
    if (newType != doc.documentType) {
      // Update document with new type
      await _localStorageService.updateDocument(updatedDoc);
    }
  }
}
```

**UI Enhancements**:
- Added Travel Insurance cards to dashboard
- Updated document icons across all screens (documents list, selection dialog)
- Added refresh button with loading states and user feedback

#### Results
- ✅ Niva Bupa policies now correctly detected as "Health Insurance"
- ✅ Document type cards show accurate counts in dashboard
- ✅ Users can manually refresh document types when needed
- ✅ Support for 5 insurance categories: Health, Auto, Home, Life, Travel
- ✅ Comprehensive Indian insurance company recognition

### Code Structure

#### Key Files Modified
- `mobile/lib/services/api_service.dart` - Enhanced document type detection logic
- `mobile/lib/screens/documents_screen.dart` - Added refresh functionality
- `mobile/lib/screens/dashboard_screen.dart` - Added Travel Insurance support
- `mobile/lib/screens/documents_list.dart` - Updated document icons
- `mobile/lib/screens/document_selection_dialog.dart` - Updated document icons

#### Testing Approach
- Verified with existing Niva Bupa health insurance documents
- Tested manual refresh functionality
- Confirmed UI updates across all screens
- Validated backend integration and response parsing

This enhancement significantly improves the user experience by providing accurate document categorization and giving users control over the detection process through manual refresh capabilities. 