# Document Processing Research: OCR, Pre/Post-Processing, and Eval

**Date:** 2026-07-11
**Scope:** Comprehensive research on open-source document parsing tools (2025+), pre-processing pipelines, post-processing pipelines, and RAG evaluation frameworks. Findings are evaluated against CoverWise's current architecture and long-term product direction.

---

## 1. Open-Source Document Parsing Tools (2025+)

### 1.1 Current State of CoverWise Pipeline

CoverWise currently uses:
- **PyMuPDF** for direct text extraction from digital PDFs (fast, no structure recovery)
- **doctr** (db_resnet50 + crnn_vgg16_bn) for OCR on scanned documents and images (~500MB models)
- **Docling** (IBM) as optional opt-in for deep layout analysis (`DOCLING_ENABLED=true`)
- **LLM-based field extraction** via `LLMClient.generate_structured()` on extracted text

### 1.2 Tool Comparison Matrix (2025 Benchmarks)

| Tool | License | Format Support | OmniDocBench Score | Speed (macOS) | RAM | Stars | Active Dev |
|------|---------|---------------|-------------------|---------------|-----|-------|-----------|
| **MinerU** | AGPL-3.0 (PyMuPDF dep) | PDF, PPT, DOCX | **90.67** (best) | Slow (~2.5 min/9pg) | High | 30K | Very active (229 commits/28d) |
| **MinerU 2.5** | AGPL-3.0 | PDF, images | **90.67** (SOTA) | 2.12 pg/s on A100 | 1.2B params | 30K | Very active |
| **Marker** | GPL-3.0 (CC-BY-NC-SA weights) | PDF, img, PPTX, DOCX, XLSX, HTML, EPUB | Runner-up | Fast (~20s/9pg) | Medium | 22K | Slowing (19 commits/28d) |
| **Docling** | **MIT** | PDF, DOCX, XLSX, PPTX, HTML, CSV, images | Worst (0.589 EN) | Fast (~21s/9pg) | Medium | 26K | Active (139 commits/28d) |
| **MarkItDown** | **MIT** | PDF, PPT, Word, Excel, img, audio, HTML, CSV, JSON, XML, ZIP, EPUB | Poor (text only) | **Fastest** (0.9s/9pg) | Low | 51K | Stalled (3 commits/28d) |
| **olmOCR** | Apache 2.0 | PDF, images | Runner-up | Requires 20GB+ GPU | High | 11K | Active (169 commits/28d) |
| **Surya 2** | GPL-3.0 | PDF, images (90+ langs) | Strong (83.3% olmOCR-bench) | 650M params | Medium | — | Active |
| **Unstructured.io** | Apache 2.0 (OSS) | 64+ file types | Good | Medium | Medium | 12K | Active |
| **PyMuPDF** (current) | AGPL-3.0 | PDF | Basic text only | **Fastest** | Low | — | Maintained |

### 1.3 Key Findings

**MinerU 2.5** is the new state-of-the-art for PDF parsing:
- 1.2B parameter vision-language model (compact!)
- Two-stage processing: structure analysis on downsampled images + recognition at native resolution
- Outperforms Gemini 2.5 Pro and MonkeyOCR-pro-3B on OmniDocBench (90.67)
- 4x faster than MonkeyOCR on A100
- Supports tables (HTML), formulas (LaTeX), reading order, 84 languages
- License: AGPL-3.0 (PyMuPDF dependency) — commercial restriction

**Surya 2** is the best lightweight OCR engine:
- 650M params, one model for 4 tasks: OCR, layout, reading order, table recognition
- 90+ language support
- olmOCR-bench: 83.3%
- Powers Marker internally
- License: GPL-3.0 with CC-BY-NC-SA weights (commercial exemption for <$5M revenue)

**Docling** remains the best MIT-licensed option:
- Local execution, privacy-friendly
- DocLayNet + TableFormer for layout and table structure
- Integrates with LlamaIndex, LangChain, Haystack
- But: worst OmniDocBench scores (0.589 EN, 0.909 CN)
- Good for simple documents, struggles with complex tables and Chinese

**Unstructured.io** is the broadest format supporter:
- 64+ file types including audio, video, email
- Apache 2.0 license (commercial-friendly)
- Good for enterprise ETL pipelines
- Cloud API available for production scale

### 1.4 Recommendation for CoverWise

**Short-term (now):** Keep current pipeline (PyMuPDF + doctr + optional Docling). It works for insurance PDFs which are mostly text-based.

**Medium-term (next sprint):** Add **MinerU 2.5** as an optional high-accuracy parser for complex insurance documents (multi-column, tables, formulas). Gate behind `MINERU_ENABLED=true` like Docling. The 1.2B model is small enough for M-series Macs.

**Long-term:** Evaluate **Surya 2** as a doctr replacement — it's 650M params (vs doctr's ~500MB+), does layout + reading order + tables in one model, and supports 90+ languages. The GPL license is a concern for commercial use but the <$5M revenue exemption may apply.

**License risk:** MinerU and PyMuPDF both use AGPL-3.0, which requires source disclosure for network-facing applications. If CoverWise becomes a SaaS, this is a problem. Alternatives:
- Use Docling (MIT) for basic parsing
- Use Surya 2 (GPL, but <$5M exemption) for OCR
- Use MarkItDown (MIT) for non-PDF formats
- Or: license MinerU commercially from OpenDataLab

---

## 2. Pre-Processing Pipeline Research

### 2.1 Current State

CoverWise has **no image pre-processing**. The OCR pipeline directly processes raw images/PDFs without:
- Deskewing
- Denoising
- Binarization
- Contrast enhancement
- Auto-cropping
- Border removal

### 2.2 Standard Pre-Processing Pipeline (Industry Best Practice)

```
Raw Image/PDF
    │
    ▼
1. Format Normalization → convert to consistent image format (PNG/BMP)
    │
    ▼
2. Deskew → detect and correct text skew angle (Hough transform, projection profile)
    │
    ▼
3. Denoise → remove scan artifacts (Gaussian blur, median filter, BM3D)
    │
    ▼
4. Binarization → convert to black/white (Otsu, Sauvola, adaptive threshold)
    │
    ▼
5. Contrast Enhancement → CLAHE (Contrast Limited Adaptive Histogram Equalization)
    │
    ▼
6. Border Removal → remove black borders from scans
    │
    ▼
7. Auto-Crop → remove whitespace margins
    │
    ▼
8. Resolution Check → ensure minimum 300 DPI for OCR
    │
    ▼
OCR Engine (doctr / Surya / MinerU)
```

### 2.3 Tools for Pre-Processing

| Technique | Library | License | Notes |
|-----------|---------|---------|-------|
| Deskew | OpenCV (`cv2`) | Apache 2.0 | Hough line transform or projection profile |
| Denoise | OpenCV (`cv2.fastNlMeansDenoising`) | Apache 2.0 | Best for document scans |
| Binarization | OpenCV (`cv2.threshold`, `cv2.adaptiveThreshold`) | Apache 2.0 | Otsu for uniform, Sauvola for variable lighting |
| Contrast | OpenCV (`cv2.createCLAHE`) | Apache 2.0 | CLAHE is the gold standard |
| Auto-crop | OpenCV | Apache 2.0 | Contour detection + bounding box |
| Border removal | OpenCV | Apache 2.0 | Flood fill from edges |
| Resolution check | PyMuPDF / PIL | AGPL-3.0 / MIT | Check DPI metadata |

### 2.4 Recommendation for CoverWise

Add a pre-processing stage to `OCRPipeline._process_pdf()` before sending pages to doctr:

```python
def _preprocess_page_image(self, image: np.ndarray) -> np.ndarray:
    """Apply standard pre-processing to improve OCR accuracy."""
    # 1. Convert to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # 2. Deskew
    angle = self._detect_skew_angle(gray)
    if abs(angle) > 0.5:
        gray = self._rotate_image(gray, angle)
    
    # 3. Denoise
    gray = cv2.fastNlMeansDenoising(gray, h=10)
    
    # 4. Binarization (Sauvola — best for variable lighting in scanned docs)
    gray = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY, 11, 2
    )
    
    # 5. Border removal
    gray = self._remove_borders(gray)
    
    return gray
```

This should improve OCR accuracy on scanned insurance documents by 5-15% based on industry benchmarks. OpenCV is already a dependency of doctr.

---

## 3. Post-Processing Pipeline Research

### 3.1 Current State

CoverWise has **minimal post-processing**:
- LLM-based field extraction (via `generate_structured`)
- Basic document classification (keyword + LLM fallback)
- No field validation
- No entity normalization
- No deduplication of extracted entities
- No cross-document linking

### 3.2 Standard Post-Processing Pipeline (Industry Best Practice)

```
OCR Output (raw text + layout elements)
    │
    ▼
1. Text Cleanup → fix common OCR errors (0→O, l→1, rn→m), remove artifacts
    │
    ▼
2. Field Extraction → structured extraction (policy number, dates, amounts, names)
    │
    ▼
3. Field Validation → regex/regex+LLM validation per field type
    │
    ▼
4. Entity Normalization → standardize dates (ISO-8601), amounts (numeric), phone numbers (E.164)
    │
    ▼
5. Entity Linking → link extracted entities to known databases (insurer names, ICD codes)
    │
    ▼
6. Cross-Document Dedup → detect if same policy was uploaded twice (hash + content match)
    │
    ▼
7. Confidence Scoring → assign confidence to each extracted field
    │
    ▼
8. Human-in-the-Loop Review → flag low-confidence fields for manual review
    │
    ▼
Structured Policy Data (PolicySummary)
```

### 3.3 Specific Techniques for Insurance Documents

| Field Type | Validation | Normalization | Confidence Signal |
|-----------|------------|---------------|------------------|
| Policy Number | Regex: alphanumeric, 8-20 chars | Uppercase, remove spaces | Regex match score |
| Dates | Date parser (dateutil), range check | ISO-8601 (YYYY-MM-DD) | Parser confidence |
| Amounts | Numeric, currency symbol detection | Float (INR default), detect lakh/crore | Currency match |
| Phone Numbers | E.164 format, country code detection | `+CC-XXX-XXXXXXX` | Digit count + format |
| Email | RFC 5322 regex | Lowercase | Regex match |
| Insurer Name | Fuzzy match against known insurer list | Canonical name mapping | Fuzzy match score |
| Coverage Type | Keyword classification (health/auto/home/life/travel) | Standard taxonomy | Classification confidence |

### 3.4 Tools for Post-Processing

| Technique | Library | License | Notes |
|-----------|---------|---------|-------|
| Text cleanup | regex, `ftfy` (fix text encoding) | MIT | Common OCR error patterns |
| Date parsing | `python-dateutil` | BSD | Handles DD-MM-YYYY, DD-Mon-YYYY, etc. |
| Phone normalization | `phonenumbers` (Google) | Apache 2.0 | E.164 normalization |
| Fuzzy matching | `rapidfuzz` | MIT | Insurer name matching |
| Entity linking | spaCy NER + custom gazetteer | MIT | Named entity recognition |
| Confidence scoring | Custom (per-field) | — | Rule-based + LLM-judge |

### 3.5 Recommendation for CoverWise

The mobile app's `PolicyExtractionService` already does basic post-processing (amount parsing, date parsing, email extraction). The backend should add:

1. **Text cleanup** before LLM extraction — fix common OCR errors to improve LLM accuracy
2. **Field validation** — regex-validate policy numbers, dates, amounts before accepting LLM output
3. **Entity normalization** — standardize insurer names against a canonical list (the `_inferInsurerInfo` already has a list but doesn't do fuzzy matching)
4. **Confidence scoring** — track per-field confidence and surface low-confidence extractions to the user
5. **Cross-document dedup** — the `findDuplicateDocument` in `LocalStorageService` does filename matching but should also do content hash matching

---

## 4. RAG Evaluation Frameworks

### 4.1 Current State

CoverWise has a minimal eval system (`src/eval/`):
- 7 test samples, all from a single document
- Checks: field extraction, answer contains, source contains, citations
- No integration with standard RAG eval frameworks
- No CI integration
- No automated reporting

### 4.2 Framework Comparison

| Framework | License | Focus | Key Metrics | Integration | Best For |
|-----------|---------|-------|-------------|-------------|----------|
| **RAGAS** | Apache 2.0 | RAG-specific | Context Precision, Context Recall, Faithfulness, Response Relevancy, Noise Sensitivity | LangChain, LlamaIndex, LangSmith, Arize | Research + pipeline testing |
| **DeepEval** | Apache 2.0 | LLM + RAG + agents | Faithfulness, Answer Relevancy, + custom metrics, agentic evals | LangChain, CI/CD native | Production testing + CI |
| **TruLens** | Apache 2.0 | Production monitoring | RAG Triad (context relevance, faithfulness, answer relevance), cost tracking | LangChain, LlamaIndex | Continuous monitoring |
| **Phoenix** (Arize) | Apache 2.0 | Observability + eval | Trace-level metrics, drift detection, production monitoring | LangChain, LlamaIndex, Ollama | Production observability |
| **Deepchecks** | Commercial | Production quality | Data integrity, model quality, drift | Custom | Enterprise monitoring |
| **Opik** (Comet) | Commercial | LLM eval + tracking | Hallucination, toxicity, custom | LangChain, Ollama | Experiment tracking |

### 4.3 RAGAS Metrics (Most Relevant for CoverWise)

RAGAS provides these RAG-specific metrics:

| Metric | What It Measures | How It Works |
|--------|-----------------|-------------|
| **Context Precision** | Are retrieved chunks relevant to the query? | LLM judges if each retrieved chunk is relevant |
| **Context Recall** | Did we retrieve all needed information? | Compare retrieved chunks against ground truth |
| **Faithfulness** | Is the answer grounded in retrieved context? | LLM checks if each claim in answer is supported by context |
| **Response Relevancy** | Does the answer address the question? | LLM generates hypothetical questions from answer, compares to original |
| **Noise Sensitivity** | How much does irrelevant context hurt? | Measure answer degradation when noise is added |
| **Context Entities Recall** | Are key entities in the context? | Named entity overlap between context and ground truth |

### 4.4 Recommendation for CoverWise

**Adopt RAGAS** for pipeline evaluation:
- Open-source (Apache 2.0), RAG-specific, integrates with LangChain/LlamaIndex
- Metrics directly map to CoverWise's needs: faithfulness (are answers grounded in the policy text?), context precision (are we retrieving the right chunks?)
- Has test data generation — can auto-generate test cases from documents
- CLI support for CI/CD integration

**Adopt TruLens** for production monitoring:
- The RAG Triad (context relevance, faithfulness, answer relevance) is exactly what we need to monitor in production
- Cost tracking aligns with motto_v3's observability requirements
- Can alert on faithfulness drops (when answers stop being grounded in policy text)

**Implementation plan:**
1. Add RAGAS to `requirements.txt`
2. Create `src/eval/ragas_eval.py` with RAGAS metrics wrapping `query_rag()`
3. Generate test set from the demo policy using RAGAS testset generation
4. Add eval CI step that runs RAGAS metrics on every PR
5. Add TruLens tracing to `query_rag()` for production observability

---

## 5. Summary: Recommended Pipeline Upgrade

### Current Pipeline
```
PDF → PyMuPDF (text) → doctr (OCR fallback) → LLM extraction → RAG (embed + search + LLM)
```

### Recommended Pipeline (staged)
```
PDF → [Pre-processing: deskew, denoise, binarize, contrast]
  → [Parser: PyMuPDF → MinerU 2.5 (complex docs) → Surya 2 (scanned)]
  → [Post-processing: text cleanup, field validation, entity normalization, confidence scoring]
  → [LLM extraction: structured field extraction with validation]
  → [RAG: embed + hybrid search + rerank + LLM answer]
  → [Eval: RAGAS faithfulness + context precision + response relevancy]
  → [Monitoring: TruLens RAG Triad + cost tracking]
```

### Priority Order
1. **Pre-processing** (immediate — OpenCV, low effort, high impact)
2. **RAGAS eval** (next sprint — Apache 2.0, medium effort, high visibility)
3. **Post-processing validation** (next sprint — medium effort, quality improvement)
4. **MinerU 2.5 integration** (when license is resolved — high effort, high accuracy gain)
5. **Surya 2 as doctr replacement** (when commercial license is needed — medium effort)
6. **TruLens monitoring** (when in production — medium effort, operational visibility)

---

## 6. Sources

### OCR/Parsing Tools
- [Euler AI Benchmark](https://www.eulerai.au/blog/doc-parser-benchmark) — comprehensive comparison with OmniDocBench scores
- [LlamaIndex Parser Comparison 2025](https://www.llamaindex.ai/insights/document-parser-comparison-2025) — cloud + open-source comparison
- [MinerU GitHub](https://github.com/opendatalab/mineru) — 30K stars, AGPL-3.0
- [MinerU 2.5 paper coverage](https://neurohive.io/en/state-of-the-art/mineru2-5-open-source-1-2b-model-for-pdf-parsing-outperforms-gemini-2-5-pro-on-benchmarks/) — 1.2B VLM, SOTA on OmniDocBench
- [Surya 2 / Datalab](https://github.com/datalab-to/surya) — 650M params, 90+ languages
- [Marker](https://github.com/VikParuchuri/marker) — built on Surya, GPL-3.0
- [Docling](https://github.com/docling-project/docling) — MIT, IBM Research
- [MarkItDown](https://github.com/microsoft/markitdown) — MIT, Microsoft
- [olmOCR](https://github.com/allenai/olmocr) — Apache 2.0, AllenNLP
- [Unstructured.io](https://github.com/Unstructured-IO/unstructured) — Apache 2.0, 64+ formats
- [OmniDocBench](https://github.com/opendatalab/OmniDocBench) — CVPR 2025 benchmark, 981 PDF pages
- [Applied AI PDF Parsing Benchmark](https://www.applied-ai.com/briefings/pdf-parsing-benchmark/) — 800+ documents, 17 parsers

### Pre-Processing
- [Survey on Image Preprocessing for OCR](https://medium.com/technovators/survey-on-image-preprocessing-techniques-to-improve-ocr-accuracy-616ddb931b76)
- [LlamaIndex: Image Preprocessing for OCR](https://www.llamaindex.ai/glossary/what-is-image-preprocessing)
- [MDPI: Analysis of Image Preprocessing and Binarization for OCR](https://www.mdpi.com/2079-9292/12/11/2449)
- [python-ocr-preprocessing GitHub](https://github.com/neonwatty/python-ocr-preprocessing)

### Post-Processing
- [Unstract: Best OCR for Insurance](https://unstract.com/blog/best-ocr-for-insurance-document-processing-automation/)
- [LlamaIndex: OCR for Insurance Documents](https://www.llamaindex.ai/blog/ocr-for-insurance-documents)
- [AltexSoft: IDP in Insurance](https://www.altexsoft.com/blog/idp-intelligent-document-processing-insurance/)
- [Docsumo: Insurance OCR](https://www.docsumo.com/blogs/ocr/insurance-documents)

### RAG Evaluation
- [RAGAS Documentation](https://docs.ragas.io/en/stable/concepts/metrics/available_metrics/)
- [RAGAS Paper (arXiv)](https://arxiv.org/abs/2309.15217) — reference-free RAG evaluation
- [DeepEval vs RAGAS](https://deepeval.com/blog/deepeval-vs-ragas) — feature comparison
- [Deepchecks: Best RAG Evaluation Tools](https://deepchecks.com/best-rag-evaluation-tools/)
- [Comet: LLM Evaluation Frameworks](https://www.comet.com/site/blog/llm-evaluation-frameworks/)
- [Datasumi: RAGAS vs TruLens vs DeepEval](https://www.datasumi.com/blog/rag-evaluation-frameworks)

## Addendum (2026-07-21) — capability coverage, workbook reconciliation, and code correction

The local workbook `/Users/pranay/Downloads/document_parsers_extractors_catalog_2026_v2.xlsx`
was inspected rather than treated as a dependency manifest. It contains 149
catalog entries and separate guidance for native text, scanned OCR, tables,
forms/KVP, formulas, office/web/email formats, privacy-first local execution,
recent document models, and general VLMs. The workbook’s separation of
specialist document parsers from general VLMs is retained here: a general VLM
can be useful for bounded review or derived chart descriptions, but its output
does not guarantee reading order, coordinates, cell fidelity, or semantic
correctness.

The current code changes the older “current state” in two ways. First,
`src/ocr/pipeline.py` already has `_preprocess_image`; the earlier statement
that preprocessing was absent is historical and no longer accurate. Second,
Docling and MinerU are optional branches, not complete production parsers:
their current adapters do not preserve a typed table/cell/figure/formula
representation and full parser provenance in the evidence contract.

The durable recommendation is now recorded in
`docs/technical/document_intelligence_capability_matrix_2026-07-21.md` and
`docs/decisions/ADR-2026-07-21-05-document-intelligence-router-and-evidence-contract.md`:
keep PyMuPDF/native parsing first, route by capability and quality, normalize
to one source-preserving CIR, then perform policy-field extraction and RAG.
Benchmark Docling, Surya, PaddleOCR/PP-Structure, and the current doctr path
against the CoverWise corpus before changing the default. Keep MinerU, Marker,
managed form services, and GPU-oriented VLMs in isolated profiles until
license, privacy, platform, cost, and accuracy gates pass.

One code hardening item is explicitly open: `src/ocr/pipeline.py` imports doctr
eagerly while the production requirements and the surrounding documentation
describe OCR as optional. Either make the dependency a declared runtime
requirement or make the import genuinely lazy with an observable, user-safe
failure state; do not claim optional import resilience until this is resolved.

## Addendum (2026-07-21) — optional-import item resolved

The preceding paragraph is historical and is superseded by the current code:
the doctr import is now deferred until OCR construction, and a missing local
OCR dependency produces a bounded import error at scan time. Module import
without doctr is covered by `tests/test_document_intelligence_contract.py`;
actual scanned-document execution remains a separate runtime gate.
