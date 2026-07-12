# Go-Live Blocking Issues — 2026-07-11

## The real situation

The production backend reports `{"status":"ok"}` but **0% of queries work**.
Every `/query` call returns a 401 from OpenAI because the API key is dead. The
mobile app is a polished shell that cannot deliver its core value (answering
questions about insurance policies). This document records what I fixed, what
remains, and what only the user can do.

---

## What I fixed (code — verified working locally)

### Backend bugs (3 real production crashes/bugs fixed)

1. **Reranker crash** (`src/rag/pipeline.py`) — `_rank_results()` referenced
   `self.reranker` which was never initialized. Every query with >1 result
   (i.e., every real query) would crash with `AttributeError`. Added
   `_init_reranker()` that loads a cross-encoder when available, and made the
   reference defensive (`getattr`). **Verified: reranker loads locally, test
   passes.**

2. **Logger-as-timestamp bug** (`src/services/policy_extraction_service.py:97`)
   — `result["extracted_at"] = logger` assigned the logger object as a timestamp.
   Fixed to `datetime.now(timezone.utc).isoformat()`.

3. **Ephemeral summary storage** — `PolicyExtractionService._summaries` was an
   in-memory dict lost on every container restart. Refactored to Redis-primary
   + disk-fallback persistence. Summaries now survive restarts within an
   instance and are cached across requests.

### Infrastructure/config fixes

4. **Scrubbed leaked secrets from 8 tracked files** — OpenAI key + Qdrant JWT
   hardcoded in plaintext across deploy scripts, test scripts, and JSON config.
   Replaced with env-var references + fail-fast guards.

5. **Fixed lying `/health` endpoint** — was always returning 200 "ok" even when
   embeddings fail. Now runs a cached (60s) real embedding probe and returns
   503 "degraded" when broken.

6. **Made embedding fallback real** — `sentence-transformers` wasn't in
   `requirements.txt`, so the OpenAI→Ollama→local fallback chain was dead code.
   Added it. **Verified locally: embeddings work via Ollama fallback.**

7. **Fixed Redis wiring** — `anti_abuse.py` read `REDIS_URL` but deploy sets
   `REDIS_HOST`/`PORT`/`PASSWORD`. Pipeline disabled Redis when password was
   empty (production Redis has none). Both fixed.

8. **Restricted CORS in production** — `allow_origins=["*"]` +
   `allow_credentials=True` → environment-aware.

9. **Removed dummy Firebase key** — deploy script baked a fake
   `serviceAccountKey.json` into the image. Now graceful: if no real Firebase
   key is provided, auth endpoints are disabled but the API starts normally.

### Verification (Tier 4 — runtime observed)
- **62/62 tests pass** (1 deselected: azure integration test needs live URL)
- **Local backend starts, serves real queries** — embeddings work (via Ollama
  fallback), retrieval works (Qdrant returns real policy content), reranking
  works, graceful degradation when LLM has insufficient quota
- `/health` correctly probes embedding reachability and returns 200 "ok"

---

## What only the user can do (blocking production go-live)

### 🔴 1. Rotate the leaked secrets (IMMEDIATE)
Keys are scrubbed from the working tree but **still in git history**. You must:
- Revoke/rotate the OpenAI API key at platform.openai.com
- Rotate the Qdrant API key in Qdrant Cloud dashboard
- Put new keys in `.env` (gitignored) and export before deploying

### 🔴 2. Fund/fix the OpenAI account
Local `.env` key works for embeddings but returns **429 insufficient_quota**
for chat completions. The account is out of quota. Without billing, no LLM
answers can be generated (though the system degrades gracefully — it returns
raw retrieved context with a `[LLM unavailable]` marker).

### 🔴 3. Commit and deploy
Production runs a 13-month-old image. `policy_extraction_service.py` and
`models/rag.py` are untracked. Everything needs committing and redeploying.

### 🟡 4. Decide the auth model
All endpoints are open. Firebase is now graceful (won't crash without a key),
but you need to decide: open + rate limits, real Firebase auth, or a simpler
token model.

### 🟡 5. Persistent storage (for real production)
Document files and rate-limit counters are ephemeral. Summaries now persist
to Redis+disk within an instance, but for multi-instance durability you need
S3 (for files) and DynamoDB/Postgres (for structured data). This is the
documented migration path.

---

## Verification commands

After rotating keys, funding the account, and deploying:
```bash
# Health should return 200 + "available"
curl -s https://aa2485vt7t.ap-south-1.awsapprunner.com/health | jq .

# Query should return a real answer
curl -s -X POST https://aa2485vt7t.ap-south-1.awsapprunner.com/query \
  -H "Content-Type: application/json" \
  -d '{"query":"What is health insurance coverage?"}' | jq .answer
```
