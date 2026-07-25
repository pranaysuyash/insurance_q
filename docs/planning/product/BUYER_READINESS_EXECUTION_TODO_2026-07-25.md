# Buyer-readiness execution todo (live queue) — 2026-07-25

Status source: `docs/planning/product/BUYER_READINESS_ACTIVE_QUEUE_2026-07-25.md`, `docs/planning/product/BUYER_READINESS_TODO_LIST_2026-07-25.md`.

Owner mode: solo founder. Focused, one-item-at-a-time execution with evidence-backed checks.

## Last run
- **Timestamp:** `2026-07-25T13:10:25+05:30`  
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'` returns `Client 29.6.2;Server 29.6.2`.
  - `tools/check_buyer_readiness_prereqs.sh --sourced-env` returns `BLOCKED: BR-04/BR-05 readiness check failed with 1 item(s).`
  - `SUPABASE_SERVICE_ROLE_KEY` remains unset in effective env; fallback to `SUPABASE_SECRET_KEY` is shown in logs.
  - `SUPABASE_URL/rest/v1` probe still returns HTTP `401` (`curl: (56) The requested URL returned error: 401`).
  - `tools/verify_local_identity_claim.py --allow-remote-supabase` with `SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'`: `FAIL admin user creation failed: Invalid API key`.
  - `tools/verify_local_tenant_isolation.py --allow-remote-supabase` with `SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'`: `FAIL: admin user creation failed: Invalid API key`.
  - `verify_hosted_legal_documents.py` for `app.example.com` + `coverwise.app`: both still `URLError`.
  - `dig +short app.example.com` and `dig +short coverwise.app` still return no A/AAAA records.
  - `./.venv/bin/pytest -q tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py tests/test_verify_hosted_legal_documents.py` -> `8 passed in 0.02s`.

  - `./.venv/bin/pytest -q` result confirms local verifier harness still functions with current script/runtime setup; readiness remains blocked by missing valid auth input and deployed hostability.
  - Decision: no state transition; continue with Q2 owner-key unblock first, then Q3/Q4 replay, then Q5 hostability.

- **Timestamp:** `2026-07-25T13:06:48+05:30`  
  - `docker context show`: `desktop-linux`
  - `/Users/pranay/.docker/run/docker.sock` is present (`srwxr-xr-x`), `/var/run/docker.sock` remains symlink to it.
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'` returns `Client 29.6.2;Server 29.6.2`.
  - `docker ps -a` shows the Supabase stack containers in Running/healthy state.
  - `launchctl print gui/501/com.docker.helper`: `state = not running`, `job state = exited`, `runs = 20`, `last exit code = 0`.
  - `launchctl print system/com.docker.socket`: `state = not running`, `job state = exited`, `runs = 7`, `last exit code = 0`.
  - ENOSPC evidence still present in Docker host logs (`write .../Docker.raw: no space left on device`).
  - `~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw` remains `926G` virtual / `24G` allocated.
  - `tools/check_buyer_readiness_prereqs.sh --sourced-env` now blocked on 1 item:
    - `SUPABASE_URL/rest/v1` returns `401` via normalized `SUPABASE_SECRET_KEY` fallback.
    - `SUPABASE_SERVICE_ROLE_KEY` remains JWT-bearer-incompatible for BR-04/BR-05 admin auth.
  - `tools/verify_local_identity_claim.py --allow-remote-supabase` with placeholder key: `FAIL admin user creation failed: Invalid API key`.
  - `tools/verify_local_tenant_isolation.py --allow-remote-supabase` with placeholder key: `FAIL: admin user creation failed: Invalid API key`.
  - `verify_hosted_legal_documents.py` on `app.example.com` and `coverwise.app`: still `URLError`.
- **Additional one-item checkpoint:** `2026-07-25T13:06:48+05:30`
  - `set -a; ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `BLOCKED: BR-04/BR-05 readiness check failed with 1 item(s).`
    - `DockerVersion=29.6.2;Server=29.6.2`
    - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `set -a; ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - result: `FAIL admin user creation failed: Invalid API key`.
  - `set -a; ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - result: `FAIL: admin user creation failed: Invalid API key`.
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py` for both `app.example.com` and `coverwise.app`: both still `URLError`.
  - Decision: no state transition; keep Q2 as active blocker.
- **Additional one-item checkpoint:** `2026-07-25T13:04:44+05:30`
  - `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`:
    - `BLOCKED: BR-04/BR-05 readiness check failed with 1 item(s).`
    - `DockerVersion=29.6.2;Server=29.6.2`
    - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `set -a; ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`: `FAIL admin user creation failed: Invalid API key`.
  - `set -a; ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`: `FAIL: admin user creation failed: Invalid API key`.
  - Decision: no state transition; Q2 remains owner-key-only blocker.
- **Additional one-item checkpoint:** `2026-07-25T13:02:23+05:30`
  - `launchctl kickstart -k gui/501/com.docker.helper` (exit 0), `launchctl start gui/501/com.docker.helper` (exit 3), `launchctl start system/com.docker.socket` (exit 3).
  - Immediate state check shows `/Users/pranay/.docker/run/docker.sock` present and `docker ps -a` confirming daemon responsiveness.
  - `Q1` status moved to complete this pass; Q2 remains active.
- **Additional one-item checkpoint:** `2026-07-25T12:57:55+05:30`  
  - Re-ran `launchctl kickstart -k gui/501/com.docker.helper`, `launchctl start gui/501/com.docker.helper`, and `launchctl start system/com.docker.socket`; services returned to `state = not running` within ~2s.
  - `open`/daemon recovery still no socket creation.
  - `Q1` remains blocked by unresolved Docker init-space condition plus no API socket.
- **Additional one-item checkpoint:** `2026-07-25T12:59:19+05:30`  
  - Re-ran `tools/check_buyer_readiness_prereqs.sh`, `tools/verify_local_identity_claim.py`, `tools/verify_local_tenant_isolation.py`, and hosted legal checks with current in-session values:
    - `tools/check_buyer_readiness_prereqs.sh` remains `BLOCKED` on:
      - missing socket at `/Users/pranay/.docker/run/docker.sock`
      - fallback auth (`SUPABASE_SECRET_KEY`) `curl .../rest/v1` `401`
    - `tools/verify_local_identity_claim.py --allow-remote-supabase` (`COVERWISE_API_BASE_URL=http://127.0.0.1:8005`) now reaches admin/user flow, but:
      - `FAIL guest-to-account claim: HTTP 401 (Invalid or expired account token)`
      - `FAIL account profile: HTTP 401`
      - `FAIL: synthetic upload failed (HTTP 401, Invalid or expired account token)`
    - `tools/verify_local_tenant_isolation.py --allow-remote-supabase` now fails with JWT parse path:
      - `FAIL: admin user creation failed: invalid JWT: unable to parse or verify signature, token is unverifiable: error while executing keyfunc: unrecognized JWT kid <nil> for algorithm ES256`
    - `verify_hosted_legal_documents.py` against `app.example.com` and `coverwise.app` still `URLError`.
  - Decision: no status transition this pass; upstream blockers remain unresolved.
- **Service-role key check:** `2026-07-25T12:57:39+05:30`  
  - `.env` source has no direct `SUPABASE_SERVICE_ROLE_KEY`; only `SUPABASE_SECRET_KEY` and `SUPABASE_PUBLISHABLE_KEY` are present, both non-JWT.
  - `tools/check_buyer_readiness_prereqs.sh` still blocks on:
    - missing Docker socket, and
    - `/rest/v1` auth check via fallback key (401).
  - `tools/verify_local_identity_claim.py --allow-remote-supabase` fails at the auth flow with `Invalid or expired account token` and `HTTP 401` for claim/account profile due wrong/absent service key.
- **Hostability check:** `2026-07-25T12:58:20+05:30`  
  - `verify_hosted_legal_documents.py` against `app.example.com` and `coverwise.app` continues to return `URLError`; unresolved in this environment.
  - `https://example.com/privacy` / `/terms` still returns `HTTPError` in this session.

## Gate status
- **Q1** is now completed (daemon/socket reachable; readiness harness can query Docker).
- **Q2** remains blocked (missing/invalid `SUPABASE_SERVICE_ROLE_KEY` input required).
- **Q3/Q4** remain waiting on `Q1`/`Q2` and cannot be promoted.
- **Q5** remains blocked (hostability unresolved).
- **Q6/Q7/Q8** remain deferred until account/provider/runtime gates are available.

## One-item queue

- [x] **Q1 — Restore local Docker API socket + daemon health** ✅
  - **Owner/runtime dependency:** open helper/socket recovery and status checks executed.
  - **Evidence snapshot:** `/Users/pranay/.docker/run/docker.sock` now present (`srwxr-xr-x`); `docker version` returns `Client 29.6.2;Server 29.6.2`; `docker ps -a` shows live stack containers.
  - **Decision:** complete.

- [ ] **Q2 — Supply valid owner `SUPABASE_SERVICE_ROLE_KEY` (JWT service_role key)**
  - **Owner-only dependency:** key not present or malformed in session env (`SUPABASE_SERVICE_ROLE_KEY` length 0; fallback to `SUPABASE_SECRET_KEY` triggers `/rest/v1` 401).
  - **Evidence snapshot:** `tools/check_buyer_readiness_prereqs.sh` reports `FAIL: required env vars missing ... SUPABASE_SERVICE_ROLE_KEY` when env is not sourced, and `INFO: normalizing from SUPABASE_SECRET_KEY` + `WARN: SUPABASE_URL REST probe failed` when sourced.
  - **Decision:** still blocked.

- [ ] **Q3 — BR-04 real-credential identity continuity**
  - **Dependency:** Q2 must pass first.
  - **Current check:** executed with placeholder service-role key (`__PLACEHOLDER__`) -> `FAIL admin user creation failed: Invalid API key`.
  - **Decision:** blocked (expected without valid service-role key).

- [ ] **Q4 — BR-05 tenant-isolation continuity**
  - **Dependency:** Q3 must pass first.
  - **Current check:** executed with placeholder key -> `FAIL: admin user creation failed: Invalid API key`.
  - **Decision:** blocked (dependency not met).

- [ ] **Q5 — BR-06 hosted legal-page proof on canonical deployed URLs**
  - **Dependency:** deployed hostability + URLs must resolve.
  - **Evidence snapshot:** `verify_hosted_legal_documents.py` returns `URLError` for `app.example.com` and `coverwise.app`; `dig +short` resolves neither.
  - **Decision:** still blocked.

- [ ] **Q6 — BR-07 provider lifecycle proof**
  - **Dependency:** provider credentials and provider-side route/access.
  - **Decision:** deferred until owner credentials/runtime access is available.

- [ ] **Q7 — BR-12 store/distribution proof**
  - **Dependency:** store/developer-console credentials and release state.
  - **Decision:** deferred until owner account credentials are available.

- [ ] **Q8 — BR-13/14 buyer handover closeout**
  - **Dependency:** closure evidence rows in Q5–Q7.
  - **Decision:** deferred until upstream gates finish.

## Next explicit action (in order)
1. Obtain and set a valid owner JWT `SUPABASE_SERVICE_ROLE_KEY` in `.env`, then rerun `tools/check_buyer_readiness_prereqs.sh --sourced-env`.
2. Re-run **Q3** (`tools/verify_local_identity_claim.py --allow-remote-supabase`) immediately when Q2 passes.
3. Re-run **Q4** (`tools/verify_local_tenant_isolation.py --allow-remote-supabase`) after Q3 passes.
4. Re-run **Q5** (`verify_hosted_legal_documents.py`) against canonical live URLs once DNS/hosting resolves.
5. Complete **Q6/Q7/Q8** with owner provider/store credentials and signature evidence, then close BR-13/BR-14 package.
3. Re-run **Q3** then **Q4** with valid `SUPABASE_SERVICE_ROLE_KEY`.
4. Resolve deployed URL/DNS path and re-run **Q5**.
5. Run **Q6**/**Q7** with owner platform credentials, then finalize **Q8** handover closeout.
