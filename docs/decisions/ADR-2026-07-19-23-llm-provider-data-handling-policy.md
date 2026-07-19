# ADR-2026-07-19-23: LLM provider data-handling policy — no training on user data, TLS in transit, no retention beyond the request-response cycle

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The LLM providers (OpenAI, Anthropic, etc.) that the product uses for extraction, summary, and Q&A handle user data (policies, substrate fields, user questions). The data-handling policy is explicit:** (1) the operator's API agreement with each LLM provider includes a contractual clause that the provider does not train on the user's data and does not retain the data beyond the request-response cycle (per the provider's zero-retention policy, where applicable); (2) the data is transmitted over TLS; (3) the consent ledger (per ADR-2026-07-19-07) records the user's opt-in/opt-out for the `model_improvement` purpose (the user can opt out of having their data used for model improvement, where the provider offers that opt-in/opt-out); (4) the launch-claim registry entry: "CoverWise does not allow LLM providers to train on user data; data is transmitted over TLS and is not retained beyond the request-response cycle." A CI test scans the LLM client code for any code path that sends user data to a non-zero-retention endpoint. The policy is the engineering answer to the audit's P0-7 ("the LLM client silently returns empty or unexpected results for unsupported params") and the broader question of how the product uses third-party AI services.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** the LLM provider data-handling policy: operator's API agreement with each LLM provider includes a contractual clause that the provider does not train on the user's data; for providers that offer a zero-retention API, the zero-retention API is the default; data is transmitted over TLS; consent ledger (per ADR-07) records the user's opt-in/opt-out for the `model_improvement` purpose; the launch-claim registry entry is "CoverWise does not allow LLM providers to train on user data; data is transmitted over TLS and is not retained beyond the request-response cycle." A CI test scans the LLM client code for any code path that sends user data to a non-zero-retention endpoint, bypasses the consent ledger, or uses a non-TLS endpoint. Implementation may begin in dependency order: TLS enforcement (already in place) → `data_retention=zero` flag → consent purpose in ledger → CI test → launch-claim registry entry. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-07](./ADR-2026-07-19-07-security-phase-2-server-side-consent-ledger.md) (the consent ledger that the `model_improvement` purpose is added to), [ADR-2026-07-19-16](./ADR-2026-07-19-16-value-add-partnerships-framework.md) (the "data-handling policy per third-party integration" pattern), [canonical architecture doc](../../architecture/coverwise_canonical_architecture.md).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The LLM providers handle user data. The data-handling policy is explicit: no training, TLS in transit, no retention beyond request-response cycle, consent ledger `model_improvement` purpose. The launch-claim registry entry is the policy. A CI test is the boundary. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The LLM provider data-handling policy: operator's API agreement with each LLM provider includes a contractual clause that the provider does not train on the user's data; for providers that offer a zero-retention API, the zero-retention API is the default; data is transmitted over TLS; consent ledger (per ADR-07) records the user's opt-in/opt-out for the `model_improvement` purpose; the launch-claim registry entry is "CoverWise does not allow LLM providers to train on user data; data is transmitted over TLS and is not retained beyond the request-response cycle." A CI test scans the LLM client code for any code path that sends user data to a non-zero-retention endpoint, bypasses the consent ledger, or uses a non-TLS endpoint. Implementation may begin in dependency order: TLS enforcement (already in place) → `data_retention=zero` flag → consent purpose in ledger → CI test → launch-claim registry entry.


---

## Context

The product uses LLM providers (OpenAI, Anthropic, etc.) for:
- **Extraction** (the parser pipeline's LLM extractors per ADR-14, ADR-17, ADR-18, ADR-19)
- **Summary** (the policy summary, the claim summary, etc.)
- **Q&A** (the verified Q&A tool per ADR-08 #2, the Coverage Check-in observations, the Family Coverage Map observations)

The LLM providers receive user data: the policy text, the substrate fields, the user's questions, the user's life events (when synced), the user's scenario picks (when synced). The data is sensitive:
- Policy text: insurance contract details, sum insured, exclusions, family members
- Substrate fields: extracted values with evidence_strength, citations, parser_version
- User questions: the user's intent, the user's life situation
- Life events: new baby, new diagnosis, etc. (per ADR-21)
- Scenario picks: C-section, knee replacement, etc. (per ADR-22)

The LLM provider's data-handling policy is a first-class concern. The audit's P0-7 (per the document intelligence trust audit) is about the LLM client's compatibility with newer models (gpt-5+, o1+, o3+); the broader question is how the product uses third-party AI services and what guarantees the product has about the data.

This ADR defines the LLM provider's data-handling policy. The policy is the engineering answer to the audit's broader question.

---

## The policy in detail

### 1. No training on user data (contractual)

- The operator's API agreement with each LLM provider includes a contractual clause that the provider does not train on the user's data. The clause is in the operator's master services agreement (MSA) with the provider.
- For providers that offer a zero-retention API (e.g. OpenAI's API with `data_retention=zero` for enterprise customers, Anthropic's API with zero retention for all customers), the product uses the zero-retention API. The zero-retention API is the default; the non-zero-retention API is not used.
- For providers that do not offer a zero-retention API, the product does not use the provider. The provider is excluded from the LLM client.

**Verification:** the operator's MSA is reviewed by legal counsel. The MSA is a public document (or a redacted version is published on the marketing site). The launch-claim registry entry links to the MSA.

### 2. TLS in transit

- All LLM API calls are over HTTPS (TLS 1.2 or higher). The LLM client (per `src/llm/client.py`) enforces TLS; non-TLS endpoints are rejected.
- The TLS certificate is verified against the system certificate store. Self-signed certificates are rejected (in production; in development, the operator can configure a custom CA).

**Verification:** the LLM client test asserts that all API calls are over HTTPS. The test fails if a non-TLS endpoint is configured.

### 3. No retention beyond the request-response cycle

- The LLM provider's response is returned to the product. The product stores the response in the substrate (per the parser pipeline's record). The product does not store the response on the LLM provider's servers beyond the request-response cycle.
- For providers that offer a zero-retention API, the zero-retention API is the default. The provider's retention policy is documented in the launch-claim registry entry.
- For providers that retain data beyond the request-response cycle, the product uses the data for the response only and then discards the data on the product's side. The provider's retention is a contractual concern; the product's retention is in the substrate.

**Verification:** the LLM client test asserts that the response is stored in the substrate, not in the LLM provider's servers (the LLM provider's servers are out of the product's control; the test asserts the product's side, not the provider's side).

### 4. Consent for `model_improvement`

- The consent ledger (per ADR-07) records the user's opt-in/opt-out for the `model_improvement` purpose. The purpose means: "the user allows the LLM provider to use the user's data for model improvement (training, fine-tuning, etc.)."
- The default is opt-out (the user is not opted in by default). The opt-in is explicit: the user must grant consent in the settings page.
- For providers that offer a "do not train" flag in the API (e.g. OpenAI's `data_retention=zero`), the product sets the flag regardless of the user's opt-in. The provider does not train on the data.
- For providers that do not offer a "do not train" flag, the product does not use the provider unless the user has explicitly opted in.

**Verification:** the LLM client test asserts that the `model_improvement` opt-in/opt-out is respected. The test fails if the user's opt-out is bypassed.

### 5. The launch-claim registry entry

- "CoverWise does not allow LLM providers to train on user data; data is transmitted over TLS and is not retained beyond the request-response cycle."
- The entry links to the operator's MSA with each LLM provider.
- The entry is enforced by a CI test (per the boundary).

### 6. The CI test (the boundary)

- A CI test scans the LLM client code (`src/llm/`) for:
  - Non-TLS endpoints (HTTP instead of HTTPS) — the test fails.
  - Endpoints that are not on the allow-list (the operator's MSA-covered providers) — the test fails.
  - Code paths that bypass the consent ledger's `model_improvement` opt-in/opt-out — the test fails.
- The test is a release guard. A regression is caught before the launch.

---

## What ships in the meantime (the "minimum-viable privacy stance" for the LLM provider integration)

1. **TLS in transit** is enforced (the LLM client already uses HTTPS; the test is new).
2. **No training on user data** is enforced via the `data_retention=zero` flag (where available) and the MSA (where not).
3. **Consent for `model_improvement`** is recorded in the consent ledger (per ADR-07). The default is opt-out.
4. **The launch-claim registry entry** is added.
5. **The CI test** is added.

**What is deferred (when the operator revisits):**
1. The full MSA review (the legal review is a separate workstream; the engineering ADR is the foundation)
2. The marketing site disclosure (the MSA is published or redacted)
3. The user-facing explanation (a settings page that explains the LLM provider's data handling in plain language)

**When the operator revisits:** the three deferred components are the implementation checklist. The effort is S. 0.5-1 week.

---

## Anything else flagged

The "data-handling policy per third-party integration" pattern (per ADR-16) is now applied to:
- LLM providers (this ADR)
- Qdrant vector database (future ADR-24)
- Supabase Storage (future ADR-25)
- Value-Add Partnerships (ADR-16, accepted)

Each follows the same shape: explicit data-handling policy, no-share rule (where applicable), launch-claim registry entry, CI test. The pattern is the engineering answer to the user's right to know who sees their data.
