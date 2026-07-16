# System Exploration Map

## Permanent product boundary (owner decision, 2026-07-16)

CoverWise is a solo, non-regulated personal-information product. It helps users understand and organize policies they already have. It will never sell, solicit, procure, rank, recommend, or renew insurance; represent claims; earn commissions; sell leads; or become insurer/broker infrastructure.

```text
IN SCOPE
  user-owned policy -> extract -> cite -> explain -> organize -> remind
  user-entered health -> store -> chart -> remind -> export

OUT OF SCOPE
  recommend -> rank -> quote -> sell -> paid referral -> renew
  diagnose -> predict disease -> prescribe -> triage -> clinical risk score
  share sensitive signals with insurer/employer/advertiser/data buyer
```

### Existing surfaces requiring alignment

| Surface | Conflict | Direction |
|---|---|---|
| `mobile/lib/screens/coverage_gap_screen.dart` | Recommendations imply needed coverage | Reduce to factual "not found in uploaded documents" or remove |
| `mobile/lib/screens/what_if_calculator_screen.dart` | Premium estimates imply pricing guidance | Remove from product surface |
| `mobile/lib/screens/renewal_calendar_screen.dart` | "Start renewal" resembles an action funnel | Use neutral reminder/contact language |
| `mobile/lib/services/preventive_health_service.dart` | Treatment-planning language becomes medical guidance | Limit to policy-stated benefit reminders and clinician-directed actions |
| `mobile/lib/screens/onboarding_screen.dart` | "Coverage gaps and claim guidance" overstates the role | Reframe as policy details, dates, contacts, and personal records |
| Paid expert/claim services | Advice/representation ambiguity | Rejected |
| Broker/insurer B2B and commission branches | Conflicts with solo consumer neutrality | Rejected |

Health tracking remains exploration, not an approved broad feature. The preferred lane is optional, local-first records, neutral charts, reminders, and export. Diagnosis, treatment, prediction, medical-device claims, insurer use, advertising use, and default training use are prohibited.

### Approved comparative judgment lane

The product may make evidence-based judgments about policies the user already owns. This is not the same as giving an overall insurance recommendation.

Allowed: "Policy B is ₹4,000 cheaper," "Policy A has the shorter listed waiting period," "Policy B lists an additional exclusion," and "we could not verify equivalence because the deductible is missing."

Not allowed: "Policy B is better for you," "switch to Policy B," "Policy A is overpriced," "this is the best plan," or "you are under-insured."

The comparison pipeline must normalize price frequency, taxes, and riders, calculate percentages with an explicit denominator, cite source clauses, expose missing fields, and render only dimension-specific conclusions.

## Exploration update: monetization, ads, and responsible data (2026-07-16)

**Canonical research:** [`docs/planning/coverwise_monetization_ads_responsible_data_research_2026-07-16.md`](../planning/coverwise_monetization_ads_responsible_data_research_2026-07-16.md)

### Strategic branch map

```text
CoverWise: trusted policy intelligence
|
+-- Consumer revenue
|   +-- Free: one useful policy-understanding outcome
|   +-- Plus: household policies, reminders, comparison, higher Q&A
|   +-- Family: sharing, emergency access, annual review
|   `-- Fixed-fee review and claim-packet services
|
+-- Platform revenue
|   +-- Regulated broker/insurer workspace
|   +-- Employer-benefits policy intelligence
|   `-- Tenant-isolated extraction and Q&A API
|
+-- Regulated distribution (later)
|   +-- Technology partnership with regulated entity
|   `-- Appropriate registration after demand proof
|
+-- Advertising
|   +-- Behavioral/ad-network monetization: rejected in core product
|   `-- Fixed contextual sponsor: public education only, if ever
|
`-- Model improvement
    +-- Public wordings and expert cases
    +-- Controlled synthetic documents
    +-- Opt-in corrected structured fields
    `-- Raw redacted samples: gated future research, never default
```

### Opinionated direction

- **Monetize the ongoing job, not sensitive data.** Recurring value is household management, renewal readiness, sourced Q&A, comparison, and claim preparation.
- **Do not become an ad-supported policy viewer.** Ad SDKs create disproportionate privacy, disclosure, trust, and incident surface.
- **No commission path exists.** CoverWise must work for policies bought anywhere and will not participate in distribution.
- **Separate operational and learning data.** Upload permission covers the requested service, not shared-model training.
- **Earn the right to request contributions.** Begin with previewable field corrections. Consider redacted samples only if benchmarks prove material need.

### New architecture nodes

| Node | Purpose | Current state | Gate |
|---|---|---|---|
| Entitlements service | Canonical plan and usage decisions | Missing | Before paywall |
| Billing adapter | Provider-neutral subscription/reconciliation | Missing | Sandbox and idempotency |
| Commercial disclosure registry | Partner role, compensation, approval | Missing | Before sponsor/referral |
| Purpose/consent ledger | Notice, consent, withdrawal, propagation | Partial UI consent | Before contribution |
| Dataset registry | Provenance, allowed use, expiry, lineage | Missing | Before shared training |
| Contribution quarantine | Isolate opted-in artifacts | Missing | Before customer corpus |
| Privacy release gate | Detection, transformation, review, risk | Missing | Before research release |
| Cost attribution | OCR/LLM/storage cost by safe bucket | Partial LLM tracking | Before pricing |

### Current gaps surfaced by the exploration

- Analytics safety is caller-enforced rather than schema-enforced: the backend currently accepts arbitrary event properties.
- Full questions are used in local Hive feedback keys even though the transmitted feedback event contains only sentiment.
- Processing consent is not a reusable purpose/consent ledger.
- Retention and production deletion behavior remain incomplete in the privacy draft.
- No entitlements, billing, commercial disclosure, dataset registry, quarantine, or privacy-release system exists yet.

### Architecture review note (2026-07-16)

Reference: [`docs/review/coverwise_architecture_review_2026-07-16.md`](coverwise_architecture_review_2026-07-16.md)

The current repo shape is strongest when the canonical path stays singular:

- one FastAPI backend as the product runtime;
- one storage/auth/data boundary aligned to the newer platform decision docs;
- one consumer product boundary with the non-regulated scope above;
- compatibility surfaces only when they have a documented retirement trigger.

The review found the most important follow-through areas are retiring legacy service paths, collapsing frontend compatibility fallbacks once contracts stabilize, and neutralizing mobile surfaces that still imply recommendation or renewal behavior.

### Research queue

1. Interview 12-20 households after a real policy summary; test Plus value and annual willingness to pay.
2. Build bottom-up unit economics from actual OCR, LLM, storage, support, payment, and tax costs.
3. Review app copy and behavior to remove solicitation, advice, premium prediction, and transactional renewal implications.
4. Compare Indian subscription payment providers and app-store billing rules against the final distribution plan.
5. Interview consumer users about neutral policy organization and optional private health-record needs.
6. Benchmark public+synthetic+expert data against permissioned corrected fields before proposing raw contributions.
7. Design deletion propagation across object, metadata, vector, cache, analytics, quarantine, dataset, and model lineage.
8. Threat-model membership inference, memorization, poisoning, reviewer access, and experiment-tracker leakage.
9. Decide whether permanently banning raw customer documents from shared training should become a public trust promise.

### Explicitly parked

- Behavioral ad SDKs in the authenticated product.
- Leads inferred from uploaded contents.
- Training consent bundled into the privacy policy.
- Cross-customer benchmarks before minimum-cohort and privacy standards.
- Personalized pricing based on premium, claim urgency, health, or financial capacity.
- A second billing, consent, analytics, or training path outside the canonical backend.

## Architecture Overview

```
┌─────────────────────┐
│   Frontend Service   │────▶  Main API (consolidated)
│  src/frontend/app.py │      src/app/main.py
│                      │      ┌──────────────────────────┐
│  Jinja2 templates    │      │  /process-and-ingest     │
│                      │      │  /documents/upload       │
│                      │      │  /documents/query        │
│                      │      │  /query                  │
│                      │      │                          │
│                      │      │  DocumentProcessingService│
│                      │      │  ┌────────────────────┐   │
│                      │      │  │ OCR (PyMuPDF/     │   │
│                      │      │  │      doctr/Docling)│   │
│                      │      │  │ Classify (keyword │   │
│                      │      │  │           /LLM)   │   │
│                      │      │  │ Embed (OpenAI/    │   │
│                      │      │  │   Ollama/MLX/BGE) │   │
│                      │      │  │ Store (Qdrant)   │   │
│                      │      │  └────────────────────┘   │
│                      │      │                          │
│                      │      │  RAGPipeline              │
│                      │      │  ┌────────────────────┐   │
│                      │      │  │ LLM (OpenAI/      │   │
│                      │      │  │   Ollama/MLX)     │   │
│                      │      │  │ Embeddings        │   │
│                      │      │  │ Qdrant + Redis    │   │
│                      │      │  └────────────────────┘   │
│                      │      └──────────────────────────┘
└─────────────────────┘
```

## Architecture Decision: Consolidated Single Backend

### Problem
Two parallel code paths for document processing:
- **Standalone OCR service** (`src/ocr/service.py`) — separate FastAPI process with its own `OCRPipeline()`, Redis cache, httpx client. Frontend proxied to it.
- **Main app** (`src/app/main.py`) — in-process `DocumentProcessingService` with OCR + RAG + classification + anti-abuse + lead capture.

Two paths → duplicate model loading, HTTP latency, Redis sync complexity, code drift.

### Decision
**Consolidate to a single backend.** The pipeline (upload → OCR → classify → embed → store → query) is linear — no stage needs independent scaling. The OCR service's only real benefit was isolating the heavy torch/doctr model, which is a deployment detail, not an architectural need.

### What changed
1. **Added `/process-and-ingest`** to main app — synchronous endpoint matching the OCR service's response contract. Uses the same `DocumentProcessingService` internally.
2. **Updated frontend** — calls `/process-and-ingest` on the main app instead of the OCR service. No more `/cached_ocr_data` Redis round-trip.
3. **Deprecated `src/ocr/service.py`** — marked with `@deprecated` docstring, removal target next major release.

### Architecture (after)
```
Frontend (thin proxy)
  └─ /upload → Main App (in-process: OCR → classify → embed → store)
  └─ /query  → Main App (in-process: embed → search → LLM)
```

One process, one model load, one code path.

## Component Map

### Settings (src/config/settings.py)
- pydantic-settings `Settings` class
- Single `.env` source of truth
- Models: `gpt-5-nano`, `text-embedding-3-small`
- Ollama: `ollama_base_url`, `ollama_chat_model` (llama3.2), `ollama_embedding_model` (nomic-embed-text)

### LLM Client (src/llm/client.py)
- `AsyncOpenAI` wrapper with multi-client support (OpenAI + Ollama)
- `generate()` with retry + semaphore (5 concurrent)
- `generate_structured()` with `json_schema` response format
- `CostTracker` per-call token tracking
- Model fallback: `gpt-5-nano` → `gpt-4o-mini` → `llama3.2` (Ollama)
- `_adapt_response_format()` — auto-converts `json_schema` → `json_object` for unsupported models
- `_supports_json_schema()` — checks model capability set
- `_select_client()` — routes to Ollama client for local models

### OCR Layers

**Layer 1**: `src/ocr/pipeline.py` `OCRPipeline` (shared, single instance)
- Initializes doctr OCR predictor (db_resnet50 + crnn_vgg16_bn) — heavy ~500MB+ download
- `_process_pdf()` — PyMuPDF direct text extraction first, image fallback
- `_process_pdf_with_docling()` — optional Docling parser (opt-in via `DOCLING_ENABLED=true`)
- `_get_ocr_text_for_image()` — doctr OCR for images
- `_get_layout_elements_for_text()` — LLM structured extraction on page text
- `process_document()` — orchestration: PDF/image → text/OCR → LLM extraction

**Layer 2**: `src/ocr/pdf_processor.py` `PDFProcessor`
- Wraps `OCRPipeline` for PDF files
- Accepts shared pipeline instance (no longer creates its own)

**Layer 3**: `src/ocr/image_processor.py` `ImageProcessor`
- Wraps `OCRPipeline` for image files
- Accepts shared pipeline instance (no longer creates its own)

**Service**: `src/ocr/service.py` — **@deprecated**
- Standalone FastAPI service (separate process)
- Being replaced by `/process-and-ingest` on the main app
- Removal target: next major release

### Orchestrator (src/services/document_processing_service.py)
`DocumentProcessingService`
- Used by Main API and Document API
- `process_document_full()` — file storage → OCR extraction → RAG ingestion
- Uses `PDFProcessor` / `ImageProcessor` / text fallback for OCR
- `_split_text_into_blocks()` — structure-aware chunking (section headers, paragraph boundaries)
- `query_documents()` → delegates to `rag_pipeline.query_rag()`

### RAG Pipeline (src/rag/pipeline.py)
`RAGPipeline`
- Embedding fallback: `try OpenAI → try Ollama → try local sentence-transformers`
- Qdrant fallback: `try server → try in-memory`
- Redis cache: `try connect → disable if fails`, used for versioned query-response caching
- `ingest_document_data()` — async embedding + Qdrant upsert
- `query_rag()` — versioned cache lookup → embed query → Qdrant search + local FTS fallback → rerank → structured LLM answer with citations, confidence, and filter support
- `query_rag_structured()` — same + structured output
- Ollama embedding client (OpenAI-compatible, lazy init)

### Document Classifier (src/utils/document_classifier.py)
- Keyword/regex-based with LLM fallback
- 4 types: health, auto, home, life
- 25+ insurers with pattern matching
- Policy number + date regex extraction
- LLM classification via `generate_structured()` when keyword confidence < 0.3
- Used in background after OCR in `api/document.py`

### API Layer

| Route | Router | Auth | Purpose |
|---|---|---|---|
| `/health` | main | No | Health check |
| `/query` | main | No | Root query (mobile app) |
| `/processing/status` | main | No | Background job status |
| `/rag/stats` | main | No | LLM cost + embedding stats |
| `/documents` | main | No | Test documents list |
| `/debug/*` | main | No | Debug endpoints |
| `/users/*` | user | Firebase | User management |
| `/families/*` | family | Firebase | Family management |
| `/policies/*` | policy | Firebase | Policy management |
| `/documents/upload` | document | No (lead gen) | Upload + process |
| `/documents/query` | document | No (lead gen) | Query via RAG |
| `/documents/*` | document | Firebase | CRUD for auth users |
| `/documents/*/status` | document | No | Processing status |

## Fallback Chain Analysis

### 1. Embedding Fallback
```
OpenAI (text-embedding-3-small, 1536d)
  └─ on failure: Ollama (nomic-embed-text, 768d) — local, OpenAI-compatible API
       └─ on failure: local sentence-transformers (all-MiniLM-L6-v2, 384d)
            └─ on failure: exception propagates up
```
**Status**: ✅ 3-tier fallback. Qdrant collection auto-recreates on dimension change.

### 2. Qdrant Fallback
```
Try: QdrantClient(url= configured URL, api_key= configured key)
  └─ on failure: QdrantClient(":memory:")
       └─ on failure: exception propagates up
```
**Status**: ✅ Working, verified in tests

### 3. OCR Fallback (within OCRPipeline)
```
PDF: direct text extraction (PyMuPDF)
  └─ always: also generate page images
Text: use directly extracted text
  └─ if no text: doctr OCR on image
Plus: .txt/.md/.csv/.json/.xml/.html → direct text (new)
```
**Status**: ✅ Working, now includes text-based file support.

### 4. Document Processing OCR Fallback
```
PDF → PDFProcessor (wraps shared OCRPipeline)
Image → ImageProcessor (wraps shared OCRPipeline)
Other extension → read file as text (utf-8)
```
**Status**: ✅ Fixed — lazy initialization with single shared OCRPipeline instance (was creating 3 separate instances before)

### 5. LLM Fallback
```
gpt-5-nano with retry (3 attempts, exponential backoff)
  └─ on permanent error (quota/invalid_key): skip retry → try gpt-4o-mini
       └─ on failure: try llama3.2 (Ollama, local)
            └─ on failure: context-only fallback (raw top source)
```
**Status**: ✅ 3-tier fallback + context-only mode. Response format auto-adapted for unsupported models.

### 6. Classification Fallback
```
RAG query (query_rag) → keyword/regex classification
  └─ if confidence < 0.3: LLM classification via generate_structured()
       └─ on failure: default "Insurance Policy" / "Unknown"
```
**Status**: ✅ LLM fallback added. Uses `generate_structured` with Pydantic schema.

### 7. Redis Cache Fallback
```
Try: connect Redis → ping
  └─ on failure: disable caching
```
**Status**: ✅ Working (graceful degradation)

### 8. Anti-Abuse SQLite Fallback
```
check_document_hash_exists_db(db_path=ANTI_ABUSE_DB_PATH)
  └─ on ImportError: skip hash check (allow upload)
```
**Status**: ✅ DB path configurable via `ANTI_ABUSE_DB_PATH` env var (default: `insurance_app.db`). Tests can set to `:memory:` or temp path.

## Fixes Applied

| # | Fix | File | Impact |
|---|---|---|---|---|
| 1 | `rag_pipeline.query()` → `query_rag()` | `src/utils/document_classifier.py` | Prevents RuntimeError |
| 2 | Shared OCRPipeline via lazy init | `src/services/document_processing_service.py`, `src/ocr/pdf_processor.py`, `src/ocr/image_processor.py` | ~1.5GB RAM, fast startup |
| 3 | Local `sentence-transformers` fallback | `src/rag/pipeline.py` | Works offline, 384d |
| 4 | LLM model fallback chain (gpt-5-nano→gpt-4o-mini→Ollama) | `src/llm/client.py`, `src/rag/pipeline.py` | Survives quota exhaustion |
| 5 | Quota short-circuit in LLM client | `src/llm/client.py` | 429 doesn't retry 3× |
| 6 | Text file support in OCR pipeline | `src/ocr/pipeline.py` | `.txt`/`.md`/`.csv` etc |
| 7 | Date regex fixed in classifier | `src/utils/document_classifier.py` | "Coverage period from X to Y" |
| 8 | `_adapt_response_format()` for json_schema→json_object | `src/llm/client.py` | gpt-4o-mini works with structured output |
| 9 | Embedding fallback catches ALL errors (not just non-quota) | `src/rag/pipeline.py` | Local fallback works on quota exhaustion |
| 10 | Qdrant collection recreation on dim change | `src/rag/pipeline.py` | 1536d→768d→384d seamless |
| 11 | Context-only LLM fallback | `src/rag/pipeline.py` | Returns raw context when all LLMs fail |
| 12 | Structure-aware chunking (section headers) | `src/services/document_processing_service.py` | Preserves document structure |
| 13 | LLM classification fallback | `src/utils/document_classifier.py` | Uses `generate_structured` when keywords insufficient |
| 14 | Ollama local LLM + embeddings support | `src/llm/client.py`, `src/rag/pipeline.py`, `src/config/settings.py` | Fully local operation |
| 15 | Anti-abuse DB path configurable | `src/utils/anti_abuse.py` | `ANTI_ABUSE_DB_PATH` env var for tests |
| 16 | Phi-3-mini as alt LLM model | `src/llm/client.py`, `src/config/settings.py` | Better JSON extraction, zero risk |
| 17 | BGE-base-en-v1.5 configurable embedding | `src/rag/pipeline.py`, `src/config/settings.py` | +4.8 MTEB over MiniLM |
| 18 | Docling optional PDF parser | `src/ocr/pipeline.py`, `src/config/settings.py` | Deep layout analysis for insurance PDFs |
| 19 | Shared OCR pipeline (single instance) | `src/services/document_processing_service.py` | ~1GB RAM saved, 2→1 instances |
| 20 | Consolidated backend (deprecated OCR service) | `src/app/main.py`, `src/frontend/app.py`, `src/ocr/service.py` | One code path, no HTTP latency, no Redis sync |

## New Dependencies Installed
- `sentence-transformers` (all-MiniLM-L6-v2 cached locally)
- `python-doctr[torch]` (db_resnet50 + crnn_vgg16_bn cached locally)
- `torch` + `torchvision` (prerequisite for doctr)
- **Ollama** (external, not pip) — `ollama pull llama3.2 nomic-embed-text`

Both models cached in `~/.cache/doctr/models/` and HF cache. First-time startup downloads ~160MB for doctr models. Subsequent starts are instant.

## Local Model Options — Full Evaluation

### Decision Framework
Each option evaluated on: **Effort** (days to integrate), **Risk** (breakage probability), **Benefit** (accuracy/speed gain), **Dependency weight** (disk/RAM). Decisions are documented with rationale.

---

### 1. LLM Runtime: Ollama vs MLX vs llama.cpp vs ONNX

| Runtime | Install | Speed on M-series | Effort | Risk | Benefit | Decision |
|---|---|---|---|---|---|---|
| **Ollama** (current) | `brew install ollama` | Good | 0d (done) | None | Baseline | ✅ **Keep** |
| **MLX** | `pip install mlx-lm` | **Fastest** (+30-50%) | 2d | Medium — different API, error modes | Speed | ❌ Defer — app is async/batch, not latency-sensitive |
| **llama.cpp** | `brew install llama.cpp` | Good | 2d | Medium — different API | Portability | ❌ Defer — Ollama wraps this already |
| **ONNX Runtime** | `pip install onnxruntime-silicon` | Comparable to MLX | 3d | High — fewer models, less mature | Speed | ❌ Defer — not enough model selection |
| **HF Transformers** | `pip install transformers` | Slowest | 1d | Low | None | ❌ Too slow without quantization |

**Rationale**: Ollama is already integrated, provides OpenAI-compatible API, and is fast enough for document processing (which is async/batch, not real-time). MLX would be faster but the app doesn't need sub-second LLM latency. Revisit if we add real-time chat features.

---

### 2. LLM Model: llama3.2 vs Phi-3-mini vs Qwen2.5-3B vs alternatives

| Model | Size (Q4) | JSON Extraction | Chat | RAM | Available via Ollama | Decision |
|---|---|---|---|---|---|---|
| **llama3.2-3B** (current) | ~1.8GB | ★★★☆☆ | ★★★★☆ | 3GB+ | ✅ | ✅ **Keep as primary** |
| **Phi-3-mini-3.8B** | ~2.2GB | ★★★★☆ | ★★★★☆ | 4GB+ | ✅ (`phi3:mini`) | ✅ **Add as alt** — better JSON extraction, zero risk |
| **Qwen2.5-3B** | ~1.8GB | ★★★★☆ | ★★★★☆ | 3GB+ | ✅ | ✅ **Add as alt** — comparable to Phi-3 |
| **Qwen2.5-1.5B** | ~900MB | ★★★☆☆ | ★★★☆☆ | 2GB+ | ✅ | ❌ Defer — weaker than current |
| **Mistral-7B** | ~4.1GB | ★★★★★ | ★★★★★ | 6GB+ | ✅ | ❌ Defer — needs 8GB+ RAM, heavy |
| **Llama-3.1-8B** | ~4.5GB | ★★★★★ | ★★★★★ | 6GB+ | ✅ | ❌ Defer — needs 8GB+ RAM |

**Rationale**: Phi-3-mini is trained on synthetic data and excels at structured JSON output — exactly what this app needs for document extraction. Adding it as a configurable alt model (`ollama_alt_model`) costs nothing: just a model name change. Users `ollama pull phi3:mini` and set the env var.

**Implementation**: Added `ollama_alt_model: str = "phi3:mini"` to settings. Fallback chain: `gpt-5-nano` → `gpt-4o-mini` → `llama3.2` → `phi3:mini`. ✅ Done.

---

### 3. Embeddings: all-MiniLM-L6-v2 vs BGE-base vs GTE vs nomic-embed-text

| Model | Size | MTEB | Dims | Speed | Effort | Risk | Benefit | Decision |
|---|---|---|---|---|---|---|---|---|
| **all-MiniLM-L6-v2** (current) | 90MB | 58.8 | 384 | ★★★★★ | 0d | None | Baseline | ✅ **Keep as final fallback** |
| **BAAI/bge-base-en-v1.5** | 400MB | 63.6 | 768 | ★★★★☆ | 0.5d | Low — same sentence-transformers API | +4.8 MTEB | ✅ **Add as configurable** |
| **BAAI/bge-small-en-v1.5** | 130MB | 61.0 | 384 | ★★★★★ | 0.5d | Low | +2.2 MTEB | ❌ Defer — small gain over MiniLM |
| **Alibaba/gte-base-en-v1.5** | 400MB | 64.1 | 768 | ★★★★☆ | 0.5d | Low | +5.3 MTEB | ❌ Defer — marginal over BGE-base |
| **nomic-embed-text** (Ollama) | 275MB | 62.4 | 768 | ★★★★☆ | 0d (already in Ollama) | None | +3.6 MTEB | ✅ **Already available** via Ollama |
| **intfloat/e5-mistral-7b** | 4GB | 66.7 | 4096 | ★★☆☆☆ | 2d | Medium | +7.9 MTEB | ❌ Defer — too heavy for retrieval |

**Rationale**: BGE-base-en-v1.5 is the best upgrade — same sentence-transformers API (zero code change), meaningful accuracy gain, and the dimension change (384→768) is already handled by the Qdrant collection recreation code. Users just set `HF_EMBEDDING_MODEL=BAAI/bge-base-en-v1.5` in `.env`.

---

### 4. PDF Parser: PyMuPDF vs Docling vs Unstructured vs pdfplumber

| Tool | Install | Layout | Tables | Effort | Risk | Benefit | Decision |
|---|---|---|---|---|---|---|---|
| **PyMuPDF** (current) | `pip install pymupdf` | Basic text | ❌ Manual | 0d | None | Baseline | ✅ **Keep as fallback** |
| **Docling** (IBM) | `pip install docling` | ★★★★★ Deep | ✅ Built-in | 2d | Medium — heavy dep, edge cases | **Highest** | ✅ **Add as optional parser** |
| **Unstructured.io** | `pip install unstructured[pdf]` | ★★★★☆ | ✅ | 2d | Medium | High | ❌ Defer — Docling is better for insurance |
| **pdfplumber** | `pip install pdfplumber` | ★★★★☆ | ✅ | 0.5d | Low | Medium | ❌ Defer — lightweight but less capable than Docling |

**Rationale**: Insurance documents have complex layouts (tables, headers, nested sections). Docling is purpose-built for this. Heavy dependency (~1GB) but worth it for accuracy. Add as optional — PyMuPDF remains the fallback.

---

### 5. OCR: doctr vs PaddleOCR vs Tesseract vs Surya

| Tool | Install | Size | Speed | Accuracy | Effort | Risk | Decision |
|---|---|---|---|---|---|---|---|
| **doctr** (current) | `pip install python-doctr[torch]` | 500MB | ★★★☆☆ | ★★★★☆ | 0d | None | ✅ **Keep** |
| **PaddleOCR** | `pip install paddleocr` | 500MB | ★★★★☆ | ★★★★★ | 2d | Medium — paddlepaddle dep | ❌ Defer — Docling reduces OCR need |
| **Tesseract** | `brew install tesseract` | 50MB | ★★★★★ | ★★☆☆☆ | 0.5d | Low | ❌ Too inaccurate for insurance |
| **Surya OCR** | `pip install surya-ocr` | 2GB | ★★☆☆☆ | ★★★★★ | 3d | High | ❌ Too heavy, too slow |
| **Marker** | `pip install marker-pdf` | 2GB | ★★☆☆☆ | ★★★★★ | 3d | High | ❌ Too heavy, overlaps with Docling |

**Rationale**: Docling (PDF parser upgrade) will reduce OCR need significantly. PaddleOCR is the best upgrade if we still need OCR, but it's lower priority than Docling.

---

### 6. Vision/Layout Models: LayoutLMv3 vs Donut vs PaliGemma

| Model | Size | Approach | Effort | Risk | Decision |
|---|---|---|---|---|---|
| **LayoutLMv3** | 400MB | Text + layout + image | 3d | Medium | ❌ Defer — Docling covers layout needs |
| **Donut** | 1.2GB | OCR-free, end-to-end | 4d | High | ❌ Defer — heavy, needs fine-tuning |
| **PaliGemma** (3B) | 6GB | VLM | 5d | High | ❌ Defer — needs 16GB RAM |

**Rationale**: Vision models are overkill for this pipeline. Docling + LLM extraction covers the same ground with less complexity.

---

### 7. Quantization Format: MLX vs GGUF vs ONNX

| Format | Speed on M-series | Size Reduction | Effort | Decision |
|---|---|---|---|---|
| **GGUF Q4_K_M** (via Ollama) | ★★★★☆ | 75-80% | 0d (done) | ✅ **Keep** |
| **MLX 4-bit** | ★★★★★ | 75-80% | 2d | ❌ Defer — Ollama GGUF is fast enough |
| **ONNX INT8** | ★★★★☆ | 50-60% | 3d | ❌ Defer — fewer models |

**Rationale**: Ollama's GGUF quantization is already working and fast enough. MLX would be faster but not worth the integration cost for this app.

---

### Implementation Status

| # | Option | Status | Config | How to use |
|---|---|---|---|---|---|
| 1 | Ollama runtime | ✅ Integrated | `OLLAMA_BASE_URL` | `brew install ollama && ollama pull llama3.2` |
| 2 | Phi-3-mini LLM | ✅ Integrated | `OLLAMA_ALT_MODEL=phi3:mini` | `ollama pull phi3:mini` |
| 3 | BGE-base embeddings | ✅ Integrated | `HF_EMBEDDING_MODEL=BAAI/bge-base-en-v1.5` | Auto-downloads on first use |
| 4 | Docling PDF parser | ✅ Integrated (opt-in) | `DOCLING_ENABLED=true` | `pip install docling` |
| 5 | MLX runtime | ✅ Integrated (opt-in) | `MLX_ENABLED=true` | `pip install mlx-lm && mlx_lm.server --model ...` |
| 6 | PaddleOCR | ❌ Deferred | — | Revisit if Docling misses text |

### Recommended Pipeline for Mac

```
PDF Input
    │
    ▼
┌─────────────────────┐
│  Docling (IBM)      │  ← Optional, best for insurance docs
│  → Markdown + JSON  │     pip install docling
└─────────┬───────────┘
          │ (fallback)
          ▼
┌─────────────────────┐
│  PyMuPDF (current)  │  ← Always available, lightweight
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  BGE-base-en-v1.5   │  ← Configurable, better retrieval
│  (sentence-transformers)│  pip install sentence-transformers
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Ollama + Phi-3-mini│  ← Configurable, best JSON extraction
│  or llama3.2        │     brew install ollama
│  (structured output)│     ollama pull phi3:mini
└─────────────────────┘
```

**Total disk: ~3-4GB** for the full pipeline. Runs on any M-series Mac with 8GB+ RAM.

## Tests Added
`tests/test_fallbacks.py` — 41 tests covering all fallback chains and new features:
- Qdrant in-memory init
- Local embedding generation  
- Embedding fallback from OpenAI failure
- PDF direct text extraction
- Text file OCR support
- Image OCR fallback
- Health/Auto classification
- Date/policy number extraction
- Insurer detection
- Default fallback
- LLM quota short-circuit
- Response format adaptation (3 tests: kept for supported, converted for unsupported, kept when no json_schema)
- Settings defaults
- Ollama integration (4 tests: client routing, json_schema, fallback chain)
- MLX integration (3 tests: client routing, json_schema, disabled exclusion)
- Phi-3-mini alt model (2 tests: client routing, fallback chain)
- BGE-base embedding (2 tests: settings usage, dimensions dict)
- Docling PDF parser (2 tests: ImportError handling, PyMuPDF fallback)
- Anti-abuse DB path (3 tests: default, env var override, path passing)
- Structure-aware chunking (3 tests: section headers, max block size, paragraph fallback)
- Shared OCR pipeline (2 tests: single instance, shared between processors)
- LLM classification fallback (2 tests: low confidence trigger, LLM unavailable)

## Addendum — Local document intelligence evaluation (2026-07-12)

`docs/technical/local_document_intelligence_evaluation_2026-07-12.md` is the
current evidence-backed research record for Gemma, DeepSeek-OCR, OLM OCR,
PaddleOCR-VL, Unlimited-OCR, and the existing local stack. It corrects the
older assumption that generic VLM invocation is an interchangeable OCR path.

Current machine proof on the synthetic policy fixture:

- PyMuPDF remains the correct instantaneous fast path for embedded-text PDFs.
- Gemma 3 4B transcribed the simple rendered page in 19.027s; 12B did so in
  40.217s; Qwen2.5-VL 7B in 77.441s. None can replace PyMuPDF by default.
- DeepSeek-OCR produced no text through the generic Ollama image request;
  future work needs the model-native adapter rather than a fallback swap.
- Unlimited-OCR and olmOCR currently require GPU-oriented official inference
  paths, so are research-lane candidates, not App Runner / Apple Silicon launch
  dependencies.

The reusable, text-safe evaluator is
`tools/evaluate_local_document_models.py`; reports contain hashes, timing, and
expected-token checks by default. The next accepted model must meet the corpus
contract in the technical evaluation record before becoming part of the
canonical OCR pipeline.

## Addendum — source acceptance before model selection (2026-07-13)

Model quality cannot compensate for unsafe or unparseable source input. The
launch pipeline is therefore constrained to signature-verified PDF and image
formats with explicit byte/page/pixel budgets. Office-document extraction is a
separate exploration item, not an extension-list change: evaluate only
sandboxed parsers with malware-scanning posture, resource limits, schema-aware
extraction metrics, and policy corpus evidence before it can join the canonical
pipeline. See `src/utils/upload_validation.py` and the document-storage
contract for the active boundary.
