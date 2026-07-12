# LLM Provider Evaluation — 2026-07-12

## Context

CoverWise's LLM answer generation was blocked by OpenAI quota exhaustion
(429). The fallback chain was configured to `llama3.2` → `phi3:mini`, but
`phi3:mini` is **not installed** in the local Ollama, so every fallback failed.
The local machine (M3 Max, 96GB RAM) has 15+ models available that were never
used. This document records the full evaluation of alternatives and the
decision.

## Machine

- Apple M3 Max, 14 cores (10P + 4E), 96GB unified memory
- Ollama running with: gemma3:12b, gemma3:4b, qwen2.5:7b, qwen2.5:3b, mistral:7b,
  llama3.2:3b, aya-expanse:8b, qwen2.5vl:7b, deepseek-ocr, nomic-embed-text,
  plus several cloud aliases

## Problem statement

1. OpenAI out of quota → 429 on all chat completions
2. Ollama fallback targets `llama3.2` + `phi3:mini` — `phi3:mini` not installed
3. Embeddings work via Ollama `nomic-embed-text` fallback
4. Retrieval/reranking works (local models)
5. Only LLM generation fails — and only because the fallback was misconfigured

## Options evaluated

### Hosted (cloud) providers

| Provider | Cost | Quality | Latency | Free tier? | OpenAI-compat? |
|---|---|---|---|---|---|
| OpenAI gpt-5-nano | $0.05/$0.40 per M | Best, strict json_schema | 300-800ms | No | Native |
| Groq (Llama-3.3-70B) | ~$0.69/$0.89 per M | Strong | **Fastest** (LPU, <300ms TTFT) | Yes (RPM-limited) | Yes (/v1/chat/completions) |
| Together AI (Qwen2.5) | ~$0.18-0.88 per M | Strong (best JSON discipline) | 500ms-2s | $1-5 credit | Yes |
| Fireworks AI | ~$0.20-0.90 per M | **json_schema support** (rare) | Sub-second | Credit | Yes |
| Google Gemini free | Free | Good (long context) | Fast (Flash) | 15 RPM/1500 RPD | No (different API) |
| Cerebras | ~$0.25-1.00 per M | Good | Very fast | Free tier | Yes |
| Cloudflare Workers AI | 10k neurons/day free | OK | Edge (fast globally) | Yes | Partial |
| HF Inference API | Free (limited) | OK for chat, best for OCR | Poor (cold starts) | Yes | No |

### Local (on-device) providers

| Provider | Cost | Quality | Latency | Privacy |
|---|---|---|---|---|
| Ollama gemma3:12b | Free | Strong for Q&A | 14-24s load, then reasonable | Best (on-device) |
| Ollama qwen2.5:7b | Free | Strong (best JSON locally) | Similar | Best |
| Ollama gemma3:4b | Free | Good | 14s load, fastest locally | Best |
| MLX | Free | Same models, faster tokens/s than Ollama | Better than Ollama | Best |

### Local model diagnostics (from existing evidence)

| Model | Task | Time | Correct? |
|---|---|---|---|
| deepseek-ocr | OCR | 65s | **FAILED** (empty output) |
| gemma3:4b | OCR | 27s | ✅ Correct |
| gemma3:12b | OCR | 40s | ✅ Correct |
| qwen2.5vl:7b | OCR | 77s | ✅ Correct (slow) |

## Decision

### Generation: 3-tier fallback chain

**Tier 1: OpenAI `gpt-5-nano`** (primary, when quota is funded)
- Strict json_schema for structured extraction
- Best quality
- Cheapest OpenAI model ($0.05/$0.40)

**Tier 2: Groq `llama-3.3-70b-versatile`** (cloud fallback, near-free)
- OpenAI-compatible API (drop-in base_url)
- Fastest cloud latency (LPU acceleration)
- Free developer tier covers solo usage
- Supports json_object (not strict json_schema, but good enough with prompt)

**Tier 3: Ollama `gemma3:12b`** (local fallback, free, private)
- Already installed and verified
- Strong for insurance Q&A with retrieved context
- Works offline, fully private
- Replace dead `phi3:mini` reference

### Embeddings: keep current
- Primary: OpenAI `text-embedding-3-small` (1536d)
- Fallback: Ollama `nomic-embed-text` (768d) — already works

### OCR: gemma3:4b for local dev, HF Inference for production
- `deepseek-ocr` is broken — remove from any fallback chain
- `gemma3:4b` is the fastest working local OCR model
- Production: HF Inference API (100-500x cheaper than LLM OCR per arch doc)

## Code changes

1. `src/config/settings.py`: Add `groq_api_key`, `groq_base_url`, `groq_chat_model`.
   Replace `ollama_alt_model: str = "phi3:mini"` with `"gemma3:4b"`.
2. `src/llm/client.py`: Add Groq client branch (OpenAI-compatible, just different
   base_url). Insert Groq model between OpenAI and Ollama in fallback chain.
   Add Groq pricing to `MODEL_PRICING`.
3. `.env`: Add `GROQ_API_KEY`. Uncomment `HF_TOKEN`.

## What needs verification (web search quota reset 2026-08-06)
- Groq free-tier rate limits and paid pricing
- Together/Fireworks/Cerebras per-token rates
- Gemini free-tier RPD caps and training-data terms
- Confirm gpt-5-nano pricing matches OpenAI's live rate
