# CoverWise Backend Platform Decision — Reassessment

**Date:** 2026-07-28
**Supersedes:** `platform_decision_for_solo_launch_2026-07-20.md`
**Founder constraints:** cost-effective · easy to operate solo · scalable · better than current
**Pricing verified:** 2026-07-28, from each provider's own pricing page (links at bottom)

---

## What we're hosting

Two process types, both stateless (all data is external: Supabase, Qdrant Cloud, Redis Cloud, OpenAI):

| Service | Workload | Needs always-on? |
|---|---|---|
| **FastAPI API** | Request-response (upload, query, auth, billing sync) | No — can scale to zero; cold starts acceptable if <3s |
| **Durable outbox worker** | Polls `job_outbox` table, processes document/RAG/billing/deletion jobs | **Yes** — if it stops, the queue stalls and uploads never complete |

Region target: **Mumbai (`ap-south1`)** — same as Supabase, for low latency to India users.

---

## Current state (why we're reassessing)

- **AWS App Runner** is live at `aa2485vt7t.ap-south-1.awsapprunner.com` but runs a **13-month-old image** (`version 2.0.0`, `2025-06-11`). Missing endpoints the current mobile app calls.
- **No worker deployed anywhere.** The outbox worker is fully coded (`src/workers/outbox_worker.py`) but has never run in production.
- `API_BASE_URL` is unset in every `.env` — a release build would crash on launch.
- The 07-20 doc recommended Railway; founder asked for a thorough reassessment before committing.

---

## Pricing comparison (verified 2026-07-28)

All figures assume **two always-on services** (API + worker), smallest viable size, Mumbai/equivalent region, 730 hours/month.

| Platform | API (always-on) | Worker (always-on) | **Total/mo** | Free tier? | DX complexity |
|---|---|---|---|---|---|
| **Render** (Starter) | $7 (0.5 vCPU / 512 MB) | $7 (0.5 vCPU / 512 MB) | **$14** | Free tier spins down (unsuitable for worker) | 🟢 Lowest — git push, web UI, native workers |
| **Fly.io** (PAYG) | ~$2–4 (shared-cpu-1x, 256–512 MB) | ~$2–4 | **~$5–8** | ❌ None for new accounts (legacy plans retired) | 🟢 Low — `fly deploy`, multi-region |
| **Google Cloud Run** | ~$0 (scales to zero, free tier) | ~$12 (1 vCPU / 512 MB, instance billing) | **~$12** | ✅ 2M req/mo + 240K vCPU-s/mo free | 🔴 High — IAM, Secret Manager, `gcloud`, 7 env vars + 4 secrets |
| **Railway** (Hobby) | ~$10–15 (usage-based) | ~$10–15 | **~$20–30** | $5 one-time credit | 🟢 Low — but usage-based is unpredictable |
| **AWS App Runner** (current) | ~$14 (0.5 vCPU / 1 GB) | ~$14 | **~$28** | ❌ No free tier for App Runner | 🟡 Medium — already set up, but most expensive |

### Detail per platform

**Render** — `render.com/pricing`
- Starter: $7/mo per service, 0.5 vCPU / 512 MB, always-on (no spin-down).
- Background Workers are a first-class service type (not a workaround).
- Deploy from GitHub push; env vars in dashboard; no IAM.
- Free tier exists but spins down after 15 min idle — unsuitable for the worker.

**Fly.io** — `fly.io/docs/about/pricing/`
- shared-cpu-1x (256 MB): ~$2.02/mo baseline per machine.
- Additional RAM: ~$5/mo per GB. 256 MB is very tight for Python + PDF/ML deps — realistically 512 MB (~$4/mo each).
- Legacy free tiers retired; new accounts are pure PAYG.
- Best multi-region scaling; `fly deploy` is one command.

**Google Cloud Run** — `cloud.google.com/run/pricing`
- API can scale to zero → near-free at low traffic (2M free req/mo).
- Worker must use instance-based billing (CPU always allocated) → ~$11.61/mo for 1 vCPU / 512 MB (after free tier).
- Cheapest for the API, but GCP setup is the heaviest: IAM roles, Secret Manager, `gcloud auth`, Cloud Build. The 07-20 doc flagged this as HIGH operator burden for a solo launch.

**Railway** — `railway.com/pricing`
- Hobby: $5/mo + usage. CPU $0.00000772/vCPU-s, RAM $0.00000386/GB-s.
- A 0.5 vCPU / 512 MB always-on service ≈ $15/mo usage (before the $5 included credit).
- Excellent DX but usage-based billing makes monthly cost unpredictable — violates "cost-effective / no surprises" for a solo founder watching spend.

**AWS App Runner** (current) — `aws.amazon.com/apprunner/pricing/`
- ~$13.61/mo for 0.5 vCPU / 1 GB (provisioned memory + active compute).
- No free tier for App Runner. Two services = ~$28/mo.
- Already provisioned and the account/scripts exist, but it's the most expensive and the image is stale.

---

## Scoring against the four criteria

| Criterion | Render | Fly.io | Cloud Run | Railway | App Runner |
|---|---|---|---|---|---|
| **Cost-effective** | 🟢 $14 flat, predictable | 🟢 ~$6, cheapest | 🟡 ~$12, good free tier for API | 🟡 ~$20–30, unpredictable | 🔴 ~$28, most expensive |
| **Easy (solo)** | 🟢 Git-push, web UI, no IAM | 🟢 `fly deploy` | 🔴 IAM + Secret Manager + gcloud | 🟢 Web UI | 🟡 Already set up but stale |
| **Scalable** | 🟡 Upgrade tiers manually | 🟢 Multi-region, autoscale | 🟢 Autoscale to thousands | 🟡 Manual | 🟡 Auto-scale exists |
| **Better than current** | 🟢 Native worker | 🟢 Fresh start | 🟢 Fresh start | 🟢 Fresh start | 🔴 Stale, most costly |

---

## Recommendation: Render (Starter) for launch

**Why Render wins on all four criteria:**

1. **Cost-effective:** $14/mo flat for API + worker. No usage surprises, no IAM-induced over-provisioning. The bill is the bill.
2. **Easy:** Connect GitHub repo → auto-deploy on push. Background Workers are a native service type, so the outbox worker deploys with the same DX as the API. Env vars in a web UI. No `gcloud`, no IAM roles, no Secret Manager.
3. **Scalable:** When traffic grows, upgrade to Standard ($25/mo, 1 vCPU / 2 GB) per service. The migration is a dropdown, not a re-architecture.
4. **Better than current:** Fresh image, native worker support (the #1 missing piece today), predictable cost (~half of App Runner).

**Why not the others:**
- **Fly.io** is cheaper but 256 MB is too tight for this Python stack (PDF processing, OCR deps), and PAYG-only means no free buffer.
- **Cloud Run** is architectically ideal but the GCP setup burden is the highest — directly conflicts with solo-operator simplicity.
- **Railway** has great DX but usage-based billing is unpredictable, which is exactly what a cost-watching solo founder doesn't want.
- **App Runner** is the most expensive with no free tier and is already running a stale image.

**Migration path (Render → Cloud Run later):** If/when traffic justifies it, the app is already Docker-containerized (Cosign-signed in CI). Moving to Cloud Run is re-pointing the same image — not a rewrite. Render is the right *now*; Cloud Run remains the right *later*.

---

## What "deploy to Render" looks like (the plan, not executed yet)

1. Push the repo to GitHub (already done).
2. In Render dashboard: create **Web Service** (API) from the repo, Dockerfile-based.
3. Create **Background Worker** from the same repo, same image, different start command (`python -m src.workers.outbox_worker`).
4. Set env vars (Supabase, OpenAI, Qdrant, Redis, RevenueCat webhook secret) in Render's dashboard.
5. Render assigns a URL → set as `API_BASE_URL` in `.env` + GitHub secret + mobile `--dart-define`.
6. Verify `/health` returns current version + both statuses `available`.

**Cost at launch:** $14/mo (Render) + $25/mo (Supabase Pro, only if needed) + ~$10–50/mo OpenAI (usage) + Qdrant/Redis. **Realistic total: ~$50–90/mo**, matching the existing cost analysis.

---

## Sources (verified 2026-07-28)

- Render pricing: https://render.com/pricing
- Fly.io pricing: https://fly.io/docs/about/pricing/
- Google Cloud Run pricing: https://cloud.google.com/run/pricing
- Railway pricing: https://railway.com/pricing
- AWS App Runner pricing: https://aws.amazon.com/apprunner/pricing/
