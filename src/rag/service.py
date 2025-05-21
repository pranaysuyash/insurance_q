"""
FastAPI service for the RAG pipeline, with OpenAI/Hugging Face fallback mechanism.
"""
from fastapi import FastAPI, HTTPException, Body
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional, List
import uvicorn
from .pipeline import RAGPipeline
import logging
import os

logger = logging.getLogger(__name__)
logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper())

app = FastAPI(
    title="Insurance Policy RAG API (with OpenAI/HF fallback)",
    description="API for ingesting processed document data and querying with RAG using a fallback mechanism.",
    version="2.1.0"
)

# Initialize RAG pipeline
try:
    rag_pipeline = RAGPipeline(
        # Use environment variables to control embedding model preferences
        use_openai_first=os.getenv("USE_OPENAI_FIRST", "true").lower() == "true"
    )
    logger.info("RAG API service initialized with RAGPipeline and fallback mechanism.")
except Exception as e:
    logger.error(f"Error initializing RAGPipeline: {e}", exc_info=True)
    rag_pipeline = None  # Will handle missing pipeline in endpoints

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
    query: str
    filters: Optional[Dict[str, Any]] = Field(None, description="Key-value filters for Qdrant search, e.g., {'document_id': 'doc123'}")
    top_k: Optional[int] = Field(5, description="Number of top results to retrieve.")

class QueryResponse(BaseModel):
    answer: str
    sources: List[Dict[str, Any]]
    query: str
    embedding_model_used: Optional[str] = Field(None, description="The embedding model that was used for this query.")

class EmbeddingStats(BaseModel):
    active_embedding_model: str
    primary_model: str 
    fallback_model: str
    openai_embedding_failures: int
    hf_embedding_failures: int
    embedding_dimensions: int

class APIResponse(BaseModel):
    status: str
    result: Optional[Any] = None
    error: Optional[str] = None
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
    if not rag_pipeline:
        logger.error("RAGPipeline not available. Cannot process ingest request.")
        raise HTTPException(status_code=503, detail="RAG service is not fully initialized")
    
    logger.info(f"Received ingestion request for document_id: {request.document_id}, num_blocks: {len(request.text_blocks)}")
    try:
        # Convert Pydantic models to dicts for the pipeline if it expects dicts
        text_blocks_data = [block.model_dump() for block in request.text_blocks]
        
        result = await rag_pipeline.ingest_document_data(
            document_id=request.document_id,
            text_blocks=text_blocks_data,
            document_metadata=request.document_metadata
        )
        
        if result.get("status") == "error":
            error_msg = result.get("error", "Ingestion failed")
            logger.error(f"Ingestion failed for document_id {request.document_id}: {error_msg}")
            
            # Customize the error message for better user experience
            if "embedding" in error_msg.lower() and "failed" in error_msg.lower():
                error_msg = "Document text was extracted but couldn't be processed for Q&A functionality. You can still view the document text."
            
            raise HTTPException(
                status_code=500,
                detail=error_msg
            )
        
        logger.info(f"Ingestion successful for document_id {request.document_id}. Points added: {result.get('points_added')}, Model used: {result.get('embedding_model_used', 'unknown')}")
        return APIResponse(**result) # Directly return the pipeline's response dict

    except HTTPException as he:
        raise he # Re-raise HTTPExceptions directly
    except Exception as e:
        logger.error(f"Unexpected error during ingestion for document_id {request.document_id}: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"An unexpected error occurred during ingestion: {str(e)}"
        )

@app.post("/query", response_model=APIResponse)
async def query_rag_system(request: QueryRequest) -> APIResponse:
    """Query the RAG system with a user question."""
    if not rag_pipeline:
        logger.error("RAGPipeline not available. Cannot process query request.")
        raise HTTPException(status_code=503, detail="RAG service is not fully initialized")
    
    logger.info(f"Received query: '{request.query}', top_k: {request.top_k}, filters: {request.filters}")
    try:
        result_dict = await rag_pipeline.query_rag(
            user_query=request.query,
            filters=request.filters,
            top_k=request.top_k
        )
        
        if result_dict.get("status") == "error":
            error_msg = result_dict.get("error", "Query processing failed")
            logger.error(f"Query processing failed for '{request.query}': {error_msg}")
            
            if "embedding" in error_msg.lower() and "failed" in error_msg.lower():
                error_msg = "Your query could not be processed. Please try a different question or try again later."
                
            raise HTTPException(
                status_code=500,
                detail=error_msg
            )
        
        # The pipeline now returns {"status": "success", "result": final_response}
        # where final_response is {"answer": ..., "sources": ...}
        return APIResponse(status="success", result=QueryResponse(**result_dict["result"])) 

    except HTTPException as he:
        raise he
    except Exception as e:
        logger.error(f"Unexpected error during query '{request.query}': {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"An unexpected error occurred during query processing: {str(e)}"
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
        primary = rag_pipeline.openai_embedding_model if rag_pipeline.use_openai_first else rag_pipeline.embedding_model
        fallback = rag_pipeline.embedding_model if rag_pipeline.use_openai_first else rag_pipeline.openai_embedding_model
        active = rag_pipeline.active_embedding_model
        
        model_info = {
            "primary_embedding": primary,
            "fallback_embedding": fallback,
            "active_embedding": active,
            "chat_model": rag_pipeline.openai_chat_model
        }
        
    return APIResponse(
        status=status, 
        result={
            "message": message, 
            "models": model_info,
            "openai_failures": rag_pipeline.openai_embedding_failures if rag_pipeline else None,
            "hf_failures": rag_pipeline.hf_embedding_failures if rag_pipeline else None
        }
    )

# To run this service directly (e.g., for local testing without docker-compose for this specific service)
# if __name__ == "__main__":
#     uvicorn.run(
#         "src.rag.service:app", # Or if file is main.py in current dir: "main:app"
#         host=os.getenv("HOST", "0.0.0.0"),
#         port=int(os.getenv("PORT", 8001)), # Default RAG port, ensure it matches docker-compose
#         log_level=os.getenv("LOG_LEVEL", "info").lower(),
#         reload=True # Enable reload for development
#     ) 