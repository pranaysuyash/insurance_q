"""Outbox handler for QA_RESPONSE jobs.

Persists AI-generated content user reports to the qa_reports table via Supabase.
This handler is the durable async path for QA reports.
"""
from __future__ import annotations

import logging
import os
from typing import Any

log = logging.getLogger(__name__)


async def handle_qa_response(payload: dict[str, Any]) -> None:
    """Persist a qa_response job payload to the qa_reports table."""
    try:
        from src.utils.supabase_client import create_client

        url = os.getenv("SUPABASE_URL", "").strip()
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", os.getenv("SUPABASE_KEY", "")).strip()
        if not url or not key:
            log.warning("qa_report_outbox_missing_credentials payload=%s", payload)
            return
        client = create_client(url, key)
        client.table("qa_reports").upsert(payload, on_conflict="report_id").execute()
        log.info("qa_report_persisted_via_outbox report_id=%s", payload.get("report_id"))
    except Exception as exc:
        log.error("qa_report_outbox_handler_failed report_id=%s error=%s", payload.get("report_id"), exc)
        raise
