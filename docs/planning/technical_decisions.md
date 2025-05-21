# Technical Decisions & Issue Resolution Log

This document captures specific technical decisions, issue resolutions, and architectural choices made during the development of the Insurance Document Processing application. It serves as a decision log to understand why certain approaches were chosen and how specific issues were resolved.

## OCR Processing

### Decision: Local OCR vs. Cloud API
* **Context:** Initial implementation relied on HuggingFace Inference API for OCR processing
* **Problem:** HuggingFace API started failing with 404 errors
* **Options Considered:**
  1. Switch to alternative cloud OCR APIs (e.g., Google Vision, AWS Textract)
  2. Implement local OCR processing with python-doctr
* **Decision:** Implemented local OCR processing with python-doctr
* **Rationale:**
  * More control over OCR parameters and configuration
  * Eliminated dependency on external service availability
  * Lower operational costs for high-volume processing
  * Better privacy for sensitive insurance documents
* **Consequences:**
  * Increased Docker image size due to additional dependencies
  * Required more system dependencies (OpenCV, etc.)
  * Longer initial processing time but more consistent results

### Decision: PDF Text Extraction Approach
* **Context:** Need to extract text from various insurance policy PDFs
* **Options Considered:**
  1. Direct text extraction from PDF where possible
  2. Pure OCR approach for all documents
  3. Hybrid approach: Try direct extraction first, fall back to OCR
* **Decision:** Implemented hybrid approach
* **Rationale:**
  * Direct extraction is faster and more accurate for text-based PDFs
  * OCR provides coverage for scanned documents and image-based PDFs
  * Hybrid approach maximizes speed and accuracy across document types
* **Consequences:**
  * More complex implementation logic
  * Better overall results across various document types
  * Required maintenance of two text extraction paths

## Mobile App Development

### Decision: Text Display in Flutter App
* **Context:** OCR results needed to be displayed in the mobile app
* **Problem:** Only showing ~5 lines of text despite full document being processed
* **Options Considered:**
  1. Paginate the text with next/previous controls
  2. Show truncated preview with "Show More" option
  3. Use scrollable container with full text
* **Decision:** Implemented scrollable container with fixed height
* **Rationale:**
  * Provides full document visibility without UI complexity
  * Familiar scrolling interaction for users
  * Simpler implementation than pagination
* **Consequences:**
  * Improved user experience with access to all extracted text
  * Eliminated confusion from text truncation
  * Required careful handling of large text documents for performance

### Decision: QA Feature Design
* **Context:** Need to help users extract specific information from insurance documents
* **Options Considered:**
  1. Free-form question input only
  2. Category-based browsing only
  3. Hybrid approach with both standard and custom questions
* **Decision:** Implemented tabbed interface with standard questions by category, custom questions, and history
* **Rationale:**
  * Standard questions help users discover what they can ask
  * Categories organize questions by insurance document sections
  * Custom questions provide flexibility for specific needs
  * History tab enables revisiting previous inquiries
* **Consequences:**
  * More comprehensive and usable QA interface
  * Required more upfront design work
  * Better user experience for both novice and experienced users

## Backend Architecture

### Decision: Service Separation
* **Context:** Need to structure backend services for the application
* **Options Considered:**
  1. Monolithic application handling all functions
  2. Microservices architecture with specialized services
* **Decision:** Implemented separate services for frontend, OCR, and RAG
* **Rationale:**
  * Better separation of concerns
  * Independent scaling based on resource needs
  * Ability to update/replace individual services
  * Easier debugging and maintenance
* **Consequences:**
  * More complex deployment and communication between services
  * Improved fault isolation
  * Better development workflow with specialized teams

### Decision: Data Storage Strategy
* **Context:** Need to store OCR results and vector embeddings
* **Options Considered:**
  1. Relational database for all data
  2. Specialized storage for different data types
* **Decision:** Used Redis for OCR caching and Qdrant for vector storage
* **Rationale:**
  * Redis provides fast caching for OCR results
  * Qdrant optimized for vector search operations
  * Each database specialized for its specific use case
* **Consequences:**
  * Improved performance for respective operations
  * More infrastructure components to maintain
  * Better scalability for each data type

## Testing & Quality Assurance

### Decision: OCR Verification Approach
* **Context:** Need to verify OCR extraction quality
* **Problem:** Uncertain if backend was fully processing documents
* **Options Considered:**
  1. Log-based verification
  2. Direct API endpoint for OCR results
  3. Sample-based manual verification
* **Decision:** Implemented direct API endpoint to access cached OCR data
* **Rationale:**
  * Provided direct visibility into complete extraction results
  * Enabled comparison between UI display and actual data
  * Facilitated debugging without relying on logs
* **Consequences:**
  * Quickly identified that the issue was in UI display, not extraction
  * Added a useful diagnostic tool for future quality assurance
  * Improved overall debugging workflow

### Decision: API Timeout Configuration
* **Context:** Processing large documents takes time
* **Problem:** Some requests were timing out before processing completed
* **Options Considered:**
  1. Optimize processing to be faster
  2. Implement asynchronous processing with webhooks
  3. Increase timeout values
* **Decision:** Increased API service timeout from 60 to 90 seconds
* **Rationale:**
  * Quick solution for immediate issue resolution
  * Most documents were processing successfully within new timeout
  * Provided better user experience without major architecture changes
* **Consequences:**
  * Some very large documents might still timeout
  * Long-running requests tie up server resources
  * Identified need for future async processing solution

## This document will be continuously updated as new technical decisions are made and significant issues are resolved. 