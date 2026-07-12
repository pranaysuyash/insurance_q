"""Retired compatibility router.

It is intentionally not mounted. Canonical policy document ownership, upload,
summary, and deletion live under ``/documents``.
"""

from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from src.api.user import get_current_user
from src.models.user import User
from src.models.policy import Policy
from typing import List, Optional
from datetime import datetime
import os, uuid, shutil

router = APIRouter(prefix="/policy", tags=["policy"])

POLICY_STORAGE = "storage/policies"
POLICIES = []  # In-memory for now
os.makedirs(POLICY_STORAGE, exist_ok=True)

@router.post(
    "/upload", response_model=Policy, response_model_exclude={"file_path", "user_uid"}
)
def upload_policy(
    file: UploadFile = File(...),
    family_member_id: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user)
):
    policy_id = str(uuid.uuid4())
    file_name = f"{policy_id}_{file.filename}"
    file_path = os.path.join(POLICY_STORAGE, file_name)
    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    policy = Policy(
        id=policy_id,
        user_uid=current_user.uid,
        family_member_id=family_member_id,
        file_name=file.filename,
        file_path=file_path,
        upload_time=datetime.utcnow(),
        metadata=None
    )
    POLICIES.append(policy)
    return policy

@router.get(
    "/list", response_model=List[Policy], response_model_exclude={"file_path", "user_uid"}
)
def list_policies(current_user: User = Depends(get_current_user)):
    return [p for p in POLICIES if p.user_uid == current_user.uid]

@router.get(
    "/{policy_id}", response_model=Policy, response_model_exclude={"file_path", "user_uid"}
)
def get_policy(policy_id: str, current_user: User = Depends(get_current_user)):
    for p in POLICIES:
        if p.id == policy_id and p.user_uid == current_user.uid:
            return p
    raise HTTPException(status_code=404, detail="Policy not found")
