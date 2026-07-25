# Prompt-caching audit and implementation — 2026-07-24

## Finding

### Mobile runtime boundary

CoverWise is a Flutter mobile client backed by the authenticated Python API.
The phone sends questions to `/query` or `/query/stream` and uploads policy
documents to the backend; it does not currently execute a generative LLM.
`mobile/pubspec.yaml` contains ML Kit text recognition for on-device OCR, but
no mobile LLM runtime or prompt/KV-cache implementation. Hive and local file
storage are application/document caches, not prompt caching.

Therefore the phone has no local prompt cache to enable today. Provider prompt
caching and the optional Ollama/MLX adapters described below are backend or
developer/private-server concerns, not capabilities that require or assume a
user's laptop. A true on-device prompt cache would be a separate mobile
feature requiring a native model runtime, model delivery strategy, encrypted
cache lifecycle, eviction limits, and an offline/fallback contract.

That mobile feature is now started behind an explicit flag. The Flutter app
declares `flutter_gemma` with the MediaPipe engine and
`OnDeviceInferenceService` keeps a fenced per-document session in native
memory. The session is the prompt/KV reuse mechanism; policy prompts and
answers are not persisted. It is disabled unless an approved HTTPS `.task`
model URL is supplied, and it does not replace the canonical backend QA path.

Prompt caching was not explicitly configured in CoverWise. The project already
had two application-managed caches:

- `RAGPipeline` stores exact RAG responses in Redis with a version namespace and
  TTL (`src/rag/pipeline.py`). Ingestion increments the namespace version.
- `PolicyExtractionService` reuses persisted per-document summaries in
  Supabase, Redis, or the local development adapter.

The LLM path uses OpenAI Chat Completions plus OpenAI-compatible fallback
providers. The current Chat Completions API manages prompt-prefix caching
automatically for eligible requests and reports `cached_tokens` in usage; it
does not expose the `prompt_cache_key` request field in the canonical endpoint
reference. Therefore this project does not add a misleading provider-specific
key setting or migrate the whole LLM client to a second API surface.

## Local-provider result

The project has optional local-provider adapters, but local prompt caching is
not currently configured or proven:

- **Ollama:** the project uses Ollama's `/v1/chat/completions` compatibility
  endpoint. Ollama's native `/api/chat` endpoint supports `keep_alive`, which
  keeps model weights resident; that is model residency, not an application
  prompt-prefix cache. The compatibility endpoint's documented request fields
  do not include `keep_alive`, so this code does not pretend to configure it.
- **MLX-LM:** `mlx_lm.cache_prompt` supports a saved prompt cache through the
  Python/CLI path. The project instead uses `mlx_lm.server` at
  `http://localhost:8080/v1`; its documented HTTP request contract has no
  prompt-cache-file field. MLX is disabled by default and no local MLX cache
  runtime is installed or verified here.
- **Local embeddings:** Ollama and `sentence-transformers` model-load behavior
  is separate from LLM prompt caching and is not evidence of prompt reuse.

This is an explicit **not configured / not verified** state for local prompt
caching, not a claim that local adapters lack all runtime KV optimizations.

## Implemented

1. `CostTracker` now records `cached_input_tokens` from the provider usage
   object and exposes the total in `LLMClient.get_cost_summary()`.
2. Cache-hit telemetry remains separate from provider prompt-cache telemetry:
   Redis response hits are recorded as `cache_hit` in retrieval traces; provider
   prompt reuse is visible as `cached_input_tokens` in the LLM cost summary and
   an informational log line.
3. Redis RAG response caching now requires `owner_id` or `document_id` in the
   filter scope. Unscoped evaluation/internal queries bypass the response
   cache, preventing private policy answers from entering a shared bucket.
4. The existing stable system-first message layout is retained so OpenAI can
   reuse any eligible common prefix without changing the answer contract or
   fallback providers.

## Boundaries and invalidation

- Do not cache arbitrary LLM responses by semantic similarity. Insurance
  answers can change when policy documents, ownership, or evidence changes.
- Redis response entries are invalidated by the existing query-cache version
  bump on ingestion and expire using `CACHE_TTL_SECONDS`.
- Persisted policy summaries are keyed by `document_id` and are deleted by the
  existing summary deletion path. A document replacement must use a new or
  invalidated summary record before customer-visible use.
- Provider prompt-prefix caching is provider-managed. Do not enable extended
  retention without a separate data-handling decision because provider cache
  retention and zero-data-retention eligibility are distinct controls.
- Local prompt caching remains open until the project chooses one canonical
  local path: a native Ollama client, or a direct MLX-LM Python backend. Adding
  either would be a pipeline decision, not just an environment variable.

## Verification

- Static inspection: `src/llm/client.py`, `src/rag/pipeline.py`,
  `src/services/policy_extraction_service.py`, and `src/config/settings.py`.
- Targeted contract tests added in `tests/test_prompt_caching.py`.
- AST parsing passed for all touched Python modules. The focused contract suite
  passes (`2 passed`). The focused RAG suite was attempted but could not
  collect because the environment lacks the pinned `qdrant_client` dependency;
  the full suite was not run.
- No live OpenAI request was made; provider cached-token behavior remains
  unverified at runtime until a configured, approved integration environment
  is available.

## Three review passes

- Pass 1 — correctness: confirmed cache bypass for unscoped requests, preserved
  existing TTL/version invalidation, and added provider-token accounting.
- Pass 2 — architecture: kept one Chat Completions/fallback path, avoided a
  duplicate Responses client, and separated Redis cache hits from provider
  prompt-cache hits.
- Pass 3 — supervision: checked secret/config boundaries, documented missing
  dependency and runtime proof, and recorded the follow-up trigger for any future
  extended-retention or Responses API decision.
- Additional correction — local providers: rechecked Ollama and MLX against
  their current provider contracts and downgraded local prompt caching from
  “implicitly available” to “not configured / not verified.”
- Additional correction — mobile boundary (superseded 2026-07-25): the Flutter
  dependency and service surfaces now include an opt-in MediaPipe runtime and
  QA-screen offline-assist path. It remains unverified on physical devices
  and is not a replacement for evidence-backed backend QA.

## Anything else?

Yes: `.env.example` had an uncommitted live-looking OpenAI key. It was restored
to the documented placeholder while preserving the unrelated `ALLOWED_HOSTS`
addition. The key should be treated as exposed and revoked/rotated if it was
ever valid.

## Decision

Keep Redis exact-response caching as the application cache, use automatic
provider prefix caching only as an observed optimization, and require an
explicit future ADR before adding extended provider retention or migrating the
canonical LLM client to the Responses API.

References: [OpenAI Chat Completions API](https://developers.openai.com/api/reference/resources/chat),
[OpenAI data controls](https://platform.openai.com/docs/models/default-usage-policies-by-endpoint),
[Ollama OpenAI compatibility](https://docs.ollama.com/api/openai-compatibility),
[Ollama API](https://ollama.readthedocs.io/en/api/),
[MLX-LM server contract](https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md),
[MLX-LM prompt caching](https://github.com/ml-explore/mlx-lm#long-prompts-and-generations).

## Addendum — 2026-07-25 mobile execution

The mobile lane is now connected to the QA screen behind the same explicit
model configuration. When online, a preparation banner can download the
approved `.task` model. When offline, the app can OCR a locally stored policy,
reuse its in-memory per-document session, and render a `Not verified` answer.
It does not consume server question quota, invent citations, or replace the
backend path when connectivity is available.

Verification: `flutter analyze` passed; targeted QA and local-inference tests
passed; the Android debug APK built successfully. A real-device run with an
approved model and representative policy corpus is still required before any
offline-assist customer claim.
