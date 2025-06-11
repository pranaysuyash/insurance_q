#!/bin/bash
set -e

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

# Use port 8001 to avoid conflicts
PORT=8001

# Kill any existing server on the port
echo ""
echo "3️⃣ Cleaning up any existing server on port $PORT..."
sudo lsof -ti:$PORT | xargs kill -9 2>/dev/null || echo "No existing server found on port $PORT"
sleep 2

# Set environment variables for local testing
export PYTHONPATH="$(pwd)"
export LOG_LEVEL="INFO"
export QDRANT_URL="https://c0496763-dd69-4f30-9b8a-ca0b9294ddf2.us-east4-0.gcp.cloud.qdrant.io:6333"
export QDRANT_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIn0.gUETgUylDxoSvj1iw-P02in7mHnAkC5rL98tsqsSJYQ"
export QDRANT_COLLECTION="insurance_documents_v2"
export USE_OPENAI_FIRST="true"
export OPENAI_EMBEDDING_MODEL="text-embedding-ada-002"
export OPENAI_CHAT_MODEL="gpt-3.5-turbo"

# Start the application
echo ""
echo "4️⃣ Starting the enhanced application..."
echo "📱 API will be available at: http://localhost:$PORT"
echo "🔗 Health check: http://localhost:$PORT/health"
echo "🔍 Debug services: http://localhost:$PORT/debug/services"
echo "📚 API docs: http://localhost:$PORT/docs"
echo ""
echo "🎯 Starting Enhanced Insurance RAG App v2.0.0..."
echo "Press Ctrl+C to stop the server"
echo ""

# Run the application with explicit module path
cd /Users/pranay/Projects/medpiper/insurance_app
uvicorn src.app.main:app --host 0.0.0.0 --port $PORT --reload --log-level info
