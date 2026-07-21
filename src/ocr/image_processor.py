"""
Image Processor using OCR Pipeline
"""
import logging
from typing import Dict, Any, Optional
from src.ocr.pipeline import OCRPipeline

logger = logging.getLogger(__name__)

class ImageProcessor:
    """Image processing using the OCR pipeline"""
    
    def __init__(self, ocr_pipeline: Optional['OCRPipeline'] = None):
        self.ocr_pipeline = ocr_pipeline if ocr_pipeline else OCRPipeline()
        logger.info("ImageProcessor initialized")
    
    def process_image(self, file_path: str) -> Dict[str, Any]:
        """Process image file and extract text"""
        try:
            # Read file content
            with open(file_path, 'rb') as f:
                file_content = f.read()
            
            # Extract filename and determine file type
            filename = file_path.split('/')[-1]
            file_ext = filename.split('.')[-1].lower() if '.' in filename else 'png'
            
            # Process using OCR pipeline
            import asyncio
            result = asyncio.run(self.ocr_pipeline.process_document(
                file_content=file_content,
                file_type=file_ext,
                filename=filename
            ))
            
            if result.get("status") == "success":
                ocr_result = result["result"]
                return {
                    "status": "completed",
                    "full_text": ocr_result.get("full_text", ""),
                    "text_blocks": ocr_result.get("text_blocks", []),
                    "layout_elements": ocr_result.get("layout_elements", []),
                    "page_texts": ocr_result.get("page_texts", {}),
                    "page_images": ocr_result.get("page_images", {}),
                    "source_artifact_sha256": ocr_result.get("source_artifact_sha256"),
                    "cir": ocr_result.get("cir"),
                    "metadata": ocr_result.get("metadata", {}),
                    "method": "ocr_pipeline"
                }
            else:
                logger.error(f"OCR pipeline failed for {filename}: {result.get('error')}")
                return {
                    "status": "failed",
                    "error": result.get("error", "Unknown OCR error"),
                    "full_text": f"Failed to process image: {filename}"
                }
                
        except Exception as e:
            logger.error(f"Image processing failed for {file_path}: {str(e)}")
            return {
                "status": "failed",
                "error": str(e),
                "full_text": f"Failed to process image: {file_path}"
            }
