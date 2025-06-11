#!/bin/bash
set -e

echo "🔧 Installing Enhanced Insurance RAG App Dependencies"
echo "====================================================="

# Check if virtual environment is activated
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "✅ Virtual environment activated: $VIRTUAL_ENV"
else
    echo "⚠️ No virtual environment detected. Consider activating one."
    echo "   python -m venv venv"
    echo "   source venv/bin/activate"
fi

echo ""
echo "1️⃣ Installing PyTorch (CPU-optimized for faster installation)..."
pip install torch==2.1.0 torchvision==0.16.0 --index-url https://download.pytorch.org/whl/cpu

echo ""
echo "2️⃣ Installing core dependencies..."
pip install fastapi==0.104.1 uvicorn[standard]==0.24.0 python-multipart==0.0.6

echo ""
echo "3️⃣ Installing AI/ML dependencies..."
pip install openai==1.3.0 huggingface-hub==0.17.3

echo ""
echo "4️⃣ Installing database and caching..."
pip install qdrant-client==1.6.9 redis==5.0.1

echo ""
echo "5️⃣ Installing document processing..."
pip install PyMuPDF==1.23.8 pillow==10.1.0
pip install python-doctr[torch]==0.7.0

echo ""
echo "6️⃣ Installing remaining dependencies..."
pip install pydantic==2.5.0 firebase-admin==6.2.0 email-validator==2.1.0
pip install python-jose[cryptography]==3.3.0 passlib[bcrypt]==1.7.4
pip install python-dotenv==1.0.0 structlog==23.2.0 requests==2.31.0
pip install python-dateutil==2.8.2 validators==0.22.0 aiofiles==23.2.1
pip install jinja2==3.1.2 numpy==1.24.3

echo ""
echo "✅ All dependencies installed successfully!"
echo ""
echo "🚀 Ready to run the application!"
echo "   ./test_local.sh"
