# Technical Decisions & Issue Resolution Log

## Decision: allow evidence-based comparison, prohibit unsupported insurance recommendations

**Date:** 2026-07-16  
**Owner:** Solo CoverWise operator  
**Status:** accepted product boundary

### Context

Users may upload two policies that appear to cover the same need but have materially different premiums, for example ₹10,000 versus ₹6,000. A neutral product that refuses to explain this difference is not useful. The product must remain non-regulated and must not become an insurance seller, adviser, or recommender.

### Decision

CoverWise may compare user-selected policies and make source-grounded, dimension-specific judgments: lower premium, broader documented benefits, shorter listed waiting period, higher deductible, or more exclusions listed. It may state that one policy is cheaper for the documented terms. It must not declare an overall best policy, say what is better for the user personally, tell the user to switch/buy/renew, or label the user under-insured.

### Required behavior

- Normalize currency, payment frequency, taxes, riders, discounts, and period.
- Calculate arithmetic with an explicit denominator: ₹6,000 is 40% below ₹10,000; ₹10,000 is 66.7% above ₹6,000.
- Compare fields independently; never assume "same cover" without evidence.
- Cite source page/section, expose missing or contradictory fields, and preserve user inspection.
- Render comparative copy only after structured evidence passes validation.

### Rationale and trade-off

This preserves real user value while avoiding unsupported personalized insurance advice. The trade-off is that the app may feel less decisive than a salesperson; that is intentional. Its trust signal is transparent evidence, not a hidden recommendation.

### Revisit trigger

Revisit only if the product scope, operating entity, or customer journey changes. Any move into compensated referrals, product shopping, or personal advice requires a separate decision and regulatory review.

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

### Decision: Document Management Strategy
* **Context:** Need to manage multiple insurance documents efficiently for the user
* **Options Considered:**
  1. Unlimited document storage
  2. Limited document storage with manual cleanup
  3. Limited document storage with automatic cleanup
* **Decision:** Implemented 5-document limit with automatic removal of oldest documents
* **Rationale:**
  * Prevents excessive storage use on mobile device
  * Automatic cleanup provides seamless user experience
  * 5 documents is typically sufficient for personal insurance needs
  * Oldest-first removal is intuitive for users
* **Consequences:**
  * Simpler user experience without manual cleanup
  * Potential risk of unintentionally removing needed documents
  * Need for clear UI indicators about document limits

### Decision: Document Metadata Tracking
* **Context:** Need to provide users with information about their documents
* **Options Considered:**
  1. Basic filename-only approach
  2. Comprehensive metadata capturing upload and processing details
  3. Auto-classification of document types
* **Decision:** Implemented comprehensive metadata with timestamps and document properties
* **Rationale:**
  * Helps users identify documents beyond just filenames
  * Timestamps provide context for document history
  * Page count and file size offer document characteristics
  * Document type identification improves organization
* **Consequences:**
  * More complex data model and UI
  * Better user experience with richer document information
  * Allows for future integration of sorting and filtering

### Decision: Mobile Document Storage and Sync Semantics
* **Context:** The mobile app was persisting documents in SharedPreferences and deleting the oldest record automatically when the user exceeded the limit.
* **Options Considered:**
  1. Keep SharedPreferences as the document store and auto-delete oldest entries.
  2. Move documents to a typed local store and reject over-limit uploads explicitly.
* **Decision:** Moved document persistence to a Hive-backed document box, added remote/local ID separation, and changed the upload limit behavior to explicit rejection.
* **Rationale:**
  * Preserves user data instead of silently deleting it.
  * Makes local/offline documents distinguishable from synced backend records.
  * Provides a clean migration path from the legacy SharedPreferences list.
* **Consequences:**
  * The storage path now needs initialization during app startup and tests.
  * A document can exist locally before it is queryable remotely.
  * The UI can now show honest pending/queued states instead of implying a successful sync.

### Decision: Mobile QA Failure Semantics
* **Context:** The mobile app returned hardcoded policy answers whenever backend query processing failed.
* **Options Considered:**
  1. Keep the fallback policy answers for all failures.
  2. Restrict hardcoded answers to the demo flavor and return explicit unavailable states in production.
* **Decision:** Production QA now returns an explicit unavailable state; demo answers remain available only behind the bootstrap demo flag.
* **Rationale:**
  * Avoids fabricated insurance answers in production flows.
  * Preserves a safer demo path without conflating it with the real product.
  * Keeps answer provenance visible for future grounded-answer UX.
* **Consequences:**
  * QA screens must handle unavailable states directly.
  * The app is no longer pretending that failed network calls are policy answers.
  * Structured metadata such as citations and retrieval confidence can now be preserved end to end.

### Decision: Mobile Operational State Storage
* **Context:** The mobile app was still using SharedPreferences as a lightweight database for selected document state, recent questions, last-uploaded document state, and deletion history.
* **Options Considered:**
  1. Keep the preference-based state model and continue extending it.
  2. Move operational state to the same Hive-backed storage layer used for documents.
* **Decision:** Moved operational state to a Hive-backed app-state box and removed the SharedPreferences provider from the app bootstrap.
* **Rationale:**
  * Keeps the app’s active state in one typed local store.
  * Avoids parallel truth sources for document selection, recent questions, and activity history.
  * Preserves only a narrow legacy migration bridge for old document lists.
* **Consequences:**
  * The mobile app now has a coherent local state model for documents and app metadata.
  * SharedPreferences is no longer the runtime source of truth for operational state.
  * Legacy migration code remains only for compatibility with previously stored document lists.

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

### Decision: Hybrid Retrieval Without Qdrant Sparse Support
* **Context:** The app needs exact-match retrieval for policy numbers, names, and IDs, but the installed Qdrant client stack in this repo does not expose sparse-vector APIs cleanly.
* **Options Considered:**
  1. Upgrade the Qdrant client/runtime stack immediately and wire sparse vectors end to end.
  2. Add a second retrieval layer that can ship now and still respect first principles.
* **Decision:** Implemented dense Qdrant search plus a local SQLite FTS candidate index, then reranked the merged candidate set.
* **Rationale:**
  * Restores exact-match behavior immediately for policy IDs and names.
  * Keeps the canonical vector store path intact.
  * Avoids pretending sparse-vector support exists when the current dependency stack does not expose it.
* **Consequences:**
  * Adds a small local retrieval index to maintain.
  * Creates a clean upgrade path to Qdrant-native sparse vectors later if the stack is upgraded.
  * Gives us a measurable hybrid retrieval contract now rather than a roadmap-only promise.

### Decision: Versioned Redis Query Cache
* **Context:** Query answers are expensive enough that repeated questions should avoid recomputing embeddings, search, and LLM output when the document corpus has not changed.
* **Options Considered:**
  1. Cache query responses with a static key and manual flushes.
  2. Skip query caching entirely and pay the retrieval/LLM cost every time.
  3. Cache query responses behind a corpus-versioned key that is bumped on ingest.
* **Decision:** Implemented Redis query caching with a versioned cache key and ingest-time invalidation.
* **Rationale:**
  * Preserves correctness by invalidating stale answers after new document ingestion.
  * Avoids manual cache management and hidden stale-answer risk.
  * Keeps the optimization optional when Redis is unavailable.
* **Consequences:**
  * Slightly more moving parts in the RAG pipeline.
  * Query latency improves for repeated questions on an unchanged corpus.
  * Cache behavior is now explicit and observable through the version key.

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
