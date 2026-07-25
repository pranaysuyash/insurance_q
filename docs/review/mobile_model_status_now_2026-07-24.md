# CoverWise mobile model status — 2026-07-24 (current truth map)

## What I actually did this pass

- Verified existing repository evidence for model execution/evaluation status against the policy-corpus and synthetic fixtures.
- Verified mobile code seam for local inference (`flutter_gemma` + MediaPipe).
- Verified environment/key presence in `medpiper/insurance_app` and related projects where provider keys are surfaced.
- Re-ran the mobile on-device service guard tests.

### Latest hard evidence check

- `cd mobile && flutter test test/on_device_inference_service_test.dart`
  - Result: **3/3 pass** (`3/3` in 2026-07-25 continuation, after adding the install-attempt coverage path).
  - Confirms the on-device seam is guarded off by default and refuses install when no approved config is present.
- `mobile/lib/services/on_device_inference_service.dart` + `mobile/lib/config/app_config.dart` + `mobile/pubspec.yaml` confirm:
  - `flutter_gemma` and `flutter_gemma_mediapipe` are declared
  - on-device path requires explicit `ON_DEVICE_INFERENCE_ENABLED=true` and HTTPS `ON_DEVICE_MODEL_URL`
  - no runtime model is bundled by default.

## Evaluated vs not (strict definition used here)

**Evaluated = reproducible run exists in repo evidence for this stage/runtime/pipeline lane.**  
**Catalog-only / scaffold-only = not yet an evaluated mobile/on-device claim.**

### Hosting / remote lanes (already evaluated, but not mobile-device)

- OpenAI direct (`gpt-5-nano`) — policy corpus + synthetic: evaluated (held-out policy run `29/52`, synthetic `3/3`)
- OpenRouter (`gemini-2.5-flash-lite`, `google/gemma-3-4b-it`) — synthetic: evaluated (limited)
- HF Inference (`Qwen3-4B`) — synthetic: evaluated (limited)
- Ollama desktop (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`) — desktop fixture checks: evaluated
- Surya 2 / docTR / PyMuPDF baseline: evaluated in server/local canonical pipeline

### Mobile native/on-device lanes (status)

- `flutter_gemma` + MediaPipe seam in app code: scaffolded, integration exists
- Android/iOS actual runtime execution: **not yet executed on physical devices**
- Simulator evidence: `flutter devices` in this pass detected **iPhone 17 simulator + macOS + Chrome**.
- Any of: Gemma 3n, Gemma 3 270M/1B, Qwen3, Phi-4-mini, SmolLM3, Ministral, Qwen3-VL, Gemini Nano, Apple Foundation Models: **not evaluated on-device in this repo**
- Transformers.js: **not evaluated in Flutter-native app runtime** (web/WebGPU style only)

### Fine-tune / adapter status

- No production-ready fine-tuned LoRA/QLoRA/merged checkpoint is currently wired into this mobile lane.
- Fine-tune is treated as an asset-state decision (dataset, tokenizer, quantization, runtime format, export lineage) before any mobile model claim.

## Provider/key surface sweep (project-level)

- CoverWise itself: `OPENAI_API_KEY`, `HF_TOKEN` (not direct proof of any one paid routing in mobile runtime)
- OrbitCover D2C: `OPENROUTER_API_KEY` (project-level)
- Comfy: `HF_TOKEN`, `MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET` (project-level)
- `speech_experiments/model-lab`: `HF_TOKEN`, `HUGGINGFACE_HUB_TOKEN`
- Other projects surfaced in the same sweep include OpenAI/Gemini/Groq/Anthropic/ToGether key-name presence (e.g., edureka, bas5minute, notes, sentineltwin), but these are **not wired into CoverWise mobile inference yet**.

## Execution posture by pipeline stage for this project

| Stage | Status |
|---|---|
| Parse / text extraction | Canonical server path evaluated |
| OCR / layout frontier (Docling/Marker/Unlimited-OCR/RT-DocLayout/etc.) | Catalogued only; not executed on mobile |
| Chunking / reconstruction | Evaluated on server pipeline; mobile-only tuning not done |
| Retrieval / rerank | Server hybrid baseline evaluated; mobile-device stress not done |
| Embeddings | `text-embedding-3-small` hosted baseline evaluated; mobile embedding lanes (EmbeddingGemma/Qwen3-Embedding) not executed |
| Generation hosted fallback | Evaluated (OpenAI/OpenRouter/HF synthetic + policy corpus reference) |
| Generation local/offline | Scaffold exists only (`flutter_gemma`); no on-device evaluation |
| Managed native model fallback | Not integrated yet (Gemini Nano / Apple Foundation Models) |
| Visual-stage fallback (VLM) | Catalogued only (mobile execution not yet run) |

## Why Android users do not install Ollama

Ollama is a host/desktop local runtime and daemon model, not an Android/iOS app runtime dependency.

## What to do next (minimum viable run order)

1. **T1** capability contract + platform detection + policy (unsupported devices/fail-open behavior)
2. **T2** first mobile runtime lane pilot: shared Gemma 3n `.task` path (if model + export + app bridge ready)
3. **T3** policy-grounding smoke set on real Android + iOS devices (latency, RAM/RSS, thermal, cancellation, failure reason telemetry)
4. **T4** managed-native probe matrix (Android Gemini Nano / iOS Foundation Models) if native routes are enabled
5. **T5** optional comparator candidates only if T2/T3 pass (Qwen/Gemma variants, RAG embeddings, VLM fallback)

## Ground-truth references

- [docs/review/mobile_model_execution_ledger_2026-07-24.md](docs/review/mobile_model_execution_ledger_2026-07-24.md)
- [docs/review/mobile_model_evidence_appendix_2026-07-24.md](docs/review/mobile_model_evidence_appendix_2026-07-24.md)
- [docs/review/mobile_model_decision_onepager_2026-07-24.md](docs/review/mobile_model_decision_onepager_2026-07-24.md)
- [docs/technical/mobile_local_model_evaluation_2026-07-24.md](docs/technical/mobile_local_model_evaluation_2026-07-24.md)
- [docs/review/mobile_model_decision_sheet_2026-07-24.md](docs/review/mobile_model_decision_sheet_2026-07-24.md)
- [docs/review/mobile_model_evaluated_vs_not_authority_2026-07-24.md](docs/review/mobile_model_evaluated_vs_not_authority_2026-07-24.md)
