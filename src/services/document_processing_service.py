"""
Enhanced Document Processing Service
Handles the complete pipeline: Document Upload → OCR → RAG Ingestion → Vector Database
"""
import os
import asyncio
import uuid
import logging
from typing import Optional, Dict, Any, List
from datetime import datetime
import tempfile

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
        self.pdf_processor = PDFProcessor() if PDFProcessor else None
        self.image_processor = ImageProcessor() if ImageProcessor else None
        self.processing_status = {}  # Track processing status by document_id
        
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
        processing_mode: str = "full"
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
                ocr_result = await self._extract_text(file_path, filename)
                extracted_text = ocr_result.get("full_text", "")
                result["stages"]["ocr"] = ocr_result
                result["extracted_text"] = extracted_text
            
            # Stage 3: RAG Ingestion (if needed and available)
            if processing_mode in ["full", "rag_only"] and self.rag_pipeline:
                await self._update_status(document_id, "creating_embeddings", 60)
                
                # If we don't have extracted text, try to get it
                if not extracted_text and processing_mode == "rag_only":
                    logger.warning(f"RAG-only mode but no extracted text for {document_id}")
                    extracted_text = f"Document: {filename}"  # Fallback
                
                rag_result = await self._ingest_into_rag(document_id, extracted_text, filename)
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
    
    async def _extract_text(self, file_path: str, filename: str) -> Dict[str, Any]:
        """Extract text using OCR processors"""
        file_extension = os.path.splitext(filename)[1].lower()
        
        try:
            if file_extension == '.pdf' and self.pdf_processor:
                result = await self._run_in_executor(self.pdf_processor.process_pdf, file_path)
            elif file_extension in ['.png', '.jpg', '.jpeg', '.tiff', '.webp'] and self.image_processor:
                result = await self._run_in_executor(self.image_processor.process_image, file_path)
            else:
                # Fallback: try to read as text
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    text = f.read()
                result = {
                    "full_text": text,
                    "status": "completed",
                    "method": "text_fallback"
                }
            
            result["status"] = "completed"
            return result
            
        except Exception as e:
            logger.error(f"OCR extraction failed for {filename}: {str(e)}")
            return {
                "status": "failed",
                "error": str(e),
                "full_text": f"Failed to extract text from {filename}"
            }
    
    async def _ingest_into_rag(self, document_id: str, text: str, filename: str) -> Dict[str, Any]:
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
        """Split text into manageable blocks for RAG ingestion"""
        if len(text) <= max_block_size:
            return [{"text": text, "id": str(uuid.uuid4())}]
        
        # Simple sentence-aware splitting
        sentences = text.split('. ')
        blocks = []
        current_block = ""
        
        for sentence in sentences:
            if len(current_block) + len(sentence) + 2 <= max_block_size:
                current_block += sentence + ". "
            else:
                if current_block:
                    blocks.append({"text": current_block.strip(), "id": str(uuid.uuid4())})
                current_block = sentence + ". "
        
        if current_block:
            blocks.append({"text": current_block.strip(), "id": str(uuid.uuid4())})
        
        return blocks if blocks else [{"text": text, "id": str(uuid.uuid4())}]
    
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
