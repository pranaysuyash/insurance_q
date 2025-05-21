"""
Frontend service for the Insurance Policy Parser & QA App.
"""
from fastapi import FastAPI, HTTPException, UploadFile, File, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
import os
import httpx
from typing import Optional, Dict, Any, List
from pydantic import BaseModel
import structlog
import time
import json

# Configure structured logging
logger = structlog.get_logger()
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer()
    ]
)

class Query(BaseModel):
    query: str

app = FastAPI(
    title="Insurance Policy Frontend (Updated)",
    description="Frontend service for insurance policy document processing and querying with new backend services.",
    version="2.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
app.mount("/static", StaticFiles(directory="src/frontend/static"), name="static")

# Templates setup
templates = Jinja2Templates(directory="src/frontend/templates")

# Service URLs from environment variables
OCR_SERVICE_URL = os.getenv("OCR_SERVICE_URL", "http://ocr_service:8001")
RAG_SERVICE_URL = os.getenv("RAG_SERVICE_URL", "http://rag_service:8000")

# HTTP client (managed by lifespan events)
http_client: Optional[httpx.AsyncClient] = None

@app.on_event("startup")
async def startup_event():
    global http_client
    http_client = httpx.AsyncClient(timeout=None) # Long timeout for OCR potentially
    logger.info("Frontend service started up, httpx.AsyncClient initialized.")

@app.on_event("shutdown")
async def shutdown_event():
    if http_client:
        await http_client.aclose()
    logger.info("Frontend service shutting down, httpx.AsyncClient closed.")

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Render the home page."""
    return templates.TemplateResponse(
        "index.html",
        {"request": request}
    )

@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log request and response details."""
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    
    logger.info(
        "request_processed",
        path=request.url.path,
        method=request.method,
        duration=f"{duration:.2f}s",
        status_code=response.status_code
    )
    return response

@app.post("/upload")
async def upload_document(file: UploadFile = File(...)):
    """Upload document to OCR service, get processed data, and display relevant parts."""
    if not http_client: # Should be initialized by lifespan
        raise HTTPException(status_code=503, detail="HTTP client not available.")
    
    try:
        filename = file.filename
        logger.info("document_upload_started", filename=filename)
        
        # Validate file extension
        file_ext = os.path.splitext(filename.lower())[1] if filename else ""
        allowed_extensions = ['.pdf', '.png', '.jpg', '.jpeg', '.tiff', '.tif', '.webp', '.doc', '.docx']
        if file_ext not in allowed_extensions:
            logger.warning("invalid_file_format", filename=filename, extension=file_ext)
            raise HTTPException(
                status_code=400, 
                detail=f"Unsupported file format: {file_ext}. Supported formats: PDF, PNG, JPG, TIFF, DOC, DOCX"
            )
        
        # 1. Call OCR service's /process_and_ingest endpoint
        files_for_ocr = {"file": (filename, file.file, file.content_type)}
        ocr_process_url = f"{OCR_SERVICE_URL.rstrip('/')}/process_and_ingest"
        logger.debug(f"Calling OCR process endpoint: {ocr_process_url}")
        
        ocr_response = await http_client.post(ocr_process_url, files=files_for_ocr)
        ocr_response.raise_for_status()
        ocr_process_result = ocr_response.json()
        logger.info("ocr_process_and_ingest_response", filename=filename, response=ocr_process_result)

        ocr_doc_key = ocr_process_result.get("ocr_doc_key")
        rag_status = ocr_process_result.get("rag_ingestion_status")
        rag_detail = ocr_process_result.get("rag_ingestion_detail")
        
        # Handle rate limit errors better
        if rag_status == "failed" and rag_detail:
            error_msg = str(rag_detail)
            if "429" in error_msg or "exceeded your current quota" in error_msg or "rate limit" in error_msg.lower():
                logger.warning("openai_rate_limit_exceeded", filename=filename)
                # We'll continue since OCR was successful, just add a note about RAG failure
                rag_detail = "OpenAI API rate limit exceeded. Text extraction worked, but Q&A features may be limited."
        
        if not ocr_doc_key:
            logger.error("ocr_doc_key_missing", ocr_response=ocr_process_result)
            raise HTTPException(status_code=500, detail="OCR service response missing 'ocr_doc_key'.")

        # 2. Fetch the cached full OCR data using the ocr_doc_key
        # Make sure we strip any 'ocr_cache:' prefix from the key to avoid double-prefixing
        clean_ocr_key = ocr_doc_key.replace("ocr_cache:", "") if ocr_doc_key.startswith("ocr_cache:") else ocr_doc_key
        ocr_data_url = f"{OCR_SERVICE_URL.rstrip('/')}/cached_ocr_data/{clean_ocr_key}"
        logger.debug(f"Fetching cached OCR data from: {ocr_data_url}")
        cached_data_response = await http_client.get(ocr_data_url)
        cached_data_response.raise_for_status()
        cached_data_payload = cached_data_response.json()
        
        # The actual OCR output is nested under 'cached_ocr_result' and then 'result'
        actual_ocr_output = cached_data_payload.get("cached_ocr_result", {}).get("result", {})
        if not actual_ocr_output:
            logger.warning("empty_ocr_output_from_cache", filename=filename, doc_key=ocr_doc_key)
            # Fallback or decide how to handle if cached data is unexpectedly empty

        # 3. Extract data for frontend
        # For V2, we primarily show full_text and layout_elements (which might be QA pairs)
        display_text = actual_ocr_output.get("full_text", "Text not found in OCR output.")
        layout_elements = actual_ocr_output.get("layout_elements", [])
        
        # Convert layout_elements into a simpler dictionary for the template if needed,
        # or the template can iterate through the list of dicts.
        # Group layout elements by ID to create sections
        sections = {}
        for element in layout_elements:
            element_id = element.get('id', 'unknown')
            sections[element_id] = element.get('text', '')
        
        logger.info("document_upload_data_prepared_for_frontend", filename=filename, doc_key=ocr_doc_key)
        
        return {
            "message": f"OCR processing for '{filename}' complete. RAG Ingestion: {rag_status} - {rag_detail}",
            "filename": filename,
            "doc_key": ocr_doc_key, # This is the key for cached OCR data
            "text": display_text,
            "layout_elements": layout_elements, # Pass the list of layout elements
            "sections": sections  # Add the sections dictionary
        }
            
    except httpx.HTTPStatusError as e:
        err_detail = f"Error communicating with backend service: {e.response.text if e.response else str(e)}"
        logger.error("http_error_during_backend_communication", filename=file.filename, error_detail=err_detail, status_code=e.response.status_code if e.response else 500)
        raise HTTPException(status_code=e.response.status_code if e.response else 500, detail=err_detail)
    except Exception as e:
        logger.error("document_upload_failed_unexpectedly", filename=file.filename, error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {str(e)}")

@app.post("/query")
async def query_document(query: Query):
    """Send query to RAG service."""
    if not http_client:
        raise HTTPException(status_code=503, detail="HTTP client not available.")
    try:
        logger.info("document_query_started", query=query.query)
        rag_query_url = f"{RAG_SERVICE_URL.rstrip('/')}/query"
        response = await http_client.post(rag_query_url, json={"query": query.query, "top_k": 5}) # Example top_k
        response.raise_for_status()
        result = response.json()
        logger.info("document_query_completed", query=query.query)
        # The RAG service now returns APIResponse(status="success", result=QueryResponse(...))
        # We should return the content of result['result'] to match frontend expectations if any, 
        # or update frontend to handle the new APIResponse structure.
        if result.get("status") == "success" and isinstance(result.get("result"), dict):
            # Ensure sources are properly formatted as objects not strings
            response_data = result["result"]
            # Convert sources if needed
            if isinstance(response_data.get("sources"), list):
                # Make sure each source is a properly formatted object
                for i, source in enumerate(response_data["sources"]):
                    if not isinstance(source, dict):
                        response_data["sources"][i] = {"source_text": str(source)}
            return response_data
        else:
            logger.error("rag_service_unexpected_response", query=query.query, response=result)
            return result # Or raise HTTPException

    except httpx.HTTPStatusError as e:
        err_detail = f"Error communicating with RAG service: {e.response.text if e.response else str(e)}"
        logger.error("http_error_during_rag_communication", query=query.query, error_detail=err_detail)
        raise HTTPException(status_code=e.response.status_code if e.response else 500, detail=err_detail)
    except Exception as e:
        logger.error("document_query_failed_unexpectedly", query=query.query, error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "ocr_service_target": OCR_SERVICE_URL, "rag_service_target": RAG_SERVICE_URL}

# Ensure all necessary imports are at the top, like Request for home(request: Request)
# Ensure structlog is configured if used.
# Uvicorn run block for direct execution (if __name__ == '__main__') can be added if needed for local dev. 