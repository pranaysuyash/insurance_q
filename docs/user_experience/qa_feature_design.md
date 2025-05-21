# Question & Answer Feature Design

This document outlines the design and implementation details for the Question & Answer functionality in the Insurance Document Processing application.

## Feature Overview

The Q&A feature allows users to extract specific information from their insurance documents through natural language questions. The system leverages the Retrieval-Augmented Generation (RAG) backend to provide accurate, contextual answers based on the user's uploaded documents.

### Key Components:
1. **Standard Questions Library**: Pre-defined questions organized by categories
2. **Custom Question Interface**: Allows users to ask free-form questions
3. **Document Selection**: Ability to target questions to specific documents
4. **Answer Display**: Structured presentation of answers with source references
5. **History Tracking**: Record of previous Q&A interactions

## User Experience

### Standard Questions

Users are presented with a set of common insurance-related questions organized by categories. These questions are designed to extract the most frequently needed information from insurance policies.

#### Question Categories:
- **Policy Basics**: Policy number, effective dates, insured parties
- **Coverage Details**: Coverage amounts, limits, deductibles 
- **Premiums & Payments**: Premium amounts, payment schedules
- **Claims**: Filing procedures, timelines, contact information
- **Exclusions & Limitations**: What's not covered, waiting periods
- **Benefits**: Additional perks, special coverages

#### User Interaction Flow:
1. User browses categories of standard questions
2. User selects a question of interest
3. System processes the question against the selected document(s)
4. Answer is displayed with source information

### Custom Questions

Beyond standard questions, users can ask custom, free-form questions about their documents.

#### User Interaction Flow:
1. User types a custom question in the input field
2. User submits the question
3. System processes the question against the selected document(s)
4. Answer is displayed with source information

### Document Selection

Users should be able to:
- Ask questions about all uploaded documents
- Target questions to a specific document
- Compare information across multiple policies

### Answer Display

Answers should be:
- Clear and concise
- Reference specific sections of the document
- Include page numbers for verification
- Support expandable source views

## Technical Implementation

### Data Structures

#### Standard Question Model
```dart
class StandardQuestion {
  final String id;          // Unique identifier
  final String text;        // Question text
  final String category;    // Category grouping
  final IconData icon;      // Visual identifier
  
  StandardQuestion({
    required this.id,
    required this.text,
    required this.category,
    required this.icon,
  });
}
```

#### Answer Model
```dart
class QaAnswer {
  final String text;                   // Answer text
  final List<QaSource> sources;        // Source references
  final DateTime timestamp;            // When the answer was generated
  final String documentId;             // Source document ID
  final String question;               // Original question text
  
  QaAnswer({
    required this.text,
    required this.sources,
    required this.timestamp,
    required this.documentId,
    required this.question,
  });
}

class QaSource {
  final String documentId;             // Source document ID
  final int? pageNumber;               // Page number if available
  final String text;                   // Source text snippet
  final double score;                  // Relevance score
  
  QaSource({
    required this.documentId,
    this.pageNumber,
    required this.text,
    required this.score,
  });
}
```

### API Endpoints

The mobile app will interact with the following backend endpoints:

1. **Query Endpoint**:
   - **URL**: `/query`
   - **Method**: POST
   - **Payload**: 
     ```json
     {
       "query": "What is my policy number?",
       "filters": {
         "document_id": "optional_specific_document_id"
       }
     }
     ```
   - **Response**:
     ```json
     {
       "answer": "Your policy number is ABC123456789.",
       "sources": [
         {
           "document_id": "doc123",
           "page": 1,
           "text": "Policy Number: ABC123456789",
           "score": 0.95
         }
       ]
     }
     ```

2. **Document List Endpoint**:
   - **URL**: `/documents`
   - **Method**: GET
   - **Response**:
     ```json
     {
       "documents": [
         {
           "id": "doc123",
           "filename": "health_insurance.pdf",
           "upload_date": "2025-05-21T10:30:00Z",
           "type": "Health Insurance"
         }
       ]
     }
     ```

### State Management

The app will use Riverpod for state management:

1. **Document Provider**: Tracks available documents and currently selected document
2. **QA Provider**: Manages question state, answer results, and history
3. **Loading State Provider**: Tracks API request status

### Local Storage

The app will store:
1. Recent question history using Hive or shared_preferences
2. Document metadata for quick access

## UI Components

### QA Screen Layout
- Document selector at the top
- Tab navigation for:
  - Standard Questions (organized by category)
  - Custom Questions
  - Question History
- Answer display area
- Loading indicators
- Error states

### Standard Questions UI
- Expandable category sections
- Question cards with icons
- Search/filter functionality

### Custom Question UI
- Text input with microphone option for voice input
- Submit button
- Suggested questions based on context

### Answer Display UI
- Answer card with formatted text
- Expandable sources panel
- "Copy to clipboard" action
- "Share" action

## Implementation Plan

### Phase 1: Basic QA Functionality
- Implement QA screen with basic layout
- Add standard questions library
- Connect to backend query endpoint
- Implement basic answer display

### Phase 2: Enhanced UX
- Add document selector
- Implement question history
- Add source highlighting
- Implement share functionality

### Phase 3: Advanced Features
- Voice input for questions
- Question suggestions
- Multi-document comparison
- Answer PDF generation

## Potential Extensions

1. **Policy Comparison**: Compare answers to the same question across multiple policies
2. **Coverage Analysis**: Automatically identify gaps or overlaps in coverage
3. **Scheduled Questions**: Monitor policies for important details with regular scheduled checks
4. **Agent Integration**: Share Q&A results directly with insurance agents

## Pre-Defined Standard Questions

Below is the initial set of standard questions by category:

### Policy Basics
- What is my policy number?
- When does my policy start and end?
- Who is the insurer for this policy?
- Who are the insured parties on this policy?
- What type of insurance is this?

### Coverage Details
- What is the total coverage amount?
- What is my deductible?
- What is the out-of-pocket maximum?
- What is the coverage for hospital stays?
- What is the coverage for prescription drugs?
- What is the coverage for preventive care?
- What is the coverage for emergency services?
- What is the coverage for specialist visits?

### Premiums & Payments
- What is my premium amount?
- How often do I need to pay my premium?
- When is my next premium due?
- What payment methods are accepted?
- Is there an auto-payment option?
- Are there any premium discounts available?

### Claims
- How do I file a claim?
- What is the claims process?
- What is the claims contact information?
- What documentation is needed for claims?
- What is the timeframe for filing claims?
- How are claim payments disbursed?

### Exclusions & Limitations
- What is not covered by this policy?
- Are there any waiting periods?
- Are there any pre-existing condition limitations?
- What services require pre-authorization?
- Are there any lifetime maximum benefits?
- Are there any geographical limitations to coverage?

### Benefits
- Does this policy include dental coverage?
- Does this policy include vision coverage?
- Does this policy cover mental health services?
- Are there any wellness program benefits?
- Does this policy cover telemedicine?
- Are there any special riders or endorsements? 