# LLM access options beyond OpenAI — exploration & recommendation

**Date:** 2026-08-12
**Author:** Forge
**Context:** Pranay asked why the CoverWise RAG appears "OpenAI-only" and requested an
exploration of local, browser-based, and other LLM access methods, to be done in
parallel with the Policy Wording Specialist work and documented.

**Headline correction:** the backend is **not** OpenAI-only. The premise that we are
locked to OpenAI is inaccurate. The genuine gap is **browser / on-device inference on
the backend path** — which the mobile app already has via a separate lane.

---

## 1. What the backend already supports (verified, Tier 1)

`src/llm/client.py` (`LLMClient`) is a single provider abstraction built on the
OpenAI SDK and instantiates **four** providers, all through OpenAI-compatible
`AsyncOpenAI(base_url=...)` clients, with a fallback chain in `generate()` /
`generate_stream()`:

| Provider | Class of provider | Config flag / env | Notes |
|---|---|---|---|
| **OpenAI** | Cloud | `OPENAI_API_KEY`, `OPENAI_CHAT_MODEL` | Primary. Supports `json_schema` structured outputs (`JSON_SCHEMA_MODELS`). |
| **Ollama** | **Local** | `ollama_base_url`, `ollama_chat_model` | Local LLM + embeddings (`nomic-embed-text`). |
| **MLX** | **Local (Apple Silicon)** | `mlx_enabled`, `mlx_model` | Local LLM via `/v1` endpoint. |
| **Groq** | Cloud (LPU) | `groq_api_key`, `groq_chat_model` | Near-free dev tier, OpenAI-compatible. |

Behaviour:
- `generate()` builds `models_to_try` = primary OpenAI → Groq → Ollama → MLX and
  tries each until one succeeds.
- `CostTracker` records `input_tokens / output_tokens / cached_input_tokens` and price
  per model.
- `_supports_json_schema()` returns `False` for local models (Ollama / MLX / llama /
  mistral / qwen / phi / gemma) and adapts the response format to plain JSON.

Embeddings are similarly multi-source (`src/rag/pipeline.py`): OpenAI
`text-embedding-3-small` (1536-d) → Ollama `nomic-embed-text` → local
`sentence-transformers` (`all-MiniLM-L6-v2`, 384-d). The Supabase backend fails
closed on embedding-space mismatch (it refuses to mix spaces); the Qdrant backend
auto-version the collection by dimension.

**Conclusion:** "only OpenAI" is wrong for the backend. We already have local
inference and at least one other cloud. The provider layer is provider-agnostic by
construction — the Policy Wording Specialist persona (a prompt + a Pydantic schema)
is entirely independent of which provider serves it.

---

## 2. The real gap: browser / on-device inference on the backend

The backend has **no browser or on-device inference path at all**. Every request is
served by a server-side `LLMClient`. That is the only place "OpenAI-only" thinking
creeps in, and it is the frontier worth closing for an **offline-first / privacy**
posture.

Options for closing it (research, not yet built):

| Option | What it is | Fit for CoverWise | Maturity / risk |
|---|---|---|---|
| **transformers.js** | WebAssembly / ONNX LLMs in the browser | Privacy-first: no server call; but large models, slow on phones | Medium; ships multi-GB wasm or lazy-load |
| **WebLLM / MLCEngine** | LLM running on WebGPU in-browser | Best browser perf (GPU); Chrome/Edge first | Medium; WebGPU support uneven on mobile Safari |
| **MLC LLM** | Compiled LLMs for WebGPU / native / mobile | Shares runtime with WebLLM; good mobile story | Medium; build/quantisation overhead |
| **llama.cpp (WASM / GGML)** | Classic local LLM runtime | Battle-tested; used by many local apps | Medium; manual integration |
| **Ollama on-device** | Already a *server* local provider | Trivially usable if a local Ollama is present | Low (already wired) |
| **HF `sentence-transformers` / ONNX** | Local **embeddings** | Already partially wired (MiniLM) | Low |

Important: the **mobile app already has an on-device lane** — `mobile/lib/services/
on_device_inference_service.dart` uses `flutter_gemma` (Google Gemma) for an
offline reading assistant. So the "on-device" capability exists on mobile; the gap is
specifically a **web/browser** backend path and a unified abstraction that lets the
server persona and the on-device lane share one instruction surface (see the on-device
alignment task).

---

## 3. Other clouds via OpenAI-compatible gateways

Because `LLMClient` is OpenAI-compatible, any provider exposing an OpenAI-style
`/v1` endpoint drops in with near-zero code. Candidates:

- **OpenRouter** — aggregator; one key, many models (incl. Anthropic, Mistral,
  Meta, open-weight). Strong "one integration, swap models" story.
- **Mistral / Mistral La Plateforme** — OpenAI-compatible; good EU data-residency
  angle.
- **Together / Fireworks / Groq** — already Groq; others are same shape.
- **Anthropic (Claude)** — **not** OpenAI-compatible (different API + message
  format + no `json_schema` strict mode). Requires either an adapter (e.g.
  `anthropic` SDK) or a proxy that translates to OpenAI format. Worth it only if we
  want Claude's long-context / reasoning specifically; otherwise skip.

Recommendation: add **OpenRouter** as the single "other cloud" integration (one key,
model-portable) rather than wiring each vendor. Keep OpenAI as primary for quality,
use Groq/Ollama/MLX for cost/offline, and reserve Anthropic for a deliberate,
separate decision.

---

## 4. Privacy implication for the live eval (the reason this matters now)

The deferred live acceptance gate (#16) runs the real persona against a **real policy
corpus** (`policy.pdf`). `policy.pdf` is encrypted (test-fixture password
`pran1005`, also in `tools/benchmark_chunking.py`) and contains **Pranay's real PII**
(name, address, DOB, policy number, contact). Two safe choices:

1. **Redact before embedding** — strip the schedule/PII pages and mask known tokens
   so no PII is ever sent to a cloud embedding/LLM provider. This is what the live
   fixture does.
2. **Use local embeddings + local LLM** — run the whole eval with Ollama/MLX so the
   policy text never leaves the machine. This is the fully privacy-preserving option
   and is now first-class because the backend already supports it.

The fixture defaults to (1) with OpenAI for fidelity, and documents (2) as the
drop-in private alternative (set `OLLAMA_*` env and point the chat/embedding models
at Ollama).

---

## 5. Recommendation (Tier 1 + 3 evidence)

- **Keep** the OpenAI primary; the multi-provider fallback already exists — do not
  rebuild it.
- **Add OpenRouter** as the one "other cloud" integration (model-portable, one key).
- **Do not** add a separate Anthropic client unless there is a concrete reason;
  if needed, isolate it behind the same `LLMClient` interface.
- **Close the browser/on-device backend gap** only if/when offline web is a product
  requirement; the mobile on-device lane already exists and should be aligned with
  the server persona rather than duplicated.
- **For the live eval:** redact PII before embedding, or run fully local — never send
  real policy PII to a cloud provider.

## 6. Open follow-ups

- Browser/on-device backend path (WebLLM / transformers.js) — research only, not yet
  scoped for build.
- OpenRouter integration — small, additive; pick up if Pranay wants cloud-model
  portability.
- Unified "instruction surface" so the server persona and the mobile on-device lane
  cannot drift (see on-device alignment task).
