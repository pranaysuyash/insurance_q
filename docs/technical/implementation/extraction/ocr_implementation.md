# OCR Implementation Details

This document describes the Optical Character Recognition (OCR) and document processing pipeline implemented in the insurance application. It leverages Hugging Face Inference APIs for text extraction and document understanding.

## Overview

The OCR service is responsible for:
1.  Accepting uploaded documents (PDF, PNG, JPG, TIFF, etc.).
2.  Converting documents to a processable format (images per page).
3.  For PDF documents, attempting direct text extraction first from each page.
4.  If direct text extraction is not fruitful or for image-based documents, using a Hugging Face OCR model (e.g., `mindee/doctr-ocr`) to extract text from page images.
5.  Using a Hugging Face Document Question Answering model (e.g., `impira/layoutlm-document-qa`) to extract specific layout elements (like title, dates, policy numbers) from page images by asking predefined or custom questions.
6.  Aggregating all extracted text and layout elements.
7.  Storing the full structured result in a Redis cache.
8.  Sending the extracted text blocks and associated metadata to the RAG (Retrieval-Augmented Generation) service for ingestion and embedding generation.

## Core Components

### 1. `OCRPipeline` Class (`src/ocr/pipeline.py`)

This class encapsulates the logic for processing a single document.

#### Initialization (`__init__`)

-   **Hugging Face Client**: Initializes `InferenceClient` from `huggingface_hub` using an `HF_TOKEN` environment variable. This token is required for accessing Hugging Face Inference APIs.
-   **Models**: Defines the Hugging Face models to be used:
    -   `ocr_model`: For general text extraction from images (default: `mindee/doctr-ocr`). Configurable via `HF_OCR_MODEL` env var.
    -   `doc_qa_model`: For document question answering to find specific layout elements (default: `impira/layoutlm-document-qa`). Configurable via `HF_DOC_QA_MODEL` env var.

#### Key Methods

-   **`_process_pdf(file_content: bytes) -> List[Dict[str, Any]]`**:
    -   Takes PDF file content as bytes.
    -   Uses `fitz` (PyMuPDF) to open the PDF.
    -   For each page:
        -   Attempts to extract text directly using `page.get_text()`.
        -   Renders the page to an image (PNG format) using `page.get_pixmap()` at a configurable DPI (default 200, via `OCR_IMAGE_DPI` env var).
    -   Returns a list of dictionaries, each containing `page_num`, `text` (if directly extracted), and `image_bytes`.

-   **`_convert_file_to_images_bytes(file_content: bytes, file_type: str) -> List[Dict[str, Any]]`**:
    -   If `file_type` is PDF, calls `_process_pdf`.
    -   If `file_type` is an image (PNG, JPG, etc.), it returns a list containing a single dictionary with `page_num: 1` and the `image_bytes`.
    -   Raises ValueError for unsupported file types.

-   **`_get_ocr_text_for_image(image_bytes: bytes, page_num: int) -> str`**:
    -   Takes image bytes for a single page.
    -   Calls the Hugging Face `InferenceClient.image_to_text()` method with the configured `self.ocr_model`.
    -   Parses the API response (which can be a string or a dictionary containing `generated_text`).
    -   Returns the extracted OCR text string.
    -   Includes error logging for API call failures.

-   **`_get_layout_elements_for_image(image_bytes: bytes, page_num: int, questions: List[Dict[str, Any]]) -> List[Dict[str, Any]]`**:
    -   Takes image bytes and a list of `questions` (each a dict with `question`, `type`, and optional `id`).
    -   Converts image bytes to a PIL `Image` object.
    -   For each question in the `questions` list:
        -   Calls the Hugging Face `InferenceClient.document_question_answering()` method with the PIL image, question text, and the configured `self.doc_qa_model`.
        -   The API is expected to return a list of answers.
        -   Each answer (if valid format with `answer`, `score`, and optionally `box_2d` or `box`) is formatted into a dictionary including `id`, `type`, `text`, `answer_box`, `confidence`, `page`, and `question_asked`.
    -   Returns a list of these extracted layout element dictionaries.
    -   Includes error logging for API call failures or unexpected response formats.

-   **`process_document(file_content: bytes, file_type: str, filename: str, layout_questions_config: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]`**:
    -   This is the main public method of the pipeline.
    -   Calls `_convert_file_to_images_bytes` to get page-wise data (text and/or images).
    -   Initializes a default `layout_questions_config` if none is provided. This default list includes questions for common elements like title, date, policy number, etc.
    -   Iterates through each processed page:
        -   If direct text was extracted by `_process_pdf`, it's used.
        -   Otherwise (or if direct text is empty), `_get_ocr_text_for_image` is called on the page's image bytes to get OCR text.
        -   The extracted text (direct or OCR) is added to `all_pages_full_text` and structured into `all_pages_text_blocks`. Each text block gets a UUID, page number, the text itself, a full-page bounding box `[0.0, 0.0, 1.0, 1.0]`, and an `extraction_method` (`direct` or `ocr`).
        -   If page image bytes are available, `_get_layout_elements_for_image` is called with the `layout_questions_config` to extract structured elements. These are added to `all_pages_layout_elements`.
    -   Aggregates results into a final dictionary containing:
        -   `metadata`: Filename, processing timestamp, page count, OCR/DocQA models used, processing time.
        -   `full_text`: All pages' text combined, separated by a separator string.
        -   `text_blocks`: List of structured text blocks suitable for RAG ingestion.
        -   `layout_elements`: List of all extracted layout elements from all pages.
    -   Returns a dictionary with `status: "success"` and the `result` dictionary, or `status: "error"` with an error message.

### 2. OCR Service (`src/ocr/service.py`)

This FastAPI application provides the HTTP interface for the OCR pipeline.

#### Initialization

-   Creates a FastAPI `app` instance.
-   Configures CORS middleware.
-   **Redis Client**: Initializes a connection to Redis (host/port from `REDIS_HOST`/`REDIS_PORT` env vars). Used for caching OCR results.
-   **OCRPipeline Instance**: Creates an instance of `OCRPipeline`. If this fails (e.g., `HF_TOKEN` not set), the service will log an error and endpoints will likely fail.
-   **HTTPX Client**: An `httpx.AsyncClient` is initialized for making asynchronous HTTP requests to the RAG service.

#### Key Endpoints

-   **`POST /process_and_ingest`**:
    -   Accepts a file upload (`UploadFile`).
    -   Validates file extension (PDF, common image types).
    -   Uses the `filename` as `document_id`.
    -   Reads file content.
    -   Defines a default list of `ocr_layout_questions` (similar to the pipeline's default, but defined at the service layer for this endpoint). This could be made more dynamic in future versions (e.g., passed in request).
    -   Calls `ocr_pipeline.process_document()` with the file content, type, filename, and layout questions.
    -   **Caching**: If OCR processing is successful, the entire result from `process_document` is stored in Redis using a key like `ocr_cache:{document_id}` (cached for 2 hours by default).
    -   **RAG Ingestion Trigger**:
        -   Extracts `text_blocks` and `metadata` from the OCR result.
        -   If no text blocks are found, logs a warning and RAG ingestion is skipped.
        -   Constructs a payload for the RAG service: `{"document_id": ..., "text_blocks": ..., "document_metadata": ...}`.
        -   Makes an asynchronous POST request to the RAG service's `/ingest` endpoint (URL from `RAG_SERVICE_URL` env var, default `http://rag_service:8000`, likely should be `http://rag_service:8001` based on project README).
        -   Logs the RAG service's response (success or failure).
    -   Returns a JSON response indicating OCR completion status, the `ocr_doc_key` (document ID), RAG ingestion status, and some OCR metadata.
    -   Handles `HTTPException` and other general exceptions, returning appropriate error responses.

-   **`GET /cached_ocr_data/{doc_id}`**:
    -   Retrieves the full cached OCR result for a given `doc_id` from Redis.
    -   Constructs the Redis key `ocr_cache:{doc_id}`.
    -   Returns the cached data or a 404 error if not found.

-   **`GET /health`**:
    -   Provides a health check for the service.
    -   Checks status of OCR pipeline initialization and Redis connection.
    -   Returns `status: "healthy"` or `"unhealthy"` along with individual component statuses.

#### Helper Functions

-   `store_in_redis()`: Stores JSON-serialized data in Redis with an optional expiry.
-   `get_from_redis()`: Retrieves and JSON-deserializes data from Redis.

## Data Flow

1.  User uploads a document to the Frontend Service.
2.  Frontend Service sends the file to the OCR Service's `/process_and_ingest` endpoint.
3.  OCR Service (`OCRPipeline`):
    a.  Converts/prepares pages (PDF text extraction + image rendering, or direct image use).
    b.  For each page image:
        i.  Performs OCR if direct text not available/sufficient.
        ii. Performs Document QA using configured questions to get layout elements.
    c.  Aggregates all text into blocks and collects all layout elements.
4.  OCR Service:
    a.  Caches the full structured result (metadata, full text, text blocks, layout elements) in Redis.
    b.  Sends `document_id`, `text_blocks`, and `document_metadata` to the RAG Service's `/ingest` endpoint.
5.  RAG Service then processes these text blocks for embedding and storage (see RAG Implementation docs).

## Environment Variables

Key environment variables influencing the OCR service and pipeline:

-   `HF_TOKEN`: Essential for Hugging Face API access.
-   `HF_OCR_MODEL`: Specifies the OCR model.
-   `HF_DOC_QA_MODEL`: Specifies the Document QA model.
-   `OCR_IMAGE_DPI`: DPI for rendering PDF pages to images.
-   `REDIS_HOST`, `REDIS_PORT`: For connecting to Redis.
-   `RAG_SERVICE_URL`: URL of the RAG service for triggering ingestion.
-   `LOG_LEVEL`

## Error Handling

-   The `OCRPipeline` logs errors from Hugging Face API calls but attempts to continue processing where possible (e.g., if one question fails in DocQA, others are still attempted).
-   The `ocr_service` FastAPI app handles file type validation, pipeline initialization errors, and exceptions during processing, returning appropriate HTTP error codes and messages.
-   Communication failures with the RAG service are logged, and the status is reported in the response to the original `/process_and_ingest` call.

This documentation provides an overview of the OCR and document understanding capabilities of the system. 