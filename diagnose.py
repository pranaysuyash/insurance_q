#!/usr/bin/env python3
"""
Quick diagnostic script to check if all imports work correctly
"""

import importlib
import sys
from pathlib import Path

# Add the project root to Python path
sys.path.insert(0, str(Path(__file__).resolve().parent))

print("🔍 Diagnosing Enhanced Insurance RAG App imports...")
print("=" * 50)

# Test 1: Basic imports
try:
    importlib.import_module("fastapi")
    print("✅ FastAPI import: OK")
except Exception as e:
    print(f"❌ FastAPI import failed: {e}")

# Test 2: RAG Pipeline
try:
    importlib.import_module("src.rag.pipeline")
    print("✅ RAG Pipeline import: OK")
except Exception as e:
    print(f"❌ RAG Pipeline import failed: {e}")

# Test 3: Document Processing Service
try:
    importlib.import_module("src.services.document_processing_service")
    print("✅ Document Processing Service import: OK")
except Exception as e:
    print(f"❌ Document Processing Service import failed: {e}")

# Test 4: OCR Components
try:
    importlib.import_module("src.ocr.pdf_processor")
    print("✅ PDF Processor import: OK")
except Exception as e:
    print(f"❌ PDF Processor import failed: {e}")

try:
    importlib.import_module("src.ocr.image_processor")
    print("✅ Image Processor import: OK")
except Exception as e:
    print(f"❌ Image Processor import failed: {e}")

# Test 5: Enhanced Document API
try:
    importlib.import_module("src.api.document")
    print("✅ Enhanced Document API import: OK")
except Exception as e:
    print(f"❌ Enhanced Document API import failed: {e}")

# Test 6: Main app import
try:
    app = importlib.import_module("src.app.main").app
    print("✅ Enhanced Main App import: OK")
    print(f"📋 App title: {app.title}")
    print(f"📋 App version: {app.version}")

    # Check if enhanced endpoints are registered
    routes = [
        path
        for route in app.routes
        if isinstance(path := getattr(route, "path", None), str)
    ]
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
