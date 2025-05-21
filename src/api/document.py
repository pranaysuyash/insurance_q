from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, Query
from src.api.user import get_current_user
from src.models.user import User
from src.models.document import Document
from typing import List, Optional
from datetime import datetime
import os, uuid, shutil

router = APIRouter(prefix="/documents", tags=["documents"])

DOCUMENT_STORAGE = "storage/documents"
DOCUMENTS = []  # In-memory for now
os.makedirs(DOCUMENT_STORAGE, exist_ok=True)

@router.post("/upload", status_code=202)
async def upload_document(
    files: List[UploadFile] = File(...),
    metadata: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user)
):
    """Upload insurance policy documents for processing."""
    uploaded_docs = []
    failed_docs = 0
    
    for file in files:
        try:
            doc_id = str(uuid.uuid4())
            file_name = f"{doc_id}_{file.filename}"
            file_path = os.path.join(DOCUMENT_STORAGE, file_name)
            
            with open(file_path, "wb") as f:
                shutil.copyfileobj(file.file, f)
            
            # Get file size
            file_size = os.path.getsize(file_path)
            
            document = Document(
                id=doc_id,
                filename=file.filename,
                size=file_size,
                upload_date=datetime.utcnow(),
                status="processing",
                user_uid=current_user.uid,
                file_path=file_path
            )
            
            DOCUMENTS.append(document)
            uploaded_docs.append({
                "id": doc_id,
                "filename": file.filename,
                "size": file_size,
                "upload_date": document.upload_date,
                "status": "processing",
                "processing_id": doc_id
            })
        except Exception as e:
            failed_docs += 1
    
    return {
        "documents": uploaded_docs,
        "total_uploaded": len(uploaded_docs),
        "total_failed": failed_docs
    }

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
                    pass
                
                # Remove from list
                deleted_doc = DOCUMENTS.pop(i)
                
                return {
                    "message": "Document deleted successfully",
                    "id": document_id
                }
            else:
                raise HTTPException(status_code=403, detail="Document belongs to another user")
    
    raise HTTPException(status_code=404, detail="Document not found") 