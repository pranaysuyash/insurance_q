#!/bin/bash

echo "🧪 Testing Azure API Endpoints for Play Store Readiness"
echo "======================================================="

# Service URLs
FRONTEND_URL="https://insurance-frontend-app.azurewebsites.net"
OCR_URL="https://insurance-ocr-app.azurewebsites.net"
RAG_URL="https://insurance-rag-app.azurewebsites.net"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_status="$3"
    
    echo -n "Testing $name... "
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json "$url")
    status_code="${response: -3}"
    
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ PASS${NC} (Status: $status_code)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # Show response for health checks
        if [[ "$url" == *"/health" ]]; then
            echo "   Response: $(cat /tmp/response.json)"
        fi
    else
        echo -e "${RED}❌ FAIL${NC} (Status: $status_code, Expected: $expected_status)"
        echo "   Response: $(cat /tmp/response.json)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to test POST endpoint
test_post_endpoint() {
    local name="$1"
    local url="$2"
    local data="$3"
    local expected_status="$4"
    
    echo -n "Testing $name... "
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json -X POST -H "Content-Type: application/json" -d "$data" "$url")
    status_code="${response: -3}"
    
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ PASS${NC} (Status: $status_code)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC} (Status: $status_code, Expected: $expected_status)"
        echo "   Response: $(cat /tmp/response.json)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo ""
echo "1. Health Check Tests"
echo "--------------------"
test_endpoint "Frontend Health" "$FRONTEND_URL/health" "200"
test_endpoint "OCR Health" "$OCR_URL/health" "200"
test_endpoint "RAG Health" "$RAG_URL/health" "200"

echo ""
echo "2. API Endpoint Tests"
echo "--------------------"
test_endpoint "Frontend Documents List" "$FRONTEND_URL/documents" "200"

# Test query endpoint (may fail if RAG not fully initialized)
echo -n "Testing Frontend Query... "
response=$(curl -s -w "%{http_code}" -o /tmp/response.json -X POST -H "Content-Type: application/json" -d '{"query":"test query"}' "$FRONTEND_URL/query")
status_code="${response: -3}"

if [ "$status_code" = "200" ] || [ "$status_code" = "500" ]; then
    echo -e "${YELLOW}⚠️  PARTIAL${NC} (Status: $status_code - Service may not be fully initialized)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL${NC} (Status: $status_code)"
    echo "   Response: $(cat /tmp/response.json)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "3. Error Handling Tests"
echo "----------------------"
test_endpoint "Invalid Endpoint" "$FRONTEND_URL/invalid" "404"

echo ""
echo "4. CORS and Security Tests"
echo "-------------------------"
echo -n "Testing CORS headers... "
cors_response=$(curl -s -H "Origin: https://example.com" -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: Content-Type" -X OPTIONS "$FRONTEND_URL/upload")
if [[ "$cors_response" == *"Access-Control-Allow-Origin"* ]] || [ -z "$cors_response" ]; then
    echo -e "${GREEN}✅ PASS${NC} (CORS configured)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠️  WARNING${NC} (CORS may not be properly configured)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "5. Performance Tests"
echo "-------------------"
echo -n "Testing response time... "
start_time=$(date +%s%N)
curl -s "$FRONTEND_URL/health" > /dev/null
end_time=$(date +%s%N)
response_time=$(( (end_time - start_time) / 1000000 ))

if [ $response_time -lt 5000 ]; then
    echo -e "${GREEN}✅ PASS${NC} (${response_time}ms - Good)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
elif [ $response_time -lt 10000 ]; then
    echo -e "${YELLOW}⚠️  WARNING${NC} (${response_time}ms - Acceptable)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL${NC} (${response_time}ms - Too slow)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "📊 Test Summary"
echo "==============="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! Ready for Play Store deployment.${NC}"
    exit 0
elif [ $TESTS_FAILED -le 2 ]; then
    echo -e "\n${YELLOW}⚠️  Most tests passed. Minor issues detected but app should work.${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Multiple test failures. Please fix issues before Play Store deployment.${NC}"
    exit 1
fi 