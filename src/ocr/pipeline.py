"""
OCR pipeline implementation using the doctr library for document understanding.
"""
import os
import io
import json
import hashlib
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

from src.config.settings import settings

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
        """Initialize the local OCR predictor when the OCR path is requested.

        doctr is a local accelerator, not a production import requirement.
        Keeping this import inside construction allows the API and direct-text
        PDF path to load in a slim deployment while preserving a clear
        ImportError when a scan actually requires unavailable OCR.
        """
        # HF_TOKEN might still be needed for other things (e.g., DocQA if re-enabled, or RAG embedding models)
        # self.hf_token = os.getenv("HF_TOKEN")
        # if not self.hf_token:
        #     logger.warning("HF_TOKEN environment variable not set. This might be an issue if other HF models are used.")
            # raise ValueError("HF_TOKEN environment variable not set.")
        
        try:
            from doctr.models import ocr_predictor as doctr_ocr_predictor
        except (ImportError, OSError) as error:
            logger.warning(
                "Local doctr OCR is unavailable error_type=%s",
                type(error).__name__,
            )
            raise ImportError(
                "Local OCR is unavailable. Install requirements-local.txt or "
                "use on-device OCR for scanned documents."
            ) from error

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


    async def _process_pdf_with_docling(self, pdf_path: str) -> Optional[Dict[str, Any]]:
        """
        Process a PDF using Docling (IBM) for text + layout extraction.
        Returns dict with full_text and layout_elements, or None if docling is not available.
        """
        try:
            from docling.document_converter import DocumentConverter
        except ImportError:
            logger.warning("docling is not installed. Install with: pip install docling")
            return None

        try:
            logger.info("Processing PDF with Docling...")
            converter = DocumentConverter()
            result = converter.convert(pdf_path)
            doc = result.document

            full_text = doc.text if hasattr(doc, 'text') else ""
            if not full_text:
                full_text = "\n".join(
                    item.text for item in doc.texts
                ) if hasattr(doc, 'texts') else ""

            layout_elements = []
            page_texts = {}
            if hasattr(doc, 'pages'):
                for page in doc.pages:
                    page_num = page.page_number if hasattr(page, 'page_number') else 0
                    page_items = []
                    if hasattr(page, 'items'):
                        for item in page.items:
                            item_text = item.text if hasattr(item, 'text') else ""
                            if item_text:
                                page_items.append(item_text)
                            bbox = None
                            if hasattr(item, 'bbox') and item.bbox:
                                bbox = [
                                    float(item.bbox.l),
                                    float(item.bbox.t),
                                    float(item.bbox.r),
                                    float(item.bbox.b),
                                ]
                            layout_elements.append({
                                "id": str(uuid.uuid4()),
                                "text": item_text,
                                "page": page_num,
                                "bbox": bbox or [0.0, 0.0, 1.0, 1.0],
                            })
                    if page_num > 0 and page_items:
                        page_texts[page_num] = "\n".join(page_items)

            logger.info(
                f"Docling extracted {len(full_text)} chars, "
                f"{len(layout_elements)} layout elements"
            )
            return {
                "full_text": full_text,
                "layout_elements": layout_elements,
                "page_texts": page_texts,
            }

        except Exception as e:
            logger.error(f"Docling processing failed: {e}", exc_info=True)
            return None

    async def _process_pdf_with_mineru(self, pdf_path: str) -> Optional[Dict[str, Any]]:
        """Process a PDF using MinerU 2.5 for high-accuracy extraction.

        MinerU is a 1.2B VLM that achieves SOTA on OmniDocBench (90.67),
        outperforming Gemini 2.5 Pro. Best for complex insurance documents
        with tables, multi-column layouts, and formulas.

        Requires: pip install magic-pdf[full] and MINERU_ENABLED=true
        License: AGPL-3.0 (PyMuPDF dependency — check commercial use)
        """
        if not settings.mineru_enabled:
            return None

        try:
            from magic_pdf.pipe.UNIPipe import UNIPipe
            from magic_pdf.rw.DiskReaderWriter import DiskReaderWriter
            import magic_pdf.model as model_config
            model_config.__use_inside_model = True
        except ImportError:
            logger.warning("MinerU (magic-pdf) not installed. Install with: pip install magic-pdf[full]")
            return None

        try:
            logger.info("Processing PDF with MinerU 2.5...")
            image_writer = DiskReaderWriter("/tmp/mineru_images")
            pipe = UNIPipe(pdf_path, {"_pdf_type": "", "model_list": []}, image_writer)
            pipe.pipe_classify()
            pipe.pipe_parse()
            content_list = pipe.pipe_mk_uni_format(pdf_path)

            full_text = ""
            tables = []
            for item in content_list:
                if item.get("type") == "text":
                    full_text += item.get("text", "") + "\n"
                elif item.get("type") == "table":
                    tables.append({
                        "headers": item.get("headers", []),
                        "rows": item.get("rows", []),
                        "html": item.get("html", ""),
                        "page": item.get("page_idx", 0),
                    })
                    full_text += item.get("text", "") + "\n"

            logger.info("MinerU extracted %d chars, %d tables", len(full_text), len(tables))
            return {
                "full_text": full_text,
                "method": "mineru",
                "tables": tables,
                "layout_elements": [],
            }
        except Exception as e:
            logger.error("MinerU processing failed: %s", e)
            return None

    async def _extract_entities(self, text: str) -> List[Dict[str, Any]]:
        """Extract named entities from text for multi-view indexing.

        Extracts: policy numbers, dates, amounts, phone numbers, email addresses.
        These are stored as separate 'entity' chunk type for exact-match retrieval.
        """
        import re as regex

        entities = []

        # Policy numbers — alphanumeric with slashes/dashes, 5-25 chars
        for match in regex.finditer(r'\b([A-Z]{2,6}[/\-]?[A-Z0-9]{3,15}[/\-]?[A-Z0-9]{0,10})\b', text):
            val = match.group(1)
            if len(val) >= 5 and regex.match(r'^[A-Z0-9/\-]+$', val):
                entities.append({"entity_type": "policy_number", "value": val, "source_text": match.group(0)})

        # Dates — DD-MM-YYYY, DD/MM/YYYY, DD Mon YYYY
        for match in regex.finditer(r'\b(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})\b', text):
            entities.append({"entity_type": "date", "value": match.group(1), "source_text": match.group(0)})
        for match in regex.finditer(r'\b(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4})\b', text, regex.IGNORECASE):
            entities.append({"entity_type": "date", "value": match.group(1), "source_text": match.group(0)})

        # Amounts — ₹XX,XXX or Rs. XXXXX
        for match in regex.finditer(r'[₹Rs\.]+\s*([0-9,]+(?:\.[0-9]+)?)', text):
            amount_str = match.group(1).replace(",", "")
            try:
                amount = float(amount_str)
                entities.append({"entity_type": "amount", "value": amount, "source_text": match.group(0)})
            except ValueError:
                pass

        # Phone numbers
        for match in regex.finditer(r'\b(\+?[\d\s\-()]{10,15})\b', text):
            val = match.group(1).strip()
            digits = regex.sub(r'[^\d]', '', val)
            if 10 <= len(digits) <= 13:
                entities.append({"entity_type": "phone", "value": val, "source_text": match.group(0)})

        # Email
        for match in regex.finditer(r'\b([\w.+-]+@[\w-]+\.[\w.-]+)\b', text):
            entities.append({"entity_type": "email", "value": match.group(1), "source_text": match.group(0)})

        return entities

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
        elif file_type.lower() in ["txt", "text", "md", "csv", "json", "xml", "html"]:
            # Text-based files: decode and use directly
            try:
                text = file_content.decode("utf-8", errors="replace")
            except Exception:
                text = file_content.decode("latin-1", errors="replace")
            return [{"page_num": 1, "text": text}]
        else:
            logger.error(f"Unsupported file type for conversion: {file_type}")
            raise ValueError(f"Unsupported file type: {file_type}")
        

    async def _get_ocr_text_for_image(self, image_bytes: bytes, page_num: int) -> str:
        """Get plain text OCR for a single image using the local doctr predictor.

        Applies pre-processing (deskew, denoise, binarize) before OCR to improve accuracy.
        """
        ocr_text = ""
        try:
            logger.debug(f"Page {page_num}: Preparing image for doctr OCR.")
            pil_image = Image.open(io.BytesIO(image_bytes))

            # Pre-processing: deskew, denoise, binarize (5-15% OCR accuracy improvement)
            processed_image = self._preprocess_image(np.array(pil_image))

            # doctr expects multi-channel HxWxC pages. Preprocessing returns
            # a single-channel image for thresholding; restore the channel
            # dimension before prediction so image OCR does not degrade to an
            # empty result after a predictor shape error.
            if processed_image.ndim == 2:
                processed_image = np.repeat(processed_image[:, :, None], 3, axis=2)

            doc_content = [processed_image]

            logger.debug(f"Page {page_num}: Sending pre-processed image to local doctr OCR predictor.")
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

    def _preprocess_image(self, image: np.ndarray) -> np.ndarray:
        """Apply standard pre-processing to improve OCR accuracy.

        Pipeline: grayscale → deskew → denoise → adaptive threshold (binarize).
        Estimated 5-15% accuracy improvement on scanned insurance documents.
        All techniques use OpenCV (already a dependency of doctr).
        """
        try:
            import cv2

            # 1. Convert to grayscale
            if len(image.shape) == 3:
                gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
            else:
                gray = image

            # 2. Deskew — detect and correct text skew angle
            angle = self._detect_skew_angle(gray)
            if abs(angle) > 0.5:
                (h, w) = gray.shape
                center = (w // 2, h // 2)
                rotation_matrix = cv2.getRotationMatrix2D(center, angle, 1.0)
                gray = cv2.warpAffine(gray, rotation_matrix, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
                logger.debug("Deskewed image by %.2f degrees", angle)

            # 3. Denoise — remove scan artifacts
            gray = cv2.fastNlMeansDenoising(gray, h=10)

            # 4. Adaptive threshold (Sauvola-like) — binarize for better OCR
            gray = cv2.adaptiveThreshold(
                gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                cv2.THRESH_BINARY, 11, 2
            )

            return gray
        except Exception as e:
            logger.warning("Pre-processing failed, using original image: %s", e)
            return image

    def _detect_skew_angle(self, gray: np.ndarray) -> float:
        """Detect the skew angle of text in a grayscale image."""
        try:
            import cv2
            # Find dark pixels (text)
            coords = np.column_stack(np.where(gray < 128))
            if len(coords) == 0:
                return 0.0
            # Get minimum area rectangle
            angle = cv2.minAreaRect(coords)[-1]
            # Normalize angle
            if angle < -45:
                angle = 90 + angle
            return angle
        except Exception:
            return 0.0

    async def _get_layout_elements_for_text(
        self, page_text: str, page_num: int, questions: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Extract layout elements by querying the LLM with the page text."""
        if not page_text.strip():
            return []

        logger.debug("Page %d: extracting elements via LLM (%d questions)", page_num, len(questions))

        try:
            from src.llm.client import LLMClient
            from src.models.extraction import InsuranceDocumentExtraction

            llm = LLMClient()
            system_prompt = (
                "Extract the following insurance document fields from the text below. "
                "Return values exactly as they appear. Use null for missing fields."
            )
            question_descriptions = "\n".join(
                f"- {q['id']} ({q['type']}): {q['question']}" for q in questions
            )
            user_prompt = (
                f"Document text (page {page_num}):\n{page_text[:8000]}\n\n"
                f"Extract these fields:\n{question_descriptions}"
            )

            result = await llm.generate_structured(
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                response_model=InsuranceDocumentExtraction,
                temperature=0.1,
            )

            elements = []
            value_map = result.model_dump(exclude_none=True)
            for q in questions:
                field_id = q["id"]
                value = value_map.get(field_id)
                if value is not None:
                    elements.append({
                        "id": q.get("id", field_id),
                        "type": q["type"],
                        "text": str(value),
                        "confidence": 1.0,
                        "page": page_num,
                        "question_asked": q["question"],
                    })

            logger.debug("Page %d: extracted %d/%d elements", page_num, len(elements), len(questions))
            return elements

        except ImportError:
            logger.warning("LLM client not available, skipping extraction")
            return []
        except Exception as e:
            logger.error("Page %d: extraction error: %s", page_num, e)
            return []

    async def process_document(self, file_content: bytes, file_type: str, filename: str, layout_questions_config: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
        print(f"DEBUG_PRINT: process_document CALLED for {filename}", file=sys.stderr)
        logger.info(f"Starting document processing for: {filename}, type: {file_type}")
        start_time = time.time()

        try:
            # If docling is enabled and this is a PDF, try docling first
            if settings.docling_enabled and file_type.lower() == "pdf":
                import tempfile
                with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
                    tmp.write(file_content)
                    tmp_path = tmp.name
                try:
                    docling_result = await self._process_pdf_with_docling(tmp_path)
                    if docling_result is not None:
                        logger.info(f"Docling processing succeeded for {filename}")
                        processing_time = time.time() - start_time
                        from src.models.document_intelligence import build_document_cir
                        source_hash = hashlib.sha256(file_content).hexdigest()
                        docling_page_texts = docling_result.get("page_texts") or {
                            1: docling_result["full_text"]
                        }
                        docling_cir = build_document_cir(
                            filename=filename,
                            source_artifact_sha256=source_hash,
                            file_type=file_type,
                            page_texts=docling_page_texts,
                            parser_profile="docling",
                            metadata={"processing_time_seconds": round(processing_time, 2)},
                        )
                        final_result = {
                            "metadata": {
                                "filename": filename,
                                "processed_at": datetime.now().isoformat(),
                                "page_count": len(docling_page_texts),
                                "ocr_model": "docling",
                                "doc_qa_model": self.doc_qa_model_name,
                                "processing_time_seconds": round(processing_time, 2),
                            },
                            "full_text": docling_result["full_text"],
                            "text_blocks": [
                                {
                                    "id": str(uuid.uuid4()),
                                    "page": 1,
                                    "text": docling_result["full_text"],
                                    "bbox": [0.0, 0.0, 1.0, 1.0],
                                    "confidence": None,
                                    "extraction_method": "docling",
                                }
                            ],
                            "layout_elements": docling_result["layout_elements"],
                            "page_texts": docling_page_texts,
                            "page_images": {},
                            "source_artifact_sha256": source_hash,
                            "cir": docling_cir.model_dump(mode="json"),
                        }
                        return {"status": "success", "result": final_result}
                    logger.info(f"Docling returned None for {filename}, falling back to standard pipeline")
                except Exception as e:
                    logger.warning(f"Docling failed for {filename}: {e}, falling back to standard pipeline")
                finally:
                    os.unlink(tmp_path)

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
                
                # Extract structured fields from page text via LLM
                if page_text.strip():
                    page_layout_elements = await self._get_layout_elements_for_text(
                        page_text, page_num, layout_questions_config
                    )
                    all_pages_layout_elements.extend(page_layout_elements)

            combined_full_text = "\n\n--- Page Separator ---\n\n".join(all_pages_full_text).strip()
            processing_time = time.time() - start_time
            logger.info(f"Finished processing {filename} in {processing_time:.2f} seconds. Total pages: {page_count}.")

            page_texts = {
                page_data["page_num"]: page_text
                for page_data, page_text in zip(processed_pages, all_pages_full_text)
                if page_text.strip()
            }
            page_images = {
                page_data["page_num"]: page_data["image_bytes"]
                for page_data in processed_pages
                if page_data.get("image_bytes")
            }
            parser_profile = (
                "native_text"
                if all("text" in page_data for page_data in processed_pages)
                else "local_doctr_ocr"
            )
            from src.models.document_intelligence import build_document_cir
            native_nodes = []
            if file_type.lower() == "pdf":
                from src.ocr.native_pdf import extract_native_pdf_nodes
                native_nodes = extract_native_pdf_nodes(file_content)
            cir = build_document_cir(
                filename=filename,
                source_artifact_sha256=hashlib.sha256(file_content).hexdigest(),
                file_type=file_type,
                page_texts=page_texts,
                page_images=page_images,
                parser_profile=parser_profile,
                metadata={"processing_time_seconds": round(processing_time, 2)},
                observed_nodes=native_nodes,
            )

            final_result = {
                "metadata": {
                    "filename": filename,
                    "processed_at": datetime.now().isoformat(),
                    "page_count": page_count,
                    "ocr_model": parser_profile,
                    "doc_qa_model": self.doc_qa_model_name, # Using the renamed variable
                    "processing_time_seconds": round(processing_time, 2)
                },
                "full_text": combined_full_text,
                "text_blocks": all_pages_text_blocks, 
                "layout_elements": all_pages_layout_elements,
                "page_texts": page_texts,
                "page_images": page_images,
                "source_artifact_sha256": hashlib.sha256(file_content).hexdigest(),
                "cir": cir.model_dump(mode="json"),
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
