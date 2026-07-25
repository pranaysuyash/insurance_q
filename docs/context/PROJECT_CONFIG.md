# Project Configuration — Shared Reference for All Agents

> **Principle:** Discover once, document here, reuse forever.  
> Check this file before making ANY external API call or creating new infrastructure tools.

## ⛔ Anti-Patterns (Read Before Making API Calls)

| Don't do this | Instead do this | Why |
|---------------|----------------|-----|
| `POST /auth/v1/signup` for testing | Use `supabase.create_client().auth.admin.create_user()` via the supabase Python library | Email signup hits rate limit after 3-5 calls (HTTP 429) |
| `POST /auth/v1/admin/users` with raw `SUPABASE_SECRET_KEY` | Use the supabase Python library — it signs a proper JWT internally | Raw key returns `403 User not allowed` (JWT signature mismatch) |
| `DELETE /auth/v1/admin/users/{id}` with raw key | Use `client.auth.admin.delete_user(user_id)` via supabase library | Same JWT issue as admin user creation |
| Create new verification tools without checking `tools/` first | Check if the tool already exists in `tools/` | Identity claim and tenant isolation tools already exist |

### Why the rate limit was hit

Multiple agent sessions independently created verification tools (`verify_local_*`), each calling `POST /auth/v1/signup` to create disposable users. The tools were iterated ~5-10 times during debugging, and each run created a new disposable user. After 3-5 signups the Supabase email rate limit kicked in, returning **HTTP 429** (`over_email_send_rate_limit`). **Each session should have documented shared state here instead of rediscovering it.** This file is the fix.

## Supabase

**Project URL:** `https://eyumuxwabmsymytjbxoj.supabase.co`

### 🔑 Supabase Key Taxonomy — Read Before Making ANY Admin API Call

There are **three distinct key formats** for Supabase, each serving a different purpose. Confusing them has wasted multiple agent sessions. **Read this table carefully before calling any Supabase API.**

| Key | Format prefix | Where it goes | What it CAN do | What it CANNOT do |
|-----|--------------|---------------|----------------|-------------------|
| **Publishable (anon)** | `sb_publishable_...` | Mobile app (`--dart-define`) | Auth (login, signup, token refresh), read/write via PostgREST within RLS | DDL (CREATE TABLE), bypass RLS, Storage admin API, Management API |
| **Secret (service_role)** | `sb_secret_...` | Backend `.env` (`SUPABASE_SECRET_KEY`) | Bypass RLS, manage user data, upload to Storage, call pgvector functions — **server-only** | ❌ GoTrue admin API (`/auth/v1/admin/users`) rejects raw key format — must use **supabase Python library** which signs a proper JWT internally |
| **PAT (Management API)** | `sbp_v0_...` | One-time use for migrations | Run arbitrary SQL via `POST /v1/projects/{ref}/database/query`, manage projects/settings | Expires (30-day), NOT a runtime credential |

### ⚠️ Why the secret key doesn't work with the GoTrue Admin API

The `sb_secret_...` format is Supabase's **newer key format** (introduced mid-2024). For normal backend operations (reading/writing data, bypassing RLS via PostgREST), it works perfectly. **However, the GoTrue admin API** (`/auth/v1/admin/users`) specifically requires the `eyJ...` JWT format for its Bearer token. The `sb_secret_...` string is NOT a valid JWT — it has an invalid number of segments.

**The fix:** Use the **supabase Python library** instead of raw HTTP:
```python
from supabase import create_client
client = create_client(supabase_url, publishable_key)
# Signs a proper JWT internally from sb_secret_...
client.auth.admin.create_user({"email": "...", "password": "...", "email_confirm": True})
# NOT this (will fail with 403 bad_jwt):
# requests.post(f"{supabase_url}/auth/v1/admin/users", headers={"Authorization": f"Bearer {sb_secret_...}"})
```

The verification tools (`verify_deployed_*.py`) already do this correctly — they use the supabase library for admin operations. The `verify_local_*.py` tools use raw HTTP which fails.

### Why schema migrations can't use any of the standard keys

NONE of the three keys work for schema migrations through PostgREST because PostgREST only calls **existing** functions — it can't run DDL (CREATE TABLE, CREATE EXTENSION). To run migrations:

1. **Use the Management API** with a PAT (`sbp_v0_...`): `POST /v1/projects/{ref}/database/query` with `{"query": "CREATE TABLE ..."}`
2. **Use the Supabase dashboard SQL editor**
3. **Use direct psql** (requires IPv6 or the correct pooler format — newer Supabase free-tier projects are IPv6-only for direct DB access)

### ⛔ Anti-pattern: What NOT to do

| Don't | Why | Instead |
|-------|-----|---------|
| `POST /auth/v1/admin/users` with raw `sb_secret_...` in Authorization header | GoTrue API needs `eyJ...` JWT format | Use `supabase.create_client().auth.admin.create_user()` |
| `DELETE /auth/v1/admin/users/{id}` with raw key | Same JWT issue | Use `client.auth.admin.delete_user(user_id)` |
| `curl POST .../auth/v1/signup` for testing | Email rate limit (429 after 3-5 calls) | Use supabase library admin API |
| Use `sbp_v0_...` token as runtime credential | It expires in 30 days | Use `sb_secret_...` in backend `.env` |

### Current state

| Credential | Location | Status |
|-----------|----------|--------|
| SUPABASE_URL | `.env` | ✅ **Populated** |
| SUPABASE_PUBLISHABLE_KEY | `.env` | ✅ **Populated** — `sb_publishable_...` |
| SUPABASE_SECRET_KEY | `.env` | ✅ **Populated** — `sb_secret_...` (correct for backend) |
| SUPABASE_SERVICE_ROLE_KEY | Not in `.env` | ❌ **Not needed** — `SUPABASE_SECRET_KEY` is the same credential in newer format |
| ANONYMOUS_AUTH_SIGNING_KEY | `.env` | ✅ **Populated** |
| SUPABASE_STORAGE_BUCKET | `.env` | ✅ **Populated** — `coverwise-documents` |

**Important:** `SUPABASE_SECRET_KEY` and the old `SUPABASE_SERVICE_ROLE_KEY` are the **same credential** — just different format versions. The backend normalizes `SUPABASE_SECRET_KEY` to `SUPABASE_SERVICE_ROLE_KEY`. Do NOT add a separate `SUPABASE_SERVICE_ROLE_KEY` — it would be redundant.

### Network note

Direct database host (`db.eyumuxwabmsymytjbxoj.supabase.co`) is **IPv6-only** — this machine has no IPv6 connectivity. The connection pooler has IPv4 but uses SNI-based routing (newer v2 pooler), which older tools don't support. **Always use the Management API or supabase library for admin operations.**

**Database password (`Osddeies_12`):** This password exists for emergency admin access but is **not usable** from this machine — direct psql is blocked by IPv6, the pooler rejects the newer username format, and NONE of the API keys work for DDL through PostgREST. Do not waste time trying direct psql. Use the Supabase dashboard SQL editor or the Management API with a PAT token for schema changes.

## Existing Verification Tools

### Local-only tools (require localhost API + localhost Supabase)

| Tool | What it does | Status |
|------|-------------|--------|
| `tools/verify_local_identity_claim.py` | Creates 1 user, tests anonymous → account claim flow | ✅ Working (`--allow-remote-supabase` flag available) |
| `tools/verify_local_tenant_isolation.py` | Creates 2 users, uploads PDF, tests cross-owner denial | ⚠️ Upload fails with HTTP 422 (multipart encoding issue) |

### Deploy-safe tools (work against deployed Supabase + API)

| Tool | What it does | Status |
|------|-------------|--------|
| `tools/verify_deployed_identity_claim.py` | Creates 1 user via supabase lib, tests claim flow | ✅ **5/5 PASS** (no --confirm required) |
| `tools/verify_deployed_tenant_isolation.py` | Creates 2 users via supabase lib, tests isolation | ⚠️ Upload fails with HTTP 422 (same multipart issue) |

**Safety:** All deploy tools require `--confirm` flag and validate URL schemes.

## API Server

| Config | Value |
|--------|-------|
| Local port | 8005 |
| Start command | `uvicorn src.app.main:app --host 0.0.0.0 --port 8005` |
| Health check | `GET /healthz` (returns 200) |

## Authentication

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `POST /user/anonymous` | API | Get anonymous bearer token |
| `POST /user/claim-anonymous` | API | Link anonymous workspace to account |
| `GET /user/profile` | API | Get account profile |

## Important Commands

| Task | Command |
|------|---------|
| Run Python tests | `cd /path/to/insurance_app && TMPDIR=/tmp .venv/bin/pytest tests/ -x` |
| Run Flutter tests | `cd mobile && flutter test --concurrency=1` |
| Run Ruff | `.venv/bin/ruff check src/` |
| Flutter analyze | `cd mobile && flutter analyze` |

## Related Docs

- `docs/planning/product/TODO_app_improvements.md` — Buyer-readiness TODO stack
- `docs/planning/product/BUYER_READINESS_CLOSURE_2026-07-24.md` — BR closure register
- `docs/launch_claims/evidence-backed.md` — Four-face evidence contract
- `docs/review/policy_rag_hybrid_legacy_module_review_2026-07-24.md` — Legacy module review
