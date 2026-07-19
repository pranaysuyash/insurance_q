# ADR-2026-07-19-24: Qdrant vector database data-handling policy — embeddings stored in Qdrant, vectors not text, operator's account bound by Qdrant's policy

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Qdrant vector database that the product uses for embedding storage and similarity search handles user data in the form of vector embeddings (not text). The data-handling policy is explicit:** (1) the operator's account with Qdrant is bound by Qdrant's data-handling policy and terms of service; (2) the embeddings are vectors (high-dimensional numerical representations), not text — a leak of the embeddings is not a leak of the user's data; (3) the embeddings are transmitted over TLS; (4) the embeddings are stored in the operator's region (configurable; default is the operator's primary region); (5) the launch-claim registry entry: "CoverWise stores embeddings in Qdrant; the embeddings are vectors, not text; the operator's Qdrant account is bound by Qdrant's data-handling policy." A CI test scans the Qdrant client code for any code path that sends non-vector data (e.g. raw policy text) to Qdrant. The policy is the engineering answer to the audit's question of how the product uses third-party storage services.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** the Qdrant vector database data-handling policy: operator's Qdrant account is bound by Qdrant's terms; embeddings are vectors not text (a leak is not the same as a leak of policy text); TLS in transit; embeddings stored in the operator's region. The launch-claim registry entry is "CoverWise stores embeddings in Qdrant; the embeddings are vectors, not text; the operator's Qdrant account is bound by Qdrant's data-handling policy." A CI test scans the Qdrant client code for non-TLS endpoints, non-vector payloads, or non-operator-region endpoints. Implementation may begin in dependency order: TLS enforcement → vector-payload-only enforcement → region enforcement → CI test → launch-claim registry entry. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-16](./ADR-2026-07-19-16-value-add-partnerships-framework.md) (the "data-handling policy per third-party integration" pattern), [ADR-2026-07-19-23](./ADR-2026-07-19-23-llm-provider-data-handling-policy.md) (the precedent: explicit policy + CI test + launch-claim registry entry).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Qdrant vector database handles user data in the form of vector embeddings. The data-handling policy: operator's account bound by Qdrant's policy, vectors not text, TLS in transit, embeddings stored in operator's region. The launch-claim registry entry. A CI test. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The Qdrant vector database data-handling policy: operator's Qdrant account is bound by Qdrant's terms; embeddings are vectors not text (a leak is not the same as a leak of policy text); TLS in transit; embeddings stored in the operator's region. The launch-claim registry entry is "CoverWise stores embeddings in Qdrant; the embeddings are vectors, not text; the operator's Qdrant account is bound by Qdrant's data-handling policy." A CI test scans the Qdrant client code for non-TLS endpoints, non-vector payloads, or non-operator-region endpoints. Implementation may begin in dependency order: TLS enforcement → vector-payload-only enforcement → region enforcement → CI test → launch-claim registry entry.


---

## Context

The product uses Qdrant (a vector database) for embedding storage and similarity search. The embeddings are produced by the LLM provider (per ADR-23) from the policy text and the substrate fields. The embeddings are high-dimensional numerical representations (e.g. 1536 dimensions for `text-embedding-3-small` per ADR-03); the embeddings are not human-readable.

The Qdrant data-handling policy is a first-class concern. The audit's question (per the security audit) is how the product uses third-party storage services and what guarantees the product has about the data.

This ADR defines the Qdrant data-handling policy. The policy is the engineering answer to the audit's question.

---

## The policy in detail

### 1. The operator's account is bound by Qdrant's policy

- The operator has a Qdrant Cloud account (or self-hosted Qdrant). The account is bound by Qdrant's terms of service and data-handling policy.
- For Qdrant Cloud, the policy is documented at qdrant.io/legal. The policy covers data retention, data access, data deletion, data residency.
- For self-hosted Qdrant, the operator's hosting provider's data-handling policy applies (e.g. AWS, GCP, Azure).

**Verification:** the operator's Qdrant account is reviewed. The policy is documented in the launch-claim registry entry.

### 2. The embeddings are vectors, not text

- A vector embedding is a high-dimensional numerical representation. A leak of the embeddings is not a leak of the user's data in the same way a leak of the policy text would be.
- However, recent research (e.g. "Information Leakage in Embedding Models") has shown that embeddings can sometimes be inverted to recover the original text, especially for short texts or in specific contexts. The product assumes the embeddings are not perfectly private; the policy is a defense-in-depth, not a guarantee.
- The policy does not pretend the embeddings are perfectly private. The policy is honest about the limitation.

**Verification:** the launch-claim registry entry is honest: "the embeddings are vectors, not text; a leak of the embeddings is not a leak of the user's data in the same way a leak of the policy text would be."

### 3. TLS in transit

- All Qdrant API calls are over HTTPS (TLS 1.2 or higher). The Qdrant client enforces TLS; non-TLS endpoints are rejected.
- For Qdrant Cloud, the API endpoint is HTTPS by default. For self-hosted Qdrant, the operator configures TLS at the hosting provider.

**Verification:** the Qdrant client test asserts that all API calls are over HTTPS. The test fails if a non-TLS endpoint is configured.

### 4. Embeddings stored in the operator's region

- The Qdrant cluster is in the operator's region (e.g. AWS Mumbai for Indian users). The region is configurable; the default is the operator's primary region.
- The launch-claim registry entry names the region. The user can see the region in the settings page.

**Verification:** the Qdrant client test asserts the cluster's region. The test fails if the region is not the operator's primary region.

### 5. The launch-claim registry entry

- "CoverWise stores embeddings in Qdrant; the embeddings are vectors, not text; the operator's Qdrant account is bound by Qdrant's data-handling policy."
- The entry names the region.
- The entry is enforced by a CI test (per the boundary).

### 6. The CI test (the boundary)

- A CI test scans the Qdrant client code for:
  - Non-TLS endpoints — the test fails.
  - Non-vector payloads (e.g. raw policy text) — the test fails.
  - Endpoints that are not the operator's cluster — the test fails.
- The test is a release guard. A regression is caught before the launch.

---

## What ships in the meantime (the "minimum-viable privacy stance" for the Qdrant integration)

1. **TLS in transit** is enforced.
2. **Vectors not text** is enforced via the Qdrant client (the client only accepts vector payloads; raw text payloads are rejected).
3. **Embeddings stored in the operator's region** is enforced.
4. **The launch-claim registry entry** is added.
5. **The CI test** is added.

**What is deferred (when the operator revisits):**
1. The full Qdrant data-handling policy review (the legal review is a separate workstream)
2. The user-facing explanation (a settings page that explains the Qdrant data handling in plain language)
3. The embedding inversion research monitoring (a periodic review of the academic literature on embedding inversion; if a practical inversion attack is published, the policy is updated)

**When the operator revisits:** the three deferred components are the implementation checklist. The effort is S. 0.5-1 week.

---

## Anything else flagged

The "data-handling policy per third-party integration" pattern is now applied to:
- LLM providers (ADR-23, proposed)
- Qdrant vector database (this ADR, proposed)
- Supabase Storage (future ADR-25)
- Value-Add Partnerships (ADR-16, accepted)

Each follows the same shape: explicit data-handling policy, no-share rule (where applicable), launch-claim registry entry, CI test.
