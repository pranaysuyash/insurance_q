"""GenAI Objectionable Content User Reporting API.

Provides an in-app and API user reporting mechanism for AI-generated content
required by Google Play Developer Program Policies (Generative AI Content Policy).
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

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


# In-memory storage for reports (in production logged to evidence substrate / DB)
_REPORTS_STORE = []


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
        "created_at": now_iso,
        "user_agent": request.headers.get("user-agent"),
        "ip_address": request.client.host if request.client else None,
    }

    _REPORTS_STORE.append(record)
    logger.info(
        "qa_content_report_registered report_id=%s category=%s user_id=%s",
        report_id,
        body.category,
        current_user.uid[:12],
    )

    return QAReportResponse(
        report_id=report_id,
        status="registered",
        created_at=now_iso,
        message="Thank you. Your report has been registered for moderation review.",
    )
