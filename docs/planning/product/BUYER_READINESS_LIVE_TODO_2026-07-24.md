# Buyer-readiness live todo (2026-07-24)

## Current active item

- Last updated (session): 2026-07-28
- Active gate: **BR-06** (hosted legal pages — requires deployed HTTPS URL)
- BR-04/BR-05: **RESOLVED 2026-07-28** — 11/11 checks passed against remote Supabase using SUPABASE_SECRET_KEY fallback.
  See evidence below in one-item execution list items 7 & 8.

## Immediate blocker status

- `tools/check_buyer_readiness_prereqs.sh` currently returns:
  - `DockerVersion=29.6.2;Server=29.6.2` (docker daemon reachable in this session)
  - missing/invalid `SUPABASE_SERVICE_ROLE_KEY`
- with `source .env`:
  - `DockerVersion=29.6.2;Server=29.6.2`
  - missing `SUPABASE_SERVICE_ROLE_KEY`
  - warn: `SUPABASE_URL` `/rest/v1/` probe returned `401`
- with `--sourced-env` at latest rerun (`2026-07-25T08:08:15+05:30`):
  - missing `SUPABASE_SERVICE_ROLE_KEY`
  - `DockerVersion=29.6.2;Server=29.6.2`
  - `tools/verify_local_identity_claim.py` and `tools/verify_local_tenant_isolation.py` pass local shape/parse checks, but auth/admin path now fails with `HTTP 401 Invalid API key` when placeholder service-role credentials are used.
- `tools/validate_production_config.py` still blocks BR-11 without production runtime vars (`SUPABASE_*`, encryption/signing/webhook/backend keys, allow-lists).
- `SUPABASE_SECRET_KEY` is present but does not satisfy `Authorization: Bearer` service-role auth shape for BR-04/BR-05 in this session; earlier runs showed malformed-token `400/403` semantics (`bad_jwt`), while explicit placeholder tests now fail as `HTTP 401 Invalid API key`.
- `COVERWISE_API_BASE_URL` target for BR-04 is this session’s `http://127.0.0.1:8005`.
- `/user/anonymous` responds to `POST` with HTTP 200 and to `GET` with HTTP 404.
- `COVERWISE_API_URL` is not the script-facing variable in this runbook.
- Auth material shape confirmation from local env:
  - `SUPABASE_SERVICE_ROLE_KEY` remains unset.
  - `COVERWISE_API_BASE_URL` is currently unset in `.env`.
  - `SUPABASE_SECRET_KEY` and `SUPABASE_PUBLISHABLE_KEY` are 1-segment values (not JWT-formatted), so they cannot satisfy admin endpoint authentication for BR-04/BR-05.

## One-item execution list (in sequence)

1. [x] BR-02 representative corpus local contract checks
   - `./.venv/bin/pytest -q tests/test_br02_representative_corpus.py`
   - Result: `8 passed`.

2. [x] BR-04 preflight gate capture
   - `./tools/check_buyer_readiness_prereqs.sh`
   - Result:
     - no-env: `BLOCKED` with 4 items (`DockerVersion=29.6.2;Server=`, missing `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`).
     - placeholder env: `BLOCKED` with 1 item (`DockerVersion=29.6.2;Server=`), with local API/Supabase health endpoints passing.

3. [x] BR-04/BR-05 local command-shape tests
   - `./.venv/bin/pytest -q tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py`
   - Result: `4 passed` (current repo state).

4. [x] BR-07 local contract checks
   - `./.venv/bin/pytest -q tests/test_billing_ledger_service.py tests/test_subscription_webhook.py`
   - Result: `17 passed`.

5. [x] BR-06 hosted-legal contract checks (non-deployed control)
   - `./.venv/bin/pytest -q tests/test_verify_hosted_legal_documents.py`
   - Result: `4 passed`.

6. [x] BR-11 production config proof capture
   - `./.venv/bin/python tools/validate_production_config.py`
   - Result: explicit missing-var failure list (no false-positive pass).

7. [x] BR-04 real credentials execution — **RESOLVED 2026-07-28**
   - Previous assumption: `SUPABASE_SERVICE_ROLE_KEY` must be JWT `eyJ...` format.
   - Actual finding: `SUPABASE_SECRET_KEY` (`sb_secret_...`) works via the Supabase Python SDK, which handles auth internally.
   - Run command:
     ```
     source .env
     export SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SECRET_KEY"
     .venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase \
       --api-url http://127.0.0.1:8005 \
       --supabase-url https://eyumuxwabmsymytjbxoj.supabase.co
     ```
   - Evidence: 5/5 checks PASSED
     - PASS admin user creation: via supabase admin client
     - PASS user sign-in: via supabase lib
     - PASS anonymous identity: HTTP 200
     - PASS guest-to-account claim: HTTP 200
     - PASS account profile: HTTP 200
     - Exit code: 0

8. [x] BR-05 real tenant-isolation execution — **RESOLVED 2026-07-28**
   - Run command:
     ```
     source .env
     export SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SECRET_KEY"
     .venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase \
       --api-url http://127.0.0.1:8005 \
       --supabase-url https://eyumuxwabmsymytjbxoj.supabase.co
     ```
   - Evidence: 6/6 checks PASSED
     - PASS upload
     - PASS cross-owner API denial
     - PASS cross-owner Storage denial
     - PASS owner deletion
     - PASS post-delete API absence
     - PASS post-delete Storage absence
     - Exit code: 0

9. [ ] BR-06 hosted legal parity proof
   - Expected success criteria:
     - `tools/verify_hosted_legal_documents.py --privacy-url <prod-url>/privacy --terms-url <prod-url>/terms` passes.
  - Blocker: canonical deployed legal URLs not supplied.

10. [ ] BR-07 provider lifecycle proof
    - Expected success criteria:
      - BIL-01 + signed webhook replay + idempotency + writeback evidence.
    - Blocker: no live provider/store runtime in-session.

11. [ ] BR-12 store/distribution evidence
    - Expected success criteria:
      - signed artifacts + real-device smoke + store metadata checks.
    - Blocker: store account/runtime required.

12. [ ] BR-13/14 transfer/commercial readiness evidence
   - Expected success criteria:
     - transaction pack + transfer continuity checks + handover assumptions signed by owner.
   - Blocker: commercial handoff environment not yet executed.

## Progress log
- 2026-07-25T00:42:30+05:30: latest checkpoint:
  - `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - result: `BLOCKED` with 3 items (`DockerVersion=29.6.2;Server=`, missing `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_URL/rest/v1` `401`).
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - result: `HTTP 403 bad_jwt` (`invalid JWT`).
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - result: `HTTP 403 bad_jwt` (`invalid JWT`).
  - `./.venv/bin/python tools/validate_production_config.py`
    - result unchanged: not launch-ready (missing `SUPABASE_*`, processing/encryption/signing/backend vars, allow-lists).
  - env-shape snapshot:
    - `SUPABASE_SERVICE_ROLE_KEY` unset
    - `COVERWISE_API_BASE_URL` unset
    - `SUPABASE_PUBLISHABLE_KEY` and `SUPABASE_SECRET_KEY` are non-JWT single-segment values.

- 2026-07-25T00:40:59+05:30: fresh checkpoint and one-step checks:
  - `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - result: `BLOCKED` with 3 items (`DockerVersion=29.6.2;Server=`, `SUPABASE_SERVICE_ROLE_KEY`, `/rest/v1` `401`).
  - `COVERWISE_API_BASE_URL` remains unset in `.env`; route checks were run against `http://127.0.0.1:8005` with:
    - `POST /user/anonymous` -> `200`,
    - `GET /user/anonymous` -> `404`.
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - result: `HTTP 403 bad_jwt` (`invalid JWT`).
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - result: `HTTP 403 bad_jwt` (`invalid JWT`).

- 2026-07-25T09:37:00+05:30: preflight/env-shape verification rerun:
  - with `set -a; source .env`:
    - `./tools/check_buyer_readiness_prereqs.sh --sourced-env` result still blocked:
      - `DockerVersion=29.6.2;Server=`
      - `SUPABASE_SERVICE_ROLE_KEY` missing
      - `SUPABASE_URL/rest/v1` returns `401` under current publishable key.
  - `.env` variable shape:
    - `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are set,
    - `SUPABASE_PUBLISHABLE_KEY` has no JWT dots (single segment),
    - `SUPABASE_SERVICE_ROLE_KEY` is unset.
  - Immediate required owner input narrowed to:
    - provide JWT-style `SUPABASE_SERVICE_ROLE_KEY` for admin API (`/auth/v1/admin/users`) bearer auth.
- 2026-07-25T09:18:40+05:30: verifier contract confirmation pass:
  - Script re-check confirms BR-04/BR-05 require JWT-style `SUPABASE_SERVICE_ROLE_KEY` for `Authorization: Bearer` on `/auth/v1/admin/users`.
  - `SUPABASE_SECRET_KEY` only used as fallback when service-role is unset.
  - BR-04/BR-05 route target remains `COVERWISE_API_BASE_URL=http://127.0.0.1:8005`.
  - This corroborates that `HTTP 403 bad_jwt` is credential shape/role mismatch, not endpoint misconfiguration.
- 2026-07-25T00:50:44+05:30:
  - `POST /user/anonymous` on `http://127.0.0.1:8005` -> HTTP 200 token body.
  - `GET /user/anonymous` -> HTTP 404.
  - `check_buyer_readiness_prereqs.sh --sourced-env` with `set -a && source .env` remains blocked (`DockerVersion=29.6.2;Server=`, missing `SUPABASE_SERVICE_ROLE_KEY`, REST 401 at `SUPABASE_URL/rest/v1`).
  - `verify_local_identity_claim.py --allow-remote-supabase` -> `HTTP 403` / `bad_jwt`.
  - `verify_local_tenant_isolation.py --allow-remote-supabase` -> `HTTP 403` / `bad_jwt`.
  - `validate_legal_release_assets.py` -> legal release assets complete and match.
- 2026-07-25T00:44:12+05:30:
  - ran and verified evidence in one pass:
    - `33 passed` from BR-04/BR-05/BR-07/BR-06 local test suite bundle.
    - `./tools/check_buyer_readiness_prereqs.sh --sourced-env` → `BLOCKED` (`DockerVersion=29.6.2;Server=`, missing Supabase env vars).
    - `./.venv/bin/python tools/validate_production_config.py` → production/runtime variable failures unchanged.
    - `verify_local_identity_claim.py` with `set -a && source .env && COVERWISE_API_BASE_URL='http://127.0.0.1:8005'` and placeholder `SUPABASE_SERVICE_ROLE_KEY` → `HTTP 403 bad_jwt`.
    - `verify_local_tenant_isolation.py` with same env → same `bad_jwt` failure at `/auth/v1/admin/users`.

- 2026-07-25T00:21:13+05:30:
  - reran `tools/check_buyer_readiness_prereqs.sh --sourced-env` in-session; still missing `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY` with `DockerVersion=29.6.2;Server=`.
  - BR-04 path is confirmed against `http://127.0.0.1:8005` (app endpoint active and `/user/anonymous` returns HTTP 200).
- 2026-07-25T00:25:11+05:30:
  - re-ran preflight with `--sourced-env`: `DockerVersion=29.6.2;Server=`, missing required Supabase env vars.
  - with `.env` loaded and placeholder service-role, BR-04/BR-05 still fail at `/auth/v1/admin/users` with `HTTP 403 bad_jwt` (`invalid JWT...invalid number of segments`).
  - `tools/validate_production_config.py` still blocks BR-11 on required production/runtime keys.
- 2026-07-25T00:25:14+05:30:
  - shape check confirms `SUPABASE_SERVICE_ROLE_KEY` is unset; secret/publishable tokens are single-segment values, so JWT-formatted service auth is not available in this environment.
- 2026-07-25T00:27:21+05:30:
  - re-confirmed API route behavior:
    - `POST /user/anonymous` -> HTTP 200.
    - `GET /user/anonymous` -> 404.
  - BR-04/BR-05 with `COVERWISE_API_BASE_URL=http://127.0.0.1:8005` and `SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'` still fail at `/auth/v1/admin/users` with `HTTP 403 bad_jwt` (`invalid JWT: token contains an invalid number of segments`).
- 2026-07-25T00:25:06+05:30:
  - reran BR-04 and BR-05 with `SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'` and with `.env` fallback `SUPABASE_SECRET_KEY`:
  - both fail at `/auth/v1/admin/users` with `HTTP 403 bad_jwt` (`token malformed`).
- 2026-07-25T00:17:06+05:30:
  - re-ran BR-04 and BR-05 in a single check with both `.env` material and:
    - explicit `SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'`
    - explicit `SUPABASE_SERVICE_ROLE_KEY` unset (so fallback to `SUPABASE_SECRET_KEY`)
  - command pattern used:
    - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase --api-url http://127.0.0.1:8000`
    - `./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase --api-url http://127.0.0.1:8000`
  - failure remains identical: `HTTP 403 bad_jwt` at `/auth/v1/admin/users` with `invalid JWT: unable to parse or verify signature, token contains an invalid number of segments`.
- 2026-07-25T00:18:22+05:30:
  - attempted `tools/verify_local_identity_claim.py` and `tools/verify_local_tenant_isolation.py` with `.env` URL/publishable key + placeholder service key + `--allow-remote-supabase`; both failed with `HTTP 403 bad_jwt` during admin-user create.
- 2026-07-25T00:31:10+05:30:
  - attempted `tools/verify_local_identity_claim.py` and `tools/verify_local_tenant_isolation.py` with `.env` values, `SUPABASE_SERVICE_ROLE_KEY` unset (fallback `SUPABASE_SECRET_KEY`), and `--allow-remote-supabase`; both failed with `HTTP 403 bad_jwt` at `/auth/v1/admin/users`:
    `invalid JWT: unable to parse or verify signature, token contains an invalid number of segments`.
- 2026-07-25T00:09:08+05:30:
  - preflight with `source .env` blocked on daemon + `SUPABASE_SERVICE_ROLE_KEY`; plus `401` warning on `/rest/v1/` probe.

- 2026-07-28: **BR-04/BR-05 RESOLVED**
  - Key discovery: `SUPABASE_SECRET_KEY` (sb_secret_...) works via Supabase Python SDK — no JWT `eyJ...` key needed.
  - BR-04 identity claim: 5/5 PASS, exit 0.
  - BR-05 tenant isolation: 6/6 PASS, exit 0.
  - Both verifiers run against remote Supabase (https://eyumuxwabmsymytjbxoj.supabase.co).
  - Active gate moved to **BR-06** (hosted legal pages — requires deployed HTTPS URL).

## Active one-item queue

- Continue from: [BUYER_READINESS_ACTIVE_QUEUE_2026-07-25.md](BUYER_READINESS_ACTIVE_QUEUE_2026-07-25.md)
