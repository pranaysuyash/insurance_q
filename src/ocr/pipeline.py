"""
OCR pipeline implementation using Hugging Face Inference APIs for document understanding.
"""
import os
import io
from typing import Dict, Any, List, Tuple, Optional # Added Optional
from PIL import Image
import fitz  # PyMuPDF
from huggingface_hub import InferenceClient, HfApi # Added HfApi for model checks if needed
from huggingface_hub.utils import RepositoryNotFoundError, GatedRepoError # For error handling
from datetime import datetime
import uuid # For generating unique block IDs
import json # For logging complex objects if needed
import time # For potential retries or delays

# Configure logging
import logging
logger = logging.getLogger(__name__)
# You might want to configure structlog here if it's used project-wide
# For now, using standard logging for simplicity within this refactor.
logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper())


# Helper to convert PIL Image to bytes
def pil_image_to_bytes(image: Image.Image, format="PNG") -> bytes:
    img_byte_arr = io.BytesIO()
    image.save(img_byte_arr, format=format)
    return img_byte_arr.getvalue()

class OCRPipeline:
    def __init__(self):
        """Initialize the OCR pipeline with Hugging Face Inference Client."""
        self.hf_token = os.getenv("HF_TOKEN")
        if not self.hf_token:
            logger.error("HF_TOKEN environment variable not set.")
            raise ValueError("HF_TOKEN environment variable not set.")
        
        # Consider adding a timeout to the client
        self.client = InferenceClient(token=self.hf_token) 
        
        # Define models to use
        self.ocr_model = os.getenv("HF_OCR_MODEL", "mindee/doctr-ocr")
        self.doc_qa_model = os.getenv("HF_DOC_QA_MODEL", "impira/layoutlm-document-qa")
        logger.info(f"OCRPipeline initialized. OCR Model: {self.ocr_model}, DocQA Model: {self.doc_qa_model}")

    async def _process_pdf(self, file_content: bytes) -> List[Dict[str, Any]]:
        """
        Process a PDF file to extract text and/or images.
        Returns a list of dictionaries, each containing:
        - page_num: page number (1-indexed)
        - text: directly extracted text if available
        - image_bytes: image of the page for OCR fallback if needed
        """
        page_data = []
        try:
            doc = fitz.open(stream=file_content, filetype="pdf")
            for page_num_fitz, page in enumerate(doc):  # fitz pages are 0-indexed
                page_number = page_num_fitz + 1
                page_info = {"page_num": page_number}
                
                # First try direct text extraction
                text = page.get_text()
                if text and text.strip():
                    page_info["text"] = text
                    logger.debug(f"Page {page_number}: Extracted {len(text)} chars directly from PDF.")
                
                # Always generate image as fallback for OCR if needed or for document QA
                pix = page.get_pixmap(dpi=int(os.getenv("OCR_IMAGE_DPI", "200")))
                img_bytes = pix.tobytes("png")  # PNG is lossless
                page_info["image_bytes"] = img_bytes
                
                page_data.append(page_info)
                
            doc.close()
            logger.info(f"Processed PDF: {len(page_data)} pages, tried direct text extraction first.")
        except Exception as e:
            logger.error(f"Error processing PDF: {e}", exc_info=True)
            raise ValueError(f"Failed to process PDF file: {e}")
        return page_data
        
    async def _convert_file_to_images_bytes(self, file_content: bytes, file_type: str) -> List[Tuple[Any, int]]:
        """
        Process document content based on file type.
        For PDFs: Try direct text extraction first, with image as fallback
        For images: Use image content directly
        Returns a list of processed pages with extracted text and/or image data.
        """
        if file_type.lower() == "pdf":
            return await self._process_pdf(file_content)
        elif file_type.lower() in ["png", "jpg", "jpeg", "tiff", "tif", "bmp", "webp"]:
            # For single images, wrap in a list with page number 1
            return [{"page_num": 1, "image_bytes": file_content}]
        else:
            logger.error(f"Unsupported file type for conversion: {file_type}")
            raise ValueError(f"Unsupported file type: {file_type}")
        

    async def _get_ocr_text_for_image(self, image_bytes: bytes, page_num: int) -> str:
        """Get plain text OCR for a single image using the configured OCR model."""
        ocr_text = ""
        try:
            logger.debug(f"Sending page {page_num} to OCR model: {self.ocr_model}")
            # Fix: removed 'data=' parameter which is not supported by the image_to_text method
            api_result = self.client.image_to_text(image_bytes, model=self.ocr_model)
            
            if isinstance(api_result, str):
                ocr_text = api_result
            elif isinstance(api_result, dict) and "generated_text" in api_result: 
                ocr_text = api_result["generated_text"]
            elif isinstance(api_result, list) and api_result and isinstance(api_result[0], dict) and "generated_text" in api_result[0]:
                 ocr_text = api_result[0]["generated_text"] # Handle cases like [{'generated_text': '...'}]
            else: 
                logger.warning(f"Page {page_num}: Unexpected OCR API result format from {self.ocr_model}. Result: {str(api_result)[:500]}")
            
            logger.debug(f"Page {page_num}: OCR extracted text length: {len(ocr_text)}")
        except Exception as e:
            logger.error(f"Page {page_num}: Error during HF Inference API call for OCR ({self.ocr_model}): {e}", exc_info=True)
        return ocr_text

    async def _get_layout_elements_for_image(self, image_bytes: bytes, page_num: int, questions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Get layout elements by asking questions to the document QA model for a single image."""
        layout_elements = []
        if not questions:
            return layout_elements

        # Convert image_bytes to PIL Image because some HF doc_qa models expect it directly
        # or InferenceClient handles it better. If direct bytes are preferred by the model, adjust.
        try:
            pil_image = Image.open(io.BytesIO(image_bytes))
        except Exception as e:
            logger.error(f"Page {page_num}: Failed to convert image bytes to PIL Image for DocQA: {e}", exc_info=True)
            return layout_elements

        for q_item in questions:
            question_text = q_item["question"]
            element_type = q_item["type"]
            field_id = q_item.get("id", str(uuid.uuid4())) # Allow predefined ID for element type
            try:
                logger.debug(f"Page {page_num}: Querying DocQA model ({self.doc_qa_model}) with question: '{question_text}'")
                
                # Fix: Use document_question_answering method instead of post
                api_answers = self.client.document_question_answering(
                    image=pil_image,
                    question=question_text,
                    model=self.doc_qa_model
                )
                                
                if not isinstance(api_answers, list):
                    logger.warning(f"Page {page_num}: DocQA model ({self.doc_qa_model}) returned non-list for question '{question_text}'. Response: {str(api_answers)[:500]}")
                    continue

                for answer_item in api_answers:
                    if isinstance(answer_item, dict) and all(k in answer_item for k in ["answer", "score"]):
                        # box_2d might not always be present or might be named differently (e.g. "box")
                        bbox = answer_item.get("box_2d", answer_item.get("box")) 
                        layout_elements.append({
                            "id": field_id, # Use the id from question config
                            "type": element_type,
                            "text": str(answer_item["answer"]),
                            "answer_box": bbox, 
                            "confidence": float(answer_item["score"]),
                            "page": page_num,
                            "question_asked": question_text # For traceability
                        })
                    else:
                        logger.warning(f"Page {page_num}: Unexpected answer item format from DocQA for question '{question_text}'. Item: {str(answer_item)[:200]}")
            except Exception as e:
                logger.error(f"Page {page_num}: Error during HF Inference API call for DocQA ({self.doc_qa_model}) with question '{question_text}': {e}", exc_info=True)
        logger.debug(f"Page {page_num}: Extracted {len(layout_elements)} layout elements.")
        return layout_elements

    async def process_document(self, file_content: bytes, file_type: str, filename: str, layout_questions_config: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
        """
        Process a document using Hugging Face Inference APIs.
        Returns a structured dictionary with OCR text and extracted layout elements.
        `layout_questions_config`: A list of dicts, e.g., 
            [{"id": "title_field", "type": "title", "question": "What is the title?"}, ...]
        """
        logger.info(f"Starting document processing for: {filename}, type: {file_type}")
        start_time = time.time()

        try:
            processed_pages = await self._convert_file_to_images_bytes(file_content, file_type)
            
            page_count = len(processed_pages)
            if page_count == 0:
                logger.warning(f"No pages processed from file: {filename}")
                return {"status": "error", "error": "No content found in document.", "filename": filename}

            all_pages_full_text = []
            all_pages_text_blocks = []
            all_pages_layout_elements = []

            # Use provided layout_questions_config or a default set
            if layout_questions_config is None:
                layout_questions_config = [
                    {"id": "doc_title", "type": "title", "question": "What is the title of this document?"},
                    {"id": "doc_date", "type": "date", "question": "What is the main date on this page?"},
                    {"id": "policy_number", "type": "policy_id", "question": "What is the policy number?"},
                    {"id": "effective_date", "type": "date", "question": "What is the effective date?"},
                    {"id": "insurance_provider", "type": "provider", "question": "What is the name of the insurance company?"},
                ]
                logger.info("Using default layout questions.")
            else:
                logger.info(f"Using provided layout questions: {json.dumps(layout_questions_config)}")

            for page_data in processed_pages:
                page_num = page_data["page_num"]
                logger.info(f"Processing page {page_num}/{page_count} for {filename}...")
                
                # Get text - either from direct extraction or OCR
                page_text = ""
                
                # If we already have directly extracted text, use it
                if "text" in page_data and page_data["text"].strip():
                    page_text = page_data["text"]
                    logger.info(f"Page {page_num}: Using directly extracted text ({len(page_text)} chars)")
                # Otherwise fall back to OCR
                elif "image_bytes" in page_data:
                    page_text = await self._get_ocr_text_for_image(page_data["image_bytes"], page_num)
                    logger.info(f"Page {page_num}: Used OCR to extract text ({len(page_text)} chars)")
                
                all_pages_full_text.append(page_text)
                
                if page_text:
                    all_pages_text_blocks.append({
                        "id": str(uuid.uuid4()), 
                        "page": page_num,
                        "text": page_text,
                        "bbox": [0.0, 0.0, 1.0, 1.0], 
                        "confidence": None,
                        "extraction_method": "direct" if "text" in page_data else "ocr"
                    })
                
                # Use image for document QA regardless of text extraction method
                if "image_bytes" in page_data:
                    page_layout_elements = await self._get_layout_elements_for_image(
                        page_data["image_bytes"], page_num, layout_questions_config
                    )
                    all_pages_layout_elements.extend(page_layout_elements)

            combined_full_text = "\n\n--- Page Separator ---\n\n".join(all_pages_full_text).strip()
            processing_time = time.time() - start_time
            logger.info(f"Finished processing {filename} in {processing_time:.2f} seconds. Total pages: {page_count}.")

            final_result = {
                "metadata": {
                    "filename": filename,
                    "processed_at": datetime.now().isoformat(),
                    "page_count": page_count,
                    "ocr_model": self.ocr_model,
                    "doc_qa_model": self.doc_qa_model,
                    "processing_time_seconds": round(processing_time, 2)
                },
                "full_text": combined_full_text,
                "text_blocks": all_pages_text_blocks, 
                "layout_elements": all_pages_layout_elements
            }
            
            return {"status": "success", "result": final_result}
        
        except ValueError as e: 
            logger.error(f"File conversion failed for {filename}: {e}", exc_info=True)
            return {"status": "error", "error": str(e), "filename": filename}
        except Exception as e:
            processing_time = time.time() - start_time
            logger.error(f"Unhandled error in OCRPipeline.process_document for {filename} after {processing_time:.2f}s: {e}", exc_info=True)
            return {
                "status": "error",
                "error": f"An unexpected error occurred during document processing: {str(e)}",
                "filename": filename
            }

# Example of how to call this (e.g., from an API endpoint in src/ocr/service.py)
# async def ocr_endpoint(file: UploadFile, filename: str):
#     pipeline = OCRPipeline() # Ideally, pipeline is initialized once and reused
#     content = await file.read()
#     file_type = file.content_type.split('/')[-1] if file.content_type else filename.split('.')[-1]
#     # Example custom questions
#     custom_questions = [
#         {"id": "policy_number", "type": "policy_id", "question": "What is the policy number?"},
#         {"id": "effective_date", "type": "date", "question": "What is the effective date?"}
#     ]
#     result = await pipeline.process_document(content, file_type, filename, layout_questions_config=custom_questions)
#     return result 