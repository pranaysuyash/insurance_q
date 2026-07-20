# App Improvement TODOs

Based on the detailed app review from May 2025, this document tracks actionable items to improve the insurance app. Issues are formatted to be easily transferred to GitHub issues.

## Critical Issues (Must Fix Now)

- [ ] **P0-01: Fix RAG Service Error in Q&A**
  - [x] Fix the error: "Error communicating with RAG service: {"detail":"An unexpected error occurred during query processing: 'result'}"}" (May 21, 2025)
  - [x] Implement proper error handling in the service.py file with compatibility fixes (May 21, 2025)
  - [x] Create Redis cache validation tool to verify and fix cached responses (May 22, 2025)
  - [ ] Add comprehensive error logging to identify root causes
  - [ ] Add retry mechanisms for intermittent failures
  
- [ ] **P0-02: Fix Document Type Recognition**
  - [ ] Implement proper document type detection during OCR processing
  - [ ] Add document categorization algorithms to identify policy types
  - [ ] Create fallback for documents that can't be automatically categorized
  - [ ] Add manual selection for document type when automatic detection fails
  
- [x] **P0-03: Resolve UI Layout Overflow Issues** ✅ DONE
  - [ ] Fix the "RIGHT OVERFLOWED BY X PIXELS" and "BOTTOM OVERFLOWED BY X PIXELS" errors
  - [ ] Implement responsive layouts for different screen sizes and orientations
  - [ ] Test on a variety of device dimensions
  - [ ] Ensure keyboard appearance doesn't cause overflow issues
  
- [ ] **P0-04: Add Privacy Policy and Terms of Service**
  - [ ] Create and link privacy policy and terms of service documents
  - [ ] Add clear information about how user data is handled
  - [ ] Implement disclosure of data retention policies
  - [ ] Add consent mechanism for document processing and storage

## High Priority Issues

- [ ] **P1-01: Improve Upload Feedback**
  - [ ] Add a clear progress indicator during document upload and processing
  - [ ] Implement status updates during the OCR process
  - [ ] Show estimated time remaining for larger documents
  - [ ] Provide success/failure notifications with clear next steps
  
- [x] **P1-02: Prevent Duplicate Document Uploads**
  - [x] Implement document detection to identify duplicates (June 2025)
  - [x] Add warning dialog when attempting to upload a duplicate (June 2025)
  - [x] Offer options: "Cancel", "Replace" or "Keep Both" (June 2025)
  - [x] Implement smart filename comparison that handles version numbers and timestamps (June 2025)
  
- [ ] **P1-03: Implement User-Friendly Error Messages**
  - [ ] Replace technical error messages with actionable, friendly messages
  - [ ] Create standardized error handling across all app screens
  - [ ] Add help links for common errors
  - [ ] Implement error reporting to help resolve issues

- [x] **P1-04: Fix Default Document Selection in Q&A**
  - [x] Implement intelligent document selection priority algorithm (June 2025)
  - [x] Use most recently viewed document when entering Q&A screen (June 2025)
  - [x] Use last uploaded document as fallback option (June 2025)
  - [x] Auto-select the only document if just one exists (June 2025)

- [ ] **P1-05: Complete "Family Management" and "More Menu" Screens**
  - [ ] Add basic functionality to these incomplete screens
  - [ ] Create an MVP version of Family Management
  - [ ] Implement standard More Menu with settings, help, etc.
  - [ ] Hide or mark features as "Coming Soon" if not ready

- [ ] **P1-06: Verify Policy Information Extraction**
  - [ ] Test policy number extraction with documents where filename ≠ policy number
  - [ ] Implement proper document parsing for key policy information
  - [ ] Create confidence scores for extracted information
  - [ ] Allow manual correction of incorrectly extracted data

- [ ] **P1-07: Implement Complex Relationship Extraction**
  - [ ] Develop document section classifier for identifying policy details, insured persons, and nominee sections
  - [ ] Create relationship extraction module to identify policyholder, insured persons, and nominees
  - [ ] Implement relationship graph model to represent connections between parties
  - [ ] Design specialized prompt templates for relationship-focused questions
  - [ ] Add verification mechanisms for extracted relationships
  - [ ] Create test cases for complex family relationship scenarios
  - [ ] Update UI to display relationship information in a user-friendly format

## Medium Priority Issues

- [ ] **P2-01: Optimize Document Upload UI**
  - [ ] Redesign document upload section to be less prominent once documents exist
  - [ ] Convert to a simple "Add New" button when documents are present
  - [ ] Make the document list the primary focus when documents exist
  - [ ] Add drag-and-drop support for desktop web version

- [x] **P2-02: Improve Document Limit Messaging**
  - [x] Rephrase "oldest will be removed" to less alarming "free storage limit" (June 2025)
  - [ ] Add warnings before automatic document removal
  - [ ] Consider increasing limit beyond 5 documents
  - [ ] Implement archive functionality instead of permanent deletion

- [ ] **P2-03: Fix History Display Truncation**
  - [ ] Ensure questions and answers are displayed in full in history
  - [ ] Add expand/collapse functionality for longer entries
  - [ ] Implement proper date/time grouping for historical questions
  - [ ] Add search functionality for history

- [ ] **P2-04: Fix Accordion Behavior in Q&A**
  - [ ] Prevent accordions from auto-closing on error
  - [ ] Maintain user's expanded/collapsed state during interactions
  - [ ] Add smooth animations for accordion transitions
  - [ ] Consider alternative to accordion for better visibility of categories

- [ ] **P2-05: Improve Error Toast Handling**
  - [ ] Make error toasts context-specific
  - [ ] Implement auto-dismissal after appropriate time
  - [ ] Add manual dismiss option
  - [ ] Ensure toasts don't persist across screen changes

## User Experience Enhancements

- [ ] **P3-01: Add File Type Information**
  - [ ] Display supported file types before upload
  - [ ] Add file type validation before upload attempt
  - [ ] Provide helpful messaging for unsupported files
  - [ ] Add file size limits and warnings

- [ ] **P3-02: Implement Document Renaming**
  - [ ] Allow users to rename documents after upload
  - [ ] Add edit buttons next to document names
  - [ ] Implement auto-suggestions for document names based on content
  - [ ] Save rename history for audit purposes

- [x] **P3-03: Enhance Home Screen Experience** (June 2025)
  - [x] Create comprehensive dashboard with document summary cards
  - [x] Add recent activity timeline for documents and questions
  - [x] Implement quick action buttons for common tasks
  - [x] Design responsive and user-friendly layout for all screen sizes

- [ ] **P3-04: Add Document Sorting and Filtering**
  - [ ] Implement sorting by date, name, type
  - [ ] Add filtering by document type
  - [ ] Create saved filter/sort preferences
  - [ ] Add search functionality across documents

- [ ] **P3-05: Enable Batch Upload Support**
  - [ ] Allow multiple document selection during upload
  - [ ] Show multi-file progress indicator
  - [ ] Add batch processing status updates
  - [ ] Implement parallel processing for better performance

- [ ] **P3-06: Add Document Preview**
  - [ ] Generate thumbnails for document list
  - [ ] Implement document preview within the app
  - [ ] Add page navigation for multi-page documents
  - [ ] Include zoom functionality for preview

- [ ] **P3-07: Add Follow-up Question Suggestions**
  - [ ] Suggest related questions after an answer is provided
  - [ ] Implement one-tap to ask suggested questions
  - [ ] Create context-aware suggestion algorithm
  - [ ] Learn from user question patterns

- [x] **P3-08: Implement Insurance Terminology Education** (June 2025)
  - [x] Create comprehensive insurance terminology glossary
  - [x] Integrate terminology reference in the dashboard
  - [x] Implement easy-to-access terminology dialog
  - [x] Use plain language definitions for technical terms

- [ ] **P3-09: Implement Source References**
  - [ ] Link answers to specific pages/sections in source documents
  - [ ] Add "View Source" button for verification
  - [ ] Highlight relevant text in original document
  - [ ] Include confidence score for sourced information

- [ ] **P3-10: Add Relationship Visualization**
  - [ ] Create visual representation of policy relationships
  - [ ] Implement interactive family/relationship diagram
  - [ ] Add tooltips with relationship details
  - [ ] Enable editing of relationship information if extraction is incorrect

## Lead Generation Improvements

- [ ] **Add Contextual CTAs**
  - [ ] Implement context-aware CTAs based on Q&A content
  - [ ] Add rate comparison offers after coverage questions
  - [ ] Create renewal reminders based on policy dates
  - [ ] Include personalized offer generation

- [ ] **Implement Newsletter Sign-up**
  - [ ] Add email collection with valuable content offer
  - [ ] Create insurance tips newsletter template
  - [ ] Implement proper email consent and CAN-SPAM compliance
  - [ ] Add unsubscribe and preference management

- [ ] **Add Agent Connection**
  - [ ] Create "Talk to an Agent" feature for complex questions
  - [ ] Implement scheduling for agent callbacks
  - [ ] Add instant chat option where available
  - [ ] Create lead routing system based on question types 