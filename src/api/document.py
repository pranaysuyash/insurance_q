from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, Query, BackgroundTasks, Request
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

# Import anti-abuse utilities
from src.utils.anti_abuse import (
    create_document_hash,
    get_client_ip,
    check_all_rate_limits,
    log_usage_attempt,
    get_current_usage_stats
)

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
    request: Request,
    background_tasks: BackgroundTasks,
    files: List[UploadFile] = File(...),
    processing_mode: str = Form("full"),  # "full", "ocr_only", "rag_only"
    metadata: Optional[str] = Form(None),
    user_email: Optional[str] = Form(None),  # Optional lead capture
    user_phone: Optional[str] = Form(None),  # Optional lead capture
    consent: Optional[bool] = Form(False),
    current_user: User = Depends(get_current_user),
):
    """Upload policy documents owned by the verified anonymous principal."""
    uploaded_docs = []
    failed_docs = 0
    
    # Extract client information for anti-abuse
    ip_address = get_client_ip(request)
    session_id = current_user.uid
    user_agent = request.headers.get('User-Agent', '')
    
    logger.info(f"Upload request from IP: {ip_address}, Session: {session_id[:8]}...")
    
    for file in files:
        try:
            doc_id = str(uuid.uuid4())
            file_name = f"{doc_id}_{file.filename}"
            
            # Read file content
            file_content = await file.read()
            file_size = len(file_content)
            
            # Create document hash for anti-abuse checking
            document_hash = create_document_hash(file_content)
            
            # Check anti-abuse limits BEFORE processing
            rate_limit_allowed, rate_limit_reason = check_all_rate_limits(
                ip_address=ip_address,
                session_id=session_id,
                document_hash=document_hash,
                email=user_email
            )
            
            if not rate_limit_allowed:
                log_usage_attempt(
                    ip_address=ip_address,
                    session_id=session_id,
                    document_hash=document_hash,
                    email=user_email,
                    user_agent=user_agent,
                    allowed=False,
                    reason=rate_limit_reason
                )
                raise HTTPException(
                    status_code=429,
                    detail=f"Rate limit exceeded: {rate_limit_reason}"
                )
            
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
            
            # Log successful usage attempt
            log_usage_attempt(
                ip_address=ip_address,
                session_id=session_id,
                document_hash=document_hash,
                email=user_email,
                user_agent=user_agent,
                allowed=True,
                reason="Upload accepted"
            )
            
            # Create document record (no user_uid required)
            document = Document(
                id=doc_id,
                filename=file.filename,
                size=file_size,
                upload_date=datetime.utcnow(),
                status="processing",
                user_uid=session_id,  # Use session ID instead of user UID
                file_path=os.path.join(DOCUMENT_STORAGE, file_name),
                document_type="unknown",  # Will be determined during processing
                processing_mode=processing_mode
            )
            
            # Add lead capture data and anti-abuse metadata
            metadata_dict = {
                "owner_id": current_user.uid,
                "document_hash": document_hash,
                "ip_address": ip_address,
                "user_agent": user_agent[:200] if user_agent else None,  # Truncate for storage
                "upload_timestamp": datetime.utcnow().isoformat()
            }
            
            # Add lead capture data if provided
            if user_email or user_phone:
                metadata_dict.update({
                    "user_email": user_email,
                    "user_phone": user_phone,
                    "consent": consent,
                    "lead_captured_at": datetime.utcnow().isoformat()
                })
            
            document.metadata = metadata_dict
            
            DOCUMENTS.append(document)
            
            # Start background processing if service is available
            if processing_service:
                background_tasks.add_task(
                    process_document_background,
                    doc_id,
                    file_content,
                    file.filename,
                    processing_mode,
                    current_user.uid,
                )
                logger.info(f"Background processing started for {file.filename} (ID: {doc_id}, Session: {session_id})")
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
                "processing_id": doc_id,
                "owner_id": current_user.uid
            })
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Failed to upload {file.filename}: {e}")
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
    processing_mode: str,
    owner_id: str,
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
            processing_mode=processing_mode,
            owner_id=owner_id,
        )
        
        # Update document status
        for doc in DOCUMENTS:
            if doc.id == document_id:
                if result.get("status") == "completed":
                    doc.status = "completed"
                    doc.processing_completed_at = datetime.utcnow()
                    
                    # Enhanced document classification using the new classifier
                    try:
                        from src.utils.document_classifier import get_document_classifier
                        
                        # Get text content from OCR result
                        text_content = ""
                        if "stages" in result and "ocr" in result["stages"]:
                            ocr_result = result["stages"]["ocr"]
                            text_content = ocr_result.get("full_text", "")
                        
                        # Use the classifier to determine document type and metadata
                        classifier = get_document_classifier(processing_service.rag_pipeline if processing_service else None)
                        classification = await classifier.classify_document(document_id, text_content)
                        
                        # Update document with classification results
                        doc.document_type = classification.get('document_type', 'Insurance Policy')
                        doc.insurer = classification.get('insurer', 'Unknown')
                        
                        # Store additional metadata
                        if not doc.metadata:
                            doc.metadata = {}
                        doc.metadata.update({
                            'classification': classification,
                            'policy_number': classification.get('policy_number'),
                            'effective_date': classification.get('effective_date'),
                            'expiration_date': classification.get('expiration_date'),
                            'classification_confidence': classification.get('confidence', 0.0)
                        })
                        
                        logger.info(f"Document {document_id} classified as {doc.document_type} by {classification.get('insurer', 'Unknown')} with {classification.get('confidence', 0.0):.2f} confidence")
                        
                    except Exception as e:
                        logger.error(f"Document classification failed for {document_id}: {str(e)}")
                        # Fallback to simple heuristic
                        if "stages" in result and "ocr" in result["stages"]:
                            ocr_result = result["stages"]["ocr"]
                            text = ocr_result.get("full_text", "").lower()
                            if "health" in text or "medical" in text:
                                doc.document_type = "Health Insurance"
                            elif "auto" in text or "vehicle" in text:
                                doc.document_type = "Auto Insurance"
                            elif "life" in text:
                                doc.document_type = "Life Insurance"
                            else:
                                doc.document_type = "Insurance Policy"
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
    current_user: User = Depends(get_current_user),
):
    """Get processing status only for the owning principal."""
    # Find document by ID
    user_doc = None
    for doc in DOCUMENTS:
        if doc.id == document_id:
            if doc.user_uid == current_user.uid:
                user_doc = doc
                break
    
    if not user_doc:
        raise HTTPException(status_code=404, detail="Document not found or access denied")
    
    # Get processing status from service
    processing_status = None
    if processing_service:
        processing_status = processing_service.get_processing_status(document_id)
    
    response = {
        "document_id": document_id,
        "filename": user_doc.filename,
        "status": user_doc.status,
        "upload_date": user_doc.upload_date,
        "processing_completed_at": getattr(user_doc, 'processing_completed_at', None),
        "error_message": getattr(user_doc, 'error_message', None),
        "processing_details": processing_status,
    }
    
    # Include lead data if available
    if hasattr(user_doc, 'metadata') and user_doc.metadata:
        response["lead_data"] = {
            "email": user_doc.metadata.get("user_email"),
            "phone": user_doc.metadata.get("user_phone"),
            "consent": user_doc.metadata.get("consent", False)
        }
        
        # Include classification data if available
        if "classification" in user_doc.metadata:
            classification = user_doc.metadata["classification"]
            response["classification"] = {
                "document_type": classification.get("document_type"),
                "insurer": classification.get("insurer"),
                "policy_number": classification.get("policy_number"),
                "effective_date": classification.get("effective_date"),
                "expiration_date": classification.get("expiration_date"),
                "confidence": classification.get("confidence"),
                "classified_at": classification.get("classified_at")
            }
    
    return response

@router.get("/usage-stats")
async def get_usage_statistics(
    request: Request,
    current_user: User = Depends(get_current_user),
):
    """Get current usage statistics for rate limiting transparency."""
    ip_address = get_client_ip(request)
    actual_session_id = current_user.uid
    
    stats = get_current_usage_stats(ip_address, actual_session_id)
    
    return {
        "usage_stats": stats,
        "limits": {
            "ip_daily": stats['ip_limit'],
            "session_daily": stats['session_limit'],
            "policy_monthly": 5  # Will be dynamic in Phase 2
        },
        "remaining": {
            "ip_daily": max(0, stats['ip_limit'] - stats['ip_usage']),
            "session_daily": max(0, stats['session_limit'] - stats['session_usage'])
        }
    }

@router.post("/query")
async def query_documents(
    request: Request,
    query: str = Form(...),
    document_ids: Optional[List[str]] = Form(None),
    current_user: User = Depends(get_current_user),
):
    """Query only documents that belong to the verified principal."""
    if not processing_service:
        raise HTTPException(status_code=503, detail="Document processing service not available")
    
    filters = {"owner_id": current_user.uid}
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
                    deletion = await processing_service.rag_pipeline.delete_document_data(
                        document_id, current_user.uid
                    )
                    if deletion.get("status") != "success":
                        raise HTTPException(status_code=503, detail="Unable to delete derived search data; retry deletion")

                if processing_service and processing_service.policy_extraction_service:
                    processing_service.policy_extraction_service.delete_summary(document_id)
                
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

@router.post("/capture-lead")
async def capture_lead(
    user_email: str = Form(...),
    user_phone: Optional[str] = Form(None),
    user_name: Optional[str] = Form(None),
    consent: bool = Form(...),
    interest_level: Optional[str] = Form(None),  # "high", "medium", "low"
    preferred_contact: Optional[str] = Form(None),  # "email", "phone", "both"
    notes: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user),
):
    """Capture lead information after user sees document analysis results."""
    
    # Find documents associated with this session
    session_documents = [doc for doc in DOCUMENTS if doc.user_uid == current_user.uid]
    
    if not session_documents:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Create lead record
    lead_data = {
        "owner_id": current_user.uid,
        "email": user_email,
        "phone": user_phone,
        "name": user_name,
        "consent": consent,
        "interest_level": interest_level,
        "preferred_contact": preferred_contact,
        "notes": notes,
        "captured_at": datetime.utcnow().isoformat(),
        "documents_processed": len(session_documents),
        "document_types": list(set([doc.document_type for doc in session_documents if doc.document_type != "unknown"]))
    }
    
    # Update all documents in this session with lead data
    for doc in session_documents:
        if not hasattr(doc, 'metadata') or not doc.metadata:
            doc.metadata = {}
        doc.metadata.update(lead_data)
    
    logger.info("Lead captured for owner %s", current_user.uid[:12])
    
    return {
        "status": "success",
        "message": "Lead information captured successfully",
        "documents_count": len(session_documents)
    }


@router.get("/{document_id}/summary")
async def get_policy_summary(
    document_id: str, current_user: User = Depends(get_current_user)
):
    """Get the structured policy summary for a document.

    Returns the extracted PolicySummaryExtraction data that was generated
    at ingestion time via a single LLM call. This endpoint is used by the
    mobile app's Emergency Card, Claims Assistant, Renewal Calendar,
    Coverage Gap Scan, and Policy Comparison features.
    """
    if not any(doc.id == document_id and doc.user_uid == current_user.uid for doc in DOCUMENTS):
        raise HTTPException(status_code=404, detail="Document not found")
    if not processing_service:
        raise HTTPException(status_code=503, detail="Processing service not available")

    # Check if the document was processed and has a summary
    if not hasattr(processing_service, 'policy_extraction_service') or not processing_service.policy_extraction_service:
        raise HTTPException(status_code=503, detail="Policy extraction service not available")

    summary = processing_service.policy_extraction_service.get_summary(document_id)
    if not summary:
        raise HTTPException(status_code=404, detail=f"No policy summary found for document {document_id}")

    return {"status": "success", "summary": summary}


@router.get("/summaries/all")
async def get_all_policy_summaries(current_user: User = Depends(get_current_user)):
    """Get all stored policy summaries.

    Used by the mobile app to load all policy data at once for dashboard
    rendering, coverage gap analysis, and comparison features.
    """
    if not processing_service:
        raise HTTPException(status_code=503, detail="Processing service not available")

    if not hasattr(processing_service, 'policy_extraction_service') or not processing_service.policy_extraction_service:
        raise HTTPException(status_code=503, detail="Policy extraction service not available")

    owned_ids = {doc.id for doc in DOCUMENTS if doc.user_uid == current_user.uid}
    all_summaries = processing_service.policy_extraction_service.get_all_summaries()
    owned_summaries = [summary for doc_id, summary in all_summaries.items() if doc_id in owned_ids]
    return {"status": "success", "summaries": owned_summaries, "count": len(owned_summaries)}
