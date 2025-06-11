#!/bin/bash

echo "🔍 Checking what's actually running on localhost:8000"
echo "=================================================="

echo "1️⃣ Testing basic health endpoint..."
curl -s http://localhost:8000/health | python -m json.tool

echo -e "\n2️⃣ Testing all available routes..."
echo "GET /:"
curl -s http://localhost:8000/ 2>/dev/null || echo "Not available"

echo -e "\nGET /docs (FastAPI auto docs):"
curl -s http://localhost:8000/docs 2>/dev/null | head -c 100 || echo "Not available"

echo -e "\n\n3️⃣ Testing some expected endpoints..."
endpoints=("/debug/services" "/processing/status" "/query" "/documents")

for endpoint in "${endpoints[@]}"; do
    echo "Testing $endpoint:"
    response=$(curl -s -w "%{http_code}" http://localhost:8000$endpoint 2>/dev/null)
    echo "Response: $response"
    echo "---"
done

echo -e "\n4️⃣ Check if the server process is running uvicorn with the right module..."
ps aux | grep uvicorn | grep -v grep || echo "No uvicorn process found"
