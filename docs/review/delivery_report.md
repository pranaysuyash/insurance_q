# Delivery Report — Insurance App Refactor

## 1. Model Update: `gpt-4.1-nano` → `gpt-5-nano`

### Comparison

| Dimension | gpt-4.1-nano | gpt-5-nano | Δ |
|---|---|---|---|
| Input price | $0.10/1M tok | $0.05/1M tok | **-50%** |
| Output price | $0.40/1M tok | $0.40/1M tok | same |
| Context window | 1,000,000 | 400,000 | -60% (still ample for insurance docs) |
| Max output | 33K tok | 128K tok | **+288%** |
| GPQA Diamond | 51.2% | 67.6% | **+16.4 pp** |
| Intelligence Index | 9.6% | 19.9% | **+107%** |
| Simple QA | 71.7% | 86.4% | **+14.7 pp** |
| Structured Outputs | ❌ | ✅ | guaranteed valid JSON |
| Reasoning effort | ❌ | ✅ | controllable reasoning |

**Verdict**: Update is a no-brainer — better quality at half the input cost.

### Embedding Model

`text-embedding-ada-002` ($0.10/1M tok, 1536d) → `text-embedding-3-small` ($0.02/1M tok, 1536d): **5× cheaper**, same dimension, higher MTEB scores, drop-in replacement for existing Qdrant schema.

---

## 2. Config Consolidation

**Before**: Config scattered across `pipeline.py` (os.getenv defaults), `config.py` (dead dataclass), `.env`, and docker-compose.yml.

**After**: Single pydantic-settings `Settings` class at `src/config/settings.py`. One import, one `.env` file, one source of truth. The old `src/rag/config.py` now emits a `DeprecationWarning`.

**Files changed**:
- `.env` — model names updated
- `src/config/settings.py` — **new**, canonical Settings
- `src/config/__init__.py` — **new**
- `src/rag/pipeline.py` — rewritten to consume Settings
- `src/rag/config.py` — deprecated with warning
- `docker-compose.yml` — added model env vars

---

## 3. Unified LLM Client

**New module**: `src/llm/client.py`

Features:
- `AsyncOpenAI` — non-blocking, event-loop-safe
- `generate()` — with semaphore (max 5 concurrent), exponential-backoff retry, cost tracking
- `generate_structured()` — structured outputs via `response_format="json_schema"` (GPT-5 nano native)
- `CostTracker` — per-call token/cost records, model pricing table
- Quota-error detection: 429 insufficient_quota → abort immediately (no pointless retries)

---

## 4. DocQA Enabled

**Before**: `src/ocr/pipeline.py` `_get_layout_elements_for_image` immediately returned `[]` at line 187. DocQA was fully bypassed.

**After**: Replaced HF DocQA model with LLM-based structured extraction:
- `_get_layout_elements_for_text(page_text, page_num, questions)` uses `LLMClient.generate_structured()` with `InsuranceDocumentExtraction` Pydantic model
- Nine extracted fields: `policy_number`, `insurer`, `document_type`, `effective_date`, `expiration_date`, `insured_name`, `coverage_amount`, `premium_amount`, `deductible`, `copay`
- Extraction model at `src/models/extraction.py`

---

## 5. Eval Infrastructure

**New module**: `src/eval/`

- `dataset.py` — `EvalSample` schema + 6-sample `INSURANCE_EVAL_SET` (policy number, provider, coverage, effective date, deductible, insured name)
- `runner.py` — `run_eval(rag_pipeline, eval_set)` → `EvalResult` with per-field pass/fail, scoring, summary dict
- Each sample checks: (a) expected fields extracted correctly, (b) expected substrings in answer

---

## 6. Async Fixes

- All `time.sleep()` → `asyncio.sleep()` — no more event-loop blocking
- `OpenAI(...)` → `AsyncOpenAI(...)` — all calls truly async
- `openai_client.chat.completions.create(...)` → `LLMClient.generate(...)` — retry + cost tracking
- Startup document processing moved to background task — server accepts connections immediately

---

## 7. Verification

Server started and responds on all endpoints:

```
/health                  → {"status":"ok","rag_status":"available",...}
/debug/services          → {"rag_pipeline":"initialized",...}
/rag/stats               → {"embedding_model":"text-embedding-3-small",...}
/processing/status       → {"active_processing_jobs":2,...}
```

Blocked: OpenAI quota exhausted (429). Embedding and chat calls fail at the API level. No code changes needed — operational issue (add billing credits).

---

## 8. Remaining

| Item | Priority | Notes |
|---|---|---|
| Hybrid search + reranking | Medium | Qdrant `bm25` + RRF; needs Qdrant server, not in-memory |
| Expand eval dataset | Low | Currently 6 samples; add more document types |
| CI eval gate | Low | Hook eval runner into CI after quota is restored |
| Delete old config.py | Low | After verifying no imports remain |
