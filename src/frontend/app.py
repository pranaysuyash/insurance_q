"""
Frontend service for the Insurance Policy Parser & QA App.
"""
from contextlib import asynccontextmanager
from datetime import date
from hashlib import sha256
from pathlib import Path
from fastapi import Depends, FastAPI, HTTPException, UploadFile, File, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, PlainTextResponse, Response, FileResponse
import os
import httpx
from typing import Optional
from pydantic import BaseModel
import structlog
import time
from src.utils.log_config import configure_structlog
from src.utils.runtime_access import require_nonproduction
from src.utils.upload_validation import MAX_UPLOAD_BYTES, UploadValidationError, validate_upload_content
from tools.validate_legal_release_assets import validation_errors as legal_release_errors

# Configure structured logging via the shared config (JSON output).
_environment = os.environ.get("ENVIRONMENT", "development").lower()
configure_structlog(service_name="frontend", environment=_environment)
logger = structlog.get_logger()

class Query(BaseModel):
    query: str

SITE_NAME = "CoverWise"
DEFAULT_LAUNCH_WINDOW = os.getenv("LAUNCH_WINDOW", "late July 2026")
INTERACTIVE_DEMO_ENABLED = os.getenv("ENVIRONMENT", "development").lower() != "production"
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
LEGAL_DOCUMENTS = {
    "privacy": ("Privacy Policy", REPOSITORY_ROOT / "docs/legal/privacy_policy.md"),
    "terms": ("Terms of Service", REPOSITORY_ROOT / "docs/legal/terms_of_service.md"),
}

app = FastAPI(
    title="CoverWise | Insurance Policy Frontend",
    description="CoverWise turns insurance policy PDFs into plain-language summaries and grounded answers.",
    version="2.0.0"
)

# CORS middleware — restrict to the configured public site URL in production.
# This service is mounted as a sub-app under the main API (src/app/main.py)
# which already handles CORS at the top level. The wildcard + credentials
# combination here was a security anti-pattern (CSO Finding #2).
_frontend_env = os.getenv("ENVIRONMENT", "development")
_frontend_public_url = os.getenv("PUBLIC_SITE_URL", "").strip()
if _frontend_env == "production" and _frontend_public_url:
    _frontend_origins = [_frontend_public_url]
else:
    _frontend_origins = ["http://localhost:8080", "http://127.0.0.1:8080"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_frontend_origins,
    allow_credentials=_frontend_env != "production",
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
app.mount("/static", StaticFiles(directory="src/frontend/static"), name="static")

# Templates setup
templates = Jinja2Templates(directory="src/frontend/templates")

# Service URLs from environment variables
INTERNAL_SERVICE_URL = os.getenv("INTERNAL_SERVICE_URL", "http://127.0.0.1:8080")
OCR_SERVICE_URL = os.getenv("OCR_SERVICE_URL", INTERNAL_SERVICE_URL)
RAG_SERVICE_URL = os.getenv("RAG_SERVICE_URL", INTERNAL_SERVICE_URL)

# HTTP client (managed by lifespan events)
http_client: Optional[httpx.AsyncClient] = None


def _require_complete_legal_assets_for_production() -> None:
    """Block a public production process when its legal source is incomplete."""
    if os.getenv("ENVIRONMENT", "development").lower() != "production":
        return

    errors = legal_release_errors()
    if errors:
        logger.error("production_legal_release_blocked", error_count=len(errors))
        raise RuntimeError(
            "Refusing to start the public frontend with incomplete legal assets: "
            + "; ".join(errors)
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialise Sentry error tracking before any service initialisation so
    # startup failures are captured. Silently skipped when SENTRY_DSN is empty.
    from src.utils.sentry_config import init_sentry, shutdown_sentry
    init_sentry(service_name="frontend")

    global http_client
    _require_complete_legal_assets_for_production()
    http_client = httpx.AsyncClient(timeout=None)
    logger.info("Frontend service started up, httpx.AsyncClient initialized.")
    try:
        yield
    finally:
        shutdown_sentry()
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
        request=request,
        name="index.html",
        context={
            "request": request,
            "site_url": site_url,
            "site_name": SITE_NAME,
            "page_title": "CoverWise | Understand your insurance policy in plain language",
            "page_description": (
                "CoverWise reads insurance policy PDFs, surfaces coverage, exclusions, waiting periods, and claim details, then answers grounded questions."
            ),
            "launch_window": DEFAULT_LAUNCH_WINDOW,
            "current_year": date.today().year,
            "interactive_demo_enabled": INTERACTIVE_DEMO_ENABLED,
        }
    )


def _render_legal_document(request: Request, document_key: str) -> HTMLResponse:
    """Render the approved-source candidate verbatim without duplicating copy.

    The production startup guard validates these same files before serving the
    public frontend. Rendering the Markdown as escaped, pre-wrapped text keeps
    every legal character intact and avoids a second, lossy document format.
    """
    page_title, document_path = LEGAL_DOCUMENTS[document_key]
    try:
        document_text = document_path.read_text(encoding="utf-8")
    except OSError as error:
        logger.error("legal_document_unavailable", document=document_key)
        raise HTTPException(
            status_code=503,
            detail="The requested legal document is temporarily unavailable.",
        ) from error

    document_hash = sha256(document_text.encode("utf-8")).hexdigest()
    return templates.TemplateResponse(
        request=request,
        name="legal_document.html",
        context={
            "request": request,
            "site_name": SITE_NAME,
            "page_title": page_title,
            "legal_document": document_text,
            "legal_document_sha256": document_hash,
        },
        headers={
            "Cache-Control": "no-store",
            "Content-Security-Policy": (
                "default-src 'self'; base-uri 'none'; form-action 'none'; "
                "frame-ancestors 'none'; style-src 'unsafe-inline'"
            ),
            "Referrer-Policy": "no-referrer",
            "X-Content-Type-Options": "nosniff",
            "X-CoverWise-Legal-SHA256": document_hash,
        },
    )


@app.get("/privacy", response_class=HTMLResponse, include_in_schema=False)
async def privacy_policy(request: Request):
    return _render_legal_document(request, "privacy")


@app.get("/terms", response_class=HTMLResponse, include_in_schema=False)
async def terms_of_service(request: Request):
    return _render_legal_document(request, "terms")


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
  <url>
    <loc>{site_url}/privacy</loc>
    <lastmod>{today}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.3</priority>
  </url>
  <url>
    <loc>{site_url}/terms</loc>
    <lastmod>{today}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.3</priority>
  </url>
</urlset>
"""
    return Response(content=xml, media_type="application/xml")


@app.api_route("/favicon.ico", methods=["GET", "HEAD"], include_in_schema=False)
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
async def upload_document(
    file: UploadFile = File(...), _: None = Depends(require_nonproduction)
):
    """Upload document to OCR service, get processed data, and display relevant parts."""
    if not http_client: # Should be initialized by lifespan
        raise HTTPException(status_code=503, detail="HTTP client not available.")
    
    try:
        filename = file.filename
        logger.info("document_upload_started", filename=filename)
        
        content = await file.read(MAX_UPLOAD_BYTES + 1)
        try:
            validate_upload_content(filename, content)
        except UploadValidationError as error:
            raise HTTPException(
                status_code=422,
                detail={"code": error.code, "message": error.message},
            ) from error
        
        # Call main app's /process-and-ingest (replaces standalone OCR service)
        files_for_ocr = {"file": (filename, content, file.content_type)}
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
async def query_document(query: Query, _: None = Depends(require_nonproduction)):
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
async def get_documents(_: None = Depends(require_nonproduction)):
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

@app.get("/ops", response_class=HTMLResponse, include_in_schema=False)
@app.get("/ops/", response_class=HTMLResponse, include_in_schema=False)
async def ops_index(request: Request):
    """Render the admin/operator landing page with links to all monitoring
    and debugging tools.

    Lists the analytics dashboard, Prometheus metrics, health probes, and
    debug endpoints in one place for easier access.
    """
    return templates.TemplateResponse(
        request=request,
        name="ops_index.html",
        context={
            "request": request,
            "site_name": SITE_NAME,
            "page_title": "CoverWise Admin Tools",
            "current_year": date.today().year,
        },
    )


@app.get("/ops/dashboard", response_class=HTMLResponse, include_in_schema=False)
async def operator_dashboard(request: Request):
    """Render the operator analytics dashboard.

    A self-contained HTML dashboard that queries the /analytics/* endpoints
    via client-side JavaScript. The operator must provide an
    X-Operator-Token, which is entered on the page and sent with each
    request. No server-side proxy — data flows directly browser → API.

    Linked from the /ops admin landing page.
    """
    return templates.TemplateResponse(
        request=request,
        name="ops_dashboard.html",
        context={
            "request": request,
            "site_name": SITE_NAME,
            "page_title": "CoverWise Operator Dashboard",
            "current_year": date.today().year,
        },
    )


# Ensure all necessary imports are at the top, like Request for home(request: Request)
# Ensure structlog is configured if used.
# Uvicorn run block for direct execution (if __name__ == '__main__') can be added if needed for local dev. 
