"""
OCR pipeline implementation using the doctr library for document understanding.
"""
import os
import io
import json
from typing import Dict, Any, List, Tuple, Optional
from PIL import Image
import fitz  # PyMuPDF
# Removed Hugging Face InferenceClient specific imports for OCR
# from huggingface_hub import InferenceClient, HfApi 
# from huggingface_hub.utils import RepositoryNotFoundError, GatedRepoError
from datetime import datetime
import uuid
import time
import numpy as np # For potential doctr input/output
import sys # Add this at the top of the file

# doctr imports
from doctr.models import ocr_predictor as doctr_ocr_predictor # Renamed to avoid clash if any
from doctr.io import DocumentFile as DoctrDocumentFile

# Configure logging
import logging
logger = logging.getLogger(__name__)
# Ensure this specific logger outputs INFO and DEBUG messages
# This is more specific than just basicConfig for the root logger
logger.setLevel(logging.INFO) # Or logging.DEBUG for even more verbosity
logger.propagate = True # Ensure messages are passed to handlers of ancestor loggers

# Add a handler if one isn't configured already by Uvicorn/FastAPI for this logger
# This ensures messages go to stderr, which Docker captures
if not logger.hasHandlers():
    handler = logging.StreamHandler() # Defaults to sys.stderr
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)

# The global basicConfig is still useful for other modules or the root logger if needed,
# but the settings above are more direct for this specific pipeline logger.
# logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper())


# Helper to convert PIL Image to bytes
def pil_image_to_bytes(image: Image.Image, format="PNG") -> bytes:
    img_byte_arr = io.BytesIO()
    image.save(img_byte_arr, format=format)
    return img_byte_arr.getvalue()

class OCRPipeline:
    def __init__(self):
        """Initialize the OCR pipeline with a local doctr predictor."""
        # HF_TOKEN might still be needed for other things (e.g., DocQA if re-enabled, or RAG embedding models)
        # self.hf_token = os.getenv("HF_TOKEN")
        # if not self.hf_token:
        #     logger.warning("HF_TOKEN environment variable not set. This might be an issue if other HF models are used.")
            # raise ValueError("HF_TOKEN environment variable not set.")
        
        # Initialize doctr OCR predictor
        # Common defaults: db_resnet50 for detection, crnn_vgg16_bn for recognition
        # export_as_straight_boxes=True can simplify downstream processing if you don't need rotated boxes
        # assume_straight_pages=True can speed up if pages are generally upright
        try:
            logger.info("Initializing doctr OCR predictor...")
            # You might need to specify device depending on your Docker setup & available hardware
            # e.g., doctr_ocr_predictor(..., device=torch.device("cuda" if torch.cuda.is_available() else "cpu"))
            # For now, let's let doctr decide or default to CPU.
            self.doctr_predictor = doctr_ocr_predictor(
                det_arch='db_resnet50',          # Detection model architecture
                reco_arch='crnn_vgg16_bn',       # Recognition model architecture
                pretrained=True,                 # Use pretrained weights
                export_as_straight_boxes=True,   # Output straight bounding boxes
                assume_straight_pages=True       # Assume pages are mostly upright
            )
            logger.info("doctr OCR predictor initialized successfully.")
        except Exception as e:
            logger.error(f"Failed to initialize doctr OCR predictor: {e}", exc_info=True)
            raise

        # DocQA model (currently bypassed, but definition kept for potential future use)
        self.doc_qa_model_name = os.getenv("HF_DOC_QA_MODEL", "impira/layoutlm-document-qa") # Renamed from self.doc_qa_model
        # logger.info(f"OCRPipeline initialized. Using local doctr for OCR. DocQA Model (if used): {self.doc_qa_model_name}")
        logger.info(f"OCRPipeline initialized. Using local doctr for OCR. DocQA Model set to: {self.doc_qa_model_name} (currently bypassed in _get_layout_elements_for_image).")


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
        """Get plain text OCR for a single image using the local doctr predictor."""
        ocr_text = ""
        try:
            logger.debug(f"Page {page_num}: Preparing image for doctr OCR.")
            # doctr expects a list of numpy arrays or PIL Images.
            # We have image_bytes, so convert to PIL Image first.
            pil_image = Image.open(io.BytesIO(image_bytes))
            
            # Process with doctr predictor
            # The predictor takes a list of pages (images). For a single image:
            doc_content = [np.array(pil_image)] # Convert PIL to NumPy array
            
            logger.debug(f"Page {page_num}: Sending image to local doctr OCR predictor.")
            result = self.doctr_predictor(doc_content)
            
            # Extract text from the result
            # The result object has a structure that needs to be navigated.
            # result.export() gives a dictionary representation.
            # We want to concatenate all text found on the page.
            exported_result = result.export()
            
            page_text_parts = []
            if exported_result and "pages" in exported_result and len(exported_result["pages"]) > 0:
                page_export = exported_result["pages"][0] # We processed one image/page
                for block in page_export.get("blocks", []):
                    for line in block.get("lines", []):
                        for word in line.get("words", []):
                            page_text_parts.append(word.get("value", ""))
                        page_text_parts.append("\n") # Add newline after each line for readability
                    # page_text_parts.append("\n\n") # Add more space between blocks if needed
            
            ocr_text = " ".join(page_text_parts).replace(" \n ", "\n").strip() # Join words, handle newlines

            # Alternative simpler text extraction:
            # ocr_text = result.render() # This might include bounding box info, not just plain text.
                                      # Or use result.pages[0].render()

            logger.debug(f"Page {page_num}: doctr OCR extracted text length: {len(ocr_text)}")
            if not ocr_text and len(page_text_parts) > 0 : # If join resulted in empty but parts existed
                 logger.warning(f"Page {page_num}: doctr OCR produced parts but final text is empty. Parts: {page_text_parts[:5]}")


        except Exception as e:
            logger.error(f"Page {page_num}: Error during local doctr OCR processing: {e}", exc_info=True)
        return ocr_text

    async def _get_layout_elements_for_image(self, image_bytes: bytes, page_num: int, questions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Get layout elements by asking questions to the document QA model for a single image."""
        logger.info(f"Page {page_num}: Skipping DocQA and returning empty layout_elements for now.")
        return [] # Immediately return empty list to bypass DocQA

        # The rest of the original method is now effectively disabled by the return above.
        # Keeping it here commented out for future reference if we re-enable local DocQA.
        '''
        # layout_elements = []
        # if not questions:
        #     return layout_elements

        # # Convert image_bytes to PIL Image because some HF doc_qa models expect it directly
        # # or InferenceClient handles it better. If direct bytes are preferred by the model, adjust.
        # try:
        #     pil_image = Image.open(io.BytesIO(image_bytes))
        # except Exception as e:
        #     logger.error(f"Page {page_num}: Failed to convert image bytes to PIL Image for DocQA: {e}", exc_info=True)
        #     return layout_elements

        # for q_item in questions:
        #     question_text = q_item["question"]
        #     element_type = q_item["type"]
        #     field_id = q_item.get("id", str(uuid.uuid4())) # Allow predefined ID for element type
        #     try:
        #         logger.debug(f"Page {page_num}: Querying DocQA model ({self.doc_qa_model}) with question: '{question_text}'")
                
        #         # Fix: Use document_question_answering method instead of post
        #         api_answers = self.client.document_question_answering(
        #             image=pil_image,
        #             question=question_text,
        #             model=self.doc_qa_model
        #         )
                                
        #         if not isinstance(api_answers, list):
        #             logger.warning(f"Page {page_num}: DocQA model ({self.doc_qa_model}) returned non-list for question '{question_text}'. Response: {str(api_answers)[:500]}")
        #             continue

        #         for answer_item in api_answers:
        #             if isinstance(answer_item, dict) and all(k in answer_item for k in ["answer", "score"]):
        #                 # box_2d might not always be present or might be named differently (e.g. "box")
        #                 bbox = answer_item.get("box_2d", answer_item.get("box")) 
        #                 layout_elements.append({
        #                     "id": field_id, # Use the id from question config
        #                     "type": element_type,
        #                     "text": str(answer_item["answer"]),
        #                     "answer_box": bbox, 
        #                     "confidence": float(answer_item["score"]),
        #                     "page": page_num,
        #                     "question_asked": question_text # For traceability
        #                 })
        #             else:
        #                 logger.warning(f"Page {page_num}: Unexpected answer item format from DocQA for question '{question_text}'. Item: {str(answer_item)[:200]}")
        #     except Exception as e:
        #         # If it's a StopIteration, it means the model likely isn't available on inference API for this task
        #         if isinstance(e, StopIteration):\n            logger.error(f"Page {page_num}: StopIteration encountered for DocQA model {self.doc_qa_model} with question '{question_text}'. This often means the model is not deployed on a free Inference API provider for 'document-question-answering'. Error: {e}", exc_info=True)
        #         else:
        #             logger.error(f"Page {page_num}: Error during HF Inference API call for DocQA ({self.doc_qa_model}) with question '{question_text}': {e}", exc_info=True)
        # logger.debug(f"Page {page_num}: Extracted {len(layout_elements)} layout elements.")
        # return layout_elements
        ''' 

    async def process_document(self, file_content: bytes, file_type: str, filename: str, layout_questions_config: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
        print(f"DEBUG_PRINT: process_document CALLED for {filename}", file=sys.stderr)
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
                    "ocr_model": "doctr (local)", # Updated OCR model name
                    "doc_qa_model": self.doc_qa_model_name, # Using the renamed variable
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