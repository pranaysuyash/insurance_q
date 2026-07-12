# RAG Implementation Details

This document outlines the implementation of the Retrieval-Augmented Generation (RAG) pipeline used in the insurance document processing application.

## Overview

The RAG pipeline is responsible for:
1.  Ingesting processed document data (text blocks and metadata).
2.  Generating embeddings for text blocks using an OpenAI embedding model.
3.  Storing these embeddings and associated metadata in a Qdrant vector database.
4.  Retrieving relevant context from Qdrant based on user queries.
5.  Generating answers using an OpenAI chat model, conditioned on the retrieved context.
6.  Caching query results in Redis with versioned invalidation on ingest.

## 2026-07-10 Query Contract Update

The current canonical query path is more explicit than the older implementation notes below:

- `query_rag()` now accepts optional payload filters and forwards them into Qdrant search and the local FTS fallback index.
- Retrieved hits are lightly reranked before context generation using dense similarity plus local FTS plus lexical/exact-match boosts.
- The answer path returns structured output through `RAGAnswer` / `RAGCitation` rather than raw free text only.
- The response payload includes `confidence`, `retrieval_confidence`, `citations`, `missing_information`, `follow_up_questions`, and `retrieval_strategy`.
- Query responses are cached in Redis with a versioned cache key that is invalidated when new chunks are ingested.
- The frontend upload path keeps a compatibility fallback for older cached OCR payloads when inline OCR text is not present.

## Core Components

### 1. `RAGPipeline` Class (`src/rag/pipeline.py`)

This is the central class managing the RAG process.

#### Initialization (`__init__`)

-   **Clients**:
    -   `OpenAI`: For chat completions and embeddings. Requires `OPENAI_API_KEY`.
    -   `QdrantClient`: For vector storage and retrieval. Connects to a Qdrant instance.
    -   `Redis`: For caching query results.
-   **Configuration**:
    -   `qdrant_host`, `qdrant_port`, `collection_name`: Qdrant connection details.
    -   `redis_host`, `redis_port`, `cache_ttl`: Redis connection and cache settings.
    -   `openai_embedding_model`: Specifies the OpenAI model for embeddings (e.g., `text-embedding-ada-002`, `text-embedding-3-small`, `text-embedding-3-large`).
    -   `openai_chat_model`: Specifies the OpenAI model for answer generation (e.g., `gpt-3.5-turbo`, `gpt-4o-mini`).
-   **Embedding Dimensions**: The constructor dynamically determines the embedding dimensions based on the selected OpenAI model using `_get_openai_dimensions`. This ensures the Qdrant collection is configured correctly.
-   **Qdrant Collection**: The `_ensure_collection_exists` method creates the Qdrant collection if it doesn't exist, configured with the appropriate vector size and distance metric (Cosine).
-   **Failure Tracking**: Initializes `openai_embedding_failures` counter for monitoring.

#### Key Methods

-   **`_get_openai_dimensions(model_name: str) -> int`**:
    -   Returns the known embedding dimensions for various OpenAI embedding models.
    -   Defaults to 1536 if the model is unknown.

-   **`_ensure_collection_exists()`**:
    -   Checks if the specified Qdrant collection exists.
    -   If not, it creates the collection with `VectorParams` matching the `embedding_dimensions` of the OpenAI model and `Distance.COSINE`.

-   **`_generate_openai_embeddings(texts: List[str], max_retries=3) -> List[List[float]]`** (also referred to as `_generate_embeddings` if HuggingFace fallback is removed from the actual code):
    -   Generates embeddings using the configured OpenAI embedding model.
    -   Cleans input texts (replaces newlines, strips whitespace) and truncates texts exceeding OpenAI's token limit (e.g., 8191 characters for some models).
    -   Implements batch processing with a small chunk size (e.g., 5 texts) to avoid rate limits, with delays between chunks.
    -   Includes retry logic with exponential backoff for handling transient API errors and rate limits.
    -   Provides detailed logging of API calls, token usage, and errors (including specific handling for rate limit, billing, key, or capacity issues).
    -   Increments `openai_embedding_failures` on failure.
    -   This method becomes the primary way to generate embeddings if no fallback is used.

-   **`ingest_document_data(document_id: str, text_blocks: List[Dict[str, Any]], document_metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]`**:
    -   Takes a `document_id` and a list of `text_blocks` (dictionaries containing `text`, `page`, `id`, `bbox`).
    -   Checks if the document already has points in Qdrant to prevent duplicate ingestion.
    -   Filters out empty text blocks and truncates long texts.
    -   Initializes an empty list `points_to_upsert` to collect points to be added to Qdrant, ensuring this variable exists even if embedding generation fails.
    -   Calls `_generate_openai_embeddings` (or the simplified `_generate_embeddings` method) to get embeddings for the text content of the blocks.
    -   Constructs Qdrant `PointStruct` objects, including:
        -   A unique ID (derived from `block_id` or a new UUID).
        -   The generated embedding vector.
        -   Payload containing `document_id`, `text_content`, `page_number`, `block_id`, `bbox`, `embedding_model` (the OpenAI model used), and `embedding_timestamp`. Document-level metadata is also added to the payload.
    -   Upserts the points into the Qdrant collection.
    -   Returns a status dictionary with details of the ingestion.

-   **`query_rag(user_query: str, top_k: int = 5, filters: Optional[Dict[str, Any]] = None) -> Dict[str, Any]`**:
    -   Handles an incoming user query.
    -   **Caching**:
        -   Constructs a versioned cache key based on the query, active models, `top_k`, filters, and corpus version.
        -   Checks Redis for a cached response first. If found, returns it.
    -   **Query Embedding**:
        -   Generates an embedding for the `user_query` using `_generate_openai_embeddings` (or the simplified `_generate_embeddings` method).
    -   **Vector Search**:
        -   Performs a search in Qdrant using the query embedding.
        -   Supports optional `filters` (e.g., to scope search by `document_id`).
        -   Retrieves extra candidates from both dense Qdrant search and the local FTS index, then reranks them before the final `top_k` context set is chosen.
    -   **Context Preparation**:
        -   Extracts text content from search results to form a context string.
        -   Collects metadata about the retrieved sources (ID, score, document ID, page number, and section when available).
    -   **Answer Generation**:
        -   If no relevant contexts are found, returns a default message with empty citations and zero confidence.
        -   Otherwise, constructs a prompt for an OpenAI chat model, including the system prompt and the retrieved contexts.
        -   Calls the OpenAI chat client through `LLMClient.generate_structured()` to produce structured answer output.
    -   **Response Formatting**:
        -   Packages the answer, citations, retrieved sources, confidence values, and fallback metadata into a final dictionary.
    -   **Caching**:
        -   Stores the final response in Redis with the configured `cache_ttl`.
        -   Ingest bumps the cache version so new documents invalidate stale answers.
    -   Returns the query result.

-   **`get_embedding_stats() -> Dict[str, Any]`**:\n    -   Returns a dictionary containing statistics about embedding generation:\n        -   `active_embedding_model` (will be the OpenAI model)\n        -   `openai_embedding_failures`\n        -   `embedding_dimensions`

## Embedding Models

-   The system prefers OpenAI embeddings first (e.g., `text-embedding-3-small` / `text-embedding-3-large`) and falls back to Ollama-compatible embeddings and then local sentence-transformers if the primary path fails.
-   The active embedding model is tracked in the pipeline state so retrieval and health checks can report the real backend in use.
-   The `test_embedding_fallback.py` script mentioned in previous versions is still useful as a general fallback-path smoke test, but the current canonical fallback chain is OpenAI → Ollama → local sentence-transformers.

## Data Flow

### Ingestion

1.  OCR Service processes a document and extracts text blocks.
2.  OCR Service calls the RAG Service's `/ingest` endpoint with `document_id` and `text_blocks`.
3.  `RAGPipeline.ingest_document_data()`:
    a.  Generates embeddings for text blocks via `_generate_openai_embeddings()`.
    b.  Stores embeddings and metadata in Qdrant.

### Querying

1.  User submits a query via the Frontend Service.
2.  Frontend Service calls the RAG Service's `/query` endpoint.
3.  `RAGPipeline.query_rag()`:
    a.  Checks Redis cache.
    b.  Generates query embedding via `_generate_openai_embeddings()`.
    c.  Searches Qdrant for relevant text blocks.
    d.  Retrieves extra lexical candidates from the local FTS index.
    e.  Constructs a prompt with retrieved context.
    f.  Calls OpenAI Chat Completions API for an answer.
    g.  Caches and returns the answer.

## Complex Relationship Extraction Enhancement

To address the complex relationship extraction challenges identified in our case studies, the following enhancements to the RAG pipeline are proposed:

### 1. Document Section Classification Module (`src/rag/section_classifier.py`)

A new module for classifying document sections that will:
- Use rule-based and/or ML approaches to identify key insurance document sections
- Categorize text blocks into sections like "policy details," "insured information," "nominee details," etc.
- Add section metadata to text blocks before embedding generation

```python
class SectionClassifier:
    def __init__(self, model_path=None):
        # Initialize section classification model or rules
        pass
        
    def classify_sections(self, text_blocks):
        """
        Classify text blocks into document sections.
        
        Args:
            text_blocks: List of text block dictionaries
            
        Returns:
            List of text blocks with added 'section' field
        """
        # Implementation of section classification
        for block in text_blocks:
            # Determine section based on content and position
            block['section'] = self._determine_section(block)
        return text_blocks
```

### 2. Relationship Extraction Module (`src/rag/relationship_extractor.py`)

A specialized module for extracting entity relationships:

```python
class RelationshipExtractor:
    def __init__(self, llm_client):
        self.llm_client = llm_client
        
    def extract_relationships(self, section_blocks):
        """
        Extract relationships between entities in insurance documents.
        
        Args:
            section_blocks: Text blocks with section classification
            
        Returns:
            Dictionary of relationship graph
        """
        # Implementation of relationship extraction logic
        relationships = {
            'policyholder': {},
            'insured_persons': [],
            'nominees': [],
            'relationships': []
        }
        
        # Process policy details section
        policy_blocks = [b for b in section_blocks if b.get('section') == 'policy_details']
        if policy_blocks:
            relationships['policyholder'] = self._extract_policyholder(policy_blocks)
            
        # Process insured persons section
        insured_blocks = [b for b in section_blocks if b.get('section') == 'insured_details']
        if insured_blocks:
            relationships['insured_persons'] = self._extract_insured_persons(insured_blocks)
            
        # Process nominee section
        nominee_blocks = [b for b in section_blocks if b.get('section') == 'nominee_details']
        if nominee_blocks:
            relationships['nominees'] = self._extract_nominees(nominee_blocks)
            
        # Determine relationships between entities
        relationships['relationships'] = self._determine_relationships(relationships)
        
        return relationships
```

### 3. Extended RAGPipeline Integration

The RAGPipeline class would be extended to incorporate these new modules:

```python
# Enhanced ingest_document_data method
def ingest_document_data(self, document_id, text_blocks, document_metadata=None):
    # Initialize new components
    section_classifier = SectionClassifier()
    relationship_extractor = RelationshipExtractor(self.openai_client)
    
    # Classify sections
    section_blocks = section_classifier.classify_sections(text_blocks)
    
    # Extract relationships
    relationships = relationship_extractor.extract_relationships(section_blocks)
    
    # Add relationship data to document metadata
    if document_metadata is None:
        document_metadata = {}
    document_metadata['relationships'] = relationships
    
    # Add section information to each text block
    for block in section_blocks:
        block['metadata'] = block.get('metadata', {})
        block['metadata']['section'] = block.get('section')
    
    # Continue with regular ingestion process
    # ... (existing code)
```

### 4. Enhanced Query Processing

The query_rag method would be updated to handle relationship-specific queries:

```python
# Enhanced query processing
def query_rag(self, user_query, top_k=5, filters=None):
    # Detect if query is relationship-focused
    if self._is_relationship_query(user_query):
        # Get document metadata including relationship graph
        if filters and 'document_id' in filters:
            doc_id = filters['document_id']
            relationship_data = self._get_document_relationships(doc_id)
            
            # Generate specialized prompt that includes relationship context
            enhanced_prompt = self._generate_relationship_prompt(user_query, relationship_data)
            
            # Use specialized prompt for answer generation
            # ... (relationship-specific answer generation)
            
    # Continue with regular query processing for non-relationship queries
    # ... (existing code)
```

### 5. Specialized Relationship Prompts

Create specialized prompts for relationship queries that include structured relationship data:

```python
def _generate_relationship_prompt(self, query, relationship_data):
    # Create a structured prompt with relationship information
    relationship_context = f"""
    Document contains the following insurance relationships:
    
    POLICYHOLDER: {relationship_data['policyholder'].get('name')}
    
    INSURED PERSONS:
    {self._format_entities(relationship_data['insured_persons'])}
    
    NOMINEES:
    {self._format_entities(relationship_data['nominees'])}
    
    RELATIONSHIPS:
    {self._format_relationships(relationship_data['relationships'])}
    """
    
    prompt = f"""
    You are an insurance document assistant. Answer the following question about insurance relationships.
    
    Here is information about the relationships in this policy:
    
    {relationship_context}
    
    USER QUESTION: {query}
    
    Provide a clear, accurate answer based only on the information provided above. If the answer cannot be determined from the information provided, say so.
    """
    
    return prompt
```

## Data Structures

### Relationship Graph Schema

The relationship data would be stored in a structured format in the document metadata:

```json
{
  "relationships": {
    "policyholder": {
      "name": "John Doe",
      "id": "PH123456",
      "role": "policyholder",
      "contact": "john.doe@example.com"
    },
    "insured_persons": [
      {
        "name": "Shishu Ranjan",
        "relationship_to_policyholder": "parent",
        "dob": "1950-05-15"
      },
      {
        "name": "Ranjana",
        "relationship_to_policyholder": "parent",
        "dob": "1955-08-20"
      }
    ],
    "nominees": [
      {
        "name": "Shishu Ranjan",
        "relationship_to_policyholder": "parent",
        "allocation_percentage": 100
      }
    ],
    "relationships": [
      {
        "entity1": "John Doe",
        "entity2": "Shishu Ranjan",
        "relationship": "child-parent"
      },
      {
        "entity1": "John Doe", 
        "entity2": "Ranjana",
        "relationship": "child-parent"
      },
      {
        "entity1": "Shishu Ranjan",
        "entity2": "Ranjana",
        "relationship": "spouse"
      }
    ]
  }
}
```

## Error Handling and Retries

-   OpenAI embedding generation implements retry logic with exponential backoff for transient errors.
-   Specific error messages from OpenAI (rate limits, billing, key issues) are logged for easier debugging.
-   Failures in Qdrant operations or OpenAI chat completions are logged and returned as errors in the API response.
-   Variables are properly initialized to handle edge cases (e.g., `points_to_upsert` is initialized early in the `ingest_document_data` method to prevent potential `NameError` if embedding generation fails).

## Environment Variables

Key environment variables influencing the RAG pipeline:

-   `OPENAI_API_KEY`: Essential for OpenAI models.
-   `QDRANT_HOST`, `QDRANT_PORT`, `QDRANT_COLLECTION`
-   `REDIS_HOST`, `REDIS_PORT`, `CACHE_TTL_SECONDS`
-   `OPENAI_EMBEDDING_MODEL`
-   `OPENAI_CHAT_MODEL`
-   `LOG_LEVEL`
-   `ENABLE_RELATIONSHIP_EXTRACTION`: Toggle for the relationship extraction feature
-   `RELATIONSHIP_EXTRACTION_MODEL`: Specifies which model to use for relationship extraction

## Testing

-   `test_openai_key.py`: Tests OpenAI API key validity and embedding model functionality directly.
-   `test_rag.py` and `test_endpoints.py` cover general RAG functionality.
-   `test_embedding_fallback.py` is no longer relevant for testing fallback but can be adapted to test OpenAI embedding generation within the RAG pipeline.
-   `test_relationship_extraction.py`: New test suite for the relationship extraction functionality with various test cases.

This detailed documentation should provide a good understanding of the RAG pipeline's architecture and behavior.
