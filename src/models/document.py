from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List, Dict, Any

class Document(BaseModel):
    id: str
    filename: str
    size: int
    upload_date: datetime
    status: str = "processing"  # "processing", "completed", "failed", "uploaded"
    document_type: Optional[str] = None
    insurer: Optional[str] = None
    processing_completed_at: Optional[datetime] = None
    user_uid: str
    file_path: str
    processing_mode: Optional[str] = "full"  # "full", "ocr_only", "rag_only"
    error_message: Optional[str] = None
    extracted_text_length: Optional[int] = None
    rag_ingested: Optional[bool] = False
    metadata: Optional[Dict[str, Any]] = None  # For lead capture and other metadata

class DocumentProcessingStatus(BaseModel):
    document_id: str
    filename: str
    status: str
    stage: str
    progress: int
    started_at: Optional[str] = None
    updated_at: Optional[str] = None
    error: Optional[str] = None

class DocumentUploadResponse(BaseModel):
    documents: List[Dict[str, Any]]
    total_uploaded: int
    total_failed: int
    message: str

class DocumentQueryRequest(BaseModel):
    query: str
    document_ids: Optional[List[str]] = None
    filters: Optional[Dict[str, Any]] = None

class DocumentQueryResponse(BaseModel):
    answer: str
    sources: List[Dict[str, Any]] = []
    confidence: Optional[float] = None
    total_documents_searched: Optional[int] = None
    query_time_ms: Optional[int] = None
