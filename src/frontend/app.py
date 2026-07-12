"""
Frontend service for the Insurance Policy Parser & QA App.
"""
from contextlib import asynccontextmanager
from datetime import date
from fastapi import FastAPI, HTTPException, UploadFile, File, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, PlainTextResponse, Response, FileResponse
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

SITE_NAME = "CoverWise"
DEFAULT_LAUNCH_WINDOW = os.getenv("LAUNCH_WINDOW", "late July 2026")

app = FastAPI(
    title="CoverWise | Insurance Policy Frontend",
    description="CoverWise turns insurance policy PDFs into plain-language summaries, grounded answers, and launch-ready marketing pages.",
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
OCR_SERVICE_URL = os.getenv("OCR_SERVICE_URL", "http://rag_service:8000")  # Now points to main app
RAG_SERVICE_URL = os.getenv("RAG_SERVICE_URL", "http://rag_service:8000")

# HTTP client (managed by lifespan events)
http_client: Optional[httpx.AsyncClient] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global http_client
    http_client = httpx.AsyncClient(timeout=None)
    logger.info("Frontend service started up, httpx.AsyncClient initialized.")
    try:
        yield
    finally:
        if http_client:
            await http_client.aclose()
        logger.info("Frontend service shutting down, httpx.AsyncClient closed.")


app.router.lifespan_context = lifespan


def _resolve_public_site_url(request: Request) -> str:
    configured_url = os.getenv("PUBLIC_SITE_URL", "").strip()
    if configured_url:
        return configured_url.rstrip("/")
    return str(request.base_url).rstrip("/")


@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Render the home page."""
    site_url = _resolve_public_site_url(request)
    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "site_url": site_url,
            "site_name": SITE_NAME,
            "page_title": "CoverWise | Understand your insurance policy in plain language",
            "page_description": (
                "CoverWise reads insurance policy PDFs, surfaces coverage, exclusions, waiting periods, and claim details, then answers grounded questions."
            ),
            "launch_window": DEFAULT_LAUNCH_WINDOW,
            "current_year": date.today().year,
        }
    )


@app.get("/robots.txt")
async def robots_txt(request: Request):
    site_url = _resolve_public_site_url(request)
    content = "\n".join(
        [
            "User-agent: *",
            "Allow: /",
            f"Sitemap: {site_url}/sitemap.xml",
            "",
        ]
    )
    return PlainTextResponse(content, media_type="text/plain")


@app.get("/sitemap.xml")
async def sitemap_xml(request: Request):
    site_url = _resolve_public_site_url(request)
    today = date.today().isoformat()
    xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>{site_url}/</loc>
    <lastmod>{today}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
"""
    return Response(content=xml, media_type="application/xml")


@app.api_route("/favicon.ico", methods=["GET", "HEAD"])
async def favicon():
    return FileResponse(os.path.join("src/frontend/static", "favicon.ico"))

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
        
        # Call main app's /process-and-ingest (replaces standalone OCR service)
        files_for_ocr = {"file": (filename, file.file, file.content_type)}
        ocr_process_url = f"{OCR_SERVICE_URL.rstrip('/')}/process-and-ingest"
        logger.debug(f"Calling process endpoint: {ocr_process_url}")
        
        ocr_response = await http_client.post(ocr_process_url, files=files_for_ocr)
        ocr_response.raise_for_status()
        ocr_process_result = ocr_response.json()
        logger.info("process_and_ingest_response", filename=filename, response=ocr_process_result)

        ocr_doc_key = ocr_process_result.get("ocr_doc_key")
        rag_status = ocr_process_result.get("rag_ingestion_status")
        rag_detail = ocr_process_result.get("rag_ingestion_detail")
        
        # Handle rate limit errors better
        if rag_status == "failed" and rag_detail:
            error_msg = str(rag_detail)
            if "429" in error_msg or "exceeded your current quota" in error_msg or "rate limit" in error_msg.lower():
                logger.warning("openai_rate_limit_exceeded", filename=filename)
                rag_detail = "OpenAI API rate limit exceeded. Text extraction worked, but Q&A features may be limited."
        
        if not ocr_doc_key:
            logger.error("ocr_doc_key_missing", ocr_response=ocr_process_result)
            raise HTTPException(status_code=500, detail="Process response missing 'ocr_doc_key'.")

        # Extract data from the inline response, but stay compatible with older
        # nested cache-shaped payloads so the frontend keeps working across
        # backend transition states.
        display_text = (
            ocr_process_result.get("text")
            or ocr_process_result.get("full_text")
            or ocr_process_result.get("cached_ocr_result", {}).get("result", {}).get("full_text")
            or ocr_process_result.get("result", {}).get("full_text")
            or "Text not found in OCR output."
        )
        layout_elements = (
            ocr_process_result.get("layout_elements")
            or ocr_process_result.get("cached_ocr_result", {}).get("result", {}).get("layout_elements", [])
            or ocr_process_result.get("result", {}).get("layout_elements", [])
        )

        if (
            display_text == "Text not found in OCR output."
            and ocr_doc_key
            and hasattr(http_client, "get")
        ):
            try:
                cached_url = f"{OCR_SERVICE_URL.rstrip('/')}/cached_ocr_data/{ocr_doc_key}"
                cached_response = await http_client.get(cached_url)
                if cached_response.status_code == 200:
                    cached_payload = cached_response.json()
                    cached_result = cached_payload.get("cached_ocr_result", {}).get("result", {})
                    display_text = cached_result.get("full_text", display_text)
                    layout_elements = cached_result.get("layout_elements", layout_elements)
            except Exception as cache_error:
                logger.warning(
                    "cached_ocr_fallback_failed",
                    filename=filename,
                    doc_key=ocr_doc_key,
                    error=str(cache_error),
                )
        
        # Group layout elements by ID to create sections
        sections = {}
        for element in layout_elements:
            element_id = element.get('id', 'unknown')
            sections[element_id] = element.get('text', '')
        
        logger.info("document_upload_data_prepared_for_frontend", filename=filename, doc_key=ocr_doc_key)
        
        return {
            "message": f"OCR processing for '{filename}' complete. RAG Ingestion: {rag_status} - {rag_detail}",
            "filename": filename,
            "doc_key": ocr_doc_key,
            "text": display_text,
            "layout_elements": layout_elements,
            "sections": sections,
            "metadata": ocr_process_result.get("metadata")
            or ocr_process_result.get("result", {}).get("metadata", {}),
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

# Document list endpoint for mobile app
@app.get("/documents")
async def get_documents():
    """List available documents for the mobile app."""
    # For now, return sample documents (same as src/app/main.py test endpoint)
    return {
        "documents": [
            {
                "id": "doc123",
                "filename": "policy_document.pdf",
                "size": 1258000,
                "upload_date": "2023-05-25T14:22:30Z",
                "status": "completed",
                "document_type": "health_insurance",
                "insurer": "Niva Bupa",
                "processing_completed_at": "2023-05-25T14:25:45Z"
            },
            {
                "id": "doc124",
                "filename": "auto_insurance.pdf",
                "size": 983000,
                "upload_date": "2023-05-26T09:10:15Z",
                "status": "processing",
                "document_type": "auto_insurance",
                "insurer": "Progressive" 
            }
        ],
        "total": 2,
        "page": 1,
        "limit": 10,
        "total_pages": 1
    }

# Ensure all necessary imports are at the top, like Request for home(request: Request)
# Ensure structlog is configured if used.
# Uvicorn run block for direct execution (if __name__ == '__main__') can be added if needed for local dev. 
