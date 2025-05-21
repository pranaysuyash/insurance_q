from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List

class Document(BaseModel):
    id: str
    filename: str
    size: int
    upload_date: datetime
    status: str = "processing"
    document_type: Optional[str] = None
    insurer: Optional[str] = None
    processing_completed_at: Optional[datetime] = None
    user_uid: str
    file_path: str 