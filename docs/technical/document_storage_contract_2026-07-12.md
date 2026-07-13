# CoverWise document storage contract — 2026-07-12

## Decision

`/documents` is the only policy-document resource. Its metadata is persisted
through `src/services/document_repository.py`, and original bytes are persisted
through `src/services/document_object_store.py`. The API does not use
process-global lists as a customer-data source of truth.

## Environments

| Environment | Metadata | Original bytes | Allowed |
| --- | --- | --- | --- |
| local/test | SQLite at `DOCUMENT_METADATA_DB_PATH` | local `DOCUMENT_STORAGE_DIR` | Yes, restart-safe locally |
| production | Supabase Postgres `documents` table | private Supabase Storage bucket | Required |

Production defaults to Supabase and fails closed if its URL, server-only role
key, or Storage bucket are absent. Local storage is deliberately rejected when
`ENVIRONMENT=production`. DynamoDB/S3 adapters remain portable fallbacks, but
are not the launch architecture.

## Canonical production contract

Apply [the canonical Supabase schema](/Users/pranay/Projects/medpiper/insurance_app/infra/supabase/001_coverwise_schema.sql) and the
[processing-lease upgrade](/Users/pranay/Projects/medpiper/insurance_app/infra/supabase/002_document_processing_leases.sql) before deploying the single
Cloud Run application service. Configure:

```text
ENVIRONMENT=production
DOCUMENT_REPOSITORY_BACKEND=supabase
DOCUMENT_OBJECT_STORE_BACKEND=supabase
RAG_VECTOR_BACKEND=supabase
SUPABASE_URL=<project URL>
SUPABASE_SERVICE_ROLE_KEY=<server-only secret>
SUPABASE_DOCUMENTS_TABLE=documents
SUPABASE_STORAGE_BUCKET=coverwise-documents
ANONYMOUS_AUTH_SIGNING_KEY=<rotatable secret-manager value>
ANONYMOUS_AUTH_PREVIOUS_SIGNING_KEYS=<optional comma-separated prior values>
```

The schema creates owner-scoped document metadata, `pgvector` chunks, an HNSW
index, and a private Storage bucket. The service-role key is server-only; it
must never ship in the Flutter app or public website. See the authoritative
[long-term platform decision](/Users/pranay/Projects/medpiper/insurance_app/docs/planning/coverwise_long_term_platform_decision_2026-07-12.md) for rationale,
rollback, and migration acceptance criteria.

Rotate anonymous-auth keys by making the new Secret Manager value active and
placing the immediately previous value in `ANONYMOUS_AUTH_PREVIOUS_SIGNING_KEYS`
for no longer than the 30-day token lifetime. The application tries at most the
active plus two prior keys; remove the old value early only when forced logout
is the required compromise response.

## Superseded AWS reference

[document-storage.yaml](/Users/pranay/Projects/medpiper/insurance_app/infra/aws/document-storage.yaml) is preserved as an exploratory,
noncanonical AWS/App Runner alternative. It must not be provisioned for this
launch unless the platform decision is formally revisited; keeping both active
would create duplicate data and deployment truth sources.

## Workflow and deletion

1. Verify the bearer principal and validate file/password input.
2. Resolve the owner-scoped source hash. An identical replay returns the
   existing logical document and never creates duplicate storage or vectors.
3. Write original bytes to the configured object store.
4. Create owner-scoped metadata. If metadata creation fails, delete the new
   object before returning an error.
5. Claim a 15-minute processing lease; a restart can recover only `received`
   or expired-lease documents from canonical storage.
6. Deletion removes vectors and summaries first, then the original object, then
   the metadata row. A failure leaves metadata intact for retry/audit context.

## Ingestion safety contract

The canonical customer API accepts only PDF, PNG, JPG, TIFF, and WebP source
documents. It validates the extension against the file signature, parses the
source before hashing or persistence, limits source bytes to 50 MB, limits PDFs
to 100 pages, and rejects decompression-bomb-sized images above 40 megapixels.
Password-protected PDFs are rejected before hashing or storage for launch. The
app does not collect a password it cannot safely retain across a restart. A
future encrypted-PDF feature requires a separately reviewed envelope-encrypted,
short-lived credential design with KMS/Secret Manager, deletion, rotation,
audit events, and recovery tests.

Office formats are deliberately not accepted at launch. They were previously
advertised despite lacking a canonical, bounded extraction path, which could
have stored binary data that the processing service then treated as text. A
future Office-format decision must add a sandboxed parser, format-specific
limits, malware scanning posture, and extraction benchmarks before widening
this contract.

## Verification required before launch

- Apply the Supabase migration and create the private Storage bucket in the
  selected production project.
- Deploy the one Cloud Run service with secrets injected by Secret Manager; no
  service-role key may appear in client builds or source control.
- Execute two anonymous identities against the deployed API: upload, list,
  status, summary, query, delete, and restart/scale-out.
- Confirm owner-scoped Postgres rows/pgvector retrieval cannot be crossed and
  delete removes Storage object/vector/summary/metadata.
- Capture redacted audit evidence; no policy text, bearer token, or contact PII
  belongs in logs or test artifacts.

## Mobile release contract

Build the store binary only after the live deployment and legal pages exist:

```bash
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=PRIVACY_POLICY_URL=https://www.example.com/privacy \
  --dart-define=TERMS_OF_SERVICE_URL=https://www.example.com/terms \
  --dart-define=SUPPORT_EMAIL=support@example.com
```

These values are public release configuration, not server secrets. The app
rejects a production release missing HTTPS endpoints or a valid support email.
