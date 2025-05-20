from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

class Policy(BaseModel):
    id: str
    user_uid: str
    family_member_id: Optional[str]
    file_name: str
    file_path: str
    upload_time: datetime
    metadata: Optional[Dict[str, Any]] = None 