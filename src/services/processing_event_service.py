"""Append-only durable processing stage history."""

from __future__ import annotations

import os
from typing import Any, Optional

from src.utils.runtime_config import supabase_server_key


class ProcessingEventService:
    def __init__(self, client: Optional[Any] = None):
        if client is not None:
            self._client = client
            return
        url = os.getenv("SUPABASE_URL", "").strip()
        key = supabase_server_key()
        if not url or not key:
            raise RuntimeError("Supabase processing event configuration is required")
        from supabase import create_client
        self._client = create_client(url, key)

    def append(
        self,
        document_id: str,
        owner_id: str,
        stage: str,
        progress: int,
        attempt: int = 0,
        error_class: Optional[str] = None,
    ) -> None:
        if stage == "failed":
            state = "failed"
        elif progress >= 100:
            state = "completed"
        elif progress == 0:
            state = "started"
        else:
            state = "in_progress"
        self._client.table("processing_events").insert({
            "document_id": document_id,
            "owner_id": owner_id,
            "stage": stage,
            "state": state,
            "progress": max(0, min(progress, 100)),
            "attempt": max(attempt, 0),
            "error_class": error_class[:120] if error_class else None,
        }).execute()
