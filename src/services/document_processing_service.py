"""
Enhanced Document Processing Service
Handles the complete pipeline: Document Upload → OCR → Structured Extraction → RAG Ingestion → Vector Database
"""
import os
import re
import asyncio
import uuid
import logging
from typing import Optional, Dict, Any, List
from datetime import datetime
import tempfile
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

class DocumentProcessingService:
    """
    Orchestrates the complete document processing pipeline:
    1. File validation and storage
    2. OCR text extraction (PDF/Image)
    3. RAG ingestion (create embeddings)
    4. Status tracking and monitoring
    """
    
    def __init__(self, rag_pipeline: Optional['RAGPipeline'] = None):
        self.rag_pipeline = rag_pipeline
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
        
        logger.info(f"Starting document processing: {filename} (ID: {document_id}, Mode: {processing_mode})")
        
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
                    file_path, filename, pdf_password=pdf_password
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
                    logger.warning("Policy extraction failed for %s: %s", document_id, e)
                    result["stages"]["policy_extraction"] = {"status": "failed", "error": str(e)}
            
            # Stage 3: RAG Ingestion (if needed and available)
            if processing_mode in ["full", "rag_only"] and self.rag_pipeline:
                await self._update_status(document_id, "creating_embeddings", 60)
                
                # If we don't have extracted text, try to get it
                if not extracted_text and processing_mode == "rag_only":
                    logger.warning(f"RAG-only mode but no extracted text for {document_id}")
                    extracted_text = f"Document: {filename}"  # Fallback
                
                rag_result = await self._ingest_into_rag(
                    document_id, extracted_text, filename, owner_id=owner_id
                )
                result["stages"]["rag_ingestion"] = rag_result
            elif processing_mode in ["full", "rag_only"]:
                result["stages"]["rag_ingestion"] = {
                    "status": "skipped", 
                    "reason": "RAG pipeline not available"
                }
            
            # Stage 4: Completion
            await self._update_status(document_id, "completed", 100)
            result["status"] = "completed"
            result["completed_at"] = datetime.utcnow().isoformat()
            
            logger.info(f"Document processing completed: {filename} (ID: {document_id})")
            return result
            
        except Exception as e:
            logger.error(f"Document processing failed: {filename} (ID: {document_id}) - {str(e)}")
            await self._update_status(document_id, "failed", 0, str(e))
            return {
                "document_id": document_id,
                "filename": filename,
                "status": "failed",
                "error": str(e),
                "failed_at": datetime.utcnow().isoformat()
            }
    
    async def _save_file(self, file_content: bytes, filename: str, document_id: str) -> str:
        """Save uploaded file to storage"""
        file_extension = os.path.splitext(filename)[1].lower()
        stored_filename = f"{document_id}_{filename}"
        file_path = os.path.join(self.storage_dir, stored_filename)
        
        with open(file_path, "wb") as f:
            f.write(file_content)
        
        logger.info(f"File saved: {file_path}")
        return file_path
    
    async def _extract_text(
        self, file_path: str, filename: str, pdf_password: Optional[str] = None
    ) -> Dict[str, Any]:
        """Extract text from a document.

        Production (slim image, no OCR): uses PyMuPDF direct-text extraction for
        PDFs. Scanned/image-only PDFs are detected and flagged with a clear
        message instead of crashing.

        Local dev (with doctr installed): falls back to OCR for image-only pages.
        """
        file_extension = os.path.splitext(filename)[1].lower()

        # --- Image files: need OCR (not available in slim production image) ---
        if file_extension in ['.png', '.jpg', '.jpeg', '.tiff', '.webp']:
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
                logger.error(f"Image OCR failed for {filename}: {str(e)}")
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
                for page in doc:
                    text = page.get_text()
                    if text and text.strip():
                        all_text.append(text.strip())
                    else:
                        image_only_pages += 1
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
                        "status": "completed",
                        "method": method,
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
                logger.warning(f"PDF direct-text extraction failed for {filename}: {str(e)}")
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
                    logger.error(f"PDF OCR fallback also failed for {filename}: {str(ocr_err)}")
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
                "status": "completed",
                "method": "text_fallback",
            }
        except Exception as e:
            logger.error(f"Text extraction failed for {filename}: {str(e)}")
            return {
                "status": "failed",
                "error": str(e),
                "full_text": "",
            }
    
    async def _ingest_into_rag(
        self, document_id: str, text: str, filename: str, *, owner_id: Optional[str]
    ) -> Dict[str, Any]:
        """Ingest document into RAG pipeline"""
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
            
            # Split text into chunks for better RAG performance
            text_blocks = self._split_text_into_blocks(text)
            
            # Ingest into RAG pipeline
            ingest_result = await self.rag_pipeline.ingest_document_data(
                document_id=document_id,
                text_blocks=text_blocks,
                document_metadata=metadata
            )
            
            return {
                "status": "completed",
                "text_blocks_count": len(text_blocks),
                "total_text_length": len(text),
                "rag_result": ingest_result
            }
            
        except Exception as e:
            logger.error(f"RAG ingestion failed for {document_id}: {str(e)}")
            return {
                "status": "failed",
                "error": str(e)
            }
    
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
            logger.error(f"Document query failed: {str(e)}")
            return {
                "status": "error",
                "error": str(e)
            }
