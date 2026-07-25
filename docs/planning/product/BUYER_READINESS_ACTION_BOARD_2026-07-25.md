# Buyer-readiness action board (solo-founder mode)

Last updated: 2026-07-25T12:49:23+05:30

## Objective

Keep this file as the active execution board: one item checked only when command/runtime evidence exists in this repository.

## Latest checkpoint (2026-07-25T12:49:23+05:30)

- `docker context show`: `desktop-linux` -> `/Users/pranay/.docker/run/docker.sock`
- `ls -la /Users/pranay/.docker/run`: only socket analytics/proxy files, no `docker.sock` file
- `/var/run/docker.sock -> /Users/pranay/.docker/run/docker.sock` (target missing)
- `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'` still fails: missing socket
- `open -a Docker` still fails with `_LSOpenURLsWithCompletionHandler() ... error -1712`
- `launchctl print gui/501/com.docker.helper`: `state = not running`, `job state = exited`, `runs = 15`
- `launchctl print system/com.docker.socket`: `state = not running`, `job state = exited`, `runs = 7`
- Docker storage/log health:
  - `~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw`: `24G`
  - `df /System/Volumes/Data`: `825Gi used / 63Gi free`
  - `monitor.log` + `com.docker.backend.log` still show `no space left on device` errors for `/init.log` write.
- Decision: Q1 remains blocked (socket/runtime remains unavailable); next action remains `SUPABASE_SERVICE_ROLE_KEY` injection and hostability/domain recovery.

## Latest checkpoint (2026-07-25T12:38:19+05:30)

- `launchctl kickstart -k gui/501/com.docker.helper` + `launchctl start gui/501/com.docker.helper` + `launchctl start system/com.docker.socket` attempted.
- Result: helper/service jobs still `not running/exited`; no new `/Users/pranay/.docker/run/docker.sock`.
- `ENOSPC` and `Docker Desktop cannot continue because the disk is full` still present in host logs.

## Latest checkpoint (2026-07-25T12:37:04+05:30)

- `tools/check_buyer_readiness_prereqs.sh` still fails with:
  - missing socket at `/Users/pranay/.docker/run/docker.sock`
  - normalized service key (`SUPABASE_SERVICE_ROLE_KEY` is unset; fallback from non-JWT secret)
  - `/rest/v1` 401.
- `docker context show` remains `desktop-linux`; `docker version` still fails with no daemon socket.
- launchd services still stopped:
  - `gui/501/com.docker.helper` = `state = not running`, `job state = exited`
  - `system/com.docker.socket` = `state = not running`, `job state = exited`
- hosted legal probe remains unresolved (`URLError` on `app.example.com`, `coverwise.app`; `HTTPError` on `example.com`).
- Decision unchanged: in-progress Q1/Q2 dependency recovery remains blocked by environment/runtime and missing owner secret.

## Current owner-controlled blockers

- `SUPABASE_SERVICE_ROLE_KEY` is still unset in `.env`.
- Docker socket is currently missing at `/Users/pranay/.docker/run/docker.sock`.
- Canonical deployed hostnames are unresolved in-session (`app.example.com`, `coverwise.app`).
- Runtime production variables for BR-11 are now populated for contract validation (`supabase` backends, keys, allowlists, webhook/site defaults), but still require launch-ready values where applicable.

## Live todo sequence

- [x] BR-04/BR-06 readiness + legal-holdability probe (12:12:37+05:30).
  - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
  - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `docker context ls`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - Result: blocked with unchanged dependency conditions:
    - `FAIL: docker socket missing at /Users/pranay/.docker/run/docker.sock`
    - `INFO: SUPABASE_SERVICE_ROLE_KEY not set; normalizing from SUPABASE_SECRET_KEY.`
    - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).`
    - hosted legal probe for both app.example.com and coverwise.app returned `hosted page could not be read: URLError`.

- [x] BR-04 readiness follow-up probe at `2026-07-25T12:10:59+05:30`.
  - `docker context ls`
  - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - `docker version --format 'Client {{.Client.Version}};Server {{.Server.Version}}'`
  - `launchctl print gui/501/com.docker.helper`
  - `launchctl print system/com.docker.socket`
  - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `docker context ls`
  - `rg -n "Docker Desktop cannot continue because the disk is full|ENOSPC|no space left|vm/init.log|com.docker.backend.log" ~/Library/Containers/com.docker.docker/Data/log/host/*.log`
  - `Result: remains blocked (missing socket + auth normalization path still unresolved).`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
    - `privacy: verification failed` (`hosted page could not be read: URLError`)
    - `terms: verification failed` (`hosted page could not be read: URLError`)
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
    - `privacy: verification failed` (`hosted page could not be read: URLError`)
    - `terms: verification failed` (`hosted page could not be read: URLError`)

- [x] BR-04 readiness preflight + BR-06 deployed-hostability recheck at `2026-07-25T12:01:59+05:30`.
  - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
  - `dig +short app.example.com` (no A/AAAA record)
  - `dig +short coverwise.app` (no A/AAAA record)
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://coverwise.app/privacy --terms-url https://coverwise.app/terms`
  - `curl -ksS -o /tmp/hostcheck_app_now.txt -w '%{http_code}' https://app.example.com/privacy` → `http_code=000` (`Could not resolve host`)
  - `curl -ksS -o /tmp/hostcheck_cover_now.txt -w '%{http_code}' https://coverwise.app/privacy` → `http_code=000` (`Could not resolve host`)
  - `ls -l /Users/pranay/.docker/run/docker.sock /var/run/docker.sock`
  - Additional: `open -a Docker`, `launchctl print gui/501/com.docker.helper`, `launchctl print system/com.docker.socket` still show helper/socket not running.
  - `BLOCKED: BR-04/BR-05 readiness check failed with 2 item(s).` (`docker socket` + fallback service-role normalization)
  - Result: still blocked on 3 items for BR-04/BR-05 (`docker socket missing`, `invalid/missing service-role key`) and BR-06 hostability remains unresolved.

- [x] BR-04 check: run `tools/check_buyer_readiness_prereqs.sh` with sourced `.env` (latest timestamp `2026-07-25T10:34:53+05:30`).
  - Evidence: command failed with 3 blockers (`docker socket missing`, missing `SUPABASE_SERVICE_ROLE_KEY`, `/rest/v1` auth 401).
- [x] BR-04/BR-05 blocker recheck at `2026-07-25T10:27:51+05:30`.
  - Evidence:
    - `set -a; . ./.env; timeout 30s bash tools/check_buyer_readiness_prereqs.sh`
    - `check_buyer_readiness_prereqs.sh` command produced: `FAIL: docker socket missing`, `FAIL: required env vars missing: SUPABASE_SERVICE_ROLE_KEY`, `/rest/v1` 401.
  - `tools/verify_local_identity_claim.py` with placeholder key: `HTTP 401 Invalid API key`.
  - `tools/verify_local_tenant_isolation.py` with placeholder key: `HTTP 400 {}` in auth/create call.
- [x] BR-06 hostability + legal-host proof probe.
  - `dig +short` for `app.example.com`, `coverwise.app`, `nrmmvtpyaf.ap-south-1.awsapprunner.com` returned no DNS A/AAAA answers.
  - `curl` against `https://app.example.com/privacy` and `https://coverwise.app/privacy` returned no host resolution (`http_code=000`).
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://example.com/privacy --terms-url https://example.com/terms`
    - `privacy: verification failed` (`hosted page could not be read: HTTPError`)
    - `terms: verification failed` (`hosted page could not be read: HTTPError`)
- [x] BR-04 check: verify env key shape from `.env`.
  - Evidence: `SUPABASE_SERVICE_ROLE_KEY=<unset>`; publishable/secret are present but non-JWT shapes.
- [ ] BR-04 run: load valid `SUPABASE_SERVICE_ROLE_KEY` in `.env` and rerun `tools/verify_local_identity_claim.py --allow-remote-supabase`.
- [x] BR-13/14 dependency evidence: generate and attach production SBOM artifact for transfer continuity.
  - Command: `bash tools/generate_production_sbom.sh docs/review/evidence-transfer/analytics/production-dependencies-sbom-2026-07-25.json`
  - Result: `SBOM generated ...; locked-graph audit found no known vulnerabilities.`
  - Checksum: `ea74643c50dcecaf8cf4da13fe04ddb81aa26b6fe9d5a7868ba12655eaaadb86`
  - Attached to `docs/review/evidence-transfer/analytics/analytics_evidence_bundle_2026-07-25.md`, `docs/review/evidence-transfer/README.md`, and `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`.
  - Latest checkpoint: `2026-07-25T10:34:53+05:30` still blocked with `.env`-sourced placeholder returning HTTP 401/URLError style failures.
- [x] BR-04/BR-05 command harness recheck (non-secret only).
  - `./.venv/bin/pytest -q tests/test_verify_local_identity_claim.py tests/test_verify_local_tenant_isolation.py` -> `4 passed`.
  - `./.venv/bin/pytest -q tests/test_verify_hosted_legal_documents.py` -> `4 passed`.
  - `set -a; ./.env; ./.venv/bin/python tools/validate_production_config.py` -> `production configuration contract is valid; no secret values were printed.`
  - `./.venv/bin/python tools/verify_hosted_legal_documents.py --privacy-url https://app.example.com/privacy --terms-url https://app.example.com/terms` -> URLError on both paths (host currently non-resolvable).
- [ ] BR-05 run: rerun `tools/verify_local_tenant_isolation.py --allow-remote-supabase` after BR-04 passes.
- [x] BR-11 config: set canonical runtime values (`PROCESSING_PAYLOAD_ENCRYPTION_KEY`, `PUBLIC_SITE_URL`, `REVENUECAT_WEBHOOK_AUTHORIZATION`, backends, `ALLOWED_ORIGINS`, `ALLOWED_HOSTS`) and rerun `tools/validate_production_config.py`.
  - `set -a; . ./.env; ./.venv/bin/python tools/validate_production_config.py`
  - `production configuration contract is valid; no secret values were printed.`
- [x] BR-14 packet file inventory validated: all BR-14 packet and bundle files exist in expected folders.
  - Evidence: `python` audit script run against `docs/review/evidence-transfer/*/*_2026-07-25.md` and related pack manifests.
  - Result: `TOTAL_EXPECTED 11`, `EXISTS 11`, `RESULT PASS` (all expected files present with non-empty content).
- [x] BR-14 source handoff snapshot refreshed in `docs/review/evidence-transfer/source/source_handover_notes_2026-07-25.md`.
  - Evidence: runtime workspace counts captured via git:
    - branch: `main`
    - head: `1eb3ccb858fc7ae5fb9d6eda25119fb16fbd7613`
    - modified tracked files: `200`
    - untracked files/dirs: `185`
    - timestamp in artifact: `2026-07-25T11:12:20+05:30`
- [x] BR-14 manifest status map refreshed for non-secret evidence-transfer staging.
  - Evidence: `docs/review/evidence-transfer/README.md` now includes one-item handoff status for all BR-14 rows with attached/prepared/signature-state.
- [x] BR-14 packet scaffolds prepared: ownership/IP packet and commercial/liabilities packet.
  - `docs/review/evidence-transfer/ownership/ownership_ip_transfer_packet_2026-07-25.md`
  - `docs/review/evidence-transfer/commercial/commercial_liabilities_transfer_packet_2026-07-25.md`
- [ ] BR-06 deployed legal proof: resolve deployed URL and run `tools/verify_hosted_legal_documents.py` with live terms/privacy links.
- [ ] BR-07 provider lifecycle proof: rerun deployed launch / webhook checks once provider host and credentials are available.
- [ ] BR-12 store/distribution proof: attach store ownership/release handoff evidence in BR-14 packet.
- [ ] BR-13/BR-14 commercial continuity: close open matrix rows with owner signatures + evidence links for entity/account/IP/source/documentation continuity.

## In-progress completion status

- Completed this pass: 12 (all with evidence snapshots and template prep).
- Blocked/pending: 5.

## Next next action (strict sequence)

- [ ] Unblock BR-04 run by inserting a valid `SUPABASE_SERVICE_ROLE_KEY` into `.env`.
  - Why: all BR-04/BR-05 runtime checks are sequenced and cannot proceed with placeholder/invalid JWT material.
- [ ] Restore local docker socket before re-running BR-04/BR-05 real-credential commands.
  - latest attempt: `open -a Docker` issued, followed by `ls` + `docker version`, still no `/Users/pranay/.docker/run/docker.sock`.
- [ ] Re-run BR-04 real-credential identity continuity (`tools/verify_local_identity_claim.py --allow-remote-supabase`) immediately after key injection.
- [ ] Re-run BR-05 tenant-isolation continuity only after BR-04 passes.

## Sources of truth

- `docs/planning/product/BUYER_READINESS_LIVE_TODO_LIST_2026-07-25.md`
- `docs/planning/product/BUYER_READINESS_TODO_TRACKER_2026-07-25.md`
- `docs/planning/product/BUYER_READINESS_TODO_LIST_2026-07-25.md`
- `docs/review/TRANSACTION_READINESS_EVIDENCE_PACK_2026-07-25.md`

## Owner-only rule

No external legal-counsel or enterprise governance dependency is required for this sale track. Founder-owned legal/docs and operational continuity evidence is the required baseline; external advisory is optional if explicitly requested.
