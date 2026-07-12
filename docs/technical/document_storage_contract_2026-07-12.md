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
| production | DynamoDB `DOCUMENT_METADATA_TABLE` | S3 `DOCUMENT_STORAGE_BUCKET`, KMS encrypted | Required |

Production defaults to DynamoDB/S3 and fails closed if the table, bucket, KMS
key, or explicit runtime dependencies are absent. Local storage is deliberately
rejected when `ENVIRONMENT=production`.

## AWS provisioning contract

Deploy [document-storage.yaml](/Users/pranay/Projects/medpiper/insurance_app/infra/aws/document-storage.yaml), then attach its
`DocumentApiInstanceRoleArn` output as the App Runner instance role. Configure:

```text
ENVIRONMENT=production
DOCUMENT_REPOSITORY_BACKEND=dynamodb
DOCUMENT_METADATA_TABLE=<CloudFormation DocumentMetadataTable output>
DOCUMENT_OBJECT_STORE_BACKEND=s3
DOCUMENT_STORAGE_BUCKET=<CloudFormation DocumentStorageBucket output>
DOCUMENT_STORAGE_KMS_KEY_ID=<CloudFormation DocumentStorageKmsKeyId output>
AWS_REGION=ap-south-1
ANONYMOUS_AUTH_SIGNING_KEY=<rotatable secret-manager value>
```

The template creates a private versioned bucket with SSE-KMS and bucket keys,
a pay-per-request DynamoDB table with point-in-time recovery and the required
`owner_id-index`, and a least-privilege App Runner task role. It does not
provision public endpoints or put secrets into source control.

## Workflow and deletion

1. Verify the bearer principal and validate file/password input.
2. Write original bytes to the configured object store.
3. Create owner-scoped metadata. If metadata creation fails, delete the new
   object before returning an error.
4. Queue processing; status/classification updates write through the repository.
5. Deletion removes vectors and summaries first, then the original object, then
   the metadata row. A failure leaves metadata intact for retry/audit context.

## Verification required before launch

- Deploy this template in the actual production account.
- Start the API with only the instance role—no AWS access keys in App Runner.
- Execute two anonymous identities against the deployed API: upload, list,
  status, summary, query, delete, and restart/scale-out.
- Confirm bucket object encryption is KMS, DynamoDB item ownership cannot be
  crossed, and delete removes the object/vector/summary/metadata.
- Capture redacted audit evidence; no policy text, bearer token, or contact PII
  belongs in logs or test artifacts.
