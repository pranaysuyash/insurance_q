from pydantic import BaseModel, EmailStr
from typing import Optional

class User(BaseModel):
    uid: str
    identity_type: str = "anonymous"
    email: Optional[EmailStr]
    phone: Optional[str]
    display_name: Optional[str]

    @property
    def is_account(self) -> bool:
        return self.identity_type == "account"
