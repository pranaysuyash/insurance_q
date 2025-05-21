import asyncio
import httpx

async def test_endpoints():
    endpoints = [
        "http://localhost:8080/health",  # Frontend
        "http://localhost:8001/health",  # OCR Service
        "http://localhost:8000/health",  # RAG Service
    ]
    
    async with httpx.AsyncClient() as client:
        for endpoint in endpoints:
            try:
                response = await client.get(endpoint)
                print(f"✅ {endpoint}: {response.status_code}")
                print(f"   Response: {response.json()}")
            except Exception as e:
                print(f"❌ {endpoint}: Error - {str(e)}")
        
        # Test if frontend can communicate with OCR service
        try:
            frontend_ocr_health = await client.get("http://localhost:8080/test_ocr_connection")
            print(f"\nFrontend -> OCR Connection Test: {frontend_ocr_health.status_code}")
            print(f"Response: {frontend_ocr_health.json() if frontend_ocr_health.status_code == 200 else 'N/A'}")
        except Exception as e:
            print(f"\nFrontend -> OCR Connection Test: Failed - {str(e)}")
        
        # Test if frontend can communicate with RAG service
        try:
            frontend_rag_health = await client.get("http://localhost:8080/test_rag_connection")
            print(f"\nFrontend -> RAG Connection Test: {frontend_rag_health.status_code}")
            print(f"Response: {frontend_rag_health.json() if frontend_rag_health.status_code == 200 else 'N/A'}")
        except Exception as e:
            print(f"\nFrontend -> RAG Connection Test: Failed - {str(e)}")

if __name__ == "__main__":
    asyncio.run(test_endpoints()) 