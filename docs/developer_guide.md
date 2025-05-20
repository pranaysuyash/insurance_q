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

- Python 3.9+ (3.11 recommended)
- Node.js 18+ (for frontend development)
- PostgreSQL 14+
- Docker and Docker Compose
- Git

### Initial Setup

1. **Clone the repository**

```bash
git clone https://github.com/your-organization/insurance-app.git
cd insurance-app
```

2. **Set up Python virtual environment**

```bash
# Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt  # Development dependencies
```

3. **Set up environment variables**

Create a `.env` file in the project root directory based on the provided `.env.example`:

```
# Database
DATABASE_URL=postgresql://username:password@localhost:5432/insurance_app
TEST_DATABASE_URL=postgresql://username:password@localhost:5432/insurance_app_test

# Storage
STORAGE_BUCKET=local-development-bucket
STORAGE_PROVIDER=local  # Options: local, s3, gcs

# AI Services
OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key

# Security
SECRET_KEY=your_secret_key
AUTH_TOKEN_EXPIRY_MINUTES=60
REFRESH_TOKEN_EXPIRY_DAYS=7

# Features
ENABLE_OCR=true
ENABLE_COMPARISON=true
ENABLE_NOTIFICATIONS=true

# Development
DEBUG=true
ENVIRONMENT=development
```

4. **Set up database**

```bash
# Create database
createdb insurance_app
createdb insurance_app_test

# Run migrations
alembic upgrade head
```

5. **Set up frontend (if working on UI components)**

```bash
cd frontend
npm install
```

### Using Docker for Development

Alternatively, you can use Docker to set up the development environment:

```bash
# Build and start all services
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Stop all services
docker-compose -f docker-compose.dev.yml down
```

### AI Service Configuration

To work with the AI components, you'll need API keys for:

1. **OpenAI API** - For GPT models and embeddings
2. **Anthropic API** - For Claude models (optional)
3. **Google Cloud Vision API** - For OCR (optional, can use Tesseract locally)

Add these API keys to your `.env` file or set them as environment variables.

## Project Structure

The project follows a modular architecture with clear separation of concerns:

```
insurance-app/
├── api/                  # FastAPI application
│   ├── core/             # Core functionality and config
│   ├── dependencies/     # Dependency injection
│   ├── models/           # Database models
│   ├── routers/          # API routes
│   ├── schemas/          # Pydantic schemas
│   ├── services/         # Business logic
│   └── main.py           # Application entry point
├── frontend/             # React frontend (if applicable)
├── pipelines/            # Document processing pipelines
│   ├── extraction/       # Information extraction modules
│   ├── ocr/              # OCR processing modules
│   ├── embeddings/       # Vector embedding generation
│   └── validation/       # Extraction validation
├── qa/                   # Question answering system
│   ├── retrieval/        # Context retrieval modules
│   ├── generation/       # Answer generation modules
│   ├── verification/     # Answer verification modules
│   └── prompts/          # LLM prompts
├── tests/                # Test suite
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── fixtures/         # Test fixtures and sample data
├── scripts/              # Utility scripts
├── alembic/              # Database migrations
├── docker/               # Docker configurations
└── docs/                 # Documentation
```

### Key Components

1. **API Layer (`api/`)**: FastAPI application providing RESTful endpoints
2. **Document Processing (`pipelines/`)**: Modules for processing insurance documents
3. **QA System (`qa/`)**: Retrieval-augmented generation system for answering questions
4. **Frontend (`frontend/`)**: User interface components (React/Streamlit)
5. **Infrastructure (`docker/`, `alembic/`)**: Deployment and database configuration

## Development Workflow

### Running the Application Locally

1. **Start the backend API**

```bash
# Activate virtual environment
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Run the FastAPI application with auto-reload
uvicorn api.main:app --reload --port 8000
```

2. **Start the frontend (if applicable)**

```bash
cd frontend
npm run dev
```

3. **Access the application**
   - API: http://localhost:8000
   - API documentation: http://localhost:8000/docs
   - Frontend: http://localhost:3000

### Development Cycles

1. **Feature Development**
   - Create a feature branch from `develop`
   - Implement the feature with tests
   - Create a pull request
   - Address review comments
   - Merge to `develop` when approved

2. **Bug Fixes**
   - Create a bug fix branch from `develop`
   - Fix the issue with appropriate tests
   - Create a pull request
   - Address review comments
   - Merge to `develop` when approved

3. **Releases**
   - Merge `develop` to `main` for production releases
   - Tag releases with semantic versioning
   - Deploy to production

### Code Style and Linting

We follow strict code style guidelines to maintain consistency:

1. **Python Code**
   - Use Black for code formatting
   - Use isort for import sorting
   - Use flake8 for linting
   - Use mypy for type checking

2. **Frontend Code**
   - Use ESLint for JavaScript/TypeScript linting
   - Use Prettier for code formatting

Run the linting checks using:

```bash
# Backend
black .
isort .
flake8
mypy .

# Frontend
cd frontend
npm run lint
```

## API Documentation

### Automatic Documentation

The API documentation is automatically generated using FastAPI's built-in documentation tools:

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Authentication

The API uses JSON Web Tokens (JWT) for authentication:

1. **Login Endpoint**: `/api/auth/login`
2. **Token Refresh**: `/api/auth/refresh`
3. **Authenticated Requests**: Include the JWT token in the `Authorization` header:
   ```
   Authorization: Bearer <token>
   ```

### Key Endpoints

Here are some of the key API endpoints you'll work with:

#### Documents and Policies

- `POST /api/documents/upload` - Upload a new document
- `GET /api/documents/{document_id}` - Get document details
- `GET /api/documents` - List user's documents
- `GET /api/policies/{policy_id}` - Get policy details
- `GET /api/policies` - List user's policies

#### QA System

- `POST /api/qa/question` - Ask a question
- `GET /api/qa/conversations` - List conversations
- `GET /api/qa/conversations/{conversation_id}` - Get conversation details

#### User Management

- `POST /api/users/register` - Register a new user
- `GET /api/users/me` - Get current user info
- `PUT /api/users/me` - Update user info

## Testing

### Test Structure

Tests are organized into:

1. **Unit Tests**: Test individual functions and classes in isolation
2. **Integration Tests**: Test interactions between components
3. **End-to-End Tests**: Test complete user workflows

### Running Tests

```bash
# Run all tests
pytest

# Run specific test categories
pytest tests/unit/
pytest tests/integration/

# Run tests with coverage report
pytest --cov=api --cov=pipelines --cov=qa

# Run tests and generate HTML coverage report
pytest --cov=api --cov=pipelines --cov=qa --cov-report=html
```

### Test Fixtures

Common test fixtures are located in `tests/fixtures/`, including:

- Sample PDF documents
- Mock API responses
- Test database setups

### Mocking External Services

When testing components that interact with external services:

1. Use the `unittest.mock` library for simple mocks
2. Use `pytest-mock` for more complex scenarios
3. Use response fixtures for consistent testing

Example of mocking an external API:

```python
def test_openai_extraction(mocker):
    # Mock the OpenAI API call
    mock_response = {"choices": [{"message": {"content": "extracted content"}}]}
    mocker.patch("api.services.ai.openai_client.call", return_value=mock_response)
    
    # Test the extraction function
    result = extract_policy_information("sample text")
    
    # Assertions
    assert result is not None
    assert "extracted content" in result
```

## Deployment

### Deployment Environments

The application supports multiple deployment environments:

1. **Development**: Local development environment
2. **Staging**: Pre-production testing environment
3. **Production**: Live production environment

### Deployment Using Docker

Production deployment uses Docker and Docker Compose:

```bash
# Build the images
docker-compose -f docker-compose.prod.yml build

# Deploy the services
docker-compose -f docker-compose.prod.yml up -d
```

### Cloud Deployment

For cloud deployment, we use:

1. **Container Orchestration**: Kubernetes or AWS ECS
2. **Database**: Managed PostgreSQL service
3. **Storage**: S3 or GCS for document storage
4. **Caching**: Redis for caching and session management

Deployment configurations for different cloud providers are in the `deploy/` directory.

### CI/CD Pipeline

The CI/CD pipeline is implemented using GitHub Actions:

1. **On Pull Request**: Run tests, linting, and code quality checks
2. **On Merge to Develop**: Deploy to staging environment
3. **On Merge to Main**: Deploy to production environment

## Contribution Guidelines

### Getting Started

1. Fork the repository
2. Clone your fork
3. Set up the development environment
4. Create a feature branch

### Pull Request Process

1. Ensure code passes all tests and linting
2. Update documentation as needed
3. Include unit tests for new functionality
4. Create a pull request with a clear description
5. Reference any related issues

### Code Review

All code changes require review before merging:

1. At least one approval is required
2. All comments must be resolved
3. CI checks must pass
4. Documentation must be updated

### Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types include:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `test`: Adding or modifying tests
- `chore`: Changes to the build process or auxiliary tools

Example:
```
feat(document): add support for multi-page table extraction

This adds the ability to extract tables that span multiple pages in insurance policies.

Closes #123
```

## Troubleshooting

### Common Issues

#### Database Connection Issues

```
ERROR: Could not connect to the database
```

**Solution**: Check that PostgreSQL is running and your `.env` file has the correct `DATABASE_URL`.

#### OpenAI API Key Issues

```
ERROR: OpenAI API key not found or invalid
```

**Solution**: Ensure your OpenAI API key is correctly set in the `.env` file and that it has not expired.

#### PDF Processing Issues

```
ERROR: Failed to process PDF: Unsupported format
```

**Solution**: Ensure the PDF is not encrypted or password-protected. Check that it's a valid PDF file.

### Getting Help

1. Check the existing issues on GitHub
2. Search the project documentation
3. Create a new issue with detailed information:
   - Description of the problem
   - Steps to reproduce
   - Expected vs. actual behavior
   - Environment details (OS, Python version, etc.)

### Logging

The application uses structured logging for easier debugging:

```python
# Example of logging in code
import logging

logger = logging.getLogger(__name__)
logger.info("Processing document", extra={"document_id": document_id})
```

Logs are output to:
- Console during development
- Log files in production
- Cloud logging services in cloud deployments

View logs in production using:
```bash
docker-compose -f docker-compose.prod.yml logs -f app
```

### Debugging Tools

1. **API Debugging**: Use the `/docs` Swagger UI to test API endpoints
2. **Database Inspection**: Use `psql` or a GUI tool like pgAdmin
3. **Application Performance**: Use the `/metrics` endpoint for Prometheus metrics
