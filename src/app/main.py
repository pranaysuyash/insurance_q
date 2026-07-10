from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from src.api.user import router as user_router
from src.api.family import router as family_router
from src.api.policy import router as policy_router
from src.api.document import router as document_router, set_processing_service
from src.utils.firebase_auth import init_firebase

# Import RAG components and enhanced document processing
from typing import Dict, Any, List, Optional, Union
import sys
import logging
import os
import asyncio

# Set up logging
logger = logging.getLogger(__name__)
logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper())

app = FastAPI(title="Insurance Policy Parser & QA API", version="2.0.0")

# CORS setup (allow all for now, restrict in prod)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
rag_pipeline = None
document_processing_service = None

# Models for the root query endpoint
class QueryRequest(BaseModel):
    query: str
    filters: Optional[Dict[str, Any]] = None
    _cache_buster: Optional[Union[int, str]] = None

class QueryResponse(BaseModel):
    answer: str
    sources: List[str] = []
    confidence: Optional[float] = None
    error: Optional[str] = None

@app.on_event("startup")
async def startup_event():
    global rag_pipeline, document_processing_service
    
    # Initialize anti-abuse system
    try:
        from src.utils.database_migration import create_anti_abuse_tables
        create_anti_abuse_tables()
        logger.info("✅ Anti-abuse system initialized successfully")
    except Exception as e:
        logger.error(f"⚠️ Failed to initialize anti-abuse system: {e}")
        print(f"⚠️ Anti-abuse system init failed: {e}", file=sys.stderr)
        print("Continuing without anti-abuse protection...", file=sys.stderr)
    
    try:
        init_firebase()
    except Exception as e:
        print(f"⚠️ Firebase init failed: {e}", file=sys.stderr)
        print("Continuing without Firebase authentication...", file=sys.stderr)
    
    # Initialize RAG pipeline
    try:
        from src.rag.pipeline import RAGPipeline
        rag_pipeline = RAGPipeline()
        logger.info("✅ RAG pipeline initialized successfully")
    except Exception as e:
        logger.error(f"⚠️ Failed to initialize RAG pipeline: {e}")
        print(f"⚠️ RAG pipeline init failed: {e}", file=sys.stderr)
        print("Continuing without RAG functionality...", file=sys.stderr)
    
    # Initialize enhanced document processing service
    try:
        from src.services.document_processing_service import DocumentProcessingService
        document_processing_service = DocumentProcessingService(rag_pipeline=rag_pipeline)
        logger.info("✅ Enhanced document processing service initialized successfully")
        
        # Configure the document API to use the processing service
        set_processing_service(document_processing_service)
        
        # Store in app state for access by other components
        app.state.document_processing_service = document_processing_service
        app.state.rag_pipeline = rag_pipeline
        
    except Exception as e:
        logger.error(f"⚠️ Failed to initialize document processing service: {e}")
        print(f"⚠️ Document processing service init failed: {e}", file=sys.stderr)
        print("Continuing without enhanced document processing...", file=sys.stderr)
    
    # Process any unprocessed documents in background (don't block startup)
    if document_processing_service:
        loop = asyncio.get_event_loop()
        loop.create_task(_background_doc_processing())

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
app.include_router(family_router)
app.include_router(policy_router)
app.include_router(document_router)

@app.get("/health")
def health_check():
    """Health check endpoint with service status"""
    rag_status = "available" if rag_pipeline else "unavailable"
    doc_processing_status = "available" if document_processing_service else "unavailable"
    return {
        "status": "ok",
        "rag_status": rag_status,
        "document_processing_status": doc_processing_status,
        "version": "2.0.0",
        "timestamp": "2025-06-11T08:00:00Z"
    }

@app.post("/query")
async def query_documents(request: QueryRequest):
    """
    Root-level query endpoint that mobile app expects.
    Now uses the integrated document processing service with actual RAG.
    """
    try:
        logger.info(f"Received query: {request.query}")
        logger.info(f"Filters: {request.filters}")
        
        if not document_processing_service:
            return QueryResponse(
                answer="I'm sorry, but the document processing system is currently unavailable. Please try again later or contact support.",
                sources=[],
                error="Document processing service not initialized"
            )
        
        # Normalize filters: mobile sends document_id (singular), backend expects document_ids (plural list)
        filters = request.filters
        if filters and "document_id" in filters and "document_ids" not in filters:
            doc_id = filters.pop("document_id")
            if doc_id:
                filters["document_ids"] = [doc_id] if isinstance(doc_id, str) else doc_id

        # Use the document processing service to query
        result = await document_processing_service.query_documents(
            query=request.query,
            filters=filters
        )
        
        # Handle the response format
        if isinstance(result, dict):
            if result.get("status") == "error":
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
            else:
                answer = result.get("answer", "I couldn't find a specific answer to your question.")
                sources = result.get("sources", [])
                confidence = result.get("confidence")
            
            # Format sources for mobile app
            formatted_sources = []
            if isinstance(sources, list):
                for source in sources:
                    if isinstance(source, dict):
                        if "text" in source:
                            formatted_sources.append(source["text"])
                        elif "content" in source:
                            formatted_sources.append(source["content"])
                        elif "source_text" in source:
                            formatted_sources.append(source["source_text"])
                        else:
                            formatted_sources.append(str(source))
                    else:
                        formatted_sources.append(str(source))
            
            return QueryResponse(
                answer=answer,
                sources=formatted_sources,
                confidence=confidence
            )
        
        # Fallback if result format is unexpected
        return QueryResponse(
            answer="I received your question but couldn't process it in the expected format. Please try again.",
            sources=[],
            error="Unexpected response format from document processing service"
        )
        
    except Exception as e:
        logger.error(f"Error processing query: {e}", exc_info=True)
        return QueryResponse(
            answer="I encountered an unexpected error while processing your question. Please try again later.",
            sources=[],
            error=str(e)
        )

@app.post("/process-and-ingest")
async def process_and_ingest(file: UploadFile = File(...)):
    """
    Synchronous document processing endpoint.
    Replaces the standalone OCR service's /process_and_ingest.
    Processes the document inline and returns OCR text + layout + metadata.
    """
    if not document_processing_service:
        raise HTTPException(status_code=503, detail="Document processing service not available")

    try:
        content = await file.read()
        filename = file.filename or "document"
        file_ext = os.path.splitext(filename.lower())[1]

        allowed = {'.pdf', '.png', '.jpg', '.jpeg', '.tiff', '.tif', '.webp', '.doc', '.docx'}
        if file_ext not in allowed:
            raise HTTPException(status_code=400, detail=f"Unsupported format: {file_ext}")

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


@app.get("/documents")
def get_test_documents():
    """Test endpoint for mobile app to fetch documents without authentication."""
    return {
        "documents": [
            {
                "id": "88d76c91-1484-41d8-93f3-b9c0b08fbd6e",
                "filename": "health_policy_2024.pdf",
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

# Additional endpoints for monitoring and debugging
@app.get("/processing/status")
async def get_processing_status():
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
async def get_rag_stats():
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
async def debug_services():
    """Debug endpoint to check service initialization status"""
    return {
        "rag_pipeline": "initialized" if rag_pipeline else "not initialized",
        "document_processing_service": "initialized" if document_processing_service else "not initialized",
        "app_state_rag": "available" if hasattr(app.state, 'rag_pipeline') else "not available",
        "app_state_doc_service": "available" if hasattr(app.state, 'document_processing_service') else "not available"
    }

@app.post("/debug/test-processing")
async def test_processing():
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
