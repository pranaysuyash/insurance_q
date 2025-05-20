from pydantic import BaseModel, EmailStr
from typing import Optional

class User(BaseModel):
    uid: str  # Firebase UID
    email: Optional[EmailStr]
    phone: Optional[str]
    display_name: Optional[str]
