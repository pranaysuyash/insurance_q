# CoverWise Deployment Decision

**Date:** 2026-07-12  
**Status:** superseded by [`coverwise_long_term_platform_decision_2026-07-12.md`](coverwise_long_term_platform_decision_2026-07-12.md); retained as the initial platform comparison  
**Decision owner:** Pranay

## Decision

The initial recommendation was to deploy the first solo-product release to **Railway Hobby** as one project, using the existing containerized services:

- `frontend` as the public service.
- `ocr_service` as a private service.
- `rag_service` as a private service.
- Redis-compatible storage as a private persistent service.
- Qdrant as a private persistent service.

Use Railway's private networking and service variables for internal URLs. Put the custom domain and HTTPS at the public frontend service. Keep OpenAI/Hugging Face as external model/API dependencies; do not run a GPU or model server for the launch.

## Why this is the right solo default

- It accepts Docker and GitHub deployment without introducing AWS accounts, ECR, App Runner, VPCs, IAM policies, load balancers, or Kubernetes.
- Railway's Hobby plan is currently $5/month and that subscription counts toward resource usage; usage above the included amount is billed separately. The platform documents GitHub/Docker deployment, service variables, health checks, private networking, and volumes on the same product surface.
- The current Compose architecture can remain recognizable while we launch, instead of forcing a risky rewrite before customer evidence exists.
- Scaling can be done service-by-service later if OCR or RAG becomes the bottleneck.

Railway pricing is usage-based, so $5/month is a floor, not a guaranteed total. The first cost-control target is a low double-digit monthly budget, with hard alerts and no unbounded replicas.

## Why not the alternatives now

### AWS

Not justified for this stage. It adds operational and billing surface area before the product has validated demand.

### Render

Easy to use, but the current multi-service shape is less cost-efficient for this app. Render's current paid web service tier starts at $7/month per service, and its managed Redis-compatible Key Value service starts at $10/month. The free tier also has ephemeral filesystem behavior and is not a safe home for durable document/vector state.

### Fly.io

Cheap compute is possible, but it exposes more VM, volume, region, and billing decisions than we need for a solo launch. It is a good later option if we need more control and are willing to own more operations.

### A single VPS

Potentially cheapest, but it transfers patching, backups, firewalling, monitoring, recovery, and deployment responsibility to us. It is not the easiest first launch unless monthly cost becomes more important than operator time.

## Cost guardrails

- Railway Hobby only; do not upgrade to Pro without a deliberate decision.
- One replica per service.
- No autoscaling for launch.
- Set a monthly spending alert and review usage weekly.
- Start with the smallest memory allocation that passes a real upload-to-answer flow.
- Use persistent volumes only for state that must survive redeploys.
- Do not store original customer documents permanently until retention and deletion behavior are explicitly implemented and documented.
- Keep test/staging resources stopped or removed when not in use.
- Keep model calls bounded by file size, page count, query length, timeout, and retry policy.

## Required deployment hardening before provisioning

- Create a production Compose/Railway configuration without `--reload`.
- Make the public frontend's health endpoint explicit.
- Configure internal service URLs through Railway variables, not localhost or Compose-only hostnames.
- Confirm Qdrant and Redis persistence and backup behavior.
- Confirm the deployed OCR path supports the file types advertised in the website and Play Store copy.
- Add startup validation for required secrets without logging secret values.
- Set `PUBLIC_SITE_URL` to the final HTTPS origin.
- Add error and usage monitoring before inviting real users.
- Verify deletion/retention behavior before accepting sensitive documents.

## Addendum (2026-07-24)

The canonical API now rejects unconfigured Host headers in production. Set
`ALLOWED_HOSTS` to the comma-separated public API and direct health-check DNS
hostnames, without a scheme or path. This is separate from browser
`ALLOWED_ORIGINS` and the public frontend `PUBLIC_SITE_URL`.

## Deployment shape

```text
Custom domain
     |
Railway public frontend
     |
     +--> private OCR service ----> Redis volume/service
     |
     +--> private RAG service ----> Qdrant volume/service
                               \
                                OpenAI/Hugging Face APIs
```

## Revisit triggers

Reconsider the platform only when one of these becomes true:

- Monthly Railway usage is materially above the solo budget for two consecutive months.
- Persistent storage or backup requirements exceed the chosen volume setup.
- We need regional latency, dedicated compute, or a formal availability target.
- Data residency, compliance, or enterprise procurement requires a different hosting model.
- A single-service deployment becomes practical after the pipeline is simplified.

## Approval boundary

This document chooses the platform direction but does not create an account, add a card, provision infrastructure, or deploy production. Those are external state changes and require the owner's explicit go-ahead.

## Alternative evaluation: Firebase and other one-service paths

### Firebase / Google Cloud

Firebase can cover more of the product than just hosting:

- Firebase Hosting can serve the marketing site and route requests to Cloud Run.
- Cloud Run can run the Python/FastAPI container and scales to zero or out with demand.
- Firestore supports K-nearest-neighbor vector search, so it could replace Qdrant after a deliberate data-layer migration.
- Cloud Storage could replace local document files.
- Firebase Authentication, App Check, Analytics, Crashlytics, and Remote Config are available if those product needs become real.

However, Firebase App Hosting itself is not the direct fit for this repository: its preconfigured framework support is Next.js and Angular. The Python path is Firebase Hosting paired with Cloud Run, which is still Google Cloud infrastructure and requires a Blaze billing account. This is not simpler than Railway for the current Compose architecture.

Firebase becomes the stronger long-term option if we are willing to make this staged refactor:

1. Move the public FastAPI service to Cloud Run.
2. Replace Redis cache/rate-limit dependencies with a managed or in-process alternative.
3. Replace Qdrant persistence with Firestore vector indexes or another intentionally selected vector store.
4. Move document storage to Cloud Storage with explicit retention/deletion behavior.
5. Add Firebase Auth only when accounts and cross-device history are part of the product.

Do not choose Firebase merely because it offers more products. More products do not mean fewer operational decisions.

### Other options

| Option | Cost shape | Ease now | Scale path | Decision |
|---|---|---:|---:|---|
| Railway Hobby | $5 minimum plus usage; current services can remain | High | Good service-by-service scaling | Recommended now |
| Firebase + Cloud Run + Firestore | Pay per use with no-cost quotas; requires Blaze billing and refactor | Medium-low now | Very good | Revisit after product/data simplification |
| Render | Simple deploys; multiple paid services and managed Redis add up | Medium | Good | More expensive for current shape |
| Single VPS | Lowest steady compute cost | Low operationally | Manual scaling | Only if cost dominates operator time |
| Fly.io | Usage-based compute and volumes | Medium-low | Good but more infrastructure control | Not the easiest launch |

The principle is: launch on Railway without blocking a future Firebase migration, but do not pay the migration cost before users prove that Firebase's integrated auth, analytics, storage, and vector search are needed.

## Addendum: 2026-07-12 first-principles revision

After reviewing the goal as a long-term solo product rather than a minimal deployment of the current repository, this Railway recommendation is superseded. The Firestore direction was then evaluated against `pgvector`; the canonical direction is now one Cloud Run application service with Supabase Postgres/pgvector and Supabase Storage, documented in [`coverwise_long_term_platform_decision_2026-07-12.md`](coverwise_long_term_platform_decision_2026-07-12.md). The Firestore proposal remains preserved in [`coverwise_platform_architecture_decision_2026-07-12.md`](coverwise_platform_architecture_decision_2026-07-12.md).

Railway remains a useful temporary fallback for a demo or migration rehearsal, but it is no longer the target production architecture because it preserves the current Redis/Qdrant/service split and creates a second platform move later.
