from pydantic import BaseModel
from typing import Optional
from datetime import date

class FamilyMember(BaseModel):
    id: str
    user_uid: str  # Owner's Firebase UID
    name: str
    relationship: str  # e.g., self, spouse, child, parent
    dob: Optional[date]
