#!/usr/bin/env python3
"""
Quick diagnostic script to check if all imports work correctly
"""
import sys
import os

# Add the project root to Python path
sys.path.insert(0, '/Users/pranay/Projects/medpiper/insurance_app')

print("🔍 Diagnosing Enhanced Insurance RAG App imports...")
print("=" * 50)

# Test 1: Basic imports
try:
    from fastapi import FastAPI
    print("✅ FastAPI import: OK")
except Exception as e:
    print(f"❌ FastAPI import failed: {e}")

# Test 2: RAG Pipeline
try:
    from src.rag.pipeline import RAGPipeline
    print("✅ RAG Pipeline import: OK")
except Exception as e:
    print(f"❌ RAG Pipeline import failed: {e}")

# Test 3: Document Processing Service
try:
    from src.services.document_processing_service import DocumentProcessingService
    print("✅ Document Processing Service import: OK")
except Exception as e:
    print(f"❌ Document Processing Service import failed: {e}")

# Test 4: OCR Components
try:
    from src.ocr.pdf_processor import PDFProcessor
    print("✅ PDF Processor import: OK")
except Exception as e:
    print(f"❌ PDF Processor import failed: {e}")

try:
    from src.ocr.image_processor import ImageProcessor
    print("✅ Image Processor import: OK")
except Exception as e:
    print(f"❌ Image Processor import failed: {e}")

# Test 5: Enhanced Document API
try:
    from src.api.document import router as document_router
    print("✅ Enhanced Document API import: OK")
except Exception as e:
    print(f"❌ Enhanced Document API import failed: {e}")

# Test 6: Main app import
try:
    from src.app.main import app
    print("✅ Enhanced Main App import: OK")
    print(f"📋 App title: {app.title}")
    print(f"📋 App version: {app.version}")
    
    # Check if enhanced endpoints are registered
    routes = [route.path for route in app.routes]
    enhanced_endpoints = ["/debug/services", "/processing/status", "/query"]
    
    print("\n🔍 Checking enhanced endpoints:")
    for endpoint in enhanced_endpoints:
        if endpoint in routes:
            print(f"✅ {endpoint}: Registered")
        else:
            print(f"❌ {endpoint}: Missing")
    
except Exception as e:
    print(f"❌ Enhanced Main App import failed: {e}")
    import traceback
    traceback.print_exc()

print("\n" + "=" * 50)
print("🔍 Diagnosis complete!")
