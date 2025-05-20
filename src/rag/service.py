"""
FastAPI service for the RAG pipeline, using OpenAI for embeddings and generation.
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
    title="Insurance Policy RAG API (OpenAI based)",
    description="API for ingesting processed document data and querying with RAG using OpenAI.",
    version="2.0.0"
)

# Initialize RAG pipeline
rag_pipeline = RAGPipeline()
logger.info("RAG API service initialized with RAGPipeline.")

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

class APIResponse(BaseModel):
    status: str
    result: Optional[Any] = None
    error: Optional[str] = None
    message: Optional[str] = None # For non-error messages like in ingestion
    document_id: Optional[str] = None # For ingestion response
    points_added: Optional[int] = None # For ingestion response

# --- API Endpoints ---

@app.post("/ingest", response_model=APIResponse)
async def ingest_processed_document(request: IngestRequest = Body(...)) -> APIResponse:
    """
    Ingest structured data (text blocks and metadata) from a processed document 
    into the RAG system (Qdrant).
    This endpoint is typically called by the OCR service after it has processed a document.
    """
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
            logger.error(f"Ingestion failed for document_id {request.document_id}: {result.get('error')}")
            raise HTTPException(
                status_code=500,
                detail=result.get("error", "Ingestion failed")
            )
        
        logger.info(f"Ingestion successful for document_id {request.document_id}. Points added: {result.get('points_added')}")
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
    logger.info(f"Received query: '{request.query}', top_k: {request.top_k}, filters: {request.filters}")
    try:
        result_dict = await rag_pipeline.query_rag(
            user_query=request.query,
            filters=request.filters,
            top_k=request.top_k
        )
        
        if result_dict.get("status") == "error":
            logger.error(f"Query processing failed for '{request.query}': {result_dict.get('error')}")
            raise HTTPException(
                status_code=500,
                detail=result_dict.get("error", "Query processing failed")
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

@app.get("/health", response_model=APIResponse)
async def health_check() -> APIResponse:
    """Check service health."""
    # Could add checks for Qdrant/Redis/OpenAI connectivity if needed
    logger.debug("Health check endpoint called.")
    return APIResponse(status="success", result={"message": "RAG service is healthy"})

# To run this service directly (e.g., for local testing without docker-compose for this specific service)
# if __name__ == "__main__":
#     uvicorn.run(
#         "src.rag.service:app", # Or if file is main.py in current dir: "main:app"
#         host=os.getenv("HOST", "0.0.0.0"),
#         port=int(os.getenv("PORT", 8001)), # Default RAG port, ensure it matches docker-compose
#         log_level=os.getenv("LOG_LEVEL", "info").lower(),
#         reload=True # Enable reload for development
#     ) 