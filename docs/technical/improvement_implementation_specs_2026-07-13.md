# CoverWise Improvement Implementation Specs

**Date:** 2026-07-13
**Scope:** Engineering implementation specs for all 27 identified improvement items across RAG pipeline, OCR processing, mobile app, backend, testing, and product/marketing. Each spec includes: what changes, which files, how to implement, expected impact, and verification criteria.

---

## RAG Pipeline Improvements (Items 1-5)

### 1. RAG Fusion — Multi-Query Generation + RRF Merge

**What:** Generate 3 alternative phrasings of the user query via LLM, retrieve for each, merge all results with RRF.

**Files to change:**
- `src/rag/pipeline.py` → `query_rag()` method

**Implementation:**
```python
async def _generate_query_variants(self, user_query: str) -> List[str]:
    """Generate 3 alternative phrasings of the query."""
    if not self.llm:
        return [user_query]
    try:
        result = await self.llm.generate(
            messages=[
                {"role": "system", "content": "Generate 3 alternative phrasings of this insurance question. One per line. No numbering."},
                {"role": "user", "content": user_query},
            ],
            temperature=0.3,
            max_tokens=200,
        )
        variants = [v.strip() for v in result.strip().split('\n') if v.strip()]
        return [user_query] + variants[:3]
    except:
        return [user_query]
```

In `query_rag()`: generate variants, embed each, search for each, merge all dense results with RRF before reranking.

**Impact:** Broader coverage for ambiguous queries like "What is my premium?" (could be health or auto).
**Verification:** Query "What is my premium?" retrieves from both health and auto policy chunks.

### 2. Adaptive RAG — Query Classifier Routing

**What:** Classify query complexity and route to: no retrieval (simple), single-step (moderate), multi-step (complex).

**Files to change:**
- `src/rag/pipeline.py` → new `_classify_query()` method + routing in `query_rag()`

**Implementation:**
```python
def _classify_query(self, query: str) -> str:
    """Route query to appropriate retrieval path."""
    query_lower = query.lower().strip()
    
    # Exact lookup patterns — route to entity/structured retrieval
    if re.search(r'policy number|policy no|policy id', query_lower):
        return "exact_lookup"
    
    # Comparison/analysis — multi-step
    if any(w in query_lower for w in ['compare', 'versus', 'difference', 'gap', 'across all']):
        return "multi_step"
    
    # Summary — broad retrieval
    if any(w in query_lower for w in ['summar', 'overview', 'what does', 'what is']):
        return "broad"
    
    # Default — single-step semantic retrieval
    return "single_step"
```

Route `exact_lookup` to FTS-only search (faster, more precise for IDs). Route `multi_step` to multiple queries with document_id filters. Route `broad` to higher top_k.

**Impact:** Cost reduction (skip embedding for exact lookups), latency reduction.
**Verification:** "What is my policy number?" returns in <200ms (FTS only, no embedding).

### 3. Sentence Window Retrieval

**What:** Index at sentence level for precise matching, but return surrounding 3-5 sentences for generation context.

**Files to change:**
- `src/services/document_processing_service.py` → `_split_text_into_blocks()` — add sentence-level splitting
- `src/rag/pipeline.py` → `query_rag()` — retrieve sentence chunks, expand to window

**Implementation:**
```python
def _split_into_sentences(self, text: str) -> List[Dict]:
    """Split text into sentence-level chunks with position metadata."""
    sentences = re.split(r'(?<=[.!?])\s+', text)
    return [
        {"text": s.strip(), "id": str(uuid.uuid4()), "sentence_index": i}
        for i, s in enumerate(sentences) if s.strip()
    ]
```

At retrieval time: fetch top-k sentence chunks, then expand each to include ±2 sentences from the same document.

**Impact:** #1 precision in ARAGOG benchmark. Precise matching + rich context.
**Verification:** Query "maternity" returns the specific sentence about maternity coverage plus surrounding context.

### 4. Retrieval Evaluator — Quality Gate

**What:** Grade retrieved chunks for relevance before sending to LLM. If quality is too low, return "no relevant information" instead of hallucinating.

**Files to change:**
- `src/rag/pipeline.py` → `query_rag()` — add evaluation step after reranking

**Implementation:**
```python
def _evaluate_retrieval_quality(self, user_query: str, results: List) -> bool:
    """Check if retrieved results are good enough to answer."""
    if not results:
        return False
    top_score = float(results[0].score or 0.0)
    if top_score < 0.01:  # RRF score threshold
        return False
    # Check lexical overlap of top result
    top_text = (results[0].payload or {}).get("text_content", "")
    overlap = self._lexical_overlap(self._tokenize(user_query), top_text)
    return overlap > 0.05 or top_score > 0.05
```

If evaluation fails, return honest "no relevant information found" instead of forcing an LLM answer.

**Impact:** Prevents hallucination when retrieval fails. Customer trust.
**Verification:** Query about unrelated topic returns "not found" instead of fabricated answer.

### 5. RAGAS Evaluation Harness

**What:** Systematic RAG evaluation with faithfulness, context precision, response relevancy metrics.

**Files to change:**
- `requirements.txt` → add `ragas`
- `src/eval/ragas_eval.py` → new file
- `src/eval/dataset.py` → expand to 20+ questions

**Implementation:**
```python
# src/eval/ragas_eval.py
from ragas import evaluate
from ragas.metrics import context_precision, faithfulness, response_relevancy

async def run_ragas_eval(rag_pipeline, eval_questions):
    results = []
    for q in eval_questions:
        rag_result = await rag_pipeline.query_rag(q["question"])
        results.append({
            "question": q["question"],
            "answer": rag_result["result"]["answer"],
            "contexts": [s["text"] for s in rag_result["result"]["sources"]],
            "ground_truth": q["expected_answer"],
        })
    return evaluate(results, metrics=[faithfulness, context_precision, response_relevancy])
```

**Impact:** Can measure quality improvements systematically. CI-ready.
**Verification:** `python -m src.eval.ragas_eval` outputs faithfulness > 0.7.

---

## OCR / Document Processing Improvements (Items 6-9)

### 6. Pre-Processing Pipeline — Deskew, Denoise, Binarize

**What:** Apply OpenCV pre-processing to scanned images before OCR.

**Files to change:**
- `src/ocr/pipeline.py` → `OCRPipeline._process_pdf()` — add pre-processing step
- `requirements.txt` → `opencv-python` (already a dep of doctr)

**Implementation:**
```python
import cv2
import numpy as np

def preprocess_image(self, image: np.ndarray) -> np.ndarray:
    # 1. Grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    # 2. Deskew
    angle = self._detect_skew(gray)
    if abs(angle) > 0.5:
        gray = self._rotate(gray, angle)
    # 3. Denoise
    gray = cv2.fastNlMeansDenoising(gray, h=10)
    # 4. Adaptive threshold (Sauvola-like)
    gray = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)
    return gray

def _detect_skew(self, gray: np.ndarray) -> float:
    coords = np.column_stack(np.where(gray < 128))
    if len(coords) == 0:
        return 0.0
    angle = cv2.minAreaRect(coords)[-1]
    if angle < -45:
        angle = 90 + angle
    return angle
```

**Impact:** 5-15% OCR accuracy improvement on scanned insurance documents.
**Verification:** Upload a skewed scan → OCR extracts text correctly.

### 7. Post-Processing Validation — Field Validation

**What:** Regex-validate extracted fields (policy numbers, dates, amounts) before accepting LLM output.

**Files to change:**
- `src/services/policy_extraction_service.py` → add validation after extraction

**Implementation:**
```python
def _validate_summary(self, summary: dict) -> dict:
    """Validate and normalize extracted fields."""
    # Validate policy number — alphanumeric, 5-25 chars
    pn = summary.get("policy_number")
    if pn and not re.match(r'^[A-Z0-9/\-]{5,25}$', pn.upper().strip()):
        summary["policy_number"] = None  # Reject invalid
    
    # Validate dates — parse to ISO
    for date_field in ["effective_date", "expiration_date"]:
        val = summary.get(date_field)
        if val and not re.match(r'\d{4}-\d{2}-\d{2}', val):
            # Try parsing with dateutil
            try:
                from dateutil import parser
                parsed = parser.parse(val)
                summary[date_field] = parsed.strftime("%Y-%m-%d")
            except:
                summary[date_field] = None
    
    # Validate amounts — must be positive numeric
    for amt_field in ["coverage_amount", "premium_amount", "deductible"]:
        val = summary.get(amt_field)
        if val is not None and (not isinstance(val, (int, float)) or val < 0):
            summary[amt_field] = None
    
    return summary
```

**Impact:** Prevents invalid data from reaching the UI.
**Verification:** Test with malformed extraction → fields set to None, not garbage.

### 8. MinerU 2.5 Integration — Optional High-Accuracy Parser

**What:** Add MinerU 2.5 as optional parser for complex documents (tables, multi-column, formulas).

**Files to change:**
- `src/ocr/pipeline.py` → new `_process_pdf_with_mineru()` method
- `src/config/settings.py` → add `mineru_enabled: bool = False`

**Implementation:**
```python
async def _process_pdf_with_mineru(self, file_path: str) -> dict:
    """Process PDF with MinerU 2.5 for high-accuracy extraction."""
    try:
        from magic_pdf.pipe.UNIPipe import UNIPipe
        # ... MinerU processing
        return {"full_text": text, "method": "mineru", "tables": tables}
    except ImportError:
        raise RuntimeError("MinerU not installed. pip install magic-pdf[full]")
```

Gate behind `MINERU_ENABLED=true`, try MinerU first for PDFs with tables, fall back to PyMuPDF.

**Impact:** SOTA table/layout extraction (90.67 on OmniDocBench).
**Verification:** Complex insurance table PDF → HTML table extracted correctly.

### 9. Multi-View Indexing — Entity/Table/Image Chunks

**What:** Create separate chunk types (entity, table, image) alongside text chunks for multi-view retrieval.

**Files to change:**
- `src/services/document_processing_service.py` → extraction stage
- `src/rag/pipeline.py` → store chunk_type in Qdrant payload

**Implementation:**
During ingestion, after OCR:
1. Extract entities (policy numbers, dates, amounts) → store as `chunk_type: "entity"`
2. Detect tables → store as `chunk_type: "table"` with structured JSON
3. Regular text → store as `chunk_type: "text"` (existing behavior)

At query time: if query contains exact identifiers (policy number, date), search `chunk_type: "entity"` first.

**Impact:** Exact lookup for policy numbers (FTS-only, no embedding needed).
**Verification:** "Find policy 4214i/CPHSR" returns the entity chunk in <50ms.

---

## Mobile App Improvements (Items 10-16)

### 10. Push Notifications — Renewal Reminders

**What:** Schedule local notifications 30/14/7 days before policy expiry.

**Files to change:**
- `mobile/pubspec.yaml` → add `flutter_local_notifications` + `timezone`
- `mobile/lib/services/notification_service.dart` → new file
- `mobile/lib/main.dart` → initialize notifications
- `mobile/lib/providers/policy_providers.dart` → schedule notifications when summaries load

**Implementation:**
```dart
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  
  static Future<void> init() async {
    await _plugin.initialize(InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
  }
  
  static Future<void> scheduleRenewalReminder(PolicySummary summary) async {
    if (summary.endDate == null || summary.isExpired) return;
    final daysBefore = [30, 14, 7];
    for (final days in daysBefore) {
      final scheduledDate = summary.endDate!.subtract(Duration(days: days));
      if (scheduledDate.isAfter(DateTime.now())) {
        await _plugin.zonedSchedule(
          summary.documentId.hashCode + days,
          'Policy Renewal Reminder',
          'Your ${summary.documentType} from ${summary.insurer ?? "Unknown"} expires in $days days',
          TZDateTime.from(scheduledDate),
          ...,
        );
      }
    }
  }
}
```

**Impact:** Core promised feature. Drives retention and DAU.
**Verification:** Upload policy with expiry 30 days out → notification scheduled.

### 11. Onboarding Flow — First-Run Tutorial

**What:** 3-screen onboarding: "Upload your policy" → "Ask questions" → "Track renewals".

**Files to change:**
- `mobile/lib/screens/onboarding_screen.dart` → new file
- `mobile/lib/main.dart` → show onboarding on first launch (check Hive for `onboarding_complete`)

**Implementation:**
```dart
class OnboardingScreen extends StatelessWidget {
  // 3 pages with illustrations:
  // 1. "Upload your insurance documents" (upload icon)
  // 2. "Ask questions in plain English" (chat icon)
  // 3. "Track renewals, gaps, and claims" (calendar icon)
  // After: set onboarding_complete = true in Hive, go to MainNavigation
}
```

**Impact:** Determines Day-1 retention. Users who complete onboarding are 3x more likely to upload.
**Verification:** Fresh install → onboarding shows → completes → main app.

### 12. App Store Screenshots + Metadata — ASO

**What:** Create 5 app store screenshots and optimized metadata.

**Files to change:**
- `mobile/assets/store/` → screenshots (generated from simulator)
- `mobile/pubspec.yaml` → update app name, description

**Implementation:**
1. Run app on simulator in demo mode
2. Capture 5 screenshots: Dashboard (policy cards), Q&A (answer), Emergency Card, Coverage Gaps, Renewal Calendar
3. Write ASO-optimized title, subtitle, keywords per launch_strategy doc
4. Add to App Store Connect / Play Console

**Impact:** Determines download conversion rate.
**Verification:** Screenshots show real data (demo mode), metadata matches ASO spec.

### 13. Document Preview — View Original PDF

**What:** Tap a document to view the original PDF in-app.

**Files to change:**
- `mobile/lib/screens/documents_list.dart` → add preview button
- `mobile/pubspec.yaml` → `pdfx` already in deps
- `mobile/lib/screens/document_preview_screen.dart` → new file

**Implementation:**
```dart
class DocumentPreviewScreen extends StatelessWidget {
  final String filePath;
  // Use pdfx PdfView to render the PDF
  // Show page navigation, zoom
}
```

**Impact:** Users want to see the source document, not just extracted text.
**Verification:** Tap document → PDF renders with page navigation.

### 14. Dark Mode — Theme Adaptation

**What:** Support system dark mode.

**Files to change:**
- `mobile/lib/main.dart` → `ThemeData` with `brightness: Brightness.dark` variant

**Implementation:**
```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: MediaQuery.platformBrightnessOf(context),
  ),
  useMaterial3: true,
),
// Or use dynamic_color for Material You
```

**Impact:** User expectation, battery saving on OLED screens.
**Verification:** Toggle system dark mode → app adapts.

### 15. Deep Linking — Notification to Screen

**What:** Tapping a renewal notification opens the specific policy in the app.

**Files to change:**
- `mobile/lib/main.dart` → handle deep links
- `mobile/lib/services/notification_service.dart` → include payload

**Implementation:**
```dart
// In notification payload: {"type": "renewal", "document_id": "..."}
// In main.dart: parse deep link, navigate to RenewalCalendarScreen or PolicyDetailScreen
```

**Impact:** Notification → action loop. Reduces friction.
**Verification:** Tap notification → app opens at renewal calendar with policy highlighted.

### 16. Offline Indicator — Backend Unavailable Banner

**What:** Show a banner when the backend is unreachable.

**Files to change:**
- `mobile/lib/widgets/shared/offline_banner.dart` → new file (already exists from other agent?)
- `mobile/lib/screens/dashboard_screen.dart` → add connectivity check

**Implementation:**
```dart
// Check API health on app start and periodically
// If unreachable, show orange banner: "Offline mode — some features may be limited"
// Check every 30 seconds, auto-dismiss when back online
```

**Impact:** Honest UX, prevents confusion when backend is down.
**Verification:** Kill backend → app shows banner → restart backend → banner disappears.

---

## Backend Improvements (Items 17-20)

### 17. Persistent Document Storage — SQLite/Postgres

**What:** Replace in-memory DOCUMENTS list with SQLite storage.

**Files to change:**
- `src/api/document.py` → replace `DOCUMENTS = []` with SQLite queries
- `src/models/document.py` → add `to_dict()` / `from_dict()`
- `src/config/settings.py` → add `database_url`

**Implementation:**
```python
import sqlite3

DB_PATH = "storage/coverwise.db"

def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            filename TEXT,
            document_type TEXT,
            insurer TEXT,
            status TEXT,
            uploaded_at TEXT,
            session_id TEXT,
            metadata_json TEXT
        )
    """)
    conn.commit()
    return conn
```

**Impact:** Documents survive restarts. Production-ready.
**Verification:** Upload document → restart server → document still exists.

### 18. API Documentation — OpenAPI

**What:** Auto-generated Swagger/OpenAPI docs.

**Files to change:**
- `src/app/main.py` → already has FastAPI which auto-generates /docs

**Implementation:**
FastAPI already generates OpenAPI at `/docs` and `/redoc`. Just need to:
1. Add proper docstrings to all endpoints
2. Add response models
3. Add tags

**Impact:** Developer experience.
**Verification:** Visit `/docs` → all endpoints documented with examples.

### 19. Health Monitoring Endpoint

**What:** `/health` returns status of all services.

**Files to change:**
- `src/app/main.py` → expand `/health` endpoint

**Implementation:**
```python
@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "services": {
            "rag": bool(rag_pipeline),
            "ocr": bool(document_processing_service),
            "extraction": bool(document_processing_service and document_processing_service.policy_extraction_service),
            "qdrant": "connected" if rag_pipeline else "unavailable",
            "redis": "connected" if rag_pipeline and rag_pipeline.cache else "disabled",
        },
        "version": "2.0.0",
    }
```

**Impact:** Operational visibility.
**Verification:** `GET /health` returns service status.

### 20. Background Extraction Queue

**What:** Don't block upload on extraction — return 202 immediately, extract in background.

**Files to change:**
- `src/api/document.py` → move extraction to `BackgroundTasks`
- `src/services/document_processing_service.py` → async extraction

**Implementation:**
Already partially done with FastAPI `BackgroundTasks`. Just need to move the extraction step to background:
```python
background_tasks.add_task(
    processing_service.policy_extraction_service.extract_summary,
    document_id, extracted_text, document_type
)
```

**Impact:** Faster upload response time (extraction takes 2-5s).
**Verification:** Upload returns immediately, summary appears within 10s.

---

## Testing Improvements (Items 21-23)

### 21. Integration Tests — End-to-End

**What:** Test full flow: upload → OCR → extract → query → answer.

**Files to change:**
- `tests/test_integration.py` → new file

**Implementation:**
```python
@pytest.mark.asyncio
async def test_full_flow():
    # 1. Upload a test PDF
    # 2. Wait for processing
    # 3. Query "What is the policy number?"
    # 4. Assert answer contains expected policy number
```

**Impact:** Catches contract mismatches between services.
**Verification:** Test passes with real test PDF.

### 22. RAGAS Eval Suite — 20+ Questions

**What:** Expanded eval dataset with RAGAS metrics.

**Files to change:**
- `src/eval/dataset.py` → expand to 20+ questions across document types
- `src/eval/ragas_eval.py` → RAGAS evaluation runner

**Implementation:** Already spec'd in item 5 above. Expand dataset with:
- 5 policy number queries (exact match)
- 5 coverage amount queries (numeric)
- 5 date queries (temporal)
- 3 exclusion queries (semantic)
- 2 comparison queries (cross-document)

**Impact:** Systematic quality measurement.
**Verification:** `python -m src.eval.ragas_eval` outputs all metrics.

### 23. Performance Tests — Query Latency

**What:** Measure query latency under load.

**Files to change:**
- `tests/test_performance.py` → new file

**Implementation:**
```python
import time

@pytest.mark.asyncio
async def test_query_latency():
    start = time.time()
    await rag_pipeline.query_rag("What is my policy number?")
    elapsed = time.time() - start
    assert elapsed < 5.0  # Must respond within 5 seconds
```

**Impact:** Production readiness.
**Verification:** Test passes, latency < 5s.

---

## Product / Marketing Improvements (Items 24-27)

### 24. Landing Page

**What:** Simple landing page: "Upload insurance, understand instantly" + email capture.

**Files to change:**
- `src/frontend/templates/landing.html` → new file
- `src/frontend/app.py` → add `/landing` route

**Implementation:**
Minimal HTML with:
- Hero: "Upload insurance, understand instantly"
- 3 feature bullets with icons
- Email capture form (stores to SQLite)
- Demo video embed
- App store links (when live)

**Impact:** Pre-launch waitlist.
**Verification:** Visit `/landing` → page loads, email submission works.

### 25. Demo Video

**What:** 60-second screen recording showing the app in action.

**Implementation:**
1. Run app on simulator in demo mode
2. Screen record: upload → summary appears → ask question → emergency card → coverage gaps
3. Edit to 60 seconds with captions
4. Upload to YouTube as unlisted, use in Product Hunt / app store

**Impact:** Product Hunt launch, app store preview, social sharing.
**Verification:** Video plays, shows all key features in 60 seconds.

### 26. Blog Content — 5 SEO Articles

**What:** 5 articles on insurance literacy.

**Files:**
- `src/frontend/blog/` → new directory with markdown files
- Topics per launch_strategy doc

**Implementation:**
1. "How to Read Your Health Insurance Policy in 5 Minutes"
2. "What Is a Deductible? (And Why It Matters)"
3. "5 Coverage Gaps You Probably Have in Your Insurance"
4. "How to File an Insurance Claim: A Step-by-Step Guide"
5. "Insurance Terms Explained: A Simple Glossary"

**Impact:** Organic SEO traffic.
**Verification:** Articles indexed by Google, drive traffic to landing page.

### 27. Social Media Setup

**What:** Create Twitter/X, Instagram, LinkedIn accounts for CoverWise.

**Implementation:**
1. Create accounts with consistent branding
2. Profile: "CoverWise — Upload insurance, understand instantly"
3. Bio: "AI-powered insurance document assistant. Read your policies, ask questions, track renewals, file claims."
4. Post first 3 tips from the blog content

**Impact:** Distribution channels for content marketing.
**Verification:** All 3 accounts live with profile, bio, first posts.