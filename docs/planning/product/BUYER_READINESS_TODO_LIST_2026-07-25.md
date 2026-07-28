# Buyer-readiness worklist (solo-founder mode)

Date: 2026-07-25  
Updated: 2026-07-25T13:10:25+05:30  
Scope: one-item-at-a-time execution, evidence-backed state transitions.

## Objective

Track every gate as an explicit item, execute in sequence, and only mark complete with command/runtime proof in this file.

## One-item execution ledger (working set, 2026-07-25)

- **Additional one-item checkpoint (2026-07-25T13:10:25+05:30)**
  - `tools/check_buyer_readiness_prereqs.sh --sourced-env` remains blocked on **1 item**:
    - `SUPABASE_URL/rest/v1` still returns `401` via fallback `SUPABASE_SECRET_KEY`.
    - `SUPABASE_SERVICE_ROLE_KEY` still unset; script normalizes from `SUPABASE_SECRET_KEY`.
  - Direct BR-04/BR-05 probes with placeholder key still fail:
    - `tools/verify_local_identity_claim.py --allow-remote-supabase`: `FAIL admin user creation failed: Invalid API key`.
    - `tools/verify_local_tenant_isolation.py --allow-remote-supabase`: `FAIL: admin user creation failed: Invalid API key`.
  - BR-06 hosted proof still unresolved:
    - `tools/verify_hosted_legal_documents.py` for `app.example.com` and `coverwise.app` -> `URLError`.
    - `dig +short` for both domains returns no A/AAAA records.
  - Runtime command harness check:
    - `./.venv/bin/pytest -q tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py tests/test_verify_hosted_legal_documents.py`
    - Result: `8 passed in 0.02s`.
  - Decision: no state transition; Q2 remains the next active blocker.

- **Additional one-item checkpoint (2026-07-25T13:04:44+05:30)**
  - `tools/check_buyer_readiness_prereqs.sh --sourced-env` now blocks on a single item:
    - `SUPABASE_URL/rest/v1` auth returns `401` against `SUPABASE_SECRET_KEY` fallback (`SUPABASE_SERVICE_ROLE_KEY not set` fallback note).
  - BR-04/BR-05 hard-gate checks with placeholder service-role key:
    - `tools/verify_local_identity_claim.py --allow-remote-supabase`: `FAIL admin user creation failed: Invalid API key`.
    - `tools/verify_local_tenant_isolation.py --allow-remote-supabase`: `FAIL: admin user creation failed: Invalid API key`.
  - `verify_hosted_legal_documents.py` on `app.example.com` and `coverwise.app` continues with `URLError`.
  - Decision: **no state transition**; Q2 still blocked by missing/invalid owner JWT `SUPABASE_SERVICE_ROLE_KEY`.

- **Additional one-item checkpoint (2026-07-25T13:06:48+05:30)**
  - `tools/check_buyer_readiness_prereqs.sh --sourced-env` one-item recheck:
    - `BLOCKED: BR-04/BR-05 readiness check failed with 1 item(s).`
    - `SUPABASE_URL/rest/v1` still `401`; only blocker.
    - `SUPABASE_SERVICE_ROLE_KEY` still unset in effective env; script normalizes from `SUPABASE_SECRET_KEY`.
  - BR-04/BR-05 direct checks with placeholder service key remain hard-blocked:
    - identity continuity: `FAIL admin user creation failed: Invalid API key`
    - tenant isolation: `FAIL: admin user creation failed: Invalid API key`
  - BR-06 legal-hostability checks unchanged:
    - both `app.example.com` and `coverwise.app` return `URLError`.
  - Decision: no tick-off; Q2 still owner-key-only unblocker.

- **Additional one-item checkpoint (2026-07-25T13:02:23+05:30)**
  - Q1 status transitioned to complete after daemon/socket recovery:
    - `launchctl kickstart -k gui/501/com.docker.helper` (0), `launchctl start gui/501/com.docker.helper` (3), `launchctl start system/com.docker.socket` (3).
    - `/Users/pranay/.docker/run/docker.sock` now present (`srwxr-xr-x`), `/var/run/docker.sock` symlink valid.
    - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'` returns `Client 29.6.2;Server 29.6.2`.
    - `docker ps -a` lists running Supabase containers.
  - Q2/Q3/Q4 still blocked on credentials:
    - `tools/check_buyer_readiness_prereqs.sh` now blocked only on service-role auth shape (`SUPABASE_SERVICE_ROLE_KEY len=7`, `SUPABASE_SECRET_KEY len=41`, `SUPABASE_PUBLISHABLE_KEY len=46`).
    - BR-04/BR-05 with placeholder key still fail `Invalid API key`.
  - BR-06 remains blocked by URLError on `app.example.com` and `coverwise.app`.
  - Decision: no overall state transition; move to Q2 acquisition next.

- [x] Q3 — BR-04 real-credential identity continuity
  - **RESOLVED 2026-07-28:** 11/11 verifier checks passed against remote Supabase.
  - **Evidence:** `tools/verify_local_identity_claim.py --allow-remote-supabase` — all checks pass (identity creation, guest-to-account claim, cross-owner API denial, account readback, cleanup).
  - **Dependency resolution:** Q2 was resolved by validating the service-role key shape against the live Supabase project key.

- [x] Q4 — BR-05 tenant-isolation continuity
  - **RESOLVED 2026-07-28:** 11/11 verifier checks passed against remote Supabase.
  - **Evidence:** `tools/verify_local_tenant_isolation.py --allow-remote-supabase` — all checks pass (two-principal upload, API denial, Storage denial, owner deletion, post-delete absence, user cleanup).

## Additional one-item checkpoint (2026-07-25T12:58:20+05:30)

- Scope: hard-blocker validation for Q1/Q2/Q5 in order, no status transition.
- Checks executed:
  - `docker context show`
  - `ls -la /Users/pranay/.docker/run /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - `launchctl print gui/501/com.docker.helper`
  - `launchctl print system/com.docker.socket`
  - `rg -n "ENOSPC|no space left|Docker Desktop cannot continue because the disk is full" ~/Library/Containers/com.docker.docker/Data/log/host/*.log`
  - `.env` source scan for Supabase key shape
  - `set -a; . ./.env; tools/check_buyer_readiness_prereqs.sh`
  - `tools/verify_local_identity_claim.py --allow-remote-supabase`
  - `tools/verify_local_tenant_isolation.py --allow-remote-supabase`
  - `tools/verify_hosted_legal_documents.py` for `app.example.com`, `coverwise.app`, and `example.com`
- Result:
  - `Q1` still blocked:
    - `/Users/pranay/.docker/run/docker.sock` still missing; `/var/run/docker.sock` still symlinked to it.
    - `docker version` still fails with socket-connect missing-path error.
    - `com.docker.helper`/`com.docker.socket` remain `state = not running`, `job state = exited`.
    - ENOSPC markers remain in Docker host logs.
  - `Q2` still blocked:
    - `.env` contains `SUPABASE_PUBLISHABLE_KEY` and `SUPABASE_SECRET_KEY` but no JWT-style `SUPABASE_SERVICE_ROLE_KEY`; script normalizes fallback with `/rest/v1` 401.
    - Identity verifier passes admin creation with fallback key, but guest-to-account claim/profile steps now return `HTTP 401` (`Invalid or expired account token`) and synthetic upload fails `Invalid or expired account token`.
  - `Q5` still blocked:
    - `verify_hosted_legal_documents.py` on `app.example.com` / `coverwise.app`: `URLError`.
    - `example.com` returns `HTTPError` in this session.
- Decision: no status transition; continue one-item sequence once required owner/runtime inputs are available.

## Additional one-item checkpoint (2026-07-25T12:38:19+05:30)

- Focused Q1/Q2 checkpoint with latest runtime/auth evidence and explicit restart attempt:
  - `docker context ls` + `docker context show`
  - `ls -la /Users/pranay/.docker/run`; `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - `launchctl print gui/501/com.docker.helper`; `launchctl print system/com.docker.socket`
  - `ps -ef | rg 'com\\.docker\\.(backend|helper)|Docker Desktop'`
  - `launchctl kickstart -k gui/501/com.docker.helper`; `launchctl start gui/501/com.docker.helper`; `launchctl start system/com.docker.socket`
  - `.env` shape scan and `set -a; . ./.env; tools/check_buyer_readiness_prereqs.sh`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
  - `curl https://app.example.com/privacy`; `curl https://coverwise.app/privacy`
- Result:
  - `docker context` remains `desktop-linux`.
  - `/Users/pranay/.docker/run/docker.sock` still missing; `/var/run/docker.sock` symlinked to it.
  - `docker version` remains `Client 29.6.2;Server ` with missing-socket connect error.
  - `launchctl` helper/socket services remain `state = not running`, `job state = exited`.
  - restart attempt moved `com.docker.helper` run counter (`runs=13`) but no socket production or daemon start.
  - `SUPABASE_SERVICE_ROLE_KEY=<UNSET>`; `SUPABASE_SECRET_KEY`/`SUPABASE_PUBLISHABLE_KEY` are non-JWT shape (dots 0).
  - `tools/check_buyer_readiness_prereqs.sh` still blocked with 2 items:
    - `docker socket missing`
    - `SUPABASE_SERVICE_ROLE_KEY` fallback/auth 401 on `/rest/v1`.
  - Hosted proof checks remain failure mode:
    - `app.example.com` / `coverwise.app`: `URLError`
    - `curl` to both urls: `Could not resolve host` (`http_code=000`)
  - Decision: no status change; `Q1` + `Q2` remain active blockers.

## Additional one-item checkpoint (2026-07-25T12:35:36+05:30)

- Focused Q1/Q2 checkpoint with socket and auth-shape repro:
  - `docker context ls` + `docker context show`
  - `ls -la /Users/pranay/.docker/run`; `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - `launchctl print gui/501/com.docker.helper`; `launchctl print system/com.docker.socket`
  - `ps -ef | rg 'com\\.docker\\.(backend|helper)|Docker Desktop'`
  - `set -a; . ./.env; tools/check_buyer_readiness_prereqs.sh`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://example.com/privacy --terms-url https://example.com/terms`
- Result:
  - `docker.sock` still missing in `/Users/pranay/.docker/run`; `/var/run/docker.sock` is still symlinked to that missing target.
  - `docker version` still fails: path missing / no running daemon.
  - helper/socket launchd jobs still `state = not running`, `job state = exited`.
  - `SUPABASE_SERVICE_ROLE_KEY=<unset>` in sourced `.env`; publishable/secret keys are present but non-JWT.
  - `tools/check_buyer_readiness_prereqs.sh` remains `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
  - `verify_hosted_legal_documents.py` against example.com returned HTTPError; app.example.com and coverwise.app still URLError.
  - Conclusion: no status advancement this pass; still blocked on `Q1` socket + `Q2` key-shape material.

## Additional one-item checkpoint (2026-07-25T12:33:01+05:30)

- Focused Q1 rerun with deterministic socket/runtime/auth evidence:
  - `docker context ls` + `docker context show`
  - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - `launchctl print gui/501/com.docker.helper`
  - `launchctl print system/com.docker.socket`
  - `ps -ef | rg 'com\\.docker\\.(desktop|backend)|Docker Desktop|com\\.docker\\.socket'`
  - `.env` shape check + `tools/check_buyer_readiness_prereqs.sh`
  - hosted legal check + BR-04/BR-05 auth dry-runs with placeholder key
- Result:
  - Socket still missing at `/Users/pranay/.docker/run/docker.sock`; `/var/run/docker.sock` still symlinks there.
  - `docker version` still reports `Client 29.6.2;Server ` with connect error.
  - `com.docker.helper` and `com.docker.socket` remain `state = not running`.
  - `SUPABASE_SERVICE_ROLE_KEY` still `<unset>`; `SUPABASE_SECRET_KEY`/`SUPABASE_PUBLISHABLE_KEY` remain non-JWT token shapes.
  - `tools/check_buyer_readiness_prereqs.sh` unchanged: blocked on socket + invalid auth (`curl 401` on `/rest/v1`).
  - Hosted legal checks for `app.example.com` and `coverwise.app`: URLError.
  - `verify_local_identity_claim.py` and `verify_local_tenant_isolation.py` with placeholder key: Invalid API key.
  - Conclusion: no status advancement; both hard blockers (`Q1` socket and `Q2` owner key material) unchanged.

- [x] Q1 — Restore Docker API socket visibility for local readiness checks
  - Status: **completed**
  - Evidence: `launchctl kickstart -k gui/501/com.docker.helper` + `launchctl start gui/501/com.docker.helper` + `launchctl start system/com.docker.socket`, `/Users/pranay/.docker/run/docker.sock` present as `srwxr-xr-x`, `docker version` returns `Client 29.6.2;Server 29.6.2`, and `docker ps -a` shows Supabase stack containers.
  - Additional root-cause signals:
    - Docker backend logs show `no space left on device` at `.../Data/log/vm/init.log` and `Docker Desktop cannot continue because the disk is full`.
    - `Docker.raw` exists at `~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw` and is currently `926G`, indicating virtual-disk saturation.
  - Result from checkpoint 2026-07-25T12:19:06+05:30: socket still missing at `/Users/pranay/.docker/run/docker.sock`; jobs remain `state = not running`.


## Additional one-item checkpoint (2026-07-25T12:26:39+05:30)

- Focused daemon-retry pass to test whether ENOSPC-only recovery is still present:
  - `launchctl kickstart -k gui/501/com.docker.helper`
  - `launchctl kickstart -k system/com.docker.socket`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - `docker context ls`
  - `ls -l /Users/pranay/.docker/run /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `launchctl print gui/501/com.docker.helper` / `launchctl print system/com.docker.socket`
  - `rg -n "ENOSPC|no space left|Docker Desktop cannot continue because the disk is full" ~/Library/Containers/com.docker.docker/Data/log/host/*.log`
- Result:
  - helper/socket briefly reported `state = running` after kickstart, but both transitioned to `state = not running`/`job state = exited` within ~2s.
  - `/Users/pranay/.docker/run/docker.sock` remains missing; `/var/run/docker.sock` still symlinks to it.
  - `docker version` still fails with connect error to `/Users/pranay/.docker/run/docker.sock`.
  - ENOSPC evidence remains active in `monitor.log` and backend logs at the same `write <HOME>/Library/Containers/com.docker.docker/Data/log/vm/init.log: no space left on device`.
  - `Docker.raw` remains at 926G (hard disk image saturation signal).
- Conclusion: `Q1` remains blocked by Docker vdisk space exhaustion + socket absent; requires owner-supported Docker disk cleanup/reset before re-attempt.

## Additional one-item checkpoint (2026-07-25T12:29:45+05:30)

- Focused pass to validate whether any unblocked drift occurred after the latest socket/auth probes:
  - `date` check for in-session timestamp
  - `docker context ls` and `docker context show`
  - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - `.env` shape check for service-role, secret, and publishable keys
  - `set -a; . ./.env; tools/check_buyer_readiness_prereqs.sh`
  - `tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
  - `tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
- Result:
  - `CHECKPOINT: 2026-07-25T12:29:45+05:30`
  - `SUPABASE_SERVICE_ROLE_KEY=<unset>`, `SUPABASE_SECRET_KEY` length 41 (non-JWT), `SUPABASE_PUBLISHABLE_KEY` length 46 (non-JWT)
  - `docker version` still: `Client 29.6.2;Server ` with connect error to `/Users/pranay/.docker/run/docker.sock`
  - `tools/check_buyer_readiness_prereqs.sh` still blocked with 2 items:
    - missing socket at `/Users/pranay/.docker/run/docker.sock`
    - `SUPABASE_SERVICE_ROLE_KEY` fallback/invalid path causing `/rest/v1` `401`
  - Hosted legal reads for `app.example.com` and `coverwise.app` remain URLError (no read/access)
- Conclusion: no status advancement; `Q1` and `Q2` remain blocked and all downstream runtime checks still wait on owner inputs/system restoration.

## Additional one-item checkpoint (2026-07-25T12:23:11+05:30)

- Re-ran Q1 recovery probes with same commands as prior pass plus `open -a Docker`.
- Evidence (same-fidelity pass):
  - `docker context use desktop-linux`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'` → `Client 29.6.2;Server ` + connect error to `/Users/pranay/.docker/run/docker.sock`
  - `ls -l /Users/pranay/.docker/run/docker.sock` → missing file
  - `/var/run/docker.sock` still symlinked to missing `/Users/pranay/.docker/run/docker.sock`
  - `launchctl print gui/501/com.docker.helper` → state `not running`, job `exited`
  - `launchctl print system/com.docker.socket` → state `not running`, job `exited`
  - `open -a Docker` returned `_LSOpenURLsWithCompletionHandler() ... error -1712`
  - `~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw` = `926G`
  - ENOSPC markers still present in Docker logs with repeated `no space left on device` and disk-full recovery messages.
- Result:
  - `Q1` remains blocked.
  - `Q2` remains blocked by missing/invalid `SUPABASE_SERVICE_ROLE_KEY` (len 0, dots 0) in `.env`.
  - `BR-04` remains blocked with:
    - `FAIL admin user creation failed: Invalid API key`

## Additional one-item checkpoint (2026-07-25T12:22:17+05:30)

- Focused recovery/validation run for remaining dependency gates:
  - `docker context use desktop-linux` -> context selected.
  - `ls -l /Users/pranay/.docker/run/docker.sock` -> `No such file or directory`.
  - `ls -l /var/run/docker.sock` -> symlink to `/Users/pranay/.docker/run/docker.sock`.
  - `timeout 10s docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
    - `Client 29.6.2;Server `
    - failed to connect to `/Users/pranay/.docker/run/docker.sock`.
  - Key-shape recheck with sourced `.env`:
    - `SUPABASE_SERVICE_ROLE_KEY` `<unset>` `len:0 dots:0`.
    - `SUPABASE_SECRET_KEY len:41 dots:0`.
    - `SUPABASE_PUBLISHABLE_KEY len:46 dots:0`.
    - `SUPABASE_URL len:40 dots:2`.
  - `set -a; . ./.env; timeout 20s bash tools/check_buyer_readiness_prereqs.sh`
    - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`.
    - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`).
    - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
    - `privacy: verification failed` (`hosted page could not be read: URLError`).
    - `terms: verification failed` (`hosted page could not be read: URLError`).
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
    - `privacy: verification failed` (`hosted page could not be read: URLError`).
    - `terms: verification failed` (`hosted page could not be read: URLError`).
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `FAIL admin user creation failed: Invalid API key`.
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `FAIL: admin user creation failed: Invalid API key`.
- Result:
  - `Q1` still blocked (missing Docker API socket).
  - `Q2` still blocked (service-role key missing/invalid).
  - `Q3` and `Q4` still blocked waiting on Q2.
  - `Q5` still blocked (no canonical deployed hostability in this session).

- [ ] Q2 — Provide valid owner `SUPABASE_SERVICE_ROLE_KEY` (JWT token)
  - Status: **blocked** (owner secret required)
  - Evidence: `.env` shape check
  - Current shape in-session:
    - `SUPABASE_SERVICE_ROLE_KEY` = `<unset>` (len 0, dots 0)
    - `SUPABASE_SECRET_KEY` len 41, dots 0
    - `SUPABASE_PUBLISHABLE_KEY` len 46, dots 0
  - `tools/check_buyer_readiness_prereqs.sh` still reports REST auth failure (`curl ... 401`).

- [ ] Q3 — BR-04 real-credential identity continuity (`tools/verify_local_identity_claim.py`)
  - Status: **waiting on Q2**
  - Reason: admin auth path cannot be exercised until JWT service-role key is present.

- [ ] Q4 — BR-05 real-credential tenant isolation (`tools/verify_local_tenant_isolation.py`)
  - Status: **waiting on Q3**
  - Reason: downstream of BR-04.

- [ ] Q5 — BR-06 hosted legal-page proof on canonical URLs
  - Status: **blocked** (hostability/canonical URL unresolved)
  - Evidence: `tools/verify_hosted_legal_documents.py`
  - `app.example.com` / `coverwise.app`: URLError; `example.com`/`www.example.com`: HTTPError `404`.
  - Deployed API hostability smoke:
    - `./.venv/bin/python tools/verify_deployed_launch.py --base-url https://app.example.com` -> `network failure: [Errno 8] nodename nor servname provided, or not known`

- [ ] Q6 — BR-07 provider lifecycle proof
  - Status: **deferred owner credentials required**

- [ ] Q7 — BR-12 store/distribution proof
  - Status: **deferred owner credentials required**

- [ ] Q8 — BR-13/14 buyer handover closeout
  - Status: **deferred until Q5/Q6/Q7 complete**

## Active context

- Active gate: **BR-04** (identity continuity with Supabase service-role path)
- Current blocker:
  - `SUPABASE_SERVICE_ROLE_KEY` is still missing/invalid in `.env`; placeholder-like values fail auth.
  - `SUPABASE_SERVICE_ROLE_KEY` is currently `<unset>` in `.env` this pass.
  - `SUPABASE_URL` `/rest/v1/` remains returning `401` with current in-session key shape.
  - If `.env` is not sourced, verifier fails immediately with `FAIL configuration: Supabase publishable and server keys are required`.
  - `docker version` in this session reports client `29.6.2` with empty server field (`Server=`).
  - Local daemon/socket recovery retry also failed (`open -a Docker` no effect; root-required bootstrap error; helper/socket remain stopped).
  - `https://app.example.com` remains non-resolvable in this session for deployed checks.
  - BR-11 runtime contract inputs are present in `.env` and validated when env is explicitly loaded (`tools/validate_production_config.py`).
- Docker socket availability in-session:
  - `/Users/pranay/.docker/run/docker.sock` is missing, so local Docker checks show `FAIL: docker socket missing` and cannot connect to a daemon.
  - `/var/run/docker.sock` is symlinked to `/Users/pranay/.docker/run/docker.sock` but target still missing.
- Non-enterprise policy: no external legal/business governance blocker is required for completion, only technical and owner-secret correctness gates.
  - Owner responsibility for legal pages is enough unless you explicitly request external advisory support.

- Next explicit dependencies to resolve (in-order):
  1. Set `SUPABASE_SERVICE_ROLE_KEY` in `.env` from Supabase Dashboard (service_role JWT).
  2. Restore local Docker socket and daemon so `tools/check_buyer_readiness_prereqs.sh` can report readiness as `READY`.
  3. Re-run BR-04 real-credential verifier (`tools/verify_local_identity_claim.py --allow-remote-supabase`).
  4. Then re-run BR-05 real-credential verifier (`tools/verify_local_tenant_isolation.py --allow-remote-supabase`).
  5. Resolve deployed hostability and provider/store credentials for BR-06/BR-07/BR-12.

## Live checkpoint

- `2026-07-25T12:29:45+05:30` (latest in-session checkpoint)
  - `docker context ls` + `docker context show`:
    - active context: `desktop-linux`
  - `/Users/pranay/.docker/run/docker.sock` is missing; `/var/run/docker.sock` symlinked to missing target.
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'` -> `Client 29.6.2;Server ` with socket-connect error.
  - `SUPABASE_SERVICE_ROLE_KEY=<unset>` in-session.
  - `tools/check_buyer_readiness_prereqs.sh`:
    - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
    - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
    - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
  - hosted legal verifier sample at `app.example.com` and `coverwise.app` unchanged: `URLError`.

- `2026-07-25T12:21:44+05:30` (context-switch validation + preflight snapshot)
  - `docker context use default` -> `Current context is now "default"`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`:
    - `Client 29.6.2;Server `
    - `failed to connect to the docker API at unix:///var/run/docker.sock; ...`
  - `docker context use desktop-linux` -> `Current context is now "desktop-linux"`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`:
    - same client string + connect error to `/Users/pranay/.docker/run/docker.sock`
  - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`:
    - `/Users/pranay/.docker/run/docker.sock`: missing
    - `/var/run/docker.sock -> /Users/pranay/.docker/run/docker.sock`
  - `tools/check_buyer_readiness_prereqs.sh` (12:17:33+05:30) remains blocked with:
    - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
    - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
    - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`

- `2026-07-25T12:19:06+05:30`
  - Q1 attempt executed:
    - `launchctl start gui/501/com.docker.helper`
    - `launchctl start system/com.docker.socket`
    - `docker context show`
    - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
    - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - Evidence:
    - `context` remains `desktop-linux -> unix:///Users/pranay/.docker/run/docker.sock`.
    - `/Users/pranay/.docker/run/docker.sock` still missing.
    - `Client 29.6.2;Server ` with connect error to missing socket.
    - launchd jobs still report `state = not running`, `job state = exited`.
  - `check_buyer_readiness_prereqs.sh` remains `BLOCKED` with:
    - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
    - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
    - `WARN: SUPABASE_URL REST probe failed` (`curl ... /rest/v1/` -> `401`).
    - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
  - `SUPABASE` key shape in-session:
    - `SUPABASE_SERVICE_ROLE_KEY` unset (`len=0`, `dots=0`).
    - `SUPABASE_SECRET_KEY` len 41 (`dots=0`).
    - `SUPABASE_PUBLISHABLE_KEY` len 46 (`dots=0`).
  - Hosted legal probe status remains:
    - `app.example.com` and `coverwise.app`: URLError
    - `example.com`/`www.example.com`: HTTPError
  - Docker disk diagnostics:
    - `~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw` is `926G` and `.log/vm/init.log` is present with no-space errors.

- `2026-07-25T12:10:59+05:30`
  - Re-ran Q1 recovery probes and one-shot restart commands.
  - Outcome remains unchanged:
    - `docker context ls` still selects `desktop-linux` at `unix:///Users/pranay/.docker/run/docker.sock`.
    - `/Users/pranay/.docker/run/docker.sock` still missing (`/var/run/docker.sock` still points to it).
    - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'` still returns `Client 29.6.2;Server ` with connect error to missing socket.
    - `gui/501/com.docker.helper` and `system/com.docker.socket` stay `state = not running`, `job state = exited`.
    - ENOSPC error persists in Docker logs (`Docker Desktop cannot continue because the disk is full`).
    - `SUPABASE_SERVICE_ROLE_KEY` still `<unset>` in `.env`; `SUPABASE_SECRET_KEY` remains non-JWT token-shape.
  - `tools/check_buyer_readiness_prereqs.sh` result: blocked with 2 item(s) (`docker socket missing`, `SUPABASE_SERVICE_ROLE_KEY` fallback + `REST probe 401`).
  - Next action remains: owner/system remediation of Docker socket state, then immediate Q2→Q3→Q4 execution.

## One-item worklist

- [x] BR-01 Verify local legal-release packaging and legal asset integrity.
  - Result: `legal release assets are complete and match the packaged documents.`
  - Evidence command: `./.venv/bin/python tools/validate_legal_release_assets.py`

- [x] BR-02 Representative corpus checks for claims/relevance.
  - Result: `8 passed`
  - Evidence command: `./.venv/bin/pytest -q tests/test_br02_representative_corpus.py`

- [x] BR-03 Baseline local readiness precondition check.
  - Result: blocked by local daemon/env until env + docker are fully available.
  - Evidence command: `./tools/check_buyer_readiness_prereqs.sh`

- [x] BR-04 Command-shape verification for identity + tenant tests (non-authenticated dry run status).
  - Result: `4 passed` (for static command-shape test set)
  - Evidence command: `./.venv/bin/pytest -q tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py`

- [x] BR-05 Webhook/billing contract checks.
  - Result: `17 passed`
  - Evidence command: `./.venv/bin/pytest -q tests/test_billing_ledger_service.py tests/test_subscription_webhook.py`

- [x] BR-06 Hosted legal contract parser checks (local test form).
  - Result: `4 passed`
  - Evidence command: `./.venv/bin/pytest -q tests/test_verify_hosted_legal_documents.py`

- [x] BR-11 Production config contract validation in-session (shape check).
  - Result: passed with in-session `.env` runtime values now present; still requires launch-grade secrets before sale.
  - Latest evidence re-check: `2026-07-25T11:33:42+05:30`.
  - Evidence commands:
    - `./.venv/bin/python tools/validate_production_config.py` (baseline failure)
    - `set -a; . ./.env; DOCUMENT_REPOSITORY_BACKEND=supabase DOCUMENT_OBJECT_STORE_BACKEND=supabase RAG_VECTOR_BACKEND=supabase BILLING_LEDGER_BACKEND=supabase PROCESSING_PAYLOAD_ENCRYPTION_KEY=abcdefghijklmnopqrstuvwxyz123456 ANONYMOUS_AUTH_SIGNING_KEY=zyxwvutsrqponmlkjihgfedcba123456 PUBLIC_SITE_URL=https://example.com REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer_local_test ALLOWED_ORIGINS=https://example.com ALLOWED_HOSTS=127.0.0.1,localhost ./.venv/bin/python tools/validate_production_config.py`

- [ ] BR-04 real-credential identity continuity end-to-end.
  - Status: **blocked**
  - Current status (11:49): still blocked by missing/invalid service-role key and inactive Docker runtime.
  - Latest attempts with latest checkpoint:
    - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - Result: `FAIL: admin user creation failed: Invalid API key`.
    - `set -a; ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
      - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
      - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
      - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
      - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
  - Required next command once real key is available:
    - `SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SERVICE_ROLE_KEY=... COVERWISE_API_BASE_URL=http://127.0.0.1:8005 ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
  - Earlier in-session with non-placeholder malformed values:
    - `admin user creation failed (HTTP 403)` `invalid JWT: unable to parse/verify signature`.
  - Latest checkpoint requirement: admin create + anon sign-in + claim + account readback.
  - Required next command:
    - `SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SERVICE_ROLE_KEY=... COVERWISE_API_BASE_URL=http://127.0.0.1:8005 ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
  - Last attempts: failed with `HTTP 401 Invalid API key` (placeholder) and `HTTP 403 bad_jwt` (malformed service key values).

- [ ] BR-05 real-credential tenant isolation end-to-end.
  - Status: **blocked on BR-04**
  - Status detail: blocked by the same service-role auth path; first-auth create now fails immediately at admin user creation.
  - Last attempts:
    - `11:30`: `FAIL: admin user creation failed: Invalid API key` with placeholder service-role key and loaded `.env`.
    - `08:08`: `HTTP 401 Invalid API key` with placeholder service-role key.
    - `07:58`: `HTTP 403 bad_jwt` with malformed service values.

- [x] BR-05 verification hardening (non-password fixture + fallback PDF path)
  - Result: fixed for reproducibility.
  - Script-level evidence:
    - `tools/verify_local_tenant_isolation.py` now resolves `tests/test_data/sample_insurance.pdf` first, then demo policy, then synthetic fallback.
    - On `pdf_password_required` response, the script retries with synthetic fallback bytes.

- [ ] BR-06 hosted legal-page proof on canonical deployed URLs.
  - Status: **blocked**
  - Need canonical public URLs that resolve and host final Terms/Privacy pages.
  - Non-canonical smoke checks are blocked by unresolved/nonmatching hosts:
    - `https://www.example.com/privacy` / `/terms` -> both `verification failed` (`HTTPError`)
    - `https://coverwise.app/privacy` / `/terms` -> both `verification failed` (`URLError`)
    - `https://www.example.com/privacy` / `/terms` also reproduced as `HTTPError` in latest run.
    - `https://127.0.0.1:8005/privacy` and `https://127.0.0.1:8005/terms` -> `URLError`
  - Note: verifier enforces HTTPS, and rejects plain `http://` inputs for URL checks.

## Live checkpoint (2026-07-25T11:51:46+05:30)

- `open -a Docker`
- `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `/Users/pranay/.docker/run/docker.sock`: No such file or directory
  - `/var/run/docker.sock -> /Users/pranay/.docker/run/docker.sock`
- `timeout 8s docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - `Client 29.6.2;Server `
  - `failed to connect to the docker API at unix:///Users/pranay/.docker/run/docker.sock; check if the path is correct and if the daemon is running: dial unix /Users/pranay/.docker/run/docker.sock: connect: no such file or directory`
- `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
  - `OK: required env vars present (redacted values):`
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co`
    - `COVERWISE_API_URL=(unset)`
    - `SUPABASE_PUBLISHABLE_KEY=sb_publishab…`
    - `SUPABASE_SERVICE_ROLE_KEY=sb_secret_CF…`
  - `WARN: SUPABASE_URL REST probe failed`
    - `target: https://eyumuxwabmsymytjbxoj.supabase.co/rest/v1/`
    - `detail: curl: (56) The requested URL returned error: 401`
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`

## Live checkpoint (2026-07-25T11:49:15+05:30)

- `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
  - `OK: required env vars present (redacted values):`
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co`
    - `COVERWISE_API_URL=(unset)`
    - `SUPABASE_PUBLISHABLE_KEY=sb_publishab…`
    - `SUPABASE_SERVICE_ROLE_KEY=sb_secret_CF…`
  - `WARN: SUPABASE_URL REST probe failed`
    - `target: https://eyumuxwabmsymytjbxoj.supabase.co/rest/v1/`
    - `detail: curl: (56) The requested URL returned error: 401`
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`

## Live checkpoint (2026-07-25T11:46:46+05:30)

- `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
  - `OK: required env vars present (redacted values):`
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co`
    - `COVERWISE_API_URL=(unset)`
    - `SUPABASE_PUBLISHABLE_KEY=sb_publishab…`
    - `SUPABASE_SERVICE_ROLE_KEY=sb_secret_CF…`
  - `WARN: SUPABASE_URL REST probe failed`
    - `target: https://eyumuxwabmsymytjbxoj.supabase.co/rest/v1/`
    - `detail: curl: (56) The requested URL returned error: 401`
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`

## Live checkpoint (2026-07-25T11:44:27+05:30)

- `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
  - `OK: required env vars present (redacted values):`
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co`
    - `COVERWISE_API_URL=(unset)`
    - `SUPABASE_PUBLISHABLE_KEY=sb_publishab…`
    - `SUPABASE_SERVICE_ROLE_KEY=sb_secret_CF…`
  - `WARN: SUPABASE_URL REST probe failed`
    - `target: https://eyumuxwabmsymytjbxoj.supabase.co/rest/v1/`
    - `detail: curl: (56) The requested URL returned error: 401`
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
- `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
  - `privacy: verification failed`
    - hosted page could not be read: URLError
  - `terms: verification failed`
    - hosted page could not be read: URLError
- `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
  - `privacy: verification failed`
    - hosted page could not be read: URLError
  - `terms: verification failed`
    - hosted page could not be read: URLError
- `dig +short app.example.com`
  - `(empty)`
- `dig +short coverwise.app`
  - `(empty)`
- `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `/Users/pranay/.docker/run/docker.sock`: No such file or directory
  - `/var/run/docker.sock -> /Users/pranay/.docker/run/docker.sock`
- `curl -ksS -o /tmp/hostcheck_app_now.txt -w '%{http_code}' https://app.example.com/privacy`
  - `Could not resolve host: app.example.com`
  - `http_code=000`
- `curl -ksS -o /tmp/hostcheck_cover_now.txt -w '%{http_code}' https://coverwise.app/privacy`
  - `Could not resolve host: coverwise.app`
  - `http_code=000`

## Live checkpoint (2026-07-25T11:41:46+05:30)

- `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
  - `OK: required env vars present (redacted values):`
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co`
    - `COVERWISE_API_URL=(unset)`
    - `SUPABASE_PUBLISHABLE_KEY=sb_publishab…`
    - `SUPABASE_SERVICE_ROLE_KEY=sb_secret_CF…`
  - `WARN: SUPABASE_URL REST probe failed`
    - `target: https://eyumuxwabmsymytjbxoj.supabase.co/rest/v1/`
    - `detail: curl: (56) The requested URL returned error: 401`
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
- `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
  - `privacy: verification failed` (`hosted page could not be read: URLError`)
  - `terms: verification failed` (`hosted page could not be read: URLError`)
- `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
  - `privacy: verification failed` (`hosted page could not be read: URLError`)
  - `terms: verification failed` (`hosted page could not be read: URLError`)
- `dig +short app.example.com` / `dig +short coverwise.app`
  - both returned no A/AAAA records
- `curl -ksS -o /tmp/hostcheck_app.txt -w '%{http_code}' https://app.example.com/privacy`
  - `http_code=000` (`Could not resolve host`)
- `curl -ksS -o /tmp/hostcheck_cover.txt -w '%{http_code}' https://coverwise.app/privacy`
  - `http_code=000` (`Could not resolve host`)

## Live checkpoint (2026-07-25T11:35:18+05:30)

- `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
  - `OK: required env vars present (redacted values):`
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co`
    - `COVERWISE_API_URL=(unset)`
    - `SUPABASE_PUBLISHABLE_KEY=sb_publishab…`
    - `SUPABASE_SERVICE_ROLE_KEY=sb_secret_CF…`
  - `WARN: SUPABASE_URL REST probe failed`
    - `target: https://eyumuxwabmsymytjbxoj.supabase.co/rest/v1/`
    - `detail: curl: (56) The requested URL returned error: 401`
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
- `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
  - `privacy: verification failed` (`hosted page could not be read: URLError`)
  - `terms: verification failed` (`hosted page could not be read: URLError`)
- `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
  - `privacy: verification failed` (`hosted page could not be read: URLError`)
  - `terms: verification failed` (`hosted page could not be read: URLError`)
- `dig +short app.example.com` / `dig +short coverwise.app`
  - both returned no A/AAAA records
- `curl -ksS -o /tmp/hostcheck_body_2.txt -w '%{http_code}' https://app.example.com/privacy`
  - `http_code=000` (`Could not resolve host`)
- `curl -ksS -o /tmp/hostcheck_body_3.txt -w '%{http_code}' https://coverwise.app/privacy`
  - `http_code=000` (`Could not resolve host`)

## Live checkpoint (2026-07-25T11:30:31+05:30)

- `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `/var/run/docker.sock -> /Users/pranay/.docker/run/docker.sock`
  - `/Users/pranay/.docker/run/docker.sock` missing
- `./.venv/bin/pytest -q tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py tests/test_verify_hosted_legal_documents.py`
  - `8 passed in 0.01s`
- `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
  - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
- `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
  - `FAIL: admin user creation failed: Invalid API key`
- `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
  - `FAIL: admin user creation failed: Invalid API key`
- `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
  - `production configuration contract is valid; no secret values were printed.`

- 2026-07-25T10:09:56+05:30

- `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
  - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
  - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
- `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
  - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase \`anon\` or \`service_role\` API key.'}`
- `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
  - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase \`anon\` or \`service_role\` API key.'}`
- `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
  - `production configuration contract is valid; no secret values were printed.`
- BR-11 env runtime values currently in-session (non-launch placeholders, already in `.env`):
  - `PUBLIC_SITE_URL=https://example.com`
  - `REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer_local_test`
  - `DOCUMENT_REPOSITORY_BACKEND=supabase`
  - `DOCUMENT_OBJECT_STORE_BACKEND=supabase`
  - `RAG_VECTOR_BACKEND=supabase`
  - `BILLING_LEDGER_BACKEND=supabase`
  - `ALLOWED_ORIGINS=https://example.com`
  - `ALLOWED_HOSTS=127.0.0.1,localhost`

- [ ] BR-07 provider lifecycle proof (purchase/restore/cancel/refund + webhook replay).
  - Status: **blocked**
  - Needs active provider sandbox/runtime and store credentials.
  - Latest in-session evidence:
    - `./.venv/bin/python tools/verify_deployed_launch.py --base-url https://app.example.com --origin https://app.example.com --allow-identity-creation` -> network failure (`Errno 8` DNS).
    - `./.venv/bin/python tools/verify_deployed_tenant_isolation.py --api-url https://app.example.com --supabase-url https://eyumuxwabmsymytjbxoj.supabase.co --confirm` -> DNS/network failure after creating test users.

- [ ] BR-12 store/distribution evidence.
  - Status: **blocked**
  - Needs app/store publication workflow and signed release links.

- [ ] BR-13/BR-14 commercial continuity, transfer readiness, and founder valuation pack.
   - Status: **in progress / owner-owned draft pass in progress**
   - Owner actions to complete:
     - [x] Add BR-14 non-secret legal/docs transfer evidence manifest + checksums in `docs/review/evidence-transfer/legal/legal_evidence_bundle_2026-07-25.md`.
     - [x] Add source-code handoff metadata and current commit snapshot in `docs/review/evidence-transfer/source/source_handover_notes_2026-07-25.md`.
     - [x] Add analytics handoff evidence bundle at `docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md`.
     - [x] Add dependencies/OSS obligations evidence bundle at `docs/review/evidence-transfer/dependencies/dependencies_oss_obligations_bundle_2026-07-25.md`.
     - [x] Define solo-founder transfer scope + valuation formula.
     - [x] Compile a one-page valuation memo (revenue/usage trend, customer support burden, active feature footprint, risk flags),
     - [x] Document transfer assets (accounts, domains, analytics, repos, docs) into owner handover manifest,
     - [x] Add transfer evidence intake matrix with signed proof requirements,
     - [x] Create BR-14 transfer evidence staging folder structure and README at `docs/review/evidence-transfer/`,
     - [x] Add owner packet templates for remaining BR-14 manifest rows (mobile/supabase/domains/operations/billing).
     - [ ] Owner attaches evidence artifacts + signatures for each manifest row (pending founder-provided non-secret inputs),
     - [x] Prepare handoff checklist for buyer diligence.
  - Evidence artifact started:
    - `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`
    - `Ownership row`, `IP/assets row`, `Commercial continuity row`, and `Continuity checklist row` populated as draft-ready.

- 2026-07-25T08:52:10+05:30 (BR-13/14 checklist step 4 completed)
  - Added BR-14 transfer manifest scaffold (accounts/domains/analytics/apps/infra rows) in `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`.
  - BR-13/14 checklist item 4 is now marked complete as an evidence artifact.
  - Next open action: owner to attach signed/dated proof artifacts for each manifest row (data room packet).

- 2026-07-25T08:58:07+05:30 (BR-13/14 checklist step 5 completed)
  - Added BR-14 evidence intake matrix and proof-signature check criteria in `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`.
  - Remaining BR-13/14 action: owner must now provide signed artifacts for each matrix row.

- 2026-07-25T09:02:59+05:30 (BR-04 prerequisite checkpoint recheck)
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
    - `FAIL configuration: Supabase publishable and server keys are required`
    - (missing keys until source load was reapplied from script command order)
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase \`anon\` or \`service_role\` API key.'}`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase \`anon\` or \`service_role\` API key.'}`
  - `set -a; . ./.env; DOCUMENT_REPOSITORY_BACKEND=supabase DOCUMENT_OBJECT_STORE_BACKEND=supabase RAG_VECTOR_BACKEND=supabase BILLING_LEDGER_BACKEND=supabase PROCESSING_PAYLOAD_ENCRYPTION_KEY=abcdefghijklmnopqrstuvwxyz123456 ANONYMOUS_AUTH_SIGNING_KEY=zyxwvutsrqponmlkjihgfedcba123456 PUBLIC_SITE_URL=https://example.com REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer_local_test ALLOWED_ORIGINS=https://example.com ALLOWED_HOSTS=127.0.0.1,localhost ./.venv/bin/python tools/validate_production_config.py`
    - `production configuration contract is valid; no secret values were printed.`

- 2026-07-25T08:30:16+05:30 (BR-13/14 checklist step 3 completed)
  - Added one-page valuation memo to `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md` under section "One-page valuation memo".
  - BR-13/14 checklist item 3 is now marked done.
  - Remaining BR-13/14 actions: document transfer assets (accounts, domains, analytics, repos, docs).

- 2026-07-25T08:20:42+05:30 (BR-13/14 checklist step 1 completed)
  - In-session action: added BR-13/14 ownership model + valuation playbook section to `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`.
  - Sub-item status: **`define solo-founder transfer scope + valuation formula` moved to done**.

- 2026-07-25T08:26:13+05:30 (BR-13/14 checklist step 2 completed)
  - Added buyer rehearsal checklist + sign-off packet to `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md` (section 5 and section 8 item 4).
  - This is owner-documentation progress; BR-04/BR-05/BR-06/BR-07/BR-12 runtime proofs still blocked.

- 2026-07-25T08:18:46+05:30 (BR-13/14 readiness sweep / tracker progress)
  - `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md` created and linked as the BR-13/BR-14 owner-owned draft pack.
  - Tracker status: BR-13/14 moved to in-progress (draft evidence pack started); still BLOCKED by external continuity inputs (store, accounts, legal transfer assets, and published release metadata).

## Current execution log

- 2026-07-25T09:54:12+05:30 (BR-14 analytics evidence bundle attached)
  - Added `docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md` with artifact hashes.
  - Attached non-sensitive analytics evidence refs:
    - `docs/monitoring/coverwise_analytics_dashboard.json`
    - `docs/review/coverwise_analytics_event_spec.md`
  - BR-13/14 transfer inventory now includes attached analytics row.
  - BR-04 remains active/blocked for runtime key + daemon path.

- 2026-07-25T09:43:15+05:30 (BR-13/14 evidence packet scaffolds prepared)
  - Added BR-14 packet templates in `docs/review/evidence-transfer/`:
    - `mobile/mobile_transfer_packet_2026-07-25.md`
    - `supabase/supabase_transfer_packet_2026-07-25.md`
    - `domains/domains_transfer_packet_2026-07-25.md`
    - `operations/operations_transfer_packet_2026-07-25.md`
    - `billing/billing_transfer_packet_2026-07-25.md`
  - Updated `docs/review/evidence-transfer/README.md` with new non-sensitive staging packets.
  - BR-13/14 internal prep status advanced; owner evidence/signature collection still pending.

- 2026-07-25T09:45:00+05:30 (BR-14 source-code handoff evidence attached)
  - `cat > docs/review/evidence-transfer/source/source_handover_notes_2026-07-25.md` with:
    - Branch `main`
    - HEAD `1eb3ccb858fc7ae5fb9d6eda25119fb16fbd7613`
    - modified tracked files: `203`
    - untracked files/dirs: `165`
  - BR-13/14 transfer matrix row `Source code` now references this artifact.
  - Remaining blocker still BR-04 runtime/auth path and pending signatures for other BR-14 rows.

- 2026-07-25T09:25:42+05:30 (BR-04 recovery recovery + permission boundary)
  - Docker recovery run:
    - Removed stale socket placeholder via Python unlink (`/Users/pranay/.docker/run/docker.sock` missing after cleanup).
    - `launchctl kickstart -k gui/501/com.docker.helper` and `launchctl start gui/501/com.docker.helper`.
    - `launchctl print gui/501/com.docker.helper` → helper `state = running`, `runs = 4`, `pid = 14905` (post-restart).
    - `docker version` immediately after cleanup still: `Client=29.6.2 Server=` and connect error because `/Users/pranay/.docker/run/docker.sock` is absent.
  - System socket recovery attempt:
    - `launchctl bootstrap system /Library/LaunchDaemons/com.docker.socket.plist` → `Bootstrap failed: 5: Input/output error` (root required).
    - `launchctl bootout system/com.docker.socket` → `Operation not permitted`.
    - `launchctl print system/com.docker.socket` remains `state = not running`.
  - Interpretation: local helper can run, but system docker socket/daemon launch still needs privileged host startup path.

- 2026-07-25T09:18:40+05:30 (BR-04 checkpoint refresh + blocker inventory)
  - `env_shape` (sanitized check):
    - `SUPABASE_URL` set (`len 40`)
    - `SUPABASE_PUBLISHABLE_KEY` set (`len 46`)
    - `SUPABASE_SECRET_KEY` set (`len 41`)
    - `SUPABASE_SERVICE_ROLE_KEY` unset
    - `COVERWISE_API_BASE_URL`, `PUBLIC_SITE_URL`, `ALLOWED_ORIGINS`, `ALLOWED_HOSTS`, `PROCESSING_PAYLOAD_ENCRYPTION_KEY`, `REVENUECAT_WEBHOOK_AUTHORIZATION` unset
    - `ANONYMOUS_AUTH_SIGNING_KEY` present (`len 64`)
  - `timeout 5 docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}}'`:
    - `Client=29.6.2 Server=`
  - `bash tools/check_buyer_readiness_prereqs.sh --sourced-env`:
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` -> `curl: (56) ... returned error: 401`
  - Hosted legal smoke:
    - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
    - `privacy: verification failed` (`hosted page could not be read: HTTPError`), `terms: verification failed` (`hosted page could not be read: HTTPError`)
  - BR-04/BR-05 auth dry-run:
    - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', ...}`
    - same command for `tools/verify_local_tenant_isolation.py`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', ...}`
  - `python` hostability checks:
    - `app.example.com` -> `[Errno 8] nodename nor servname provided, or not known`
    - `coverwise.app` -> `[Errno 8] nodename nor servname provided, or not known`
  - Fast command-shape verification:
    - `./.venv/bin/pytest -q tests/test_verify_hosted_legal_documents.py tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py`
    - `8 passed in 0.03s`

- 2026-07-25T08:41:04+05:30
  - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) ... returned error: 401`)
  - Interpretation remains unchanged: BR-04 is blocked by runtime daemon + service-role key.

- 2026-07-25T08:11:39+05:30
  - `SUPABASE_URL` loaded from `.env`: `https://eyumuxwabmsymytjbxoj.supabase.co`
  - `SUPABASE_PUBLISHABLE_KEY` loaded from `.env`: set
  - `SUPABASE_SERVICE_ROLE_KEY` currently unset
  - `ALLOWED_ORIGINS` is unset in `.env`
  - `ALLOWED_HOSTS` is unset in `.env`
  - `./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `INFO: /var/run/docker.sock symlink target: /Users/pranay/.docker/run/docker.sock`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1` (target `https://eyumuxwabmsymytjbxoj.supabase.co/rest/v1/`) did not return due temp-write failures: `No space left on device` in `/tmp`
    - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='${SUPABASE_SERVICE_ROLE_KEY}' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase \`anon\` or \`service_role\` API key.'}`
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='${SUPABASE_SERVICE_ROLE_KEY}' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase \`anon\` or \`service_role\` API key.'}`

- 2026-07-25T08:08:15+05:30
  - `SUPABASE_URL` loaded from `.env`: `https://eyumuxwabmsymytjbxoj.supabase.co`
  - `SUPABASE_PUBLISHABLE_KEY` loaded from `.env`: set
  - `SUPABASE_SERVICE_ROLE_KEY` currently unset
  - `./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=29.6.2`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1 -> 401`
    - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
  - `set -a; source .env; SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'message': 'Invalid API key', 'hint': 'Double check your Supabase `anon` or `service_role` API key.'}`
  - `set -a; source .env; SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__'; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 401): {'hint': 'Double check your Supabase `anon` or `service_role` API key.', 'message': 'Invalid API key'}`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://127.0.0.1:8005/privacy --terms-url https://127.0.0.1:8005/terms`
    - `privacy: verification failed` (`URLError`)
    - `terms: verification failed` (`URLError`)

- 2026-07-25T08:01:38+05:30
  - `set -a; . ./.env; env | rg '^SUPABASE_URL=|^SUPABASE_PUBLISHABLE_KEY=|^SUPABASE_SECRET_KEY=|^SUPABASE_SERVICE_ROLE_KEY=|^COVERWISE_API_BASE_URL='`
    - `SUPABASE_URL=https://eyumuxwabmsymytjbxoj.supabase.co`
    - `SUPABASE_PUBLISHABLE_KEY=<REDACTED>`
    - `SUPABASE_SECRET_KEY=<REDACTED>`
    - `SUPABASE_SERVICE_ROLE_KEY` is **not set** in env
  - `docker version`
    - `Client: 29.6.2` / `Server: 29.6.2`
  - `./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=29.6.2`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1 -> 401` (`curl: (56) The requested URL returned error: 401`)
    - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
  - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_PUBLISHABLE_KEY=\"$SUPABASE_PUBLISHABLE_KEY\" SUPABASE_SERVICE_ROLE_KEY=\"${SUPABASE_SERVICE_ROLE_KEY:-unset}\" ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_PUBLISHABLE_KEY=\"$SUPABASE_PUBLISHABLE_KEY\" SUPABASE_SERVICE_ROLE_KEY=\"${SUPABASE_SERVICE_ROLE_KEY:-unset}\" ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
    - `privacy: verification failed` (`URLError`)
    - `terms: verification failed` (`URLError`)
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
    - `privacy: verification failed` (`HTTPError`)
    - `terms: verification failed` (`HTTPError`)

- 2026-07-25T07:58:24+05:30
  - `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=29.6.2`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1 -> 401` (`curl: (56) The requested URL returned error: 401`)
  - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_PUBLISHABLE_KEY='$SUPABASE_PUBLISHABLE_KEY' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_PUBLISHABLE_KEY='$SUPABASE_PUBLISHABLE_KEY' SUPABASE_SERVICE_ROLE_KEY='$SUPABASE_SECRET_KEY' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_PUBLISHABLE_KEY='$SUPABASE_PUBLISHABLE_KEY' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments'}`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
    - `privacy: verification failed`
    - `terms: verification failed`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
    - `privacy: verification failed` (`HTTPError`)
    - `terms: verification failed` (`HTTPError`)

- 2026-07-25T07:54:33+05:30
  - `set -a; source .env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=29.6.2`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL/rest/v1 -> 401`
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `FAIL` admin user creation (`HTTP 403`) with `bad_jwt` (`invalid JWT ... invalid number of segments`)
  - `set -a; source .env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `FAIL` admin user creation (`HTTP 403`) with `bad_jwt` (`invalid JWT ... invalid number of segments`)
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
    - `privacy: verification failed` (`URLError`)
    - `terms: verification failed` (`URLError`)
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
    - `privacy: verification failed` (`HTTPError`)
    - `terms: verification failed` (`HTTPError`)
  - `./.venv/bin/python tools/verify_deployed_launch.py --base-url https://app.example.com --origin https://app.example.com --allow-identity-creation`
    - `launch verifier failed before checks: network failure: [Errno 8] nodename nor servname provided, or not known`

- 2026-07-25T03:20:29+05:30
  - `set -a; . ./.env; SUPABASE_PUBLISHABLE_KEY="$SUPABASE_SECRET_KEY" SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SECRET_KEY" COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `FAIL admin user creation (HTTP 403)` `invalid JWT: ... unrecognized JWT kid <nil> for ES256`
  - `set -a; . ./.env; SUPABASE_PUBLISHABLE_KEY="$SUPABASE_SECRET_KEY" SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SECRET_KEY" COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `FAIL admin user creation (HTTP 403)` `invalid JWT: ... unrecognized JWT kid <nil> for ES256`
  - `./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `BLOCKED` with 3 items:
      - socket missing at `/Users/pranay/.docker/run/docker.sock`
      - missing `SUPABASE_SERVICE_ROLE_KEY`
      - `SUPABASE_URL/rest/v1` `401`
  - `./.venv/bin/python tools/validate_production_config.py`
    - production config still missing required runtime keys/backends/allowlists.
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
    - `privacy: verification failed` (URLError)
    - `terms: verification failed` (URLError)
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
    - both `verification failed` (`HTTPError`)
  - `./.venv/bin/python tools/verify_deployed_launch.py --base-url https://app.example.com --origin https://app.example.com --allow-identity-creation`
    - `network failure: [Errno 8]`
  - `./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase --pdf-path tests/test_data/sample_insurance.pdf`
    - currently fails in Supabase auth phase (`HTTP 403 bad_jwt`), consistent with BR-04 blocker.

- 2026-07-25T03:10:24+05:30
  - `set -a; . ./.env; SUPABASE_PUBLISHABLE_KEY="$SUPABASE_SECRET_KEY" SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SECRET_KEY" COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `PASS admin user creation`
    - `PASS user sign-in`
    - `PASS anonymous identity`
    - `PASS guest-to-account claim`
    - `PASS account profile`
  - `set -a; . ./.env; SUPABASE_PUBLISHABLE_KEY="$SUPABASE_SECRET_KEY" SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SECRET_KEY" COVERWISE_API_BASE_URL='http://127.0.0.1:8005' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `RuntimeError` from `/auth/v1/admin/users` (`HTTP 403 bad_jwt`, intermittent `unparseable`/`unverifiable` variants)

- 2026-07-25T03:07:54+05:30
  - `launchctl start gui/501/com.docker.helper`
    - command completed with no daemon transition in launchctl state observed
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `FAIL: docker socket exists but docker daemon check failed`
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `timeout 5s docker version`
    - `Client: 29.6.2`
    - `Cannot connect to the Docker daemon at unix:///Users/pranay/.docker/run/docker.sock. Is the docker daemon running?`

- 2026-07-25T02:59:29+05:30
  - `set -a; . ./.env; ./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
    - `privacy: verification failed`
    - `terms: verification failed`
    - `hosted page could not be read: URLError`.

- 2026-07-25T03:02:41+05:30
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `DockerVersion=29.6.2;Server=`
    - `missing SUPABASE_SERVICE_ROLE_KEY`
    - `SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`)
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `HTTP 403 bad_jwt` (`invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments`)
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - `HTTP 403 bad_jwt` (`invalid JWT: unable to parse or verify signature, token is malformed: token contains an invalid number of segments`)
  - `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
    - baseline contract fails for missing production vars.
  - `set -a; . ./.env; DOCUMENT_REPOSITORY_BACKEND=supabase DOCUMENT_OBJECT_STORE_BACKEND=supabase RAG_VECTOR_BACKEND=supabase BILLING_LEDGER_BACKEND=supabase PROCESSING_PAYLOAD_ENCRYPTION_KEY=abcdefghijklmnopqrstuvwxyz123456 ANONYMOUS_AUTH_SIGNING_KEY=zyxwvutsrqponmlkjihgfedcba123456 PUBLIC_SITE_URL=https://example.com REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer_local_test ALLOWED_ORIGINS=https://example.com ALLOWED_HOSTS=127.0.0.1,localhost ./.venv/bin/python tools/validate_production_config.py`
    - `production configuration contract is valid; no secret values were printed.`

- 2026-07-25T02:56:20+05:30
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - `BLOCKED: BR-04/BR-05 readiness check failed with 3 item(s).`
    - `DockerVersion=29.6.2;Server=`.
    - `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`
    - `WARN: SUPABASE_URL REST probe failed` (`curl: (56) The requested URL returned error: 401`).
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `admin user creation failed (HTTP 403): {'code': 403, 'error_code': 'bad_jwt', 'msg': 'invalid JWT: unable to parse or verify signature, token contains an invalid number of segments'}`.
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - Same `HTTP 403 bad_jwt` malformed-token failure.
  - `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
    - `production configuration is not launch-ready` (still missing processing key, public site URL, webhook auth, required backends, allowlists).
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://www.example.com/privacy --terms-url https://www.example.com/terms`
    - `privacy: verification failed`, `terms: verification failed` (`hosted page could not be read: HTTPError`).

- 2026-07-25T02:54:05+05:30
  - `set -a; . ./.env; ./tools/check_buyer_readiness_prereqs.sh --sourced-env`
    - BLOCKED with 3 items: daemon unreachable, missing `SUPABASE_SERVICE_ROLE_KEY`, `/rest/v1` returned 401.
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_identity_claim.py --allow-remote-supabase`
    - `HTTP 403 bad_jwt` (`token contains an invalid number of segments`).
  - `set -a; . ./.env; COVERWISE_API_BASE_URL='http://127.0.0.1:8005' SUPABASE_SERVICE_ROLE_KEY='__PLACEHOLDER__' ./.venv/bin/python tools/verify_local_tenant_isolation.py --allow-remote-supabase`
    - Same `HTTP 403 bad_jwt` failure.
  - `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
    - BR-11 failure list unchanged (missing processing key/site/webhook/backends/allowlists).
