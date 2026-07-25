# Mobile model evidence appendix (2026-07-24)

This appendix is the consolidated, one-page + structured answer for:
what was evaluated, what was only cataloged, what can actually run on Android/iOS, and why.

**Scope:** CoverWise mobile decision only. Desktop and hosted lanes are logged separately.

## Definition used in this appendix

- **Evaluated (mobile-app evidence):** reproduced output in this repository for the target lane/runtime.
- **Evaluated (non-mobile):** reproduced output exists, but not on Android/iOS target runtime.
- **Catalog-only:** model/runtime appears in the frontier/strategy documents but has no repo execution evidence.
- **Cloud-only fallback:** paid API lane (OpenAI/OpenRouter/HF Modal/other) that never maps to Android/iOS offline execution.

## 1) Evaluated vs not — model/runtime ledger (CoverWise)

| Candidate / lane | Layer | Evaluated here | Evidence file / code | Android/iOS status | Selection reason |
|---|---|---|---|---|---|
| `gpt-5-nano` (OpenAI) | Hosted generation (default production path) | ✅ | `docs/review/evidence/provider-smoke/openai-synthetic-2026-07-24-success.json`; `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | No | Production-safe canonical fallback; 3/3 synthetic pass + held-out policy corpus grounding metrics |
| `google/gemini-2.5-flash-lite` (OpenRouter) | Hosted generation comparison | ✅ (synthetic only) | `docs/review/evidence/provider-smoke/openrouter-synthetic-2026-07-24.json` | No | Comparison only: 2/3 pass, grounded-answer failure |
| `google/gemma-3-4b-it` (OpenRouter) | Hosted generation comparison | ✅ (synthetic only) | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | No | Comparison only: 1/3 pass |
| `Qwen/Qwen3-4B-Instruct-2507` (HF Inference/HF Pro) | Hosted generation comparison | ✅ (synthetic only) | `docs/review/evidence/provider-smoke/hf-qwen3-synthetic-2026-07-24.json` | No | Comparison only: 2/3 pass |
| PyMuPDF + canonical extractor/chunking chain | Parsing + retrieval baseline | ✅ | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | No | Proven server-side pipeline input quality for policy corpus |
| Surya-2 / docTR / OCR-family desktop checks | OCR/layout fallback experiments | ✅ | `docs/review/evidence/local-model-eval/gemma3-12b-2026-07-12.json` (and companion OCR checks) | No | Useful desktop checks; not Android/iOS proof |
| Ollama: `gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`, DeepSeek OCR | Desktop local fallback lane | ✅ | `docs/review/evidence/local-model-eval/gemma3-12b-2026-07-12.json`; `docs/review/evidence/local-model-eval/gemma3-4b-recheck-2026-07-12.json`; `docs/review/evidence/local-model-eval/deepseek-ocr-diagnostic-2026-07-12.json` | No | Useful local baseline only; not mobile product evidence |
| `flutter_gemma` scaffold (`ON_DEVICE_INFERENCE_ENABLED`, `ON_DEVICE_MODEL_URL`) | Mobile-local framework integration | ⚠️ scaffold-only | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart` | No runtime runs yet | Integration seam exists, but no Android/iOS execution evidence yet |
| Gemma 3n E2B / E4B | Mobile custom runtime candidate | ❌ | — | Android/iOS candidate only | No device asset/import/runtime execution evidence |
| Gemma 3 270M / 1B | Mobile custom runtime candidate | ❌ | — | Android/iOS candidate only | No device export/runtime test |
| Qwen3 0.6B / 1.7B / 4B | Mobile custom runtime candidate | ❌ | — | Android/iOS candidate only | No export/runtime test |
| Phi-4-mini-instruct / SmolLM3 3B / Ministral 3 3B | Mobile custom runtime candidate | ❌ | — | Android/iOS candidate only | No export/runtime test |
| Qwen3-VL 2B / 4B | Visual fallback candidate | ❌ | — | Android/iOS candidate only | No on-device visual-failure run |
| Gemini Nano / AICore | Managed Android on-device path | ❌ | — | Android only | No capability probe + in-app integration in this pass |
| Apple Foundation Models | Managed iOS on-device path | ❌ | — | iOS only | No capability probe + in-app integration in this pass |
| Transformers.js (WebGPU/ONNX) | Web bridge fallback | ❌ | — | Mobile-web only | Not Flutter-native mobile execution path |
| Docling / MinerU / Marker / RT-DocLayout / Unlimited-OCR / PaddleOCR-VL / Qwen3-VL / etc. | Parser frontier | Catalog-only | `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md`; `docs/review/mobile_model_general_vlm_frontier_2026-07-24.md` | Android/iOS possible *after* export & runs | No device run this pass |
| EmbeddingGemma / Qwen3-Embedding (0.6B/4B/8B) | Embedding layer candidate | ❌ | — | Android/iOS candidate only | Not yet exported/running in mobile |

## 2) Why each lane is or is not selected now

- **Keep as production-safe default:** OpenAI `gpt-5-nano` for hosted, evidence-gated policy responses.
- **Comparison-only now:** OpenRouter/HF smoke models (for model quality and grounding checks only).
- **Prototype-first local lane:** `flutter_gemma` + Gemma-3n family (requires artifact + device matrix + runtime gates).
- **Defer until gates pass:** Qwen/phi/smollm/minstral/managed-platform candidates.
- **Always excluded for Android/iOS claim:** Ollama/MLX/Desktop setups unless explicitly rebuilt as mobile runtime package + telemetry.

## 3) Android/iOS execution reality check

- We have **no Android or iOS on-device model execution evidence in this pass**.
- Existing files prove the architectural seam, not runtime truth:
  - `mobile/lib/config/app_config.dart`
  - `mobile/lib/services/on_device_inference_service.dart`
  - `docs/technical/mobile_local_model_evaluation_2026-07-24.md`
- Android users are **not** expected to install Ollama/MLX/llama-server.

## 4) Project-level key-surface inventory used for route planning

Only key names are listed; values are never copied.

| Project | Key names observed in `.env` / `.env.example` |
|---|---|
| `medpiper/insurance_app` | `OPENAI_API_KEY`, `HF_TOKEN` |
| `orbitcover-d2c` | `OPENROUTER_API_KEY` |
| `comfy` | `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` |
| `edureka` | `OPENAI_API_KEY`, `HF_TOKEN`(via `HUGGINGFACE_API_KEY`), `GROQ_API_KEY`, `GEMINI_API_KEY` |
| `speech_experiments/model-lab` | `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN` |
| `learning_for_kids` | `HF_TOKEN`, `HUGGINGFACEHUB_API_TOKEN`, `GEMINI_API_KEY` |
| `adshot` | `HF_TOKEN`, `GEMINI_API_KEY` |
| `bas5minute` | `OPENAI_API_KEY`, `HF_TOKEN`, `HUGGINGFACE_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` |
| `notes` | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY` |
| `sentinelTwin` | `OPENAI_API_KEY`, `GEMINI_API_KEY`, `TOGETHER_API_KEY` |
| `invoice-intelligence` | `OPENAI_API_KEY`, `OPENROUTER_API_KEY` |
| `musicathon` | `HF_TOKEN` |
| `EchoPanel` | `HF_TOKEN` |

## 5) “SOTA/niche” frontier coverage

- Fine-grained frontier candidates are tracked in:
  - `docs/review/mobile_model_general_vlm_frontier_2026-07-24.md` (general VLM OCR-capable models)
  - `docs/review/mobile_model_catalog_2025_2026_2026-07-24.md` (2025–2026 parser/frontier list)
- These are **important**, but currently **not executed on-device in CoverWise**.

## 6) Stage-wise evidence map for this decision pass

| Stage | What exists | Why this is/was evaluated | What is still missing |
|---|---|---|---|
| Parse / text extraction | Canonical PyMuPDF baseline + docs/policy corpus | Proven in held-out policy run and live pipeline behavior | Mobile-native parse replacement and device benchmark |
| OCR / layout | Surya-2 and local OCR checks | Useful desktop signal for synthetic and parse edge cases | Android/iOS image/layout benchmark and failure recovery telemetry |
| Chunking/reconstruction | Multi-strategy chunking implemented | Implemented and used in corpus path | Mobile-only tuning and memory/latency validation |
| Retrieval / rerank | Hybrid dense + FTS + existing rerank baseline | Proven on policy corpus evidence | On-device retrieval pressure / cancellation behavior |
| Hosted generation | OpenAI + OpenRouter + HF smoke | Reproducible provider results are present | Not offline/on-device |
| Embedded/mobile generation | `flutter_gemma` seam + config flags | Scaffold exists | No executed Android/iOS benchmark |

## 7) Shortlist for next practical run

1. Device capability + contract matrix (supported/unsupported + refusal behavior) for Android/iOS.
2. One local baseline lane: Gemma 3n (E2B/E4B) with fixed manifest + telemetry.
3. 20-policy + 6 visual-failure + 6 negative probe benchmark after lane opens.
4. Comparator only if gate passes: Qwen3 1.7B or smaller local candidate.

This appendix is intentionally strict: **no model can be claimed “mobile-ready” without Android/iOS run evidence + telemetry + fallback logs.**

