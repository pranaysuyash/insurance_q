# RAG System Improvements - Priority Tasks

Based on the comprehensive app review feedback from May 2025, this document outlines specific improvements needed for the RAG (Retrieval-Augmented Generation) system in our insurance application. These improvements focus on enhancing reliability, accuracy, and user experience.

## Critical RAG Issues

### 1. Resolve RAG Service Error Response (P0-01)
- **Issue:** Users receive error "Error communicating with RAG service: {"detail":"An unexpected error occurred during query processing: 'result'}"}"
- **Root Cause Analysis:** 
  - The error appears related to the response format inconsistency we recently fixed
  - Cached responses may still be in the old format
  - Error handling is not robust enough in the frontend
- **Implementation Tasks:**
  - [x] Add response format normalization in service.py (completed May 21, 2025)
  - [x] Create Redis cache validation tool to verify and fix cached responses (completed May 22, 2025)
  - [ ] Add additional validation layer before returning responses
  - [ ] Implement graceful degradation for service failures
  - [ ] Add comprehensive logging throughout the pipeline for better debugging

### 2. Fix Policy Information Extraction (P1-06)
- **Issue:** App may be using filename rather than properly parsing document content for policy details
- **Root Cause Analysis:**
  - OCR might be working but structured data extraction is failing
  - Current policy number extraction logic might be too simplistic
  - Verification against actual document content is missing
- **Implementation Tasks:**
  - [ ] Audit policy number extraction in different document types
  - [ ] Test with documents where filename is not the policy number
  - [ ] Implement robust pattern recognition for policy details in OCR output
  - [ ] Add confidence scores for extracted information
  - [ ] Create validation rules for common policy number formats

### 3. Improve Complex Relationship Extraction (P1-09)
- **Issue:** System cannot correctly identify and distinguish between policyholder, insured persons, and nominees
- **Root Cause Analysis:**
  - Current entity extraction doesn't understand relationship context
  - Flat data structure loses relationship information
  - Generic embeddings don't preserve relationship hierarchy
  - No relationship-aware query processing
- **Implementation Tasks:**
  - [ ] Develop document section classifier to identify policy details, insured details, and nominee sections
  - [ ] Implement role-specific entity extraction for each document section
  - [ ] Create knowledge graph to represent relationships between entities
  - [ ] Develop relationship-aware prompt templates for querying
  - [ ] Implement verification mechanisms for extracted relationships
  - [ ] Add specialized test cases for complex relationship scenarios

## Cache Validation Utility

We've developed a utility to inspect and fix cached responses in Redis to ensure consistent format. This addresses one of the root causes of the RAG service errors where cached responses lacked the expected structure.

### Redis Cache Validator Features
- Scans all keys matching a pattern (default: `rag:query:*`)
- Validates response format according to our standard structure
- Automatically fixes malformed responses to conform to the expected format
- Provides detailed reports of validation results

### How to Use

1. **Check for issues without making changes:**
   ```bash
   ./scripts/validate_redis_cache.sh --dry-run
   ```

2. **Validate and fix all cache entries:**
   ```bash
   ./scripts/validate_redis_cache.sh
   ```

3. **Verbose output with all details:**
   ```bash
   ./scripts/validate_redis_cache.sh --verbose
   ```

4. **Scan specific patterns:**
   ```bash
   ./scripts/validate_redis_cache.sh --pattern='rag:*'
   ```

### Implementation Details

The validation utility:
1. Connects to Redis using environment variables
2. Scans for keys matching the specified pattern
3. Validates each response using these criteria:
   - Must be a valid JSON dictionary
   - Must have a "status" key with value "success" or "error"
   - Success responses must have a "result" key containing a dictionary
   - The result must have an "answer" field
4. For invalid entries, applies these fixes:
   - Wraps direct answer/sources responses in the proper format
   - Restructures responses with correct status but missing "result" key
   - Marks unfixable entries with an error status
   - Removes non-JSON entries

## RAG Enhancements

### 1. Improve Answer Quality and Sources
- **Current Issues:**
  - Answers may be incomplete or inaccurate
  - Source references aren't provided to build user trust
  - No way to verify AI-generated answers against original text
- **Implementation Tasks:**
  - [ ] Implement source citations with page/paragraph references
  - [ ] Add "View in Document" feature to verify answers
  - [ ] Improve prompt engineering for more accurate answers
  - [ ] Implement answer quality metrics and logging

### 2. Enhance Query Understanding
- **Current Issues:**
  - Limited understanding of insurance-specific terminology
  - No follow-up questions for clarification
  - Standard questions may be too generic
- **Implementation Tasks:**
  - [ ] Create insurance-specific prompt templates
  - [ ] Implement domain-specific context for the LLM
  - [ ] Add clarification requests for ambiguous questions
  - [ ] Develop better categorization of standard questions

### 3. Add Multi-Document Querying
- **Current Issues:**
  - "Search across all your policies" option exists but functionality is unclear
  - No comparative analysis between policies
- **Implementation Tasks:**
  - [ ] Implement true multi-document vector search
  - [ ] Add cross-document reference resolution
  - [ ] Create specialized prompts for policy comparison
  - [ ] Develop visualization for multi-document answers

### 4. Implement Relationship-aware Extraction and Querying
- **Current Issues:**
  - Cannot distinguish between policyholder, insured persons, and nominees
  - Flat data structure loses relationship information
  - Questions about "who is covered" yield incomplete answers
- **Implementation Tasks:**
  - [ ] Design and implement relationship graph schema
  - [ ] Develop section-aware document processing
  - [ ] Create specialized embeddings for relationship information
  - [ ] Implement relationship-aware prompts
  - [ ] Add relationship verification mechanisms
  - [ ] Create test suite with complex relationship scenarios

## Technical Debt and Architecture Improvements

### 1. Robust Error Handling
- **Implementation Tasks:**
  - [ ] Create standardized error response format across all services
  - [ ] Implement retry mechanisms with exponential backoff
  - [ ] Add detailed logging for all RAG pipeline stages
  - [ ] Create user-friendly fallback responses

### 2. Performance Optimization
- **Implementation Tasks:**
  - [ ] Implement query caching with proper versioning
  - [ ] Optimize vector search performance
  - [ ] Reduce end-to-end latency for common questions
  - [ ] Add performance monitoring and alerts

### 3. Testing and Quality Assurance
- **Implementation Tasks:**
  - [ ] Create comprehensive test suite for RAG system
  - [ ] Implement automated testing for various document types
  - [ ] Add regression tests for fixed issues
  - [ ] Create benchmark for answer quality evaluation
  - [ ] Add specific test cases for complex relationship scenarios

## Implementation Timeline

### Immediate (Sprint 1)
1. Fix RAG service error response format issues
2. Implement proper error handling in mobile app
3. Flush and rebuild Redis cache with correct formats
4. Add comprehensive logging

### Short-term (Sprint 2-3)
1. Improve policy information extraction
2. Implement source references
3. Enhance error handling and fallbacks
4. Create user-friendly error messages
5. Begin document section classification for relationship extraction

### Medium-term (Sprint 4-5)
1. Enhance query understanding
2. Implement multi-document querying
3. Add follow-up question suggestions
4. Improve answer quality metrics
5. Develop relationship graph schema and population algorithms

### Long-term
1. Develop conversational AI capabilities
2. Implement domain-specific fine-tuning
3. Create comprehensive testing framework
4. Optimize performance and scalability
5. Complete relationship-aware extraction and querying system 