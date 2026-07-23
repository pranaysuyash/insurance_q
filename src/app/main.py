from src.utils.native_runtime import configure_native_library_paths
from src.utils.runtime_config import normalize_supabase_environment

configure_native_library_paths()
normalize_supabase_environment()

from fastapi import Depends, FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field
from src.api.user import router as user_router, get_current_user
from src.api.analytics import router as analytics_router
from src.api.consent import router as consent_router
from src.api.subscription import router as subscription_router
from src.api.evidence import router as evidence_router
from src.models.user import User
from src.api.document import (
    router as document_router,
    recover_interrupted_document_processing,
    set_processing_service,
    set_job_outbox_service,
    document_object_store,
    document_repository,
)
from src.utils.runtime_access import require_nonproduction
from src.utils.runtime_config import allowed_cors_origins, production_configuration_errors
from src.utils.upload_validation import MAX_UPLOAD_BYTES, UploadValidationError, validate_upload_content
from src.services.qa_usage_service import QaUsageService, production_qa_usage_enabled

# Import RAG components and enhanced document processing
from typing import Dict, Any, List, Optional, Union, AsyncGenerator
import sys
import logging
import os
import asyncio
from uuid import UUID, uuid4
from contextlib import asynccontextmanager

# Set up logging
logger = logging.getLogger(__name__)
logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper())

app = FastAPI(title="Insurance Policy Parser & QA API", version="2.0.0")

# CORS setup — restrict origins in production, allow all in development.
# allow_origins=["*"] with allow_credentials=True is a browser-rejected
# combination and a security anti-pattern in production.
_cors_env = os.environ.get("ENVIRONMENT", "development")
_allowed_origins = allowed_cors_origins(
    _cors_env, os.environ.get("ALLOWED_ORIGINS", "")
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=_cors_env != "production",  # can't use creds with wildcard
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
rag_pipeline = None
document_processing_service = None
qa_usage_service: QaUsageService | None = None

# Health-check embedding probe cache (avoids calling OpenAI on every poll)
_last_embedding_probe = 0.0
_embedding_probe_result = None

# Models for the root query endpoint
class QueryRequest(BaseModel):
    query: str
    filters: Optional[Dict[str, Any]] = None
    _cache_buster: Optional[Union[int, str]] = None
    request_id: Optional[UUID] = None

class QueryResponse(BaseModel):
    answer: str
    # Keep accepting legacy string sources while allowing the canonical
    # mobile client to receive page/document navigation metadata.
    sources: List[Union[str, Dict[str, Any]]] = Field(default_factory=list)
    confidence: Optional[float] = None
    citations: List[Dict[str, Any]] = Field(default_factory=list)
    missing_information: List[str] = Field(default_factory=list)
    follow_up_questions: List[str] = Field(default_factory=list)
    retrieval_confidence: Optional[float] = None
    retrieval_strategy: Optional[str] = None
    embedding_model_used: Optional[str] = None
    error: Optional[str] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global rag_pipeline, document_processing_service, qa_usage_service

    is_production = os.environ.get("ENVIRONMENT", "development").lower() == "production"
    configuration_errors = production_configuration_errors(os.environ)
    if configuration_errors:
        raise RuntimeError("Invalid production configuration: " + "; ".join(configuration_errors))

    if production_qa_usage_enabled():
        try:
            qa_usage_service = QaUsageService.from_env()
            app.state.qa_usage_service = qa_usage_service
            logger.info("server Q&A usage ledger configured")
        except Exception as error:
            qa_usage_service = None
            raise RuntimeError("Production Q&A usage ledger initialization failed") from error

    # Durable document processing is mandatory in production. Development may
    # use the legacy in-process compatibility path when Supabase is absent.
    job_outbox_service = None
    try:
        from src.services.job_outbox_service import JobOutboxService
        job_outbox_service = JobOutboxService.from_env()
        set_job_outbox_service(job_outbox_service)
        logger.info("durable job outbox configured")
    except Exception as error:
        set_job_outbox_service(None)
        if is_production:
            raise RuntimeError("Production durable job outbox initialization failed") from error
        logger.warning("durable job outbox unavailable in development error_type=%s", type(error).__name__)

    # SQLite anti-abuse tables are a development compatibility adapter only.
    # Production rate limits use Supabase RPCs and must not create local
    # durable state during startup.
    if not is_production:
        try:
            from src.utils.database_migration import create_anti_abuse_tables, add_analytics_indexes
            create_anti_abuse_tables()
            add_analytics_indexes()
            logger.info("✅ Development anti-abuse tables initialized")
        except Exception as e:
            logger.error("anti_abuse_initialization_failed error_type=%s", type(e).__name__)
            print("⚠️ Anti-abuse initialization failed; continuing only in development", file=sys.stderr)
    else:
        logger.info("Production anti-abuse uses canonical Supabase rate-limit RPCs")
    
    # Anonymous bearer identity is the launch auth mode. Firebase remains an
    # optional historical integration and is not initialized in the core path.
    
    # Initialize RAG pipeline
    try:
        from src.rag.pipeline import RAGPipeline
        rag_pipeline = RAGPipeline()
        logger.info("✅ RAG pipeline initialized successfully")
    except Exception as e:
        logger.error("rag_initialization_failed error_type=%s", type(e).__name__)
        if is_production:
            raise RuntimeError("Production RAG initialization failed") from e
        print("⚠️ RAG pipeline init failed; continuing only in development", file=sys.stderr)
    
    # Initialize enhanced document processing service
    try:
        from src.services.document_processing_service import DocumentProcessingService
        document_processing_service = DocumentProcessingService(
            rag_pipeline=rag_pipeline,
            document_object_store=document_object_store,
            document_repository=document_repository,
            job_outbox_service=job_outbox_service,
        )
        logger.info("✅ Enhanced document processing service initialized successfully")
        
        # Configure the document API to use the processing service
        set_processing_service(document_processing_service)
        
        # Store in app state for access by other components
        app.state.document_processing_service = document_processing_service
        app.state.rag_pipeline = rag_pipeline
        
    except Exception as e:
        logger.exception("document_processing_initialization_failed error_type=%s", type(e).__name__)
        if is_production:
            raise RuntimeError("Production document processing initialization failed") from e
        print("⚠️ Document processing init failed; continuing only in development", file=sys.stderr)
    
    # Production recovery belongs exclusively to the durable outbox worker.
    # The API must not scan and execute received documents in-process, or it
    # becomes a second worker outside queue retry/dead-letter observability.
    # Development retains the repository-lease compatibility scan.
    if document_processing_service and not is_production:
        loop = asyncio.get_event_loop()
        loop.create_task(_recover_durable_document_processing())
        # Legacy disk scanning is strictly local-development compatibility.
        if os.environ.get("ENVIRONMENT", "development").lower() != "production":
            loop.create_task(_background_doc_processing())

    try:
        yield
    finally:
        pass


app.router.lifespan_context = lifespan


async def _recover_durable_document_processing() -> None:
    """Run startup recovery with an auditable outcome, never silently."""
    try:
        recovered = await recover_interrupted_document_processing()
        logger.info("document_processing_recovery_completed recovered=%s", recovered)
    except Exception as error:
        logger.exception(
            "document_processing_recovery_failed error_type=%s",
            type(error).__name__,
        )


async def _background_doc_processing():
    """Run document processing in background so startup doesn't block."""
    try:
        await process_existing_documents()
    except Exception as e:
        logger.warning("Background doc processing failed: %s", e)

async def process_existing_documents():
    """Process any existing documents in storage that haven't been processed yet"""
    try:
        import os
        from pathlib import Path

        if os.getenv("ENVIRONMENT", "development").lower() == "production":
            logger.info("Skipping legacy local-document startup scan in production")
            return
        
        storage_dir = "storage/documents"
        if not os.path.exists(storage_dir):
            logger.info("No storage directory found, skipping existing document processing")
            return
        
        # Get all text files in storage directory
        document_files = list(Path(storage_dir).glob("*.txt"))
        if not document_files:
            logger.info("No existing documents found to process")
            return
        
        logger.info(f"Found {len(document_files)} existing documents to process")
        
        # Check if documents are already indexed by testing a query
        try:
            test_result = await document_processing_service.query_documents(
                query="health insurance coverage",
                filters=None
            )
        except Exception as e:
            # Skip startup processing if API calls fail (e.g. quota exhausted)
            logger.warning("Startup query check failed (%s), skipping startup processing", e)
            return
        
        # If we get meaningful results, documents are already processed
        if (test_result.get("result", {}).get("sources") and 
            len(test_result["result"]["sources"]) > 0 and
            "test insurance document" not in str(test_result["result"]["sources"][0]).lower()):
            logger.info("Documents appear to already be processed and indexed")
            return
        
        logger.info("Processing existing documents through RAG pipeline...")
        processed_count = 0
        
        for file_path in document_files:
            try:
                # Skip files that look like they were already processed (have UUID prefixes)
                if len(file_path.stem.split('_')[0]) == 36:  # UUID length
                    continue
                    
                logger.info(f"Processing existing document: {file_path.name}")
                
                # Read file content
                with open(file_path, 'rb') as f:
                    file_content = f.read()
                
                # Process through the same pipeline as uploads
                result = await document_processing_service.process_document_full(
                    file_content=file_content,
                    filename=file_path.name,
                    processing_mode="full"
                )
                
                if result.get("status") == "completed":
                    logger.info(f"✅ Successfully processed existing document: {file_path.name}")
                    processed_count += 1
                else:
                    logger.warning(f"⚠️ Failed to process {file_path.name}: {result}")
                    
            except Exception as e:
                logger.error(f"❌ Error processing {file_path.name}: {str(e)}")
        
        if processed_count > 0:
            logger.info(f"🎯 Startup document processing complete! Processed {processed_count} documents")
            
            # Test query after processing
            test_result = await document_processing_service.query_documents(
                query="What is covered under health insurance?",
                filters=None
            )
            
            if test_result.get("result", {}).get("sources"):
                logger.info("✅ Documents are now available for queries")
            else:
                logger.warning("⚠️ Documents processed but may not be properly indexed")
        else:
            logger.info("No new documents were processed")
            
    except Exception as e:
        logger.error(f"❌ Error during startup document processing: {str(e)}")

app.include_router(user_router)
app.include_router(document_router)
app.include_router(analytics_router)
app.include_router(evidence_router)
app.include_router(consent_router)
app.include_router(subscription_router)

@app.get("/healthz")
async def liveness_check():
    """Cheap process liveness probe for Cloud Run—never calls external APIs."""
    return {"status": "live", "version": "2.0.0"}


@app.get("/readyz")
async def readiness_check():
    """Admit traffic only after the integrated processing path is initialized."""
    ready = rag_pipeline is not None and document_processing_service is not None
    return JSONResponse(
        status_code=200 if ready else 503,
        content={
            "status": "ready" if ready else "not_ready",
            "rag": "available" if rag_pipeline else "unavailable",
            "document_processing": "available" if document_processing_service else "unavailable",
        },
    )

@app.get("/health")
async def health_check():
    """Health check endpoint with real service reachability.

    Reports 'degraded' (HTTP 503) when the RAG pipeline exists but embedding
    generation is failing — so App Runner can drain a broken instance instead
    of routing traffic to a service that 401s on every query. The embedding
    probe is cached for 60s to avoid hammering OpenAI on every health check.
    """
    import time
    from src.ocr.capability_registry import capability_registry_snapshot

    global _last_embedding_probe, _embedding_probe_result

    doc_processing_status = "available" if document_processing_service else "unavailable"

    if not rag_pipeline:
        return JSONResponse(
            status_code=503,
            content={
                "status": "unavailable",
                "rag_status": "unavailable",
                "document_processing_status": doc_processing_status,
                "version": "2.0.0",
                "detail": "RAG pipeline not initialized",
                "document_capabilities": capability_registry_snapshot(),
            },
        )

    # Cached probe: avoid calling OpenAI on every health check (App Runner
    # polls frequently). Refresh every 60 seconds.
    now = time.time()
    if _embedding_probe_result is None or (now - _last_embedding_probe) > 60:
        _last_embedding_probe = now
        try:
            await rag_pipeline._generate_embeddings_with_fallback(["health"])
            _embedding_probe_result = "ok"
        except Exception as e:
            logger.warning("Health check embedding probe failed: %s", e)
            _embedding_probe_result = f"failed: {e}"

    rag_status = "available" if _embedding_probe_result == "ok" else "degraded"
    overall = "ok" if rag_status == "available" else "degraded"
    status_code = 200 if overall == "ok" else 503

    return JSONResponse(
        status_code=status_code,
        content={
            "status": overall,
            "rag_status": rag_status,
            "embedding_probe": _embedding_probe_result,
            "document_processing_status": doc_processing_status,
            "version": "2.0.0",
            "document_capabilities": capability_registry_snapshot(),
        },
    )

@app.post("/query")
async def query_documents(request: QueryRequest, current_user: User = Depends(get_current_user)):
    """
    Root-level query endpoint that mobile app expects.
    Now uses the integrated document processing service with actual RAG.
    """
    qa_reservation = None

    def release_qa_reservation() -> None:
        nonlocal qa_reservation
        if qa_reservation is None:
            return
        service, owner_id, request_id = qa_reservation
        try:
            service.release(owner_id=owner_id, request_id=request_id)
        except Exception as error:
            logger.error(
                "qa_usage_release_failed error_type=%s", type(error).__name__
            )
        finally:
            qa_reservation = None

    def finalize_qa_reservation() -> bool:
        nonlocal qa_reservation
        if qa_reservation is None:
            return True
        service, owner_id, request_id = qa_reservation
        try:
            service.finalize(owner_id=owner_id, request_id=request_id)
            qa_reservation = None
            return True
        except Exception as error:
            logger.error(
                "qa_usage_finalize_failed error_type=%s", type(error).__name__
            )
            release_qa_reservation()
            return False

    try:
        if qa_usage_service is not None:
            request_id = request.request_id or uuid4()
            try:
                usage = qa_usage_service.reserve(
                    owner_id=current_user.uid,
                    request_id=request_id,
                )
            except Exception as error:
                logger.error("qa_usage_reservation_failed error_type=%s", type(error).__name__)
                return QueryResponse(
                    answer="",
                    sources=[],
                    error="qa_usage_unavailable",
                )
            if not bool(usage.get("allowed")):
                logger.info(
                    "qa_question_blocked owner=%s reason=%s",
                    current_user.uid[:12],
                    usage.get("reason", "qa_budget_exhausted"),
                )
                return QueryResponse(
                    answer="",
                    sources=[],
                    error="qa_budget_exhausted",
                )
            qa_reservation = (qa_usage_service, current_user.uid, request_id)

        logger.info(
            "document_query_received owner=%s query_length=%s has_document_filter=%s",
            current_user.uid[:12],
            len(request.query),
            bool(request.filters and (request.filters.get("document_id") or request.filters.get("document_ids"))),
        )
        
        if not document_processing_service:
            release_qa_reservation()
            return QueryResponse(
                answer="I'm sorry, but the document processing system is currently unavailable. Please try again later or contact support.",
                sources=[],
                error="Document processing service not initialized"
            )
        
        # Normalize filters: mobile sends document_id (singular), backend expects document_ids (plural list)
        filters = dict(request.filters) if request.filters else {}
        if filters and "document_id" in filters and "document_ids" not in filters:
            doc_id = filters.pop("document_id")
            if doc_id:
                filters["document_ids"] = [doc_id] if isinstance(doc_id, str) else doc_id
        # Owner scope is derived exclusively from the verified bearer token.
        # Never accept a client-supplied owner filter.
        filters["owner_id"] = current_user.uid

        # Use the document processing service to query
        result = await document_processing_service.query_documents(
            query=request.query,
            filters=filters
        )
        
        # Handle the response format
        if isinstance(result, dict):
            if result.get("status") == "error":
                release_qa_reservation()
                return QueryResponse(
                    answer="I encountered an error while processing your question. Please try rephrasing your question or try again later.",
                    sources=[],
                    error=result.get("error", "Unknown error")
                )
            
            # Extract answer and sources from the result
            if "result" in result:
                inner_result = result["result"]
                answer = inner_result.get("answer", "I couldn't find a specific answer to your question.")
                sources = inner_result.get("sources", [])
                confidence = inner_result.get("confidence")
                citations = inner_result.get("citations", [])
                missing_information = inner_result.get("missing_information", [])
                follow_up_questions = inner_result.get("follow_up_questions", [])
                retrieval_confidence = inner_result.get("retrieval_confidence")
                retrieval_strategy = inner_result.get("retrieval_strategy")
                embedding_model_used = inner_result.get("embedding_model_used")
            else:
                answer = result.get("answer", "I couldn't find a specific answer to your question.")
                sources = result.get("sources", [])
                confidence = result.get("confidence")
                citations = result.get("citations", [])
                missing_information = result.get("missing_information", [])
                follow_up_questions = result.get("follow_up_questions", [])
                retrieval_confidence = result.get("retrieval_confidence")
                retrieval_strategy = result.get("retrieval_strategy")
                embedding_model_used = result.get("embedding_model_used")
            
            # Format sources for mobile app. Preserve only customer-safe
            # navigation/relevance metadata; immutable source text remains an
            # internal verifier input and is not duplicated into the API
            # response.
            formatted_sources = []
            if isinstance(sources, list):
                for source in sources:
                    if isinstance(source, dict):
                        if "text" in source:
                            formatted_sources.append({
                                key: source.get(key)
                                for key in (
                                    "index", "id", "document_id", "filename",
                                    "page_number", "page_artifact_id", "section",
                                    "section_type", "bbox", "text",
                                )
                                if key in source
                            })
                        elif "content" in source:
                            formatted_sources.append({"text": source["content"]})
                        elif "source_text" in source:
                            formatted_sources.append({"text": source["source_text"]})
                        else:
                            formatted_sources.append({"text": str(source)})
                    else:
                        formatted_sources.append(str(source))
            
            if not finalize_qa_reservation():
                return QueryResponse(
                    answer="",
                    sources=[],
                    error="qa_usage_unavailable",
                )
            return QueryResponse(
                answer=answer,
                sources=formatted_sources,
                confidence=confidence
                if confidence is not None
                else None,
                citations=citations,
                missing_information=missing_information,
                follow_up_questions=follow_up_questions,
                retrieval_confidence=retrieval_confidence,
                retrieval_strategy=retrieval_strategy,
                embedding_model_used=embedding_model_used,
            )
        
        # Fallback if result format is unexpected
        release_qa_reservation()
        return QueryResponse(
            answer="I received your question but couldn't process it in the expected format. Please try again.",
            sources=[],
            error="Unexpected response format from document processing service"
        )
        
    except Exception as e:
        release_qa_reservation()
        logger.error("document_query_failed error_type=%s", type(e).__name__)
        return QueryResponse(
            answer="I encountered an unexpected error while processing your question. Please try again later.",
            sources=[],
            error="Document query failed"
        )

@app.post("/query/stream")
async def query_documents_stream(request: QueryRequest, current_user: User = Depends(get_current_user)):
    """
    Streaming query endpoint for real-time token-by-token responses.
    Uses Server-Sent Events (SSE) format.
    """
    qa_reservation = None

    def release_qa_reservation() -> None:
        nonlocal qa_reservation
        if qa_reservation is None:
            return
        service, owner_id, request_id = qa_reservation
        try:
            service.release(owner_id=owner_id, request_id=request_id)
        except Exception as error:
            logger.error("qa_usage_release_failed error_type=%s", type(error).__name__)
        finally:
            qa_reservation = None

    def finalize_qa_reservation() -> bool:
        nonlocal qa_reservation
        if qa_reservation is None:
            return True
        service, owner_id, request_id = qa_reservation
        try:
            service.finalize(owner_id=owner_id, request_id=request_id)
            qa_reservation = None
            return True
        except Exception as error:
            logger.error("qa_usage_finalize_failed error_type=%s", type(error).__name__)
            release_qa_reservation()
            return False

    try:
        if qa_usage_service is not None:
            request_id = request.request_id or uuid4()
            try:
                usage = qa_usage_service.reserve(
                    owner_id=current_user.uid,
                    request_id=request_id,
                )
            except Exception as error:
                logger.error("qa_usage_reservation_failed error_type=%s", type(error).__name__)
                return StreamingResponse(
                    iter([f"data: {{\"error\": \"qa_usage_unavailable\"}}\n\n"]),
                    media_type="text/event-stream",
                )
            if not bool(usage.get("allowed")):
                logger.info(
                    "qa_question_blocked owner=%s reason=%s",
                    current_user.uid[:12],
                    usage.get("reason", "qa_budget_exhausted"),
                )
                return StreamingResponse(
                    iter([f"data: {{\"error\": \"qa_budget_exhausted\"}}\n\n"]),
                    media_type="text/event-stream",
                )
            qa_reservation = (qa_usage_service, current_user.uid, request_id)

        logger.info(
            "document_query_stream_received owner=%s query_length=%s has_document_filter=%s",
            current_user.uid[:12],
            len(request.query),
            bool(request.filters and (request.filters.get("document_id") or request.filters.get("document_ids"))),
        )

        if not document_processing_service:
            release_qa_reservation()
            return StreamingResponse(
                iter([f"data: {{\"error\": \"Document processing service not initialized\"}}\n\n"]),
                media_type="text/event-stream",
            )

        # Normalize filters
        filters = dict(request.filters) if request.filters else {}
        if filters and "document_id" in filters and "document_ids" not in filters:
            doc_id = filters.pop("document_id")
            if doc_id:
                filters["document_ids"] = [doc_id] if isinstance(doc_id, str) else doc_id
        filters["owner_id"] = current_user.uid

        # Create streaming generator
        async def generate_stream():
            try:
                # Stream the answer from the RAG pipeline
                async for token in document_processing_service.query_documents_stream(
                    query=request.query,
                    filters=filters
                ):
                    yield f"data: {token}\n\n"
            except Exception as e:
                logger.error("stream_query_failed error_type=%s", type(e).__name__)
                yield f"data: {{\"error\": \"Stream failed\"}}\n\n"
            finally:
                finalize_qa_reservation()

        return StreamingResponse(
            generate_stream(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
            },
        )

    except Exception as e:
        release_qa_reservation()
        logger.error("document_query_stream_failed error_type=%s", type(e).__name__)
        return StreamingResponse(
            iter([f"data: {{\"error\": \"Document query failed\"}}\n\n"]),
            media_type="text/event-stream",
        )

@app.post("/process-and-ingest")
async def process_and_ingest(
    file: UploadFile = File(...), _: None = Depends(require_nonproduction)
):
    """
    Synchronous document processing endpoint.
    Replaces the standalone OCR service's /process_and_ingest.
    Processes the document inline and returns OCR text + layout + metadata.
    """
    if not document_processing_service:
        raise HTTPException(status_code=503, detail="Document processing service not available")

    try:
        content = await file.read(MAX_UPLOAD_BYTES + 1)
        filename = file.filename or "document"

        try:
            validate_upload_content(filename, content)
        except UploadValidationError as error:
            raise HTTPException(
                status_code=422,
                detail={"code": error.code, "message": error.message},
            ) from error

        result = await document_processing_service.process_document_full(
            file_content=content,
            filename=filename,
            processing_mode="full",
        )

        ocr_stage = result.get("stages", {}).get("ocr", {})
        full_text = ocr_stage.get("full_text", "")
        layout = ocr_stage.get("layout_elements", [])

        return {
            "message": f"Document processed: {filename}",
            "filename": filename,
            "ocr_doc_key": result.get("document_id", ""),
            "rag_ingestion_status": "success" if result.get("status") == "completed" else "failed",
            "rag_ingestion_detail": f"Points: {result.get('points_added', 0)}",
            "text": full_text,
            "layout_elements": layout,
            "ocr_metadata": ocr_stage.get("metadata", {}),
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error("process-and-ingest failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# Additional endpoints for monitoring and debugging
@app.get("/processing/status")
async def get_processing_status(_: None = Depends(require_nonproduction)):
    """Get overall processing status"""
    if not document_processing_service:
        return {"error": "Document processing service not available"}
    
    try:
        all_status = document_processing_service.get_all_processing_status()
        return {
            "status": "success",
            "active_processing_jobs": len(all_status),
            "jobs": all_status
        }
    except Exception as e:
        logger.error(f"Error getting processing status: {e}")
        return {"error": str(e)}

@app.get("/rag/stats")
async def get_rag_stats(_: None = Depends(require_nonproduction)):
    """Get RAG system statistics"""
    if not rag_pipeline:
        return {"error": "RAG pipeline not available"}
    
    try:
        stats = await rag_pipeline.get_embedding_stats()
        return {"status": "success", "stats": stats}
    except Exception as e:
        logger.error(f"Error getting RAG stats: {e}")
        return {"error": str(e)}

# Debug endpoints for development
@app.get("/debug/services")
async def debug_services(_: None = Depends(require_nonproduction)):
    """Debug endpoint to check service initialization status"""
    return {
        "rag_pipeline": "initialized" if rag_pipeline else "not initialized",
        "document_processing_service": "initialized" if document_processing_service else "not initialized",
        "app_state_rag": "available" if hasattr(app.state, 'rag_pipeline') else "not available",
        "app_state_doc_service": "available" if hasattr(app.state, 'document_processing_service') else "not available"
    }

@app.post("/debug/test-processing")
async def test_processing(_: None = Depends(require_nonproduction)):
    """Test endpoint to verify processing pipeline"""
    if not document_processing_service:
        return {"error": "Document processing service not available"}
    
    # Test with dummy content
    test_content = b"This is a test insurance document. Policy number: TEST123. Coverage: Health Insurance."
    
    try:
        result = await document_processing_service.process_document_full(
            file_content=test_content,
            filename="test.txt",
            processing_mode="full"
        )
        return {"status": "success", "result": result}
    except Exception as e:
        return {"error": str(e)}


# Keep the public marketing surface in the same Cloud Run process. API routes
# above take precedence; the mounted app supplies the public site and assets.
from src.frontend.app import app as marketing_app
app.mount("/", marketing_app)
