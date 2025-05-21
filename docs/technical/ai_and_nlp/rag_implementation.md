# RAG Implementation Details

This document outlines the implementation of the Retrieval-Augmented Generation (RAG) pipeline used in the insurance document processing application.

## Overview

The RAG pipeline is responsible for:
1.  Ingesting processed document data (text blocks and metadata).
2.  Generating embeddings for text blocks using a primary (default: OpenAI) and a fallback (default: Hugging Face) embedding model.
3.  Storing these embeddings and associated metadata in a Qdrant vector database.
4.  Retrieving relevant context from Qdrant based on user queries.
5.  Generating answers using an OpenAI chat model, conditioned on the retrieved context.
6.  Caching query results in Redis.

## Core Components

### 1. `RAGPipeline` Class (`src/rag/pipeline.py`)

This is the central class managing the RAG process.

#### Initialization (`__init__`)

-   **Clients**:
    -   `OpenAI`: For chat completions and primary embeddings. Requires `OPENAI_API_KEY`.
    -   `HuggingFace Hub InferenceClient`: For fallback embeddings. Can use `HF_TOKEN` for authenticated access to private/gated models, but works for public models without it.
    -   `QdrantClient`: For vector storage and retrieval. Connects to a Qdrant instance.
    -   `Redis`: For caching query results.
-   **Configuration**:
    -   `qdrant_host`, `qdrant_port`, `collection_name`: Qdrant connection details.
    -   `redis_host`, `redis_port`, `cache_ttl`: Redis connection and cache settings.
    -   `openai_embedding_model`: Specifies the OpenAI model for embeddings (e.g., `text-embedding-ada-002`, `text-embedding-3-small`, `text-embedding-3-large`).
    -   `openai_chat_model`: Specifies the OpenAI model for answer generation (e.g., `gpt-3.5-turbo`, `gpt-4o-mini`).
    -   `embedding_model` (Hugging Face): Specifies the Hugging Face sentence transformer model for fallback embeddings (e.g., `sentence-transformers/all-mpnet-base-v2`).
    -   `use_openai_first`: Boolean flag (default: `True`) to determine if OpenAI is the primary embedding provider. If `False`, Hugging Face is primary.
-   **Embedding Dimensions**: The constructor dynamically determines the embedding dimensions based on the selected OpenAI and Hugging Face models using `_get_openai_dimensions` and `_get_hf_dimensions`. This ensures the Qdrant collection is configured correctly.
-   **Qdrant Collection**: The `_ensure_collection_exists` method creates the Qdrant collection if it doesn't exist, configured with the appropriate vector size and distance metric (Cosine).
-   **Failure Tracking**: Initializes `openai_embedding_failures` and `hf_embedding_failures` counters for monitoring.

#### Key Methods

-   **`_get_openai_dimensions(model_name: str) -> int`**:
    -   Returns the known embedding dimensions for various OpenAI embedding models.
    -   Defaults to 1536 if the model is unknown.

-   **`_get_hf_dimensions(model_name: str) -> int`**:
    -   Returns the known embedding dimensions for common Hugging Face sentence-transformer models.
    -   Defaults to 768 if the model is unknown.

-   **`_ensure_collection_exists()`**:
    -   Checks if the specified Qdrant collection exists.
    -   If not, it creates the collection with `VectorParams` matching the `embedding_dimensions` of the currently active primary model and `Distance.COSINE`.

-   **`_generate_openai_embeddings(texts: List[str], max_retries=3) -> List[List[float]]`**:
    -   Generates embeddings using the configured OpenAI embedding model.
    -   Cleans input texts (replaces newlines, strips whitespace) and truncates texts exceeding OpenAI's token limit (8191 characters).
    -   Implements batch processing with a small chunk size (e.g., 5 texts) to avoid rate limits, with delays between chunks.
    -   Includes retry logic with exponential backoff for handling transient API errors and rate limits.
    -   Provides detailed logging of API calls, token usage, and errors (including specific handling for rate limit, billing, key, or capacity issues).
    -   Increments `openai_embedding_failures` on failure.

-   **`_generate_hf_embeddings(texts: List[str], max_retries=3) -> List[List[float]]`**:
    -   Generates embeddings using the configured Hugging Face model via `InferenceClient.feature_extraction`.
    -   Cleans and truncates texts (default max 2000 chars).
    -   Processes texts in chunks (e.g., 10 texts) with small delays.
    -   Includes retry logic with exponential backoff.
    -   Logs errors and increments `hf_embedding_failures` on failure.

-   **`_generate_embeddings_with_fallback(texts: List[str], max_retries=3) -> List[List[float]]`**:
    -   This is the core of the fallback mechanism.
    -   Determines the primary and fallback embedding methods based on `self.use_openai_first`.
    -   Attempts to generate embeddings using the primary method.
    -   If the primary method fails (raises an exception after retries):
        -   Logs the primary failure.
        -   Attempts to generate embeddings using the fallback method.
        -   If the fallback also fails, logs both errors and re-raises an exception.
    -   If successful with either primary or fallback, it updates `self.active_embedding_model` and `self.embedding_dimensions` to reflect the model that successfully generated the embeddings.
    -   Returns the list of embedding vectors.

-   **`ingest_document_data(document_id: str, text_blocks: List[Dict[str, Any]], document_metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]`**:
    -   Takes a `document_id` and a list of `text_blocks` (dictionaries containing `text`, `page`, `id`, `bbox`).
    -   Checks if the document already has points in Qdrant to prevent duplicate ingestion.
    -   Filters out empty text blocks and truncates long texts.
    -   Calls `_generate_embeddings_with_fallback` to get embeddings for the text content of the blocks.
    -   Constructs Qdrant `PointStruct` objects, including:
        -   A unique ID (derived from `block_id` or a new UUID).
        -   The generated embedding vector.
        -   Payload containing `document_id`, `text_content`, `page_number`, `block_id`, `bbox`, `embedding_model` (the model actually used), and `embedding_timestamp`. Document-level metadata is also added to the payload.
    -   Upserts the points into the Qdrant collection.
    -   Returns a status dictionary with details of the ingestion.

-   **`query_rag(user_query: str, top_k: int = 5, filters: Optional[Dict[str, Any]] = None) -> Dict[str, Any]`**:
    -   Handles an incoming user query.
    -   **Caching**:
        -   Constructs a cache key based on the query, active models, `top_k`, and filters.
        -   Checks Redis for a cached response first. If found, returns it.
    -   **Query Embedding**:
        -   Generates an embedding for the `user_query` using `_generate_embeddings_with_fallback`.
    -   **Vector Search**:
        -   Performs a search in Qdrant using the query embedding.
        -   Supports optional `filters` (e.g., to scope search by `document_id`).
        -   Retrieves the `top_k` most similar text blocks.
    -   **Context Preparation**:
        -   Extracts text content from search results to form a context string.
        -   Collects metadata about the retrieved sources (ID, score, document ID, etc.).
    -   **Answer Generation**:
        -   If no relevant contexts are found, returns a default message.
        -   Otherwise, constructs a prompt for an OpenAI chat model (e.g., `gpt-3.5-turbo`), including the system prompt and the retrieved contexts.
        -   Calls the OpenAI Chat Completions API to generate an answer.
    -   **Response Formatting**:
        -   Packages the LLM's answer, retrieved sources, original query, and the embedding model used into a final dictionary.
    -   **Caching**:
        -   Stores the final response in Redis with the configured `cache_ttl`.
    -   Returns the query result.

-   **`get_embedding_stats() -> Dict[str, Any]`**:
    -   Returns a dictionary containing statistics about embedding generation:
        -   `active_embedding_model`
        -   `primary_model`
        -   `fallback_model`
        -   `openai_embedding_failures`
        -   `hf_embedding_failures`
        -   `embedding_dimensions`

## Embedding Models & Fallback Logic

-   **Primary Model**: By default, OpenAI's `text-embedding-ada-002` (or other configured OpenAI models like `text-embedding-3-small` or `text-embedding-3-large`) is used. This can be changed by setting `USE_OPENAI_FIRST=false` in the environment, making the configured Hugging Face model primary.
-   **Fallback Model**: If the primary model fails (e.g., due to API errors, rate limits after retries), the system automatically switches to the alternative model for the current operation.
    -   If OpenAI is primary, it falls back to the specified Hugging Face model (e.g., `sentence-transformers/all-mpnet-base-v2`).
    -   If Hugging Face is primary, it falls back to the specified OpenAI model.
-   The choice of model (and its dimensions) used for a successful embedding generation is recorded in `self.active_embedding_model` and `self.embedding_dimensions`. This ensures that subsequent operations (like querying) use compatible embeddings if the active model changes due to a fallback event.
-   The Qdrant collection is initially configured based on the primary model's dimensions. If a fallback to a model with different dimensions occurs, this could lead to issues if not managed. However, the current implementation appears to re-check/re-create collection on init, and the active embedding dimension is updated. The test scripts (`test_embedding_fallback.py`) explore scenarios with different OpenAI models, including those with varying dimensions.

## Data Flow

### Ingestion

1.  OCR Service processes a document and extracts text blocks.
2.  OCR Service calls the RAG Service's `/ingest` endpoint with `document_id` and `text_blocks`.
3.  `RAGPipeline.ingest_document_data()`:
    a.  Generates embeddings for text blocks via `_generate_embeddings_with_fallback()`.
    b.  Stores embeddings and metadata in Qdrant.

### Querying

1.  User submits a query via the Frontend Service.
2.  Frontend Service calls the RAG Service's `/query` endpoint.
3.  `RAGPipeline.query_rag()`:
    a.  Checks Redis cache.
    b.  Generates query embedding via `_generate_embeddings_with_fallback()`.
    c.  Searches Qdrant for relevant text blocks.
    d.  Constructs a prompt with retrieved context.
    e.  Calls OpenAI Chat Completions API for an answer.
    f.  Caches and returns the answer.

## Error Handling and Retries

-   Both OpenAI and Hugging Face embedding generation methods implement retry logic with exponential backoff for transient errors.
-   Specific error messages from OpenAI (rate limits, billing, key issues) are logged for easier debugging.
-   The fallback mechanism itself is a form of error handling for embedding generation.
-   Failures in Qdrant operations or OpenAI chat completions are logged and returned as errors in the API response.

## Environment Variables

Key environment variables influencing the RAG pipeline:

-   `OPENAI_API_KEY`: Essential for OpenAI models.
-   `HF_TOKEN`: Optional, for authenticated Hugging Face Hub access.
-   `QDRANT_HOST`, `QDRANT_PORT`, `QDRANT_COLLECTION`
-   `REDIS_HOST`, `REDIS_PORT`, `CACHE_TTL_SECONDS`
-   `OPENAI_EMBEDDING_MODEL`
-   `OPENAI_CHAT_MODEL`
-   `EMBEDDING_MODEL` (for Hugging Face fallback/primary)
-   `USE_OPENAI_FIRST` (boolean: `true` or `false`)
-   `LOG_LEVEL`

## Testing

-   `test_openai_key.py`: Tests OpenAI API key validity and embedding model functionality directly.
-   `test_embedding_fallback.py`: Specifically tests the embedding generation fallback logic within the RAG pipeline by simulating different scenarios and model configurations. This script uses the `RAGPipeline` class to ingest and query data, checking if the fallback occurs as expected.

This detailed documentation should provide a good understanding of the RAG pipeline's architecture and behavior. 