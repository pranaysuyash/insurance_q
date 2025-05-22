# Developer Guide: Insurance Policy Parser & QA App

This guide provides instructions for developers working on the Insurance Policy Parser & QA App, including environment setup, code organization, development workflows, and contribution guidelines.

## Table of Contents

1. [Development Environment Setup](#development-environment-setup)
2. [Project Structure](#project-structure)
3. [Development Workflow](#development-workflow)
4. [API Documentation](#api-documentation)
5. [Testing](#testing)
6. [Deployment](#deployment)
7. [Contribution Guidelines](#contribution-guidelines)
8. [Troubleshooting](#troubleshooting)

## Development Environment Setup

### Prerequisites

Before you begin, ensure you have the following installed:

- Python 3.9+ (3.11 recommended, as used in `Dockerfile` and `venv`)
- Docker and Docker Compose
- Git
- Flutter SDK (if working on the mobile app, see `mobile/README.md` for specific version and setup)
- Node.js and npm (for Tailwind CSS compilation, see `package.json`)

### Initial Setup

1. **Clone the repository**

```bash
git clone <repository-url>
cd insurance_app
```

2. **Set up Python virtual environment (for local development outside Docker, or for IDE integration)**

While the primary development and execution path is via Docker, you might want a local venv.
The `create_env.py` script can help, or do it manually:

```bash
python3.11 -m venv venv
source venv/bin/activate  # On Windows: venv\\Scripts\\activate
pip install -r requirements.txt
```
*Note: Ensure your local Python version matches the one in Docker (`python:3.11-slim`) for consistency.*

3. **Set up environment variables**

Create a `.env` file in the project root directory by copying `sample.env`:

```bash
cp sample.env .env
```

Then, edit `.env` and fill in the necessary API keys and configurations:
```env
# Required for AI features
HF_TOKEN=your_hugging_face_token_if_needed_for_private_models
OPENAI_API_KEY=your_openai_api_key

# Service Configuration (defaults are usually fine for local Docker setup)
QDRANT_HOST=qdrant
QDRANT_PORT=6333
QDRANT_COLLECTION=insurance_docs
OCR_SERVICE_URL=http://ocr_service:8002/process_document
RAG_SERVICE_URL=http://rag_service:8001
EMBEDDING_MODEL=sentence-transformers/all-mpnet-base-v2 # Example HF model
OPENAI_EMBEDDING_MODEL=text-embedding-ada-002 # Example OpenAI model
USE_OPENAI_FIRST=true # or false, to set primary embedding service

# Backend-for-Frontend (BFF) configuration
BFF_HOST=0.0.0.0
BFF_PORT=8080

# OCR Service configuration
OCR_HOST=0.0.0.0
OCR_PORT=8002

# RAG Service configuration
RAG_HOST=0.0.0.0
RAG_PORT=8001

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
CACHE_TTL_SECONDS=3600

# Logging level (e.g., INFO, DEBUG)
LOG_LEVEL=INFO
```
Refer to `set_env_vars.py` for how these are used and potentially other variables that might be introduced.

4. **Build Frontend Static Assets (Tailwind CSS)**
If you modify `src/frontend/static/css/input.css` or `tailwind.config.js`, you need to rebuild the `main.css`:
```bash
npm install
npm run build:css
```
This is also handled during the Docker build.

### Using Docker for Development

This is the recommended way to run the entire application stack.

1. **Build and start all services:**

```bash
docker compose up --build -d
```
The `-d` flag runs the services in detached mode. Omit it to see logs in the current terminal.

2. **View logs:**

If running in detached mode:
```bash
docker compose logs -f            # View logs for all services
docker compose logs -f frontend   # View logs for a specific service (e.g., frontend)
```

3. **Stop all services:**

```bash
docker compose down
```

4. **Accessing Services:**
- **Web Frontend:** `http://localhost:8080` (or the port mapped in `docker-compose.yml` for the `frontend` service)
- **Qdrant Dashboard:** `http://localhost:6333/dashboard`
- Individual service APIs (if you need to test them directly):
  - RAG Service: `http://localhost:8001/docs`
  - OCR Service: `http://localhost:8002/docs`

### AI Service Configuration

- **OpenAI API Key:** Essential for RAG answer generation and (optionally) primary embeddings. Set `OPENAI_API_KEY` in your `.env` file.
- **Hugging Face Token:** `HF_TOKEN` in `.env` might be needed if you use private or gated models from Hugging Face Hub for OCR or fallback embeddings. Public models usually don't require it.

## Project Structure

The project is organized into several key directories:

```
insurance_app/
├── .github/                # GitHub Actions workflows
├── docs/                   # Project documentation
├── mobile/                 # Flutter mobile application
│   ├── lib/                # Main Flutter app code
│   └── ...                 # Other Flutter project files (android, ios, etc.)
├── scripts/                # Utility and helper scripts
├── src/                    # Backend Python source code
│   ├── api/                # Potentially for standalone API services (if any beyond BFF)
│   ├── app/                # Main application logic (could be merged with specific services)
│   ├── frontend/           # Backend-for-Frontend (BFF) service
│   │   ├── app.py          # FastAPI app for BFF
│   │   ├── static/         # Static assets (CSS, JS, images)
│   │   └── templates/      # HTML templates (Jinja2)
│   ├── models/             # Pydantic models for data structures
│   ├── ocr/                # OCR processing service and pipeline
│   │   └── pipeline.py     # Core OCR logic
│   ├── rag/                # Retrieval-Augmented Generation service and pipeline
│   │   └── pipeline.py     # Core RAG logic
│   └── utils/              # Common utility functions
├── tests/                  # Test suite for backend services
├── .env                    # Local environment variables (gitignored)
├── sample.env              # Example environment variables
├── check_redis.py          # Script to check Redis connection
├── create_env.py           # Script to help create .env file
├── docker-compose.yml      # Docker Compose configuration for all services
├── Dockerfile              # Dockerfile for the Python backend services
├── package.json            # Node.js dependencies (for Tailwind CSS)
├── package-lock.json       #
├── README.md               # Project root README
├── requirements.txt        # Python dependencies
├── set_env_vars.py         # Script to load .env variables (used by services)
├── tailwind.config.js      # Tailwind CSS configuration
└── ...                     # Other configuration files
```

### Key Components

1. **`src/frontend/app.py` (Backend-for-Frontend - BFF):**
- FastAPI application serving the web interface (HTML, CSS, JS).
- Handles user requests from the web UI.
- Communicates with `ocr_service` and `rag_service`.
2. **`src/ocr/pipeline.py` (OCR Service):**
- Handles PDF/image ingestion and text extraction using OCR models (e.g., from Hugging Face).
- Exposes an API for the BFF to call.
3. **`src/rag/pipeline.py` (RAG Service):**
- Manages document embedding, storage in Qdrant, and question-answering using LLMs (e.g., OpenAI).
- Provides an API for ingestion (from OCR service) and querying (from BFF).
4. **`mobile/` (Flutter Mobile App):**
- Cross-platform mobile application.
- Interacts with the backend services (likely via the BFF or dedicated API endpoints).
- See `mobile/README.md` and `docs/user_experience/mobile_app_architecture.md` for more details.
5. **Docker (`docker-compose.yml`, `Dockerfile`):**
- Defines and orchestrates the services (`frontend`, `ocr_service`, `rag_service`, `qdrant`, `redis`).
- Ensures a consistent development and deployment environment.
6. **Qdrant & Redis:**
- Qdrant is the vector database for RAG.
- Redis is used for caching (e.g., RAG query results, OCR results).

## Development Workflow

### Running the Application Locally (Docker Recommended)

Follow the steps in [Using Docker for Development](#using-docker-for-development).

### Making Changes

1. **Backend Python Services (`src/`):**
- Modify the Python code in the respective service directory (e.g., `src/rag/pipeline.py`).
- Docker Compose with `--build` will rebuild the Python service image if `requirements.txt` or source code changes. You might need to restart the specific service or the compose stack:
```bash
docker compose up -d --no-deps --build <service_name> # e.g., rag_service
# or
docker compose restart <service_name>
# or rebuild all
docker compose up --build -d
```
2. **Web Frontend (`src/frontend/static/`, `src/frontend/templates/`):**
- For changes to HTML templates (`*.html`) or Python code in `src/frontend/app.py`, restarting the `frontend` service in Docker is usually sufficient:
```bash
docker compose restart frontend
# or if app.py changed significantly and Dockerfile copies it
docker compose up -d --no-deps --build frontend
```
- For CSS changes (`src/frontend/static/css/input.css` or `tailwind.config.js`):
1. Rebuild the `main.css`: `npm run build:css` (or ensure your Docker build step for the frontend service does this).
2. Restart/rebuild the `frontend` Docker service.
3. **Mobile App (`mobile/`):**
- Follow standard Flutter development practices.
- Run the app on an emulator or device.
- Ensure the backend services (running in Docker) are accessible from your mobile development environment (usually `http://localhost:<port>` or `http://10.0.2.2:<port>` for Android emulator).

### Branching Strategy (Example)

- **`main`**: Production-ready code.
- **`develop`**: Integration branch for features.
- **Feature branches (`feat/feature-name`):** Create from `develop` for new features.
- **Bugfix branches (`fix/bug-name`):** Create from `develop` or `main` (for hotfixes).

### Code Style and Linting

- **Python:**
- Consider using tools like Black (formatter) and Ruff (linter, faster alternative to Flake8+isort+more).
- Add configurations for these tools (e.g., `pyproject.toml`).
- Example commands (if configured):
```bash
# ruff format .
# ruff check --fix .
```
- **Frontend (Tailwind/HTML/JS):**
- Prettier can be used for formatting.
- **Flutter:**
- `flutter analyze`
- `flutter format .`

### Committing Changes

- Follow conventional commit messages if desired (e.g., `feat: add user login`, `fix: resolve OCR processing error`).
- Ensure tests pass before pushing.

## API Documentation

The FastAPI backend services provide automatic API documentation:

- **RAG Service Swagger UI:** `http://localhost:8001/docs`
- **RAG Service ReDoc:** `http://localhost:8001/redoc`
- **OCR Service Swagger UI:** `http://localhost:8002/docs`
- **OCR Service ReDoc:** `http://localhost:8002/redoc`
- **Frontend (BFF) Swagger UI:** `http://localhost:8080/docs` (if it exposes API endpoints beyond serving HTML)
- **Consolidated API Specification:** See `docs/reference/api_documentation/api_specification.md`. This should be manually kept in sync with the actual APIs.

## Testing

- The `tests/` directory contains backend tests.
- Pytest is commonly used for Python testing.
- Tests can be run inside the Docker containers or locally (if venv is set up).
Example (conceptual, adapt to your test runner and service):
```bash
docker compose exec rag_service pytest tests/rag  # Assuming tests are in the image
```
Or if tests are run from host against Dockerized services:
```bash
# (Activate venv if needed)
# pytest tests/ --base-url-rag=http://localhost:8001 ...
```
- Key test files observed:
- `test_embedding_fallback.py`
- `test_endpoints.py`
- `test_openai_key.py`
- `test_rag.py`
Integrate these into a cohesive testing strategy.

## Deployment

- Deployment will typically involve building production-ready Docker images and deploying them to a cloud platform (e.g., AWS, GCP, Azure) or a Kubernetes cluster.
- Ensure `.env` files are securely managed for production environments (e.g., using secrets management tools).
- The `Dockerfile` and `docker-compose.yml` provide a starting point for containerization.
- For the Flutter app, follow Flutter's build and release process for Android and iOS.

## Contribution Guidelines

- Follow the development workflow outlined above.
- Ensure code is well-documented (docstrings, comments where necessary).
- Write unit and integration tests for new features and bug fixes.
- Update relevant documentation in the `docs/` folder if your changes affect architecture, setup, or user-facing features.
- Create Pull Requests (PRs) against the `develop` branch (or as per project policy).
- Ensure PRs are reviewed before merging.

## Troubleshooting

- **Service not starting in Docker:**
- Check logs: `docker compose logs <service_name>`
- Ensure `.env` file is correctly configured.
- Check for port conflicts on your host machine.
- **API Key Issues:**
- Double-check `OPENAI_API_KEY` and `HF_TOKEN` in `.env`.
- For OpenAI, ensure your account has credit/is active.
- **Flutter app can't connect to backend:**
- Ensure Docker services are running.
- Use `http://localhost:<port>` if running on iOS simulator or `http://10.0.2.2:<port>` for Android emulator when backend is on the same machine.
- Verify firewall settings.
- **Tailwind CSS not updating:**
- Ensure `npm run build:css` is run after changes to `input.css` or `tailwind.config.js`.
- Clear browser cache.

This guide should help you get started with development. Refer to specific documents in the `docs/` folder for more detailed information on particular components.
