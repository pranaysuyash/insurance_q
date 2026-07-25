#!/usr/bin/env python3
"""
Script to re-ingest all existing documents into the RAG system.
This will process all documents in the storage/documents directory.
"""

import os
import requests
from pathlib import Path

# Configuration
API_BASE_URL = "https://nrmmvtpyaf.ap-south-1.awsapprunner.com"
DOCUMENTS_DIR = "storage/documents"


def process_document_via_api(file_path):
    """Process a document by sending it to the API for ingestion"""
    try:
        # First, let's trigger the test processing to see if it works
        response = requests.post(
            f"{API_BASE_URL}/debug/test-processing",
            headers={"accept": "application/json", "Content-Type": "application/json"},
        )

        if response.status_code == 200:
            result = response.json()
            print(f"✅ Test processing successful: {result.get('status')}")
            return True
        else:
            print(
                f"❌ Test processing failed: {response.status_code} - {response.text}"
            )
            return False

    except Exception as e:
        print(f"❌ Error processing {file_path}: {str(e)}")
        return False


def run_local_ingestion():
    """Run local ingestion using Python directly"""
    try:
        print("🔧 Attempting local ingestion...")

        # Import the RAG pipeline locally
        import sys

        sys.path.append(".")

        from src.rag.pipeline import RAGPipeline
        from src.services.document_processing_service import DocumentProcessingService

        # Initialize services
        rag_pipeline = RAGPipeline()
        doc_service = DocumentProcessingService(rag_pipeline=rag_pipeline)

        print("✅ Services initialized locally")

        # Process each document
        document_files = list(Path(DOCUMENTS_DIR).glob("*.txt"))
        successful = 0

        for file_path in document_files:
            try:
                print(f"📄 Processing: {file_path.name}")

                # Read file content
                with open(file_path, "rb") as f:
                    file_content = f.read()

                # Process through the service
                import asyncio

                result = asyncio.run(
                    doc_service.process_document_full(
                        file_content=file_content,
                        filename=file_path.name,
                        processing_mode="full",
                    )
                )

                if result.get("status") == "completed":
                    print(f"✅ Successfully processed: {file_path.name}")
                    successful += 1
                else:
                    print(f"❌ Failed to process {file_path.name}: {result}")

            except Exception as e:
                print(f"❌ Error processing {file_path.name}: {str(e)}")

        print(f"\n🎯 Local ingestion complete! Processed {successful} documents")
        return successful > 0

    except Exception as e:
        print(f"❌ Local ingestion failed: {str(e)}")
        return False


def test_query():
    """Test a query after re-ingestion"""
    try:
        print("\n🔍 Testing query...")
        response = requests.post(
            f"{API_BASE_URL}/query",
            headers={"accept": "application/json", "Content-Type": "application/json"},
            json={"query": "What is covered under health insurance?"},
        )

        if response.status_code == 200:
            result = response.json()
            print("🔍 Test query result:")
            print(f"Answer: {result.get('answer', 'No answer')}")
            print(f"Sources: {len(result.get('sources', []))} sources found")
            if result.get("sources"):
                print(
                    "First source preview:",
                    result["sources"][0][:100] + "..."
                    if len(result["sources"][0]) > 100
                    else result["sources"][0],
                )
        else:
            print(f"❌ Test query failed: {response.status_code}")

    except Exception as e:
        print(f"❌ Error testing query: {str(e)}")


def main():
    """Main function to re-ingest all documents"""
    print("🚀 Starting document re-ingestion process...")

    # Check if documents directory exists
    if not os.path.exists(DOCUMENTS_DIR):
        print(f"❌ Documents directory not found: {DOCUMENTS_DIR}")
        return

    # Get all text files in the documents directory
    document_files = list(Path(DOCUMENTS_DIR).glob("*.txt"))

    if not document_files:
        print(f"❌ No .txt documents found in {DOCUMENTS_DIR}")
        return

    print(f"📁 Found {len(document_files)} documents to process")

    # Try local ingestion first
    if run_local_ingestion():
        test_query()
    else:
        print("❌ Local ingestion failed. Please check the logs.")


if __name__ == "__main__":
    main()
