"""
policy_rag_hybrid_prototype.py   –   ═══ ARCHIVED PROTOTYPE ═══

Original location: src/policy_rag_hybrid.py
Archived:          2026-07-24
Reason:            Early Streamlit-based health-insurance QA prototype.
                   The product evolved to a mobile-first architecture
                   (Flutter app + FastAPI backend + Supabase). This
                   Streamlit skeleton was never completed into a
                   runnable application and is retained only as
                   historical reference.

Canonical implementation:
  - Backend:  src/rag/pipeline.py (RAG query pipeline)
              src/services/ (extraction, evidence, processing)
  - Mobile:   mobile/lib/screens/qa_screen.dart
              mobile/lib/screens/documents_screen.dart

Legacy docstring (original):
    policy_rag_hybrid.py   –   Health-insurance QA (generic, GPT-4-class)

    Run:
        streamlit run policy_rag_hybrid.py

    Flow:
        • Upload one or more policy PDFs.
        • Ask a free-form question, e.g. "since when am I with Niva Bupa"
"""



