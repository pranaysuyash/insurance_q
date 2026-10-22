"""GenAI Objectionable Content User Reporting API.

Provides an in-app and API user reporting mechanism for AI-generated content
required by Google Play Developer Program Policies (Generative AI Content Policy).
"""
from __future__ import annotations

import logging
import os
import uuid
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from src.api.user import get_current_user
from src.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/qa", tags=["qa-report"])


class QAReportRequest(BaseModel):
    question: str = Field(..., description="The user question that generated the answer")
    answer_text: str = Field(..., description="The AI answer being reported")
    category: str = Field(
        ...,
        description="Report category: incorrect, harmful, pii, offensive, other",
    )
    comments: Optional[str] = Field(None, description="Optional user details or feedback")
    document_id: Optional[str] = Field(None, description="Associated document ID if applicable")
    model_run_id: Optional[str] = Field(None, description="Model run or execution ID if applicable")


class QAReportResponse(BaseModel):
    report_id: str
    status: str
    created_at: str
    message: str


class QAReportRecord(BaseModel):
    report_id: str
    user_id: str
    question: str
    answer_text: str
    category: str
    comments: Optional[str] = None
    document_id: Optional[str] = None
    model_run_id: Optional[str] = None
    status: str = "registered"
    created_at: str


def _get_supabase_client():
    url = os.getenv("SUPABASE_URL", "").strip()
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", os.getenv("SUPABASE_KEY", "")).strip()
    if not url or not key:
        return None
    try:
        from src.utils.supabase_client import create_client
        return create_client(url, key)
    except Exception as e:
        logger.warning("qa_report_supabase_init_failed error=%s", e)
        return None


@router.post("/report", response_model=QAReportResponse, status_code=201)
async def submit_qa_report(
    body: QAReportRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
) -> QAReportResponse:
    """Submit a report for objectionable or inaccurate AI-generated content."""
    report_id = f"rpt-{uuid.uuid4().hex[:12]}"
    now_iso = datetime.now(timezone.utc).isoformat()

    record = {
        "report_id": report_id,
        "user_id": current_user.uid,
        "question": body.question,
        "answer_text": body.answer_text[:1000],  # Bounded payload snippet
        "category": body.category,
        "comments": body.comments,
        "document_id": body.document_id,
        "model_run_id": body.model_run_id,
        "status": "registered",
        "created_at": now_iso,
        "user_agent": request.headers.get("user-agent"),
        "ip_address": request.client.host if request.client else None,
    }

    client = _get_supabase_client()
    if client is not None:
        try:
            client.table("qa_reports").insert(record).execute()
            logger.info("qa_report_persisted_to_db report_id=%s user_id=%s", report_id, current_user.uid[:12])
        except Exception as e:
            logger.error("qa_report_db_insert_failed report_id=%s error=%s", report_id, e)
    else:
        logger.info("qa_report_fallback_logged report_id=%s user_id=%s", report_id, current_user.uid[:12])

    return QAReportResponse(
        report_id=report_id,
        status="registered",
        created_at=now_iso,
        message="Thank you. Your report has been registered for moderation review.",
    )


@router.get("/reports", response_model=List[QAReportRecord])
async def list_qa_reports(
    current_user: User = Depends(get_current_user),
) -> List[QAReportRecord]:
    """Admin-only: list registered reports for moderation review."""
    if getattr(current_user, "role", "") != "admin" and not getattr(current_user, "is_admin", False):
        raise HTTPException(status_code=403, detail="Admin role required for moderation access")

    client = _get_supabase_client()
    if client is None:
        return []
    try:
        res = client.table("qa_reports").select("*").order("created_at", desc=True).limit(100).execute()
        return [QAReportRecord(**item) for item in (res.data or [])]
    except Exception as e:
        logger.error("qa_report_list_failed error=%s", e)
        raise HTTPException(status_code=500, detail="Failed to retrieve moderation reports") from e
