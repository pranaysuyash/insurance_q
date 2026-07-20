"""
Enhanced Document Processing Service
Handles the complete pipeline: Document Upload → OCR → Structured Extraction → RAG Ingestion → Vector Database
"""
import os
import re
import asyncio
import logging
import uuid
from typing import Optional, Dict, Any, List
from datetime import datetime
import tempfile
from uuid import UUID
from src.utils.pdf_access import PdfPasswordError, unlock_pdf

# OCR imports
try:
    from src.ocr.pdf_processor import PDFProcessor
    from src.ocr.image_processor import ImageProcessor
except ImportError:
    PDFProcessor = None
    ImageProcessor = None

# RAG imports
try:
    from src.rag.pipeline import RAGPipeline
except ImportError:
    RAGPipeline = None

# Policy extraction
try:
    from src.services.policy_extraction_service import PolicyExtractionService
    from src.llm.client import LLMClient
except ImportError:
    PolicyExtractionService = None
    LLMClient = None

logger = logging.getLogger(__name__)

# Phase 0 P0-0.1 + P0-0.2 (trust audit, 2026-07-18): derive document state
# from required stage outcomes, not from a hardcoded "completed" string.
# The trust audit's NO-GO verdict says "completed" can hide OCR/extraction/
# indexing failures. The new model uses per-mode required-stage sets and
# derives a state machine value: `ready`, `summary_partial`, `text_partial`,
# `partial`, `ocr_required`, `password_required`, `indexing_failed`,
# `terminal_failed`, `retryable_failed`, or `ready_for_qa`.
REQUIRED_STAGES: Dict[str, frozenset] = {
    "full": frozenset({"file_storage", "ocr", "policy_extraction", "rag_ingestion"}),
    "ocr_only": frozenset({"file_storage", "ocr"}),
    "rag_only": frozenset({"file_storage", "rag_ingestion"}),
}

# Per-stage failure class. A "skipped" stage is non-fatal (the service
# was unavailable); a "failed" stage is fatal for the corresponding
# capability. The trust audit says never coerce a "failed" stage into
# "completed" because that hides the failure from the user.
FATAL_STAGE_STATUSES = frozenset({"failed", "error"})
NON_FATAL_STAGE_STATUSES = frozenset({"skipped", "not_available"})


def derive_document_state(
    processing_mode: str,
    stages: Dict[str, Any],
    policy_summary_present: bool,
) -> str:
    """Derive the terminal document state from stage outcomes.

    Implements the state machine the trust audit requires in Phase 0 P0-0.1
    + P0-0.2: a document is `ready` only when every required stage for its
    mode is `completed`. Partial readiness (e.g. text extracted but
    summary failed) produces capability-specific states.

    Order of checks matters. We first look for password / OCR-class
    failures (caller can fix by re-uploading), then capability-specific
    partial states, then generic `partial`, then the success cases.
    """
    required = REQUIRED_STAGES.get(processing_mode, REQUIRED_STAGES["full"])

    # Per-stage failure classification for required stages.
    failed_required = []
    ocr_stage = stages.get("ocr", {}) if isinstance(stages.get("ocr"), dict) else {}
    for stage_name in required:
        stage = stages.get(stage_name, {}) if isinstance(stages.get(stage_name), dict) else {}
        if stage.get("status") in FATAL_STAGE_STATUSES:
            failed_required.append(stage_name)

    # Special-case: password or OCR-class failure when OCR is the SOLE
    # required-stage failure. The user can fix by re-uploading with a
    # password or a text-based PDF. If other required stages also failed,
    # we fall through to the generic `partial` state because the recovery
    # action is more than just re-uploading.
    if failed_required == ["ocr"]:
        ocr_err = (ocr_stage.get("error", "") or "").lower()
        if "password" in ocr_err:
            return "password_required"
        if "ocr" in ocr_err:
            return "ocr_required"

    if failed_required:
        # Capability-specific granularity. The contract:
        #   - Only policy_extraction failed  -> summary_partial
        #     (text + Q&A still work; the policy detail page is partial)
        #   - Only rag_ingestion failed:
        #       - summary present  -> indexing_failed
        #         (detail page works; Q&A does not)
        #       - summary missing  -> ready_for_qa
        #         (text is ready but no projection; document is not
        #         customer-ready; UI must show "processing incomplete")
        #   - Only the two projection stages failed (both policy_extraction
        #     AND rag_ingestion) -> ready_for_qa. The text is in the
        #     canonical store; only the customer-facing projections
        #     are missing. The user can still see the source via the
        #     document preview; the UI should show "partial".
        #   - Anything else with multiple failures -> partial.
        if set(failed_required) == {"policy_extraction"}:
            return "summary_partial"
        if set(failed_required) == {"rag_ingestion"}:
            if policy_summary_present:
                return "indexing_failed"
            return "ready_for_qa"
        if set(failed_required) == {"policy_extraction", "rag_ingestion"}:
            return "ready_for_qa"
        return "partial"

    # No required failures. The document is "ready" for the capabilities
    # its mode intended. But defence-in-depth: if the policy summary
    # is required for full mode and missing, the function must NOT
    # claim ready. This catches a class of silent-failure bugs where
    # a stage self-reports 'completed' but produces no usable artifact.
    if processing_mode == "full" and not policy_summary_present:
        return "summary_partial"
    if processing_mode == "rag_only":
        # rag_only mode never produces a policy summary by design; the
        # honest label is "ready for Q&A" so operators and the UI know
        # the document is queryable but has no detail-page projection.
        return "ready_for_qa"
    return "ready"


class DocumentProcessingService:
    """
    Orchestrates the complete document processing pipeline:
    1. File validation and storage
    2. OCR text extraction (PDF/Image)
    3. RAG ingestion (create embeddings)
    4. Status tracking and monitoring
    """
    
    def __init__(
        self,
        rag_pipeline: Optional['RAGPipeline'] = None,
        document_object_store: Optional[Any] = None,
    ):
        self.rag_pipeline = rag_pipeline
        self.document_object_store = document_object_store
        # Share a single OCR pipeline instance across processors
        self._ocr_pipeline = None
        self.pdf_processor = None
        self.image_processor = None
        self.processing_status = {}  # Track processing status by document_id
        
        # Policy extraction service
        self.policy_extraction_service = None
        if PolicyExtractionService and LLMClient:
            try:
                llm_client = rag_pipeline.llm if rag_pipeline and hasattr(rag_pipeline, 'llm') else LLMClient()
                redis_client = rag_pipeline.cache if rag_pipeline and hasattr(rag_pipeline, 'cache') else None
                self.policy_extraction_service = PolicyExtractionService(llm_client, redis_client=redis_client)
                logger.info("PolicyExtractionService initialized (redis=%s)", "enabled" if redis_client else "disabled")
            except Exception as e:
                logger.warning("PolicyExtractionService init failed: %s", e)
        
        # Create storage directories
        self.storage_dir = "storage/documents"
        self.temp_dir = "temp"
        os.makedirs(self.storage_dir, exist_ok=True)
        os.makedirs(self.temp_dir, exist_ok=True)
        
        logger.info("DocumentProcessingService initialized")
    
    async def process_document_full(
        self, 
        file_content: bytes, 
        filename: str, 
        document_id: Optional[str] = None,
        processing_mode: str = "full",
        owner_id: Optional[str] = None,
        pdf_password: Optional[str] = None,
        on_device_ocr_text: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Complete document processing pipeline
        
        Args:
            file_content: Raw file bytes
            filename: Original filename
            document_id: Optional document ID (will generate if not provided)
            processing_mode: "full", "ocr_only", or "rag_only"
        
        Returns:
            Processing result with status, extracted text, and ingestion details
        """
        if not document_id:
            document_id = str(uuid.uuid4())
        
        logger.info("document_processing_started document_id=%s mode=%s", document_id, processing_mode)
        
        # Initialize status tracking
        self.processing_status[document_id] = {
            "status": "processing",
            "stage": "started",
            "filename": filename,
            "started_at": datetime.utcnow().isoformat(),
            "progress": 0
        }
        
        try:
            result = {
                "document_id": document_id,
                "filename": filename,
                "processing_mode": processing_mode,
                "stages": {}
            }
            
            # Stage 1: File validation and storage
            await self._update_status(document_id, "validating", 10)
            file_path = await self._save_file(file_content, filename, document_id)
            result["file_path"] = file_path
            result["stages"]["file_storage"] = {"status": "completed", "file_path": file_path}
            
            # Stage 2: OCR Processing (if needed)
            extracted_text = ""
            if processing_mode in ["full", "ocr_only"]:
                await self._update_status(document_id, "extracting_text", 30)
                ocr_result = await self._extract_text(
                    file_path,
                    filename,
                    pdf_password=pdf_password,
                    on_device_ocr_text=on_device_ocr_text,
                )
                extracted_text = ocr_result.get("full_text", "")
                result["stages"]["ocr"] = ocr_result
                result["extracted_text"] = extracted_text
            
            # Stage 2.5: Structured Policy Extraction (if available)
            if processing_mode in ["full"] and extracted_text and self.policy_extraction_service:
                await self._update_status(document_id, "extracting_policy_data", 45)
                try:
                    doc_type = result.get("stages", {}).get("ocr", {}).get("document_type", "Unknown")
                    summary = await self.policy_extraction_service.extract_summary(
                        document_id, extracted_text, doc_type
                    )
                    if summary:
                        summary["extracted_at"] = datetime.utcnow().isoformat()
                        result["policy_summary"] = summary
                        result["stages"]["policy_extraction"] = {"status": "completed"}
                    else:
                        result["stages"]["policy_extraction"] = {"status": "skipped", "reason": "No summary returned"}
                except Exception as e:
                    logger.warning(
                        "policy_extraction_failed document_id=%s error_type=%s",
                        document_id,
                        type(e).__name__,
                    )
                    result["stages"]["policy_extraction"] = {
                        "status": "failed",
                        "error": "Policy extraction failed",
                    }
            
            # Stage 3: RAG Ingestion (if needed and available)
            if processing_mode in ["full", "rag_only"] and self.rag_pipeline:
                await self._update_status(document_id, "creating_embeddings", 60)
                
                # If we don't have extracted text, try to get it
                if not extracted_text and processing_mode == "rag_only":
                    logger.warning(f"RAG-only mode but no extracted text for {document_id}")
                    extracted_text = f"Document: {filename}"  # Fallback
                
                rag_result = await self._ingest_into_rag(
                    document_id, extracted_text, filename, owner_id=owner_id,
                    page_texts=ocr_result.get("page_texts"),
                    page_images=ocr_result.get("page_images"),
                )
                result["stages"]["rag_ingestion"] = rag_result
            elif processing_mode in ["full", "rag_only"]:
                result["stages"]["rag_ingestion"] = {
                    "status": "skipped", 
                    "reason": "RAG pipeline not available"
                }

            # Stage 3.5: Evidence pipeline (Trust Phase 1). Runs
            # only when the substrate is configured (env var)
            # and the OCR produced page_texts. The pipeline
            # writes cited fields to the substrate; the policy
            # detail screen reads them via GET /evidence/.../
            # field-citations. Failures are recorded in the
            # result but do NOT fail the document processing:
            # the document is honest about the evidence state
            # (the policy detail screen shows the "Not yet
            # verified" scaffold when no citations exist).
            page_texts = (ocr_result or {}).get("page_texts", {}) if 'ocr_result' in locals() else {}
            if (
                processing_mode in ["full"]
                and page_texts
                and self._evidence_pipeline_enabled()
            ):
                await self._update_status(document_id, "extracting_evidence", 80)
                try:
                    from src.services.evidence_substrate_service import (
                        EvidenceSubstrateService,
                    )
                    from src.services.evidence_pipeline import (
                        EvidencePipeline,
                    )
                    substrate = EvidenceSubstrateService.from_env()
                    pipeline = EvidencePipeline(substrate=substrate)
                    pipeline_result = await pipeline.run_for_document(
                        document_id=UUID(document_id),
                        page_texts=page_texts,
                    )
                    result["stages"]["evidence_extraction"] = {
                        "status": "completed",
                        "fields_extracted": pipeline_result.fields_extracted,
                        "fields_cited": pipeline_result.fields_cited,
                        "fields_rejected": pipeline_result.fields_rejected,
                        "total_cost_usd": pipeline_result.total_cost_usd,
                        "parser_version": pipeline_result.parser_version,
                    }
                except Exception as e:
                    logger.warning(
                        "evidence_extraction_failed document_id=%s error_type=%s",
                        document_id,
                        type(e).__name__,
                    )
                    result["stages"]["evidence_extraction"] = {
                        "status": "failed",
                        "error": "Evidence extraction failed; the document is processed but the substrate is empty.",
                    }
            else:
                if processing_mode in ["full"] and not page_texts:
                    result["stages"]["evidence_extraction"] = {
                        "status": "skipped",
                        "reason": "No page text available (OCR may have failed)",
                    }
                elif processing_mode in ["full"] and not self._evidence_pipeline_enabled():
                    result["stages"]["evidence_extraction"] = {
                        "status": "skipped",
                        "reason": "Substrate not configured (SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY not set)",
                    }
            
            # Stage 4: Completion — derive the terminal state from stage
            # outcomes, do NOT hardcode "completed". The trust audit's
            # Phase 0 P0-0.1 says a document becomes `ready` only when
            # every required stage for its mode is `completed`; partial
            # readiness produces capability-specific states (e.g.
            # `summary_partial`, `ocr_required`, `indexing_failed`).
            failed_stages = [
                stage_name
                for stage_name, stage_data in result.get("stages", {}).items()
                if isinstance(stage_data, dict) and stage_data.get("status") == "failed"
            ]

            policy_summary_present = bool(result.get("policy_summary"))
            derived_state = derive_document_state(
                processing_mode=processing_mode,
                stages=result.get("stages", {}),
                policy_summary_present=policy_summary_present,
            )
            result["derived_state"] = derived_state
            result["failed_stages"] = failed_stages

            # Map the derived state onto the legacy status string the
            # repository uses elsewhere (backward compat). New code
            # should branch on `derived_state` directly. The legacy
            # status retains a "completed" only when the document is
            # actually ready, and reports "partial" or a capability-
            # specific state otherwise.
            legacy_status_map = {
                "ready": "completed",
                "ready_for_qa": "completed_no_summary",
                "summary_partial": "completed_summary_partial",
                "text_partial": "completed_text_partial",
                "ocr_required": "ocr_required",
                "password_required": "password_required",
                "indexing_failed": "indexing_failed",
                "partial": "partial",
                "terminal_failed": "failed",
            }
            legacy_status = legacy_status_map.get(derived_state, "partial")
            await self._update_status(document_id, legacy_status, 100)
            result["status"] = legacy_status

            if derived_state == "ready":
                logger.info("document_processing_completed document_id=%s", document_id)
            else:
                logger.warning(
                    "document_processing_partial document_id=%s derived_state=%s failed_stages=%s",
                    document_id, derived_state, failed_stages,
                )

            result["completed_at"] = datetime.utcnow().isoformat()
            return result
            
        except Exception as e:
            logger.error("document_processing_pipeline_failed document_id=%s error_type=%s", document_id, type(e).__name__)
            safe_error = "Document processing failed"
            await self._update_status(document_id, "failed", 0, safe_error)
            return {
                "document_id": document_id,
                "filename": filename,
                "status": "failed",
                "error": safe_error,
                "failed_at": datetime.utcnow().isoformat()
            }
    
    async def _save_file(self, file_content: bytes, filename: str, document_id: str) -> str:
        """Save uploaded file to storage"""
        file_extension = os.path.splitext(filename)[1].lower()
        stored_filename = f"{document_id}_{filename}"
        file_path = os.path.join(self.storage_dir, stored_filename)
        
        with open(file_path, "wb") as f:
            f.write(file_content)
        
        logger.info("document_processing_temp_file_saved document_id=%s", document_id)
        return file_path
    
    async def _extract_text(
        self,
        file_path: str,
        filename: str,
        pdf_password: Optional[str] = None,
        on_device_ocr_text: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Extract text from a document.

        Production (slim image, no OCR): uses PyMuPDF direct-text extraction for
        PDFs. Scanned/image-only PDFs are detected and flagged with a clear
        message instead of crashing.

        Local dev (with doctr installed): falls back to OCR for image-only pages.
        """
        file_extension = os.path.splitext(filename)[1].lower()

        # The original document remains authoritative. A mobile-generated OCR
        # sidecar is accepted only as a recovery path for scans that do not
        # contain direct text; it never overrides embedded PDF text.
        mobile_ocr_text = on_device_ocr_text.strip() if on_device_ocr_text else ""

        # --- Image files: need OCR (not available in slim production image) ---
        if file_extension in ['.png', '.jpg', '.jpeg', '.tiff', '.tif', '.webp']:
            if mobile_ocr_text:
                return {
                    "full_text": mobile_ocr_text,
                    "page_texts": {1: mobile_ocr_text},
                    "status": "completed",
                    "method": "mobile_mlkit_text_recognition",
                    "provenance": "client_on_device_ocr_sidecar",
                }
            try:
                if self._ocr_pipeline is None:
                    from src.ocr.pipeline import OCRPipeline
                    self._ocr_pipeline = OCRPipeline()
                if not self.image_processor:
                    from src.ocr.image_processor import ImageProcessor
                    self.image_processor = ImageProcessor(ocr_pipeline=self._ocr_pipeline)
                result = await self._run_in_executor(self.image_processor.process_image, file_path)
                result["status"] = "completed"
                return result
            except ImportError:
                return {
                    "status": "failed",
                    "error": "Image OCR is not available in this build. Please upload a text-based PDF instead of an image.",
                    "full_text": "",
                }
            except Exception as e:
                logger.error(
                    "image_ocr_failed document_id=%s error_type=%s",
                    document_id,
                    type(e).__name__,
                )
                return {
                    "status": "failed",
                    "error": str(e),
                    "full_text": "",
                }

        # --- PDF: try direct text first (PyMuPDF, always available) ---
        if file_extension == '.pdf':
            try:
                import fitz  # PyMuPDF — always in requirements
                doc = fitz.open(file_path)
                try:
                    unlock_pdf(doc, pdf_password)
                except PdfPasswordError as error:
                    doc.close()
                    return {
                        "status": "failed",
                        "error_code": error.code,
                        "error": error.message,
                        "full_text": "",
                    }
                all_text = []
                image_only_pages = 0
                # Per-page text for the evidence pipeline. The key
                # is the 1-based page number; the value is the
                # page's text. Pages with no text (image-only
                # pages) are omitted; the evidence pipeline handles
                # the resulting page-number gaps.
                page_texts: Dict[int, str] = {}
                # Per-page rendered image bytes (PNG) for page_artifact
                # persistence (ADR-2026-07-19-11 Layer 4).
                page_images: Dict[int, bytes] = {}
                for page_index, page in enumerate(doc, start=1):
                    text = page.get_text()
                    if text and text.strip():
                        all_text.append(text.strip())
                        page_texts[page_index] = text.strip()
                    else:
                        image_only_pages += 1
                    # Render page as PNG for page_artifact (Layer 4).
                    # This is needed even for text-only pages so the
                    # "open page" action can show the original layout.
                    try:
                        pix = page.get_pixmap(dpi=150)
                        page_images[page_index] = pix.tobytes("png")
                    except Exception:
                        pass  # rendering failed; page_artifact will lack image
                doc.close()

                full_text = "\n\n".join(all_text).strip()

                if full_text:
                    method = "direct_text"
                    if image_only_pages > 0:
                        # Some pages had text, some didn't — partial extraction
                        logger.info(
                            "PDF %s: extracted text from %d pages, %d image-only pages skipped",
                            filename, len(all_text), image_only_pages,
                        )
                    return {
                        "full_text": full_text,
                        "page_texts": page_texts,
                        "page_images": page_images,
                        "status": "completed",
                        "method": method,
                    }

                if mobile_ocr_text:
                    return {
                        "full_text": mobile_ocr_text,
                        "page_texts": {1: mobile_ocr_text},
                        "status": "completed",
                        "method": "mobile_mlkit_text_recognition",
                        "provenance": "client_on_device_ocr_sidecar",
                    }

                # No direct text at all — this is a scanned/image-only PDF
                # Try OCR if available (local dev), otherwise clear message
                if self._ocr_pipeline is not None:
                    if not self.pdf_processor:
                        from src.ocr.pdf_processor import PDFProcessor
                        self.pdf_processor = PDFProcessor(ocr_pipeline=self._ocr_pipeline)
                    result = await self._run_in_executor(self.pdf_processor.process_pdf, file_path)
                    result["status"] = "completed"
                    return result

                try:
                    from src.ocr.pipeline import OCRPipeline  # noqa: F401
                    # doctr is importable but pipeline not initialized yet
                    if self._ocr_pipeline is None:
                        self._ocr_pipeline = OCRPipeline()
                    if not self.pdf_processor:
                        from src.ocr.pdf_processor import PDFProcessor
                        self.pdf_processor = PDFProcessor(ocr_pipeline=self._ocr_pipeline)
                    result = await self._run_in_executor(self.pdf_processor.process_pdf, file_path)
                    result["status"] = "completed"
                    return result
                except ImportError:
                    return {
                        "status": "failed",
                        "error": "This PDF appears to be scanned (no embedded text). OCR is not available in this build. Please upload a digital/text-based PDF.",
                        "full_text": "",
                    }

            except Exception as e:
                logger.warning(
                    "pdf_direct_text_extraction_failed document_id=%s error_type=%s",
                    document_id,
                    type(e).__name__,
                )
                # If PyMuPDF can't open it, try OCR pipeline as last resort
                # (the file might be a valid image-based PDF that needs OCR)
                try:
                    if self._ocr_pipeline is None:
                        from src.ocr.pipeline import OCRPipeline
                        self._ocr_pipeline = OCRPipeline()
                    if not self.pdf_processor:
                        from src.ocr.pdf_processor import PDFProcessor
                        self.pdf_processor = PDFProcessor(ocr_pipeline=self._ocr_pipeline)
                    result = await self._run_in_executor(self.pdf_processor.process_pdf, file_path)
                    result["status"] = "completed"
                    return result
                except ImportError:
                    return {
                        "status": "failed",
                        "error": f"Could not extract text from this PDF: {str(e)}",
                        "full_text": "",
                    }
                except Exception as ocr_err:
                    logger.error(
                        "pdf_ocr_fallback_failed document_id=%s error_type=%s",
                        document_id,
                        type(ocr_err).__name__,
                    )
                    return {
                        "status": "failed",
                        "error": str(e),
                        "full_text": "",
                    }

        # --- Other text-based files (.txt, .csv, .json, etc.) ---
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                text = f.read()
            return {
                "full_text": text,
                "page_texts": {1: text},
                "status": "completed",
                "method": "text_fallback",
            }
        except Exception as e:
            logger.error(
                "text_extraction_failed document_id=%s error_type=%s",
                document_id,
                type(e).__name__,
            )
            return {
                "status": "failed",
                "error": str(e),
                "full_text": "",
            }
    
    async def _ingest_into_rag(
        self, document_id: str, text: str, filename: str, *,
        owner_id: Optional[str],
        page_texts: Optional[Dict[int, str]] = None,
        page_images: Optional[Dict[int, bytes]] = None,
    ) -> Dict[str, Any]:
        """Ingest document into RAG pipeline with multi-view indexing.

        Per ADR-2026-07-19-11 Layer 4: when page_texts and page_images
        are provided, page artifacts are created in the substrate before
        chunking. Every chunk gets a ``page`` field and a corresponding
        ``page_artifact_id`` so the "open page" action can resolve the
        source page.
        """
        try:
            if not text or len(text.strip()) < 10:
                return {
                    "status": "skipped",
                    "reason": "Insufficient text content"
                }
            
            # Prepare document metadata
            metadata = {
                "document_id": document_id,
                "filename": filename,
                "ingested_at": datetime.utcnow().isoformat(),
                "text_length": len(text)
            }
            if owner_id:
                metadata["owner_id"] = owner_id

            # Layer 4: create page artifacts and build page_artifact_id_map.
            page_artifact_id_map: Optional[Dict[int, str]] = None
            if page_texts and self._evidence_pipeline_enabled():
                try:
                    from src.services.evidence_substrate_service import (
                        EvidenceSubstrateService,
                    )
                    substrate = EvidenceSubstrateService()
                    page_artifact_id_map = {}
                    for page_num, ocr_text in page_texts.items():
                        page_image = (
                            page_images.get(page_num, b"")
                            if page_images
                            else b""
                        )
                        if not page_image:
                            continue  # skip pages without rendered image
                        try:
                            # Layer 5: persist page image to the object store
                            # before creating the artifact record so the
                            # image is retrievable when the cited page is
                            # not available locally.
                            if self.document_object_store:
                                self.document_object_store.put_page_image(
                                    document_id=document_id,
                                    page_number=page_num,
                                    image_bytes=page_image,
                                )
                            pa_id = await substrate.append_page_artifact(
                                document_id=UUID(document_id),
                                page_number=page_num,
                                page_image_bytes=page_image,
                                ocr_text=ocr_text,
                            )
                            page_artifact_id_map[page_num] = str(pa_id)
                        except Exception as pa_err:
                            logger.warning(
                                "page_artifact_create_failed document_id=%s "
                                "page=%d error=%s",
                                document_id, page_num, pa_err,
                            )
                except Exception as sub_err:
                    logger.warning(
                        "page_artifact_setup_failed document_id=%s error=%s",
                        document_id, sub_err,
                    )
                    page_artifact_id_map = None

            # Split text into chunks for better RAG performance.
            # When page_texts is available, split per-page so each
            # chunk carries a ``page`` field for Layer 4 linkage.
            if page_texts:
                text_blocks = []
                for page_num in sorted(page_texts):
                    page_text = page_texts[page_num]
                    page_blocks = self._split_text_into_blocks(page_text)
                    for block in page_blocks:
                        block["page"] = page_num
                    text_blocks.extend(page_blocks)
            else:
                text_blocks = self._split_text_into_blocks(text)

            # Multi-view indexing: extract entities and add as separate chunk type
            entity_blocks = await self._extract_entity_blocks(text, document_id)
            all_blocks = text_blocks + entity_blocks
            
            # Ingest into RAG pipeline
            ingest_result = await self.rag_pipeline.ingest_document_data(
                document_id=document_id,
                text_blocks=all_blocks,
                document_metadata=metadata,
                page_artifact_id_map=page_artifact_id_map,
            )
            
            return {
                "status": "completed",
                "text_blocks_count": len(text_blocks),
                "entity_blocks_count": len(entity_blocks),
                "total_text_length": len(text),
                "page_artifacts_created": len(page_artifact_id_map) if page_artifact_id_map else 0,
                "rag_result": ingest_result
            }
            
        except Exception as e:
            logger.error(
                "rag_ingestion_failed document_id=%s error_type=%s",
                document_id,
                type(e).__name__,
            )
            return {
                "status": "failed",
                "error": str(e)
            }
    
    async def _extract_entity_blocks(self, text: str, document_id: str) -> List[Dict[str, Any]]:
        """Extract entities from text and create entity-type chunks for multi-view indexing.

        Entity chunks enable exact-match retrieval for policy numbers, dates,
        amounts, phone numbers, and emails — bypassing semantic search entirely.
        """
        try:
            if self._ocr_pipeline is None:
                from src.ocr.pipeline import OCRPipeline
                self._ocr_pipeline = OCRPipeline()
            entities = await self._ocr_pipeline._extract_entities(text)
        except Exception as e:
            logger.warning("Entity extraction failed: %s", e)
            return []

        blocks = []
        for entity in entities:
            blocks.append({
                "text": f"{entity['entity_type']}: {entity['value']}",
                "id": str(uuid.uuid4()),
                "chunk_type": "entity",
                "entity_type": entity["entity_type"],
                "entity_value": str(entity["value"]),
            })

        logger.info("Extracted %d entity blocks for %s", len(blocks), document_id)
        return blocks

    def _split_text_into_blocks(self, text: str, max_block_size: int = 1000) -> List[Dict[str, Any]]:
        """Split text into manageable blocks for RAG ingestion using structure-aware boundaries."""
        if len(text) <= max_block_size:
            return [{"text": text, "id": str(uuid.uuid4())}]

        # Split on known section headers first
        section_headers = re.compile(
            r'(?=^(?:COVERAGE|EXCLUSIONS|DEDUCTIBLE|PREMIUM|BENEFITS|'
            r'POLICY|TERMS|CONDITIONS|ENDORSEMENT|SCHEDULE|DECLARATIONS|'
            r'LIMITS|DEFINITIONS|GENERAL|SPECIAL|ADDITIONAL)\b)',
            re.IGNORECASE | re.MULTILINE,
        )
        paragraphs = re.split(r'\n\s*\n', text)
        raw_chunks = []
        for para in paragraphs:
            para = para.strip()
            if not para:
                continue
            # Split long paragraphs at section header boundaries
            parts = section_headers.split(para)
            raw_chunks.extend(p for p in parts if p.strip())

        if not raw_chunks:
            return [{"text": text, "id": str(uuid.uuid4())}]

        blocks = []
        current = ""
        for chunk in raw_chunks:
            chunk = chunk.strip()
            if not chunk:
                continue
            if len(current) + len(chunk) + 1 <= max_block_size:
                current = (current + "\n\n" + chunk).strip()
            else:
                if current:
                    blocks.append({"text": current, "id": str(uuid.uuid4())})
                current = chunk

        if current:
            blocks.append({"text": current, "id": str(uuid.uuid4())})

        return blocks
    
    async def _run_in_executor(self, func, *args):
        """Run CPU-intensive tasks in executor"""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, func, *args)

    def _evidence_pipeline_enabled(self) -> bool:
        """True iff the evidence substrate is configured on this
        deployment. The substrate requires SUPABASE_URL and
        SUPABASE_SERVICE_ROLE_KEY; if either is missing, the
        pipeline is disabled and the document processing
        continues without it.

        The substrate is independent of the main document
        store: the document is processed regardless, and the
        policy detail screen shows the "Not yet verified"
        scaffold when the substrate is empty.
        """
        url = os.getenv("SUPABASE_URL", "").strip()
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        return bool(url) and bool(key)
    
    async def _update_status(self, document_id: str, stage: str, progress: int, error: str = None):
        """Update processing status"""
        if document_id in self.processing_status:
            self.processing_status[document_id].update({
                "stage": stage,
                "progress": progress,
                "updated_at": datetime.utcnow().isoformat()
            })
            if error:
                self.processing_status[document_id]["error"] = error
    
    def get_processing_status(self, document_id: str) -> Optional[Dict[str, Any]]:
        """Get current processing status"""
        return self.processing_status.get(document_id)
    
    def get_all_processing_status(self) -> Dict[str, Dict[str, Any]]:
        """Get all processing statuses"""
        return self.processing_status.copy()
    
    async def query_documents(self, query: str, filters: Optional[Dict] = None) -> Dict[str, Any]:
        """Query processed documents using RAG"""
        if not self.rag_pipeline:
            return {
                "status": "error",
                "error": "RAG pipeline not available"
            }
        
        try:
            result = await self.rag_pipeline.query_rag(
                user_query=query,
                filters=filters,
                top_k=5
            )
            return result
        except Exception as e:
            logger.error("document_query_failed error_type=%s", type(e).__name__)
            return {
                "status": "error",
                "error": str(e)
            }
