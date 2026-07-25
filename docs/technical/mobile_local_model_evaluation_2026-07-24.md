# CoverWise mobile local-model options and evaluation status

**Date:** 2026-07-24  
**Scope:** Flutter mobile app, Android and iOS, with preference for models released or materially updated from 2025 onward.  
**Evidence rule:** “Evaluated” means this repository contains a reproducible mobile or target-runtime run. Desktop Ollama, MLX, server OCR, Hugging Face API, or Modal runs do not count as mobile evaluation.

## Scope correction

The decision target is the **mobile user’s execution environment**, not the
developer workstation. Android/iOS users should not install Ollama. Ollama,
MLX, llama-server, and Modal are relevant only as server/private-GPU benchmark
or hosted-fallback infrastructure. They are not mobile product options unless a
separate hosted service is intentionally exposed to the phone.

## Executive answer

There is now an **opt-in mobile local LLM implementation seam**, but there is **no Android/iOS device evaluation yet**. The shipped default remains backend QA. The mobile package uses `flutter_gemma` plus its MediaPipe engine when explicitly enabled with an approved HTTPS `.task` model URL. No model is bundled or downloaded by default.

What exists is adjacent evidence:

- **Desktop/local:** Ollama and opt-in MLX are wired in the Python LLM client; Gemma 3 4B/12B, Qwen2.5-VL 7B, and a DeepSeek-OCR adapter were tested on a synthetic one-page policy fixture. This is not mobile proof.
- **Local document processing:** PyMuPDF is the fast canonical digital-PDF path. Surya 2 has a targeted Apple-Silicon run; Docling, PP-OCRv6, Qwen3-VL, and other parsers remain corpus-benchmark candidates.
- **Mobile:** Google ML Kit provides traditional offline OCR, and the repo now
  contains an opt-in `flutter_gemma`/MediaPipe generative seam. No physical
  device or insurance-corpus benchmark has passed yet.
- **Cloud:** Hugging Face Inference Providers/HF Pro and Modal are hosted execution paths. They are not local/offline inference and must not be described as privacy-preserving on-device execution.

## Current repo status

Cross-project credential/evaluation ledger: see the consolidated decision sheet:

- [mobile_model_decision_sheet_2026-07-24.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_decision_sheet_2026-07-24.md)
- [mobile_model_execution_ledger_2026-07-24.md](/Users/pranay/Projects/medpiper/insurance_app/docs/review/mobile_model_execution_ledger_2026-07-24.md)

| Surface | Current state | Evidence tier | What this proves | What it does not prove |
|---|---|---:|---|---|
| Flutter mobile dependencies | `flutter_gemma` + `flutter_gemma_mediapipe` declared; feature disabled by default | 1 | A mobile runtime seam is present | Device compatibility, model quality, battery, and latency |
| Mobile assistant/query UI | Existing service path remains app/API-oriented; QA now exposes explicit model preparation and offline assist | 1–2 | Local inference can be prepared and invoked without changing canonical backend QA | Production offline policy Q&A or quality evidence |
| Ollama | Integrated in Python LLM client | 1–2 | Server/desktop fallback path exists | Android/iOS runtime, battery, binary size, or device latency |
| MLX | Opt-in Python server path | 1–2 | Apple-Silicon desktop local inference is supported | iOS app execution |
| Gemma 3 4B/12B | Tested through Ollama on a synthetic page | 2 | Desktop multimodal candidate timings and token checks | Mobile quality or performance |
| Qwen2.5-VL 7B | Tested through Ollama; ~77s on the local machine fixture | 2 | Too slow for the tested desktop default path | Mobile performance on a different model/runtime |
| Surya 2 | Targeted Apple-Silicon run on synthetic policy | 2 | Local scan-parser candidate recovered expected tokens | Mobile deployment or insurance-field accuracy |
| Android Gemini Nano | Not integrated or tested | 1 | Platform-native candidate exists | Device coverage and CoverWise output quality |
| iOS Foundation Models | Not integrated or tested | 1 | Apple platform-native candidate exists on supported Apple Intelligence devices | Availability, prompt stability across OS model revisions, or insurance extraction quality |

The existing detailed desktop evidence is in [`local_document_intelligence_evaluation_2026-07-12.md`](local_document_intelligence_evaluation_2026-07-12.md) and [`llm_provider_evaluation_2026-07-12.md`](llm_provider_evaluation_2026-07-12.md). Neither is a mobile evaluation.

## Implemented mobile foundation

`mobile/lib/services/on_device_inference_service.dart` now provides the
bounded local lane:

- MediaPipe `.task` runtime through `flutter_gemma`.
- Explicit build flags: `ON_DEVICE_INFERENCE_ENABLED=true` and an approved
  `ON_DEVICE_MODEL_URL=https://...`.
- Per-document in-memory sessions. The fixed, fenced policy context is loaded
  once and subsequent questions reuse the native session/KV context.
- Context limits and session eviction; no prompt, policy text, or answer is
  persisted to Hive or files by this service.
- System instructions fence document/user text and prohibit prompt disclosure,
  unsupported coverage decisions, and hidden-data access.
- No automatic replacement of canonical backend QA. A product UI may expose
  this later only as an explicitly labelled offline assist after device and
  corpus evidence passes.

The runtime integration is statically verified by `flutter analyze`, the
focused service contract test, and dependency resolution. Android/iOS device
execution, model download integrity, battery/latency, and insurance-corpus
quality remain open Tier 3+ gates.

### 2026-07-25 integration update

The QA screen now exposes model preparation only when the build supplies the
feature flag and HTTPS model URL. Offline queries use the existing local PDF
file plus ML Kit OCR, then route through `OnDeviceInferenceService`. Answers
are stored in the existing local QA history as `offline_assist` with
`verificationStatus: unverified`; they do not consume server quota or claim
citations.

## Where the model is selected

There is intentionally no in-app model picker. The model is selected when the
mobile binary is built, using the URL of the approved public `.task` artifact:

```bash
cd /Users/pranay/Projects/medpiper/insurance_app/mobile
flutter run \
  --dart-define=ON_DEVICE_INFERENCE_ENABLED=true \
  --dart-define=ON_DEVICE_MODEL_URL="https://<approved-host>/<compatible-model>.task"
```

For a store build, set these environment variables before running
`tools/build_mobile_release.sh`:

```bash
export COVERWISE_ON_DEVICE_INFERENCE_ENABLED=true
export COVERWISE_ON_DEVICE_MODEL_URL="https://<approved-host>/<compatible-model>.task"
/Users/pranay/Projects/medpiper/insurance_app/tools/build_mobile_release.sh
```

If the variables are omitted, the release remains backend-only and the offline
assistant is not shown. Once enabled, the user taps **Prepare** in the QA
screen; that downloads the selected model to the phone. The URL chooses the
weights, while the runtime remains the hard-coded `Gemma IT` + MediaPipe
`.task` path in `OnDeviceInferenceService`.

The current compatible candidate is the
`litert-community/Gemma3-1B-IT` repository, which lists
`Gemma3-1B-IT_multi-prefill-seq_f32_ekv1280.task`. Its files are gated behind
Gemma-license acceptance, so its raw Hugging Face URL is **not yet a usable
mobile release URL** for this app: the app has no Hugging Face token flow.
Before enabling a release, publish or otherwise serve an approved artifact
from a distribution location that permits anonymous HTTPS download, then set
that final URL in `COVERWISE_ON_DEVICE_MODEL_URL`. No Hugging Face token
belongs in the mobile binary. Device download, checksum/provenance, licence
review, and insurance-corpus quality are still release gates.

## Cross-project credential and execution inventory

This is a **key-name inventory only**. Secret values were not printed, copied,
or moved. A credential existing in another project does not authorize routing
CoverWise customer data through that provider; it only identifies a provider
that can be evaluated after an explicit data-handling decision.

| Provider / capability | Key names detected in actual project env files | Representative project surfaces | CoverWise relevance |
|---|---|---|---|
| OpenAI direct | `OPENAI_API_KEY`, `NEXT_PUBLIC_OPENAI_API_KEY` | CoverWise, LLM projects, invoice-intelligence, SentinelTwin | Already the canonical hosted generation/embedding path in CoverWise; keep server-side only. |
| OpenRouter | `OPENROUTER_API_KEY` | OrbitCover D2C, influencer-feature app | Useful paid aggregator for model comparison and controlled model/provider fallbacks; key is not currently wired into CoverWise. |
| Hugging Face / HF Pro | `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`, `HUGGINGFACE_HUB_TOKEN`, `HUGGINGFACE_TOKEN`, `HUGGINGFACE_API_KEY`, `ECHOPANEL_HF_TOKEN` | Comfy, speech model-lab, EchoPanel, learning_for_kids, Adshot, Shopstack, Edureka | HF Pro is an account/credit tier; these tokens enable Hub downloads and/or hosted inference depending on token scope. It does not make mobile inference local. |
| Modal Labs | `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` | Comfy | Private GPU benchmark/hosted endpoint lane. Not Android/iOS local execution. |
| Google/Gemini | `GEMINI_API_KEY`, `VITE_GEMINI_API_KEY`, `EXPO_PUBLIC_GEMINI_API_KEY`, `GOOGLE_API_KEY` | Edureka, learning_for_kids, SceneGuide, media_exp, SentinelTwin | Paid/cloud Gemini evaluation lane; separate from Android Gemini Nano/AICore, which is device-managed and does not use this API key. |
| Groq | `GROQ_API_KEY` | Edureka | Fast hosted fallback candidate; not currently wired into CoverWise despite historical evaluation recommendation. |
| Anthropic | `ANTHROPIC_API_KEY` | Bas5minute, Notes | Paid comparison candidate through direct API or OpenRouter; not currently wired into CoverWise. |
| Together | `TOGETHER_API_KEY` | SentinelTwin | Hosted open-model comparison candidate; not currently wired into CoverWise. |
| Local runtimes | `OLLAMA_*`, `MLX_*` configuration exists in CoverWise code/config; no current API key required | CoverWise local code, Comfy/model lanes | Private local fallback path, but current live `ollama list` returned no installed models. |

### Credential boundary

The most relevant usable-looking configuration surfaces for this evaluation are:

1. CoverWise `.env`: OpenAI key name present.
2. OrbitCover `.env`: OpenRouter key name present.
3. Comfy `.env`: Hugging Face and Modal credential names present.
4. `speech_experiments/model-lab/.env`: Hugging Face credential names present.
5. Edureka / learning-for-kids / bas5minute / SentinelTwin / Notes: additional provider credentials that are useful for comparative research, but should not be silently reused for CoverWise production traffic.

No secret value or account balance was printed or retained. Synthetic-only API
smokes were subsequently run against OpenAI, OpenRouter, HF Inference
Providers, and Modal; their results appear below. No CoverWise policy content
was transmitted.

## Paid and local fallback shortlist

This shortlist is selected by task fit, not by generic benchmark rank.

| Priority | Fallback | Execution | Select for | Why selected | Known evidence / gap |
|---:|---|---|---|---|---|
| 1 | OpenAI `gpt-5-nano` or current approved structured-output model | Direct server API | Canonical structured extraction and grounded Q&A | Existing CoverWise contract, schema validation, observability, and citation pipeline already align with it | Historical CoverWise provider evaluation; current quota/billing state not tested in this pass |
| 2 | OpenRouter controlled route: OpenAI / Claude Sonnet / Gemini Flash / Qwen3-class model | Hosted aggregator | Comparative paid evaluation and provider/model failover | OrbitCover key is present; OpenRouter supports model fallback, provider ordering, throughput/latency/price routing, and structured-output constraints | Key-name presence only; no API request or balance check performed |
| 3 | Groq Llama 3.3 70B or current approved fast model | Direct hosted API | Low-latency text fallback | Existing repository evaluation rated Groq as fastest hosted fallback and OpenAI-compatible | Key exists in Edureka, not CoverWise; no current CoverWise integration or live call |
| 4 | Gemma 3n E2B/E4B via MediaPipe/LiteRT | Android/iOS local | Shared custom on-device model | Designed for mobile with conditional modality loading and effective-parameter operation | Candidate only; no Flutter bridge or device run |
| 5 | Android Gemini Nano via AICore | Android managed local | Short offline summaries/classification | OS-managed model distribution, hardware acceleration, privacy, and no app-bundled weights | Candidate only; device availability and CoverWise prompts untested |
| 6 | Apple Foundation Models | iOS managed local | Text extraction, structured output, tool calling | Native on-device model and guided generation on Apple Intelligence devices | Candidate only; OS-version model drift and unsupported-device fallback untested |
| 7 | Ollama Gemma 3 4B / Qwen 2.5 7B | Server/desktop benchmark, not phone | Private server fallback and comparison baseline | Existing synthetic-policy results; useful only to compare against mobile candidates | Historical evidence only; must not be presented as a mobile installation requirement |
| 8 | Modal-hosted Gemma/Qwen/Ministral/other open weights | Private hosted GPU | Corpus-scale model comparison or OCR/VLM benchmark | HF/Modal credentials exist in the Comfy lane; avoids mobile-device constraints for heavy models | No CoverWise Modal endpoint or benchmark run in this pass; cloud data-residency decision required |

### OpenRouter fallback policy

When the OrbitCover OpenRouter credential is approved for this work, use it as
a benchmark router rather than a hidden production dependency:

- primary: a structured-output model with the best field/citation result;
- fallback 1: a fast, lower-cost model for retryable provider failures;
- fallback 2: a local or server-private model only when the input is eligible;
- require provider/model metadata, token usage, latency, and fallback attempt
  telemetry in every benchmark result;
- use `require_parameters=true` for structured output and restrict providers
  when policy-data residency requires it;
- never send the encrypted-policy plaintext to OpenRouter, HF, Modal, or other
  hosted providers without explicit consent and a recorded data-handling rule.

OpenRouter documents automatic model fallbacks, provider ordering, and routing
by price, latency, or throughput; those features are useful for evaluation but
do not remove the need for our own evidence and schema gates.

## Explicitly excluded from the mobile product decision

- Asking Android/iOS users to install Ollama, MLX, llama-server, or a desktop
  inference daemon.
- Treating a Mac benchmark as Android/iOS performance evidence.
- Shipping a large server model inside the mobile binary merely because a
  quantized artifact exists on Hugging Face.
- Calling HF Pro, OpenRouter, OpenAI, or Modal “local” or “offline.”

The historical Ollama/MLX reports remain useful for server-side comparison and
must not be deleted, but they are not evidence for the mobile shortlist.

## Authoritative evaluated-vs-not matrix for this decision pass

Use this when asking “what did we run, and what is still open?”

| Stage | Candidate / lane | Where it was run | Evaluation status | Why |
|---|---|---|---|---|
| Parse baseline | PyMuPDF, docTR | server/local fixture path | ✅ proven (`52Q` policy path uses this stage as canonical input) | Canonical baseline; on-device replacement not yet run |
| OCR/layout | Surya-2 | desktop/Apple-Silicon synthetic check | ✅ partial | Not representative of on-device performance for app release |
| OCR/layout frontier | Docling, MinerU, Marker, PaddleOCR-PP, RT-DocLayout, Unlimited-OCR, Qwen3-VL, etc. | catalog review only | ❌ not executed in repo | Selected as frontier candidates, not yet benchmarked |
| Chunking/reconstruction | paragraph/entity/enhanced chunking | server corpus experiments | ✅ implemented and measured in policy corpus | Still needs mobile-only tuning to prove win |
| Embedding | `text-embedding-3-small` | hosted run + policy corpus | ✅ baseline | Hosted path only |
| Embedding local candidates | EmbeddingGemma 308M, Qwen3-Embedding 0.6B/4B/8B | planned only | ❌ not executed on-device | Export + runtime work pending |
| Hosted generation | OpenAI `gpt-5-nano` | synthetic + held-out policy corpus | ✅ best local anchor for backend | Not mobile/offline |
| Hosted generation | OpenRouter `gemini-2.5-flash-lite`, `google/gemma-3-4b-it` | synthetic checks only | ✅ comparison only | Not mobile/offline |
| Hosted generation | HF Qwen3-4B (`HF Inference Provider`) | synthetic check | ✅ comparison only | Not mobile/offline |
| Desktop local generation | Ollama `gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`, DeepSeek OCR | desktop synthetic checks | ✅ infra + compatibility only | Not mobile |
| Mobile runtime candidate lane | `flutter_gemma` MediaPipe seam + `.task` flag | service present, no device run | ⚠️ scaffold only | Feature exists, but no mobile runtime evidence yet |
| Managed Android/iOS | Gemini Nano / Apple Foundation Models | no in-app integration | ❌ not evaluated in CoverWise | Must run supported + unsupported device matrix |
| Cross-platform on-device generation | Gemma 3n E2B/E4B, Gemma 3 270M/1B, Qwen3 1.7B/4B, Phi-4-mini, SmolLM3 3B, Ministral 3 3B | not executed on mobile | ❌ open | These are the explicit first-pass mobile shortlist once local-capability gate opens |
| Visual-fallback lane | Qwen3-VL / PaddleOCR-VL / Vision stack candidates | none in-coverwise | ❌ open | Use after OCR+text path and only for visual-failure stages |
| Web/bridge experiments | Transformers.js | no Flutter-native mobile path | ❌ not relevant to native mobile baseline | WebView/WebGPU route only |
| Hosted infra lanes | HF Pro, OpenRouter, OpenAI, Modal | reachable + smoke in repo evidence | ✅ routed as comparison/fallback only | Never count these as mobile-offline in this model ledger |

For a single source-of-truth map that includes stage gates and explicit
run-order, use the updated [exploration map](../review/mobile_model_exploration_map_2026-07-24.md).

If you want the raw 2025–2026 inventory used for this selection pass:

- [`mobile_model_catalog_2025_2026_2026-07-24.md`](../review/mobile_model_catalog_2025_2026_2026-07-24.md)
- [`mobile_model_general_vlm_frontier_2026-07-24.md`](../review/mobile_model_general_vlm_frontier_2026-07-24.md)

## Runtime and execution options

| Option | Android | iOS | Local/offline | 2025–26 relevance | Current status for CoverWise | Assessment |
|---|---|---|---|---|---|---|
| **Google Gemini Nano via AICore / ML Kit GenAI** | Yes, only compatible Android devices | No equivalent cross-platform path | Yes when the model is available on-device | Current Android platform path; Gemini Nano 4 preview is documented in 2026 | Not integrated or evaluated | Best Android-first managed path for short summaries, classification, and constrained text/image prompts. Device availability and model version are platform-controlled. |
| **Apple Foundation Models** | No | Yes, supported Apple Intelligence devices with the required OS | Yes | Introduced with Apple platform releases from 2025 onward; model changes with OS updates | Not integrated or evaluated | Best iOS-native path for text extraction, summarization, structured output, and tool calling. Requires graceful unsupported-device fallback and prompt regression tests per OS model version. |
| **Google AI Edge / MediaPipe LLM Inference** | Yes | Yes | Yes | Current cross-platform native runtime; documented for Gemma mobile deployment | Not integrated or evaluated | Strongest first custom-runtime candidate if we want one model family on both platforms. Requires native Android/iOS bridge from Flutter and compatible converted model assets. |
| **LiteRT / TensorFlow Lite** | Yes | Yes | Yes | Current edge deployment stack | Not integrated or evaluated | Good for encoder/OCR/classification and supported generative model exports. Treat as a runtime, not a model choice. |
| **ExecuTorch** | Yes | Yes | Yes | Current PyTorch edge runtime with Java/Swift bindings and LLM export path | Not integrated or evaluated | Strong candidate for newer Hugging Face/PyTorch models where export support is proven. Export compatibility must be tested per model. |
| **ONNX Runtime Mobile** | Yes | Yes | Yes | Mature cross-platform mobile runtime | Not integrated or evaluated | Practical for small encoders, embeddings, OCR, and exported text models. Use NNAPI/XNNPACK on Android and CoreML/XNNPACK on iOS after CPU baseline. |
| **MLC LLM** | Yes | Yes | Yes | Active Android/iOS Swift/Java runtime and model compilation path | Not integrated or evaluated | Good candidate for GGUF/MLC-compiled chat models and direct performance control. Adds model compilation and native packaging complexity. |
| **llama.cpp** | Yes | Yes | Yes | Active ecosystem, broad GGUF model availability | Not integrated or evaluated | Viable lowest-level fallback through a maintained native plugin/FFI layer. Requires careful licensing, threading, memory, cancellation, and background execution work. |
| **Transformers.js** | Via WebView/PWA/browser surface | Via WebView/PWA/browser surface | Yes with cached ONNX assets | Current WebGPU/WASM JavaScript runtime | Not integrated or evaluated | Useful for a separate web/mobile-web experiment, not a direct Flutter-native runtime. WebGPU support is uneven, model downloads are large, and long-context generation is a poor fit for sensitive policy PDFs without a native bridge. |
| **Hugging Face Hub / HF Pro / Inference Providers** | App can call hosted API | App can call hosted API | No | Current hosted model discovery and provider routing | Existing HF use is for weights/API-related local workflows, not mobile local execution | Cloud execution. HF Pro supplies account/storage/inference credits; it does not make inference local. Never send policy text from the device without explicit data-handling approval. |
| **Modal Labs** | App can call hosted endpoint | App can call hosted endpoint | No | Current serverless GPU inference platform | Not integrated or evaluated for mobile | Cloud/private-GPU execution for benchmarks or a hosted API. It is not an on-device runtime and does not satisfy offline mode. |

**Interpretation of “Model Labs”:** this document assumes the question means **Modal Labs**. If a different vendor was intended, add it as a separate execution surface rather than combining it with mobile runtimes.

## Newer model shortlist

These are candidates, not evaluated decisions. Model availability in a runtime is separate from model quality and separate again from CoverWise insurance-field accuracy.

| Model family / candidate | Release window | Useful size / modality | Android + iOS route | Status | Why it is worth testing |
|---|---|---|---|---|---|
| **Gemma 3n E2B / E4B** | 2025 | Effective 2B/4B-class operation; text, image, audio; 32K context | MediaPipe/LiteRT; possibly ExecuTorch/MLC depending on export | Candidate only | Explicitly designed for phones/tablets with parameter skipping, PLE caching, and conditional modality loading. Best newer multimodal candidate for one shared custom runtime. |
| **Gemma 3 270M / 1B** | 2025 | Text-only small models | LiteRT/MediaPipe/ExecuTorch/ONNX where export exists | Candidate only | Strong size baseline for deterministic classification, routing, and short structured tasks. Not a replacement for document OCR. |
| **Qwen3 0.6B / 1.7B / 4B** | 2025 | Text; compact reasoning/instruction variants | ExecuTorch, MLC, llama.cpp/GGUF, possibly ONNX | Candidate only | Good multilingual and structured-output comparison across quantization levels. Start at 1.7B and 4B; 0.6B is a latency/quality floor. |
| **Phi-4-mini-instruct** | Feb 2025 | 3.8B text, 128K context | ExecuTorch, ONNX, MLC/llama.cpp if export/quantization is validated | Desktop/local candidate only | MIT-licensed compact reasoning model. Existing repo has no mobile run; the desktop `phi3:mini` configuration must not be treated as Phi-4 evidence. |
| **SmolLM3 3B** | 2025 | 3B text; ONNX and quantized community artifacts exist | ONNX Runtime Mobile, ExecuTorch, MLC/llama.cpp | Candidate only | Useful small-model benchmark with an ONNX-oriented route and low memory target. |
| **Ministral 3 3B** | Dec 2025 | 3B-class vision-capable edge model; Apache-2.0 model card | MLC/llama.cpp/ExecuTorch/ONNX only after export validation | Candidate only | Newer edge-focused multimodal family; 3B is the only size worth initial mobile testing. |
| **Qwen3-VL 2B/4B** | 2025 | Vision-language | Runtime-specific export required; likely heavier than text-only route | Candidate only | Relevant for page/image review after OCR, but should not be the first mobile policy parser. |
| **Llama 4 Scout/Maverick** | 2025 | Multimodal, very large | Not a practical first mobile target | Not planned for mobile benchmark | Newer does not mean mobile-suitable; memory, binary size, and thermal cost make it a server/private-GPU candidate. |

The first model benchmark should be **Gemma 3n E2B/E4B, Gemma 3 1B, Qwen3 1.7B/4B, Phi-4-mini, SmolLM3 3B, and Ministral 3 3B**. Keep Qwen3-VL 2B/4B as a second-stage visual-review lane, not the default document parser.

## What has and has not been evaluated

### Evaluated in this repository, but not on mobile

- PyMuPDF digital PDF extraction: targeted local evidence, canonical primary path.
- Ollama Gemma 3 4B and 12B: targeted synthetic-policy VLM checks and timings.
- Ollama Qwen2.5-VL 7B: targeted synthetic-policy check; too slow in the recorded desktop run.
- DeepSeek-OCR through a generic Ollama adapter: empty output; correctly classified as an adapter incompatibility, not a model-quality result.
- Surya 2 through a local Apple-Silicon/Metal path: targeted synthetic-policy token recovery.
- Desktop MLX/Ollama routing and structured-output fallback behavior: code/tests, not mobile runtime behavior.

### Immediate decision snapshot (what to prioritize next)

- **Decision now:** prioritize **one** mobile-capable path first — **Gemma 3n E2B** via the existing `flutter_gemma` seam, then measure actual Android/iOS outcomes.
- **Do not promote yet:** Gemini Nano, Apple Foundation Models, Qwen3 1.7B/4B, Phi-4-mini, SmolLM3, Ministral as first-lane products until baseline local evidence and fallback telemetry are complete.
- **Do not list as mobile offline:** Ollama, MLX, HF Inference Providers, OpenRouter, OpenAI, Modal.
- **Research-only until benchmarking:** Docling/MinerU/Marker/RT-DocLayout/Unlimited-OCR/Dolphin/AgenticOCR/Logics-Parsing/PaddleOCR family, Qwen3-VL visual candidates, ExecuTorch/ONNX/MLC/llama.cpp runtime stacks.
- **Evidence gate before any production exposure:** per-device warm/cold latency, RSS, thermal behavior, citation reliability, schema-valid output rates, cancellation/eviction telemetry, and unsupported-device fallback.

## Execution-ticket-ready matrix (technical view)

The current technical objective is **one actionable mobile-lane proof pack**, not a model catalog rewrite.

| Ticket | Scope | What to build/run | Evidence file required | Success threshold |
|---|---|---|---|---|
| T1 | Runtime contract hardening | Implement/verify a single `MobileModelCapability` contract (runtime, asset hash, tokenizer, task, source mode, constraints, failure reason, cancellation) | `docs/review/mobile_model_exploration_map_2026-07-24.md` + model-lineage entries | Contract exists and is logged before any model attempt |
| T2 | Gemma 3n E2B baseline | Android/iOS test run using `flutter_gemma` + downloadable `.task` bundle | Benchmark manifest v1 + telemetry snapshot | Baseline passes minimum field and citation checks on policy subset |
| T3 | Device capability probes | Android Nano/AICore + iOS Foundation Models availability and behavior | Device matrix notes | Explicit capability map with supported/unsupported behavior and refusal consistency |
| T4 | Local-RAG stress check | EmbeddingGemma retrieval + Gemma 3n 2-turn answer path over visual/layout-failing pages | RAG stress manifest | Retrieval + citation stability under constrained memory/time; no uncaught unsafe answers |
| T5 | Comparator holdout | Qwen3 1.7B or other candidate only if T2 passes and evidence budget allows | Comparator manifest + side-by-side diff sheet | Any improvement is statistically attributable and not just hardware variance |

### Runbook prerequisites for all tickets

- Reuse the same manifest fields as the exploration map: device model/tier, corpus version, source IDs, temperature/config, fallback reason, latency/memory/thermal metrics, cancellation counts.
- Store each ticket output in a fixed folder under `docs/review/evidence/mobile-model-proof/<ticket-id>/`.
- Before proceeding to any comparator ticket, require explicit pass at all upstream gates in the corresponding execution ticket matrix and this technical threshold table.

### Stage-wise evidence map (what is actually proven)

| Stage | Candidates / routes looked at | Stage intent | Android/iOS eval status |
|---|---|---|---|
| Parser base | `pymupdf`, `pytesseract`, `pytesseract` + form-aware paths, CIR reconstruction hooks | Deterministic baseline for digital-policy text and metadata | ✅ Stage proven in server-side pipeline; ❌ no mobile device benchmark |
| OCR & layout fallback | Surya 2; `pytesseract`; legacy OCR libraries | Scan + noisy-image recovery | ✅ Surya2 synthetic benchmark; ❌ no mobile-device OCR benchmark |
| Document frontier parsing | Docling / MinerU / Marker / LlamaParse / PaddleOCR-PP Structure (candidates) | Reading order, tables, formulas, KIE | ❌ no dedicated evaluation in CoverWise mobile pipeline |
| Chunking layer | paragraph/entity/entity+adjacent chunking | Keep policy labels + page provenance | ✅ implemented and executed in corpus runs; coverage still stage-limited on scanned layouts |
| Embeddings | `text-embedding-3-small` + fallback local path | Semantic retrieval anchor | ✅ server benchmarked in policy corpus |
| Retrieval | Dense + adaptive/fuzzy + rerank | Candidate selection and citation path | ✅ partially benchmarked; no mobile-specific retrieval stress runs |
| Generation layer (hosted) | OpenAI `gpt-5-nano`, OpenRouter Gemma/Gemini, HF Qwen3-4B | Grounded extraction + fallback | ✅ synthetic + policy corpus stage checks on server |
| Generation layer (local/managed/offline) | Flutter `flutter_gemma`/MediaPipe seam; Gemini Nano; Foundation Models; on-device Gemma prototypes | On-device generation and answer drafting | ⚠️ only contract/integration scaffolding exists; ❌ no device execution evidence |
| Runtime transport | Ollama, MLX, HF Pro, Modal, OpenRouter, OpenAI APIs | Hosted fallback and comparison | ✅ hosted paths reachable; ❌ none are mobile-offline |

### Mobile-first shortlist for 2025–2026 (explicitly separated)

#### 1) Strong 2025–2026 candidates for policy-relevant pipeline stages

- **Gemma 3n E2B / E4B (Gemma mobile family):** first shared cross-platform candidate for constrained text tasks.
- **Gemma 3 270M / 1B:** low-footprint baseline for classification/routing.
- **Qwen3 1.7B / 4B:** multilingual structured extraction baseline for cross-platform comparison.
- **Phi-4-mini-instruct:** compact reasoning baseline for schema adherence.
- **SmolLM3 3B / Ministral 3 3B:** small-to-mid edge generation alternatives.
- **GEM: text-only embedding alternatives** (embeddinggemma / Qwen3-embedding family): candidate after on-device export work.

#### 2) OCR / parsing frontier candidates in your requested catalog (2025–2026) not yet run

- **Baidu / Infinity / ByteDance family:** `Unlimited-OCR` (2026-06), `RT-DocLayout` (2026-06), `P-MTP` (2026-06), `PaddleOCR-VL-1.6` (2026-06), `PP-OCRv6` (2026-06), `Dolphin-2.0`/`Dolphin` (2026-02/2025-05), `Dolphin-1.5`.
- **Specialized document layout/KIE candidates:** `AgenticOCR`, `Logics-Parsing`, `Logics-Parsing-Omni`, `Agentar-Fin-OCR`, `Qianfan-OCR`, `docoCR`-class models (`Dot s`/`FireRed` variants), `MinerU2.5-Pro`, `MinerU-Popo`, `MinerU-Diffusion`.
- **Reason for inclusion:** these are specifically built for table/header/KVP/charts/multi-language OCR patterns that align with CoverWise failure clusters; they are currently cataloged but not executed in CoverWise.
- **Immediate decision:** keep as evaluation candidates; no production promotion until mobile execution and corpus-gated tests show gains over canonical PyMuPDF + rerank path.

#### 3) Not part of first mobile milestone

- `Transformers.js` as primary native Flutter lane (keep as web/mobile-web experiment only).
- `Llama 4 Scout/Maverick`, `Qwen3.6-35B`, and other very large multimodal models (heavy latency/memory for insurance mobile).
- Deeply speculative finetune branches without approved corpus and artifact lineage.

### Cross-project key-name inventory for model routing (relevant only, no values exposed)

- `medpiper/insurance_app`: `OPENAI_API_KEY`, `HF_TOKEN`, `OLLAMA_CHAT_MODEL`, local MLX flags.
- `orbitcover-d2c`: `OPENROUTER_API_KEY` (routing and provider comparison candidate).
- `comfy`: `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` (private GPU and HF inference candidate lane).
- `speech_experiments/model-lab`: `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN` (model conversion/workbench lane).
- `learning_for_kids`, `sceneguide`, `adshot`, `bas5minute`: `HF_TOKEN`, `HUGGINGFACE_API_KEY`, `GEMINI_API_KEY` (integration references only, not production paths).

Notes:

- A key’s presence in a project does not mean it is wired into CoverWise for mobile policy processing.
- `HF_TOKEN` enables multiple HF surfaces; it does not imply on-device inference.
- `OPENROUTER_API_KEY` and `MODAL` keys are suitable for benchmark or hosted fallback only unless policy and residency decisions are explicitly approved.

### Not evaluated yet

- Any real Android device run, including Android low/mid/high-tier matrix testing.
- Any real iPhone/iPad run, including Apple Intelligence availability and unsupported-device fallback.
- Any Flutter-to-native bridge for a local LLM.
- Transformers.js in a mobile WebView or mobile browser with cached models.
- MediaPipe LLM Inference or LiteRT with Gemma 3/Gemma 3n.
- ExecuTorch export and execution for any shortlisted model.
- ONNX Runtime Mobile execution for a text model, embedding model, OCR model, or generated model.
- MLC LLM or llama.cpp Android/iOS packaging.
- Battery, thermal throttling, memory pressure, app startup, model download/resume, cancellation, background/foreground recovery, or model eviction.
- Insurance-field accuracy, citation/page grounding, unsupported-language behavior, or malicious/garbage-input behavior for any mobile model.

## Evaluation contract

The mobile decision is not “which model has the highest public benchmark score.” It is a three-layer evaluation:

1. **Model layer:** Does the model produce correct constrained outputs for the task?
2. **Pipeline layer:** Does the app preserve page provenance, schema validation, fallback, cancellation, retry, and user/operator visibility?
3. **Data/config layer:** Are model assets, tokenizer, quantization, prompt version, field rules, corpus labels, and licenses versioned and reproducible?

### Tasks

- Short policy Q&A from already extracted text, with citations required.
- Structured extraction from text: policy number, insurer, dates, amounts, exclusions, waiting periods.
- Classification/routing: digital PDF vs scan, document type, “needs review” vs “safe to answer.”
- Image/page review only after OCR or text extraction fails; the model may propose but never silently overwrite source-grounded values.
- Offline UX: model unavailable, asset missing, unsupported device, low memory, timeout, cancellation, retry, and re-sync.

### Corpus

Use the existing synthetic fixture first, then a versioned consented-or-synthetic corpus of at least 30 Indian-policy documents with expected field values and page references. Do not place raw customer policy text in reports. Include digital PDFs, scanned pages, tables, multi-column pages, low-DPI pages, mixed English/Indian-language pages, missing fields, contradictory fields, and adversarial garbage.

### Metrics and gates

| Dimension | Measure | Initial gate for a production candidate |
|---|---|---|
| Field accuracy | Exact match for policy number/insurer; normalized dates/amounts | 99% policy number and insurer; 98% dates/amounts on the held-out corpus |
| Grounding | Every extracted value maps to page/block evidence | 100% of accepted values grounded; no unsupported overwrite |
| Structured output | Schema-valid response rate, repair rate, refusal rate | 99% schema-valid without unsafe repair; explicit refusal for missing evidence |
| Q&A | Citation precision, answer faithfulness, unsupported claim rate | No launch claim until held-out citation/faithfulness review passes |
| Latency | Cold start, warm p50/p95, first token, page processing | Set device-class budgets before comparing models; record, do not infer |
| Resource use | Peak RSS, package/model size, battery drain, thermal throttling | Must fit declared device classes without OS termination |
| Reliability | timeout, cancellation, retry, low-memory, process death, model eviction | Recovery is observable and never presents partial output as final |
| Privacy | Network trace and local storage inspection | Policy text and prompts remain local in local mode; secrets never logged |
| Cross-platform | Android/iOS result and failure parity | Same contract, with platform-specific capability shown honestly |

### Device matrix

Run real-device tests on Android low/mid/high tiers, Pixel/AICore-capable Android, and at least one supported and one unsupported iPhone/iPad class. Record OS version, chipset, RAM, battery state, thermal state, runtime, model artifact hash, quantization, prompt version, and network state. Simulator/emulator results are smoke evidence only.

## Recommended decision order

1. **Do not add Transformers.js to the Flutter app as the primary native path.** Keep it as a separately measured WebView/mobile-web experiment for small encoders or lightweight text tasks.
2. **Prototype the platform-native managed paths:** Gemini Nano/AICore for eligible Android devices and Foundation Models for eligible iOS devices. They reduce model packaging but require capability detection and a stable server fallback.
3. **Prototype one shared custom path with MediaPipe/LiteRT using Gemma 3n E2B/E4B.** This is the leading cross-platform newer-model candidate.
4. **Benchmark ExecuTorch and MLC/llama.cpp as the portability/performance alternatives** using Qwen3 1.7B/4B, Phi-4-mini, SmolLM3 3B, and Ministral 3 3B where exports are supported.
5. **Keep the current server/PyMuPDF/evidence pipeline canonical.** Local mobile models should be bounded assistive/recovery paths until Tier 3+ corpus and device evidence exists.

## Anything else?

## Live hosted-provider and Modal evidence (synthetic only, 2026-07-24)

`tools/evaluate_provider_smoke.py` sends only a fixed fictional two-page
fixture. It checks JSON output, correct refusal of an absent field, and
source-ID grounding. It does not measure insurance accuracy, mobile behavior,
production capacity, data residency, or price. Result files retain no prompt or
answer text.

| Route and requested model | Result | Median | Decision |
|---|---:|---:|---|
| CoverWise OpenAI `gpt-5-nano` | **3/3 passed**; API reported `gpt-5-nano-2025-08-07` | 1,237 ms | Selected hosted baseline for governed corpus evaluation. [Result](../review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json) |
| OrbitCover OpenRouter `google/gemini-2.5-flash-lite` | 2/3 passed | 746 ms | Not an automatic grounded-answer fallback; source-grounding failed once. [Result](../review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json) |
| OrbitCover OpenRouter `google/gemma-3-4b-it` | 1/3 passed | 582 ms | Comparison route only; not a schema/citation fallback. [Result](../review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json) |
| Comfy HF Inference Providers `Qwen/Qwen3-4B-Instruct-2507` | 2/3 passed | 1,173 ms | Reachable but not an automatic fact-answer fallback; source-grounding failed once. [Result](../review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json) |
| Comfy Modal remote smoke | completed | n/a | Proves a remote Linux/private-GPU execution account only, not LLM/mobile/document accuracy. [Run](https://modal.com/apps/pranaysuyash/main/ap-8u5LKeI1gpeBFzGdFyZYnS) |

The first OpenAI probes exposed a GPT-5 compatibility detail: chat completions
rejected legacy `max_tokens`, and too small a completion budget produced empty
visible content. The tool therefore uses `max_completion_tokens=1000` and
`reasoning_effort=minimal` for OpenAI. The CoverWise client already maps its
token parameter to `max_completion_tokens` for GPT-5; task-specific budgets
still need governed corpus verification.

OrbitCover’s `config/benchmark-models.json` is a useful separate benchmark
harness (171 ticket fields; its reported best text F1 was Gemma 3 4B), but that
ticket corpus cannot prove CoverWise insurance accuracy, grounding, privacy, or
mobile suitability.

## Fine-tuning decision

There is no fine-tuned mobile model, approved fine-tuning dataset, or exported
mobile artifact in CoverWise. Do not train from ordinary uploaded policies.
First establish retrieval-plus-citation baseline errors, then use a governed,
consented or synthetic corpus with lineage and an artifact hash. Gemma 3n can
be LoRA/QLoRA-trained on Modal then converted to LiteRT/MediaPipe; Qwen3/Phi
can be exported as separate Android/iOS ExecuTorch artifacts. Apple adapters
are version-bound and entitlement-gated, so they are not the shared first lane.

## Selected architecture and fallback posture

| Situation | Selected path | Guardrail |
|---|---|---|
| Grounded policy Q&A/extraction | Current server evidence pipeline with OpenAI `gpt-5-nano` baseline | Answer only after schema/evidence validation; unsupported claims become review/retry |
| Eligible Android short offline assist | Gemini Nano/AICore prototype | Capability detection; server/unavailable fallback |
| Eligible iOS short offline assist | Foundation Models prototype | Capability detection and OS-version prompt regression |
| Shared offline workflow | Gemma 3n E2B first, E4B for high-end phones, MediaPipe/LiteRT | No release until artifact, corpus, and real-device gates pass |
| Heavy VLM/OCR/model comparison | Modal private GPU benchmark | Approval required before policy data leaves CoverWise |
| OpenRouter/HF comparison | Explicit benchmark route only | No automatic factual fallback until grounding passes |

Yes: local inference is not automatically safe for insurance decisions. The mobile model must be treated as a proposal generator behind the existing evidence and verification contract. A model that works offline but cannot cite the source page, explain failure, survive model eviction, or fall back without making a stronger customer-facing claim is not production-ready.

## Primary sources

- [Gemma 3n model overview](https://ai.google.dev/gemma/docs/gemma-3n)
- [Google Gemma mobile deployment / MediaPipe LLM Inference](https://ai.google.dev/gemma/docs/integrations/mobile)
- [Android Gemini Nano and AICore](https://developer.android.com/ai/gemini-nano)
- [Android on-device AI solution guide](https://developer.android.com/ai/overview)
- [Apple Foundation Models framework](https://developer.apple.com/documentation/FoundationModels)
- [ExecuTorch LLM deployment](https://docs.pytorch.org/executorch/stable/llm/getting-started.html)
- [ONNX Runtime Mobile](https://onnxruntime.ai/docs/tutorials/mobile/)
- [MLC LLM iOS deployment](https://github.com/mlc-ai/mlc-llm/blob/main/docs/deploy/ios.rst)
- [Transformers.js WebGPU guide](https://huggingface.co/docs/transformers.js/main/en/guides/webgpu)
- [Hugging Face Inference Providers](https://huggingface.co/docs/inference-providers/en/index)
- [Hugging Face pricing / Pro](https://huggingface.co/pricing)
- [Modal inference guide](https://modal.com/docs/guide)
- [Microsoft Phi-4-mini-instruct model card](https://huggingface.co/microsoft/Phi-4-mini-instruct)
- [Mistral Ministral 3 model collection](https://huggingface.co/collections/mistralai/ministral-3)
- [OpenRouter model fallbacks](https://openrouter.ai/docs/guides/routing/model-fallbacks)
- [OpenRouter provider routing](https://openrouter.ai/docs/guides/routing/provider-selection)
