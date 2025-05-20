from fastapi import APIRouter, Depends
from src.api.user import get_current_user
from src.models.family import FamilyMember
from src.models.user import User
from typing import List

router = APIRouter(prefix="/family", tags=["family"])

# Stub: return empty list for now
@router.get("/members", response_model=List[FamilyMember])
def list_family_members(current_user: User = Depends(get_current_user)):
    return []
