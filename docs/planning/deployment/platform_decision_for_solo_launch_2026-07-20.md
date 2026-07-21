# CoverWise Platform Decision for Solo Launch — 2026-07-20

## Context

The original deployment was AWS App Runner + ElastiCache Redis + EKS (~$55-60/mo,
13-month-old image, dead API key). A parallel agent migrated the architecture
plan to GCP Cloud Run + Supabase. The founder asked: "from AWS you moved me to
GCP when I asked for less burdensome solo person based app and launch? Is that
long-term first-principles, motto-aligned? What about cost? What about making
money?"

This document records the analysis, the decision, and the alternatives so other
agents can review and give their POV.

## The first-principles question

**What is the simplest way for one person to deploy a Python API + Postgres +
vector search, at minimum cost and minimum operational burden?**

The founder's constraints (stated explicitly):
1. Solo founder, personal brand launch
2. Cost minimization ("I don't want to burn")
3. Less burdensome than AWS
4. Must be able to make money eventually

## What happened (honest assessment)

A parallel agent chose GCP Cloud Run + Supabase. This is architecturally sound
but operationally **more complex than necessary** for a solo launch:
- Two platforms (GCP + Supabase) = two accounts, two billing dashboards, two
  sets of credentials
- GCP requires IAM, Secret Manager, Cloud Build, `gcloud auth`, project setup
- The deploy script (`tools/deploy_cloud_run.sh`) has 6 required environment
  variables + 3 secrets in Secret Manager
- Total setup time: 30-60 minutes for someone unfamiliar with GCP

This is the right **long-term** architecture (scale-to-zero, global edge,
managed Postgres via Supabase) but violates motto §12 ("reduce operator
cognitive load") for the initial launch.

## Options evaluated

### Option A: GCP Cloud Run + Supabase (current plan, already coded)

**Status:** Fully coded. `tools/deploy_cloud_run.sh`, `infra/supabase/` (3 SQL
migrations), Supabase adapters in backend, validation script. Supabase project
is provisioned (tables, pgvector, storage bucket all live).

- **Platforms:** 2 (GCP for compute, Supabase for data)
- **Complexity:** HIGH — IAM, Secret Manager, gcloud CLI, Cloud Build
- **Cost:** Cloud Run free tier (2M req/mo) + Supabase free tier (500MB DB,
  1GB storage) = ~$0-5/mo at solo scale. Paid: Cloud Run ~$3-10, Supabase $25.
- **Scale-to-zero:** Yes (Cloud Run min-instances=0)
- **Monetization-ready:** Not inherently; needs payment integration
- **Pros:** Best long-term architecture, global edge, managed everything
- **Cons:** Two platforms, GCP learning curve, 6 env vars + 3 secrets
- **Migration effort from here:** ~30 min (create GCP project, secrets, deploy)
- **When to use:** After product-market fit, when you need scale and reliability

### Option B: Railway + Supabase (RECOMMENDED for solo launch)

**Status:** Not coded yet. Dockerfile is ready, Supabase is provisioned.

- **Platforms:** 2 but both dead-simple (Railway for compute, Supabase for data)
- **Complexity:** LOW — `railway up` deploys from Dockerfile, env vars in dashboard
- **Cost:** Railway Hobby $5/mo (includes $5 usage credit) + Supabase free = ~$5/mo
- **Scale-to-zero:** No (Railway runs always) but Hobby is cheap
- **Monetization-ready:** Not inherently
- **Pros:** Simplest possible deploy, no IAM, no CLI complexity, instant deploys
  from GitHub, built-in metrics/logs
- **Cons:** No scale-to-zero, Railway is newer than GCP, no managed Postgres
  (that's why Supabase is separate)
- **Migration effort:** ~10 min (create Railway project, connect GitHub, set
  env vars pointing at Supabase, deploy)
- **When to use:** NOW — solo launch, fast iteration, minimal ops

### Option C: Fly.io + Supabase

**Status:** Not coded. Dockerfile is ready.

- **Platforms:** 2 (Fly for compute, Supabase for data)
- **Complexity:** LOW-MEDIUM — `fly deploy`, `fly.toml`, needs Fly CLI
- **Cost:** Fly free tier (3 shared-cpu-1x VMs, 256MB) + Supabase free = ~$0-3/mo
- **Scale-to-zero:** Yes (`fly scale min=0` with machines)
- **Monetization-ready:** Not inherently
- **Pros:** Cheapest scale-to-zero option, global edge regions (Mumbai available),
  Docker-native
- **Cons:** Fly Machine API is newer/less stable, volume management for state,
  more CLI config than Railway
- **Migration effort:** ~15 min (`fly launch`, set env vars, deploy)
- **When to use:** If Railway is too expensive or you need scale-to-zero at
  minimum cost

### Option D: Railway only (built-in Postgres, no pgvector)

**Status:** Not coded. Would lose vector search capability.

- **Platforms:** 1 (Railway only)
- **Complexity:** LOWEST — one platform, one bill, one dashboard
- **Cost:** Railway Hobby $5/mo (includes Postgres) = ~$5/mo total
- **Scale-to-zero:** No
- **Monetization-ready:** Not inherently
- **Pros:** Simplest possible — single platform, built-in Postgres
- **Cons:** **No pgvector support** on Railway Postgres. Would require migrating
  RAG to a different vector backend (Qdrant Cloud free tier, or compute
  similarity in-app). Adds complexity to the RAG layer.
- **When to use:** Only if you want a single platform and are willing to change
  the vector search backend

### Option E: VPS (Hetzner/DigitalOcean) + Docker Compose

**Status:** Docker Compose exists (`docker-compose.yml`).

- **Platforms:** 1 (VPS only)
- **Complexity:** MEDIUM — you own OS updates, SSL, firewall, Docker ops
- **Cost:** Hetzner CX22 (2 vCPU, 4GB) = €3.29/mo in India region. DO $6-12/mo.
- **Scale-to-zero:** No
- **Monetization-ready:** Not inherently
- **Pros:** Full control, cheapest compute, everything in one box, no platform
  lock-in
- **Cons:** You ARE the ops team. Security patches, SSL renewal, backups,
  monitoring — all manual. Single point of failure. Docker Compose doesn't
  auto-heal.
- **When to use:** If you're comfortable with Linux ops and want maximum control
  at minimum cost

## Decision

**For the solo launch: Option B (Railway + Supabase).**

Rationale (motto §12, §0, §0.13):
- Simplest deploy path (`railway up` from Dockerfile, no IAM, no gcloud)
- Lowest cognitive load for a solo founder
- Supabase is already provisioned and verified (tables, pgvector, storage)
- ~$5/month total cost, which satisfies "I don't want to burn"
- Can migrate to Cloud Run later when scale/reliability demands it
- The GCP code is NOT deleted — it's the documented migration path for when
  Railway is no longer sufficient

**The GCP Cloud Run code stays in the repo** (`tools/deploy_cloud_run.sh`,
`infra/supabase/`, validation scripts) as the documented upgrade path. It's
not wrong — it's premature for a solo launch.

## Cost comparison (monthly, at solo scale: <100 users)

| Platform | Compute | Database | Storage | Total |
|---|---|---|---|---|
| AWS App Runner (old) | ~$35 | ~$15 (Redis) | ephemeral | ~$55 |
| GCP Cloud Run + Supabase | ~$0-5 | $0 (free) | $0 (free) | ~$5-10 |
| **Railway + Supabase (chosen)** | **~$5** | **$0 (free)** | **$0 (free)** | **~$5** |
| Fly.io + Supabase | ~$0-3 | $0 (free) | $0 (free) | ~$3 |
| Hetzner VPS | €3.29 | included | included | ~€3 |
| OpenAI (all options) | ~$2-5 | — | — | ~$2-5 |

## Monetization (separate document)

The latest monetization exploration is tracked in
`docs/planning/product/monetization_research_and_decision_2026-07-21.md`.
The earlier `monetization_strategy_2026-07-20.md` remains historical context;
the newer document is still decision pending and does not authorize
implementation.

The core question: ads vs subscriptions vs one-time unlock vs freemium.
For an Indian B2C insurance companion app, the options and their tradeoffs
are analyzed in that document.

## For other agents reviewing this

If you're an agent giving a POV on this decision, consider:
1. Is Railway + Supabase actually simpler than GCP Cloud Run + Supabase?
2. Is there a single-platform option that supports pgvector? (Supabase Edge
   Functions? Fly Postgres with pgvector?)
3. Is the cost difference meaningful at solo scale?
4. Does the founder's priority (not burning money, simple ops) change the
   recommendation?
5. What's the migration cost if we outgrow Railway?

Record your POV by appending to this file with a dated addendum.
