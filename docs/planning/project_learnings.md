# Learnings from the Insurance App Project

This document captures key lessons learned during the development of our Insurance Document Processing application.

## 1. UI/UX Considerations

### Mobile App Text Display
- **Issue:** Flutter app displayed only ~5 lines of OCR-extracted text despite backend fully processing documents
- **Root Cause:** Text widget had explicit limits (`maxLines: 8, overflow: TextOverflow.ellipsis`)
- **Solution:** Implemented scrollable container for text display
- **Lesson:** Always implement scrollable containers for potentially long text content, especially when dealing with document processing applications

### API Timeouts
- **Issue:** Large document processing occasionally timed out
- **Solution:** Increased API service timeout from 60 to 90 seconds
- **Lesson:** When dealing with document processing, implement appropriate timeouts and provide visual feedback to users during processing

### QA Feature Implementation
- **Innovation:** Designed and implemented structured Question & Answer system with standard questions library
- **Approach:** Organized pre-defined questions by categories (Policy Basics, Coverage Details, etc.)
- **UI/UX:** Created tabbed interface for standard questions, custom questions, and history
- **Lesson:** Organizing common insurance-related questions into categories helps users quickly find relevant information

## 2. Backend Infrastructure

### OCR Processing
- **Issue:** HuggingFace Inference API for `mindee/doctr-ocr` started failing (404)
- **Solution:** Switched to local `python-doctr` for OCR processing
- **Lesson:** Maintain fallback options for critical third-party dependencies

### System Dependencies
- **Issue:** Various `ImportError`s in `ocr_service` after switching to local OCR processing
- **Solution:** Added system libraries to `Dockerfile` to support OpenCV requirements
- **Lesson:** When containerizing applications with complex dependencies (especially those with system-level requirements like OpenCV), document all required system packages

### Logging Configuration
- **Issue:** Application-level logs not appearing in Docker container logs
- **Status:** Still investigating
- **Lesson:** Set up comprehensive logging early in development with verification that logs are properly captured

## 3. Testing & Verification Strategies

### Data Extraction Verification
- **Issue:** Uncertain if OCR was extracting complete document text
- **Solution:** Used direct API endpoint to verify complete data extraction and cached results
- **Lesson:** Implement direct data inspection endpoints to bypass UI for troubleshooting

### Separating UI from Data Issues
- **Issue:** Initially suspected backend data extraction issues when the problem was in the UI presentation
- **Solution:** Verified data extraction separately from UI display
- **Lesson:** When troubleshooting, isolate potential problem areas (UI vs. backend vs. data processing)

## 4. Development Process Improvements

### Documentation
- **Lesson:** Maintain detailed issue documentation (like we did in `current_issue.md`) to track debugging steps and solutions
- **Lesson:** Create specific solution documentation (like `ocr_display_fix.md`) for significant fixes that might be relevant to other parts of the application

### Codebase Organization
- **Lesson:** Clear separation of concerns between services (frontend, OCR, RAG) allowed targeted debugging

## 5. Mobile App Development

### Flutter Integration with Backend Services
- **Issue:** Mobile app couldn't connect to backend API services properly
- **Root Cause:** Network configuration mismatches between emulators and physical devices
- **Solution:** 
  - For emulators: Use 10.0.2.2 as localhost equivalent
  - For physical devices: Use the development machine's WiFi IP address
- **Lesson:** Document network configuration requirements for different testing environments

### Android Build Environment
- **Issue:** Multiple build errors related to outdated plugin implementations
- **Root Cause:** File_picker plugin had v1 Android embedding references not compatible with newer Flutter versions
- **Solution:** 
  - Updated to newer dependencies
  - Replaced file_picker with file_selector
  - Updated Android compileSdk and targetSdk to 35
- **Lesson:** Keep plugin dependencies updated and be prepared to migrate between similar packages when compatibility issues arise

### Error Handling Strategy
- **Issue:** App crashes when API endpoints return errors
- **Solution:** Implemented graceful fallbacks including mock responses and local storage options
- **Lesson:** Design mobile apps with comprehensive error handling and offline capabilities from the start

### API Integration
- **Innovation:** Built a dual-mode API service that can work both with remote endpoints and local storage
- **Approach:** Implemented a LocalStorageService with SharedPreferences for backup when network is unavailable
- **Lesson:** Design mobile apps with offline-first mentality and seamless transitions between online/offline modes

## 6. Future Improvement Ideas

Based on our experience, these enhancements would improve the application:

1. **Progress Indicators:** More detailed progress feedback during document processing
2. **Text Search:** Ability to search within extracted text
3. **Text Formatting:** Preserve original document formatting when displaying extracted text
4. **Offline Processing Fallbacks:** More robust handling of API service disruptions
5. **Logging Dashboard:** Centralized logging with alerting for application errors
6. **Voice Input for QA:** Integration of speech-to-text for asking questions verbally
7. **Multi-Document Comparison:** Ability to compare answers to the same question across different policies
8. **Answer Highlighting:** Highlight relevant sections in the original document where answers were sourced
9. **Smart Question Suggestions:** AI-driven suggestions based on the document content and user history

This document will be updated as we continue to learn from the development and operation of the insurance app. 