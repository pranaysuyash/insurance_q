"""
@deprecated — Standalone OCR microservice.

This service is DEPRECATED. The main app (src/app/main.py) now handles
document processing inline via /process-and-ingest, using the same
OCRPipeline internally. This avoids duplicate model loading, HTTP
latency, and code drift between two parallel code paths.

Migration:
  - Frontend: call POST /process-and-ingest on the main app instead
  - The main app's endpoint returns the same response shape
  - No separate Redis cache needed — results are returned inline

Removal target: next major release after all consumers are migrated.
"""

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import os
import redis
import httpx # For making requests to RAG service
from typing import Optional, Dict, Any
import json
import logging
import sys # Make sure sys is imported at the top if not already

# Correct import for Docker and local
from src.ocr.pipeline import OCRPipeline # Refactored pipeline
from src.utils.upload_validation import MAX_UPLOAD_BYTES, UploadValidationError, validate_upload_content

# Configure logging
logger = logging.getLogger(__name__)
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "DEBUG").upper(),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

app = FastAPI(
    title="Insurance Policy OCR Service (HF API based)",
    description="Service for extracting text and structure using Hugging Face APIs, and triggering RAG ingestion.",
    version="2.0.0" # Version updated
)

# CORS middleware — this is a deprecated internal-only service accessed
# over the Docker internal network. The wildcard + credentials combination
# was a security anti-pattern (CSO Finding #2). Restrict to local origins.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8080", "http://127.0.0.1:8080", "http://localhost:8000"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Service Configurations ---
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
RAG_SERVICE_URL = os.getenv("RAG_SERVICE_URL", "http://rag_service:8000") # Default internal Docker URL for RAG service

# --- Initialize Redis Client ---
redis_client: Optional[redis.Redis] = None
try:
    # Azure Redis Cache requires SSL connection
    REDIS_PASSWORD = os.getenv("REDIS_PASSWORD")
    if not REDIS_PASSWORD:
        logger.warning("REDIS_PASSWORD not set. Redis connection will fail.")
        redis_client = None
    else:
        redis_client = redis.Redis(
            host=REDIS_HOST, 
            port=REDIS_PORT, 
            password=REDIS_PASSWORD,
            ssl=True,  # Enable SSL for Azure Redis Cache
            ssl_cert_reqs=None,  # Don't verify SSL certificates
            decode_responses=True
        )
        redis_client.ping()
        logger.info(f"Successfully connected to Redis at {REDIS_HOST}:{REDIS_PORT} with SSL")
except redis.exceptions.ConnectionError as e:
    logger.error(f"Could not connect to Redis at {REDIS_HOST}:{REDIS_PORT}: {e}. Caching will be disabled.")
    redis_client = None # Allow service to run, but caching features will be affected
except Exception as e:
    logger.error(f"Unexpected error connecting to Redis: {e}. Caching will be disabled.")
    redis_client = None

# --- Initialize OCR Pipeline ---
try:
    # The refactored OCRPipeline uses os.getenv internally for its HF_TOKEN
    ocr_pipeline = OCRPipeline()
    logger.info("OCRPipeline initialized successfully.")
except Exception as e:
    logger.error(f"Critical error initializing OCRPipeline: {e}", exc_info=True)
    ocr_pipeline = None # Service will be unhealthy if pipeline fails to init

# --- HTTP Client for Inter-Service Communication ---
# It's good practice to manage the client's lifecycle, e.g., with context managers or FastAPI lifespan events.
# For simplicity here, a global client is used. Consider lifespan management for production.
http_client = httpx.AsyncClient(timeout=30.0) # Timeout for requests to RAG service

# --- Helper for Redis ---
def store_in_redis(key: str, data: Dict[str, Any], ex: Optional[int] = 3600): # ex in seconds (1 hour)
    if redis_client:
        try:
            redis_client.set(key, json.dumps(data), ex=ex)
            logger.debug(f"Stored data in Redis with key: {key}")
        except redis.exceptions.RedisError as e:
            logger.warning(f"Failed to store data in Redis for key {key}: {e}")

def get_from_redis(key: str) -> Optional[Dict[str, Any]]:
    if redis_client:
        try:
            cached_data_json = redis_client.get(key)
            if cached_data_json:
                logger.debug(f"Retrieved data from Redis for key: {key}")
                return json.loads(cached_data_json)
        except redis.exceptions.RedisError as e:
            logger.warning(f"Failed to get data from Redis for key {key}: {e}")
    return None

# --- API Endpoints ---

@app.post("/process_and_ingest")
async def process_document_and_trigger_ingestion(file: UploadFile = File(...)):
    print("ENTRY: /process_and_ingest OCR service handler hit", file=sys.stderr)
    """
    Processes an uploaded document using OCRPipeline.
    If successful, triggers ingestion of the structured data into the RAG service.
    Stores the full OCR result in Redis for caching/debugging.
    """
    if ocr_pipeline is None:
        logger.error("Process attempt failed: OCR Pipeline is not available.")
        raise HTTPException(status_code=503, detail="OCR Pipeline is not available. Service might be misconfigured.")

    try:
        content = await file.read(MAX_UPLOAD_BYTES + 1)
        try:
            file_ext = validate_upload_content(file.filename, content)
        except UploadValidationError as error:
            raise HTTPException(
                status_code=422,
                detail={"code": error.code, "message": error.message},
            ) from error
        file_type_for_pipeline = file_ext.strip('.')
        document_id = file.filename # Using filename as document_id, ensure it's unique or generate one
        logger.info(f"Processing document: {document_id}, type: {file_type_for_pipeline}")
        
        # Define layout questions for the OCR pipeline (can be customized)
        # Example: Could be loaded from a config file or passed via request in a more advanced setup
        ocr_layout_questions = [
            {"id": "policy_holder_name", "type": "policy_holder", "question": "Who is the policy holder or insured name?"},
            {"id": "policy_number", "type": "policy_id", "question": "What is the policy number?"},
            {"id": "insurance_provider", "type": "provider_name", "question": "What is the name of the insurance company or provider?"},
            {"id": "effective_date", "type": "date_effective", "question": "What is the effective date of the policy?"},
            {"id": "expiration_date", "type": "date_expiration", "question": "What is the expiration date of the policy?"},
            {"id": "total_premium", "type": "currency_amount", "question": "What is the total premium amount?"},
            {"id": "coverage_type", "type": "coverage_general_type", "question": "What is the general type of coverage (e.g., Auto, Home, Health)?"}
        ]

        ocr_result_data = await ocr_pipeline.process_document(
            file_content=content,
            file_type=file_type_for_pipeline,
            filename=document_id,
            layout_questions_config=ocr_layout_questions
        )

        if ocr_result_data.get("status") != "success":
            error_detail = ocr_result_data.get('error', "Unknown OCR processing error.")
            logger.error(f"OCRPipeline processing failed for {document_id}: {error_detail}")
            raise HTTPException(status_code=500, detail=f"OCR processing failed: {error_detail}")

        # OCR successful, store the full result in Redis with a clean document_id
        clean_doc_id = document_id.replace("ocr_cache:", "") if document_id.startswith("ocr_cache:") else document_id
        redis_key = f"ocr_cache:{clean_doc_id}"
        store_in_redis(redis_key, ocr_result_data, ex=7200) # Cache for 2 hours
        logger.info(f"OCR processing successful for {clean_doc_id}. Full result cached in Redis with key: {redis_key}")

        # Now, prepare data and trigger ingestion into RAG service
        # The actual result from OCR is in ocr_result_data["result"]
        actual_ocr_output = ocr_result_data.get("result", {})
        text_blocks_for_rag = actual_ocr_output.get("text_blocks", [])
        document_metadata_for_rag = actual_ocr_output.get("metadata", {})
        # Add any other relevant top-level metadata from OCR output if needed for RAG payload
        # For example, if full_text is needed in RAG's document metadata (not per block):
        # document_metadata_for_rag["ocr_full_text"] = actual_ocr_output.get("full_text")

        if not text_blocks_for_rag:
            logger.warning(f"No text blocks extracted by OCR for {document_id}. RAG ingestion will be skipped.")
            return {
                "message": "Document processed by OCR, but no text blocks found for RAG ingestion.",
                "filename": document_id,
                "ocr_doc_key": document_id, # Just the document ID, not the full Redis key
                "rag_ingestion_status": "skipped_no_text_blocks"
            }

        ingest_payload = {
            "document_id": document_id, # Ensure this ID is what RAG service expects
            "text_blocks": text_blocks_for_rag,
            "document_metadata": document_metadata_for_rag
        }
        
        rag_ingest_url = f"{RAG_SERVICE_URL.rstrip('/')}/ingest"
        logger.info(f"Attempting to send processed data for {document_id} to RAG service at {rag_ingest_url}")
        
        rag_ingestion_status = "failed"
        rag_ingestion_detail = "Unknown error during RAG ingestion call."

        try:
            response_from_rag = await http_client.post(rag_ingest_url, json=ingest_payload)
            response_from_rag.raise_for_status() # Raises HTTPStatusError for 4xx/5xx responses
            rag_response_json = response_from_rag.json()
            
            if rag_response_json.get("status") == "success":
                rag_ingestion_status = "success"
                rag_ingestion_detail = f"Successfully ingested. Points added: {rag_response_json.get('points_added', 'N/A')}"
                logger.info(f"RAG ingestion successful for {document_id}: {rag_ingestion_detail}")
            else:
                rag_ingestion_detail = rag_response_json.get("error", "RAG service reported an error.")
                logger.error(f"RAG ingestion failed for {document_id} (RAG service error): {rag_ingestion_detail}")

        except httpx.RequestError as exc: # Covers network errors, DNS failures, etc.
            rag_ingestion_detail = f"RAG service request failed: {exc}"
            logger.error(f"HTTP request to RAG service failed for {document_id}: {exc}", exc_info=True)
        except httpx.HTTPStatusError as exc: # For 4xx/5xx errors from RAG service
            rag_ingestion_detail = f"RAG service returned error {exc.response.status_code}: {exc.response.text[:200]}"
            logger.error(f"RAG service returned status error for {document_id}: {rag_ingestion_detail}", exc_info=True)
        except json.JSONDecodeError as exc:
            rag_ingestion_detail = f"Failed to decode RAG service response: {exc}"
            logger.error(f"Could not decode JSON response from RAG service for {document_id}: {exc}", exc_info=True)


        return {
            "message": "Document OCR processing complete.",
            "filename": document_id,
            "ocr_doc_key": document_id,  # Return just the document ID, not the full Redis key
            "rag_ingestion_status": rag_ingestion_status,
            "rag_ingestion_detail": rag_ingestion_detail,
            "ocr_metadata": document_metadata_for_rag # Return OCR metadata like page count
        }
    
    except HTTPException as he: # Re-raise HTTPExceptions
        logger.warning(f"HTTPException during processing of {file.filename if file else 'unknown file'}: {he.detail}")
        raise he
    except Exception as e:
        logger.error(f"Unexpected error in /process_and_ingest for {file.filename if file else 'unknown file'}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Server error during document processing: {str(e)}")


@app.get("/cached_ocr_data/{doc_id}")
async def get_cached_ocr_document_data(doc_id: str):
    """Retrieve all processed OCR data (text, layout, etc.) for a given document ID from Redis."""
    # Remove 'ocr_cache:' prefix if it's already included in the doc_id
    clean_doc_id = doc_id.replace("ocr_cache:", "") if doc_id.startswith("ocr_cache:") else doc_id
    
    redis_key = f"ocr_cache:{clean_doc_id}"
    logger.info(f"Looking up OCR data in Redis with key: {redis_key}")
    
    stored_data = get_from_redis(redis_key)
    
    if not stored_data:
        logger.error(f"No cached OCR data found for doc_id: {clean_doc_id} (key: {redis_key})")
        # Also try with the original doc_id as a fallback
        fallback_key = doc_id
        logger.info(f"Trying fallback Redis key: {fallback_key}")
        stored_data = get_from_redis(fallback_key)
        
        if not stored_data:
            logger.error(f"Fallback also failed - no cached data found with key: {fallback_key}")
            raise HTTPException(status_code=404, detail=f"No cached OCR data found for document ID: {clean_doc_id}")
    
    logger.info(f"Successfully retrieved cached OCR data for doc_id: {clean_doc_id}")
    # The data stored is already the full response from OCRPipeline.process_document
    return {"doc_id": clean_doc_id, "cached_ocr_result": stored_data}


@app.get("/health")
async def health_check():
    """Health check endpoint for OCR service."""
    ocr_pipeline_status = "available" if ocr_pipeline is not None else "unavailable"
    redis_connection_status = "unavailable"
    
    if redis_client:
        try:
            redis_client.ping()
            redis_connection_status = "connected"
        except redis.exceptions.ConnectionError as e:
            redis_connection_status = f"connection_error: {str(e)[:50]}"
            logger.warning(f"Health check: Redis ping failed: {e}")
        except Exception as e: # Catch other potential Redis client errors
            redis_connection_status = f"error: {str(e)[:50]}"
            logger.warning(f"Health check: Redis client error: {e}")


    final_status = "healthy" if ocr_pipeline_status == "available" and redis_connection_status == "connected" else "unhealthy"
    
    return {
        "status": final_status,
        "ocr_pipeline": ocr_pipeline_status,
        "redis": redis_connection_status,
        "rag_service_url_configured": RAG_SERVICE_URL # To check config
    }

# Lifecycle events for httpx client (good practice for production)
@app.on_event("startup")
async def startup_event():
    global http_client
    http_client = httpx.AsyncClient(timeout=30.0)
    logger.info("OCR Service started up, httpx.AsyncClient initialized.")

@app.on_event("shutdown")
async def shutdown_event():
    await http_client.aclose()
    logger.info("OCR Service shutting down, httpx.AsyncClient closed.")

# Add debug route to list Redis keys
@app.get("/debug/redis/keys")
async def debug_list_redis_keys():
    """Debug endpoint to list all Redis keys."""
    if not redis_client:
        raise HTTPException(status_code=503, detail="Redis client not available")
    
    try:
        all_keys = redis_client.keys("*")
        ocr_cache_keys = redis_client.keys("ocr_cache:*")
        
        return {
            "all_keys_count": len(all_keys),
            "all_keys": all_keys,
            "ocr_cache_keys_count": len(ocr_cache_keys),
            "ocr_cache_keys": ocr_cache_keys
        }
    except Exception as e:
        logger.error(f"Error listing Redis keys: {e}")
        raise HTTPException(status_code=500, detail=f"Error listing Redis keys: {str(e)}")

@app.delete("/debug/redis/clear_cache")
async def debug_clear_redis_cache():
    """Debug endpoint to clear all OCR cache keys in Redis."""
    if not redis_client:
        raise HTTPException(status_code=503, detail="Redis client not available")
    
    try:
        ocr_cache_keys = redis_client.keys("ocr_cache:*")
        if ocr_cache_keys:
            deleted_count = redis_client.delete(*ocr_cache_keys)
            return {"message": f"Cleared {deleted_count} OCR cache keys from Redis"}
        else:
            return {"message": "No OCR cache keys found to clear"}
    except Exception as e:
        logger.error(f"Error clearing Redis cache: {e}")
        raise HTTPException(status_code=500, detail=f"Error clearing Redis cache: {str(e)}")

# To run this service directly (e.g., for local testing without docker-compose)
# if __name__ == "__main__":
#     uvicorn.run(
#         "src.ocr.service:app",
#         host=os.getenv("HOST", "0.0.0.0"),
#         port=int(os.getenv("PORT", 8000)), # Default OCR port
#         log_level=os.getenv("LOG_LEVEL", "info").lower(),
#         reload=True 
#     )
