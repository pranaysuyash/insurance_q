# App Improvement TODOs

Based on the detailed app review from May 2025, this document tracks actionable items to improve the insurance app. Issues are formatted to be easily transferred to GitHub issues.

## Critical Issues (Must Fix Now)

- [ ] **P0-01: Fix RAG Service Error in Q&A**
  - [x] Fix the error: "Error communicating with RAG service: {\"detail\":\"An unexpected error occurred during query processing: 'result'}\"}" (May 21, 2025)
  - [x] Implement proper error handling in the service.py file with compatibility fixes (May 21, 2025)
  - [x] Create Redis cache validation tool to verify and fix cached responses (May 22, 2025)
  - [ ] Add comprehensive error logging to identify root causes
  - [ ] Add retry mechanisms for intermittent failures

- [x] **P0-02: Fix Document Type Recognition** ✅ DONE
  - [x] Implement proper document type detection during OCR processing (classifyPolicyType + _inferDocumentType)
  - [x] Add document categorization algorithms to identify policy types (backend _matchTypeFromAnswer with Indian insurer names)
  - [x] Create fallback for documents that can't be automatically categorized (inferDocumentTypeFromContent via RAG queries)
  - [x] Add manual selection for document type when automatic detection fails (DocumentTypePicker + Change type button)

- [x] **P0-03: Resolve UI Layout Overflow Issues** ✅ DONE
  - [x] Fix the "RIGHT OVERFLOWED BY X PIXELS" and "BOTTOM OVERFLOWED BY X PIXELS" errors
  - [x] Implement responsive layouts for different screen sizes and orientations
  - [x] Test on a variety of device dimensions
  - [x] Ensure keyboard appearance doesn't cause overflow issues

- [x] **P0-04: Add Privacy Policy and Terms of Service** ✅ DONE
  - [x] Create and link privacy policy and terms of service documents
  - [x] Add clear information about how user data is handled
  - [x] Implement disclosure of data retention policies
  - [x] Add consent mechanism for document processing and storage

## High Priority Issues

- [x] **P1-01: Improve Upload Feedback** ✅ DONE
  - [x] Add a clear progress indicator during document upload and processing
  - [x] Implement status updates during the OCR process
  - [x] Show estimated time remaining for larger documents
  - [x] Provide success/failure notifications with clear next steps

- [x] **P1-02: Prevent Duplicate Document Uploads** ✅ DONE
  - [x] Implement document detection to identify duplicates
  - [x] Add warning dialog when attempting to upload a duplicate
  - [x] Offer options: "Cancel", "Replace" or "Keep Both"
  - [x] Implement smart filename comparison that handles version numbers and timestamps

- [x] **P1-03: Implement User-Friendly Error Messages** ✅ DONE
  - [x] Replace technical error messages with actionable, friendly messages
  - [x] Create standardized error handling across all app screens
  - [x] Add help links for common errors
  - [x] Implement error reporting to help resolve issues

- [x] **P1-04: Fix Default Document Selection in Q&A** ✅ DONE
  - [x] Implement intelligent document selection priority algorithm
  - [x] Use most recently viewed document when entering Q&A screen
  - [x] Use last uploaded document as fallback option
  - [x] Auto-select the only document if just one exists

- [x] **P1-05: Complete "Family Management" and "More Menu" Screens** ✅ DONE
  - [x] Make family member cards tappable → navigate to detail screen with policy associations
  - [x] Wire FamilyMemberDetailScreen to show actual policies covering the member
  - [x] Add edit capability for manual family members (name, relationship)
  - [x] Add 'Family' and 'Notification preferences' entries to MoreScreen
  - [x] Add /family and /notifications routes in main.dart
  - [x] Add /family/visualization route in main.dart

- [x] **P1-06: Verify Policy Information Extraction** ✅ DONE
  - [x] Test policy number extraction with documents where filename ≠ policy number (validatePolicyNumber in policy_extraction_helpers.dart with 14 test cases)
  - [x] Implement proper document parsing for key policy information (cleanText, extractEmail, parseAmount, parseDate, splitLines in policy_extraction_helpers.dart with 83 unit tests)
  - [x] Create confidence scores for extracted information (ConfidenceBadge widget + fieldConfidence/overallExtractionConfidence in policy_extraction_helpers.dart)
  - [x] Allow manual correction of incorrectly extracted data (field_overrides_store, edit buttons on PolicyDetailScreen)

- [x] **P1-07: Implement Complex Relationship Extraction** ✅ DONE
  - [x] Develop document section classifier for identifying policy details, insured persons, and nominee sections (DocumentSectionClassifier with 30+ Indian insurance keywords across 10 section types)
  - [x] Create relationship extraction module to identify policyholder, insured persons, and nominees (RelationshipExtractionService with LLM query pipeline)
  - [x] Implement relationship graph model to represent connections between parties (RelationshipGraph with node/edge dedup, merge, JSON roundtrip)
  - [x] Design specialized prompt templates for relationship-focused questions (RelationshipPromptTemplates with 12 prompt constants)
  - [x] Add verification mechanisms for extracted relationships (confidence scoring, warning collection, edge dedup)
  - [x] Create test cases for complex family relationship scenarios (22 unit tests covering model, type conversion, classifier)
  - [x] Update UI to display relationship information (FamilyVisualizationScreen with coverage matrix)

## Medium Priority Issues

- [x] **P2-01: Optimize Document Upload UI** ✅ DONE
  - [x] Redesign document upload section to be less prominent once documents exist
  - [x] Convert to a simple "Add New" button when documents are present
  - [x] Make the document list the primary focus when documents exist
  - [ ] Add drag-and-drop support for desktop web version

- [x] **P2-02: Improve Document Limit Messaging** ✅ DONE
  - [x] Rephrase "oldest will be removed" to less alarming "free storage limit"
  - [ ] Add warnings before automatic document removal
  - [ ] Consider increasing limit beyond 5 documents
  - [ ] Implement archive functionality instead of permanent deletion

- [x] **P2-03: Fix History Display Truncation** ✅ DONE
  - [x] Ensure questions and answers are displayed in full in history
  - [x] Add expand/collapse functionality for longer entries
  - [x] Implement proper date/time grouping for historical questions (Today, Yesterday, This week, Earlier)
  - [x] Add search functionality for history (debounced search across question + answer text)

- [x] **P2-04: Fix Accordion Behavior in Q&A** ✅ DONE
  - [x] Prevent answer card from disappearing on error (preserved previous answer)
  - [x] Maintain user's expanded/collapsed state during interactions (tracked by question text in Set)
  - [x] Add smooth animations for accordion transitions (AnimatedSize 250ms easeInOut)
  - [x] First-question error shows fallback card + snackbar instead of blank screen

- [x] **P2-05: Improve Error Toast Handling** ✅ DONE
  - [x] Make error toasts context-specific (CoverWiseSnackBar.error with operation parameter)
  - [x] Implement auto-dismissal after appropriate time (per-type durations: error 5s, success 3s, info 3s, warning 4s)
  - [x] Add manual dismiss option (CoverWiseSnackBar.dismissAll + swipe-to-dismiss)
  - [x] Ensure toasts don't persist across screen changes (CoverWiseSnackBarObserver clears on route push/pop/replace)

## User Experience Enhancements

- [x] **P3-01: Add File Type Information** ✅ DONE
  - [x] Display supported file types before upload (_FileTypeHint widget with PDF/JPEG/PNG/Max 20MB chips)
  - [x] Add file type validation before upload attempt (extension check + size check in _pickFile)
  - [x] Provide helpful messaging for unsupported files (AppLocalizations constants)
  - [x] Add file size limits and warnings (AppConfig.maxUploadFileSizeBytes constant shared across codebase)

- [x] **P3-02: Implement Document Renaming** ✅ DONE
  - [x] Allow users to rename documents after upload (rename dialog in _renameDocument)
  - [x] Add edit buttons next to document names (pencil icon in ExpansionTile title row)
  - [x] Implement auto-suggestions for document names based on content
  - [x] Save rename history for audit purposes

- [x] **P3-03: Enhance Home Screen Experience** ✅ DONE
  - [x] Create comprehensive dashboard with document summary cards
  - [x] Add recent activity timeline for documents and questions
  - [x] Implement quick action buttons for common tasks
  - [x] Design responsive and user-friendly layout for all screen sizes

- [x] **P3-04: Add Document Sorting and Filtering** ✅ DONE
  - [x] Implement sorting by date, name, type (DocsSortMode with 5 modes)
  - [x] Add filtering by document type (FilterChip per distinct type + "All" chip)
  - [x] Create saved filter/sort preferences (Hive-persisted in AppStateStore)
  - [x] Add search functionality across documents

- [x] **P3-05: Enable Batch Upload Support** ✅ DONE
  - [x] Allow multiple document selection during upload (openFiles() on native, WebFilePicker.pickFiles() on web)
  - [x] Show multi-file progress indicator (LinearProgressIndicator with per-file status tiles)
  - [x] Add batch processing status updates (per-file BatchUploadState enum: pending/uploading/completed/failed/skipped)
  - [x] Implement per-file validation with duplicate detection and entitlement checks

- [ ] **P3-06: Add Document Preview** (partially done)
  - [ ] Generate thumbnails for document list
  - [x] Implement document preview within the app (DocumentPreviewScreen)
  - [x] Add page navigation for multi-page documents (page jump dialog + Prev/Next)
  - [x] Include zoom functionality for preview (InteractiveViewer)

- [x] **P3-07: Add Follow-up Question Suggestions** ✅ DONE
  - [x] Suggest related questions after an answer is provided (follow-up chips widget)
  - [x] Implement one-tap to ask suggested questions (tappable chips with loading state)
  - [x] Create context-aware suggestion algorithm
  - [x] Learn from user question patterns

- [x] **P3-08: Implement Insurance Terminology Education** ✅ DONE
  - [x] Create comprehensive insurance terminology glossary
  - [x] Integrate terminology reference in the dashboard
  - [x] Implement easy-to-access terminology dialog
  - [x] Use plain language definitions for technical terms

- [x] **P3-09: Implement Source References** ✅ DONE
  - [x] Link answers to specific pages/sections in source documents (citation cards + source cards navigable to DocumentPreviewScreen at cited page)
  - [x] Add "View source" button for verification (tappable citation cards with open_in_new icon + "View source" text)
  - [x] Highlight relevant text in original document (deferred — requires backend page-text search)
  - [x] Include confidence score for sourced information (relevance score badge with tooltip on _SourceCard)

- [x] **P3-10: Add Relationship Visualization** ✅ DONE
  - [x] Create visual representation of policy relationships (FamilyVisualizationScreen with MemberRelationshipCard, CoverageMatrix)
  - [x] Implement interactive family/relationship diagram (tap member → detail screen; tap policy → policy detail)
  - [x] Add tooltips with relationship details
  - [x] Enable editing of relationship information if extraction is incorrect

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
