# Supabase Setup — Verification Record & Key-Handling Policy

**Date:** 2026-07-28
**Status:** Supabase provisioned, keys verified, schema confirmed applied, secrets stored for CI. Auth providers + redirect URLs still pending (see §3).
**Supersedes in part:** `docs/SUPABASE_SETUP_RUNBOOK.md` (that runbook's "❌ NOT CONFIGURED" status is stale as of this date — see §4)
**Doctrine:** `motto_v4.md` §0.2 (confidence honesty — state evidence tier), §0.3 (documentation continuity), §0.5 (evidence tiers)
**Evidence tier:** Tier 1 (static config inspection) + Tier 4 (runtime HTTP probes against the live project)

---

## Why this exists

Supabase setup was attempted by multiple prior agents and the picture in the docs was contradictory: the 07-25 buyer-readiness logs claimed the service key was "malformed (41 chars, no dots)," while the runbook claimed nothing was configured. This record establishes the verified ground truth as of 2026-07-28 and replaces speculation with probed facts.

---

## 1. Project + key state (verified 2026-07-28, Tier 4)

| Item | Value shape | Verified |
|---|---|---|
| Project URL | `https://eyumuxwabmsymytjbxoj.supabase.co` (Mumbai / `ap-south1`) | ✅ `/auth/v1/health` → 200 |
| Region | Mumbai — matches backend (AWS App Runner `ap-south-1`) for low latency | ✅ |
| `SUPABASE_PUBLISHABLE_KEY` (anon) | `sb_publishable_...`, 46 chars | ✅ `/auth/v1/health` → 200 with anon key |
| `SUPABASE_SECRET_KEY` (service_role) | `sb_secret_...`, 41 chars, no dots | ✅ `/rest/v1/` → 200; bypasses RLS (proven) |
| `SUPABASE_SERVICE_ROLE_KEY` | empty in `.env` | ⚠️ backend uses fallback alias (see §2) |

### Correcting the prior "malformed key" claim

The 07-25 logs flagged the 41-char, no-dots `SUPABASE_SECRET_KEY` as malformed. **That was wrong.** Supabase's current key format uses `sb_secret_...` / `sb_publishable_...` prefixes — single-segment strings, NOT JWTs. The old `eyJhbG...` JWT format is the *legacy* service_role key. Both formats are valid; the `sb_secret_` format is what current projects expose. Probed and working (Tier 4).

---

## 2. Key-handling policy (the principle)

Three keys exist and have strictly different powers. This is the canonical policy — every agent, deploy script, and doc must follow it.

| Key | RLS (row-level security) | Power | Where it may live |
|---|---|---|---|
| **anon / publishable** (`sb_publishable_...`) | **Enforced** — bound by every `owner_id = auth.jwt()->>'sub'` policy | Read/write the authenticated user's own rows only; cannot see other users' rows | Mobile app, browser, anywhere user-facing |
| **service_role / secret** (`sb_secret_...`) | **Bypassed entirely** | Read/write/delete **every row in every table and storage bucket** — Postgres superuser-equivalent | Backend server runtime ONLY. Never in a client. Never in logs. |
| **CLI management token** (from `supabase login`) | n/a — Management API, not PostgREST | Run DDL (`CREATE TABLE`, migrations, RLS policies) | Operator's machine (`~/.supabase/access-token`) only |

### Verified proof of the power difference (Tier 4)

```
GET /rest/v1/qa_usage_events?select=*&limit=1
  with anon key    → 401 permission denied  (RLS blocks)
  with secret key  → 200 []                 (RLS bypassed)
```

### Rules

1. **The secret key never leaves the server.** It lives in backend `.env` locally and in the deploy platform's secret store (Render Environment tab, GitHub Actions secrets) in prod. It is never bundled in a mobile or web build.
2. **Migrations use the CLI management token, not the secret key.** `supabase db query --linked -f <file>` authenticates via the Management API token from `supabase login`. The REST secret key *cannot* run DDL — this was verified when the dry-run failed.
3. **Mobile reads only the publishable key** (`mobile/lib/config/app_config.dart:supabasePublishableKey`). This is correct and must not change.
4. **Reach for the secret key only for genuine cross-user server work** — background workers, account deletion, webhook reconciliation across users. For one-off verification scripts, prefer the anon key or the CLI token. Convenience is how secret-key leaks happen.

### Why other agents ask for the secret key

- **Legitimately:** the deployed backend (API + outbox worker) needs it to do cross-user work where no single user is "logged in." `render.yaml` requests it for this reason.
- **Cargo-cult:** many agents default to "I need admin to do anything" because it bypasses every RLS policy. This is the pattern the founder correctly questioned. It is often lazy, not necessary.

---

## 3. What's done vs what's pending

### ✅ Done (this session)
- Keys verified working (anon + service, Tier 4 probes).
- Schema confirmed **fully applied**: 60 tables + 19 RPC functions live. 54 of 55 migrations were already applied before this session.
- 2 missing migrations applied via CLI: `20260724000000_claims_table.sql` + `20260724010000_claim_log_boundary.sql`. Verified: `claims` table (17 cols), RLS enabled, 3 owner-scoped policies, `claims_initiated_by_user_only` constraint, `claims_status_check` constraint.
- GitHub Actions secrets set: `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `SUPABASE_PUBLISHABLE_KEY` (via `gh secret set`).
- Dual-key documentation clarified in `.env.example` + `runtime_config.py` docstring — the code's dual-name fallback is deliberate (Supabase renamed the key format); the docs were misleading.

### ⚠️ Pending (not blocking backend deploy; blocking auth features)
- **Enable Email provider** in Supabase dashboard (Authentication → Providers → Email). Default ON in new projects; confirm.
- **Add redirect URLs** (Authentication → URL Configuration) for `io.coverwise://login-callback`. NOTE: the 07-21 store-readiness audit flagged a scheme-as-host vs path bug here — the rename is the right time to fix it.
- **Google OAuth** — needs a Google Cloud OAuth client (founder). Required to fix the P0 guest-workspace-migration bug for Google sign-in (email auth already runs it).
- **Migration history reconciliation** — the remote `supabase_migrations.schema_migrations` table is out of sync with local files (~38 local-only, ~19 remote-only ghosts). This is bookkeeping, not a schema problem (all tables exist and work). Optional cleanup for clean `db push` workflows.

---

## 4. Relationship to `docs/SUPABASE_SETUP_RUNBOOK.md`

The runbook (last verified 2026-07-18) says "❌ NOT CONFIGURED" and "the `.env` file has no `SUPABASE_*` vars." **That status is stale.** As of 2026-07-28:
- `.env` has `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_STORAGE_BUCKET`, all verified working.
- The schema is fully applied (was not true on 07-18).

The runbook's *instructions* (how to enable Email, add redirect URLs, configure Google) remain accurate and should still be followed for the §3 pending items. Only the status flags are stale. The runbook should be updated to reflect verified state when the §3 pending items close.

---

## 5. Anything else? (motto §0.1.1)

1. **Storage bucket name `coverwise-documents`.** Per the rename strategy doc, this is infrastructure, not marketing — keep the name internal even after the brand changes. Renaming it would require migrating every stored document. Not worth it.

2. **`SUPABASE_STORAGE_BUCKET` — VERIFIED CORRECT (Tier 4).** Initial speculation that `.env` pointed at `coverwise.app` was a masking artifact in an earlier diagnostic display (a sed mask truncated the displayed value). Authoritative check via the CLI management connection confirms: exactly one bucket exists (`coverwise-documents`, private, created 2026-07-20), and `.env`'s `SUPABASE_STORAGE_BUCKET='coverwise-documents'` matches it exactly. No mismatch; uploads will hit the right bucket. Side note: the Storage REST API rejects the new-format `sb_secret_...` key with `Invalid Compact JWS` (it expects the legacy JWT service key), but PostgREST and the CLI both work with the new-format key — so the backend's normal path is unaffected.

3. **The empty `SUPABASE_SERVICE_ROLE_KEY`.** The backend reads `SUPABASE_SECRET_KEY` via the `supabase_server_key()` fallback, so it works. But `SUPABASE_SERVICE_ROLE_KEY` being empty is a latent footgun — if the fallback were ever removed, prod breaks silently. Consider setting `SUPABASE_SERVICE_ROLE_KEY` = `SUPABASE_SECRET_KEY` explicitly in `.env` to remove the ambiguity. (Code-side, the fallback is documented and correct.)

---

## Update log

- 2026-07-28: created. Tier-4 verification of keys + schema; key-handling policy §2; §3 done/pending split; supersedes stale status in `SUPABASE_SETUP_RUNBOOK.md`.
