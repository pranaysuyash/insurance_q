# ADR: Solo-Founder Cost-Optimized Deployment Architecture

**Date:** 2026-07-11
**Status:** Decided + Implemented
**Context:** CoverWise was architected as a company demo/product (GTM) that
didn't launch. Now re-launching as a solo founder under a personal brand.
Cost minimization is the primary constraint while maintaining the core value
(upload insurance policies, ask questions, get grounded answers).

## Decision

Strip the production deployment to the minimum viable architecture: API-first,
no bundled ML models, no managed Redis, smallest viable App Runner instance.

## Cost comparison

| Component | Before (~$55-60/mo) | After (~$12-15/mo) | Change |
|---|---|---|---|
| App Runner | 1 vCPU / 2 GB always-on (~$35) | 0.5 vCPU / 1 GB (~$18) | −48% |
| ElastiCache Redis | cache.t2.micro (~$15) | **Dropped** ($0) | −100% |
| ECR | No lifecycle, growing (~$3+) | Keep last 5 (~$1.50) | −50% |
| Qdrant Cloud | Free tier ($0) | Free tier ($0) | — |
| OpenAI | ~$0.0002/query (<$5) | Same (<$5) | — |
| **Total** | **~$55-60/mo** | **~$12-15/mo** | **~75% reduction** |

## What changed and why

### 1. Production image slimmed from ~3 GB to ~400 MB
**Decision:** Remove torch, python-doctr, sentence-transformers, celery/kombu
from `requirements.txt` (production). Keep them in `requirements-local.txt`
for local development.

**Rationale:** These packages exist for local OCR fallback and local embedding
fallback. In production, the app uses OpenAI for embeddings/chat. Bundling
~2.5 GB of ML libraries to handle an edge case (OpenAI goes down) forces a
2 GB instance at $35/mo. The graceful degradation already exists in the code —
when these libraries aren't importable, the pipeline falls back to OpenAI-only
with clear error messages. The cost of a bigger image + always-on instance far
exceeds the value of the fallback at 10-100 users.

**OCR handling:** Direct-text PDFs (the majority of Indian insurance policies)
are extracted via PyMuPDF (tiny, always installed). Scanned/image-only PDFs
get a clear message: "This PDF appears to be scanned. OCR is not available.
Please upload a digital/text-based PDF." The architecture is pluggable —
when volume justifies it, a cloud OCR API (Google Vision / AWS Textract) can
be added as one function. This is the first coherent stage, not a dead end.

### 2. Redis dropped from production
**Decision:** Remove Redis from the deploy config. Both consumers (RAG query
cache, rate-limiting) have in-memory fallbacks that work correctly.

**Rationale:** At 10-100 users, in-memory rate limiting and no query cache is
fine. The Redis instance ($15/mo) was the second-highest cost after App Runner,
and its absence doesn't break any feature — it only makes queries slightly
slower (no cache) and rate limits ephemeral (reset on restart). When traffic
grows, Redis can be re-added.

### 3. OpenAI model config aligned
**Decision:** Use `gpt-4o-mini` (chat) + `text-embedding-3-small` (embeddings).

**Rationale:** The deploy scripts were hardcoded to `gpt-3.5-turbo` +
`text-embedding-ada-002` (older, pricier). `.env` used `gpt-5-nano`. Now both
deploy configs use `gpt-4o-mini` — current, cheap ($0.15/$0.60 per M tokens),
and widely available. `text-embedding-3-small` is the cheapest OpenAI embedding
model at $0.02/M tokens. At ~10K queries/month, total OpenAI cost is ~$2-3.

### 4. ECR lifecycle policy
**Decision:** Keep last 5 images, expire the rest.

**Rationale:** Without this, every deploy adds ~400 MB to ECR indefinitely.
After a year of weekly deploys that's ~20 GB ($2/mo) for nothing. The lifecycle
policy caps storage at ~2 GB ($0.20/mo).

## Verification
- `requirements.txt` (production): no torch/doctr/sentence-transformers/celery
- `requirements-local.txt` (dev): extends production with all heavy deps
- `Dockerfile` (local dev): uses `requirements-local.txt`
- `deploy_aws_multiarch.sh` Dockerfile.aws (production): slim, uses `requirements.txt`
- OCR degrades gracefully (62/62 tests pass)
- Deploy script: no Redis, correct models, lifecycle policy, 0.5 vCPU / 1 GB

## What remains (future, not blocking solo launch)
- **Cloud OCR API** when scanned-PDF volume justifies it
- **S3** for persistent document storage (currently ephemeral — acceptable for
  beta, must fix before relying on uploaded data surviving redeploys)
- **Auth model** decision (currently rate-limit-only)
- **Scale-to-zero** on App Runner (requires the app to cold-start fast enough;
  slim image helps but startup still loads from Qdrant + OpenAI health probe)

## Rollback path
If production needs OCR or Redis back:
- OCR: `pip install -r requirements-local.txt` in Dockerfile.aws + redeploy
- Redis: add `REDIS_HOST`/`REDIS_PORT` env vars back to deploy config + redeploy
Both are additive changes with no code modifications needed.
