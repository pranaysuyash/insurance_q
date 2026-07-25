# CoverWise Launch Playbook — Solo Founder

> **Current-state addendum (2026-07-21):** This dated playbook preserves its
> historical eight-migration launch snapshot. The executable source of truth
> is now the complete ordered chain under `supabase/migrations/` (33 files as
> of this review), including retrieval contracts, identity/lifecycle,
> artifact, audit, lineage, processing-event, policy-summary, FTS-contract,
> billing, and analytics-idempotency migrations. Before any deployment, run a
> fresh reset/history check and apply the complete chain;
> do not infer current readiness from the historical migration count below.
>
> The current data-lifecycle maintenance command is
> `venv/bin/python tools/run_data_retention.py`; schedule it outside API
> startup after staging proves analytics purge, artifact fencing, object
> deletion, and retry behavior.
>
> For the current 33-migration chain, link the project and run
> `supabase db push --dry-run --linked` followed by
> `supabase db push --linked --yes`; then run
> `venv/bin/python tools/verify_supabase_schema.py`. Do not treat the REST
> table probe alone as proof that migrations are applied.

**Date:** 2026-07-18 (revision 2 — refreshes the 2026-07-18 original to match the
current repo state after the Phase 0 commit `fa02854`.)

**Supabase project:** `https://eyumuxwabmsymytjbxoj.supabase.co`
**Status at last review:** Supabase project created, **8 SQL migrations
pending apply** (3 base + 2 RevOps/analytics + 1 evidence substrate
+ 1 job outbox + 1 consent ledger). Cloud Run service: not yet
deployed. APK: not yet built for the post-Phase-0 code.

This is the exact step-by-step to go from where the repo is now to a live app.
Every step has a **Verify** sub-step that you can run to confirm it actually
worked — no "trust me" steps. If a Verify sub-step fails, the deploy chain
is broken; stop and fix before proceeding.

> **Reading order:** read this entire file before starting. The order is
> load-bearing (Supabase apply → secrets → deploy → verify → APK).
> Re-arranging steps will produce a half-broken system.

**For a system-level overview** (what the components are, what the async paths are, what the trust boundary is), read [`docs/architecture/coverwise_canonical_architecture.md`](../../architecture/coverwise_canonical_architecture.md) first. It is the canonical map of the system. This playbook is the operational plan to go live; the canonical doc is the reference for what you are deploying.

---

## Step 1: Apply SQL migrations to Supabase (~10 minutes)

The migrations are in two folders with a strict apply order. The base
schema must be applied first; the RevOps/analytics migrations depend on
`pgvector` and the `storage` schema being available.

**Apply via Supabase dashboard → SQL Editor.** For each file in order:

1. **`infra/supabase/001_coverwise_schema.sql`** (141 lines) — base
   schema. Creates: `documents`, `document_chunks` (pgvector 1536d),
   `match_document_chunks` RPC, `coverwise-documents` storage bucket
   (private), `coverwise_thumbnails` bucket (private).
2. **`infra/supabase/002_document_processing_leases.sql`** (54 lines) —
   processing lease functions. Required by `derive_document_state()` in
   `src/services/document_processing_service.py`.
3. **`infra/supabase/003_rate_limit_windows.sql`** (61 lines) — rate
   limit RPCs. Required by `src/api/document.py`.
4. **`supabase/migrations/2026_07_18_analytics_supabase.sql`** (146 lines)
   — RevOps R1.2. Creates: `analytics_events` table, 3 dashboard views
   (`v_daily_active_users`, `v_conversion_funnel`, `v_cohort_retention`).
   Required for the analytics dual-write in `src/api/analytics.py` when
   `DUAL_WRITE_ANALYTICS=true`.
5. **`supabase/migrations/2026_07_18_revops_tables.sql`** (318 lines) —
   RevOps R1.1. Creates: `profiles` (with `role` column), 9 RevOps
   tables (`user_lifecycle`, `subscriptions`, `webhook_audit_log`,
   `processed_webhook_events`, `failed_subscription_writes`,
   `routing_decisions`, `eval_set_candidates`, `deal_decisions`,
   `events_unrouted`) and their RLS policies. Self-contained
   (`create table if not exists public.profiles` is at line 295; no
   external dependency on a pre-existing `profiles`).
6. **`supabase/migrations/2026_07_18_evidence_substrate.sql`** (184
   lines) — Trust Phase 1 evidence substrate. Creates 4 immutable
   append-only tables (`page_artifacts`, `source_spans`,
   `extracted_fields`, `field_evidence`), 1 read view
   (`v_field_citations`), and 1 cost-tracking table
   (`evidence_extraction_costs`). All RLS-enabled, all access
   revoked from anon/authenticated, only `service_role` granted.
   Depends on `public.documents` (created in step 1).
7. **`supabase/migrations/2026_07_19_job_outbox.sql`** (~150 lines) —
   Durable work queue per `docs/decisions/ADR-2026-07-19-01-...md`.
   Creates `job_outbox` (the generic queue for every async path)
   plus `v_outbox_health` and `v_outbox_dead_letter` operator
   views. RLS-enabled, only `service_role` granted. Depends on
   `pgcrypto` (created in step 6's same apply if not already).
8. **`supabase/migrations/2026_07_19_consent_ledger.sql`** (~120 lines) —
   Server-side append-only consent ledger per
   [ADR-2026-07-19-07](../../decisions/ADR-2026-07-19-07-security-phase-2-server-side-consent-ledger.md).
   Creates `consent_ledger` (the user's consent events), a
   `consent_ledger_append_only()` trigger that raises an
   exception on UPDATE and DELETE for ALL roles, and 2
   views (`v_current_consent` for the "current state" query,
   `v_consent_history` for the audit view). RLS-enabled, only
   `service_role` granted for INSERT and SELECT.

**Verify after applying all 8:**

```sql
-- Run in Supabase SQL Editor. Must return rows for every object.
select 'documents' as object, count(*) from public.documents
union all select 'document_chunks', count(*) from public.document_chunks
union all select 'analytics_events', count(*) from public.analytics_events
union all select 'profiles', count(*) from public.profiles
union all select 'user_lifecycle', count(*) from public.user_lifecycle
union all select 'subscriptions', count(*) from public.subscriptions
union all select 'webhook_audit_log', count(*) from public.webhook_audit_log
union all select 'processed_webhook_events', count(*) from public.processed_webhook_events
union all select 'failed_subscription_writes', count(*) from public.failed_subscription_writes
union all select 'routing_decisions', count(*) from public.routing_decisions
union all select 'eval_set_candidates', count(*) from public.eval_set_candidates
union all select 'deal_decisions', count(*) from public.deal_decisions
union all select 'events_unrouted', count(*) from public.events_unrouted
union all select 'page_artifacts', count(*) from public.page_artifacts
union all select 'source_spans', count(*) from public.source_spans
union all select 'extracted_fields', count(*) from public.extracted_fields
union all select 'field_evidence', count(*) from public.field_evidence
union all select 'evidence_extraction_costs', count(*) from public.evidence_extraction_costs
union all select 'job_outbox', count(*) from public.job_outbox
union all select 'consent_ledger', count(*) from public.consent_ledger;

-- Views must exist (3 RevOps + 1 evidence + 2 outbox + 2 consent = 8).
select viewname from pg_views
where schemaname = 'public'
  and viewname in (
    'v_daily_active_users','v_conversion_funnel','v_cohort_retention',
    'v_field_citations',
    'v_outbox_health','v_outbox_dead_letter',
    'v_current_consent','v_consent_history'
  );

-- RLS must be enabled on the RevOps + evidence + outbox + consent tables.
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'profiles','user_lifecycle','subscriptions','webhook_audit_log',
    'processed_webhook_events','failed_subscription_writes',
    'routing_decisions','eval_set_candidates','deal_decisions',
    'events_unrouted',
    'page_artifacts','source_spans','extracted_fields',
    'field_evidence','evidence_extraction_costs',
    'job_outbox',
    'consent_ledger'
  )
order by tablename;

-- Append-only enforcement: an UPDATE on consent_ledger must raise an
-- exception (the trigger in migration #8). The launch playbook's
-- verify step proves the trigger is in place; this is the contract
-- for the DPDP Act 2023 compliance posture.
do $$
declare
  has_trigger boolean;
begin
  select exists(
    select 1 from pg_trigger
    where tgname = 'consent_ledger_append_only_trg'
      and tgrelid = 'public.consent_ledger'::regclass
  ) into has_trigger;
  if not has_trigger then
    raise exception 'consent_ledger_append_only_trg is missing; migration #8 may not have applied correctly';
  end if;
  raise notice 'consent_ledger_append_only_trg is in place';
end;
$$;
```

Expected: every `count(*)` returns a number (0 is fine for empty tables);
8 rows from the views query; every RevOps + evidence + outbox + consent
table has `rowsecurity = t`; the trigger check returns "consent_ledger_append_only_trg is in place."

---

## Step 1.5: Embedding model benchmark (30-day window) — Optional but recommended

Per [ADR-2026-07-19-03](../../decisions/ADR-2026-07-19-03-embedding-model-text-embedding-3-small-default.md), the default embedding model is `text-embedding-3-small`. The benchmark against `voyage-3` runs over 30 days from launch; the operator may skip it for v0 and run it later.

**When to run:** after Step 8 (the real-device end-to-end test) is passing, and at least 50 real policies have been uploaded. The benchmark needs real policy data, not fixtures.

**How to run:**

```bash
# 1. Create the ground-truth file
mkdir -p tools/embedding_benchmark
# Write tools/embedding_benchmark/ground_truth.jsonl: one line
# per (policy_id, query) pair, with relevant_chunk_indices
# labeled. See docs/architecture/embedding_model_benchmark_methodology_2026-07-19.md
# for the format.

# 2. Set the env vars
export OPENAI_API_KEY=...
export VOYAGE_API_KEY=...
export SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=...
export BENCHMARK_POLICY_LIMIT=50
export BENCHMARK_QUERY_LIMIT=20

# 3. Run the benchmark
python tools/benchmark_embedding_models.py

# 4. Read the results
ls -t tools/embedding_benchmark/results/ | head -1
cat tools/embedding_benchmark/results/<timestamp>/summary.json
cat tools/embedding_benchmark/results/<timestamp>/README.md
```

**Expected output:** a `summary.json` with the recall@3 per model and a decision. The decision rule is in the methodology doc.

**If the decision is SWITCH_TO_VOYAGE_3:** follow the migration plan in ADR-2026-07-19-03. The migration is a separate session; it is not part of the launch.

**If the decision is KEEP_SMALL or STRONG_KEEP_SMALL:** no action. The default stays. Re-run the benchmark every 6 months.

**Cost:** <$0.05 in API calls for one run.

---

## Step 2: Supabase keys (2 minutes, dashboard)

Dashboard → **Settings** → **API**:
- **Project URL** — you already have this: `https://eyumuxwabmsymytjbxoj.supabase.co`
- **`service_role` key** (secret; never put in mobile) — needed for the
  Cloud Run service. Copy it. You will use it in Step 4.
- **`publishable` / `anon` key** — you already have this:
  `sb_publishable_QokliXvSKAyiqeWvbsNy2Q_2EyKVqAy`. The mobile app
  uses this; it is not a secret.

**Verify:** open the key copy and confirm it matches the format
`sb_publishable_...` (not `sb_secret_...`). Wrong key in the wrong
place is the #1 cause of "auth works locally, fails in production."

---

## Step 3: Create a GCP project (~5 minutes)

1. https://console.cloud.google.com → create project `coverwise`.
2. Enable APIs: **Cloud Run**, **Secret Manager**, **Cloud Build**
   (Cloud Build is required for `gcloud run deploy --source`).
3. `brew install google-cloud-sdk` if you don't have it.
4. `gcloud auth login` and `gcloud config set project coverwise`.

**Verify:**
```bash
gcloud config get-value project     # → coverwise
gcloud services list --enabled | grep -E 'run|secretmanager|cloudbuild'
# Expect 3 lines.
```

---

## Step 4: Create secrets in Secret Manager (~3 minutes)

The deploy script reads 4 secrets at deploy time. None of these are
logged; all are mounted as env vars on the Cloud Run service.

```bash
# OpenAI key (you must fund the account first; do not reuse a key
# you have ever pasted into a chat window — generate a new one).
echo -n "sk-proj-YOUR-NEW-KEY" \
  | gcloud secrets create coverwise-openai-key --data-file=-

# Supabase service_role key (from Step 2). MUST be the service_role,
# not the publishable/anon key.
echo -n "YOUR_SUPABASE_SERVICE_ROLE_KEY" \
  | gcloud secrets create coverwise-supabase-service-role --data-file=-

# Anonymous auth signing key. Generate a random 32-byte value.
echo -n "$(openssl rand -hex 32)" \
  | gcloud secrets create coverwise-anon-auth-signing-key --data-file=-

# RevenueCat webhook authorization value. Store the exact authorization
# header value expected by the webhook route, not the mobile public SDK key.
echo -n "Bearer YOUR-REVENUECAT-WEBHOOK-SECRET" \
  | gcloud secrets create coverwise-revenuecat-webhook-auth --data-file=-
```

**Verify:**
```bash
gcloud secrets list --project=coverwise \
  | grep -E 'coverwise-openai-key|coverwise-supabase-service-role|coverwise-anon-auth-signing-key|coverwise-revenuecat-webhook-auth'
# Expect 4 lines.
```

---

## Step 5: Create the runtime env file (~2 minutes)

Create `coverwise-runtime.env` **at the repo root** (gitignored). This
file holds non-secret values only. Never put API keys here.

```env
ENVIRONMENT=production
SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co
SUPABASE_STORAGE_BUCKET=coverwise-documents
DOCUMENT_REPOSITORY_BACKEND=supabase
DOCUMENT_OBJECT_STORE_BACKEND=supabase
RAG_VECTOR_BACKEND=supabase
# Include every actual browser origin, including the API origin only if a
# browser client uses it directly. PUBLIC_SITE_URL must be one of these.
ALLOWED_ORIGINS=https://coverwise.app,https://www.coverwise.app
PUBLIC_SITE_URL=https://coverwise.app
# API hostnames only, no URL scheme or path. Include a provider service host
# if health checks reach it directly.
ALLOWED_HOSTS=api.coverwise.app
OPENAI_CHAT_MODEL=gpt-4o-mini
OPENAI_EMBEDDING_MODEL=text-embedding-3-small
# Phase 0 additions:
ANALYTICS_DUAL_WRITE=true
DUAL_WRITE_ANALYTICS=true
CONTEXTUAL_RETRIEVAL_ENABLED=false
OPERATOR_DASHBOARD_TOKEN=<random-32-byte-hex>
```

**Verify:**
```bash
test -f coverwise-runtime.env && echo "ok" || echo "MISSING"
grep -E '^(SUPABASE_URL|ANALYTICS_DUAL_WRITE|DUAL_WRITE_ANALYTICS|CONTEXTUAL_RETRIEVAL_ENABLED|OPERATOR_DASHBOARD_TOKEN)' coverwise-runtime.env
# All 5 must appear.
```

**Important:** the `OPERATOR_DASHBOARD_TOKEN` is the shared secret that
guards `/api/analytics/summary`, `/health`, and `/errors` per the
Phase 0 Security audit fix (P0-08). Without it set in the env, those
endpoints fail closed. The value must match what the operator dashboard
sends as `X-Operator-Token`. Use the same `openssl rand -hex 32` and
store the value in your password manager.

---

## Step 6: Deploy to Cloud Run (~10 minutes build, then 1 command)

```bash
cd /Users/pranay/Projects/medpiper/insurance_app

COVERWISE_GCP_PROJECT=coverwise \
COVERWISE_CLOUD_RUN_REGION=asia-south1 \
COVERWISE_RUNTIME_ENV_FILE=coverwise-runtime.env \
COVERWISE_OPENAI_SECRET=coverwise-openai-key \
COVERWISE_SUPABASE_SERVICE_ROLE_SECRET=coverwise-supabase-service-role \
COVERWISE_ANON_AUTH_SIGNING_SECRET=coverwise-anon-auth-signing-key \
COVERWISE_REVENUECAT_WEBHOOK_SECRET=coverwise-revenuecat-webhook-auth \
tools/deploy_cloud_run.sh
```

The script builds the Docker image, deploys to Cloud Run with
`min-instances=0` (scale-to-zero), and prints the URL.

**Verify after deploy:**
```bash
URL=$(gcloud run services describe coverwise-api --region=asia-south1 \
  --format='value(status.url)' 2>/dev/null)

curl -sS "$URL/health" | python3 -m json.tool
# Expected: {"status":"ok","rag_status":"available","embedding_probe":"ok",...}

# Analytics must require the operator token.
curl -sS -o /dev/null -w '%{http_code}\n' "$URL/api/analytics/summary"
# Expected: 401 or 403 (no token = no access).
curl -sS -o /dev/null -w '%{http_code}\n' \
  -H "X-Operator-Token: $OPERATOR_DASHBOARD_TOKEN" \
  "$URL/api/analytics/summary"
# Expected: 200.
```

If `/health` does not return `embedding_probe: ok`, the OpenAI key
secret is wrong. If the operator token test returns 401/403 with the
right token, the env file is missing `OPERATOR_DASHBOARD_TOKEN`.

---

## Step 7: Build the production Android App Bundle (~5 minutes + Android SDK setup)

```bash
# Run from the repository root with live public values. The script fails closed
# if the production keystore is absent or any tracked key.properties remains.
COVERWISE_API_BASE_URL=https://api.example.com \
COVERWISE_PRIVACY_POLICY_URL=https://www.example.com/privacy \
COVERWISE_TERMS_OF_SERVICE_URL=https://www.example.com/terms \
COVERWISE_SUPPORT_EMAIL=support@example.com \
COVERWISE_PRIVACY_POLICY_VERSION=1.0 \
SUPABASE_URL=https://project.supabase.co \
SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
REVENUECAT_API_KEY=appl_... \
tools/build_mobile_release.sh
```

The production artifact is at
`mobile/build/app/outputs/bundle/release/mobile-release.aab` (the exact filename
may follow the Gradle application name). Do not submit an artifact built with
placeholder values. For a non-distributable local debug/release smoke build,
use the commands in `docs/technical/deployment/release_signing.md` instead.

**Android SDK setup if needed:** `flutter doctor` — if Android
toolchain shows ✗, open Android Studio → SDK Manager → install the
SDK, then `flutter config --android-sdk ~/Library/Android/sdk`.

**Verify the bundle was built:**
```bash
ls -la mobile/build/app/outputs/bundle/release/*.aab
# Expect a non-zero file, recent mtime.
```

---

## Step 8: Real-device end-to-end test (15 minutes)

This step is **not optional**. The unit tests cover Python logic. The
only way to verify the Phase 0 fixes (the evidence guard in policy
detail, the privacy copy relabeling, the operator token gate, the
allowlisted error codes) is to actually run the APK on a phone.

```bash
# Install the APK on a real device
adb install -r mobile/build/app/outputs/flutter-apk/app-release.apk

# Watch the Cloud Run logs while you exercise the app
gcloud run services logs tail coverwise-api --region=asia-south1
```

Test sequence:
1. Cold-start the app. Verify no token copy button on the Profile
   screen (Phase 0 P0-07).
2. Open a policy, hit the policy detail screen. Upload a PDF without
   enough text — verify the "Not yet verified" scaffold shows
   instead of a confident summary (Phase 0 P0-0.4).
3. Tap "Delete policy" on a document. Verify the confirmation copy,
   remote-first deletion request, and local cleanup after server success
   (Phase 0 P0-02).
4. Privacy screen. Verify there is no "synced across devices" copy
   (Phase 0 P0-18).
5. Force a crash (any way). Wait 60s. Verify the
   `global_error_boundary` does NOT send the exception message text
   to `/api/analytics/errors` (Phase 0 P0-12).

If any of those fail, the Phase 0 commit is not actually deployed.
Re-check the build cache and re-deploy.

---

## Step 9: Tear down the old AWS App Runner service (5 minutes)

The old App Runner at `aa2485vt7t.ap-south-1.awsapprunner.com` runs
13-month-old code with a dead OpenAI key. You are paying ~$35/month
for it. **Only do this after Step 8 verifies the Cloud Run path.**

1. AWS Console → App Runner → find `insurance-app-enhanced-v2`.
2. Stop / delete the service.
3. Delete the ECR repo `insurance-rag-enhanced-v2`.
4. Cancel any ElastiCache Redis instances attached to it.

**Verify:**
```bash
# AWS billing — expect CoverWise line items to drop ~$35/month
# on the next statement. There is no API to assert "this is
# off"; manual billing check is the only verification.
```

---

## Cost summary after launch

| Service | Cost/month | Notes |
|---|---|---|
| Cloud Run (scale-to-zero, solo traffic) | $0-5 | Free tier covers 2M requests, 360K GB-seconds |
| Supabase (free tier) | $0 | 500MB DB, 1GB storage |
| OpenAI (gpt-4o-mini + embeddings, 10K queries) | ~$2 | Dominated by chat completions |
| Domain (coverwise.app or similar) | ~$10/year | ~$0.83/month amortized |
| **Total** | **~$5-10/month** | vs. ~$55-60/month for the old AWS setup |

---

## Pre-launch checklist (motto v3 §0.4 acceptance contract)

- [ ] OpenAI account funded; new key generated and stored only in GCP Secret Manager
- [ ] All 8 SQL migrations applied to Supabase; Step 1 verify passes
- [ ] Supabase service_role key captured (not the publishable key)
- [ ] GCP project created with Cloud Run / Secret Manager / Cloud Build APIs enabled
- [ ] 4 secrets created in Secret Manager; Step 4 verify passes
- [ ] `coverwise-runtime.env` created with `OPERATOR_DASHBOARD_TOKEN` set
- [ ] Cloud Run deployed; `/health` returns 200 with `embedding_probe: ok`
- [ ] Dedicated outbox worker deployed; `/healthz` returns 200 and a real queued-job round trip is observed
- [ ] Operator token gate verified (Step 6 verify)
- [ ] `coverwise.app` (or chosen brand) domain registered; DNS pointed
- [ ] Privacy policy + terms hosted at real URLs (not placeholder domains)
- [ ] `support@coverwise.app` mailbox set up
- [ ] Release APK built; Step 7 verify passes
- [ ] APK installed on a real device; all 5 Step 8 verifications pass
- [ ] Old AWS App Runner service stopped and ECR repo deleted

---

## Out of scope for this playbook

These are tracked in the Phase 1+ audits and are explicitly NOT part
of "go live":

- **Trust Phase 1 Python layer** — the SQL substrate (Step 1's
  migration #6) is in scope; the typed Python access layer in
  `src/services/evidence_substrate_service.py` and the parser
  pipeline are Phase 1 follow-up. Until those land, the substrate
  is empty and the policy detail screen continues to show the
  "Not yet verified" scaffold (which is the correct behavior
  per the Phase 0 trust fix).
- **Security Phase 1 migration** — the principal-scoped encryption
  contract is shipped in commit `0704eb5` (well, the most recent
  security commit) per
  [ADR-2026-07-19-06](../../decisions/ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md).
  The KDF + Hive re-encryption API is in
  `mobile/lib/services/principal_key_service.dart`. The per-box
  migration (each existing Hive box migrated to the new principal
  key) is a follow-up session.
- **Security Phase 2 migration** — the server-side consent
  ledger + trigger-enforced append-only + FastAPI endpoint +
  Flutter client are shipped in
  [ADR-2026-07-19-07](../../decisions/ADR-2026-07-19-07-security-phase-2-server-side-consent-ledger.md).
  The Flutter cache invalidation (the local Hive box
  becomes a cache, with the server as the source of truth)
  is a follow-up session.
- **Security Phase 3** — durable deletion job with retries +
  tombstone. `delete_account` returns 202 + per-stage status;
  the actual back-end retry / tombstone job is Phase 3.
- **Embedding model switch** — the default is `text-embedding-3-small`
  per [ADR-2026-07-19-03](../../decisions/ADR-2026-07-19-03-embedding-model-text-embedding-3-small-default.md).
  The benchmark may recommend switching to `voyage-3`; the
  migration is a separate session. Step 1.5 above covers the
  benchmark; the migration itself is not in this playbook.
- **Coverage-gap + claim-assistance full features** — the thin slice
  shipped in commit `a7166ff` is grounded in the existing 7
  substrate fields (`room_rent_cap`, `insurer_name`). The full
  features (maternity, dental, OPD, pre-existing disease waiting
  period, network hospital list, claim helpline, claim email, full
  claim-assistance flow) require extending the parser pipeline
  with 5-7 new extractors. Per
  [ADR-2026-07-19-04](../../decisions/ADR-2026-07-19-04-coverage-gap-claim-assistance-thin-slice.md),
  the full features are a follow-up session.

---

## Why this revision is different from the previous version

The original launch playbook (2026-07-18, pre-Phase-0) referenced
3 SQL migrations. The current repo has 6: the original 3 plus the
2 RevOps/analytics migrations added in commit `fa02854`, plus the
evidence substrate migration added in the next commit on the
Trust Phase 1 track. This revision:

1. Adds the 3 new SQL files to the apply order with explicit
   dependency notes.
2. Adds `OPERATOR_DASHBOARD_TOKEN` to the runtime env (the
   security P0-08 gate now fails closed if this is missing).
3. Adds `ANALYTICS_DUAL_WRITE=true` and
   `DUAL_WRITE_ANALYTICS=true` to the runtime env so the
   mobile-app analytics actually reach Supabase.
4. Sets `CONTEXTUAL_RETRIEVAL_ENABLED=false` so the trust
   P0-0.6 contamination fix is in effect.
5. Replaces every "verify" with an actual command and expected
   output. The old playbook had some "should work" steps with no
   assertion. Per motto v3 §0.5, evidence is verified, not
   asserted.
6. Adds a real-device end-to-end test (Step 8) with the specific
   Phase 0 acceptance criteria. The old playbook stopped at
   "test a query" and did not exercise the new customer-visible
   fixes.
