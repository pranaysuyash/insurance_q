# ADR-2026-07-24-07: Prompt-injection security boundary

## Status

Accepted for the current no-tools RAG/LLM pipeline.

## Decision

1. Treat all user queries, OCR text, retrieved chunks, and extracted document
   text as untrusted data.
2. Enforce the boundary centrally in `LLMClient` by prepending a security
   instruction to every normal, structured, and streaming request.
3. Fence document-derived content before prompt interpolation without rewriting
   the stored source text used for evidence and citations.
4. Block only high-confidence malicious query patterns before retrieval or LLM
   execution. Keep document detection non-destructive so legitimate policy text
   is not silently removed.
5. Keep the current owner-scoped authenticated API as the authorization
   boundary. Do not add tools, shell execution, browsing, or external actions to
   this LLM path without a new threat model and approval.

## Rationale

Central hardening covers all current call sites and fallback providers. Early
blocking reduces attack cost and prevents malicious query text from reaching
retrieval or the provider. Fencing preserves evidence integrity while making
the intended data/instruction distinction explicit to the model.

## Tradeoffs

Regex detection can miss indirect or encoded attacks and can produce occasional
false positives. It is a tripwire, not a proof of semantic safety. Document
content is fenced rather than removed because deletion could hide a genuine
policy clause and break citation completeness.

## Validation and revisit triggers

The local security contracts pass in `tests/test_prompt_injection.py`; broader
RAG/provider integration is not yet proven. Revisit this ADR before adding tool
calls, changing provider/API surfaces, enabling extended provider retention, or
shipping a multilingual/agentic workflow.

## Anything else?

The legacy `src/rag/service.py` app must be confirmed as unreachable or
deprecated before release so it cannot become a parallel security boundary.
