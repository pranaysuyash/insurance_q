# Reusable project tools

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
is supplied; it runs mobile analysis and tests first. It does not accept server
secrets.

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
mobile build.

## `deploy_cloud_run.sh`

Deploys the canonical single Cloud Run service from the repository Dockerfile.
It refuses to accept application secrets from an env file: OpenAI, Supabase
service-role, and anonymous-auth signing values must already exist in Google
Secret Manager and are referenced by secret name.

The runtime env file must contain only non-secret production configuration,
including `ENVIRONMENT=production`, the four selected Supabase backends,
`SUPABASE_URL`, `ALLOWED_ORIGINS`, and `PUBLIC_SITE_URL`.

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

```bash
uv run --python .venv/bin/python python tools/verify_deployed_launch.py \
  --base-url https://api.example.com \
  --origin https://www.example.com

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
  --analytics-retention-days 365 \
  --artifact-limit 100
```

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
uploads a document or prints tokens.

```bash
set -a; . ./.env; set +a
SUPABASE_URL=http://127.0.0.1:54321 \
SUPABASE_PUBLISHABLE_KEY="$(supabase status -o env | awk -F= '/^ANON_KEY=/{print $2}' | tr -d '\"')" \
SUPABASE_SECRET_KEY="$(supabase status -o env | awk -F= '/^SERVICE_ROLE_KEY=/{print $2}' | tr -d '\"')" \
uv run --python .venv/bin/python python tools/verify_local_identity_claim.py --api-url http://127.0.0.1:8005
```
