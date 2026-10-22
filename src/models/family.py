from __future__ import annotations

from datetime import date, datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field


class FamilyMember(BaseModel):
    id: str
    user_uid: str
    name: str
    relationship: str
    dob: Optional[date] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class CreateFamilyMemberRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    relationship: str = Field(..., min_length=1, max_length=60)
    dob: Optional[date] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    notes: Optional[str] = None


class UpdateFamilyMemberRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=120)
    relationship: Optional[str] = Field(None, min_length=1, max_length=60)
    dob: Optional[date] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    notes: Optional[str] = None


class FamilyMemberResponse(BaseModel):
    id: str
    user_uid: str
    name: str
    relationship: str
    dob: Optional[date] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    notes: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
