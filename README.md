# Insurance Policy Parser & QA (API-Driven)

An intelligent system for parsing insurance policy documents and answering questions using OCR and RAG, now powered by Hugging Face and OpenAI APIs for enhanced scalability and maintainability.

## Features

- Document Upload & Processing (PDF, Images)
- OCR Text Extraction (via Hugging Face Inference API)
- Document Layout Element Extraction (via Hugging Face Inference API - Document QA)
- Intelligent Question Answering via RAG (using OpenAI Embeddings & Chat Models)
- Modern Web Interface

## Architecture (API-Driven)

The application consists of several microservices orchestrated by Docker Compose, with a focus on leveraging managed AI services:

- **Frontend Service** (Port 8080): FastAPI web interface (HTML, JS, CSS) and API gateway. **After uploading a document, the extracted full text and identified layout elements (e.g., title, dates, custom Q&A) will be displayed.**
- **OCR Service** (Port 8000): FastAPI service using a new `OCRPipeline`.
    - Converts documents (PDF/image) to images.
    - Calls Hugging Face Inference API for OCR (e.g., `mindee/doctr-ocr`) and Document QA (e.g., `impira/layoutlm-document-qa`) to extract text and layout elements.
    - Caches full OCR results in Redis.
    - **Triggers ingestion into the RAG service** by sending structured data (text blocks, layout elements, metadata).
- **RAG Service** (Port 8001): FastAPI service for question answering.
    - Provides an endpoint for ingesting processed document data (text blocks) from the OCR service.
    - Uses OpenAI API to generate embeddings (`text-embedding-ada-002` or configurable, e.g., `text-embedding-3-small`) for text blocks. This is a core function and requires the `OPENAI_API_KEY`.
    - Implements a fallback mechanism to a Hugging Face embedding model (e.g., `sentence-transformers/all-mpnet-base-v2`) if the primary OpenAI embedding fails. This behavior is configurable.
    - Stores embeddings and metadata in Qdrant.
    - For querying, embeds the user's question using OpenAI, searches Qdrant for relevant context, and uses an OpenAI chat model (e.g., `gpt-3.5-turbo`, `gpt-4o-mini`) to generate answers. This also requires the `OPENAI_API_KEY`.
    - Caches RAG query results in Redis.
- **Qdrant** (Ports 6333, 6334): Vector database for storing document embeddings. This is our chosen vector store.
- **Redis** (Port 6379): In-memory cache for OCR results and RAG query results.

**Rationale for API-Driven Approach:** See `docs/technical/architecture/production_stack_architecture.md` for a detailed explanation of the benefits (scalability, reduced operational burden, faster iteration) compared to self-hosting large models.

**Why Docker?** Even with external APIs for model inference, Docker and Docker Compose remain essential for:
*   **Orchestrating Services:** Managing the multiple backend services (Frontend, OCR, RAG), Qdrant, and Redis.
*   **Consistent Environments:** Ensuring all services run reliably across different developer machines and deployment targets.
*   **Simplified Dependencies:** Isolating dependencies for each Python FastAPI service.
*   **Ease of Deployment:** Streamlining the process of running the entire application stack.

## Prerequisites

- **Git**: For cloning the repository.
- **Docker & Docker Compose**: Ensure Docker Desktop (or Docker Engine + Docker Compose CLI) is installed and running. ([Install Docker](https://docs.docker.com/get-docker/))
- **Node.js & npm**: Version 16+ (for frontend asset building).
- **Hugging Face Account & Token**: (Required) For accessing Hugging Face Inference APIs used by the OCR service.
- **OpenAI Account & API Key**: (Required) For accessing OpenAI Embeddings and Chat Completion APIs used by the RAG service for its core functionality.

## Setup Instructions

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/pranaysuyash/insurance_q.git # Or your fork
    cd insurance_app
    ```

2.  **API Key Configuration (Crucial):**
    Create a `.env` file in the root of the project (`insurance_app/.env`) with your API keys:
    ```env
    HF_TOKEN=your_actual_hugging_face_user_access_token
    OPENAI_API_KEY=your_actual_openai_api_key
    
    # Optional: Override default models for OCR/RAG pipelines
    # HF_OCR_MODEL=mindee/doctr-ocr
    # HF_DOC_QA_MODEL=impira/layoutlm-document-qa
    # OPENAI_EMBEDDING_MODEL=text-embedding-ada-002
    # OPENAI_CHAT_MODEL=gpt-3.5-turbo
    # EMBEDDING_MODEL=sentence-transformers/all-mpnet-base-v2 # For RAG fallback
    # USE_OPENAI_FIRST=true # For RAG, true to use OpenAI first, false for HF first
    # OCR_IMAGE_DPI=200
    # LOG_LEVEL=INFO
    ```
    *   **Important:** Add `.env` to your `.gitignore` file (it should already be there) to prevent committing secret keys.
    *   The `HF_TOKEN` is used by the `ocr_service`. The `OPENAI_API_KEY` is **essential** for the `rag_service` to generate embeddings and provide answers.
    *   Docker Compose will automatically load these environment variables.

3.  **Install Node.js Dependencies & Build Frontend Assets:**
    ```bash
    npm install
    npm run build
    ```
    This installs `tailwindcss` and builds the necessary CSS.

## Running the Full Application with Docker (Recommended)

This is the simplest way to run all services together.

1.  **Ensure Docker Desktop is running.**
2.  **Ensure your `.env` file is created and populated with your API keys.**

3.  **Start all services:**
    ```bash
    docker compose up --build -d
    ```
    *   `--build` ensures images are rebuilt with the latest code changes (important after refactoring).
    *   The `-d` flag runs services in detached mode.
    *   The first time, Docker will build images, which might take time.
    *   Services:
        *   Qdrant: `http://localhost:6333` (Dashboard: `http://localhost:6333/dashboard`)
        *   Redis: Port `6379`
        *   OCR Service: `http://localhost:8000`
        *   RAG Service: `http://localhost:8001`
        *   Frontend: `http://localhost:8080`

4.  **Check Service Status:**
    ```bash
    docker compose ps
    ```
    All services should ideally show `Up`.

5.  **View Logs (if needed for troubleshooting):**
    ```bash
    docker compose logs -f
    docker compose logs -f ocr_service
    docker compose logs -f rag_service
    docker compose logs -f frontend
    ```

6.  **Stopping Services:**
    ```bash
    docker compose down
    ```
    To remove volumes (all data will be lost): `docker compose down -v`

## Local Development (Python Services)

Not fully detailed here post-refactor due to primary reliance on Docker for service discovery and environment consistency with API keys. Running individual services locally would require:
*   Qdrant and Redis running (e.g., `docker compose up -d qdrant redis`).
*   Python virtual environment with `requirements.txt` installed.
*   `.env` file sourced or environment variables (`HF_TOKEN`, `OPENAI_API_KEY`, service URLs) set in each terminal.
*   Running each FastAPI service (`uvicorn src.ocr.service:app ...`, etc.) in separate terminals.
*   `npm run dev` for Tailwind.

## Testing the Full Flow

1.  **Access the Web Application:** `http://localhost:8080`
2.  **Upload a Document:** Use the UI.
3.  **Monitor Document Processing:**
    *   The UI should show status updates.
    *   "Full Text" and "Layout Elements" (or similar, depending on frontend HTML updates) should populate with data from the OCR service.
    *   Check logs of `frontend`, `ocr_service`, and `rag_service` if issues occur.
4.  **Ask a Question:** Use the "Ask Questions" section.
5.  **Review the Answer:** The RAG service's response will be displayed.

## Troubleshooting Common Issues

*   **API Key Errors (OCR/RAG Services):**
    *   Ensure `HF_TOKEN` and `OPENAI_API_KEY` in your `.env` file are correct and valid. `OPENAI_API_KEY` is mandatory for the RAG service.
    *   Check that the Hugging Face token has access to the models if they are gated or private (though public models are used by default).
    *   Check OpenAI account for API key status and usage limits.
*   **Hugging Face / OpenAI API Outages or Rate Limits:**
    *   Service logs (`ocr_service`, `rag_service`) will show errors if API calls fail.
    *   Check Hugging Face and OpenAI status pages if you suspect an outage.
*   **Qdrant / Redis Issues:**
    *   Check `docker compose logs qdrant` or `docker compose logs redis`.
    *   Ensure Qdrant dashboard (`http://localhost:6333/dashboard`) is accessible.
*   **Incorrect Service URLs / Inter-service Communication:**
    *   If services can't talk to each other (e.g., OCR to RAG), check `RAG_SERVICE_URL` in `ocr_service` (via environment variables, defaults to `http://rag_service:8001`). Docker networking should handle this if service names are used.
*   **Frontend Not Displaying Data:**
    *   Check browser's developer console for JavaScript errors.
    *   Check `frontend` service logs.
    *   Verify the data structure returned by `/upload` in `frontend/app.py` matches what `index.html` JavaScript expects (especially around `full_text` and `layout_elements`).

## Environment Variables Summary

(Loaded from `.env` file by Docker Compose)

*   **`HF_TOKEN`**: (Required) Your Hugging Face User Access Token. Used by the `ocr_service`.
*   **`OPENAI_API_KEY`**: (Required) Your OpenAI API Key. Used by the `rag_service` for embeddings and chat completion.
*   **`OCR_SERVICE_URL`**: Used by Frontend service (default: `http://ocr_service:8000` within Docker).
*   **`RAG_SERVICE_URL`**: Used by Frontend and OCR services (default: `http://rag_service:8001` within Docker).
*   `QDRANT_HOST`, `QDRANT_PORT`: Used by RAG Service (defaults to `qdrant` and `6333`).
*   `QDRANT_COLLECTION`: Qdrant collection name (default: `insurance_documents_v2`).
*   `REDIS_HOST`, `REDIS_PORT`: Used by OCR & RAG Services (defaults to `redis` and `6379`).
*   `CACHE_TTL_SECONDS`: Cache TTL for RAG query results (default: `3600`).
*   `HF_OCR_MODEL`: (Optional) Specify Hugging Face model for OCR service (default: `mindee/doctr-ocr`).
*   `HF_DOC_QA_MODEL`: (Optional) Specify Hugging Face model for Document QA in OCR service (default: `impira/layoutlm-document-qa`).
*   `OPENAI_EMBEDDING_MODEL`: (Optional) OpenAI model for embeddings in RAG service (default: `text-embedding-ada-002`).
*   `OPENAI_CHAT_MODEL`: (Optional) OpenAI model for chat completion in RAG service (default: `gpt-3.5-turbo`).
*   `EMBEDDING_MODEL`: (Optional) Hugging Face model for RAG service's fallback embeddings (default: `sentence-transformers/all-mpnet-base-v2`).
*   `USE_OPENAI_FIRST`: (Optional) Boolean (`true`/`false`) for RAG service, determines if OpenAI is the primary embedding provider (default: `true`).
*   `OCR_IMAGE_DPI`: (Optional) DPI for rendering PDF pages to images in OCR service (default: `200`).
*   `LOG_LEVEL`: (Optional) Set log level for services (e.g., `DEBUG`, `INFO`, `WARNING`). Default is `INFO`.

## API Documentation (Service Endpoints)

Refer to individual service OpenAPI docs (usually at `/docs` endpoint of each service when running).

*   **Frontend Service (`http://localhost:8080`):**
    *   `GET /`: Main web interface.
    *   `POST /upload`: Upload document, triggers OCR and RAG ingestion.
    *   `POST /query`: Submit questions to the RAG system.
    *   `GET /health`: Health check.
*   **OCR Service (`http://localhost:8000`):**
    *   `POST /process_and_ingest`: Processes document using HF APIs and triggers ingestion in RAG service.
    *   `GET /cached_ocr_data/{doc_id}`: Retrieve full cached OCR data from Redis.
    *   `GET /health`: Health check.
*   **RAG Service (`http://localhost:8001`):**
    *   `POST /ingest`: Endpoint for OCR service to send processed data for vector DB ingestion.
    *   `POST /query`: Answer questions using RAG pipeline.

## Project Documentation

Comprehensive documentation is maintained in the `docs/` directory:

*   **Planning Documentation:**
    *   `docs/planning/current_issue.md`: Tracks current issues being investigated
    *   `docs/planning/ocr_display_fix.md`: Details about the OCR text display issue and its resolution
    *   `docs/planning/project_learnings.md`: Key lessons learned during development

*   **Technical Documentation:**
    *   `docs/technical/architecture/`: System architecture documentation
    *   `docs/technical/implementation/`: Implementation details for various components
    *   `docs/reference/api_documentation/`: API specifications and documentation

*   **User Experience Documentation:**
    *   `docs/user_experience/`: UI/UX documentation and guides

## Contributing & License

1.  Fork the repository.
2.  Create a feature branch.
3.  Commit your changes.
4.  Push to the branch.
5.  Create a Pull Request.

ISC License - See LICENSE file for details 