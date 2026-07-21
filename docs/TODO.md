# Project TODO & Status

> **Superseded operational checklist (2026-07-21).** The commands and
> recommendations in this historical TODO mention Qdrant, Redis, Firebase, and
> local-only paths. New work must follow the canonical Supabase architecture
> and the live gap register instead; retain this file only as historical
> context.

**Last Major Update:** Implemented dashboard/home screen with insurance terminology integration, improved document handling and UI experience. Documentation updated and code pushed to repository.

**Current Status:** Backend services refactored. Mobile app core UI implementation progressing. Ready for full end-to-end testing.

## I. Immediate Next Steps & Testing:

1.  **Set up `.env` file:**
    *   Create `insurance_app/.env`.
    *   Add valid `HF_TOKEN` and `OPENAI_API_KEY`.
2.  **Build and Run with Docker:**
    *   Run `npm install && npm run build` for frontend assets.
    *   Run `docker compose up --build -d`.
    *   Verify all services start correctly (`docker compose ps`).
3.  **End-to-End Test - Document Processing & OCR:**
    *   Access frontend: `http://localhost:8080`.
    *   Upload a test PDF/image.
    *   **Expected:**
        *   OCR service processes the document.
        *   OCR service sends data to RAG service's `/ingest` endpoint.
        *   Frontend displays "Full Text" and "Layout Elements" (or similar, based on actual HTML structure).
    *   **Verify:**
        *   Check `ocr_service` logs for successful HF API calls and data sent to RAG.
        *   Check `rag_service` logs for successful `/ingest` call and Qdrant upsertion.
        *   Check `frontend` logs for communication with `ocr_service`.
        *   Check Redis for cached OCR data (e.g., via `redis-cli`).
        *   Check Qdrant dashboard (`http://localhost:6333/dashboard`) to see if collection exists and points are added.
4.  **End-to-End Test - RAG Querying:**
    *   Use the "Ask Questions" section in the frontend.
    *   **Expected:** Frontend displays an answer from the RAG service.
    *   **Verify:**
        *   Check `rag_service` logs for query embedding, Qdrant search, and OpenAI chat completion call.
        *   Check `frontend` logs for communication with `rag_service`.
        *   Check Redis for cached RAG query results.

## II. Frontend Development (Flutter & Web):

1.  **Align Frontend (`src/frontend/static/js/main.js` and `src/frontend/templates/index.html`) with Backend:**
    *   **Displaying OCR Results:**
        *   The `/upload` endpoint in `src/frontend/app.py` now returns `{"filename": ..., "full_text": ..., "layout_elements": ...}`.
        *   The frontend JavaScript (`main.js`) needs to be updated to correctly parse and display `full_text`.
        *   Crucially, `main.js` and `index.html` need to be updated to render `layout_elements`. The previous version expected `sections` with `text` and `table_html`. The new `layout_elements` is a list of dictionaries like `{"question": "...", "answer": "...", "box_2d": [[x,y], ...], "score": ...}`.
        *   Decide how to best display these `layout_elements`:
            *   As a list of Q&A pairs.
            *   Potentially try to highlight answers on the document image if feasible (more advanced).
    *   **Error Handling:** Improve frontend error messages based on responses from backend services.
2.  **Flutter App Development:**
    *   **Define API Contracts:** Solidify how the Flutter app will interact with the FastAPI backend-for-frontend (`src/frontend/app.py`).
    *   **✅ UI Implementation Progress:**
        *   ✅ Implemented comprehensive dashboard/home screen with document summary, quick actions, and insurance terminology integration
        *   ✅ Improved document upload experience with duplicate detection
        *   ✅ Fixed default document selection in Q&A interface
        *   ✅ Enhanced document limit messaging to be more user-friendly
        *   ✅ Fixed layout issues in document selection dialog and QA screens
    *   **Remaining UI Tasks:**
        *   Implement complete Family Management screen
        *   Develop More/Settings screen with user preferences
        *   Add document preview capabilities
        *   Implement document sorting and filtering
        *   Create policy comparison interface
        *   Improve general UI error handling and user feedback mechanisms
    *   **State Management:** Continue improving state management with Riverpod
    *   **User Authentication (if `firebase_auth.py` is to be used):** Integrate Firebase authentication in Flutter and potentially in the FastAPI backend-for-frontend.

## III. Backend Enhancements & Productionization:

1.  **Asynchronous Operations:**
    *   Review `ocr_pipeline.py` and `rag_pipeline.py`. While `httpx.AsyncClient` is used in services, ensure long-running calls within the pipelines (especially to external APIs like HF and OpenAI) are fully non-blocking to maximize FastAPI service performance. This might involve `asyncio.gather` for concurrent API calls if applicable (e.g., processing multiple pages or questions).
2.  **Configuration Management:**
    *   Consider a more structured configuration approach if the number of environment variables grows significantly (e.g., Pydantic's `BaseSettings`). (Current approach is fine for now).
3.  **Error Handling & Resilience:**
    *   **OCR Service:** More granular error handling for HF API calls (rate limits, model errors, timeouts). Implement retries with backoff.
    *   **RAG Service:** More granular error handling for OpenAI API calls and Qdrant operations. Retries.
    *   **Inter-service communication:** Implement retries for calls between `ocr_service` and `rag_service`.
4.  **Scalability:**
    *   **Qdrant:** Monitor and plan for scaling Qdrant if data volume grows very large (e.g., considering Qdrant Cloud or a distributed setup if self-hosting).
    *   **FastAPI Services:** Configure multiple Uvicorn workers for production deployments.
5.  **Security:**
    *   Review API key handling (currently via `.env` and Docker, which is standard).
    *   Add input validation for all API endpoints (Pydantic helps significantly).
    *   Consider rate limiting for public-facing endpoints if applicable.
6.  **Logging & Monitoring:**
    *   Standardize log formats.
    *   Integrate with a centralized logging platform (e.g., ELK stack, Grafana Loki) for production.
    *   Add more detailed metrics for monitoring API call latencies, error rates, etc. (Prometheus/Grafana).
7.  **Cost Optimization:**
    *   Continuously monitor Hugging Face and OpenAI API costs.
    *   Optimize embedding/chat model choices based on cost/performance needs (e.g., `text-embedding-3-small` vs `large`, different chat models).
    *   Refine the list of questions sent to the Document QA model in `OCRPipeline` to only ask for truly necessary information to reduce calls/cost.

## IV. Documentation & Educational Content:

1.  **API Documentation:**
    *   Ensure `/docs` for each FastAPI service are comprehensive and up-to-date.
    *   Consider generating a consolidated API documentation portal.
2.  **Code Comments & Docstrings:**
    *   Review and enhance code comments and docstrings, especially in core pipeline logic. (Mostly done).
3.  **User Education:**
    *   ✅ Created comprehensive insurance terminology glossary for user reference
    *   ✅ Integrated terminology education into the mobile app dashboard
    *   [ ] Expand educational content with policy-specific guides
    *   [ ] Develop interactive tutorials for new users
4.  **Dependency Review:**
    *   Periodically review `requirements.txt` for unused or outdated packages.

## V. User Experience & Accessibility:

1.  **UI/UX Improvements:**
    *   ✅ Created responsive dashboard with document categorization and quick actions
    *   ✅ Implemented recent activities timeline for user context
    *   [ ] Add additional visual elements for policy health/status
    *   [ ] Improve accessibility features throughout the app
2.  **Accessibility:**
    *   [ ] Conduct full accessibility audit
    *   [ ] Ensure proper contrast ratios for text elements
    *   [ ] Add screen reader support for critical functionality
    *   [ ] Implement keyboard navigation throughout the app

## VI. Post-Documentation Review Priorities (Strategic & Technical Debt):

1.  **Deep Code-to-Documentation Synchronization for Core Services (`ocr_service`, `rag_service`, `frontend` BFF):**
    *   **Goal:** Ensure detailed technical documents precisely match the source code of primary services (functions, class interactions, error handling, model/API calls).
    *   **Files to check/update:** `docs/technical/implementation/extraction/ocr_implementation.md`, `docs/technical/ai_and_nlp/rag_implementation.md`, `docs/reference/api_documentation/api_specification.md`, `docs/developer_guide.md`.
    *   **Source code to review:** `src/ocr/pipeline.py`, `src/rag/pipeline.py`, `src/frontend/app.py`.

2.  **Populate Critical "Missing" Technical Documentation - Starting with `api_design_principles.md`:**
    *   **Goal:** Define API design principles (naming, structure, error handling, versioning, etc.) to guide consistent development.
    *   **File to populate:** `docs/technical/architecture/api_design_principles.md`.

3.  **Enhance and Verify Test Coverage for Backend Services:**
    *   **Goal:** Ensure comprehensive and up-to-date `pytest` tests for OCR and RAG services, covering critical paths and functionalities.
    *   **Action:** Run existing tests, identify gaps by reviewing `src/ocr/` and `src/rag/`, write new unit/integration tests. Update `developer_guide.md` with testing instructions.

4.  **Historical item — user authentication for the web frontend:**
    *   **Status:** Supabase Auth/account lifecycle is implemented for the current mobile/API product. This older web-frontend item remains only as a separately scoped product decision; it is not the current auth gap.
    *   **Action:** Evaluate FastAPI auth libraries, design data models if needed, implement endpoints and basic UI templates. Update `docs/user_guide.md` and `docs/developer_guide.md`.

5.  **Review and Refine Environment Configuration & Secrets Management Strategy:**
    *   **Goal:** Enhance the strategy for managing environment variables and secrets across development, staging, and production.
    *   **Action:** Review current setup (`.env`, `sample.env`, `set_env_vars.py`, `docker-compose.yml`, `Dockerfile`). Propose best practices (e.g., Docker secrets for prod), refine loading/validation. Update `docs/developer_guide.md`.
