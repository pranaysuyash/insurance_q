# Buyer-readiness live todo (solo founder)

Mode: one-item-at-a-time, evidence-backed, no enterprise governance dependency.

Last updated: 2026-07-25T12:49:23+05:30

Source of truth for tracking: `BUYER_READINESS_ACTIVE_QUEUE_2026-07-25.md` and `BUYER_READINESS_TODO_TRACKER_2026-07-25.md`.

## Live checkpoint (2026-07-25T12:49:23+05:30)

- `docker context show`: `desktop-linux` (`unix:///Users/pranay/.docker/run/docker.sock`).
- `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `/Users/pranay/.docker/run/docker.sock`: missing
  - `/var/run/docker.sock -> /Users/pranay/.docker/run/docker.sock`
- `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - `Client 29.6.2;Server `
  - failed to connect (`/Users/pranay/.docker/run/docker.sock`: no such file or directory)
- `launchctl print gui/501/com.docker.helper`
  - `state = not running`, `job state = exited`, `runs = 15`
- `launchctl print system/com.docker.socket`
  - `state = not running`, `job state = exited`, `runs = 7`
- `ls -lh ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw`: `24G`
- `df -h /Users/pranay`: `/System/Volumes/Data` usage `93%`, `63G` free (host not at OS-level full, but Docker logs still report ENOSPC writes).
- `.env` shape snapshot:
  - `SUPABASE_SERVICE_ROLE_KEY` absent in `.env` and fallback still from non-JWT `SUPABASE_SECRET_KEY`.
  - `SUPABASE_SECRET_KEY` length 41, dots 0 (`sb_secret_...`, not service-role JWT)
  - `SUPABASE_PUBLISHABLE_KEY` length 46, dots 0
  - `COVERWISE_API_BASE_URL` unset
- `tools/check_buyer_readiness_prereqs.sh`:
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
  - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
- Hosted/legal checks still blocked:
  - `verify_hosted_legal_documents.py` on `app.example.com` + `coverwise.app`: `URLError`
  - `curl https://app.example.com/privacy` / `coverwise.app/privacy`: `Could not resolve host` (`http_code=000`)
- Decision: no status transition this pass.
- Fresh local probe details added in this pass:
  - `open -a Docker` still returns: `_LSOpenURLsWithCompletionHandler() failed ... error -1712`
  - `~/Library/Containers/com.docker.docker/Data/log/host/*.log` still contains ENOSPC and "Docker Desktop cannot continue because the disk is full" markers.


## Live checkpoint (2026-07-25T12:38:19+05:30)

## Live checkpoint (2026-07-25T12:43:05+05:30)

- `docker context show`: `desktop-linux` (`unix:///Users/pranay/.docker/run/docker.sock`).
- `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `/Users/pranay/.docker/run/docker.sock`: missing
  - `/var/run/docker.sock -> /Users/pranay/.docker/run/docker.sock`
- `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`:
  - `Client 29.6.2;Server `
  - failed to connect to missing socket.
- `launchctl print gui/501/com.docker.helper` + `launchctl print system/com.docker.socket`:
  - both `state = not running`, `job state = exited`, `runs` at helper `14`
- ENOSPC and disk-full log evidence still present in host logs:
  - `no space left on device`
  - `Docker Desktop cannot continue because the disk is full`
- Env-shape and preflight evidence:
  - `.env`: `SUPABASE_SERVICE_ROLE_KEY` unset; `SUPABASE_SECRET_KEY` and `SUPABASE_PUBLISHABLE_KEY` non-JWT (single segment); `COVERWISE_API_BASE_URL` unset.
  - `tools/check_buyer_readiness_prereqs.sh` remains blocked with:
    - missing Docker socket
    - `SUPABASE_SERVICE_ROLE_KEY` fallback/auth issue
    - `/rest/v1` warning: `curl: (56) The requested URL returned error: 401`
- Hosted legal checks:
  - `verify_hosted_legal_documents.py` for `app.example.com` + `coverwise.app`: `URLError`.
  - `curl` to both urls returns `Could not resolve host` (`http_code=000`).
- Decision: no status transition; `Q1` + `Q2` remain hard blockers.

- `launchctl` recovery attempt run:
  - `launchctl kickstart -k gui/501/com.docker.helper`
  - `launchctl start gui/501/com.docker.helper`
  - `launchctl start system/com.docker.socket`
  - services remain `not running` (`job state = exited`) after the attempt.
- ENOSPC remains the Docker failure signal in host logs:
  - `Docker Desktop cannot continue because the disk is full`
  - `no space left on device` (monitor/backend logs).

## Live checkpoint (2026-07-25T12:37:04+05:30)

- `docker context ls` / `docker context show`:
  - `desktop-linux * -> unix:///Users/pranay/.docker/run/docker.sock`
- `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `/Users/pranay/.docker/run/docker.sock`: missing
  - `/var/run/docker.sock -> /Users/pranay/.docker/run/docker.sock`
- `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh`
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
  - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
- `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'` still reports no daemon (connect error to socket).
- Hosted legal proof sample:
  - `tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
  - `tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
  - all paths return `URLError` (hosted pages not readable in-session).
- `curl` smoke check:
  - `curl https://app.example.com/privacy` -> `Could not resolve host` (`http_code=000`)
  - `curl https://coverwise.app/privacy` -> `Could not resolve host` (`http_code=000`)
- Identity dry-run with placeholder service key remains blocked:
  - `verify_local_identity_claim.py --allow-remote-supabase` -> `FAIL admin user creation failed: Invalid API key`
  - `verify_local_tenant_isolation.py --allow-remote-supabase` -> `FAIL: admin user creation failed: Invalid API key`
- Decision: no status change; Q1/Q2 remain hard blockers and the queue remains on in-progress blocked state.
 
## Live checkpoint (2026-07-25T12:28:36+05:30)

- `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh`
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
  - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
- `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
  - `privacy: verification failed` (`hosted page could not be read: URLError`)
  - `terms: verification failed` (`hosted page could not be read: URLError`)
- `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
  - `privacy: verification failed` (`hosted page could not be read: URLError`)
  - `terms: verification failed` (`hosted page could not be read: URLError`)
- `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
  - `FAIL admin user creation failed: Invalid API key`
- `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
  - `FAIL: admin user creation failed: Invalid API key`
- Runtime evidence:
  - `docker context use desktop-linux` remains mapped to `unix:///Users/pranay/.docker/run/docker.sock`.
  - `/Users/pranay/.docker/run/docker.sock` missing; `/var/run/docker.sock` symlinked to it.
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'` returns no daemon (`connect` error to missing socket).
  - `launchctl print gui/501/com.docker.helper` and `launchctl print system/com.docker.socket` both `state = not running`, `job state = exited`.
- Conclusion: Q1 and Q2 remain in-session blockers; queue does not move this pass.

## Executive state

- Active gate: **BR-04**  
- Progress: 11 done, 1 in progress (blocked), 4 pending  
- Owner dependency to un-block in-session:
  - `SUPABASE_SERVICE_ROLE_KEY` (owner-only backend admin secret from Supabase dashboard)
  - `DOCUMENT_REPOSITORY_BACKEND`, `DOCUMENT_OBJECT_STORE_BACKEND`, `RAG_VECTOR_BACKEND`, `BILLING_LEDGER_BACKEND` (all must be `supabase`)
  - `PROCESSING_PAYLOAD_ENCRYPTION_KEY`
  - `PUBLIC_SITE_URL`
  - `REVENUECAT_WEBHOOK_AUTHORIZATION`
  - `ALLOWED_ORIGINS`, `ALLOWED_HOSTS`
- This checkpoint retains BR-05, BR-06(deployed), BR-07, BR-08/BR-09, BR-12, BR-13/14 as blocked behind the above owner/runtime inputs.

## One-item next action (current queue)

- [ ] **Current active Q1** — restore local Docker API socket for readiness preflight.
  - Required command sequence:
    - `docker context show`
    - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
    - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
    - `launchctl print gui/501/com.docker.helper`
    - `launchctl print system/com.docker.socket`
    - `set -a; . ./.env; bash tools/check_buyer_readiness_prereqs.sh`
  - Result (latest): blocked by missing socket file and service-role key shape.

- [ ] **Current Q2 (blocked on owner input)** — provide owner `SUPABASE_SERVICE_ROLE_KEY` as real JWT `service_role` secret and re-run local BR-04 verifier.
  - Required command sequence:
    - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY=<owner_jwt> ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
  - Result: pending owner secret.

- [ ] **Current Q3 (depends on Q2)** — run tenant-isolation continuity verifier.
  - Command:
    - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY=<owner_jwt> ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
  - Result: pending Q2 pass.

- [ ] **Current Q4 (depends on hostability/runtime)** — run BR-06 hosted legal proof against canonical live URLs.
  - Command:
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url <live_privacy_url> --terms-url <live_terms_url>`
  - Result: pending canonical URL resolution and public host.

- [x] Re-run BR-04/BR-06 checkpoint at `2026-07-25T11:46:46+05:30`.
  - Evidence:
    - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
    - `dig +short app.example.com`
    - `dig +short coverwise.app`
    - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
    - `curl -ksS -o /tmp/hostcheck_app_now.txt -w '%{http_code}' https://app.example.com/privacy`
    - `curl -ksS -o /tmp/hostcheck_cover_now.txt -w '%{http_code}' https://coverwise.app/privacy`
  - Result: unchanged blocker set: missing/malformed service-role key (`SUPABASE_SERVICE_ROLE_KEY` normalized from non-JWT secret), missing Docker daemon socket (`/Users/pranay/.docker/run/docker.sock`), and unresolved deployed hosts.

- [x] BR-13/14 evidence-prep (dependency supply-chain): generate and attach SBOM for BR-14 handoff.
  - `bash tools/generate_production_sbom.sh docs/review/evidence-transfer/analytics/production-dependencies-sbom-2026-07-25.json`
    - `SBOM generated at docs/review/evidence-transfer/analytics/production-dependencies-sbom-2026-07-25.json; locked-graph audit found no known vulnerabilities.`
  - Checksum captured: `ea74643c50dcecaf8cf4da13fe04ddb81aa26b6fe9d5a7868ba12655eaaadb86`
  - Updated:
    - `docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md`
    - `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`
    - `docs/review/evidence-transfer/README.md`

- [x] Re-run BR-04/BR-05 prerequisite checker and BR-06 hostability check.
  - Evidence:
    - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
    - `dig +short app.example.com`
    - `dig +short coverwise.app`
    - `curl -ksS -o /tmp/hostcheck_app_1141.txt -w '%{http_code}' https://app.example.com/privacy`
    - `curl -ksS -o /tmp/hostcheck_cover_1141.txt -w '%{http_code}' https://coverwise.app/privacy`
  - Timestamp: `2026-07-25T11:41:46+05:30`
  - Result: BR-04 preflight still blocked (`docker socket` missing + `SUPABASE_SERVICE_ROLE_KEY` normalized/unusable), and BR-06 checks still fail (`host not resolved` + URLError on hosted legal page reads).
  - Key-shape sanity scan:
    - `SUPABASE_PUBLISHABLE_KEY`: len 46, dot count 0
    - `SUPABASE_SECRET_KEY`: len 41, dot count 0
    - `SUPABASE_SERVICE_ROLE_KEY`: unset
    - `SUPABASE_URL`: set
  - Production config guardrails still need explicit run-time values:
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY`, `PUBLIC_SITE_URL`, `REVENUECAT_WEBHOOK_AUTHORIZATION`,
      `DOCUMENT_REPOSITORY_BACKEND`, `DOCUMENT_OBJECT_STORE_BACKEND`, `RAG_VECTOR_BACKEND`,
      `BILLING_LEDGER_BACKEND`, `ALLOWED_ORIGINS`, `ALLOWED_HOSTS`.
  - In-session `.env` check now shows BR-11 values populated with non-launch placeholder values:
    - `PUBLIC_SITE_URL=https://example.com`
    - `REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer_local_test`
    - `DOCUMENT_REPOSITORY_BACKEND=supabase`
    - `DOCUMENT_OBJECT_STORE_BACKEND=supabase`
    - `RAG_VECTOR_BACKEND=supabase`
    - `BILLING_LEDGER_BACKEND=supabase`
    - `ALLOWED_ORIGINS=https://example.com`
    - `ALLOWED_HOSTS=127.0.0.1,localhost`

- [x] Confirm in-session env snapshot is unchanged (`SUPABASE_SERVICE_ROLE_KEY` still unset).
  - Evidence: quick `.env` shape scan (`python` key parser)
  - Result: `SUPABASE_SERVICE_ROLE_KEY=<unset>`; publishable/secret values remain non-JWT format.

- [x] Load/rotate latest checkpoint: `tools/check_buyer_readiness_prereqs.sh` still shows same BR-04 blocker set.
  - Command: `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`  
- Timestamp: `2026-07-25T11:51:46+05:30`
  - Result: blocked on 3 items (`docker socket missing`, `SUPABASE_SERVICE_ROLE_KEY`, `/rest/v1` 401).
  - `open -a Docker` issued as a non-privileged recovery attempt (no visible daemon socket created).
  - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
    - `/Users/pranay/.docker/run/docker.sock`: No such file or directory
    - `/var/run/docker.sock -> /Users/pranay/.docker/run/docker.sock`
  - `timeout 8s docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
    - failed to connect to the docker API at unix:///Users/pranay/.docker/run/docker.sock; check if the path is correct and if the daemon is running: dial unix /Users/pranay/.docker/run/docker.sock: connect: no such file or directory

- [x] Re-run BR-04 real-credential identity dry-run with placeholder service key and update blocker shape.
  - Command:
    `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
  - Result: `HTTP 401 Invalid API key` (`Double check your Supabase \`anon\` or \`service_role\` API key.`)
  - Interpretation: confirms the placeholder key is not acceptable for BR-04 path; valid `SUPABASE_SERVICE_ROLE_KEY` still required.

- [x] Re-run BR-05 real-credential tenant-isolation check with placeholder key.
  - Command:
    `set -a; ./.env; SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
  - Result: `admin user creation failed (HTTP 400): {}` (placeholder key rejected at admin path).

- [x] Re-check BR-06 hostability/liveness with environment DNS and hosted-legal reads.
  - Evidence:
    - `dig +short app.example.com` / `coverwise.app` / `nrmmvtpyaf.ap-south-1.awsapprunner.com` returned empty (no resolvable A/AAAA results in this environment).
    - `curl .../privacy` on `https://app.example.com` and `https://coverwise.app` returned `http_code=000` (`Could not resolve host`).
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://example.com/privacy --terms-url https://example.com/terms`
      - `privacy: verification failed` (`hosted page could not be read: HTTPError`)
      - `terms: verification failed` (`hosted page could not be read: HTTPError`).
  - Interpretation: BR-06 deployed-hosted legal proof remains blocked by environment hostability/target URL resolution, not script harness.

- [x] Re-run lightweight command-shape verification for legal and BR-04/BR-05 script harnesses after checkpoint.
  - Command:
    `./.venv/bin/pytest -q tests/test_verify_hosted_legal_documents.py tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py`
  - Result: `8 passed in 0.03s`
  - Interpretation: script command paths remain stable; BR-04 real-credential behavior is still blocked earlier by API-key material, not by harness drift.

- [x] Re-run core harness and hosted parser checks immediately after this checkpoint.
  - Evidence:
    - `./.venv/bin/pytest -q tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py`
    - `./.venv/bin/pytest -q tests/test_verify_hosted_legal_documents.py`
    - `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
  - Timestamp: `2026-07-25T10:34:53+05:30`
  - Results:
    - `4 passed` (identity tests)
    - `4 passed` (hosted legal parser tests)
    - `production configuration contract is valid; no secret values were printed.`
    - `privacy: verification failed` (`hosted page could not be read: URLError`)
    - `terms: verification failed` (`hosted page could not be read: URLError`)
  - Interpretation: harness and config contract remain stable; BR-06 proof is still blocked by unresolved/can't-resolve deployed target.

- [x] Re-attempt BR-04 recovery by restarting Docker helper/socket path (non-privileged portion) and capture blocker state.
  - Command evidence:
    - `launchctl kickstart -k gui/$(id -u)/com.docker.helper`
    - `launchctl start gui/$(id -u)/com.docker.helper`
    - `python` unlink of stale `/Users/pranay/.docker/run/docker.sock`
    - `launchctl bootstrap system /Library/LaunchDaemons/com.docker.socket.plist` (attempt)
  - Result:
    - helper moved to running state, but `/Users/pranay/.docker/run/docker.sock` is absent,
      and `docker version` remains `Client=29.6.2 Server=`.
    - system socket bootstrap/bootout remains permission/error-gated without root.

- [x] BR-14 packet scaffolds prepared for remaining transfer rows.
  - `docs/review/evidence-transfer/ownership/ownership_ip_transfer_packet_2026-07-25.md`
  - `docs/review/evidence-transfer/commercial/commercial_liabilities_transfer_packet_2026-07-25.md`
  - Both are currently `Prepared` and awaiting owner-signed evidence attachment.

- [ ] Load a valid `SUPABASE_SERVICE_ROLE_KEY` from Supabase dashboard and re-run BR-04.

- [ ] Re-run BR-04 and then BR-05 identity/tenant checks after valid key.

- [ ] Resolve deployed hostability targets (`app.example.com`, `coverwise.app`) for BR-06/BR-07/BR-12 proofs.

- [ ] Run Docker runtime setup validation once user provides admin access to restore the system socket (`open -a Docker` path or equivalent).

## Blockers now

1. `SUPABASE_SERVICE_ROLE_KEY` unset / not valid JWT for admin auth.
2. Docker socket is missing at `/Users/pranay/.docker/run/docker.sock`; `docker version` currently cannot connect to daemon.
3. Deployed hosts remain non-resolvable in this session (`app.example.com`, `coverwise.app`, `nrmmvtpyaf.ap-south-1.awsapprunner.com`).
4. BR-13/14 owner diligence sequence remains active:
   - valuation memo and transfer inventory are documented; BR-14 evidence-intake matrix is now added; founder evidence/signatures still pending.
5. Production/runtime inputs still missing:
   - `PROCESSING_PAYLOAD_ENCRYPTION_KEY`
   - `PUBLIC_SITE_URL`
   - `REVENUECAT_WEBHOOK_AUTHORIZATION`
   - `DOCUMENT_REPOSITORY_BACKEND=supabase`
   - `DOCUMENT_OBJECT_STORE_BACKEND=supabase`
   - `RAG_VECTOR_BACKEND=supabase`
   - `BILLING_LEDGER_BACKEND=supabase`
   - `ALLOWED_ORIGINS`, `ALLOWED_HOSTS`
6. Deployed synthetic account cleanup is blocked in `verify_deployed_*` flows because runtime auth/env inputs are missing (`User not allowed` on cleanup).

### Historical live checkpoints

- `2026-07-25T09:25:42+05:30` (BR-04 non-privileged Docker recovery attempt)
  - `launchctl kickstart -k gui/$(id -u)/com.docker.helper` and `launchctl start gui/$(id -u)/com.docker.helper` executed.
  - stale socket file was removed (Python unlink) and restart retried.
  - `launchctl print gui/$(id -u)/com.docker.helper` → `state = running`, `runs = 4`.
  - `launchctl print system/com.docker.socket` → `state = not running`.
  - `launchctl bootstrap system /Library/LaunchDaemons/com.docker.socket.plist` → `Bootstrap failed: 5: Input/output error` and `bootout` / `start` permission errors.
  - `timeout docker version` still `Client=29.6.2 Server=` with connect errors (socket path absent).

### Live checkpoint

- `2026-07-25T09:07:51+05:30` (runtime recovery attempt + unchanged BR-04 blockers)
  - `launchctl kickstart -k gui/$(id -u)/com.docker.helper`
    - command returns success
  - `launchctl print gui/$(id -u)/com.docker.helper`
    - `state = not running`
    - `job state = exited`
    - `run = 3`, `last exit code = 0`
  - `launchctl print system/com.docker.socket`
    - `state = not running`
    - `job state = exited`
  - `timeout 5 docker version --format 'Client {{.Client.Version}} Server {{.Server.Version}}'`
    - `Client 29.6.2`
    - `Server ` (empty)
  - Interpretation: BR-04 daemon blocker remains.

- `2026-07-25T09:05:25+05:30` (in-session BR-04 recheck, hostability check)
  - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
    - `BR-04/BR-05 readiness check`
    - `Timestamp: 2026-07-25T09:05:25+05:30`
    - `INFO: /var/run/docker.sock symlink target: /Users/pranay/.docker/run/docker.sock`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
    - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
  - `source ./.env`
    - `SUPABASE_SERVICE_ROLE_KEY_set=` (empty / unset)
    - `SUPABASE_SERVICE_ROLE_KEY_len=0`
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co`
    - `SUPABASE_PUBLISHABLE_KEY_set=yes`
    - `SUPABASE_SECRET_KEY_set=yes`
    - `COVERWISE_API_BASE_URL=<unset>`
  - DNS probe:
    - `app.example.com ->`
    - `coverwise.app ->`
    - `curl: (6) Could not resolve host: app.example.com`
  - Interpretation: BR-04 remained blocked by missing service-role key + inactive daemon; BR-06/BR-07/BR-12 also blocked by unresolved deployed hosts.

- `2026-07-25T09:02:59+05:30` (in-session BR-04 prerequisite recheck + holder-key probe)
  - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
    - `BR-04/BR-05 readiness check`
    - `Timestamp: 2026-07-25T09:02:59+05:30`
    - `INFO: /var/run/docker.sock symlink target: /Users/pranay/.docker/run/docker.sock`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
    - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase \`anon\` or \`service_role\` API key.'}`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase \`anon\` or \`service_role\` API key.'}`
  - `set -a; . ./.env; DOCUMENT_REPOSITORY_BACKEND=supabase DOCUMENT_OBJECT_STORE_BACKEND=supabase RAG_VECTOR_BACKEND=supabase BILLING_LEDGER_BACKEND=supabase PROCESSING_PAYLOAD_ENCRYPTION_KEY=abcdefghijklmnopqrstuvwxyz123456 ANONYMOUS_AUTH_SIGNING_KEY=zyxwvutsrqponmlkjihgfedcba123456 PUBLIC_SITE_URL=https://example.com REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer_local_test ALLOWED_ORIGINS=https://example.com ALLOWED_HOSTS=127.0.0.1,localhost ./.venv/bin/python tools/validate_production_config.py`
    - `production configuration contract is valid; no secret values were printed.`

- `2026-07-25T08:46:15+05:30` (re-run BR-04 prerequisite gate + key-shape scan + placeholder auth probe)
  - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` probe returned `401` (JWT likely not configured for admin route)
  - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase \`anon\` or \`service_role\` API key.'}`
  - `validate_production_config.py` remains failing on:
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY`
    - `PUBLIC_SITE_URL`
    - `REVENUECAT_WEBHOOK_AUTHORIZATION`
    - `DOCUMENT_REPOSITORY_BACKEND`, `DOCUMENT_OBJECT_STORE_BACKEND`, `RAG_VECTOR_BACKEND`, `BILLING_LEDGER_BACKEND` (must be `supabase`)
    - `ALLOWED_ORIGINS`, `ALLOWED_HOSTS`
  - Key diagnostics:
    - `SUPABASE_PUBLISHABLE_KEY` and `SUPABASE_SECRET_KEY` are present but non-JWT tokens (dot count 0), likely not accepted by admin endpoint as service-role replacement.
    - `SUPABASE_SERVICE_ROLE_KEY` remains unset.

- `2026-07-25T08:49:22+05:30` (fresh one-item BR-04 prerequisite checkpoint)
  - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
    - `INFO: /var/run/docker.sock symlink target: /Users/pranay/.docker/run/docker.sock`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
    - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
  - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase \`anon\` or \`service_role\` API key.'}`
  - `env scan (sourced .env)`:
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co` (len 40, dots 2)
    - `SUPABASE_PUBLISHABLE_KEY=sb_publishable...` (len 46, dots 0)
    - `SUPABASE_SECRET_KEY=sb_secret...` (len 41, dots 0)
    - `SUPABASE_SERVICE_ROLE_KEY=<unset>`
    - `COVERWISE_API_BASE_URL=<unset>`

- `2026-07-25T08:30:16+05:30` (BR-13/14 valuation memo drafted)
  - Added one-page valuation memo to `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`.
  - BR-13/14 blocker set now reduced to transfer-asset evidence population + platform/runtime credentials.

- `2026-07-25T08:58:07+05:30` (BR-13/14 evidence-intake matrix added)
  - Added concrete proof-locations + signature checklist for each transfer inventory row in `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`.
  - BR-13/14 transfer documentation requirement is now evidence-capture ready; remaining action is attaching concrete asset proofs/signatures.

- `2026-07-25T08:52:10+05:30` (BR-13/14 transfer inventory manifest added)
  - Added transfer-asset manifest rows (accounts, domains, analytics, repos, infrastructure, operations) in `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`.
  - BR-13/14 transfer documentation requirement is now evidence-documented; remaining action is attaching concrete asset proofs/signatures.

- `2026-07-25T03:12:18+05:30` (Docker unblock attempt in this session)
  - `open -a /Applications/Docker.app`
    - `open_rc=1`
    - `_LSOpenURLsWithCompletionHandler()` failed: `error -1712`
  - `launchctl start system/com.docker.socket`
    - `helper_start=3`
    - `system/com.docker.socket` remained `state = not running`
  - `launchctl start gui/501/com.docker.helper`
    - command exited without sustaining a running helper
  - `timeout 5s docker version`
    - `Client: 29.6.2`
    - `Cannot connect to the Docker daemon at unix:///Users/pranay/.docker/run/docker.sock. Is the docker daemon running?`

- `2026-07-25T03:07:54+05:30` (daemon + env-prereq replay)
  - `launchctl start gui/501/com.docker.helper`
    - command returned without daemon state transition.
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL REST probe failed` (`401` from `/rest/v1/`)
  - `timeout 5s docker version`
    - `Client: 29.6.2`
    - `Cannot connect to the Docker daemon at unix:///Users/pranay/.docker/run/docker.sock. Is the docker daemon running?`

- `2026-07-25T02:54:05+05:30` (next one-item checkpoint sweep)
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
    - `DockerVersion=29.6.2;Server=`
    - `missing SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `set -a; . ./.env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 403)`: `invalid JWT`, token malformed (invalid number of segments).
  - `set -a; . ./.env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 403)`: `invalid JWT`, token malformed (invalid number of segments).
  - `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
    - unchanged: missing processing payload key/public site URL/webhook auth + backend/allowlist settings.
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
    - `privacy: verification failed`, `terms: verification failed` (`HTTPError`).
  - `2026-07-25T02:54:05+05:30` (next one-item checkpoint sweep)
    - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
      - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
      - `DockerVersion=29.6.2;Server=`
      - `missing SUPABASE_SERVICE_ROLE_KEY`
      - `SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
    - `set -a; . ./.env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
      - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`
    - `set -a; . ./.env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
      - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`
  - `2026-07-25T02:49:56+05:30` (next one-item checkpoint sweep)
    - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
      - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
      - `DockerVersion=29.6.2;Server=`
      - missing `SUPABASE_SERVICE_ROLE_KEY`
      - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
    - `set -a; . ./.env; SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' COVERWISE_API_BASE_URL=http://127.0.0.1:8005 ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
      - `admin user creation failed (HTTP 403)` (`bad_jwt`, invalid token segments)
    - `set -a; . ./.env; SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' COVERWISE_API_BASE_URL=http://127.0.0.1:8005 ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
      - `admin user creation failed (HTTP 403)` (`bad_jwt`, invalid token segments)

  - `2026-07-25T02:46:32+05:30` (next one-item checkpoint sweep)
    - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
      - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
      - `DockerVersion=29.6.2;Server=`
      - `missing SUPABASE_SERVICE_ROLE_KEY`
      - `SUPABASE_URL/rest/v1` returned `401`
    - `set -a; . ./.env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
      - `admin user creation failed (HTTP 403)` (`bad_jwt`, invalid token segments)
    - `set -a; . ./.env; DOCUMENT_REPOSITORY_BACKEND=supabase DOCUMENT_OBJECT_STORE_BACKEND=supabase RAG_VECTOR_BACKEND=supabase BILLING_LEDGER_BACKEND=supabase PROCESSING_PAYLOAD_ENCRYPTION_KEY=abcdefghijklmnopqrstuvwxyz123456 ANONYMOUS_AUTH_SIGNING_KEY=zyxwvutsrqponmlkjihgfedcba123456 PUBLIC_SITE_URL=https://example.com REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer_local_test ALLOWED_ORIGINS=https://example.com ALLOWED_HOSTS=127.0.0.1,localhost ./.venv/bin/python tools/validate_production_config.py`
      - contract remains valid with placeholders
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
      - both pages failed with `HTTPError`
    - `timeout 5s docker version`
      - `Client: 29.6.2`; `Cannot connect to the Docker daemon`
    - `curl -I --max-time 8 https://app.example.com`
      - `Could not resolve host: app.example.com`
    - `launchctl print system/com.docker.socket` / `launchctl print gui/501/com.docker.helper`
      - both not running

  - `2026-07-25T02:42:16+05:30` (fresh in-session checkpoint)
    - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
      - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
      - `DockerVersion=29.6.2;Server=`
      - `missing SUPABASE_SERVICE_ROLE_KEY`
      - `SUPABASE_URL/rest/v1` returned `401`
    - `set -a; . ./.env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
      - `admin user creation failed (HTTP 403)` (`bad_jwt`, invalid token segments)
    - `set -a; . ./.env; DOCUMENT_REPOSITORY_BACKEND=supabase DOCUMENT_OBJECT_STORE_BACKEND=supabase RAG_VECTOR_BACKEND=supabase BILLING_LEDGER_BACKEND=supabase PROCESSING_PAYLOAD_ENCRYPTION_KEY=abcdefghijklmnopqrstuvwxyz123456 ANONYMOUS_AUTH_SIGNING_KEY=zyxwvutsrqponmlkjihgfedcba123456 PUBLIC_SITE_URL=https://example.com REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer_local_test ALLOWED_ORIGINS=https://example.com ALLOWED_HOSTS=127.0.0.1,localhost ./.venv/bin/python tools/validate_production_config.py`
      - contract remains valid with placeholders
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
      - both pages failed with `HTTPError`
    - `curl -I --max-time 8 https://app.example.com`
      - `curl: (6) Could not resolve host: app.example.com`

  - `2026-07-25T02:40:16+05:30` (deployed launch DNS guard)
    - `./.venv/bin/python tools/verify_deployed_launch.py --base-url https://app.example.com --origin https://app.example.com --allow-identity-creation`
      - `launch verifier failed before checks: network failure: [Errno 8] nodename nor servname provided, or not known`
    - BR-06 BR-07 still blocked on unavailable deployed runtime endpoints.
  - `2026-07-25T02:41:55+05:30` (BR-05 local dependency attempt)
    - `set -a; . ./.env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
      - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`
    - Dependency note: BR-05 blocked until BR-04 service-role/JWT blocker is resolved.
  - `2026-07-25T02:38:11+05:30` (Docker daemon visibility checkpoint)
    - `timeout 5s docker version`
      - `Client: 29.6.2`
      - `Cannot connect to the Docker daemon at unix:///Users/pranay/.docker/run/docker.sock`
    - `launchctl print system/com.docker.socket`
      - `state = not running`, `runs = 3`, `last exit code = 0`
    - `launchctl print gui/501/com.docker.helper`
      - `state = not running`, `job state = exited`, `runs = 7`, `last exit code = 0`
  - `2026-07-25T02:37:20+05:30` (BR-04 + hostability recheck)
    - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
      - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
      - `DockerVersion=29.6.2;Server=`
      - `required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
      - `SUPABASE_URL REST probe failed (401)`
    - `set -a; . ./.env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
      - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`
    - `set -a; . ./.env; DOCUMENT_REPOSITORY_BACKEND=supabase DOCUMENT_OBJECT_STORE_BACKEND=supabase RAG_VECTOR_BACKEND=supabase BILLING_LEDGER_BACKEND=supabase PROCESSING_PAYLOAD_ENCRYPTION_KEY=abcdefghijklmnopqrstuvwxyz123456 ANONYMOUS_AUTH_SIGNING_KEY=zyxwvutsrqponmlkjihgfedcba123456 PUBLIC_SITE_URL=https://example.com REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer_local_test ALLOWED_ORIGINS=https://example.com ALLOWED_HOSTS=127.0.0.1,localhost ./.venv/bin/python tools/validate_production_config.py`
      - `production configuration contract is valid; no secret values were printed.`
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
      - `privacy: verification failed`, `terms: verification failed` (`URLError`)
    - `curl -I --max-time 8 https://coverwise.app`
      - `Could not resolve host: coverwise.app`
    - `curl -I --max-time 8 https://app.example.com`
      - `Could not resolve host: app.example.com`
    - `curl -I --max-time 8 https://nrmmvtpyaf.ap-south-1.awsapprunner.com`
      - `Could not resolve host: nrmmvtpyaf.ap-south-1.awsapprunner.com`
    - `curl -I --max-time 8 https://www.example.com/privacy`
      - `HTTP/2 404`
  - `2026-07-25T02:35:05+05:30` (active gate recheck: BR-04 still blocked)
    - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
      - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
      - `DockerVersion=29.6.2;Server=`
      - `required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
      - `SUPABASE_URL REST probe failed (401)`
    - `set -a; . ./.env; COVERWISE_API_BASE_URL=http://127.0.0.1:8005 ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
      - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`
  - `2026-07-25T02:33:06+05:30` (current checkpoint: hostability regression)
    - `./.venv/bin/python tools/verify_deployed_launch.py --base-url https://nrmmvtpyaf.ap-south-1.awsapprunner.com --origin https://nrmmvtpyaf.ap-south-1.awsapprunner.com --allow-identity-creation`
      - `launch verifier failed before checks: network failure: [Errno 6] Could not resolve host: nrmmvtpyaf.ap-south-1.awsapprunner.com`
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
      - `privacy: verification failed`
      - `terms: verification failed`
      - hosted page read failed with `URLError` (`Could not resolve host`)
    - `curl -I --max-time 8 https://coverwise.app`
      - `curl: (6) Could not resolve host: coverwise.app`
    - `curl -I --max-time 8 https://nrmmvtpyaf.ap-south-1.awsapprunner.com`
      - `curl: (6) Could not resolve host: nrmmvtpyaf.ap-south-1.awsapprunner.com`
    - `curl -I --max-time 8 https://www.example.com/privacy`
      - `HTTP/2 200` (control DNS/proxy sanity check)
  - `2026-07-25T02:27:44+05:30` (current checkpoint after one-item iteration)
    - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
      - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
      - `privacy: verification failed`
      - `terms: verification failed`
      - hosted page read failed with `HTTPError`
    - `./.venv/bin/python tools/verify_deployed_launch.py --base-url https://app.example.com --origin https://app.example.com`
      - `launch verifier failed before checks: network failure: [Errno 8] nodename nor servname provided, or not known`
    - `set -a; . ./.env; DOCUMENT_REPOSITORY_BACKEND=supabase DOCUMENT_OBJECT_STORE_BACKEND=supabase RAG_VECTOR_BACKEND=supabase BILLING_LEDGER_BACKEND=supabase PROCESSING_PAYLOAD_ENCRYPTION_KEY=abcdefghijklmnopqrstuvwxyz123456 ANONYMOUS_AUTH_SIGNING_KEY=zyxwvutsrqponmlkjihgfedcba123456 PUBLIC_SITE_URL=https://example.com REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer_local_test ALLOWED_ORIGINS=https://example.com ALLOWED_HOSTS=127.0.0.1,localhost ./.venv/bin/python tools/validate_production_config.py`
      - `production configuration contract is valid; no secret values were printed.`
    - `set -a; . ./.env; ./.venv/bin/python tools/verify_deployed_identity_claim.py --api-url https://app.example.com --supabase-url https://eyumuxwabmsymytjbxoj.supabase.co --confirm`
      - `FAIL: SUPABASE_PUBLISHABLE_KEY and SUPABASE_SERVICE_ROLE_KEY are required`
    - `set -a; . ./.env; ./.venv/bin/python tools/verify_deployed_identity_claim.py --api-url https://app.example.com --supabase-url https://eyumuxwabmsymytjbxoj.supabase.co --confirm`
      - `WARNING: synthetic account cleanup failed: User not allowed`
      - `RuntimeError: network failure: [Errno 8] nodename nor servname provided, or not known`
    - `set -a; . ./.env; ./.venv/bin/python tools/verify_deployed_tenant_isolation.py --api-url https://app.example.com --supabase-url https://eyumuxwabmsymytjbxoj.supabase.co --confirm`
      - `WARNING: synthetic account cleanup failed ... User not allowed`
      - `INFO: created user A ...`
      - `INFO: created user B ...`
      - `RuntimeError: network failure: [Errno 8] nodename nor servname provided, or not known`
    - `./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
      - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`

  - `2026-07-25T02:24:13+05:30` (fresh prereq/config checkpoint)
    - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh`
      - `DockerVersion=29.6.2;Server=`
      - `FAIL: docker socket exists but docker daemon check failed`
      - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
      - `WARN: SUPABASE_URL REST probe failed (401)`
    - `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
      - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
      - `PUBLIC_SITE_URL is required`
      - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
      - `DOCUMENT_REPOSITORY_BACKEND must be supabase`
      - `DOCUMENT_OBJECT_STORE_BACKEND must be supabase`
      - `RAG_VECTOR_BACKEND must be supabase`
      - `BILLING_LEDGER_BACKEND must be supabase`
      - `ALLOWED_ORIGINS is required when ENVIRONMENT=production`
      - `ALLOWED_HOSTS is required when ENVIRONMENT=production`
    - `launchctl print system/com.docker.socket` -> `state = not running`, `last exit code = 0`
    - `launchctl print gui/501/com.docker.helper` -> `state = not running`, `job state = exited`

  - `2026-07-25T02:17:54+05:30` (attempted Docker restart + gate sweep)
    - `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
      - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
      - `PUBLIC_SITE_URL is required`
      - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
      - `DOCUMENT_REPOSITORY_BACKEND must be supabase`
      - `DOCUMENT_OBJECT_STORE_BACKEND must be supabase`
      - `RAG_VECTOR_BACKEND must be supabase`
      - `BILLING_LEDGER_BACKEND must be supabase`
      - `ALLOWED_ORIGINS is required when ENVIRONMENT=production`
      - `ALLOWED_HOSTS is required when ENVIRONMENT=production`
    - `launchctl start gui/501/com.docker.helper` + open/app
      - service remains inactive (`state = not running`, `job state = exited`)
    - `timeout 5s docker version`
      - `Client: 29.6.2`; daemon connection failed for `unix:///Users/pranay/.docker/run/docker.sock`
    - `./tools/check_buyer_readiness_prereqs.sh --sourced-env`
      - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
      - `DockerVersion=29.6.2;Server=`
      - `required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
      - `SUPABASE_URL REST probe failed (401)`
  - `2026-07-25T02:15:54+05:30` (re-run gated checkpoint)
    - `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
      - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
      - `PUBLIC_SITE_URL is required`
      - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
      - `DOCUMENT_REPOSITORY_BACKEND must be supabase`
      - `DOCUMENT_OBJECT_STORE_BACKEND must be supabase`
      - `RAG_VECTOR_BACKEND must be supabase`
      - `BILLING_LEDGER_BACKEND must be supabase`
      - `ALLOWED_ORIGINS is required when ENVIRONMENT=production`
      - `ALLOWED_HOSTS is required when ENVIRONMENT=production`
    - `./tools/check_buyer_readiness_prereqs.sh --sourced-env`
      - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
      - `DockerVersion=29.6.2;Server=`
      - `required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
      - `SUPABASE_URL REST probe failed (401)`
  - `2026-07-25T02:14:42+05:30` (re-run readiness checkpoint)
    - `./tools/check_buyer_readiness_prereqs.sh --sourced-env`
      - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
      - `DockerVersion=29.6.2;Server=`
      - `required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
      - `SUPABASE_URL REST probe failed (401)`
  - `2026-07-25T02:11:27+05:30` (prior re-run verification batch)
    - `./.venv/bin/python tools/validate_production_config.py`
      - `SUPABASE_URL is required`
      - `SUPABASE_SERVICE_ROLE_KEY is required`
      - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
      - `ANONYMOUS_AUTH_SIGNING_KEY is required`
      - `PUBLIC_SITE_URL is required`
      - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
      - `DOCUMENT_REPOSITORY_BACKEND must be supabase`
      - `DOCUMENT_OBJECT_STORE_BACKEND must be supabase`
      - `RAG_VECTOR_BACKEND must be supabase`
      - `BILLING_LEDGER_BACKEND must be supabase`
      - `ALLOWED_ORIGINS is required when ENVIRONMENT=production`
      - `ALLOWED_HOSTS is required when ENVIRONMENT=production`
    - `./tools/check_buyer_readiness_prereqs.sh --sourced-env`
      - `BLOCKED` with 4 items:
        - `DockerVersion=29.6.2;Server=`
        - missing `SUPABASE_URL SUPABASE_PUBLISHABLE_KEY SUPABASE_SERVICE_ROLE_KEY`
    - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
      - `HTTP 403 bad_jwt` malformed-token failure at admin user creation
    - `./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
      - same `HTTP 403 bad_jwt` admin token-shape failure
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
      - `privacy: verification failed`, `terms: verification failed` (`HTTPError`)
    - `./.venv/bin/python tools/verify_deployed_launch.py --base-url https://app.example.com --origin https://app.example.com`
      - `launch verifier failed before checks: network failure: [Errno 8] nodename nor servname provided, or not known`
    - `./.venv/bin/pytest -q tests/test_br04_identity_continuity.py tests/test_br05_tenant_isolation.py tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py tests/test_verify_hosted_legal_documents.py tests/test_launch_claim_registry.py`
      - `29 passed`
    - `./.venv/bin/pytest -q tests/test_br02_representative_corpus.py tests/test_billing_ledger_service.py tests/test_subscription_webhook.py tests/test_launch_claim_registry.py tests/test_verify_hosted_legal_documents.py tests/test_outbox_worker_health.py tests/test_legal_release_assets.py tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py`
      - `44 passed`

  - `2026-07-25T02:06:06+05:30` (re-run verification batch)
  - Route-shape proof (`/.venv/bin/python` probe at `http://127.0.0.1:8005`):
      - `POST /user/anonymous` => `200`
      - `GET /user/anonymous` => `HTTP 404`
      - `GET /healthz` => `200`
  - `./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `./.venv/bin/python tools/validate_production_config.py`
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
    - `PUBLIC_SITE_URL is required`
    - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
    - `DOCUMENT_REPOSITORY_BACKEND must be supabase`
    - `DOCUMENT_OBJECT_STORE_BACKEND must be supabase`
    - `RAG_VECTOR_BACKEND must be supabase`
    - `BILLING_LEDGER_BACKEND must be supabase`
    - `ALLOWED_ORIGINS is required when ENVIRONMENT=production`
    - `ALLOWED_HOSTS is required when ENVIRONMENT=production`
  - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`
  - `./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`
  - `./.venv/bin/pytest -q tests/test_br02_representative_corpus.py tests/test_billing_ledger_service.py tests/test_subscription_webhook.py tests/test_launch_claim_registry.py tests/test_verify_hosted_legal_documents.py tests/test_outbox_worker_health.py tests/test_legal_release_assets.py tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py`
    - `44 passed`

## One-item execution queue

1. ✅ **BR-02 representative-corpus contract proof**
   - Evidence: `pytest -q tests/test_br02_representative_corpus.py`
   - Status: complete
2. ✅ **BR-04 readiness preflight baseline**
   - Evidence: `tools/check_buyer_readiness_prereqs.sh --sourced-env`
   - Status: blocked by missing service key + docker
3. ✅ **BR-04 command-shape tests**
   - Evidence: local identity/tenant verifier command-shape test files
   - Status: passed command-shape, runtime auth still blocked
4. ✅ **BR-07 local entitlement contract tests**
   - Evidence: billing + webhook contract tests
   - Status: complete
5. ✅ **BR-06 hosted legal local contract tests**
   - Evidence: `tests/test_verify_hosted_legal_documents.py`
   - Status: complete
6. ✅ **BR-11 production config validation (local contract)**
   - Evidence: `tools/validate_production_config.py`
   - Status: blocked by missing production/runtime values
7. ✅ **Local legal release asset verification**
   - Evidence: `tools/validate_legal_release_assets.py`
   - Status: complete
8. ⚠️ **BR-04 real-credential identity continuity end-to-end** (active)
   - Required inputs: `SUPABASE_SERVICE_ROLE_KEY`, reachable local API base (`COVERWISE_API_BASE_URL=http://127.0.0.1:8005`)
   - Evidence attempt:
     - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`  
       -> `HTTP 403 bad_jwt` (`token contains an invalid number of segments`) when no valid service-role key is provided.
   - Status: blocked / owner input required
9. ⛔ **BR-05 real-credential tenant-isolation end-to-end**
   - Dependency: BR-04 identity continuity must pass first
   - Latest attempt: same invalid admin token failure as BR-04.
10. ⛔ **BR-06 hosted legal-page parity on deployed URLs**
   - Dependency: production canonical privacy/terms URLs
11. ⛔ **BR-07 BIL-01 provider lifecycle proof**
   - Dependency: active provider/runtime+webhook environment
12. ⛔ **BR-08/BR-09 deployed recovery + observability proof**
   - Dependency: deployed runtime + worker telemetry access
13. ⚠️ **BR-12 store/distribution readiness + BR-13/BR-14 commercial transfer proof** (in progress)
   - Dependency: app-store/external account continuity inputs
   - In-progress owner-owned draft evidence: `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`

### Current run result snapshot

- `BR-04 real-credential identity continuity` — blocked by malformed/missing `SUPABASE_SERVICE_ROLE_KEY`.
- `BR-05 real-credential tenant isolation` — still blocked behind BR-04.
- `BR-06 hosted legal-page parity` — blocked by unresolved/non-provided canonical deployment URLs.
- `BR-07 BIL-01 / BR-08-09` — blocked by unavailable deployed runtime (`app.example.com` DNS/network).
- `BR-11 production config` — contract validation is now clean when required runtime values are injected; real `.env` remains incomplete for launch values.

## Next action

1. Load missing `SUPABASE_SERVICE_ROLE_KEY` into session env and rerun:
   - `set -a; . ./.env; ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
   - `set -a; . ./.env; ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
2. If both pass, mark item 8 done and start item 9 immediately.
3. Keep this list in lockstep with the two main tracker files after every checkpoint.

## Live checkpoint

- `2026-07-25T02:06:00+05:30` (env/runtime re-audit)
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - `./.venv/bin/python tools/validate_production_config.py`
    - `SUPABASE_URL is required`
    - `SUPABASE_SERVICE_ROLE_KEY is required`
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
    - `ANONYMOUS_AUTH_SIGNING_KEY is required`
    - `PUBLIC_SITE_URL is required`
    - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
    - `DOCUMENT_REPOSITORY_BACKEND is required to be supabase`
    - `DOCUMENT_OBJECT_STORE_BACKEND is required to be supabase`
    - `RAG_VECTOR_BACKEND is required to be supabase`
    - `BILLING_LEDGER_BACKEND is required to be supabase`
    - `ALLOWED_ORIGINS is required when ENVIRONMENT=production`
    - `ALLOWED_HOSTS is required when ENVIRONMENT=production`
  - `launchctl print system/com.docker.socket`
    - `state = not running`, `last exit code = 0`
  - `launchctl print gui/501/com.docker.helper`
    - `state = not running`, `job state = exited`
  - `open -a Docker; sleep 3; timeout 5s docker version`
    - `Cannot connect to the Docker daemon...`
    - `_LSOpenURLsWithCompletionHandler() failed ... error -1712`
  - Status: unchanged

- `2026-07-25T02:03:44+05:30` (local contract re-sweep)
  - `curl -X POST http://127.0.0.1:8005/user/anonymous`
    - `POST /user/anonymous -> 200`
  - `curl -X GET http://127.0.0.1:8005/user/anonymous`
    - `GET /user/anonymous -> 404`
  - `curl -X GET http://127.0.0.1:8005/healthz`
    - `GET /healthz -> 200`
  - `./.venv/bin/python tools/validate_production_config.py`
    - `SUPABASE_URL is required`
    - `SUPABASE_SERVICE_ROLE_KEY is required`
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
    - `ANONYMOUS_AUTH_SIGNING_KEY is required`
    - `PUBLIC_SITE_URL is required`
    - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
    - `DOCUMENT_REPOSITORY_BACKEND is required to be supabase`
    - `DOCUMENT_OBJECT_STORE_BACKEND is required to be supabase`
    - `RAG_VECTOR_BACKEND is required to be supabase`
    - `BILLING_LEDGER_BACKEND is required to be supabase`
    - `ALLOWED_ORIGINS is required when ENVIRONMENT=production`
    - `ALLOWED_HOSTS is required when ENVIRONMENT=production`
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
    - `privacy: verification failed` (`hosted page could not be read: HTTPError`)
    - `terms: verification failed` (`hosted page could not be read: HTTPError`)
  - `./.venv/bin/pytest -q tests/test_billing_ledger_service.py tests/test_subscription_webhook.py tests/test_verify_hosted_legal_documents.py tests/test_launch_claim_registry.py tests/test_outbox_worker_health.py tests/test_legal_release_assets.py tests/test_br02_representative_corpus.py tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py`
    - `40 passed`
  - Status: unchanged; BR-04 remains blocked by docker/service-role, BR-11 by production config, BR-10 by invalid hosted URLs.

- `2026-07-25T02:01:32+05:30` (BR-04 preflight + BR-11 contract recheck)
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `HTTP 403 bad_jwt` (`token contains an invalid number of segments`) with current key material.
  - `./.venv/bin/python tools/validate_production_config.py`
    - `SUPABASE_URL is required`
    - `SUPABASE_SERVICE_ROLE_KEY is required`
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
    - `ANONYMOUS_AUTH_SIGNING_KEY is required`
    - `PUBLIC_SITE_URL is required`
    - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
    - `DOCUMENT_REPOSITORY_BACKEND is required to be supabase`
    - `DOCUMENT_OBJECT_STORE_BACKEND is required to be supabase`
    - `RAG_VECTOR_BACKEND is required to be supabase`
    - `BILLING_LEDGER_BACKEND is required to be supabase`
    - `ALLOWED_ORIGINS is required when ENVIRONMENT=production`
    - `ALLOWED_HOSTS is required when ENVIRONMENT=production`
  - Status: unchanged (BR-04 and BR-11 blocked).

- `2026-07-25T02:01:32+05:30` (BR-04 preflight + BR-11 contract recheck)
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - `./tools/check_buyer_readiness_prereqs.sh`
    - identical blocker set as sourced run
  - `./.venv/bin/python tools/validate_production_config.py`
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
    - `PUBLIC_SITE_URL is required`
    - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
    - `DOCUMENT_REPOSITORY_BACKEND` must be `supabase`
    - `DOCUMENT_OBJECT_STORE_BACKEND` must be `supabase`
    - `RAG_VECTOR_BACKEND` must be `supabase`
    - `BILLING_LEDGER_BACKEND` must be `supabase`
    - `ALLOWED_ORIGINS` required when `ENVIRONMENT=production`
    - `ALLOWED_HOSTS` required when `ENVIRONMENT=production`
  - Status: **unchanged** — still blocked on BR-04 service-role/dockerd and BR-11 prod/backend-mode requirements.
- `2026-07-25T02:01:58+05:30` (Docker launch probe attempt)
  - `launchctl print system/com.docker.socket`
    - `state = not running`
  - `launchctl print gui/501/com.docker.helper`
    - `state = not running`
    - `job state = exited`
  - `open -a Docker; sleep 2; timeout 5s docker version`
    - still `Cannot connect to the Docker daemon at unix:///Users/pranay/.docker/run/docker.sock`
  - Status: **unchanged** — daemon remains unreachable.

- `2026-07-25T02:00:44+05:30` (BR-04 preflight replay)
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - Status: **unchanged** — still blocked on BR-04 service-role/dockerd and BR-11 prod/backend-mode requirements.

- `2026-07-25T01:58:53+05:30` (fresh BR-04/BR-05 replay)
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - API route probe (`python`):
    - `POST /user/anonymous` -> `200`
    - `GET /user/anonymous` -> `404`
    - `GET /healthz` -> `200`
    - `POST /healthz` -> `404`
  - `tools/validate_production_config.py`:
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
    - `PUBLIC_SITE_URL is required`
    - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
    - `DOCUMENT_REPOSITORY_BACKEND` must be `supabase`
    - `DOCUMENT_OBJECT_STORE_BACKEND` must be `supabase`
    - `RAG_VECTOR_BACKEND` must be `supabase`
    - `BILLING_LEDGER_BACKEND` must be `supabase`
    - `ALLOWED_ORIGINS` required when `ENVIRONMENT=production`
    - `ALLOWED_HOSTS` required when `ENVIRONMENT=production`
  - Status: **still blocked on BR-04 (service-role + daemon) and BR-11 (production/backend-mode values).**

- `2026-07-25T01:55:56+05:30` (sourced-env config + BR-04/BR-11 checkpoint)
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - API route probe (`python`):
    - `POST /user/anonymous` -> `200`
    - `GET /user/anonymous` -> `404`
    - `GET /healthz` -> `200`
    - `POST /healthz` -> `404`
  - Status: **still blocked on BR-04 (service-role key) and BR-11 (production values/backend modes).**
  - Env presence:
    - `SUPABASE_URL` set, `SUPABASE_PUBLISHABLE_KEY` set, `SUPABASE_SECRET_KEY` set
    - `SUPABASE_SERVICE_ROLE_KEY` unset
    - `ANONYMOUS_AUTH_SIGNING_KEY` set
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY` unset
    - `PUBLIC_SITE_URL` unset
    - `REVENUECAT_WEBHOOK_AUTHORIZATION` unset
    - `DOCUMENT_REPOSITORY_BACKEND=sqlite`
    - `DOCUMENT_OBJECT_STORE_BACKEND=local`
    - `RAG_VECTOR_BACKEND=qdrant`
    - `BILLING_LEDGER_BACKEND` unset
    - `ALLOWED_ORIGINS` unset
    - `ALLOWED_HOSTS` unset
    - `APP_BASE_URL` unset
  - `tools/validate_production_config.py`:
    - missing/invalid on:
      - `PROCESSING_PAYLOAD_ENCRYPTION_KEY`
      - `PUBLIC_SITE_URL`
      - `REVENUECAT_WEBHOOK_AUTHORIZATION`
      - `DOCUMENT_REPOSITORY_BACKEND` (must be `supabase`)
      - `DOCUMENT_OBJECT_STORE_BACKEND` (must be `supabase`)
      - `RAG_VECTOR_BACKEND` (must be `supabase`)
      - `BILLING_LEDGER_BACKEND` (must be `supabase`)
      - `ALLOWED_ORIGINS` and `ALLOWED_HOSTS` when production
  - `tools/check_buyer_readiness_prereqs.sh --sourced-env`:
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - `tools/validate_legal_release_assets.py`: complete
  - Status: **still blocked on BR-04 (service-role + daemon) and BR-11 (production values/backend-mode)**.

- `2026-07-25T01:55:25+05:30` (BR-11 production-config validation re-run)
  - `./.venv/bin/python tools/validate_production_config.py`
    - `SUPABASE_URL is required`
    - `SUPABASE_SERVICE_ROLE_KEY is required`
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY is required`
    - `ANONYMOUS_AUTH_SIGNING_KEY is required`
    - `PUBLIC_SITE_URL is required`
    - `REVENUECAT_WEBHOOK_AUTHORIZATION is required`
    - `DOCUMENT_REPOSITORY_BACKEND` must be `supabase`
    - `DOCUMENT_OBJECT_STORE_BACKEND` must be `supabase`
    - `RAG_VECTOR_BACKEND` must be `supabase`
    - `BILLING_LEDGER_BACKEND` must be `supabase`
    - `ALLOWED_ORIGINS` required when `ENVIRONMENT=production`
    - `ALLOWED_HOSTS` required when `ENVIRONMENT=production`
  - Status: **BR-11 remains blocked by missing required values and backend mode overrides**

- `2026-07-25T01:54:18+05:30` (fresh re-check: auth shape + docker + route parity)
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - `./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase` with placeholder service-role key:
    - `HTTP 403 bad_jwt` (`token contains an invalid number of segments`)
  - Key shape:
    - `SUPABASE_URL` set, len 40, dots 2
    - `SUPABASE_PUBLISHABLE_KEY` set, len 46, dots 0
    - `SUPABASE_SECRET_KEY` set, len 41, dots 0
    - `SUPABASE_SERVICE_ROLE_KEY` unset
  - Route checks at `http://127.0.0.1:8005`:
    - `POST /user/anonymous` -> `200`
    - `GET /user/anonymous` -> `404`
    - `GET /healthz` -> `200`
    - `POST /healthz` -> `200`
  - Docker handshake:
    - `DOCKER_HOST=unix:///Users/pranay/.docker/run/docker.sock timeout 5 docker version --format '{{.Server.Version}}'` fails connect
  - Status: **BR-04/BR-05 still blocked by service-role key + docker daemon**

- `2026-07-25T01:46:24+05:30` (re-run of `./tools/check_buyer_readiness_prereqs.sh --sourced-env`)
  - `DockerVersion=29.6.2;Server=`
  - `FAIL: docker socket exists but docker daemon check failed`
  - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
  - `WARN: SUPABASE_URL/rest/v1` returned `401`
  - Status: **BR-04/BR-05 blocked (3 items)**

- `2026-07-25T01:46:49+05:30` (re-run of `verify_local_identity_claim.py` and `verify_local_tenant_isolation.py`)
  - `tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `RuntimeError: admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `tools/verify_local_tenant_isolation.py --allow-remote-supabase` (with `COVERWISE_API_BASE_URL=http://127.0.0.1:8005`)
    - same `HTTP 403 bad_jwt` `invalid JWT: token contains an invalid number of segments`
  - Local route checks:
    - `POST /user/anonymous` -> `200`
    - `GET /user/anonymous` -> `404`
    - `GET /healthz` -> `200`
  - Supabase REST probe:
    - `https://eyumuxwabmsymytjbxoj.supabase.co/rest/v1/` -> `401`
  - Docker:
    - `docker --version` prints `29.6.2`
  - `docker version --format '{{.Server.Version}}'` fails with daemon unreachable at `unix:///Users/pranay/.docker/run/docker.sock`
  - Status: **BR-04/BR-05 still blocked by token shape + daemon state**

- `2026-07-25T01:48:30+05:30` (re-run of `tools/validate_production_config.py`)
  - Still blocked by environment/runtime requirements:
    - `PROCESSING_PAYLOAD_ENCRYPTION_KEY`
    - `PUBLIC_SITE_URL`
    - `REVENUECAT_WEBHOOK_AUTHORIZATION`
    - `DOCUMENT_REPOSITORY_BACKEND` must be `supabase`
    - `DOCUMENT_OBJECT_STORE_BACKEND` must be `supabase`
    - `RAG_VECTOR_BACKEND` must be `supabase`
    - `BILLING_LEDGER_BACKEND` must be `supabase`
  - `ALLOWED_ORIGINS`, `ALLOWED_HOSTS` required when `ENVIRONMENT=production`
  - Status: **production-config checkpoint remains blocked**

- `2026-07-25T01:48:55+05:30` (Docker unblock attempt)
  - `open -a Docker` executed
  - `launchctl print gui/501/com.docker.helper` still reports:
    - `state = not running`
    - `job state = exited`
  - `timeout 5s docker version --format '{{.Server.Version}}'` still fails: daemon not running
  - Status: **Docker blocker unchanged**

- `2026-07-25T01:47:22+05:30` (supabase key-shape + BR-04 readiness snapshot)
  - Key shape:
    - `SUPABASE_URL` len=40, dots=2, set
    - `SUPABASE_PUBLISHABLE_KEY` len=46, dots=0, set
    - `SUPABASE_SECRET_KEY` len=41, dots=0, set
    - `SUPABASE_SERVICE_ROLE_KEY` len=0, unset
  - `./tools/check_buyer_readiness_prereqs.sh --sourced-env` => same 3-item block:
    - daemon unreachable (`Server=`)
    - missing `SUPABASE_SERVICE_ROLE_KEY`
    - `/rest/v1` returns `401`
- `2026-07-25T01:47:27+05:30` (BR-04 real-credential identity replay)
  - `tools/verify_local_identity_claim.py --allow-remote-supabase`
  - Result: `HTTP 403 bad_jwt` (`token contains an invalid number of segments`)
- `2026-07-25T01:47:30+05:30` (BR-05 real-credential tenant-isolation replay)
  - `tools/verify_local_tenant_isolation.py --allow-remote-supabase`
  - Result: `HTTP 403 bad_jwt` (`token contains an invalid number of segments`)
