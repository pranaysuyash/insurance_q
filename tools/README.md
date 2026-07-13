# Reusable project tools

## `validate_production_config.py`

Checks the canonical Cloud Run + Supabase launch configuration without exposing
secret values. Run it locally or in CI before a deployment:

```bash
ENVIRONMENT=production venv/bin/python tools/validate_production_config.py \
  --env-file /secure/path/coverwise-production.env
```

It requires the production persistence/vector backends, private Supabase
credentials, a strong anonymous-auth signing key, explicit HTTPS public/CORS
origins, and non-debug logging.

## `build_mobile_release.sh`

Builds the Android App Bundle only after explicit public release configuration
is supplied; it runs mobile analysis and tests first. It does not accept server
secrets.

```bash
COVERWISE_API_BASE_URL=https://api.example.com \
COVERWISE_PRIVACY_POLICY_URL=https://www.example.com/privacy \
COVERWISE_TERMS_OF_SERVICE_URL=https://www.example.com/terms \
COVERWISE_SUPPORT_EMAIL=support@example.com \
tools/build_mobile_release.sh
```

## `deploy_cloud_run.sh`

Deploys the canonical single Cloud Run service from the repository Dockerfile.
It refuses to accept application secrets from an env file: OpenAI, Supabase
service-role, and anonymous-auth signing values must already exist in Google
Secret Manager and are referenced by secret name.

The runtime env file must contain only non-secret production configuration,
including `ENVIRONMENT=production`, the three selected Supabase backends,
`SUPABASE_URL`, `ALLOWED_ORIGINS`, and `PUBLIC_SITE_URL`.

```bash
COVERWISE_GCP_PROJECT=your-project \
COVERWISE_CLOUD_RUN_REGION=asia-south1 \
COVERWISE_RUNTIME_ENV_FILE=/secure/coverwise-runtime.env.yaml \
COVERWISE_OPENAI_SECRET=coverwise-openai-api-key \
COVERWISE_SUPABASE_SERVICE_ROLE_SECRET=coverwise-supabase-service-role \
COVERWISE_ANON_AUTH_SIGNING_SECRET=coverwise-anonymous-auth-key \
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

## `verify_deployed_launch.py`

Runs the non-mutating deployed smoke contract: liveness/readiness, unauthenticated
document rejection, two independent anonymous identities, owner-scoped lists,
and (optionally) the production CORS allowlist. It neither uploads policy data
nor prints bearer tokens.

```bash
venv/bin/python tools/verify_deployed_launch.py \
  --base-url https://api.example.com \
  --origin https://www.example.com
```

## `evaluate_local_document_models.py`

Compares direct PDF text extraction with locally hosted Ollama vision/OCR
models on a PDF fixture. It records timing, output size, and exact expected
token checks without persisting the policy text by default.

```bash
venv/bin/python tools/evaluate_local_document_models.py \
  tests/test_data/sample_insurance.pdf \
  --models deepseek-ocr:latest gemma3:4b qwen2.5vl:7b \
  --expected 'Insurance Policy' \
  --expected '#12345' \
  --output docs/review/evidence/local-model-eval/sample-policy.json
```

Use only synthetic fixtures or explicitly approved documents with
`--include-text`; reports otherwise retain no extracted document text.
