"""
FastAPI service for the RAG pipeline, with OpenAI/Hugging Face fallback mechanism.

Supports:
- Correlation ID tracing for end-to-end request tracking
- Automatic retry with exponential backoff for transient failures
- Structured logging with timing breakdowns
"""
import asyncio
import hashlib
import json
import logging
import os
import time
import uuid
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException, Body, Request
from pydantic import BaseModel, Field

from src.rag.pipeline import RAGPipeline

logger = logging.getLogger(__name__)

# Structured log helper — appends correlation_id + timing to every record
_CORRELATION_ID: str | None = None

def _set_correlation_id(cid: str) -> None:
    global _CORRELATION_ID
    _CORRELATION_ID = cid

def _clear_correlation_id() -> None:
    global _CORRELATION_ID
    _CORRELATION_ID = None

def _log(
    level: int,
    msg: str,
    *args: object,
    extra: dict | None = None,
    exc_info: bool = False,
) -> None:
    """Emit a structured log entry with correlation_id and optional extra fields.

    Accepts printf-style format args (``*args``) like ``logger.log()``.
    The formatted message is combined with a JSON suffix containing the
    correlation_id and any keyword-only ``extra`` fields before the real
    logger processes the line.
    """
    record = {
        "correlation_id": _CORRELATION_ID,
        **(extra or {}),
    }
    formatted = msg % args if args else msg
    suffix = " | " + json.dumps(record, default=str) if record else ""
    logger.log(level, "%s%s", formatted, suffix, exc_info=exc_info)

def _info(msg: str, *args: object, **extra: object) -> None:
    _log(logging.INFO, msg, *args, extra=extra)

def _warning(msg: str, *args: object, **extra: object) -> None:
    _log(logging.WARNING, msg, *args, extra=extra)

def _error(msg: str, *args: object, **extra: object) -> None:
    _log(logging.ERROR, msg, *args, extra=extra)

def _debug(msg: str, *args: object, **extra: object) -> None:
    _log(logging.DEBUG, msg, *args, extra=extra)

# ── Retry helper ────────────────────────────────────────────────────────────

class RetryExhausted(Exception):
    """Raised when all retry attempts have been exhausted."""

async def _with_retry(
    fn,
    *,
    max_retries: int = 2,
    base_delay_s: float = 1.0,
    operation: str = "operation",
) -> Any:
    """Execute `fn` with exponential backoff on transient errors.

    Transient errors: connection errors, timeouts, 5xx responses, and
    generic exceptions that are not HTTPException or ValueError.
    Permanent errors (4xx, ValueError, etc.) are re-raised immediately.

    Logs each attempt and the final outcome with timing.
    """
    last_exc: Exception | None = None
    for attempt in range(max_retries + 1):
        try:
            start = time.time()
            result = await fn()
            elapsed = time.time() - start
            if attempt > 0:
                _info(
                    "%s succeeded after %d retries (%.1fms)", operation, attempt, elapsed * 1000,
                )
            return result
        except HTTPException as he:
            # 5xx: transient
            if 500 <= he.status_code < 600:
                last_exc = he
                _warning(
                    "%s attempt %d/%d failed (5xx %d): %s",
                    operation, attempt + 1, max_retries + 1,
                    he.status_code, he.detail,
                    http_status=he.status_code,
                )
            else:
                # 4xx: permanent
                raise
        except (asyncio.TimeoutError, ConnectionError, OSError) as conn_err:
            last_exc = conn_err
            _warning(
                "%s attempt %d/%d failed (transport): %s",
                operation, attempt + 1, max_retries + 1, conn_err,
                error_type=type(conn_err).__name__,
            )
        except ValueError:
            # Permanent: re-raise immediately
            raise
        except Exception as exc:
            # Other exceptions: transient by default
            last_exc = exc
            _warning(
                "%s attempt %d/%d failed: %s",
                operation, attempt + 1, max_retries + 1, exc,
                error_type=type(exc).__name__,
            )

        if attempt < max_retries:
            delay = base_delay_s * (2 ** attempt)
            _debug("Retrying %s in %.1fs...", operation, delay, retry_delay_s=delay)
            await asyncio.sleep(delay)

    _error(
        "%s exhausted after %d retries", operation, max_retries,
        last_error=str(last_exc) if last_exc else None,
    )
    raise RetryExhausted(f"{operation} failed after {max_retries} retries") from last_exc


# ── Logging configuration ───────────────────────────────────────────────────

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

app = FastAPI(
    title="Insurance Policy RAG API (with OpenAI/HF fallback)",
    description="API for ingesting processed document data and querying with RAG using a fallback mechanism.",
    version="2.1.0"
)


# ── Middleware: inject correlation ID into every request ────────────────────

@app.middleware("http")
async def _correlation_id_middleware(request: Request, call_next):
    """Assign a correlation ID to each incoming request for traceability.

    Uses the `X-Correlation-ID` header if provided by the client (e.g.,
    the mobile app can generate and forward it); otherwise generates one.
    Logs the request start, duration, and status code on completion.
    """
    cid = request.headers.get("x-correlation-id") or str(uuid.uuid4())
    _set_correlation_id(cid)

    start = time.time()
    method = request.method
    path = request.url.path
    _info("→ %s %s", method, path, http_method=method, path=path)

    try:
        response = await call_next(request)
        elapsed_ms = int((time.time() - start) * 1000)
        _info(
            "← %s %s %d (%.0fms)",
            method, path, response.status_code, elapsed_ms,
            status_code=response.status_code, latency_ms=elapsed_ms,
        )
        response.headers["X-Correlation-ID"] = cid
        return response
    except Exception as exc:
        elapsed_ms = int((time.time() - start) * 1000)
        _error(
            "✗ %s %s unhandled (%.0fms): %s",
            method, path, elapsed_ms, exc,
            status_code=500, latency_ms=elapsed_ms, error_type=type(exc).__name__,
        )
        raise
    finally:
        _clear_correlation_id()


# Initialize RAG pipeline
try:
    rag_pipeline = RAGPipeline(
        # No arguments needed now as it defaults to OpenAI and no fallback
    )
    _info("RAG pipeline initialized successfully")
except Exception as e:
    _error("Failed to initialize RAG pipeline: %s", e)
    rag_pipeline = None

# --- Pydantic Models for API requests/responses ---

class TextBlockSchema(BaseModel):
    id: str = Field(..., description="Unique ID for the text block, e.g., from OCR output or generated.")
    page: Optional[int] = Field(None, description="Page number where the text block is located.")
    text: str = Field(..., description="The actual text content of the block.")
    bbox: Optional[List[float]] = Field(None, description="Bounding box coordinates, e.g., [x1, y1, x2, y2].")
    # Add any other relevant fields from OCR output if needed for payload

class IngestRequest(BaseModel):
    document_id: str = Field(..., description="Unique identifier for the source document, e.g., filename or a DB ID.")
    text_blocks: List[TextBlockSchema] = Field(..., description="List of text blocks extracted from the document.")
    document_metadata: Optional[Dict[str, Any]] = Field(None, description="Overall metadata for the document, e.g., filename, original source type.")

class QueryRequest(BaseModel):
    query: str = Field(..., description="User query/question to answer")
    filters: Optional[Dict[str, Any]] = Field(None, description="Filters to apply to the query")
    top_k: Optional[int] = Field(3, description="Number of results to return")

class QueryResponse(BaseModel):
    answer: str = Field(..., description="Answer to the query")
    sources: List[Dict[str, Any]] = Field(..., description="Sources for the answer")
    query: Optional[str] = Field(None, description="The original query")
    embedding_model_used: Optional[str] = Field(None, description="The embedding model used for retrieval")

class EmbeddingStats(BaseModel):
    active_embedding_model: str
    primary_model: str 
    fallback_model: str
    openai_embedding_failures: int
    hf_embedding_failures: int
    embedding_dimensions: int

class APIResponse(BaseModel):
    status: str = Field(..., description="Success or error status")
    result: Optional[Any] = Field(None, description="Result of the operation")
    error: Optional[str] = Field(None, description="Error message if status is error")
    message: Optional[str] = None # For non-error messages like in ingestion
    document_id: Optional[str] = None # For ingestion response
    points_added: Optional[int] = None # For ingestion response
    embedding_model_used: Optional[str] = None # For ingestion response

# --- API Endpoints ---

@app.post("/ingest", response_model=APIResponse)
async def ingest_processed_document(request: IngestRequest = Body(...)) -> APIResponse:
    """
    Ingest structured data (text blocks and metadata) from a processed document 
    into the RAG system (Qdrant).
    This endpoint is typically called by the OCR service after it has processed a document.
    """
    doc_id = request.document_id
    num_blocks = len(request.text_blocks)
    _info("Ingest start: doc=%s blocks=%d", doc_id, num_blocks, document_id=doc_id, block_count=num_blocks)

    if not rag_pipeline:
        _error("RAG pipeline not available for ingest")
        raise HTTPException(status_code=503, detail="RAG service is not fully initialized")

    ingest_start = time.time()

    async def _do_ingest():
        text_blocks_data = [block.model_dump() for block in request.text_blocks]
        return await rag_pipeline.ingest_document_data(
            document_id=doc_id,
            text_blocks=text_blocks_data,
            document_metadata=request.document_metadata
        )

    try:
        result = await _with_retry(
            _do_ingest,
            max_retries=2,
            base_delay_s=1.0,
            operation=f"ingest:{doc_id}",
        )

        elapsed_ms = int((time.time() - ingest_start) * 1000)

        if result.get("status") == "error":
            error_msg = result.get("error", "Ingestion failed")
            _error(
                "Ingest failed: doc=%s error=%s (%.0fms)",
                doc_id, error_msg, elapsed_ms,
                document_id=doc_id, error=error_msg, latency_ms=elapsed_ms,
            )
            if "embedding" in error_msg.lower() and "failed" in error_msg.lower():
                error_msg = "Document text was extracted but couldn't be processed for Q&A functionality. You can still view the document text."
            raise HTTPException(status_code=500, detail=error_msg)

        points = result.get("points_added", 0)
        model_used = result.get("embedding_model_used", "unknown")
        _info(
            "Ingest success: doc=%s points=%d model=%s (%.0fms)",
            doc_id, points, model_used, elapsed_ms,
            document_id=doc_id, points_added=points, embedding_model=model_used, latency_ms=elapsed_ms,
        )
        return APIResponse(**result)

    except HTTPException:
        raise
    except RetryExhausted as re:
        _error("Ingest exhausted for doc=%s: %s", doc_id, re, document_id=doc_id)
        raise HTTPException(status_code=503, detail=f"Ingestion service temporarily unavailable: {re}")
    except Exception as e:
        _error(
            "Ingest unexpected error: doc=%s error=%s",
            doc_id, e,
            document_id=doc_id, error_type=type(e).__name__,
        )
        raise HTTPException(
            status_code=500,
            detail=f"An unexpected error occurred during ingestion: {str(e)}"
        )

@app.post("/query", response_model=APIResponse)
async def query_rag_system(request: QueryRequest) -> APIResponse:
    """Query the RAG system with a user question.

    Implements automatic retry with exponential backoff for transient failures
    (5xx, connection errors, timeouts). Client-side retry is also enabled in
    the mobile QueryService (2 retries, 2s→4s backoff).
    """
    query_text = request.query
    query_hash = hashlib.sha256(query_text.encode("utf-8")).hexdigest()
    _info(
        "Query start: hash=%s top_k=%d",
        query_hash[:12], request.top_k,
        query_hash=query_hash, top_k=request.top_k, filters=request.filters is not None,
    )

    if not rag_pipeline:
        _error("RAG pipeline not available for query")
        raise HTTPException(status_code=503, detail="RAG service is not fully initialized")

    query_start = time.time()

    async def _do_query():
        return await rag_pipeline.query_rag(
            user_query=query_text,
            filters=request.filters,
            top_k=request.top_k
        )

    try:
        result_dict = await _with_retry(
            _do_query,
            max_retries=2,
            base_delay_s=1.0,
            operation=f"query:{query_hash[:12]}",
        )

        elapsed_ms = int((time.time() - query_start) * 1000)

        # Normalize older pipeline outputs: wrap flat answer/sources into result
        if isinstance(result_dict, dict) and "answer" in result_dict and "status" not in result_dict:
            result_dict = {
                "status": "success",
                "result": {
                    "answer": result_dict.get("answer"),
                    "sources": result_dict.get("sources", []),
                    "query": query_text,
                    "embedding_model_used": result_dict.get("embedding_model_used")
                }
            }

        # Legacy flat response fallback: wrap direct answer/sources into result if no 'result' key
        if "result" not in result_dict and "answer" in result_dict:
            answer = result_dict.get("answer")
            sources = result_dict.get("sources", [])
            result_dict = {
                "status": "success",
                "result": {
                    "answer": answer,
                    "sources": sources,
                    "query": query_text,
                    "embedding_model_used": result_dict.get("embedding_model_used")
                }
            }

        if result_dict.get("status") == "error":
            error_msg = result_dict.get("error", "Query processing failed")
            _error(
                "Query failed: hash=%s error=%s (%.0fms)",
                query_hash[:12], error_msg, elapsed_ms,
                query_hash=query_hash, error=error_msg, latency_ms=elapsed_ms,
            )
            return APIResponse(status="error", error=error_msg)

        # Log summary of successful query
        res = result_dict.get("result", {})
        sources_count = len(res.get("sources", []))
        llm_used = res.get("llm_used", False)
        confidence = res.get("confidence", 0.0)
        _info(
            "Query success: hash=%s sources=%d llm=%s confidence=%.2f (%.0fms)",
            query_hash[:12], sources_count, llm_used, confidence, elapsed_ms,
            query_hash=query_hash, num_sources=sources_count,
            llm_used=llm_used, confidence=confidence, latency_ms=elapsed_ms,
        )

        return APIResponse(
            status="success",
            result=res
        )

    except HTTPException:
        raise
    except RetryExhausted as re:
        elapsed_ms = int((time.time() - query_start) * 1000)
        _error(
            "Query exhausted after retries: hash=%s (%.0fms): %s",
            query_hash[:12], elapsed_ms, re,
            query_hash=query_hash, latency_ms=elapsed_ms, error=str(re),
        )
        return APIResponse(
            status="error",
            error="The RAG service is temporarily unavailable. Please try again in a few moments."
        )
    except Exception as e:
        elapsed_ms = int((time.time() - query_start) * 1000)
        _error(
            "Query unexpected error: hash=%s error=%s (%.0fms)",
            query_hash[:12], e, elapsed_ms,
            query_hash=query_hash, error_type=type(e).__name__,
            latency_ms=elapsed_ms,
        )
        return APIResponse(
            status="error",
            error="Failed to process query. Please try again."
        )

@app.get("/embedding-stats", response_model=APIResponse)
async def get_embedding_stats() -> APIResponse:
    """Get statistics about embedding usage and failures."""
    if not rag_pipeline:
        logger.error("RAGPipeline not available. Cannot get embedding stats.")
        raise HTTPException(status_code=503, detail="RAG service is not fully initialized")
    
    try:
        stats = await rag_pipeline.get_embedding_stats()
        return APIResponse(status="success", result=EmbeddingStats(**stats))
    except Exception as e:
        logger.error(f"Error getting embedding stats: {e}", exc_info=True)
        raise HTTPException(
            status_code=500, 
            detail=f"Failed to retrieve embedding statistics: {str(e)}"
        )

@app.get("/health", response_model=APIResponse)
async def health_check() -> APIResponse:
    """Check service health."""
    logger.debug("Health check endpoint called.")
    status = "success" if rag_pipeline else "degraded"
    message = "RAG service is healthy" if rag_pipeline else "RAG service initialized with warnings"
    
    # Add embedding model info to health check
    model_info = {}
    if rag_pipeline:
        model_info = {
            "primary_embedding": rag_pipeline.openai_embedding_model,
            "fallback_embedding": getattr(rag_pipeline, "ollama_embedding_model", None) or rag_pipeline.hf_embedding_model,
            "active_embedding": rag_pipeline.active_embedding_model,
            "chat_model": rag_pipeline.openai_chat_model,
            "embedding_dimensions": rag_pipeline.embedding_dimensions,
        }
        
    return APIResponse(
        status=status, 
        result={
            "message": message, 
            "models": model_info,
            "openai_failures": rag_pipeline.openai_failure_count if rag_pipeline else None,
            "hf_failures": rag_pipeline.hf_failure_count if rag_pipeline else None
        }
    )

@app.post("/contextual-retrieval/enable", response_model=APIResponse)
async def enable_contextual_retrieval(
    collection_name: Optional[str] = None,
    owner_id: Optional[str] = None,
    trigger_backfill: bool = True,
) -> APIResponse:
    """Enable contextual retrieval feature flag and optionally trigger backfill (ADR-26, Commit 6)."""
    if not rag_pipeline:
        raise HTTPException(status_code=503, detail="RAG service not initialized")
    
    try:
        # Set feature flag in pipeline / Redis
        rag_pipeline._contextual_retrieval_enabled = True
        if getattr(rag_pipeline, "cache", None):
            key = f"rag:contextual_retrieval:enabled:{collection_name or 'default'}"
            rag_pipeline.cache.set(key, "true")
        
        backfill_result = None
        if trigger_backfill:
            from src.rag.backfill import backfill_contextual_retrieval
            backfill_result = await backfill_contextual_retrieval(
                rag_pipeline, collection_name=collection_name, owner_id=owner_id
            )

        return APIResponse(
            status="success",
            result={
                "contextual_retrieval_enabled": True,
                "backfill_result": backfill_result,
            }
        )
    except Exception as e:
        logger.error(f"Failed to enable contextual retrieval: {e}", exc_info=True)
        return APIResponse(status="error", error=str(e))


# To run this service directly (e.g., for local testing without docker-compose for this specific service)
# if __name__ == "__main__":
#     uvicorn.run(
#         "src.rag.service:app", # Or if file is main.py in current dir: "main:app"
#         host=os.getenv("HOST", "0.0.0.0"),
#         port=int(os.getenv("PORT", 8001)), # Default RAG port, ensure it matches docker-compose
#         log_level=os.getenv("LOG_LEVEL", "info").lower(),
#         reload=True # Enable reload for development
#     ) 
