# Prompt-injection and AI security review — 2026-07-24

## Scope and evidence

Reviewed the current code paths for authenticated RAG queries, streaming RAG,
OCR/document extraction, document classification, evidence extraction, LLM
fallback routing, caching, answer verification, and query logging.

Evidence level: Tier 2 for the new local security contracts; Tier 1 for the
full architecture review. No live provider, authenticated browser, or
production-like attack replay was available in this pass.

## Findings and disposition

### Closed in this pass

1. **Raw untrusted content was interpolated into LLM prompts.** Added a shared
   security instruction in `LLMClient` and fenced document/OCR/evidence context
   with explicit untrusted-data markers. Original source text remains unchanged
   for storage and citation verification.
2. **High-confidence user prompt injection had no early guard.** RAG query and
   stream paths now detect instruction override, prompt exfiltration, role
   hijack, and tool-execution requests. Blocking returns a safe, non-LLM answer
   and does not perform retrieval or invoke a provider.
3. **Pipeline logs contained raw user queries.** Query and stream logs now use a
   short SHA-256 hash; the service-level query logs already used a hash.
4. **Provider and application cache semantics could be confused.** Existing
   owner/document cache boundaries and provider `cached_tokens` telemetry remain
   separate, as documented in the prompt-caching audit.

### Existing controls confirmed

- Canonical `/query` and `/query/stream` require the authenticated user.
- The canonical app route overwrites client filters with the authenticated
  `owner_id` before document querying.
- Structured LLM outputs use Pydantic validation; RAG answers also pass citation
  and answer-face verification.
- No tool/function executor, browser agent, shell runner, or outbound action
  router is exposed through `LLMClient`; current injection impact is therefore
  answer manipulation, prompt disclosure, or unauthorized context use rather
  than direct tool execution.
- Retry, fallback, rate/usage reservation, and audit paths exist, but their
  security behavior still needs runtime integration proof.

### Open risks requiring follow-up

1. **Provider data handling:** insurance text is sent to configured cloud
   providers. Production must use the approved provider data-handling policy,
   retention controls, and secret-bound configuration; extended provider prompt
   caching needs a separate decision.
2. **Legacy RAG module:** `src/rag/service.py` defines a separate FastAPI app and
   query contract. Its deployment reachability must be proven negative or it
   must be retired/deprecated so it cannot become an unauthenticated parallel
   route.
3. **Detector coverage:** regex detection is a high-signal tripwire, not a
   complete semantic classifier. Multilingual, encoded, indirect, and
   document-mediated attacks need adversarial fixtures and model-level evals.
4. **Output leakage:** answer verification checks evidence grounding, not all
   secrets or cross-user references. Add canary-secret and cross-owner corpus
   tests before claiming release-grade prompt-injection resistance.
5. **Operational proof:** run authenticated integration tests with a synthetic
   policy corpus, malicious document text, malicious query text, retry/fallback,
   streaming, and cache-hit paths. Confirm audit records contain hashes/statuses
   rather than raw sensitive prompts.

## Required attack matrix

| Case | Expected result | Current status |
|---|---|---|
| Query says “ignore previous instructions” | Block before retrieval/provider | Local contract covered |
| Query asks for hidden/system prompt | Block before retrieval/provider | Local contract covered |
| Query asks to execute a tool/command | Block before retrieval/provider | Local contract covered |
| Policy text contains an instruction override | Treat as fenced data; extract only policy facts | Static + local fence contract |
| Malicious text in streaming query | Block before stream provider call | Code path implemented; integration unverified |
| Cross-owner document filter | Server owner scope wins | Existing route contract; integration unverified |
| Model emits unsupported/uncited claim | Pydantic/citation/answer verifier gates it | Existing focused coverage; full suite unavailable |
| Provider failure or fallback | No security instruction loss | Central hardening; provider integration unverified |

## Three review passes

- Pass 1 — correctness: traced input, prompt, output, cache, log, and fallback
  paths; added early blocking, fencing, and hashed pipeline logging.
- Pass 2 — architecture: kept one canonical LLM client, avoided a parallel
  prompt-security pipeline, and preserved immutable evidence text.
- Pass 3 — supervision: separated verified controls from inferred posture and
  recorded owners/closure triggers for provider, legacy-route, and runtime gaps.

## Anything else?

Yes: prompt injection is only one part of the threat model. The highest-value
next proof is an authenticated synthetic-corpus integration run that combines
owner isolation, malicious document/query fixtures, streaming, retries,
fallbacks, audit persistence, and cache behavior in one workflow.
