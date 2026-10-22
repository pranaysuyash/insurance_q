# Alternative LLM access methods for the CoverWise RAGPipeline (stream #17)

**Date:** 2026-08-13
**Author:** Forge (research/exploration stream — no code changes)
**Builds on:** `docs/research/llm_provider_options_2026-08-12.md` (backend already multi-provider)
**Evidence tiers used (motto_v5 §0.5):** TIER 1 static inspection (code) · TIER 2 targeted check · TIER 3 integration observed in repo · KNOWN established public fact · INFERRED (flagged). External $/token claims carry **date + source**.

---

## 0. Standing rule
This is a research deliverable only. No repository code was modified. Pricing is current as of the search/fetch date (2026-08-13) and is volatile — re-verify before any procurement decision.

---

## 1. Method

1. Read the production RAG path (`src/rag/pipeline.py`, `src/llm/client.py`) to confirm the *exact* LLM+embedding footprint we must serve. [TIER 1]
2. Enumerate candidate access methods (the six required + the two already wired as context).
3. Score each on four criteria: (a) feasibility for **chat AND embeddings**, (b) cost tier (2026 pricing, web-sourced), (c) latency profile, (d) privacy/regulatory fit for **medical** insurance data under **DPDP India** and **GDPR EU**.
4. Cross-check OpenAI/Anthropic/Azure pricing via web fetch & search on 2026-08-13.
5. Issue one recommendation.

## 2. The footprint we are optimizing (TIER 1 — read from code)

Per query the pipeline issues, in series:
- **3 chat completions** — RAG-Fusion query generation, HyDE hypothetical-doc generation, and the final Answer (structured `RAGAnswer` via `json_schema`). (`pipeline.py` calls `generate_structured`/`generate`; `LLMClient.generate_structured` requires `json_schema` support.)
- **Embeddings** — query embed + one embed per RAG-Fusion/HyDE variant (see `_generate_embeddings_with_fallback`, `pipeline.py:452-562`). Fallback chain: OpenAI `text-embedding-3-small` (1536-d) → Ollama (`nomic-embed-text`) → local `sentence-transformers`.
- `LLMClient` is OpenAI-SDK based and already instantiates **four** providers behind one interface: OpenAI (primary), Ollama (local), MLX (Apple-Silicon local), Groq (cloud LPU). `_select_client`/`_supports_json_schema` route by model name. [TIER 1]

**Consequence:** any candidate must satisfy **BOTH** a chat leg (ideally `json_schema`-capable for the Answer) **AND** an embedding leg. A provider that does only one of the two is a partial fit and must be paired.

## 3. Criteria definitions

| Criterion | What "good" means here |
|---|---|
| Chat+embed feasibility | Serves final Answer (structured) and supplies embeddings for the fusion/HyDE/retrieval leg. |
| Cost | 2026 $/1M tokens; embeddings priced per 1M tokens. |
| Latency | Added per-call overhead vs. today's measured pipeline latency (~39–48 s/query on a larger model, `global_policy_corpus_2026-08-12.md` §7.2–7.3). Mini models cut this sharply. |
| Privacy/regulatory | No/multi-tenant US transfer of medical-context data; EU data residency option; redaction-friendly; adequacy/SCCs posture for GDPR; DPDP India cross-border stance. |

---

## 4. Candidate set & per-candidate assessment

### 4.1 Cheaper OpenAI models — `gpt-4o-mini` / `gpt-4.1-mini`  (the baselined primary)
- **Chat+embed:** Full — `text-embedding-3-small` for embeddings; both mini models support `json_schema` (list in `client.py:JSON_SCHEMA_MODELS` includes `gpt-4.1-nano`; `gpt-4o-mini`/`gpt-4.1-mini` are OpenAI so strict mode works). [TIER 1]
- **Cost (2026-08-13, source: Azure OpenAI pricing page — Global price = OpenAI direct):**
  - `gpt-4o-mini` input **$0.15** / output **$0.60** per 1M. [Azure pricing page, 2026-08-13; corroborated yangmao.ai 2026-06-17]
  - `gpt-4.1-mini` input **$0.40** / output **$1.60** per 1M. [Azure pricing page 2026-08-13; getapipulse.com 2026-08; inworld.ai; cloudprice.net]
  - `text-embedding-3-small` **$0.02** / 1M tokens. [aiapiprices.com 2026-06-27; costgoat.com 2026-08-02; Azure page $0.022 DataZone]
  - Note: `gpt-4.1-mini` is ~2.7× the cost of `gpt-4o-mini` but adds 1M context and stronger reasoning. Both are ~16× cheaper than `gpt-4o` ($2.50/$10). Mixing is attractive: `gpt-4o-mini` for RAG-Fusion+HyDE, `gpt-4.1-mini` for the Answer.
- **Latency:** ~300–800 ms first token for mini class (INFERRED from known OpenAI mini behaviour; not measured here). Cached-input (prompt-cache) gives 50% input discount on repeat system/persona prefixes. [cached-input price confirmed on Azure page 2026-08-13]
- **Privacy/regulatory:** US-processed by default → for EU users needs EU-US Data Privacy Framework / SCCs; for Indian medical data, DPDP permits cross-border with consent+security but localisation pressure exists. **Best mitigated by the Azure EU Data Zone variant (see 4.3).**
- **Verdict:** Strongest default. Zero code change (already the primary). Use `gpt-4o-mini` as the floor; upgrade the Answer call to `gpt-4.1-mini`.

### 4.2 Local / Ollama — `llama3` / `qwen` (and `nomic-embed-text`)
- **Chat+embed:** Full locally. Chat via `ollama_chat_model` (already wired, `client.py`); embeddings via `ollama_embed_client` + `nomic-embed-text` (768-d) wired in `pipeline.py`. [TIER 1] `_supports_json_schema` returns False for llama/qwen → Answer adapted to `json_object` (still works, slightly less strict). [TIER 1]
- **Cost:** $0 per token. Hardware amortisation only (RAM/GPU). [KNOWN]
- **Latency:** CPU-only: seconds/token (INFERRED); Apple-Silicon MLX or CUDA: sub-second (INFERRED). Not measured here.
- **Privacy/regulatory:** **Best** — nothing leaves the machine. Directly satisfies DPDP India and GDPR special-category (Art 9 health) minimization: real policy PII can be embedded/queried fully locally (this is the privacy path the live gate already recommends, `llm_provider_options_2026-08-12.md` §4).
- **Verdict:** Use as the **private/offline + eval** path (already first-class), not as the high-quality production default — open-weight mini models are weaker on the nuanced coverage reasoning the gates showed. Pair with OpenAI/Azure for production quality.

### 4.3 Azure OpenAI — EU Data Zone
- **Chat+embed:** Full (same models + `text-embedding-3-small`, OpenAI-compatible → drops into `LLMClient` via `base_url`). [TIER 1 by compatibility; TIER 3 in prior Azure deploy docs `deployment/azure_*`]
- **Cost (2026-08-13, Azure OpenAI pricing page):** Global = OpenAI direct; **EU Data Zone/Regional = +10% uplift**:
  - `gpt-4o-mini` EU **$0.165** / **$0.66**; `gpt-4.1-mini` EU **$0.44** / **$1.76**; `text-embedding-3-small` EU **$0.022**/1M.
  - Cached-input discount 50% (e.g. `gpt-4o-mini` cached $0.083). Batch API 50% off.
- **Latency:** comparable to OpenAI direct, plus data-residency routing (INFERRED negligible delta).
- **Privacy/regulatory:** **Strongest GDPR posture** — EU data residency (no US transfer), Microsoft DPA, Art 9 safeguards. For DPDP India, an EU/India-region endpoint avoids US-transfer friction. This is the compliance-grade default for medical data.
- **Verdict:** **Recommended production primary for EU/regulated traffic.** Same code as OpenAI; only `base_url`/key change.

### 4.4 OpenRouter (aggregator)
- **Chat+embed:** Chat full (OpenAI-compatible; one key, swap GPT/Claude/qwen/Mistral). **Embeddings partial** — OpenRouter serves non-Anthropic embedding models (e.g. `text-embedding-3-small`) but **cannot** supply embeddings for Claude (Anthropic has none — see 4.5). [KNOWN + TIER 1 compatibility]
- **Cost (2026-08-13):** OpenAI models pass-through near-base: `gpt-4.1-mini` $0.40/$1.60 [openrouter.ai/gpt-4.1-mini; mytokentracker.io 2026]. Claude via OpenRouter: Opus 5 $5/$25, Sonnet 5 $2/$10, Haiku 4.5 $1/$5 [openrouter.ai/anthropic + claude.com/pricing].
- **Latency:** routing overhead on top of underlying provider (INFERRED small).
- **Privacy/regulatory:** depends on routed provider; default US. Not a compliance default; useful for model portability/R&D.
- **Verdict:** Add as the single "other-cloud" integration for portability (one key, many models). Keep embeddings on OpenAI/local. Already conceptually recommended in `llm_provider_options_2026-08-12.md` §3.

### 4.5 Anthropic Claude — **flagged embeddings gap**
- **Chat+embed:** **Chat OK, embeddings MISSING.** Anthropic exposes **no embeddings API** — confirmed on `claude.com/pricing` (2026-08-13): the API page lists input/output tokens, prompt caching, web search, code execution, managed agents — **no embeddings endpoint**. [VERIFIED-WEB 2026-08-13] So Claude can serve at most the 3 chat legs; embeddings must come from OpenAI/local/OpenRouter-non-Anthropic.
- **Extra friction:** Claude API is **not OpenAI-compatible** (different message format, no `json_schema` strict mode — uses tool-use). The repo's `LLMClient` is OpenAI-SDK based; adopting Claude needs an adapter/proxy (e.g. `anthropic` SDK or an OpenAI→Anthropic translation proxy). Structured `RAGAnswer` output would need rework to tool-use. [TIER 1 by design of client.py]
- **Cost (2026-08-13, claude.com/pricing):** Opus 5 $5/$25, Sonnet 5 $2/$10, Haiku 4.5 $1/$5 per 1M. (Page lists "Opus 5 / Sonnet 5 / Haiku 4.5" as current; legacy Opus 4.x at $5/$25.)
- **Latency:** ~300–700 ms first token (INFERRED); tool-use structured output adds overhead.
- **Privacy/regulatory:** Claude on AWS Bedrock / Azure offers EU residency options; direct Anthropic is US. GDPR-special-category needs the Bedrock/Azure EU route.
- **Verdict:** **Do NOT adopt as an embedding-serving provider (it cannot).** Only consider for chat if a specific capability (long context / reasoning) is required, behind an adapter, with OpenAI/local embeddings. Otherwise skip — the embeddings gap is disqualifying for a drop-in replacement.

### 4.6 vLLM self-host (OpenAI-compatible server)
- **Chat+embed:** Full — vLLM serves both chat (`/v1/chat/completions`) and embedding models (e.g. `bge-m3`, `nomic-embed-text`, `mxbai-embed-large`); OpenAI-compatible → drops into `LLMClient` via `base_url`. [KNOWN/TIER 1 compatibility]
- **Cost:** no per-token fee; cost = GPU compute (e.g. an A100/H100 on a cloud GPU or on-prem). INFERRED at ~$1–3/hr for a single mid GPU → effectively free at low volume, scales linearly. No public per-token price (INFERRED).
- **Latency:** high throughput, low p50 (~200–500 ms) at concurrency (INFERRED; not measured here).
- **Privacy/regulatory:** **Strong** — run on EU/on-prem GPU, zero third-party transfer; ideal for GDPR Art 9 + DPDP localization.
- **Verdict:** Best **self-hosted/EU-controlled** option for scale; needs ops (GPU provisioning, serving, autoscaling). Recommended if CoverWise wants EU data sovereignty without Azure lock-in.

### 4.7 Context: Groq (already wired) and OpenAI primary
- Groq: chat-only LPU, near-free, already in `LLMClient`; **no embeddings** → embeddings stay OpenAI/local. [TIER 1]
- OpenAI direct remains the quality/cost baseline; see 4.1.

---

## 5. Cost comparison (2026-08-13, per 1M tokens, USD)

| Provider / model | Chat in | Chat out | Embeddings /1M | Notes |
|---|---|---|---|---|
| OpenAI `gpt-4o-mini` + `t-e-3-small` | 0.15 | 0.60 | 0.02 | baseline; cached input 0.075 |
| OpenAI `gpt-4.1-mini` + `t-e-3-small` | 0.40 | 1.60 | 0.02 | 1M ctx, stronger |
| Azure `gpt-4o-mini` (EU Zone) | 0.165 | 0.66 | 0.022 | +10% for EU residency |
| Azure `gpt-4.1-mini` (EU Zone) | 0.44 | 1.76 | 0.022 | +10% for EU residency |
| OpenRouter `gpt-4.1-mini` | 0.40 | 1.60 | ~0.02* | *non-Anthropic embed only |
| OpenRouter Claude Sonnet 5 | 2.00 | 10.00 | — | **no embeddings** |
| Anthropic Claude (direct) | 2–5 | 10–25 | **NONE** | chat only; not OpenAI-compat |
| Ollama / vLLM (self-host) | 0 | 0 | 0 | hardware/GPU cost only |

*Sources: Azure OpenAI pricing page (2026-08-13) for OpenAI/Azure; claude.com/pricing (2026-08-13) for Claude; openrouter.ai + mytokentracker.io (2026) for OpenRouter; aiapiprices.com (2026-06-27) + costgoat.com (2026-08-02) for embedding unit price.*

## 6. Privacy / regulatory for MEDICAL insurance data

- **GDPR (EU):** health data is **special category (Art 9)** → needs explicit consent + extra safeguards. EU-US transfer requires adequacy (EU-US DPF) or SCCs. **Cleanest:** Azure OpenAI **EU Data Zone** or self-host (vLLM/Ollama) in EU — no US transfer. Anthropic direct = US (use Bedrock/Azure EU if ever adopted).
- **DPDP India (2023):** cross-border transfer permitted except to blacklisted countries, with consent + reasonable security; no special-category carve-out like old rules, but health is high-risk. Indian medical data → prefer **local (Ollama) or EU/India-region** processing; redact PII before any cloud embed (per `global_policy_corpus_2026-08-12.md` §4).
- **Universal control:** the pipeline already supports redaction-before-embed and full-local mode — apply for any real policy PII regardless of provider.

## 7. Recommendation

1. **Production primary (EU/regulated): Azure OpenAI EU Data Zone** — `gpt-4o-mini` for RAG-Fusion+HyDE, `gpt-4.1-mini` for the Answer; `text-embedding-3-small` for embeddings. Zero code change (OpenAI-compatible). Best GDPR Art 9 + DPDP posture. [confidence: HIGH on feasibility (Tier 1/3), MEDIUM on "best" regulatory call — legal sign-off advised]
2. **Cost floor / US traffic:** OpenAI direct `gpt-4o-mini` + `t-e-3-small`. [HIGH]
3. **Private & eval:** keep **Ollama local** (llama3/qwen + nomic-embed-text) for the live gate and any real-PII processing. [HIGH]
4. **Self-host EU option:** **vLLM** on EU GPU when data-sovereignty-at-scale is wanted without Azure. [MEDIUM — ops cost unmeasured]
5. **Model portability:** add **OpenRouter** as the one aggregator key. [MEDIUM]
6. **Anthropic Claude: do NOT adopt as embedding provider (no embeddings API).** Only for chat behind an adapter if a capability gap demands it; pair with OpenAI/local embeddings. [HIGH on the gap fact — VERIFIED-WEB 2026-08-13]

## 8. Confidence summary

| Claim | Tier | Confidence |
|---|---|---|
| Pipeline = 3 chat + embeddings; multi-provider already wired | TIER 1 (code) | High |
| OpenAI/Azure 4.x + embedding prices | Web 2026-08-13 | High (Azure page authoritative) |
| Claude has no embeddings API | Web 2026-08-13 | High (claude.com/pricing) |
| Claude pricing (Opus5/Sonnet5/Haiku4.5) | Web 2026-08-13 | High |
| Latency figures for mini models | INFERRED | Low–Medium (not measured) |
| vLLM GPU cost | INFERRED | Low (no quote obtained) |
| DPDP/GDPR interpretation | KNOWN + legal inference | Medium (not formal legal advice) |

## 9. Anything else?

- **Structured-output gap for non-OpenAI chat:** the final Answer uses `json_schema`. Ollama/MLX/Groq/Claude fall back to `json_object` or tool-use — verify the Answer parser still passes the live gates (the prior gates already run on this fallback, so low risk). 
- **Embedding-space lock-in:** Supabase backend refuses to mix embedding spaces (`pipeline.py` comment). Switching embed provider (OpenAI↔Ollama↔vLLM) means a re-ingest of `corpus_global` — budget that into any provider change.
- **`uk/travel_ipid` / `uk/travel_v2` are DISTINCT datasets, not duplicates** (verified by MD5/content 2026-08-13 — different AXA product / different insurer+IPID). No cleanup required. [CORRECTED 2026-08-13]
- **Re-verify pricing** before procurement — 2026 rates move fast (the OpenAI China mirror had already moved to gpt-5.5 and dropped 4.x from its headline table).
