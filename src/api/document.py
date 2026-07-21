from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, Query, BackgroundTasks, Request
from fastapi.responses import Response
from src.api.user import get_current_user
from src.models.user import User
from src.models.document import Document
from src.services.document_repository import DocumentRepository, create_document_repository
from src.services.document_object_store import DocumentObjectStore, create_document_object_store
from src.utils.runtime_access import require_nonproduction
from src.utils.upload_validation import (
    MAX_UPLOAD_BYTES,
    UploadValidationError,
    validate_upload_content,
)
from typing import List, Optional
from datetime import datetime
import os
import uuid
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

document_repository: DocumentRepository = create_document_repository()
document_object_store: DocumentObjectStore = create_document_object_store()

# Global processing service (will be injected from main app)
processing_service: Optional[DocumentProcessingService] = None

_CLIENT_DOCUMENT_EXCLUDED_FIELDS = {"file_path", "user_uid", "source_hash", "metadata"}


def _client_document(document: Document) -> dict:
    """Return customer-visible document state without storage/auth internals."""
    if hasattr(document, "model_dump"):
        return document.model_dump(exclude=_CLIENT_DOCUMENT_EXCLUDED_FIELDS)
    return document.dict(exclude=_CLIENT_DOCUMENT_EXCLUDED_FIELDS)

def set_processing_service(service: DocumentProcessingService):
    """Set the global processing service instance"""
    global processing_service
    processing_service = service
    logger.info("Document processing service configured for API")


def set_document_repository(repository: DocumentRepository) -> None:
    """Inject a repository for startup composition and isolated tests."""
    global document_repository
    document_repository = repository


def set_document_object_store(object_store: DocumentObjectStore) -> None:
    """Inject an object store for startup composition and isolated tests."""
    global document_object_store
    document_object_store = object_store

@router.post("/upload", status_code=202)
async def upload_document(
    request: Request,
    background_tasks: BackgroundTasks,
    files: List[UploadFile] = File(...),
    processing_mode: str = Form("full"),  # "full", "ocr_only", "rag_only"
    processing_consent: bool = Form(False),
    processing_consent_version: Optional[str] = Form(None),
    pdf_password: Optional[str] = Form(None),
    on_device_ocr_text: Optional[str] = Form(None),
    metadata: Optional[str] = Form(None),
    user_email: Optional[str] = Form(None),  # Optional lead capture
    user_phone: Optional[str] = Form(None),  # Optional lead capture
    consent: Optional[bool] = Form(False),
    current_user: User = Depends(get_current_user),
):
    """Upload policy documents owned by the verified anonymous principal."""
    if not processing_consent or not processing_consent_version:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "processing_consent_required",
                "message": "Accept the current Privacy Policy to securely process this policy.",
            },
        )
    if (user_email or user_phone) and not consent:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "contact_consent_required",
                "message": "Consent is required before contact details can be stored with a policy.",
            },
        )
    uploaded_docs = []
    failed_docs = 0
    
    # Extract client information for anti-abuse
    ip_address = get_client_ip(request)
    session_id = current_user.uid
    user_agent = request.headers.get('User-Agent', '')
    # Mobile OCR is an optional, request-scoped recovery artifact. It is never
    # persisted in document metadata and cannot replace the uploaded source.
    # Keeping a hard cap prevents a multipart text field from bypassing the
    # document-size boundary.
    mobile_ocr_text = (
        on_device_ocr_text.strip()
        if isinstance(on_device_ocr_text, str) and on_device_ocr_text.strip()
        else None
    )
    if mobile_ocr_text and len(mobile_ocr_text.encode("utf-8")) > 2 * 1024 * 1024:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "on_device_ocr_too_large",
                "message": "On-device OCR text is too large. Upload the original document without the OCR assist.",
            },
        )
    
    logger.info("document_upload_received owner=%s", session_id[:12])
    
    for file in files:
        try:
            doc_id = str(uuid.uuid4())
            # Read file content
            # Read at most one byte beyond the documented limit. This bounds
            # application-level work before hashing, storage, or OCR.
            file_content = await file.read(MAX_UPLOAD_BYTES + 1)
            file_size = len(file_content)

            try:
                validate_upload_content(
                    file.filename, file_content, pdf_password=pdf_password
                )
            except UploadValidationError as error:
                logger.info("document_upload_rejected reason=%s", error.code)
                raise HTTPException(
                    status_code=422,
                    detail={"code": error.code, "message": error.message},
                ) from error
            
            # Create document hash for anti-abuse checking
            document_hash = create_document_hash(file_content)

            # Idempotency is owner-scoped: retrying the identical source must
            # not create another object, processing job, vector set, or policy.
            existing_document = document_repository.find_by_source_hash(
                current_user.uid, document_hash
            )
            if existing_document:
                logger.info(
                    "document_upload_deduplicated document_id=%s owner=%s status=%s",
                    existing_document.id,
                    current_user.uid[:12],
                    existing_document.status,
                )
                uploaded_docs.append(
                    {
                        "id": existing_document.id,
                        "filename": existing_document.filename,
                        "size": existing_document.size,
                        "upload_date": existing_document.upload_date,
                        "status": existing_document.status,
                        "processing_mode": existing_document.processing_mode,
                        "processing_id": existing_document.id,
                        "idempotent_replay": True,
                    }
                )
                continue
            
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
            
            object_reference = document_object_store.put(
                doc_id, current_user.uid, file.filename or "document", file_content
            )
            # Persist metadata only after the encrypted/local source write succeeds.
            document = Document(
                id=doc_id,
                filename=file.filename,
                size=file_size,
                upload_date=datetime.utcnow(),
                status="received",
                user_uid=session_id,  # Use session ID instead of user UID
                file_path=object_reference,
                source_hash=document_hash,
                document_type="unknown",  # Will be determined during processing
                processing_mode=processing_mode
            )
            
            # Add lead capture data and anti-abuse metadata
            metadata_dict = {
                "owner_id": current_user.uid,
                "document_hash": document_hash,
                "ip_address": ip_address,
                "user_agent": user_agent[:200] if user_agent else None,  # Truncate for storage
                "upload_timestamp": datetime.utcnow().isoformat(),
                "processing_consent": True,
                "processing_consent_version": processing_consent_version[:128],
                "processing_consent_at": datetime.utcnow().isoformat(),
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
            
            try:
                document_repository.create(document)
            except Exception:
                # Avoid retaining an unreachable customer document if metadata
                # persistence fails before the async processing task is queued.
                document_object_store.delete(object_reference)
                raise
            
            # Start background processing if service is available
            if processing_service:
                background_tasks.add_task(
                    process_document_background,
                    doc_id,
                    file_content,
                    file.filename,
                    processing_mode,
                    current_user.uid,
                    pdf_password.strip() if pdf_password else None,
                    mobile_ocr_text,
                )
                logger.info("document_processing_queued document_id=%s owner=%s", doc_id, session_id[:12])
            else:
                document.status = "uploaded"
                document_repository.update(document)
                logger.warning("document_source_persisted_without_processing development_only=true")
            
            uploaded_docs.append({
                "id": doc_id,
                "filename": file.filename,
                "size": file_size,
                "upload_date": document.upload_date,
                "status": "received" if processing_service else "uploaded",
                "processing_mode": processing_mode,
                "processing_id": doc_id,
            })
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error("document_upload_failed error_type=%s", type(e).__name__)
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
    pdf_password: Optional[str] = None,
    on_device_ocr_text: Optional[str] = None,
):
    """Process a document only after atomically leasing its durable state."""
    try:
        if not processing_service:
            logger.error(f"Processing service not available for {document_id}")
            return
        if not document_repository.claim_processing(document_id, owner_id, lease_seconds=900):
            logger.info("Skipping document %s because another worker owns its lease", document_id)
            return
        
        # Process the document
        result = await processing_service.process_document_full(
            file_content=file_content,
            filename=filename,
            document_id=document_id,
            processing_mode=processing_mode,
            owner_id=owner_id,
            pdf_password=pdf_password,
            on_device_ocr_text=on_device_ocr_text,
        )
        
        # Update document status
        doc = document_repository.get(document_id, owner_id)
        if doc:
            if result.get("status") == "completed":
                doc.status = "completed"
                doc.processing_completed_at = datetime.utcnow()
                doc.processing_lease_expires_at = None
                    
                # Enhanced document classification using the new classifier
                try:
                    from src.utils.document_classifier import get_document_classifier

                    text_content = ""
                    if "stages" in result and "ocr" in result["stages"]:
                        text_content = result["stages"]["ocr"].get("full_text", "")
                    classifier = get_document_classifier(processing_service.rag_pipeline)
                    classification = await classifier.classify_document(document_id, text_content)
                    doc.document_type = classification.get("document_type", "Insurance Policy")
                    doc.insurer = classification.get("insurer", "Unknown")
                    if not doc.metadata:
                        doc.metadata = {}
                    doc.metadata.update(
                        {
                            "classification": classification,
                            "policy_number": classification.get("policy_number"),
                            "effective_date": classification.get("effective_date"),
                            "expiration_date": classification.get("expiration_date"),
                            "classification_confidence": classification.get("confidence", 0.0),
                        }
                    )
                    logger.info(
                        "Document %s classified as %s by %s with %.2f confidence",
                        document_id,
                        doc.document_type,
                        classification.get("insurer", "Unknown"),
                        classification.get("confidence", 0.0),
                    )
                except Exception as e:
                    logger.error(
                        "document_classification_failed document_id=%s error_type=%s",
                        document_id,
                        type(e).__name__,
                    )
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
                doc.error_message = "Document processing did not complete. Please retry the upload."
                doc.processing_lease_expires_at = None
            document_repository.update(doc)
        
        logger.info("document_processing_finished document_id=%s", document_id)
        
    except Exception as e:
        logger.error("document_processing_failed document_id=%s error_type=%s", document_id, type(e).__name__)
        # Update document status to failed
        doc = document_repository.get(document_id, owner_id)
        if doc:
            doc.status = "failed"
            doc.error_message = "Document processing did not complete. Please retry the upload."
            doc.processing_lease_expires_at = None
            document_repository.update(doc)


async def recover_interrupted_document_processing() -> int:
    """Resume received/stale documents after a serving-instance restart.

    The durable repository lease prevents two Cloud Run instances from taking
    the same recovery item. Source bytes are fetched from the canonical object
    store rather than an instance filesystem.
    """
    if not processing_service:
        return 0
    recovered = 0
    for document in document_repository.list_recoverable_processing():
        try:
            content = document_object_store.get(document.file_path)
            await process_document_background(
                document.id,
                content,
                document.filename,
                document.processing_mode or "full",
                document.user_uid,
            )
            recovered += 1
        except Exception as error:
            logger.error("Unable to recover document %s: %s", document.id, type(error).__name__)
    return recovered

@router.get("/{document_id}/status")
async def get_document_processing_status(
    document_id: str,
    current_user: User = Depends(get_current_user),
):
    """Get processing status only for the owning principal."""
    # Find document by ID
    user_doc = document_repository.get(document_id, current_user.uid)
    
    if not user_doc:
        raise HTTPException(status_code=404, detail="Document not found or access denied")
    
    # Get processing status from service
    processing_status = None
    if processing_service:
        processing_status = processing_service.get_processing_status(document_id, current_user.uid)
    
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
        logger.error("document_query_failed owner=%s error_type=%s", current_user.uid[:12], type(e).__name__)
        raise HTTPException(status_code=500, detail="Query processing failed; please try again") from e

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
    user_docs = document_repository.list_for_owner(current_user.uid)
    
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
        "documents": [_client_document(document) for document in paginated_docs],
        "total": total,
        "page": page,
        "limit": limit,
        "total_pages": total_pages
    }

@router.get("/{document_id}", response_model=dict)
async def get_document(document_id: str, current_user: User = Depends(get_current_user)):
    """Get information about a specific document."""
    document = document_repository.get(document_id, current_user.uid)
    if not document:
        raise HTTPException(status_code=404, detail="Document not found")
    return _client_document(document)

@router.delete("/{document_id}")
async def delete_document(document_id: str, current_user: User = Depends(get_current_user)):
    """Delete a document and associated data."""
    doc = document_repository.get(document_id, current_user.uid)
    if doc:
        # Delete derived search data before deleting the metadata record so a
        # retry retains the owner/document evidence needed to finish cleanup.
        if processing_service and processing_service.rag_pipeline:
            deletion = await processing_service.rag_pipeline.delete_document_data(
                document_id, current_user.uid
            )
            if deletion.get("status") != "success":
                raise HTTPException(status_code=503, detail="Unable to delete derived search data; retry deletion")
        if processing_service and processing_service.policy_extraction_service:
            processing_service.policy_extraction_service.delete_summary(document_id)
        try:
            document_object_store.delete(doc.file_path)
        except Exception as error:
            raise HTTPException(status_code=503, detail="Unable to delete source document; retry deletion") from error
        if not document_repository.delete(document_id, current_user.uid):
            raise HTTPException(status_code=409, detail="Document deletion conflicted; retry")
        return {"message": "Document deleted successfully", "id": document_id}
    raise HTTPException(status_code=404, detail="Document not found")

# Debug endpoint for development
@router.get("/debug/processing_status")
async def get_all_processing_status(_: None = Depends(require_nonproduction)):
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
    session_documents = document_repository.list_for_owner(current_user.uid)
    
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
        document_repository.update(doc)
    
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
    if not document_repository.get(document_id, current_user.uid):
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


@router.get("/{document_id}/pages/{page_number}")
async def get_document_page(
    document_id: str,
    page_number: int,
    current_user: User = Depends(get_current_user),
):
    """Serve a single page image from the document's page image store.

    Page images are generated during document processing (png, 150 DPI)
    and stored in the canonical document object store. This endpoint
    enables the mobile app to display cited pages even when the full
    source PDF is not available locally on the device.

    Returns 404 if the document does not exist or the page image has
    not been generated yet (e.g. processing is still in progress).
    """
    if not document_repository.get(document_id, current_user.uid):
        raise HTTPException(status_code=404, detail="Document not found")
    try:
        image_bytes = document_object_store.get_page_image(document_id, page_number)
    except Exception:
        raise HTTPException(
            status_code=404,
            detail=f"Page {page_number} image not available for document {document_id}. "
                   f"The document may still be processing.",
        )
    return Response(content=image_bytes, media_type="image/png")


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

    owned_ids = {doc.id for doc in document_repository.list_for_owner(current_user.uid)}
    all_summaries = processing_service.policy_extraction_service.get_all_summaries()
    owned_summaries = [summary for doc_id, summary in all_summaries.items() if doc_id in owned_ids]
    return {"status": "success", "summaries": owned_summaries, "count": len(owned_summaries)}
