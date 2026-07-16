# CoverWise Documentation

This is the comprehensive documentation for CoverWise, the insurance companion that reads policy documents,
surfaces the details that matter, and answers grounded questions in plain language. The documentation is
organized in a logical directory structure to improve navigation and accessibility.

## Current source of truth

For the solo launch, read [`docs/planning/coverwise_long_term_platform_decision_2026-07-12.md`](planning/coverwise_long_term_platform_decision_2026-07-12.md) first.
It is the canonical platform decision: one Cloud Run FastAPI service, one Supabase project,
Supabase Postgres with `pgvector`, and Supabase Storage. Older AWS, Railway, and Firestore
proposals remain preserved and explicitly marked historical or superseded; do not use them as
implementation instructions for new work.

For the commercial and responsible-data direction, read [`docs/planning/coverwise_monetization_ads_responsible_data_research_2026-07-16.md`](planning/coverwise_monetization_ads_responsible_data_research_2026-07-16.md). It records the subscription-first monetization thesis, rejection of behavioral ads in trusted workflows, regulated-distribution boundary, and opt-in model-contribution architecture. The corresponding idea and research branches live in [`docs/review/exploration_map.md`](review/exploration_map.md).

For account ownership and authentication, read [`docs/planning/coverwise_auth_architecture_2026-07-16.md`](planning/coverwise_auth_architecture_2026-07-16.md). It documents the Supabase Auth decision, anonymous-session compatibility, owner transfer, configuration contract, and production verification gate.

The current long-term platform baseline is [`docs/planning/coverwise_supabase_canonical_plan_2026-07-16.md`](planning/coverwise_supabase_canonical_plan_2026-07-16.md). It is the source of truth for Postgres/pgvector retrieval, policy data, provenance, future training readiness, and production cutover planning.

The corresponding implementation audit is [`docs/review/coverwise_supabase_gap_register_2026-07-16.md`](review/coverwise_supabase_gap_register_2026-07-16.md). It lists the remaining P0/P1/P2 gaps and their closure criteria.

## Key Technical Documents

- **OCR Implementation**: Detailed explanation of the OCR and document layout extraction process using Hugging Face APIs. Found at `docs/technical/implementation/extraction/ocr_implementation.md`.
- **RAG Implementation**: In-depth look at the Retrieval-Augmented Generation pipeline, including the embedding fallback mechanism between OpenAI and Hugging Face. Found at `docs/technical/ai_and_nlp/rag_implementation.md`.

## Directory Structure

```
docs/
├── technical/                   # Technical implementation details
│   ├── ai_and_nlp/              # AI models and NLP functionality
│   ├── architecture/            # Component-specific architecture
│   ├── data_storage/            # Data storage and management
│   ├── system_architecture/     # System architecture design (contains comprehensive_architecture.md)
│   └── implementation/          # Implementation guidelines and specifics
│       └── extraction/          # OCR and other extraction specific docs
├── user_experience/             # User-facing features and experience
│   ├── user_interface/          # User interface design and considerations
│   └── user_flows.md            # User journey flows and interactions (file)
├── planning/                    # Project planning and management
│   ├── product/                 # Product-specific planning, roadmaps, and specifications
│   └── roadmap/                 # Overall project roadmap documents
└── reference/                   # Reference documentation
    ├── api_documentation/       # API references (contains api_specification.md)
    └── insurance_terminology.md # Glossary of insurance terms (file)
```

## Project Overview

CoverWise is designed to help people understand the policy they already own. The app lets users upload
their insurance policy documents, extract key information automatically, and ask free-form questions
about coverage, benefits, exclusions, and claim readiness.

### Key Features

1. **Document Upload & Management**
   - Support for PDF insurance policy documents
   - Document organization and management
   - Version tracking for policy updates

2. **Intelligent Policy Parsing**
   - Automated extraction of key policy details
   - Recognition of policy structure, sections, and components
   - Table and structured data extraction
   - OCR capability for scanned documents

3. **Policy Information Dashboard**
   - Visual summary of coverage details
   - Key date tracking (renewals, effective dates)
   - Premium payment schedules
   - Beneficiary information

4. **Natural Language QA System**
   - Ask free-form questions about policy coverage
   - Get accurate answers with references to policy sections
   - Multi-stage retrieval and answer verification
   - Support for complex queries about conditions, limitations, etc.

5. **Comparison Tools**
   - Side-by-side policy comparison
   - Coverage gap analysis
   - Premium and benefit comparisons

6. **Alerts & Notifications**
   - Renewal reminders
   - Payment due notifications
   - Coverage change alerts
   - Policy update notifications

## Technology Stack

### Frontend
- Backend-served HTML/CSS/JS (`src/frontend/`) for web interface.
- Flutter mobile application (`mobile/`) for Android and iOS.

### Backend
- Python-based server components
- FastAPI for API development (`src/api/`, `src/frontend/app.py`)
- Redis for caching and task queuing (if Celery or similar is used, though not explicitly detailed here)

### AI/ML Components
- Custom RAG (Retrieval Augmented Generation) pipeline (`src/rag/pipeline.py`)
- Document embeddings with state-of-the-art models (OpenAI, Hugging Face)
- LLM integration (OpenAI) for question answering
- OCR capabilities for image-based documents (e.g., using Hugging Face models via `src/ocr/pipeline.py`)
- Table extraction algorithms (details in OCR implementation)

### Data Storage
- Vector database (Qdrant) for semantic search
- Document store for policy files (implicitly managed by the application, specific store like MinIO not detailed here)
- Relational database for user and metadata (not explicitly detailed, could be part of FastAPI backend or Firebase)

## Documentation Sections

See the specific documentation sections for detailed information:

- [Comprehensive System Architecture](technical/system_architecture/comprehensive_architecture.md) - Complete technical details
- [OCR Implementation Details](technical/implementation/extraction/ocr_implementation.md)
- [RAG Implementation Details](technical/ai_and_nlp/rag_implementation.md)
- [User Guide](user_guide.md) - Guide for end users
- [Developer Guide](developer_guide.md) - Information for developers
- [API Specification](reference/api_documentation/api_specification.md) - Details about the API
- [Mobile App Architecture](user_experience/mobile_app_architecture.md) - Flutter app details
- [Product Requirements Document (PRD)](planning/prd_insurance_policy_app.md) - Main PRD
- [Functional Requirements](planning/roadmap/functional_requirements.md) - Detailed functional requirements
- [Project Roadmap](planning/roadmap/unified_project_roadmap.md) - Development timeline and milestones
