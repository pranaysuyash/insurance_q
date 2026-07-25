"""Evidence substrate service (Trust Phase 1 access layer).

This is the ONLY module in the codebase that writes to the four
substrate tables (page_artifacts, source_spans, extracted_fields,
field_evidence). Per motto v3 §0.1, no parallel paths: every
parser, every UI surface, every Q&A caller that needs evidence
goes through this module. The interface is append-only by intent
(append_*, not create_* or insert_*) because the substrate is
append-only by design.

The database enforces RLS such that only the service role can
read or write these tables. Owner-scoping is enforced in the
WHERE clauses of this module, not in RLS, to match the
canonical SupabaseDocumentRepository pattern in
src/services/document_repository.py.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
from typing import Iterable, Optional
from uuid import UUID

from src.models.evidence import (
    ExtractedFieldRecord,
    ExtractedValue,
    ExtractionCostRecord,
    FieldCitation,
    PageArtifact,
    ParserKind,
    SourceSpan,
    SourceSpanRecord,
    ValueType,
)
from src.utils.runtime_config import supabase_server_key

# Substrate face constants (ADR-2026-07-19-09 Face 1)
# The minimum evidence_strength for a field to be considered "evidence-backed"
# at the substrate face. Values below this are excluded from evidence-backed answers.
SUBSTRATE_EVIDENCE_THRESHOLD = 0.7

# The current production parser version. Fields extracted by a deprecated
# parser version are not considered evidence-backed — stale extractions
# may refer to an older document format or extraction strategy.
CURRENT_PARSER_VERSION = "coverwise.document-intelligence.v1"

log = logging.getLogger(__name__)


class EvidenceSubstrateError(Exception):
    """Base for all substrate service errors."""


class EvidenceSubstrateUnavailable(EvidenceSubstrateError):
    """The Supabase client cannot be initialized. The API must
    return 503 (or refuse the call) rather than fall back to an
    in-memory store. Per Trust Phase 0, the policy detail screen
    shows the 'Not yet verified' scaffold; that's the honest UI
    for an empty or unavailable substrate."""


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _source_span_fingerprint(row: dict) -> str:
    """Return a stable identity for one logical span.

    The current schema predates an explicit span key, so the access layer
    derives one from the immutable span fields while the schema remains
    append-only. This makes sequential retries repair partial writes without
    creating a second logical span.
    """

    payload = {
        "span_text": row.get("span_text"),
        "bbox_json": row.get("bbox_json"),
        "span_type": row.get("span_type"),
        "confidence": row.get("confidence"),
        "parser_version": row.get("parser_version"),
    }
    return hashlib.sha256(
        json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    ).hexdigest()


class EvidenceSubstrateService:
    """Typed access layer for the four evidence substrate tables.

    Append-only by intent. Every write returns the row id. Read
    methods return typed Pydantic models from src.models.evidence.
    """

    def __init__(
        self,
        supabase_url: str,
        service_role_key: str,
        client: Optional[object] = None,
    ):
        if client is not None:
            self._client = client
            return
        if not supabase_url or not service_role_key:
            raise EvidenceSubstrateUnavailable(
                "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for the evidence substrate"
            )
        try:
            from src.utils.supabase_client import create_client
        except ImportError as error:  # pragma: no cover - deployment dependency
            raise EvidenceSubstrateUnavailable(
                "supabase package is required for the evidence substrate"
            ) from error
        self._client = create_client(supabase_url, service_role_key)

    @staticmethod
    def from_env() -> "EvidenceSubstrateService":
        url = os.getenv("SUPABASE_URL", "").strip()
        key = supabase_server_key()
        if not url or not key:
            raise EvidenceSubstrateUnavailable(
                "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set"
            )
        return EvidenceSubstrateService(url, key)

    # --- page_artifacts ---

    async def append_page_artifact(
        self,
        document_id: UUID,
        page_number: int,
        page_image_bytes: bytes,
        ocr_text: Optional[str] = None,
        layout_json: Optional[dict] = None,
        image_uri: Optional[str] = None,
    ) -> UUID:
        """Write one page artifact. Returns its page_artifact id.

        Replaying the same document/page and image is idempotent: the existing
        row is returned. A replay with different bytes is rejected rather than
        silently replacing source evidence.

        The image_uri is generated if not supplied, using the
        canonical storage path: coverwise-documents/{document_id}/pages/{page_number}.png
        The caller is responsible for uploading the page image
        bytes to that URI before calling this method, or the
        page will be referenced but not retrievable. The page
        SHA-256 is computed from the bytes; a mismatch between
        the uploaded bytes and the SHA in the row is a data
        integrity bug and will be flagged by the policy detail
        screen.
        """
        if page_number < 1:
            raise EvidenceSubstrateError("page_number must be >= 1")
        if not page_image_bytes:
            raise EvidenceSubstrateError("page_image_bytes must not be empty")
        if not image_uri:
            image_uri = (
                f"coverwise-documents/{document_id}/pages/{page_number}.png"
            )
        sha = _sha256_bytes(page_image_bytes)
        row = {
            "document_id": str(document_id),
            "page_number": page_number,
            "image_uri": image_uri,
            "ocr_text": ocr_text,
            "layout_json": layout_json,
            "sha256": sha,
        }
        existing = self._find_page_artifact(document_id, page_number)
        if existing is not None:
            if existing.get("sha256") != sha or existing.get("image_uri") != image_uri:
                raise EvidenceSubstrateError(
                    f"page_artifact conflict for document {document_id} page {page_number}"
                )
            return UUID(existing["id"])
        try:
            response = (
                self._client.table("page_artifacts")
                .insert(row)
                .execute()
            )
        except Exception as error:
            # A concurrent retry can win the unique (document_id, page_number)
            # constraint between the read and insert. Re-read and accept only
            # the same immutable artifact; preserve other database failures.
            existing = self._find_page_artifact(document_id, page_number)
            if existing is None:
                raise EvidenceSubstrateError(
                    f"page_artifacts insert failed for document {document_id} page {page_number}"
                ) from error
            if existing.get("sha256") != sha or existing.get("image_uri") != image_uri:
                raise EvidenceSubstrateError(
                    f"page_artifact conflict for document {document_id} page {page_number}"
                ) from error
            return UUID(existing["id"])
        if not response.data:
            raise EvidenceSubstrateError(
                f"page_artifacts insert returned no rows for document {document_id} page {page_number}"
            )
        return UUID(response.data[0]["id"])

    def _find_page_artifact(self, document_id: UUID, page_number: int) -> Optional[dict]:
        response = (
            self._client.table("page_artifacts")
            .select("id, image_uri, sha256")
            .eq("document_id", str(document_id))
            .eq("page_number", page_number)
            .limit(1)
            .execute()
        )
        rows = getattr(response, "data", None)
        if isinstance(rows, list) and rows:
            return rows[0]
        return None

    # --- source_spans ---

    async def append_source_spans(
        self, page_artifact_id: UUID, spans: Iterable[SourceSpan]
    ) -> list[UUID]:
        """Write one or more spans for a page. Returns the new span ids.

        All spans in a single call must be for the same
        page_artifact_id. The caller has already verified that
        the page_artifact exists; this method does not re-verify.
        """
        rows = []
        for span in spans:
            rows.append(
                {
                    "page_artifact_id": str(page_artifact_id),
                    "span_text": span.span_text,
                    "bbox_json": span.bbox_json,
                    "span_type": span.span_type.value,
                    "confidence": span.confidence,
                    "parser_version": span.parser_version,
                }
            )
        if not rows:
            return []
        existing_response = (
            self._client.table("source_spans")
            .select("id, span_text, bbox_json, span_type, confidence, parser_version")
            .eq("page_artifact_id", str(page_artifact_id))
            .execute()
        )
        existing_rows = getattr(existing_response, "data", None)
        existing_by_fingerprint = {
            _source_span_fingerprint(existing): existing["id"]
            for existing in existing_rows
            if isinstance(existing_rows, list) and isinstance(existing, dict)
        }
        missing_rows = [
            row for row in rows
            if _source_span_fingerprint(row) not in existing_by_fingerprint
        ]
        inserted_rows = []
        if missing_rows:
            response = (
                self._client.table("source_spans").insert(missing_rows).execute()
            )
            if not response.data:
                raise EvidenceSubstrateError(
                    f"source_spans bulk insert returned no rows for page_artifact {page_artifact_id}"
                )
            inserted_rows = response.data
        inserted_by_fingerprint = {
            _source_span_fingerprint(inserted): inserted["id"]
            for inserted in inserted_rows
        }
        result_ids = []
        for row in rows:
            fingerprint = _source_span_fingerprint(row)
            row_id = existing_by_fingerprint.get(fingerprint)
            if row_id is None:
                row_id = inserted_by_fingerprint.get(fingerprint)
            if row_id is None:
                raise EvidenceSubstrateError(
                    f"source_spans replay could not resolve row for page_artifact {page_artifact_id}"
                )
            result_ids.append(UUID(row_id))
        return result_ids

    # --- extracted_fields ---

    async def append_extracted_field(
        self,
        document_id: UUID,
        field_name: str,
        value: ExtractedValue,
        value_type: ValueType,
        confidence: float,
        parser_version: str,
        parser_kind: ParserKind,
    ) -> UUID:
        """Write one extracted_field row. Returns the new id.

        To 'change' a field, write a new row with a new
        parser_version. The UI shows the latest by created_at; the
        substrate never updates in place. This is the append-only
        contract.
        """
        if not field_name:
            raise EvidenceSubstrateError("field_name must not be empty")
        if not parser_version:
            raise EvidenceSubstrateError("parser_version must not be empty")
        if not 0.0 <= confidence <= 1.0:
            raise EvidenceSubstrateError("confidence must be in [0.0, 1.0]")
        row = {
            "document_id": str(document_id),
            "field_name": field_name,
            "value": value.model_dump(),
            "value_type": value_type.value,
            "confidence": confidence,
            "parser_version": parser_version,
            "parser_kind": parser_kind.value,
        }
        response = (
            self._client.table("extracted_fields").insert(row).execute()
        )
        if not response.data:
            raise EvidenceSubstrateError(
                f"extracted_fields insert returned no rows for document {document_id} field {field_name}"
            )
        return UUID(response.data[0]["id"])

    # --- field_evidence ---

    async def link_field_evidence(
        self,
        extracted_field_id: UUID,
        page_artifact_id: UUID,
        cite_string: str,
        evidence_strength: float = 1.0,
        source_span_id: Optional[UUID] = None,
    ) -> UUID:
        """Link an extracted_field to the page (and optional span) it
        came from. Returns the new field_evidence id.

        cite_string is the human-readable citation shown in the
        UI ("page 4, paragraph 3"). The substrate generates this
        at write time so the UI never invents it.

        evidence_strength in [0.0, 1.0] is the parser's confidence
        that this specific page+span is the source of the field.
        Multiple field_evidence rows per field are allowed; the
        v_field_citations view returns the strongest one.
        """
        if not cite_string:
            raise EvidenceSubstrateError("cite_string must not be empty")
        if not 0.0 <= evidence_strength <= 1.0:
            raise EvidenceSubstrateError(
                "evidence_strength must be in [0.0, 1.0]"
            )
        row = {
            "extracted_field_id": str(extracted_field_id),
            "page_artifact_id": str(page_artifact_id),
            "source_span_id": str(source_span_id) if source_span_id else None,
            "cite_string": cite_string,
            "evidence_strength": evidence_strength,
        }
        response = (
            self._client.table("field_evidence").insert(row).execute()
        )
        if not response.data:
            raise EvidenceSubstrateError(
                f"field_evidence insert returned no rows for extracted_field {extracted_field_id}"
            )
        return UUID(response.data[0]["id"])

    # --- extraction cost tracking ---

    async def record_extraction_cost(self, record: ExtractionCostRecord) -> UUID:
        """Write one row to evidence_extraction_costs. The
        evidence pipeline calls this for every extracted_field,
        with cost_usd=0 for deterministic extraction and the
        actual cost in USD for LLM extraction."""
        row = {
            "document_id": record.document_id,
            "extracted_field_id": record.extracted_field_id,
            "parser_kind": record.parser_kind.value,
            "model": record.model,
            "prompt_tokens": record.prompt_tokens,
            "completion_tokens": record.completion_tokens,
            "cost_usd": float(record.cost_usd) if record.cost_usd is not None else None,
        }
        response = (
            self._client.table("evidence_extraction_costs")
            .insert(row)
            .execute()
        )
        if not response.data:
            raise EvidenceSubstrateError(
                f"evidence_extraction_costs insert returned no rows for document {record.document_id}"
            )
        return UUID(response.data[0]["id"])

    # --- reads (the only paths the UI uses) ---

    async def get_field_citations(
        self,
        document_id: UUID,
        field_names: Optional[list[str]] = None,
    ) -> list[FieldCitation]:
        """Read v_field_citations for a document. This is the
        ONLY method the policy detail screen calls to render
        verified fields. One query, no app-code joins.

        field_names optionally filters to a subset of fields
        (e.g. ['sum_insured','room_rent_cap']). If None, returns
        every cited field for the document.
        """
        query = (
            self._client.table("v_field_citations")
            .select("*")
            .eq("document_id", str(document_id))
        )
        if field_names:
            query = query.in_("field_name", field_names)
        response = query.execute()
        if not response.data:
            return []
        return [FieldCitation.model_validate(row) for row in response.data]

    async def get_page_artifacts_for_document(
        self, document_id: UUID
    ) -> list[PageArtifact]:
        """All page artifacts for a document, in page_number order.
        Used by the policy detail screen to render the page strip
        and the page-image tap targets."""
        response = (
            self._client.table("page_artifacts")
            .select("*")
            .eq("document_id", str(document_id))
            .order("page_number", desc=False)
            .execute()
        )
        if not response.data:
            return []
        return [PageArtifact.model_validate(row) for row in response.data]

    async def get_source_spans_for_page(
        self, page_artifact_id: UUID
    ) -> list[SourceSpanRecord]:
        """All spans for a page. Used by the future span-highlight
        overlay; v1 of the policy detail screen does not call
        this but it is here for the v2 highlight work."""
        response = (
            self._client.table("source_spans")
            .select("*")
            .eq("page_artifact_id", str(page_artifact_id))
            .execute()
        )
        if not response.data:
            return []
        return [SourceSpanRecord.model_validate(row) for row in response.data]

    async def get_extracted_fields_for_document(
        self, document_id: UUID
    ) -> list[ExtractedFieldRecord]:
        """All extracted fields for a document, regardless of
        whether they have field_evidence rows. Used by the
        evidence_pipeline to find fields that still need
        citation links."""
        response = (
            self._client.table("extracted_fields")
            .select("*")
            .eq("document_id", str(document_id))
            .order("created_at", desc=False)
            .execute()
        )
        if not response.data:
            return []
        return [
            ExtractedFieldRecord.model_validate(row) for row in response.data
        ]

    # --- convenience helpers for the parser pipeline ---

    # --- substrate face check (ADR-2026-07-19-09 Face 1) ---

    async def is_substrate_backed(
        self,
        field_id: UUID,
        principal_id: str,
    ) -> bool:
        """Check if an extracted field passes the 5-condition substrate face contract.

        Returns True only when all 5 conditions are met:
          1. Field exists in extracted_fields table.
          2. At least one linked field_evidence row has evidence_strength >= 0.7.
          3. Field's parser_version matches the current production parser.
          4. Field's document is owned by the given principal_id.
          5. Field has at least one linked field_evidence row (the citation pointer).

        Conditions 2 and 5 share one query; condition 5 is implicitly satisfied
        when condition 2's query returns at least one row.
        """
        # Condition 1: field exists in extracted_fields
        field_response = (
            self._client.table("extracted_fields")
            .select("id, document_id, parser_version")
            .eq("id", str(field_id))
            .limit(1)
            .execute()
        )
        field_rows = getattr(field_response, "data", None)
        if not field_rows:
            return False

        field = field_rows[0]

        # Condition 3: parser_version matches current production parser
        if field.get("parser_version") != CURRENT_PARSER_VERSION:
            return False

        # Condition 4: document owner matches principal
        document_id = field.get("document_id")
        if not document_id:
            return False

        doc_response = (
            self._client.table("documents")
            .select("owner_id")
            .eq("id", document_id)
            .limit(1)
            .execute()
        )
        doc_rows = getattr(doc_response, "data", None)
        if not doc_rows:
            return False
        if doc_rows[0].get("owner_id") != principal_id:
            return False

        # Conditions 2 & 5: field has field_evidence with evidence_strength >= 0.7
        evidence_response = (
            self._client.table("field_evidence")
            .select("evidence_strength")
            .eq("extracted_field_id", str(field_id))
            .execute()
        )
        evidence_rows = getattr(evidence_response, "data", None)
        if not evidence_rows:
            return False  # Condition 5: no field_evidence rows

        # Condition 2: at least one evidence row with strength >= threshold
        max_strength = max(
            (row.get("evidence_strength", 0.0) for row in evidence_rows),
            default=0.0,
        )
        if max_strength < SUBSTRATE_EVIDENCE_THRESHOLD:
            return False

        return True

    async def cite_field_at_page(
        self,
        extracted_field_id: UUID,
        page_artifact_id: UUID,
        page_number: int,
        source_span_id: Optional[UUID] = None,
        evidence_strength: float = 1.0,
    ) -> UUID:
        """Cite a field at a specific page with a generated
        cite_string. The parser pipeline calls this when it
        knows which page a field came from but has not parsed
        the bounding box yet (v1 of the layout parser only
        does page-level citation; v2 will compute per-span)."""
        cite = f"page {page_number}"
        if source_span_id:
            cite += ", span"
        return await self.link_field_evidence(
            extracted_field_id=extracted_field_id,
            page_artifact_id=page_artifact_id,
            source_span_id=source_span_id,
            cite_string=cite,
            evidence_strength=evidence_strength,
        )
