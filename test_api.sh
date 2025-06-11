#!/bin/bash
set -e

echo "📋 Enhanced Insurance RAG App - Quick API Test"
echo "=============================================="

# Default URL (change if testing different environment)
BASE_URL=${1:-"http://localhost:8000"}

echo "🌐 Testing API at: $BASE_URL"
echo ""

# Test 1: Health Check
echo "1️⃣ Testing health endpoint..."
if curl -s "$BASE_URL/health" | grep -q "ok"; then
    echo "✅ Health check passed"
    curl -s "$BASE_URL/health" | python -m json.tool
else
    echo "❌ Health check failed"
    exit 1
fi

echo ""
echo "2️⃣ Testing debug services endpoint..."
if curl -s "$BASE_URL/debug/services" | grep -q "initialized"; then
    echo "✅ Debug services responding"
    curl -s "$BASE_URL/debug/services" | python -m json.tool
else
    echo "⚠️ Debug services may not be fully initialized"
    curl -s "$BASE_URL/debug/services" | python -m json.tool
fi

echo ""
echo "3️⃣ Testing documents endpoint..."
if curl -s "$BASE_URL/documents" | grep -q "documents"; then
    echo "✅ Documents endpoint responding"
    curl -s "$BASE_URL/documents" | python -m json.tool
else
    echo "❌ Documents endpoint failed"
fi

echo ""
echo "4️⃣ Testing query endpoint..."
curl -s -X POST "$BASE_URL/query" \
  -H "Content-Type: application/json" \
  -d '{"query": "What is my policy number?"}' | python -m json.tool

echo ""
echo "5️⃣ Testing processing status endpoint..."
if curl -s "$BASE_URL/processing/status" | grep -q "status"; then
    echo "✅ Processing status endpoint responding"
    curl -s "$BASE_URL/processing/status" | python -m json.tool
else
    echo "⚠️ Processing status endpoint may not be available"
fi

echo ""
echo "✅ API testing complete!"
echo ""
echo "📋 To test document upload, use:"
echo "   curl -X POST \"$BASE_URL/documents/upload\" \\"
echo "     -F \"files=@your_document.pdf\" \\"
echo "     -F \"processing_mode=full\""
