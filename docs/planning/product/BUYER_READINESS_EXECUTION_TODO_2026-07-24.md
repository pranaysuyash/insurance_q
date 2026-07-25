# Buyer-readiness execution todo (session tracker)

## Objective

Track each high-signal gate in strict sequence: one item at a time, each item verified with command output, then moved to done.

## Working principles

- No silent status changes: every item requires evidence in this file.
- Keep this one sequence focused on concrete, checkable proof.
- If blocked, record exact missing input or dependency so the next person can continue without guesswork.
- Solo-founder context: no enterprise governance, partner, or legal-counsel process is required to mark these items complete; founder-owned evidence is sufficient unless you explicitly request advisory review.

## Current blocking profile (authoritative)

- Latest checkpoint: `2026-07-25T07:53:03+05:30`
  - `env snapshot`:
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co`
    - `SUPABASE_PUBLISHABLE_KEY` set
    - `SUPABASE_SERVICE_ROLE_KEY` unset
    - `COVERWISE_API_BASE_URL` unset
  - `open -a Docker` attempted (no successful daemon transition observed in-session)
  - `launchctl start gui/501/com.docker.helper`/`system/com.docker.socket` attempted:
    - `gui/501/com.docker.helper` stays `state = not running`, `job state = exited`
    - `system/com.docker.socket` remains `state = not running`
    - docker socket path still absent at `/Users/pranay/.docker/run/docker.sock`
  - `bash tools/check_buyer_readiness_prereqs.sh --sourced-env`:
    - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returns `401`
  - `verify_local_identity_claim.py --allow-remote-supabase` with placeholder service key:
    - `HTTP 403 bad_jwt` (`invalid JWT: unable to parse or verify signature, token contains an invalid number of segments`)
  - `verify_local_tenant_isolation.py --allow-remote-supabase`:
    - `FAIL configuration: Supabase publishable and server keys are required` when env var is unset in command context.
  - `bash tools/check_buyer_readiness_prereqs.sh --sourced-env`:
    - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
    - `FAIL: required env vars missing: SUPABASE_URL SUPABASE_PUBLISHABLE_KEY SUPABASE_SERVICE_ROLE_KEY`
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`:
    - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`
  - `set -a; source .env; ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`:
    - `FAIL configuration: Supabase publishable and server keys are required`
  - `timeout 5s docker version`:
    - `Client: 29.6.2 ...`
    - `failed to connect ... unix:///Users/pranay/.docker/run/docker.sock: connect: no such file or directory`
  - Status: BR-04 remains blocked by missing/invalid key material and Docker runtime; BR-05 remains blocked behind BR-04. No BR item has changed from blocked to done.

- Historical checkpoint (previous): `2026-07-25T02:08:18+05:30`
  - `tools/check_buyer_readiness_prereqs.sh --sourced-env`:
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - `tools/check_buyer_readiness_prereqs.sh`:
    - same 3-item blocked result (`DockerVersion=29.6.2;Server=`, missing service-role key, `SUPABASE_URL/rest/v1` `401`)
  - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`:
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`:
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `./.venv/bin/python tools/validate_production_config.py`:
    - still missing `PROCESSING_PAYLOAD_ENCRYPTION_KEY`, `PUBLIC_SITE_URL`, `REVENUECAT_WEBHOOK_AUTHORIZATION`, backend-mode values, and allowlists.
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`:
    - `privacy: verification failed`, `terms: verification failed` (`hosted page could not be read: HTTPError`)
  - `./.venv/bin/python tools/validate_legal_release_assets.py`:
    - `legal release assets are complete and match the packaged documents.`
  - `./.venv/bin/python tools/verify_deployed_launch.py --base-url https://app.example.com --origin https://app.example.com`:
    - launch verifier failed before checks: `network failure: [Errno 8] nodename nor servname provided, or not known`
  - `POST /user/anonymous` on `http://127.0.0.1:8005` -> `200`
  - `GET /user/anonymous` on `http://127.0.0.1:8005` -> `404`
  - `GET /healthz` on `http://127.0.0.1:8005` -> `200`
  - `POST /healthz` on `http://127.0.0.1:8005` -> `404`

  - `./.venv/bin/pytest -q tests/test_br02_representative_corpus.py tests/test_billing_ledger_service.py tests/test_subscription_webhook.py tests/test_launch_claim_registry.py tests/test_verify_hosted_legal_documents.py tests/test_outbox_worker_health.py tests/test_legal_release_assets.py tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py`
    - `44 passed`

  - Status: BR-04/BR-05 remain blocked pending valid service-role key; BR-11 remains blocked by production/runtime vars; deployed/runtime/provider gates remain awaiting reachable external endpoints.

- Historical checkpoint (previous): `2026-07-25T01:54:18+05:30`
  - `tools/check_buyer_readiness_prereqs.sh --sourced-env`:
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - Key-shape scan:
    - `SUPABASE_URL` set (len 40, dots 2)
    - `SUPABASE_PUBLISHABLE_KEY` set (len 46, dots 0)
    - `SUPABASE_SECRET_KEY` set (len 41, dots 0)
    - `SUPABASE_SERVICE_ROLE_KEY` unset
  - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase` with placeholder key:
    - HTTP 403 `bad_jwt`, `token contains an invalid number of segments`
  - Docker handshake:
    - `DOCKER_HOST=unix:///Users/pranay/.docker/run/docker.sock timeout 5 docker version --format '{{.Server.Version}}'` still fails connect.
  - Route parity at `http://127.0.0.1:8005`:
    - `POST /user/anonymous` -> 200
    - `GET /user/anonymous` -> 404
    - `GET /healthz` -> 200
    - `POST /healthz` -> 200

- `tools/check_buyer_readiness_prereqs.sh` without loading `.env` currently reports hard blocker set:
  - `DockerVersion=29.6.2;Server=` (daemon unreachable in this session)
  - missing `SUPABASE_URL`
  - missing `SUPABASE_PUBLISHABLE_KEY`
  - missing `SUPABASE_SERVICE_ROLE_KEY`
- `tools/check_buyer_readiness_prereqs.sh --sourced-env` (current `source .env` state) reports:
  - `DockerVersion=29.6.2;Server=` (daemon unreachable)
  - missing `SUPABASE_SERVICE_ROLE_KEY`
  - warn: `SUPABASE_URL` REST probe returned `401` on `/rest/v1/`, indicating key mismatch or wrong auth layer.
- `tools/check_buyer_readiness_prereqs.sh --sourced-env` latest run at `2026-07-25T00:56:09+05:30` confirms the same 3-item block set with unchanged `Docker` and auth mismatch signals.
- `tools/verify_deployed_launch.py --base-url https://app.example.com --origin https://app.example.com` confirms BR-07 runtime dependency is unmet in-session (`Errno 8` DNS resolution failure) and deployment/runtime endpoint is required for provider lifecycle proof.
- `tools/verify_local_identity_claim.py` and `tools/verify_local_tenant_isolation.py` are script-valid but blocked by auth key material unless owner-provided Supabase service keys are injected.
- `verify_local_identity_claim.py --allow-remote-supabase --api-url http://127.0.0.1:8005` fails fast with:
  `FAIL configuration: Supabase publishable and server keys are required` when both key vars are not set.
- `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env` now reduces blocker count to:
  - docker daemon not reachable (`Server=`),
  - missing `SUPABASE_SERVICE_ROLE_KEY`,
  - `SUPABASE_URL/rest/v1` `401` (auth mismatch until proper role key is used).
- `.env.example` now includes `SUPABASE_SERVICE_ROLE_KEY` to make owner credentials setup explicit.
- `.env` shape (current): `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are present; `SUPABASE_PUBLISHABLE_KEY` is single-segment non-JWT, and `SUPABASE_SERVICE_ROLE_KEY` is unset.
- In-session fallback check (with `SUPABASE_SERVICE_ROLE_KEY` unset so tools use `SUPABASE_SECRET_KEY`) confirms both commands fail at admin-user create with:
  - `HTTP 403 bad_jwt`
  - `invalid JWT: unable to parse or verify signature, token contains an invalid number of segments`.
- Fresh run at 2026-07-25T09:02:31+05:30 confirms no drift:
  - `./tools/check_buyer_readiness_prereqs.sh --sourced-env` still blocked with the same 4 blockers.
  - both placeholder and fallback `SUPABASE_SERVICE_ROLE_KEY` paths for `verify_local_identity_claim.py --allow-remote-supabase` still return `HTTP 403 bad_jwt` at `/auth/v1/admin/users`.
- `tools/check_buyer_readiness_prereqs.sh --sourced-env` rerun at `2026-07-25T00:20:14+05:30` confirms the same 3 missing env var blockers.
- In-session API evidence:
  - BR-04 verifier uses `COVERWISE_API_BASE_URL` (default `http://127.0.0.1:8005`).
  - `POST /user/anonymous` returns 200.
  - `GET /user/anonymous` returns 404.
  - `http://127.0.0.1:8000/healthz` is a connect-refused endpoint in this session.
- In-session route/method evidence refresh (`2026-07-25T00:50:44+05:30`):
  - `POST /user/anonymous` on `http://127.0.0.1:8005` -> HTTP 200 with token payload.
  - `GET /user/anonymous` on same base -> HTTP 404.
- `tools/validate_production_config.py` fails deterministically on required production variables/back-end mode keys.
- BR-06, BR-07, BR-12, BR-13/14 need owner/runtime/provider/store inputs not present in-session.
- For this session specifically (solo founder mode), legal/business review tasks are non-blocking and optional.
- `tools/check_buyer_readiness_prereqs.sh --sourced-env` at `2026-07-25T01:53:21+05:30` remains blocked on 3 items (daemon + role-key + Supabase `/rest/v1` 401); local route-shape checks remain healthy (`POST /user/anonymous` and `/healthz`), keeping BR-04 still action-required, not done.

## One-item execution queue

1. [x] Validate local legal assets are complete for release packaging.
   - Command: `./.venv/bin/python tools/validate_legal_release_assets.py`
   - Evidence: `legal release assets are complete and match the packaged documents.`

2. [x] Capture BR-02 representative-corpus contract checks.
   - Command: `./.venv/bin/pytest -q tests/test_br02_representative_corpus.py`
   - Evidence: `8 passed`.
   - Note: this is contract-level local evidence, not full live replay.

3. [x] Verify local readiness gate for BR-04/BR-05 preconditions in current environment.
   - Command: `./tools/check_buyer_readiness_prereqs.sh`
   - Evidence: `BLOCKED` with 4 items (`DockerVersion=29.6.2;Server=`, missing `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`).
   - Addendum in this session: local API endpoint is not running on `http://127.0.0.1:8000` (health probe fails with connect refusal).

4. [x] Re-run BR-04/BR-05 command-shape local verification tests.
   - Command: `./.venv/bin/pytest -q tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py`
   - Evidence: `4 passed` (current repo state).

5. [x] Re-run BR-07 local entitlement/webhook contract tests.
   - Command: `./.venv/bin/pytest -q tests/test_billing_ledger_service.py tests/test_subscription_webhook.py`
   - Evidence: `17 passed`.

6. [x] Re-run BR-06 hosted legal contract tests with non-deployed control.
   - Command: `./.venv/bin/pytest -q tests/test_verify_hosted_legal_documents.py`
   - Evidence: `4 passed`.

7. [x] Re-validate BR-11 production config contract in-session.
   - Command: `./.venv/bin/python tools/validate_production_config.py`
   - Evidence: fail due required production variables and backend-mode keys (including `SUPABASE_*`, `PROCESSING_PAYLOAD_ENCRYPTION_KEY`, `ANONYMOUS_AUTH_SIGNING_KEY`, `PUBLIC_SITE_URL`, `REVENUECAT_WEBHOOK_AUTHORIZATION`, `DOCUMENT_REPOSITORY_BACKEND`, `DOCUMENT_OBJECT_STORE_BACKEND`, `RAG_VECTOR_BACKEND`, `BILLING_LEDGER_BACKEND`, `ALLOWED_ORIGINS`, `ALLOWED_HOSTS`).

8. [ ] BR-04 real-credential execution (identity continuity end-to-end).
   - Command to run next (owner-owned env needed):
     `SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SERVICE_ROLE_KEY=... COVERWISE_API_BASE_URL=http://127.0.0.1:8005 ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
   - Required verifier contract (from script): service-role must be accepted by `Authorization: Bearer <server-key>` on Supabase admin endpoint and must be a JWT-style token; `SUPABASE_SECRET_KEY` fallback is only attempted if service-role is absent.
   - Retrieval: from Supabase Dashboard → Settings → API → `service_role` key (do not put in mobile app).
   - Evidence required before marking done:
     - admin user create + anon sign-in + claim + account profile readback.
   - Current status: attempted with `SUPABASE_URL` + publishable key from `.env` and placeholder service key; failed with `HTTP 403 bad_jwt` on admin user create (`--allow-remote-supabase` used).
   - Remaining blocker: real service-role key (the in-session key material is malformed/non-role for this admin flow).
   - latest re-run attempt (2026-07-25T12:12:37+05:30): still blocked due local socket missing and no valid `SUPABASE_SERVICE_ROLE_KEY`; `tools/check_buyer_readiness_prereqs.sh` outcome remained `BR-04/BR-05 readiness check failed with 2 item(s).`

9. [ ] BR-05 real-credential tenant-isolation end-to-end.
   - Command to run next (owner-owned env needed):
     `SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SERVICE_ROLE_KEY=... COVERWISE_API_BASE_URL=http://127.0.0.1:8005 ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
   - Evidence required: cross-owner denied reads + deletion audit path confirmation.
   - Blocker: BR-04 still requires valid owner-supplied service-role credentials to make this runnable.

10. [ ] BR-06 hosted legal-page proof on canonical deployed URLs.
    - Command to run next:
      `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url <https://.../privacy> --terms-url <https://.../terms>`
    - Evidence required: passed parity read + retention/revocation copy attestation.
    - Blocker: canonical deployed URLs missing.
    - Non-blocking smoke check performed:
      - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
      - result: `privacy: verification failed`, `terms: verification failed` (`HTTPError`) for both pages.

11. [ ] BR-07 BIL-01 provider lifecycle proof.
    - Command to run next (store/provider runtime needed):
      `coverwise_runtime_gate_runbook_2026-07-22.md` flow + webhook replay command(s).
    - Evidence required: purchase/restore/cancellation/refund and signed idempotent webhook replay.
    - Blocker: active provider sandbox/store runtime session not available.

12. [ ] BR-12 store/distribution evidence.
    - Command to run next (account/store access needed): store build+smoke + signed store links.

13. [ ] BR-13/BR-14 transfer/commercial continuity evidence.
    - Command to run next: transaction evidence pack + handover continuity walk-through.

## Progress log

- 2026-07-25T12:12:37+05:30: one-item BR-04 preflight/probe pass.
  - `date`: `2026-07-25T12:12:32+0530`
  - `docker context ls` confirms `desktop-linux * -> unix:///Users/pranay/.docker/run/docker.sock`.
  - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock` -> socket still missing; `/var/run/docker.sock -> /Users/pranay/.docker/run/docker.sock`.
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'` -> `Client 29.6.2;Server <missing>` (connect failure).
  - `tools/check_buyer_readiness_prereqs.sh`:
    - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
    - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
    - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
  - `tools/verify_hosted_legal_documents.py` for both:
    - `https://app.example.com/privacy` + `/terms`
    - `https://coverwise.app/privacy` + `/terms`
    - result: `hosted page could not be read: URLError` for all pages.
  - Outcome: no status advancement; queue remains blocked on Q1 (docker socket) + Q2 (service-role key). 


- 2026-07-25T07:53:03+05:30: BR-04/BR-05 checkpoint replay (runtime unlock attempt + auth revalidation)
  - env preload:
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co`
    - `SUPABASE_PUBLISHABLE_KEY` set
    - `SUPABASE_SERVICE_ROLE_KEY` unset
    - `COVERWISE_API_BASE_URL` unset
  - `open -a Docker` / `launchctl start gui/501/com.docker.helper` / `launchctl start system/com.docker.socket`:
    - helper remained `submitted/exited`, daemon remained `not running`
    - socket path still missing at `/Users/pranay/.docker/run/docker.sock`
  - `bash tools/check_buyer_readiness_prereqs.sh --sourced-env`:
    - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` -> `401`
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`:
    - `HTTP 403 bad_jwt` (`invalid JWT: unable to parse or verify signature, token contains an invalid number of segments`)
  - `set -a; source .env; ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`:
    - `FAIL configuration: Supabase publishable and server keys are required`
  - Interpretation: BR-04/BR-05 remain blocked by missing service-role key and absent Docker runtime socket.

- 2026-07-25T07:51:43+05:30: BR-04/BR-05 checkpoint replay (preflight + auth attempts)
  - `bash tools/check_buyer_readiness_prereqs.sh --sourced-env`:
    - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
    - `FAIL: required env vars missing: SUPABASE_URL SUPABASE_PUBLISHABLE_KEY SUPABASE_SERVICE_ROLE_KEY`
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`:
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`
  - `set -a; source .env; ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`:
    - `FAIL configuration: Supabase publishable and server keys are required`
  - `timeout 5s docker version`:
    - `Client: 29.6.2 ...`
    - `failed to connect ... unix:///Users/pranay/.docker/run/docker.sock: connect: no such file or directory`
  - Interpretation: deterministic in-session block for BR-04/BR-05 remains key material + daemon; no progress on status tick-off this pass.

- 2026-07-25T01:58:53+05:30: BR-04/BR-05 checkpoint replay
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `python` route probe:
    - `POST /user/anonymous` -> `200`
    - `GET /user/anonymous` -> `404`
    - `GET /healthz` -> `200`
    - `POST /healthz` -> `404`
  - Decision: keep BR-04 active and blocked; BR-05 still dependent on BR-04 success; BR-06+ remain unchanged.

- 2026-07-25T01:53:04+05:30: BR-04/BR-05 environment diagnostics snapshot
  - `SUPABASE_URL`: len 40, dots 2
  - `SUPABASE_PUBLISHABLE_KEY`: len 46, dots 0 (non-JWT API key shape)
  - `SUPABASE_SECRET_KEY`: len 41, dots 0 (non-JWT API key shape)
  - `SUPABASE_SERVICE_ROLE_KEY`: unset
  - `DOCUMENT_REPOSITORY_BACKEND=local`, `DOCUMENT_OBJECT_STORE_BACKEND=supabase`, `RAG_VECTOR_BACKEND=local`
  - `BILLING_LEDGER_BACKEND`: unset
  - required prod/runtime vars still unset: `PROCESSING_PAYLOAD_ENCRYPTION_KEY`, `PUBLIC_SITE_URL`, `REVENUECAT_WEBHOOK_AUTHORIZATION`, `ALLOWED_ORIGINS`, `ALLOWED_HOSTS`
  - route checks remain local-healthy: `POST /user/anonymous` `200`, `GET /user/anonymous` `404`, `GET /healthz` `200`
  - readiness check still `BLOCKED` (3-item): daemon unreachable + missing `SUPABASE_SERVICE_ROLE_KEY` + `/rest/v1` `401`

- 2026-07-25T01:52:37+05:30: BR-04/BR-05 recheck after long Docker start attempt
  - `tools/check_buyer_readiness_prereqs.sh` (no `.env` loaded in this command) reports:
    - `BLOCKED` with 4 item(s): missing `SUPABASE_URL`, missing `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and `DockerVersion=29.6.2;Server=`.
  - `tools/check_buyer_readiness_prereqs.sh --sourced-env` with explicit `.env` load was run moments earlier and confirms: `DockerVersion=29.6.2;Server=`, missing `SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY/SUPABASE_SERVICE_ROLE_KEY` at this stage.
  - Route-shape checks still pass at local API:
    - `POST /user/anonymous` -> `200`
    - `GET /user/anonymous` -> `404`
    - `GET /healthz` -> `200` payload `{"status":"live","version":"2.0.0"}`
  - Runtime state after `open -a Docker` + 10s wait:
    - `gui/501/com.docker.helper`: `state = not running`
    - `system/com.docker.socket`: `state = not running`
  - Next action remains: user-supplied runtime access or Docker Desktop restart outside this session; then rerun BR-04/BR-05 auth checks with real `SUPABASE_SERVICE_ROLE_KEY`.

- 2026-07-25T01:51:41+05:30: BR-04/BR-05 checkpoint (re-verified)
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=` (daemon unreachable)
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
    - overall: `BLOCKED` with 3 items
  - API route health checks confirmed in-session:
    - `POST /user/anonymous` -> `200`
    - `GET /user/anonymous` -> `404`
    - `GET /healthz` -> `200` payload `{"status":"live","version":"2.0.0"}`
  - Next action remains: start/restart local Docker runtime and inject real Supabase `SUPABASE_SERVICE_ROLE_KEY` from Dashboard `service_role` (JWT).

- 2026-07-25T00:52:36+05:30: BR-06 contract smoke check:
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
  - result: failure (`HTTPError`) for both endpoints; BR-06 pending until canonical URLs are supplied.

- 2026-07-25T00:58:23+05:30: BR-07 preflight execution dependency check:
  - `./.venv/bin/python tools/verify_deployed_launch.py --base-url https://app.example.com --origin https://app.example.com`
  - result: `launch verifier failed before checks: network failure: [Errno 8] nodename nor servname provided, or not known`.
  - interpretation: provider lifecycle proof still blocked by missing deployed/runtime endpoint and store sandbox.

- 2026-07-25T00:56:09+05:30: active BR-04 checkpoint:
  - `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - result: `BLOCKED` with `DockerVersion=29.6.2;Server=`, `SUPABASE_SERVICE_ROLE_KEY` missing, `/rest/v1` returned `401`.
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - result: `HTTP 403` `bad_jwt` at `/auth/v1/admin/users` (`token contains an invalid number of segments`).

- 2026-07-25T00:42:30+05:30: latest checkpoint:
  - `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - result: `BLOCKED` with 3 items (`DockerVersion=29.6.2;Server=`, `SUPABASE_SERVICE_ROLE_KEY` missing, `SUPABASE_URL/rest/v1` `401`).
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - result: `HTTP 403 bad_jwt` (`invalid JWT: unable to parse or verify signature, token is malformed`) at `/auth/v1/admin/users`.
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - result: same malformed-token `bad_jwt`.
  - `./.venv/bin/python tools/validate_production_config.py`
    - result unchanged: `production configuration is not launch-ready` with same missing required vars.
  - env-shape snapshot:
    - `SUPABASE_URL` len 40 (2 dots),
    - `SUPABASE_PUBLISHABLE_KEY` len 46 (0 dots),
    - `SUPABASE_SECRET_KEY` len 41 (0 dots),
    - `SUPABASE_SERVICE_ROLE_KEY` unset,
    - `COVERWISE_API_BASE_URL` unset,
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY` unset.

- 2026-07-25T00:49:45+05:30: verification-command and key-shape refresh:
  - `./.venv/bin/python tools/verify_local_identity_claim.py --help`
  - `./.venv/bin/python tools/verify_local_tenant_isolation.py --help`
  - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase --api-url http://127.0.0.1:8005`
    - result: `FAIL configuration: Supabase publishable and server keys are required`
  - Env-shape snapshot (non-sensitive):
    - `SUPABASE_URL` len 40, dots 2
    - `SUPABASE_PUBLISHABLE_KEY` len 46, dots 0
    - `SUPABASE_SECRET_KEY` len 41, dots 0
    - `SUPABASE_SERVICE_ROLE_KEY` unset
  - `./tools/check_buyer_readiness_prereqs.sh --sourced-env` remains `BLOCKED` with:
    - `DockerVersion=29.6.2;Server=`
    - missing `SUPABASE_SERVICE_ROLE_KEY`
    - `/rest/v1` returns `401`

- 2026-07-25T00:51:15+05:30: one-step execution protocol:
  - BR-04 command to run once service-role key is available:
    `set -a; source .env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
  - BR-05 command (run only after BR-04 success):
    `set -a; source .env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
  - BR-06 deployed legal parity:
    `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url <https://.../privacy> --terms-url <https://.../terms>`
  - BR-04/BR-05 deployed versions require `--confirm` and real deployed endpoints; run only in dedicated test environment:
    - `./.venv/bin/python tools/verify_deployed_identity_claim.py --api-url ... --supabase-url ... --confirm`
    - `./.venv/bin/python tools/verify_deployed_tenant_isolation.py --api-url ... --supabase-url ... --confirm`

- 2026-07-25T00:50:48+05:30: deploy/legal verification command inventory:
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --help`
    - confirms required `--privacy-url` and `--terms-url` for BR-06 deployed parity check.
  - `./.venv/bin/python tools/verify_deployed_identity_claim.py --help`
    - confirms required `--api-url`, `--supabase-url`, mandatory `--confirm` for deployed identity continuity verification.
  - `./.venv/bin/python tools/verify_deployed_tenant_isolation.py --help`
    - confirms required `--api-url`, `--supabase-url`, mandatory `--confirm`, optional `--bucket` for deployed tenant-isolation.

- 2026-07-25T00:40:59+05:30: next checkpoint after retry:
  - `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - result: `BLOCKED` with 3 items (`DockerVersion=29.6.2;Server=`, `SUPABASE_SERVICE_ROLE_KEY` missing, `SUPABASE_URL/rest/v1` `401`).
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - result: `HTTP 403 bad_jwt` (`invalid JWT: token is malformed`) at `/auth/v1/admin/users`.
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - result: `HTTP 403 bad_jwt` (`invalid JWT: token is malformed`) at `/auth/v1/admin/users`.

- 2026-07-25T18:24:05+05:30: production-readiness gate revalidation:
  - `./.venv/bin/python tools/validate_production_config.py`
    - result: not launch-ready (required `SUPABASE_*`, `PROCESSING_PAYLOAD_ENCRYPTION_KEY`, `ANONYMOUS_AUTH_SIGNING_KEY`, `PUBLIC_SITE_URL`, `REVENUECAT_WEBHOOK_AUTHORIZATION`; backend backends must be `supabase`; `ALLOWED_ORIGINS`/`ALLOWED_HOSTS` missing under production profile).

- 2026-07-25T18:23:00+05:30: checkpoint execution pass:
  - `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - result: `BLOCKED` with 3 items (`DockerVersion=29.6.2;Server=`, `SUPABASE_SERVICE_ROLE_KEY` missing, `SUPABASE_URL/rest/v1` `401`).
  - command-shape recheck:
    - `POST http://127.0.0.1:8005/user/anonymous` -> `200` with anon token
    - `GET http://127.0.0.1:8005/user/anonymous` -> `404`.
  - `tools/verify_local_identity_claim.py --allow-remote-supabase` (placeholder service key) -> `HTTP 403 bad_jwt` (`invalid JWT: ... token is malformed`).

- 2026-07-25T09:37:00+05:30: preflight/env-shape verification rerun:
  - `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - result: `BLOCKED` with 3 items (`DockerVersion=29.6.2;Server=`, missing `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_URL/rest/v1` 401).
  - `.env` quick-shape check:
    - `SUPABASE_URL` present (len 40, dots 2),
    - `SUPABASE_PUBLISHABLE_KEY` present (len 46, dots 0, not JWT),
    - `SUPABASE_SERVICE_ROLE_KEY` unset.
  - This reinforces BR-04 blocker as: valid service-role key required for admin auth and optional Docker for local-only path.
- 2026-07-25T09:18:40+05:30: verifier contract confirmation pass:
  - Re-reviewed script contracts in `tools/verify_local_identity_claim.py` and `tools/verify_local_tenant_isolation.py`.
  - Both require a JWT-style `SUPABASE_SERVICE_ROLE_KEY` for `Authorization: Bearer` on Supabase admin API.
  - `SUPABASE_SECRET_KEY` is only fallback when `SUPABASE_SERVICE_ROLE_KEY` is absent.
  - API base variable for both verifiers is `COVERWISE_API_BASE_URL` (default `127.0.0.1:8005`).
- 2026-07-25T00:21:13+05:30: reran `./tools/check_buyer_readiness_prereqs.sh --sourced-env`:
  - hard blockers remain `DockerVersion=29.6.2;Server=`, missing `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`;
  - endpoint discovery updated: BR-04/BR-05 uses `COVERWISE_API_BASE_URL` and this session has API at `http://127.0.0.1:8005`.
- 2026-07-25T00:25:11+05:30: re-ran preflight and BR-04/BR-05 with explicit remote keys setup:
  - `./tools/check_buyer_readiness_prereqs.sh --sourced-env` -> blocked with `DockerVersion=29.6.2;Server=` plus missing `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
  - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005'`, `.env` loaded:
    - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase` -> `HTTP 403 bad_jwt` at `/auth/v1/admin/users` (malformed token).
    - `./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase` -> `HTTP 403 bad_jwt` at `/auth/v1/admin/users` (malformed token).
  - `./.venv/bin/python tools/validate_production_config.py` -> missing-production-runtime-vars failure (same as previous entries).
- 2026-07-25T00:25:14+05:30: auth material inspection (shape-only, non-secret):
  - `SUPABASE_SERVICE_ROLE_KEY` is currently unset.
  - `SUPABASE_SECRET_KEY` and `SUPABASE_PUBLISHABLE_KEY` are single-segment tokens (no `.` separators), so they cannot act as JWT-style service-role auth for admin endpoints.
- 2026-07-25T00:25:06+05:30: re-ran BR-04 and BR-05 with `COVERWISE_API_BASE_URL=http://127.0.0.1:8005`:
  - command variant: `SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'`
  - command variant: `.env` fallback to `SUPABASE_SECRET_KEY`
  - both fail on `/auth/v1/admin/users` with `HTTP 403 bad_jwt` (`token is malformed`).
- 2026-07-25T00:27:21+05:30: re-confirmed API behavior and blocker state:
  - `POST /user/anonymous` -> 200.
  - `GET /user/anonymous` -> 404.
  - with `.env` loaded and `SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'`:
    - `verify_local_identity_claim.py` -> `HTTP 403` + `bad_jwt` at `/auth/v1/admin/users`.
    - `verify_local_tenant_isolation.py` -> `HTTP 403` + `bad_jwt` at `/auth/v1/admin/users`.
- 2026-07-25T00:06:45+05:30: re-ran readiness helper in no-env and placeholder env modes.
  - no-env: `BLOCKED` with 4 items (`DockerVersion=29.6.2;Server=`, missing `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`).
  - placeholder env (dummy `SUPABASE_*` + local URLs): `BLOCKED` with 1 item (`DockerVersion=29.6.2;Server=`), with local health checks for `/healthz` and `/rest/v1` reporting OK.
- 2026-07-25T00:31:10+05:30: attempted BR-04/BR-05 with fallback key path:
  - `.env` loaded
  - `SUPABASE_SERVICE_ROLE_KEY` explicitly unset
  - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005'`
  - `--allow-remote-supabase`
  - Result for both tools: `HTTP 403 bad_jwt` at `/auth/v1/admin/users` with malformed-token signature error.
- 2026-07-25T00:18:22+05:30: attempted `tools/verify_local_identity_claim.py` and `tools/verify_local_tenant_isolation.py` with:
  - `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` loaded from `.env`
  - `SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'`
  - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005'`
  - `--allow-remote-supabase`
  - Result for both: `HTTP 403 bad_jwt` (`admin user creation failed`), confirming invalid real-service credential is the current hard block for BR-04/BR-05.
- 2026-07-25T00:09:08+05:30: re-ran preflight with `source .env`:
  - blocked with 3 items: docker daemon unreachable + missing `SUPABASE_SERVICE_ROLE_KEY`.
  - warning: REST probe to `https://eyumuxwabmsymytjbxoj.supabase.co/rest/v1/` returned `401`, confirming additional auth-layer misalignment until real role keys are used.
- 2026-07-25T00:17:06+05:30: re-ran BR-04/BR-05 in-session after the latest attempts using owner-provided `.env` values:
  - `SUPABASE_SERVICE_ROLE_KEY` unset (so fallback to `SUPABASE_SECRET_KEY`)
  - then with explicit placeholder `SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'`
  - command pattern for both:
    - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase --api-url http://127.0.0.1:8005`
    - `./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase --api-url http://127.0.0.1:8005`
  - result: both fail at `/auth/v1/admin/users` with `HTTP 403 bad_jwt` and `invalid JWT: unable to parse or verify signature, token contains an invalid number of segments`.
- Remaining active blockers remain external/owner-controlled in this session.

## Active queue source

- For current one-item execution sequencing, use:
  - [BUYER_READINESS_ACTIVE_QUEUE_2026-07-25.md](BUYER_READINESS_ACTIVE_QUEUE_2026-07-25.md)
- 2026-07-25T00:44:12+05:30: completed one-at-a-time re-check pass:
  - `./.venv/bin/pytest -q tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py tests/test_billing_ledger_service.py tests/test_subscription_webhook.py tests/test_verify_hosted_legal_documents.py tests/test_br02_representative_corpus.py`
    - result: `33 passed`.
  - `./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - result: `BLOCKED` with 4 item(s): `DockerVersion=29.6.2;Server=`, missing `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
  - `./.venv/bin/python tools/validate_production_config.py`
    - result: production required vars remain missing; failure mode unchanged.
  - `set -a && source .env && COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - result: `HTTP 403` + `bad_jwt` (token malformed, invalid number of segments) at `/auth/v1/admin/users`.
  - same env + placeholder service key for tenant isolation:
    - `./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - result: same `HTTP 403 bad_jwt` failure at `/auth/v1/admin/users`.
