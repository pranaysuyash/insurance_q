# ADR-2026-07-24-06: Prompt-caching boundary

## Status

Accepted for the current Chat Completions pipeline.

## Context

CoverWise sends private insurance-document context through `LLMClient`, while
the RAG pipeline also has a Redis exact-response cache. Prompt caching,
response caching, and persisted extraction summaries have different privacy and
invalidation semantics. The current canonical provider surface is OpenAI Chat
Completions with local/OpenAI-compatible fallbacks.

The product runtime is a Flutter mobile client plus authenticated backend. The
mobile client calls `/query` and `/query/stream`; it also has on-device OCR,
encrypted/local application storage, and now an opt-in MediaPipe local LLM
seam. Ollama/MLX prompt-cache behavior remains a server/developer concern and
must not be described as phone capability.

## Decision

- Keep Redis exact-response caching as the application-managed response cache.
- Require `owner_id` or `document_id` scope before storing or loading a RAG
  response from Redis.
- Keep prompt construction stable enough for provider-managed automatic prefix
  caching, but do not add `prompt_cache_key` to the Chat Completions client or
  create a parallel Responses API client.
- Capture provider-reported `cached_tokens` in the existing LLM cost summary;
  do not report provider prompt-cache hits as Redis response-cache hits.
- Do not use semantic response reuse for insurance answers.
- Do not claim local prompt caching is active: Ollama is reached through its
  compatibility endpoint and MLX through `mlx_lm.server`, neither of which is
  wired here to a project-controlled prompt-cache file or control.
- The mobile on-device lane is implemented behind
  `ON_DEVICE_INFERENCE_ENABLED` plus an approved HTTPS `.task` model URL.
  `OnDeviceInferenceService` reuses per-document native sessions for prompt/KV
  reuse, keeps policy context in memory only, fences untrusted text, and never
  replaces canonical backend QA automatically.

## Rationale and tradeoffs

This preserves one canonical LLM path and all existing fallback behavior while
making caching observable and tenant-safe. It leaves extended provider cache
retention and explicit cache-key controls for a future provider/API decision;
that future change would require a data-handling review and integration proof.

## Validation and revisit triggers

The targeted contracts are in `tests/test_prompt_caching.py`. Static AST
validation passed. Full pytest and a live provider request remain blocked until
the local disk-pressure issue is resolved and an approved OpenAI integration
environment is available. Revisit this ADR if the project migrates its
canonical LLM client to the Responses API, adopts a managed cache service,
chooses a native Ollama/direct MLX backend, or needs a documented retention
guarantee.

## Anything else?

The application cache already has TTL and ingestion-version invalidation; the
policy-summary cache remains document-keyed and follows its existing delete
path. These paths must stay separate from provider prompt-cache accounting.
