"""
PDF Processor using OCR Pipeline
"""
import logging
from typing import Dict, Any
from src.ocr.pipeline import OCRPipeline

logger = logging.getLogger(__name__)

class PDFProcessor:
    """PDF processing using the OCR pipeline"""
    
    def __init__(self):
        self.ocr_pipeline = OCRPipeline()
        logger.info("PDFProcessor initialized")
    
    def process_pdf(self, file_path: str) -> Dict[str, Any]:
        """Process PDF file and extract text"""
        try:
            # Read file content
            with open(file_path, 'rb') as f:
                file_content = f.read()
            
            # Extract filename from path
            filename = file_path.split('/')[-1]
            
            # Process using OCR pipeline
            import asyncio
            result = asyncio.run(self.ocr_pipeline.process_document(
                file_content=file_content,
                file_type="pdf",
                filename=filename
            ))
            
            if result.get("status") == "success":
                ocr_result = result["result"]
                return {
                    "status": "completed",
                    "full_text": ocr_result.get("full_text", ""),
                    "text_blocks": ocr_result.get("text_blocks", []),
                    "layout_elements": ocr_result.get("layout_elements", []),
                    "metadata": ocr_result.get("metadata", {}),
                    "method": "ocr_pipeline"
                }
            else:
                logger.error(f"OCR pipeline failed for {filename}: {result.get('error')}")
                return {
                    "status": "failed",
                    "error": result.get("error", "Unknown OCR error"),
                    "full_text": f"Failed to process PDF: {filename}"
                }
                
        except Exception as e:
            logger.error(f"PDF processing failed for {file_path}: {str(e)}")
            return {
                "status": "failed",
                "error": str(e),
                "full_text": f"Failed to process PDF: {file_path}"
            }
