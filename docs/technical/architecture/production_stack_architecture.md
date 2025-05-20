# OCR & RAG Production-Ready Stack

Below is a concise architecture and implementation plan you can share directly with Cursor to scaffold a development and production-ready OCR + RAG pipeline.

---

## Why move from the current setup?

* **Unreliable on-device inference**: Heavy models (PaddleOCR + LayoutLMv3) OOM on limited environments and complicate Docker resource tuning.
* **Slow iteration**: Local quantization, model-hot swapping, and debugging consume weeks.
* **Operational burden**: Self-hosting large models requires GPU provisioning, monitoring, and maintenance.
* **Scalability challenges**: Hard to autoscale on-demand when traffic spikes, leading to unpredictable performance.

**Goal**: Shift complexity into managed, scalable services and minimize heavy dependencies on developer machines or client devices.

---

## When is the current setup acceptable?

* **Low volume or prototyping**: If you process only a few documents per day and want full control, the local PaddleOCR + LayoutLMv3 pipeline can work.
* **On-premise requirements**: When data governance demands self-hosting all models without external API calls.
* **Custom fine-tuning**: If you need custom-trained models on specialized document layouts and cannot use generic endpoints.

Once you outgrow these constraints—e.g., volume spikes or maintenance headaches—you should move to the managed stack below.

---

### Architecture Overview

```text
Flutter App
    ↓ Upload PDF/Image
Your Backend (FastAPI)
 ├─1️⃣ OCR & Layout → Hugging Face Inference API
 ├─2️⃣ Text Parsing & Preprocessing (Python)
 ├─3️⃣ Embedding Generation → OpenAI Embeddings API
 ├─4️⃣ Vector Store → Qdrant (self-hosted) or Pinecone
 └─5️⃣ RAG Query Endpoint → FastAPI serves answers
```

---

### 1️⃣ OCR & Layout via Hugging Face Inference API

* **Models**:

  * Text detection & recognition: `mindee/doctr-ocr`
  * Semantic document QA: `impira/layoutlm-document-qa`

* **Sample code**:

  ```python
  from huggingface_hub import InferenceClient
  client = InferenceClient(token=HF_TOKEN)

  # OCR
  ocr = client.image_to_text(
      model="mindee/doctr-ocr",
      inputs=file_bytes # Note: The client.image_to_text often uses `data` parameter instead of `inputs`
  )

  # Layout QA
  layout_qa = client.document_question_answering(
      model="impira/layoutlm-document-qa",
      inputs={"image": file_bytes, "text": ocr["text"]} # Assuming ocr["text"] is how you get text from the above.
                                                        # The actual output from image_to_text might be just a string
                                                        # or a dict like {"generated_text": "..."}
  )
  ```

---

### 2️⃣ Parsing & Structuring

* Normalize HF responses into your JSON schema:

  ```json
  {
    "text_blocks": [ { "text": ..., "bbox": [...], "confidence": ... }, … ],
    "layout_answers": [ { "answer": ..., "box": [...], "score": ... }, … ]
  }
  ```
* Post-process: split pages, sanitize text, detect headers/footers.

---

### 3️⃣ Embedding Generation

| Model                             | Dimensions | Max Tokens | Pros                                                    | Cons                            |
| --------------------------------- | ---------: | ---------: | ------------------------------------------------------- | ------------------------------- |
| `text-embedding-3-small`          |      1 536 |      8 191 | Superior quality vs. `ada-002`, 5× cheaper, low latency | Lower nuance vs. large model    |
| `text-embedding-3-large`          |      3 072 |      8 191 | Best semantic performance on MIRACL & MTEB benchmarks   | Higher cost & storage           |
| `text-embedding-ada-002` (legacy) |      1 536 |      8 191 | Tried-and-true, compatible with older pipelines         | 25× more expensive than 3-small |
| `all-MiniLM-L6-v2` (SBERT)        |        384 |        N/A | Self-host for free, extremely fast on CPU               | Lower semantic nuance           |
| `all-mpnet-base-v2` (SBERT)       |        768 |        N/A | Strong general semantics, modest resource needs         | Larger model (\~260 MB)         |

**Recommendations:**

1. **OpenAI 3-small**: default for most RAG ingestion—best cost/quality tradeoff.
2. **OpenAI 3-large**: if peak accuracy is critical for multilingual or complex semantics.
3. **SBERT MiniLM**: for zero-cost self-hosted workloads with huge volume.
4. **Hybrid**: index bulk text with 3-small, embed queries with 3-large for reranking.

---

#### 4️⃣ Vector Store (Qdrant)

* **Latest Qdrant** (v1.14.0+): supports HNSW, payload filtering, and vector quantization for efficient on-disk storage.
* **Self-hosted** or **Qdrant Cloud**: choose managed for auto-scaling or on-premise for full control.
* **Integration**:

  ```python
  from qdrant_client import QdrantClient
  client = QdrantClient(url="http://localhost:6333") # Or QDRANT_HOST, QDRANT_PORT from env
  client.upsert(
      collection_name="docs", # Or your configured collection name
      points=[
          {
              "id": doc_id, # This should be a unique ID for the point, e.g. block ID
              "vector": embedding,
              "payload": {"text": text, "page": page, "bbox": bbox} # Or other relevant metadata
          }
      ]
  )
  ```
---

### 5️⃣ RAG Query Endpoint

* FastAPI `/query?prompt=...`:

  1. Embed user query
  2. k-NN search in vector store
  3. Build LLM prompt with retrieved passages
  4. Call OpenAI Chat Completion

---

## Cost Comparison & Final Recommendation

| Service                       | Cost per request                            |
| ----------------------------- | ------------------------------------------- |
| **HF Inference OCR**          | \$0.0000083 – \$0.0000389  (1–2 cores × 1s) |
| **GPT-4.1 (700 tokens)**      | \$0.007                                     |
| **GPT-4.1 mini (700 tokens)** | \$0.0014                                    |

* **HF OCR** is \~**100×–500× cheaper** than a GPT-4 mini chat, making it ideal for high-volume text extraction.
* **OpenAI LLM** calls are more expensive but essential for semantic QA and RAG completeness.

**Final Recommendation**: Use HF Inference for bulk OCR/layout and OpenAI APIs for embedding & conversational RAG. This blend optimizes for both cost and capability, works seamlessly in dev and scales effortlessly in production.

---

> **Next steps**:
>
> 1. Prototype HF & OpenAI calls in FastAPI
> 2. Define JSON schema & vector ingestion
> 3. Build `/process` and `/query` endpoints
> 4. Connect Flutter to these endpoints
> 5. Monitor costs, cache frequent docs, and scale vector store 