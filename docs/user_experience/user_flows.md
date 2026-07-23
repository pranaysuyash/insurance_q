# User Flows for Insurance Policy Parser & QA Application

> **Historical baseline + scope note.** This flow doc is useful for old baseline
> behavior and UX shape, but Supabase Auth and retrieval contract claims should be
> validated against the active docs under `docs/architecture/` and
> `docs/planning/coverwise_auth_and_provider_execution_plan_2026-07-22.md`.

This document outlines the primary user flows for interacting with the application, covering both the web interface and the planned Flutter mobile application.

## 1. Document Upload and Processing Flow

This flow describes how a user uploads a document and how it's processed by the system.

**Actor:** User (logged in, if authentication is implemented, or anonymous)

**Trigger:** User initiates document upload.

**Preconditions:**
*   User has an insurance policy document (PDF, JPG, PNG) they want to process.

**Steps (Web Frontend - `http://localhost:8080`):**
1.  User navigates to the main application page.
2.  User clicks the "Upload Document" button or drags and drops a file into the designated area.
3.  A file selection dialog appears (if clicked). User selects a document.
4.  Frontend displays the selected filename and a "Process" or "Upload" button.
5.  User clicks "Process/Upload".
6.  Frontend sends the file to the backend (`/upload` endpoint of the `frontend` service).
    *   UI shows a loading indicator/progress bar.
7.  `frontend` service receives the file, passes it to `ocr_service` (`/process_and_ingest`).
8.  `ocr_service` processes the document:
    *   Converts PDF pages to images (if PDF).
    *   Calls Hugging Face Inference API for OCR (`mindee/doctr-ocr`) to get text blocks.
    *   Calls Hugging Face Inference API for Document QA (`impira/layoutlm-document-qa`) with predefined questions to get `layout_elements`.
    *   Caches the full OCR result (including text blocks and layout elements) in Redis.
    *   Sends `text_blocks` and document metadata to `rag_service` (`/ingest`) for embedding and storage in Qdrant.
9.  `rag_service` ingests the data into Qdrant.
10. `ocr_service` responds to `frontend` service with a success/failure message and the `doc_id` (Redis key).
11. `frontend` service uses the `doc_id` to fetch the cached OCR data from `ocr_service` (`/cached_ocr_data/{doc_id}`).
12. `frontend` service responds to the client's browser with the `full_text` and `layout_elements`.
13. UI updates to display the extracted `full_text` and the structured `layout_elements`.
    *   Loading indicator is removed.
    *   A success message is shown, or an error message if processing failed.

**Steps (Flutter Mobile App - Conceptual):**
1.  User opens the app.
2.  User navigates to an "Upload" screen/feature.
3.  User taps an "Upload Document" button.
4.  App prompts user to select a file from device storage or take a photo.
5.  User selects/captures a document.
6.  App shows a preview or filename. User confirms.
7.  App sends the file (as bytes) to the backend (`/upload` endpoint of the `frontend` service or a dedicated mobile API gateway).
    *   UI shows a loading indicator.
8.  Backend processing occurs as described in steps 7-12 of the Web Frontend flow.
9.  App UI updates to display the extracted `full_text` and `layout_elements`.
    *   Loading indicator is removed.
    *   A success message or error is shown.

**Postconditions:**
*   Document content is extracted and structured.
*   Text blocks are stored in Qdrant for RAG.
*   User can view the extracted information.

---

## 2. Question Answering (RAG) Flow

This flow describes how a user asks a question about an uploaded document and receives an answer.

**Actor:** User

**Trigger:** User submits a question.

**Preconditions:**
*   At least one document has been successfully processed and ingested.
*   The user is viewing the interface that allows for questions (could be a general Q&A or document-specific).

**Steps (Web Frontend & Flutter App):**
1.  User types a question into the designated input field (e.g., "What is the policy effective date?").
2.  User clicks a "Submit" or "Ask" button.
3.  Client (browser or Flutter app) sends the question (and potentially a `document_id` if the question is context-specific to one document, though current RAG queries all docs) to the backend (`/query` endpoint of the `frontend` service).
    *   UI shows a loading indicator.
4.  `frontend` service relays the query to the `rag_service` (`/query` endpoint).
5.  `rag_service` processes the query:
    *   Generates an embedding for the user's question using OpenAI API.
    *   Searches Qdrant for the most relevant text chunks using the query embedding.
    *   Constructs a prompt with the retrieved context and the user's question.
    *   Calls OpenAI Chat Completion API to generate an answer.
    *   Caches the question-answer pair in Redis.
6.  `rag_service` returns the answer and source information to the `frontend` service.
7.  `frontend` service returns the response to the client.
8.  UI displays the generated answer and any relevant source snippets/references.
    *   Loading indicator is removed.

**Postconditions:**
*   User receives an answer to their question based on the document corpus.

---
## 3. User Authentication Flow (Current reference)

*Supabase Auth is the active production identity contract. Keep this section for
historical flow shape only; use current auth behavior from
[`docs/user_experience/mobile_app_architecture.md`](mobile_app_architecture.md) and
`docs/planning/coverwise_auth_provider_platform_gap_map_2026-07-22.md` for
operationally gated auth details.*
*   Registration
*   Login
*   Logout
*   Password Reset

--- 
