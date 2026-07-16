# CoverWise — Model Training Plan

**Date:** 2026-07-16
**Evidence Tier:** Tier 1 (web research + static code inspection)
**Author:** Buffy (AI Agent)
**Purpose:** Detailed plan for fine-tuning and training models to improve CoverWise's insurance document processing, extraction, and Q&A capabilities. Designed for incremental implementation starting with initial diff docs and scaling to full production.

## 0.1 Scope: Info Broker, Not Operations

CoverWise is an **information broker** — we help users **understand, access, and manage** their insurance information. We do NOT:
- File claims or process payments
- Sell or underwrite policies
- Communicate with insurers on behalf of users
- Handle policy renewals operationally

We DO:
- **Decode** — Turn complex policy PDFs into plain-English summaries
- **Access** — Find any policy detail in seconds via search, Q&A, or emergency screen
- **Organize** — Single source of truth for all family policies
- **Alert** — Renewal reminders, coverage gap detection
- **Empower** — Confidence that you know what you're covered for

All features and model training must align with this info broker scope.

---

## 0. Philosophy (motto_v3 §0.1, §0.15)

> "The model is one layer. The pipeline determines flow, validation, fallback, observability, and recovery. The data/configuration layer determines normalization, lookup, interpretation, product rules, labels, schemas, and long-term quality."

This plan separates concerns:
1. **Data layer** — What training data to collect, annotate, and version
2. **Model layer** — Which models to fine-tune, when, and how
3. **Pipeline layer** — How fine-tuned models integrate with the existing RAG pipeline
4. **Evaluation layer** — How to measure improvement and prevent regression

---

## 1. Current Model Stack

| Component | Current Model | Purpose | Fine-tune Candidate? |
|-----------|--------------|---------|---------------------|
| **Embeddings** | `text-embedding-3-small` (OpenAI) | Dense vector search | ⚠️ Could fine-tune open alternative |
| **Chat/Generation** | `gpt-5-nano` (OpenAI) | Answer generation, extraction | ❌ API-only, no fine-tuning |
| **Local Embeddings** | `all-MiniLM-L6-v2` (HF) | Offline fallback | ✅ Fine-tune on insurance corpus |
| **Local Chat** | `qwen2.5:7b` (Ollama) | Offline fallback | ✅ QLoRA fine-tune |
| **Reranker** | `ms-marco-MiniLM-L-6-v2` | Cross-encoder reranking | ✅ Fine-tune on insurance pairs |
| **OCR** | `doctr` (db_resnet50 + crnn_vgg16_bn) | Text extraction | ⚠️ Pre-trained, could fine-tune on insurance docs |
| **Contextual Retrieval** | GPT-5-nano (API) | Chunk context generation | ❌ API-only |

---

## 2. Training Data Strategy

### 2.1 Phase 1: Initial Diff Documents (User-Provided)

When you provide the initial diff documents, here's how we'll use them:

| Data Type | How to Collect | Format | Minimum Size |
|-----------|---------------|--------|-------------|
| **(query, context, answer) triples** | Ask GPT-4o to generate Q&A pairs from each document chunk | JSONL | 200-500 triples |
| **Chunk-context pairs** | Use existing contextual retrieval to generate context for each chunk | JSON | 1 chunk = 1 context |
| **Policy summaries** | Extract structured summaries from each document | JSON | 1 per document |
| **Coverage gap labels** | Manually label what's missing from each policy | JSON | 50-100 gaps |

**Format for initial diff docs:**
```json
{
  "document_id": "doc_abc123",
  "filename": "ICICI_Lombard_Health.pdf",
  "document_type": "Health Insurance",
  "insurer": "ICICI Lombard",
  "chunks": [
    {
      "chunk_id": "chunk_001",
      "text": "The Insured shall be entitled to claim for Pre-Hospitalization expenses...",
      "page": 3,
      "section": "Pre-Hospitalization Benefits"
    }
  ],
  "qa_pairs": [
    {
      "question": "Does this policy cover pre-hospitalization expenses?",
      "answer": "Yes, the policy covers pre-hospitalization expenses for 60 days before hospitalization.",
      "chunk_ids": ["chunk_001"],
      "confidence": 0.95
    }
  ],
  "coverage_gaps": [
    {
      "category": "Dental",
      "description": "No dental coverage listed in policy",
      "severity": "medium",
      "evidence": "Policy benefits section does not mention dental coverage"
    }
  ]
}
```

### 2.2 Phase 2: Scaling with More Documents

As more documents are ingested, we'll build training data through:

1. **User Feedback Loop** — Thumbs up/down on Q&A answers → labeled (query, answer) pairs
2. **Confidence-Based Sampling** — Low-confidence answers get human review → new training data
3. **Synthetic Generation** — Use GPT-4o to generate diverse Q&A pairs from policy chunks
4. **Cross-Document Pairs** — Questions that require information from multiple policies

### 2.3 Data Versioning

```
training_data/
├── v1_initial/           # From initial diff documents
│   ├── qa_pairs.jsonl
│   ├── chunk_contexts.json
│   ├── coverage_gaps.json
│   └── metadata.json
├── v2_scaled/            # From feedback + more documents
│   ├── qa_pairs.jsonl
│   ├── feedback_labeled.jsonl
│   ├── synthetic_pairs.jsonl
│   └── metadata.json
├── golden_set/           # Static evaluation set (never changes)
│   ├── retrieval_eval.json
│   ├── qa_eval.json
│   └── extraction_eval.json
└── README.md
```

---

## 3. Fine-Tuning Roadmap

### 3.1 Step 1: Fine-Tune Reranker (Lowest Risk, Highest Impact)

**Why first:** Cross-encoder reranking has the largest impact on retrieval quality. Fine-tuning it on insurance-specific query-document pairs will immediately improve answer accuracy.

**Model:** `cross-encoder/ms-marco-MiniLM-L-6-v2` → `coverwise-reranker-v1`

**Training Data:**
- (query, relevant_chunk) positive pairs from initial docs
- Hard negatives from retrieval misses

**Method:** Contrastive fine-tuning with `sentence-transformers`

**Hardware:** Single GPU (even Colab T4 works)

**Expected improvement:** 15-25% better retrieval precision

### 3.2 Step 2: Fine-Tune Embedding Model (Medium Impact)

**Why second:** Better embeddings = better retrieval = better answers. But this requires more data than reranker fine-tuning.

**Model:** `BAAI/bge-base-en-v1.5` or `sentence-transformers/all-MiniLM-L6-v2` → `coverwise-embed-v1`

**Training Data:**
- (query, chunk) pairs from insurance Q&A
- Synthetic pairs generated by GPT-4o from policy chunks
- Hard negatives from BM25 retrieval

**Method:** Contrastive learning with `MultipleNegativesRankingLoss`

**Hardware:** Single GPU

**Expected improvement:** 20-35% better retrieval recall

### 3.3 Step 3: Fine-Tune Extraction Model (High Impact for Policy Parsing)

**Why third:** Currently extraction uses GPT-5-nano via API. Fine-tuning a local model for extraction reduces cost and latency while maintaining accuracy.

**Model:** `qwen2.5:7b` (Ollama) → `coverwise-extract-v1`

**Training Data:**
- (policy_text, structured_extraction) pairs
- Ground-truth field values from initial diff documents
- Edge cases: missing fields, ambiguous text, multi-column layouts

**Method:** QLoRA (4-bit quantization + LoRA adapters)

**Hardware:** Single GPU with 16GB+ VRAM, or Apple Silicon Mac with 16GB+ RAM

**Expected improvement:** 30-40% reduction in extraction errors, 90% cost reduction

### 3.4 Step 4: Fine-Tune Q&A Model (High Impact for User Experience)

**Why last:** Requires the most data and most careful evaluation. But the payoff is highest for user experience.

**Model:** `qwen2.5:7b` → `coverwise-qa-v1`

**Training Data:**
- (context, question, answer) triples from insurance documents
- User feedback-labeled answers
- Hard negatives (wrong answers that sound plausible)

**Method:** QLoRA instruction tuning

**Hardware:** Single GPU with 16GB+ VRAM

**Expected improvement:** 25-35% better answer accuracy, reduced hallucination

---

## 4. Data Annotation Guidelines

### 4.1 Q&A Pair Annotation

**For each document chunk, generate:**

1. **Factual questions** — "What is the deductible for surgery?"
2. **Conditional questions** — "Under what conditions is dental coverage available?"
3. **Comparison questions** — "How does this policy's maternity benefit compare to standard coverage?"
4. **Negative questions** — "Is cosmetic surgery covered?" (Answer: "No, the policy excludes cosmetic treatments.")

**Quality rules:**
- Answer must be grounded in the chunk text (no external knowledge)
- If the chunk doesn't contain enough information, mark as "insufficient_context"
- Include confidence score (0.0-1.0)
- Include the exact quote from the chunk that supports the answer

### 4.2 Coverage Gap Annotation

**For each policy, label:**

1. **Present coverages** — What IS covered (with limits)
2. **Absent coverages** — What is NOT covered (standard coverages missing)
3. **Sub-limits** — Coverage with hidden restrictions
4. **Waiting periods** — Time-based restrictions
5. **Exclusions** — Explicitly excluded items

### 4.3 Extraction Annotation

**For each document field, label:**

1. **Field name** — Standardized (e.g., "coverage_amount", "premium", "deductible")
2. **Field value** — As it appears in the document
3. **Confidence** — High/Medium/Low based on clarity
4. **Location** — Page number and section

---

## 5. Evaluation Framework

### 5.1 Retrieval Evaluation

**Metric:** Hit@5, MRR@5, NDCG@5

**Dataset:** `golden_set/retrieval_eval.json` — 50+ (query, relevant_chunk_id) pairs

**Tool:** Custom evaluation script (not dependent on external frameworks)

**Frequency:** Run before every model update

### 5.2 Q&A Evaluation

**Metric:** Faithfulness, Answer Relevance, Context Precision

**Dataset:** `golden_set/qa_eval.json` — 30+ (context, question, expected_answer) triples

**Tool:** Custom evaluation with GPT-4o as judge (cost-effective)

**Frequency:** Run after every Q&A model update

### 5.3 Extraction Evaluation

**Metric:** Field-level F1, Exact Match Rate

**Dataset:** `golden_set/extraction_eval.json` — 50+ (document_text, expected_fields) pairs

**Tool:** Custom evaluation script

**Frequency:** Run after every extraction model update

---

## 6. Integration with Existing Pipeline

### 6.1 Model Registry

```python
# src/models/registry.py
MODEL_REGISTRY = {
    "reranker": {
        "v0": "cross-encoder/ms-marco-MiniLM-L-6-v2",
        "v1": "models/coverwise-reranker-v1",
    },
    "embeddings": {
        "v0": "sentence-transformers/all-MiniLM-L6-v2",
        "v1": "models/coverwise-embed-v1",
    },
    "extraction": {
        "v0": "qwen2.5:7b",
        "v1": "models/coverwise-extract-v1",
    },
    "qa": {
        "v0": "qwen2.5:7b",
        "v1": "models/coverwise-qa-v1",
    },
}
```

### 6.2 A/B Testing

When a new model version is ready:
1. Run evaluation on golden set → must pass baseline
2. Deploy to 10% of traffic → monitor confidence scores
3. If confidence improves → promote to 100%
4. If confidence drops → rollback

### 6.3 Fallback Chain

```
Fine-tuned model (v1) → Base model (v0) → API model (OpenAI)
```

Always fall back gracefully. Never block user queries on model availability.

---

## 7. Hardware Requirements

| Phase | GPU | RAM | Storage | Cost |
|-------|-----|-----|---------|------|
| **Phase 1: Reranker** | T4 (16GB) | 16GB | 10GB | ~$1/hr (Colab) |
| **Phase 2: Embeddings** | T4 (16GB) | 16GB | 20GB | ~$1/hr (Colab) |
| **Phase 3: Extraction** | A100 (40GB) | 32GB | 50GB | ~$3/hr (Colab) |
| **Phase 4: Q&A** | A100 (80GB) | 64GB | 100GB | ~$5/hr (Colab) |
| **Production inference** | CPU (Apple Silicon) | 16GB+ | 10GB | Free (local) |

**Apple Silicon Advantage:** QLoRA on M1/M2/M3 Macs with 16GB+ RAM is viable for inference and even fine-tuning smaller models.

---

## 8. Timeline

| Week | Milestone | Deliverable |
|------|-----------|-------------|
| **Week 1** | Data collection | Initial diff docs → training_data/v1_initial/ |
| **Week 2** | Reranker fine-tuning | coverwise-reranker-v1 + eval results |
| **Week 3** | Embedding fine-tuning | coverwise-embed-v1 + eval results |
| **Week 4** | Extraction fine-tuning | coverwise-extract-v1 + eval results |
| **Week 5** | Q&A fine-tuning | coverwise-qa-v1 + eval results |
| **Week 6** | Integration + A/B testing | Pipeline integration + golden set evaluation |
| **Week 7+** | Iterative improvement | Continuous training with user feedback |

---

## 9. Decision Record

| Decision | Date | Context | Chosen Path | Rationale |
|----------|------|---------|-------------|-----------|
| Create model training plan | 2026-07-16 | User requested planning for model training with initial diff docs | Comprehensive training plan with phased approach | motto_v3 §0.3 (documentation continuity), §0.15 (third-layer rule) |

---

## 10. Next Steps

1. **User provides initial diff documents** → We create `training_data/v1_initial/`
2. **Run GPT-4o synthetic generation** → Generate Q&A pairs from document chunks
3. **Fine-tune reranker** → First model improvement (Week 2)
4. **Evaluate on golden set** → Measure improvement
5. **Iterate** → Fine-tune embeddings, extraction, Q&A models

---

## 11. Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-07-16 | Initial training plan created | Buffy |
