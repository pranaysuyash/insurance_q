#!/bin/bash
set -e

# Load secrets from .env if present (never hardcode secrets in this file)
if [ -f .env ]; then set -a; source .env; set +a; fi

echo "🧪 Testing Enhanced Insurance RAG App Locally"
echo "============================================="

# Check if services are running
echo "1️⃣ Checking local environment..."

# Check if Python environment is activated
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "✅ Virtual environment activated: $VIRTUAL_ENV"
else
    echo "⚠️ No virtual environment detected. Consider activating one."
fi

# Check if required environment variables are set
echo ""
echo "2️⃣ Checking environment variables..."
if [ -z "$OPENAI_API_KEY" ]; then
    echo "⚠️ OPENAI_API_KEY not set. Loading from .env file..."
    if [ -f ".env" ]; then
        export $(cat .env | grep -v '#' | xargs)
        echo "✅ Environment variables loaded from .env"
    else
        echo "❌ No .env file found. Please create one with OPENAI_API_KEY"
        exit 1
    fi
else
    echo "✅ OPENAI_API_KEY is set"
fi

# Kill any existing server on port 8000
echo ""
echo "3️⃣ Cleaning up any existing server..."
pkill -f "uvicorn.*8000" 2>/dev/null || echo "No existing server found"
sleep 2

# Set environment variables for local testing
export PYTHONPATH="$(pwd)"
export LOG_LEVEL="INFO"
export QDRANT_URL="https://c0496763-dd69-4f30-9b8a-ca0b9294ddf2.us-east4-0.gcp.cloud.qdrant.io:6333"
export QDRANT_API_KEY="${QDRANT_API_KEY:?QDRANT_API_KEY must be set in .env or environment}"
export QDRANT_COLLECTION="insurance_documents_v2"
export USE_OPENAI_FIRST="true"
export OPENAI_EMBEDDING_MODEL="text-embedding-ada-002"
export OPENAI_CHAT_MODEL="gpt-3.5-turbo"

# Start the application
echo ""
echo "4️⃣ Starting the enhanced application..."
echo "📱 API will be available at: http://localhost:8000"
echo "🔗 Health check: http://localhost:8000/health"
echo "🔍 Debug services: http://localhost:8000/debug/services"
echo "📚 API docs: http://localhost:8000/docs"
echo ""
echo "🎯 Starting Enhanced Insurance RAG App v2.0.0..."
echo "Press Ctrl+C to stop the server"
echo ""

# Run the application with explicit module path
cd "$(dirname "$0")"
uvicorn src.app.main:app --host 0.0.0.0 --port 8000 --reload --log-level info
