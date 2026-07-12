from pydantic import BaseModel, EmailStr
from typing import Optional

class User(BaseModel):
    uid: str
    identity_type: str = "anonymous"
    email: Optional[EmailStr]
    phone: Optional[str]
    display_name: Optional[str]
