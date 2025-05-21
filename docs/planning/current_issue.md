# Current Pressing Issue: OCR Service Logging Failure & Incomplete Text Display

**Date:** 2025-05-21 (Last Update: 2025-05-22)

**Symptoms:**
The Flutter mobile app consistently displays only a very small portion of text (around 5 lines, seemingly from the first page) after a PDF document is uploaded for OCR processing. The Question & Answering (QA) feature, which relies on this OCRed text being fed into a RAG (Retrieval Augmented Generation) pipeline, shows no data and is unusable.

**Backend Setup:**
*   **Services:** Dockerized FastAPI services:
    *   `frontend`: Entry point, calls `ocr_service`, then `rag_service`.
    *   `ocr_service`: Uses `python-doctr` library for local OCR (models: `db_resnet50`, `crnn_vgg16_bn`). Attempts direct PDF text extraction, falls back to `doctr` OCR.
    *   `rag_service`: Ingests text into Qdrant.
    *   `qdrant`: Vector database.
    *   `redis`: Caching (has been flushed).
*   **Dockerfile:** Common `python:3.11-slim` base. System dependencies (`libgl1-mesa-glx`, `libglib2.0-0`, `libgtk2.0-0`, `libsm6`, `libxext6`, `libxrender1`) added to support OpenCV (`cv2`) for `doctr`.

**Debugging Journey & Current State:**
1.  **Initial Problem:** OCR via Hugging Face Inference API for `mindee/doctr-ocr` started failing (404).
2.  **Mitigation:** Switched `ocr_service` to use `python-doctr` locally.
3.  **System Library Fixes:** Resolved several `ImportError`s in `ocr_service` by adding system libraries to `Dockerfile`.
4.  **Logging Issue Investigation:**
    *   `docker compose ps` shows `ocr_service` as `Up` and running.
    *   `ocr_service` logs show successful `doctr` model downloads on startup.
    *   Detailed Python `logging.info()` messages from within the main document processing logic (`OCRPipeline.process_document` and its sub-methods) were MISSING from `docker compose logs ocr_service`.
    *   The only `ocr_service` logs visible after model downloads were Uvicorn's basic startup messages and then a final `200 OK` for incoming requests, with no application-level processing trace in between.
5.  **Backend Verification:**
    * Used `curl http://localhost:8001/cached_ocr_data/31837985202301.pdf` to view the OCR results
    * Saved the output to `temp_ocr_output.json` for analysis
    * Confirmed that backend successfully extracted and stored text from all 63 pages (approximately 351KB of data)
    * Found that the OCR pipeline was working correctly with complete text extraction

**Resolution - Frontend UI Display Issue:**
After analyzing the code and the OCR data, we discovered that the issue was not with the OCR extraction process but with the Flutter app's UI implementation:

1. **Root Cause:** The Flutter app was using a Text widget with explicit limits:
   ```dart
   Text(_ocrResult!['text'], maxLines: 8, overflow: TextOverflow.ellipsis)
   ```
   This was restricting the display to only 8 lines with an ellipsis, giving the appearance that only a small portion of text was being extracted.

2. **Solution Implemented:**
   * Replaced the limited Text widget with a scrollable container:
   ```dart
   Container(
     height: 300, // Fixed height container
     decoration: BoxDecoration(
       border: Border.all(color: Colors.grey.shade300),
       borderRadius: BorderRadius.circular(8),
     ),
     child: SingleChildScrollView(
       child: Padding(
         padding: const EdgeInsets.all(8.0),
         child: Text(_ocrResult!['text']),
       ),
     ),
   )
   ```
   * Increased API service timeout from 60 to 90 seconds to better handle large documents
   * Created new documentation in `docs/planning/ocr_display_fix.md` with details of the fix

3. **Verification:** 
   * Flutter app now correctly displays the complete OCR text from all pages
   * Users can scroll through the entire document text 
   * The QA feature should now function properly with the complete text available

**Remaining Questions:**
* We still need to investigate why the logging from the OCR pipeline is not showing up in the Docker logs
* QA functionality needs to be verified with the new text display implementation

**Next Steps:**
1. Test the QA functionality with the updated UI to confirm it works as expected
2. Address the logging configuration issue in the OCR service
3. Consider implementing additional improvements such as text search functionality and preserving document formatting

This document will be updated as the situation evolves. 