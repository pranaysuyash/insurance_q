# Modern Stack Overview & Upgrade Tracker (2024)

> **Historical snapshot.** This 2024 tracker is retained for provenance. The
> active architecture is documented in
> [`docs/architecture/coverwise_canonical_architecture.md`](../architecture/coverwise_canonical_architecture.md):
> managed Supabase Auth/Postgres/pgvector/FTS/private Storage with one FastAPI
> pipeline. Do not use the Firebase/Qdrant/Redis recommendations below for new
> production work.

This document serves as the single source of truth for the Insurance Policy Parser & QA App's technical stack, upgrade priorities, and links to detailed documentation for each major component.

## Key Libraries & Models

| Feature                | Library/Model (Latest)                                  | Open Source? |
|------------------------|--------------------------------------------------------|--------------|
| PDF Parsing            | pdfplumber, PyPDF2, pypdf                              | Yes          |
| OCR                    | pytesseract, easyocr, TrOCR, doctr, Google Vision      | Yes/Cloud    |
| Table Extraction       | camelot-py, tabula-py, layoutparser, donut, table-transformer | Yes    |
| NER/Extraction         | spaCy, transformers (custom NER)                       | Yes          |
| Embeddings             | sentence-transformers, Instructor-XL, bge-base-en-v1.5, OpenAI | Yes/Cloud |
| Vector DB              | faiss, qdrant, pinecone, weaviate                      | Yes/Cloud    |
| RAG Pipeline           | langchain, llama-index                                 | Yes          |
| LLMs                   | OpenAI GPT-4o, Llama-3, Mistral, Gemma, vllm, TGI      | Yes/Cloud    |
| Reranking              | cross-encoder/ms-marco-MiniLM-L-6-v2                   | Yes          |
| Backend API            | FastAPI                                                | Yes          |
| Task Queue             | Celery + Redis                                         | Yes          |
| Frontend               | React, Streamlit                                       | Yes          |

## Upgrade Priorities & Links

- **Embeddings:** Add bge-base-en-v1.5, Instructor-XL ([RAG doc](ai_and_nlp/rag_implementation.md))
- **RAG Orchestration:** Standardize on langchain/llama-index ([RAG doc](ai_and_nlp/rag_implementation.md))
- **LLM Serving:** Add vllm, TGI, quantized models ([RAG doc](ai_and_nlp/rag_implementation.md))
- **Table Extraction:** Add donut, table-transformer ([OCR doc](implementation/extraction/ocr_implementation.md))
- **Vector DB:** Add Qdrant/Weaviate hybrid search, schema versioning ([RAG doc](ai_and_nlp/rag_implementation.md), [Architecture doc](system_architecture/comprehensive_architecture.md))
- **OCR:** Add TrOCR, doctr ([OCR doc](implementation/extraction/ocr_implementation.md))
- **Batch Processing:** Add ray/joblib ([OCR doc](implementation/extraction/ocr_implementation.md), [RAG doc](ai_and_nlp/rag_implementation.md))
- **Model Monitoring:** Add latency/error monitoring ([Architecture doc](system_architecture/comprehensive_architecture.md))
- **How-to Guides:** Add guides for switching models, vector DBs, OCR engines ([RAG doc](ai_and_nlp/rag_implementation.md), [OCR doc](implementation/extraction/ocr_implementation.md))
- **Changelog:** Add changelog section to each doc ([see template below])

## Changelog Template

```
# Changelog

- YYYY-MM-DD: [Short description of change, e.g., "Added TrOCR support for OCR."]
- YYYY-MM-DD: [Short description of change, e.g., "Switched RAG pipeline to langchain."]
```

## See Also
- [RAG Implementation](ai_and_nlp/rag_implementation.md)
- [OCR Implementation](implementation/extraction/ocr_implementation.md)
- [Comprehensive Architecture](system_architecture/comprehensive_architecture.md)

This file should be updated whenever a major stack or architecture change is made.

## Mobile App
- The primary client is a Flutter mobile app (Android/iOS), integrating with Firebase Auth and the backend API.
- See [Mobile App Architecture](../../user_experience/mobile_app_architecture.md) for details on mobile flows, packages, and integration.

# Changelog

- 2024-06-XX: Added mobile-first Flutter app architecture and documentation.
- 2024-06-XX: Decision: Flutter chosen as the primary mobile framework for cross-platform support and Firebase integration.
