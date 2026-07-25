# Reusable project tools

## `verify_local_tenant_isolation.py`

Runs a disposable, local-only BR-05 replay: two synthetic Supabase users,
canonical document upload, cross-owner API/Storage denial, owner deletion, and
post-delete absence. It refuses remote URLs and requires local publishable and
server keys. It is not evidence of deployed RLS, durable-worker deletion, or
production erasure.

```bash
python3 tools/verify_local_tenant_isolation.py
```

## `evaluate_provider_smoke.py`

Runs three synthetic-only checks against an explicitly selected hosted provider:
structured JSON extraction, refusal to invent an absent field, and source-ID
grounding. It never reads the CoverWise policy corpus and records only
sanitized outcome categories, timings, and model metadata. Use it before a
provider is admitted to a governed corpus evaluation.

```bash
python tools/evaluate_provider_smoke.py --provider openai \
  --output docs/review/evidence/provider-smoke/openai-synthetic.json
```

For an approved credential held in another project, pass its dotenv path
explicitly. The file is parsed without being sourced or printed:

```bash
python tools/evaluate_provider_smoke.py --provider openrouter \
  --dotenv /Users/pranay/Projects/orbitcover-d2c/.env \
  --output docs/review/evidence/provider-smoke/openrouter-synthetic.json
```

This is an API-contract smoke test, not an insurance-accuracy, mobile-device,
privacy, or production-readiness evaluation.

## `validate_production_config.py`

Checks the canonical Cloud Run + Supabase launch configuration without exposing
secret values. Run it locally or in CI before a deployment:

```bash
ENVIRONMENT=production uv run --python .venv/bin/python python tools/validate_production_config.py \
  --env-file /secure/path/coverwise-production.env
```

It requires the production persistence/vector backends, private Supabase
credentials, a strong anonymous-auth signing key, explicit HTTPS public/CORS
origins, and non-debug logging.

For the Cloud Run deploy script, the four secret values are intentionally
bound from Secret Manager rather than placed in the runtime env file. The
deployment preflight accepts those bindings explicitly:

```bash
uv run --python .venv/bin/python python tools/validate_production_config.py \
  --env-file /secure/path/coverwise-runtime.env.yaml \
  --secret-bound OPENAI_API_KEY \
  --secret-bound SUPABASE_SERVICE_ROLE_KEY \
  --secret-bound ANONYMOUS_AUTH_SIGNING_KEY \
  --secret-bound REVENUECAT_WEBHOOK_AUTHORIZATION
```

## `build_mobile_release.sh`

Builds the Android App Bundle only after explicit public release configuration
is supplied; it runs legal-asset, mobile analysis, and test checks first. It
does not accept server secrets. The legal preflight rejects unresolved legal
placeholders and packaged/publishable-document drift; it is intentionally a
release block until counsel or the accountable owner finalizes the terms.

```bash
COVERWISE_API_BASE_URL=https://api.example.com \
COVERWISE_PRIVACY_POLICY_URL=https://www.example.com/privacy \
COVERWISE_TERMS_OF_SERVICE_URL=https://www.example.com/terms \
COVERWISE_SUPPORT_EMAIL=support@example.com \
COVERWISE_PRIVACY_POLICY_VERSION=1.0 \
SUPABASE_URL=https://project.supabase.co \
SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
REVENUECAT_API_KEY=<android-public-sdk-key> \
tools/build_mobile_release.sh
```

Replace every example value with a live production value. The script rejects
the placeholders shown above and rejects RevenueCat secret (`sk_`) and OAuth
(`atk_`) credentials; only the public SDK key for the Android app belongs in a
mobile build. Before running Flutter, it also checks that the configured HTTPS
Privacy and Terms pages serve the exact approved legal sources.

## `validate_legal_release_assets.py`

Checks that the versioned legal sources match the Flutter-packaged copies and
contain no known unresolved legal placeholders. It is called by the mobile
release build, and may be run independently:

```bash
python tools/validate_legal_release_assets.py
```

## `verify_hosted_legal_documents.py`

Fetches the configured HTTPS Privacy and Terms URLs and verifies that each page
returns a `no-store` response whose page and header SHA-256, plus decoded
content, match the canonical `docs/legal/` source. It limits each response to
1 MB and does not send credentials or customer data. Run it after a
non-production or production-like deployment; unresolved legal placeholders
still block release before this check can pass.

```bash
.venv/bin/python tools/verify_hosted_legal_documents.py \
  --privacy-url https://www.example.com/privacy \
  --terms-url https://www.example.com/terms
```

## `run_tracked_source_secret_scan.sh`

Scans tracked release-relevant source plus untracked, non-ignored source under
review with Gitleaks. It deliberately excludes ignored local state, generated
artifacts, documentation examples, and test fixtures so a local `.env` or a
vendor build cannot be mistaken for a release-source result. It redacts any
match and returns non-zero on a finding.

```bash
tools/run_tracked_source_secret_scan.sh
```

## `run_supply_chain_audit.sh`

Runs the direct, pinned production-dependency vulnerability scan and the
tracked release-source Gitleaks scan. The dependency result covers declared
production pins; it does not replace a fully resolved, hash-locked transitive
dependency audit.

```bash
tools/run_supply_chain_audit.sh
```

## `generate_production_sbom.sh`

Generates a CycloneDX JSON component inventory from the canonical Linux x86_64
production lock. It intentionally does **not** turn a vulnerability finding
into a passing audit: if findings exist, it still emits the valid SBOM and
prints a warning so the inventory can be retained with the release evidence.
It refuses to overwrite an existing file.

```bash
bash tools/generate_production_sbom.sh /secure/release-evidence/coverwise-production-sbom.json
```

The generated SBOM is a review artifact, not publication, image provenance, or
container-scan proof. Publish/sign only after the remaining locked-graph and
container-image gates are resolved.

## `extract_locked_license_metadata.py`

Builds a licence-review candidate from the pinned packages in the canonical
production lock and the published package metadata in the interpreter used to
run it. It refuses to overwrite an existing report and labels missing
packages, version mismatches, and the absence of legal approval explicitly.
It does not infer SPDX expressions, approve a licence policy, or publish an
SBOM.

```bash
.venv/bin/python tools/extract_locked_license_metadata.py \
  --lock requirements-production-ocr-linux-x86_64.lock \
  --output /secure/release-evidence/coverwise-license-metadata.json
```

## `requirements-production-ocr-linux-x86_64.lock`

The Docker release image installs this generated, hash-locked Linux x86_64
profile, including the CPU Torch wheels. Regenerate it only after reviewing a
source dependency change:

```bash
uv pip compile requirements-production-ocr.txt \
  --generate-hashes \
  --python-platform x86_64-manylinux_2_17 \
  --torch-backend cpu \
  --output-file requirements-production-ocr-linux-x86_64.lock
```

CI recompiles and compares the lock. It is intentionally not a macOS or ARM
lock; the production OCR image is Linux x86_64 by contract.

## `deploy_cloud_run.sh`

Deploys the canonical single Cloud Run service from the repository Dockerfile.
It refuses to accept application secrets from an env file: OpenAI, Supabase
service-role, and anonymous-auth signing values must already exist in Google
Secret Manager and are referenced by secret name.

The runtime env file must contain only non-secret production configuration,
including `ENVIRONMENT=production`, the four selected Supabase backends,
`SUPABASE_URL`, `ALLOWED_ORIGINS`, `PUBLIC_SITE_URL`, and hostname-only
`ALLOWED_HOSTS`.

```bash
COVERWISE_GCP_PROJECT=your-project \
COVERWISE_CLOUD_RUN_REGION=asia-south1 \
COVERWISE_RUNTIME_ENV_FILE=/secure/coverwise-runtime.env.yaml \
COVERWISE_OPENAI_SECRET=coverwise-openai-api-key \
COVERWISE_SUPABASE_SERVICE_ROLE_SECRET=coverwise-supabase-service-role \
COVERWISE_ANON_AUTH_SIGNING_SECRET=coverwise-anonymous-auth-key \
COVERWISE_REVENUECAT_WEBHOOK_SECRET=coverwise-revenuecat-webhook-auth \
tools/deploy_cloud_run.sh
```

For a planned anonymous-auth key rotation, set
`COVERWISE_ANON_AUTH_PREVIOUS_KEYS_SECRET` to a Secret Manager secret holding a
comma-separated previous-key ring. Do not place prior signing keys in the
runtime env file.

The command permits unauthenticated Cloud Run invocation because native mobile
clients cannot present Google IAM credentials. Policy routes remain protected by
the application bearer boundary; custom domain/CORS configuration and deployed
owner-isolation acceptance checks are still required before release.

## `deploy_outbox_worker.sh`

Deploys the durable-work consumer as a separate internal Cloud Run service.
The worker listens on `PORT` for non-mutating health probes, claims jobs from
the Supabase outbox, and runs with one minimum instance and concurrency one by
default. API request scaling therefore cannot silently remove the durable
consumer. Its preflight validates the worker production profile and rejects
secret-bearing fields in the runtime env file before invoking `gcloud`.

```bash
COVERWISE_GCP_PROJECT=your-project \
COVERWISE_CLOUD_RUN_REGION=asia-south1 \
COVERWISE_RUNTIME_ENV_FILE=/secure/coverwise-runtime.env.yaml \
COVERWISE_OPENAI_SECRET=coverwise-openai-api-key \
COVERWISE_SUPABASE_SERVICE_ROLE_SECRET=coverwise-supabase-service-role \
tools/deploy_outbox_worker.sh
```

## `verify_deployed_launch.py`

Runs the deployed smoke contract: liveness, readiness, full service health,
unauthenticated document rejection, and (optionally) the production CORS
allowlist. The default run is non-mutating. Pass
`--allow-identity-creation` only when explicitly authorizing two temporary
anonymous identities for owner-scoped list/profile checks.
It fails when `/health` reports degraded RAG or document processing, so a
deployment with an invalid provider credential cannot be called launch-ready.
It neither uploads policy data nor prints bearer tokens.

For ASYNC-01 durable-work evidence, require the internal worker listener as
well. `--require-worker` prevents an API-only pass from being treated as worker
health or recovery proof.

```bash
uv run --python .venv/bin/python python tools/verify_deployed_launch.py \
  --base-url https://api.example.com \
  --origin https://www.example.com

# Required for durable-worker/recovery evidence (ASYNC-01):
uv run --python .venv/bin/python python tools/verify_deployed_launch.py \
  --base-url https://api.example.com \
  --worker-url https://coverwise-outbox-worker.internal.example.com \
  --require-worker

# Optional stronger owner-isolation probe (creates two anonymous identities):
uv run --python .venv/bin/python python tools/verify_deployed_launch.py \
  --base-url https://api.example.com \
  --allow-identity-creation
```

## `verify_supabase_schema.py`

Runs a non-mutating service-role schema and Auth settings probe. It reports
safe provider error codes (for example `PGRST205` for a table missing from the
remote schema) without printing credentials or error payloads.

```bash
set -a; source /secure/coverwise.env; set +a
uv run --python .venv/bin/python python tools/verify_supabase_schema.py
```

## `audit_supabase_migration_parity.py`

Runs a read-only Management API audit comparing tables, added columns,
functions and normalized function bodies, indexes, triggers, policies,
explicitly named constraints and CHECK-constraint definitions, and extensions declared by the repository
migrations with the live Supabase
project.
It also compares repository-declared fixed `search_path` hardening for
server functions against live `pg_proc` configuration and explicit extension
schema placement against `pg_extension`.
It also reports whether the remote migration ledger is a complete repository
mirror. It never applies SQL and requires the management-only experimental
token (or `SUPABASE_MANAGEMENT_API_TOKEN`); do not substitute an app secret.

```bash
set -a; source /secure/coverwise.env; set +a
uv run --python .venv/bin/python python tools/audit_supabase_migration_parity.py \
  --output /tmp/coverwise-migration-parity.json
```

The command exits non-zero when a repository-declared table, added column,
function, function body, function search-path hardening, index, trigger, named constraint or definition, policy, or extension is missing or
mismatched. A non-zero
`migration_history_parity_warning` is a release/rollback audit warning even
when all current objects are present.

## `evaluate_local_document_models.py`

Compares direct PDF text extraction with locally hosted Ollama vision/OCR
models on a PDF fixture. It records timing, output size, and exact expected
token checks without persisting the policy text by default.

```bash
uv run --python .venv/bin/python python tools/evaluate_local_document_models.py \
  tests/test_data/sample_insurance.pdf \
  --models deepseek-ocr:latest gemma3:4b qwen2.5vl:7b \
  --expected 'Insurance Policy' \
  --expected '#12345' \
  --output docs/review/evidence/local-model-eval/sample-policy.json
```

Use only synthetic fixtures or explicitly approved documents with
`--include-text`; reports otherwise retain no extracted document text.

## `evaluate_document_capabilities.py`

Runs the versioned deterministic document-intelligence manifest at
`docs/eval/document_intelligence/capability_manifest_v1.json`. It measures the
native PDF path (text, layout blocks, tables/cells, and embedded image
artifacts) and reports OCR, forms, formulas, multilingual, and managed-provider
gates as explicit pending work. It never sends documents to a provider.

```bash
uv run --python .venv/bin/python python tools/evaluate_document_capabilities.py \
  --output /tmp/coverwise-document-capability-report.json \
  --ocr-profile doctr \
  --strict
```

Add `--ocr-profile doctr` to run the local generated-scan OCR gate. That gate
requires the project venv’s local OCR dependencies and remains synthetic Tier 2
evidence until the consented corpus benchmark passes.

On macOS the evaluator configures the same Homebrew native-library paths as the
API entrypoint before importing doctr. This matters because the Python package
can be installed and `uv pip check` can pass while WeasyPrint’s transitive
GLib/Pango loader still cannot discover its native libraries.

Reports contain hashes and metrics, not source text, unless `--include-text` is
explicitly used for an approved synthetic fixture.

## `inspect_document_capabilities.py`

Prints the safe runtime capability registry used by `/health`. It reports the
active native/OCR/layout/table/form/figure profiles, optional package
availability, evidence tier, and explicit benchmark-pending boundaries without
importing heavyweight models or exposing credentials.

```bash
uv run --python .venv/bin/python python tools/inspect_document_capabilities.py
```

## `verification/supabase_retrieval_benchmark.py`

Exercises the local Supabase retrieval contract with synthetic rows: owner and
document filtering, PostgreSQL FTS, pgvector, embedding identity, latency, and
cleanup. It refuses non-local Supabase URLs unless explicitly enabled.

```bash
SERVICE_ROLE_KEY=$(supabase status -o env | awk -F= '/^SERVICE_ROLE_KEY=/{print $2}' | tr -d '"') \
SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_SERVICE_ROLE_KEY="$SERVICE_ROLE_KEY" \
uv run --python .venv/bin/python python tools/verification/supabase_retrieval_benchmark.py
```

## `run_data_retention.py`

Runs the canonical service-role retention pass: purges analytics before the
configured cutoff, fences expired artifacts, and deletes already-fenced object
references. Schedule this command from the deployment environment; it does not
run automatically from API startup.

```bash
uv run --python .venv/bin/python python tools/run_data_retention.py \
  --analytics-retention-days 30 \
  --artifact-limit 100
```

The safe fallback is 30 days, matching the published privacy policy. Any
`ANALYTICS_RETENTION_DAYS` deployment override is a privacy-policy change and
requires product and legal review before release.

## `verify_supabase_schema.py`

Runs a non-mutating remote schema/Auth probe with the server key and
publishable key. It exits `2` when any required table is missing, which makes
remote migration drift visible in CI or a deployment checklist.

```bash
set -a; . ./.env; set +a
uv run --python .venv/bin/python python tools/verify_supabase_schema.py
```

## `verify_local_identity_claim.py`

Runs a local-only, synthetic guest-to-account acceptance check through local
Supabase Auth and the running API. It creates a temporary `example.com`
account, verifies anonymous identity creation, claims the guest workspace, and
checks the account profile before deleting the temporary Auth user. It never
uploads a document or prints tokens, and refuses non-local Supabase **and**
API URLs before issuing any request.

```bash
set -a; . ./.env; set +a
SUPABASE_URL=http://127.0.0.1:54321 \
SUPABASE_PUBLISHABLE_KEY="$(supabase status -o env | awk -F= '/^ANON_KEY=/{print $2}' | tr -d '\"')" \
SUPABASE_SERVICE_ROLE_KEY="$(supabase status -o env | awk -F= '/^SERVICE_ROLE_KEY=/{print $2}' | tr -d '\"')" \
uv run --python .venv/bin/python python tools/verify_local_identity_claim.py --api-url http://127.0.0.1:8005
```

## `check_buyer_readiness_prereqs.sh`

Runs a one-command BR-04/BR-05 unblock check:

- verifies docker daemon connectivity,
- verifies required env vars are set,
- probes Supabase REST and API `/healthz` when endpoints are set.

```bash
./tools/check_buyer_readiness_prereqs.sh
```
