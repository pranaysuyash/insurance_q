# Launch claim: Qdrant vector database data handling

**Source ADR:** [ADR-2026-07-19-24](../decisions/ADR-2026-07-19-24-qdrant-vector-database-data-handling-policy.md)

## Approved wording

CoverWise stores embeddings (high-dimensional numerical vectors, not text) in
Qdrant for similarity search. The embeddings are transmitted over TLS and
stored in the operator's region. A leak of the embeddings is not a leak of the
user's policy text.

## Explicit limitations

- The embeddings are vectors, not text. A leak of the embeddings does not
  expose the user's policy text, personal information, or document contents.
- The operator's Qdrant account is bound by Qdrant's data-handling policy and
  terms of service.
- No non-vector data (raw policy text, PII, metadata) is sent to Qdrant.
- The default region is the operator's primary region. The region is
  configurable but default is the operator's choice.

## Implementation owners

- Qdrant client: `src/services/vector_store_service.py`
- TLS enforcement: Client configuration
- Vector-payload-only enforcement: CI test scanning Qdrant client code
- Region enforcement: Client configuration

## Verification gates

| Requirement | Current evidence | Required before launch claim |
|-------------|-----------------|------------------------------|
| TLS in transit | Tier 2: configured | Verified connection test |
| Vector-only payloads | Tier 0: not enforced | CI test scanning for non-vector payloads |
| Region enforcement | Tier 0: not enforced | CI test scanning for non-operator-region endpoints |
| Operator policy review | Tier 0: not reviewed | Qdrant account reviewed |

## Revisit trigger

Revisit if the Qdrant client changes, if a new embedding provider is added, or
if the region configuration changes.
