from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, Query, BackgroundTasks
from src.api.user import get_current_user
from src.models.user import User
from src.models.document import Document
from typing import List, Optional
from datetime import datetime
import os, uuid, shutil
import logging

# Import the document processing service
try:
    from src.services.document_processing_service import DocumentProcessingService
except ImportError:
    DocumentProcessingService = None

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/documents", tags=["documents"])

DOCUMENT_STORAGE = "storage/documents"
DOCUMENTS = []  # In-memory for now
os.makedirs(DOCUMENT_STORAGE, exist_ok=True)

# Global processing service (will be injected from main app)
processing_service: Optional[DocumentProcessingService] = None

def set_processing_service(service: DocumentProcessingService):
    """Set the global processing service instance"""
    global processing_service
    processing_service = service
    logger.info("Document processing service configured for API")

@router.post("/upload", status_code=202)
async def upload_document(
    background_tasks: BackgroundTasks,
    files: List[UploadFile] = File(...),
    processing_mode: str = Form("full"),  # "full", "ocr_only", "rag_only"
    metadata: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user)
):
    """Upload insurance policy documents for processing with integrated OCR and RAG."""
    uploaded_docs = []
    failed_docs = 0
    
    for file in files:
        try:
            doc_id = str(uuid.uuid4())
            file_name = f"{doc_id}_{file.filename}"
            
            # Read file content
            file_content = await file.read()
            file_size = len(file_content)
            
            # Validate file size (50MB limit)
            if file_size > 50 * 1024 * 1024:
                logger.warning(f"File too large: {file.filename} ({file_size} bytes)")
                failed_docs += 1
                continue
            
            # Validate file type
            allowed_extensions = ['.pdf', '.png', '.jpg', '.jpeg', '.tiff', '.tif', '.webp', '.doc', '.docx']
            file_ext = os.path.splitext(file.filename.lower())[1] if file.filename else ""
            if file_ext not in allowed_extensions:
                logger.warning(f"Invalid file type: {file.filename} ({file_ext})")
                failed_docs += 1
                continue
            
            # Create document record
            document = Document(
                id=doc_id,
                filename=file.filename,
                size=file_size,
                upload_date=datetime.utcnow(),
                status="processing",
                user_uid=current_user.uid,
                file_path=os.path.join(DOCUMENT_STORAGE, file_name),
                document_type="unknown",  # Will be determined during processing
                processing_mode=processing_mode
            )
            
            DOCUMENTS.append(document)
            
            # Start background processing if service is available
            if processing_service:
                background_tasks.add_task(
                    process_document_background,
                    doc_id,
                    file_content,
                    file.filename,
                    processing_mode
                )
                logger.info(f"Background processing started for {file.filename} (ID: {doc_id})")
            else:
                # Fallback: just save the file
                file_path = os.path.join(DOCUMENT_STORAGE, file_name)
                with open(file_path, "wb") as f:
                    f.write(file_content)
                document.status = "uploaded"
                logger.warning(f"No processing service available, file saved only: {file.filename}")
            
            uploaded_docs.append({
                "id": doc_id,
                "filename": file.filename,
                "size": file_size,
                "upload_date": document.upload_date,
                "status": "processing" if processing_service else "uploaded",
                "processing_mode": processing_mode,
                "processing_id": doc_id
            })
            
        except Exception as e:
            logger.error(f"Failed to upload {file.filename}: {str(e)}")
            failed_docs += 1
    
    return {
        "documents": uploaded_docs,
        "total_uploaded": len(uploaded_docs),
        "total_failed": failed_docs,
        "message": f"Uploaded {len(uploaded_docs)} documents for processing" if processing_service else f"Uploaded {len(uploaded_docs)} documents (processing service unavailable)"
    }

async def process_document_background(
    document_id: str, 
    file_content: bytes, 
    filename: str, 
    processing_mode: str
):
    """Background task for document processing"""
    try:
        if not processing_service:
            logger.error(f"Processing service not available for {document_id}")
            return
        
        # Process the document
        result = await processing_service.process_document_full(
            file_content=file_content,
            filename=filename,
            document_id=document_id,
            processing_mode=processing_mode
        )
        
        # Update document status
        for doc in DOCUMENTS:
            if doc.id == document_id:
                if result.get("status") == "completed":
                    doc.status = "completed"
                    doc.processing_completed_at = datetime.utcnow()
                    # Extract document type if available
                    if "stages" in result and "ocr" in result["stages"]:
                        ocr_result = result["stages"]["ocr"]
                        # Simple heuristic to determine document type
                        text = ocr_result.get("full_text", "").lower()
                        if "health" in text or "medical" in text:
                            doc.document_type = "health_insurance"
                        elif "auto" in text or "vehicle" in text:
                            doc.document_type = "auto_insurance"
                        elif "life" in text:
                            doc.document_type = "life_insurance"
                        else:
                            doc.document_type = "insurance"
                else:
                    doc.status = "failed"
                    doc.error_message = result.get("error", "Processing failed")
                break
        
        logger.info(f"Background processing completed for {filename} (ID: {document_id})")
        
    except Exception as e:
        logger.error(f"Background processing failed for {document_id}: {str(e)}")
        # Update document status to failed
        for doc in DOCUMENTS:
            if doc.id == document_id:
                doc.status = "failed"
                doc.error_message = str(e)
                break

@router.get("/{document_id}/status")
async def get_document_processing_status(
    document_id: str, 
    current_user: User = Depends(get_current_user)
):
    """Get real-time processing status for a document"""
    # Check if user owns this document
    user_doc = None
    for doc in DOCUMENTS:
        if doc.id == document_id and doc.user_uid == current_user.uid:
            user_doc = doc
            break
    
    if not user_doc:
        raise HTTPException(status_code=404, detail="Document not found")
    
    # Get processing status from service
    processing_status = None
    if processing_service:
        processing_status = processing_service.get_processing_status(document_id)
    
    return {
        "document_id": document_id,
        "filename": user_doc.filename,
        "status": user_doc.status,
        "upload_date": user_doc.upload_date,
        "processing_completed_at": getattr(user_doc, 'processing_completed_at', None),
        "error_message": getattr(user_doc, 'error_message', None),
        "processing_details": processing_status
    }

@router.post("/query")
async def query_documents(
    query: str = Form(...),
    document_ids: Optional[List[str]] = Form(None),
    current_user: User = Depends(get_current_user)
):
    """Query processed documents using RAG"""
    if not processing_service:
        raise HTTPException(status_code=503, detail="Document processing service not available")
    
    # Build filters
    filters = {"user_uid": current_user.uid}
    if document_ids:
        filters["document_ids"] = document_ids
    
    try:
        result = await processing_service.query_documents(query, filters)
        return result
    except Exception as e:
        logger.error(f"Document query failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Query failed: {str(e)}")

@router.get("", response_model=dict)
async def get_documents(
    page: int = Query(1, gt=0),
    limit: int = Query(10, gt=0, le=100),
    status: Optional[str] = None,
    document_type: Optional[str] = None,
    sort: Optional[str] = None,
    current_user: User = Depends(get_current_user)
):
    """List all documents uploaded by the current user."""
    # Filter by user
    user_docs = [doc for doc in DOCUMENTS if doc.user_uid == current_user.uid]
    
    # Apply additional filters
    if status:
        user_docs = [doc for doc in user_docs if doc.status == status]
    
    if document_type:
        user_docs = [doc for doc in user_docs if doc.document_type == document_type]
    
    # Apply sorting if specified
    if sort:
        field, direction = sort.split(":") if ":" in sort else (sort, "asc")
        reverse = direction.lower() == "desc"
        user_docs = sorted(user_docs, key=lambda x: getattr(x, field, ""), reverse=reverse)
    
    # Calculate pagination
    total = len(user_docs)
    total_pages = (total + limit - 1) // limit
    start_idx = (page - 1) * limit
    end_idx = min(start_idx + limit, total)
    
    # Get documents for current page
    paginated_docs = user_docs[start_idx:end_idx]
    
    return {
        "documents": paginated_docs,
        "total": total,
        "page": page,
        "limit": limit,
        "total_pages": total_pages
    }

@router.get("/{document_id}", response_model=Document)
async def get_document(document_id: str, current_user: User = Depends(get_current_user)):
    """Get information about a specific document."""
    for doc in DOCUMENTS:
        if doc.id == document_id:
            if doc.user_uid == current_user.uid:
                return doc
            else:
                raise HTTPException(status_code=403, detail="Document belongs to another user")
    
    raise HTTPException(status_code=404, detail="Document not found")

@router.delete("/{document_id}")
async def delete_document(document_id: str, current_user: User = Depends(get_current_user)):
    """Delete a document and associated data."""
    for i, doc in enumerate(DOCUMENTS):
        if doc.id == document_id:
            if doc.user_uid == current_user.uid:
                # Remove the document file
                try:
                    if os.path.exists(doc.file_path):
                        os.remove(doc.file_path)
                except Exception as e:
                    logger.warning(f"Failed to delete file {doc.file_path}: {str(e)}")
                
                # TODO: Remove from RAG database if processing service available
                if processing_service and processing_service.rag_pipeline:
                    try:
                        # This would need to be implemented in the RAG pipeline
                        # await processing_service.rag_pipeline.delete_document(document_id)
                        pass
                    except Exception as e:
                        logger.warning(f"Failed to remove from RAG: {str(e)}")
                
                # Remove from list
                deleted_doc = DOCUMENTS.pop(i)
                
                return {
                    "message": "Document deleted successfully",
                    "id": document_id
                }
            else:
                raise HTTPException(status_code=403, detail="Document belongs to another user")
    
    raise HTTPException(status_code=404, detail="Document not found")

# Debug endpoint for development
@router.get("/debug/processing_status")
async def get_all_processing_status(current_user: User = Depends(get_current_user)):
    """Get all processing statuses (debug endpoint)"""
    if not processing_service:
        return {"error": "Processing service not available"}
    
    return processing_service.get_all_processing_status()
