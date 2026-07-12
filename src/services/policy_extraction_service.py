"""
Policy Extraction Service — single LLM call to extract structured policy data at ingestion time.

This replaces the mobile app's approach of sending 13 sequential questions to the backend.
Instead, the backend extracts all fields in one structured LLM call and stores the result.
The mobile app fetches the summary via a single API call.

Persistence: summaries are stored in Redis (when available) with a file-based fallback on
disk. This ensures summaries survive across requests and container restarts within the
same instance. For true multi-instance durability, see the migration note in
docs/review/go_live_blocking_issues_2026-07-11.md.
"""
import json
import logging
import os
from datetime import datetime, timezone
from typing import Optional, Dict, Any

from src.llm.client import LLMClient
from src.models.extraction import PolicySummaryExtraction

logger = logging.getLogger(__name__)

_SUMMARY_DIR = os.path.join("storage", "summaries")


class PolicyExtractionService:
    """Extract structured policy data from OCR text in a single LLM call."""

    def __init__(self, llm_client: LLMClient, redis_client=None):
        self.llm = llm_client
        self._redis = redis_client
        os.makedirs(_SUMMARY_DIR, exist_ok=True)

    def _redis_key(self, document_id: str) -> str:
        return f"policy_summary:{document_id}"

    def _store_summary(self, document_id: str, summary: Dict[str, Any]) -> None:
        """Persist summary to Redis (primary) and disk (fallback)."""
        serialized = json.dumps(summary, default=str)
        if self._redis:
            try:
                self._redis.set(self._redis_key(document_id), serialized)
                return
            except Exception as e:
                logger.warning("Redis write failed for summary %s: %s", document_id, e)
        # Disk fallback
        try:
            path = os.path.join(_SUMMARY_DIR, f"{document_id}.json")
            with open(path, "w") as f:
                f.write(serialized)
        except Exception as e:
            logger.warning("Disk write failed for summary %s: %s", document_id, e)

    def _load_summary(self, document_id: str) -> Optional[Dict[str, Any]]:
        """Load summary from Redis (primary) or disk (fallback)."""
        if self._redis:
            try:
                raw = self._redis.get(self._redis_key(document_id))
                if raw:
                    return json.loads(raw)
            except Exception as e:
                logger.warning("Redis read failed for summary %s: %s", document_id, e)
        # Disk fallback
        try:
            path = os.path.join(_SUMMARY_DIR, f"{document_id}.json")
            if os.path.exists(path):
                with open(path, "r") as f:
                    return json.loads(f.read())
        except Exception as e:
            logger.warning("Disk read failed for summary %s: %s", document_id, e)
        return None

    def _delete_summary(self, document_id: str) -> None:
        """Delete summary from both stores."""
        if self._redis:
            try:
                self._redis.delete(self._redis_key(document_id))
            except Exception:
                pass
        try:
            path = os.path.join(_SUMMARY_DIR, f"{document_id}.json")
            if os.path.exists(path):
                os.remove(path)
        except Exception:
            pass

    async def extract_summary(
        self,
        document_id: str,
        document_text: str,
        document_type: str = "Unknown",
    ) -> Optional[Dict[str, Any]]:
        """Extract structured policy summary from document text.

        Args:
            document_id: Unique document identifier
            document_text: Full text extracted from the document (OCR output)
            document_type: Inferred document type (health, auto, life, etc.)

        Returns:
            Dict matching PolicySummaryExtraction schema, or None on failure.
        """
        if not document_text or len(document_text.strip()) < 50:
            logger.warning("Insufficient text for extraction: %s", document_id)
            return None

        # Return cached result if already extracted
        cached = self._load_summary(document_id)
        if cached:
            logger.info("Returning cached summary for %s", document_id)
            return cached

        # Truncate to avoid excessive token usage — 8000 chars is ~2000 tokens
        truncated_text = document_text[:8000]

        system_prompt = (
            "You are an expert insurance document analyst. Extract all key policy "
            "information from the provided document text. Be precise and only include "
            "information that is explicitly stated in the text. If a field is not found, "
            "use null. For amounts, provide numeric values (e.g., 2500000 for ₹25 lakhs). "
            "For dates, use ISO format (YYYY-MM-DD) if possible. For lists, provide up to "
            "5 items as brief one-line descriptions."
        )

        user_prompt = (
            f"Document type (inferred): {document_type}\n\n"
            f"Document text:\n{truncated_text}\n\n"
            "Extract the following fields from this insurance document:\n"
            "- policy_number: The policy number or ID\n"
            "- insurer: Insurance company name\n"
            "- insurer_helpline: Claims/customer care phone number\n"
            "- insurer_email: Customer care email\n"
            "- document_type: Type of insurance (health, auto, life, home, travel, other)\n"
            "- coverage_amount: Total sum insured (numeric, in rupees)\n"
            "- deductible: Deductible amount (numeric, or null if not applicable)\n"
            "- premium_amount: Premium amount (numeric, in rupees)\n"
            "- premium_frequency: How often premium is paid (monthly, quarterly, half-yearly, annually)\n"
            "- effective_date: Policy start date\n"
            "- expiration_date: Policy end/expiry date\n"
            "- key_benefits: List of top 5 covered benefits (brief, one per line)\n"
            "- exclusions: List of top 5 exclusions/things not covered (brief)\n"
            "- waiting_periods: List of any waiting periods mentioned\n"
            "- coverage_items: Individual coverage line items with name, limit, covered status"
        )

        try:
            summary = await self.llm.generate_structured(
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                response_model=PolicySummaryExtraction,
                temperature=0.1,
                fallback_models=["gpt-4o-mini"],
            )

            if summary is None:
                logger.warning("LLM returned None for extraction: %s", document_id)
                return None

            # Convert to dict and add metadata
            result = summary.model_dump()
            result["document_id"] = document_id
            result["extracted_at"] = datetime.now(timezone.utc).isoformat()

            # Persist
            self._store_summary(document_id, result)

            logger.info("Policy summary extracted for %s: policy=%s, insurer=%s, coverage=%s",
                        document_id,
                        result.get("policy_number"),
                        result.get("insurer"),
                        result.get("coverage_amount"))
            return result

        except Exception as e:
            logger.error("Policy extraction failed for %s: %s", document_id, e)
            return None

    def get_summary(self, document_id: str) -> Optional[Dict[str, Any]]:
        """Get a previously extracted summary."""
        return self._load_summary(document_id)

    def delete_summary(self, document_id: str) -> None:
        """Delete a stored summary."""
        self._delete_summary(document_id)

    def get_all_summaries(self) -> Dict[str, Dict[str, Any]]:
        """Get all stored summaries."""
        summaries: Dict[str, Dict[str, Any]] = {}
        # Load from disk
        try:
            for filename in os.listdir(_SUMMARY_DIR):
                if filename.endswith(".json"):
                    doc_id = filename[:-5]
                    summary = self._load_summary(doc_id)
                    if summary:
                        summaries[doc_id] = summary
        except Exception as e:
            logger.warning("Failed to list summaries from disk: %s", e)
        # Overlay Redis keys (if available, Redis may have newer data)
        if self._redis:
            try:
                for key in self._redis.scan_iter("policy_summary:*"):
                    doc_id = key.split(":", 1)[1]
                    if doc_id not in summaries:
                        summary = self._load_summary(doc_id)
                        if summary:
                            summaries[doc_id] = summary
            except Exception as e:
                logger.warning("Failed to scan summaries from Redis: %s", e)
        return summaries
