# Mobile model shortlist — authoritative status map (2026-07-25)

Date: 2026-07-25  
Scope: CoverWise policy-RAG on Android/iOS + relevant paid comparison lanes.

## 1) What “done” means in this repo

- **EVAL** = reproducible in-repo evidence for that exact stage/runtime.
- **SCaffold** = code/tests/config exist, but no real Android/iOS install/load/ask model telemetry.
- **Catalog-only** = model/family appears in the frontier/pipeline research set, no mobile execution artifact in this repo.
- **No-path** = not wired into CoverWise mobile route at all.

## 2) What is actually evaluated (today)

### A) Hosted/paid comparison lanes (not mobile-offline)

| Lane | Stage | Evidence | Status | Status reason |
|---|---|---|---|---|
| OpenAI `gpt-5-nano` | Hosted policy grounding (generation) | `docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json` | **EVAL (3/3)** | Stable cloud baseline; policy checks pass in synthetic + held-out harness context. |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted generation comparator | `docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json` | **EVAL (2/3)** | Comparison lane only; one synthetic case fails source/factual consistency check. |
| OpenRouter `google/gemma-3-4b-it` | Hosted generation comparator | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | **EVAL (1/3)** | Weak pass rate in synthetic; comparison only. |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | Hosted generation comparator | `docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json` | **EVAL (2/3)** | Useful benchmark lane only; no on-device contract. |
| Policy held-out corpus QA | End-to-end baseline scoring | `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | **EVAL** | `accuracy=0.5577`, `citation_rate=0.9615`, `hallucination_rate=0.3333`. |

### B) Mobile/offline lanes

| Lane | Android | iOS | Evidence | Status | Why |
|---|---:|---:|---|---|---|
| `flutter_gemma` seam (`ON_DEVICE_INFERENCE_ENABLED`, `ON_DEVICE_MODEL_URL`) | ✅ | ✅ | `mobile/lib/config/app_config.dart` / `mobile/lib/services/on_device_inference_service.dart` / `mobile/test/on_device_inference_service_test.dart` / `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26.json` | **SCaffold** | Install/load/ask telemetry missing; only flag + path reachability validated. |
| Gemma 3n E2B / E4B `.task` | ✅ | ✅ | frontier catalog + no mobile trace | **Catalog-only** | No exported `.task`, signed manifest, install/load/ask trace. |
| Gemma 3 `270M` / `1B` | ✅ | ✅ | frontier catalog + no mobile trace | **Catalog-only** | No export + no on-device run. |
| Qwen3 `0.6B` / `1.7B` / `4B` | ✅ | ✅ | frontier catalog + no mobile trace | **Catalog-only** | No export + no on-device run. |
| Phi-4-mini / SmolLM3 / Ministral 3B | ✅ | ✅ | frontier catalog + no mobile trace | **Catalog-only** | No export + no on-device run. |
| Android managed (`Gemini Nano` / `AICore`) | ✅ | — | no probe logs in this repo | **No-path** | not yet integrated/probed in app. |
| iOS managed (`Apple Foundation Models`) | — | ✅ | no probe logs in this repo | **No-path** | not yet integrated/probed in app. |
| Transformers.js / WebGPU / ONNX Web | web-only | web-only | no Flutter-native bridge for this lane | **No-path** | valid web research path, not Flutter Android/iOS execution path. |
| Modal-Labs endpoint path (`comfy` keys) | n/a | n/a | `comfy/.env` token surface | **Context-only** | key+infra exists; no CoverWise mobile endpoint routing. |

## 3) Fine-tune / adapter lane status

- **Fine-tune/LoRA/adapter mobile-ready artifact:** **Catalog-only / Not wired**
- Missing manifest pieces: tokenizer lock + quantization preset + metadata hash + mobile export + install/load/ask telemetry for Android+iOS.
- Current policy: keep generic hosted fallbacks (`gpt-5-nano`) until on-device artifact gates are met.

## 4) 2024–2026 frontier model list status (77 entries)

Source of truth: `docs/review/evidence/local-model-eval/recent_models_2024_plus_inventory_2026-07-25.json` and `docs/review/mobile_model_full_evaluation_compendium_2026-07-26.md`  
Status for all 77 entries in this frontier run: **Catalog-only for mobile execution** (no Android/iOS on-device proof yet).

### 2026 model families (43)
`ABot-OCR`, `Agentar-Fin-OCR`, `AgenticOCR`, `Agents-K1`, `BabelDOC`, `Beaver`, `Consensus Entropy`, `DODO`, `DeepSeek-OCR 2`, `Dolphin-2.0`, `Falcon OCR / Falcon Perception`, `FastOCR`, `FireRed-OCR`, `GLM-OCR`, `GutenOCR`, `HSD`, `HunyuanOCR-1.5`, `Infinity-Parser2`, `LightOnOCR`, `Logics-Parsing-Omni`, `MeDocVL`, `MinerU-Diffusion`, `MinerU-Popo`, `MinerU2.5-Pro`, `OCR-Agent`, `OCRVerse`, `OmniOCR`, `P-MTP`, `PP-OCRv6`, `PTP`, `PaddleOCR-VL (coarse-to-fine)`, `PaddleOCR-VL-1.5`, `PaddleOCR-VL-1.6`, `PixelPrune`, `Qianfan-OCR`, `RT-DocLayout`, `RTPrune`, `SAYRE`, `TexOCR`, `Typhoon-OCR`, `Unlimited-OCR`, `Youtu-Parsing`, `dots.mocr`.

### 2025 model families (30)
`AgenticOCR`, `Chandra v0.1.0`, `DOCR-Inspector`, `DeepSeek-OCR`, `DianJin-OCR-R1`, `Doc-Researcher`, `Dolphin`, `Dolphin-1.5`, `GTR-VL`, `Granite-Docling-258M`, `HunyuanOCR`, `Infinity-Parser`, `Logics-Parsing`, `Marker 1.10.1`, `MinerU 2.5`, `MinerU2.0-2505-0.9B`, `MonkeyOCR`, `MonkeyOCR v1.5`, `MonkeyOCR-Pro`, `Nanonets-OCR 2`, `OCRFlux`, `Ocean-OCR`, `PP-StructureV3`, `PaddleOCR-VL`, `SmolDocling-256M`, `TRivia`, `Uni-Parser`, `UniRec-0.1B`, `dots.ocr`, `olmOCR`, `olmOCR 2`.

### 2024 model families (4)
`GOT-OCR 2.0`, `MarkItDown`, `MinerU`, `open-parse`.

## 5) Why these are your realistic shortlist right now

1. If the goal is **true mobile-offline policy QA**, only `flutter_gemma` is currently wired in repo; it is still scaffold-only and cannot yet be called a mobile-offline production lane.
2. For now, **hosted `OpenAI`/`OpenRouter`/`HF Pro` lanes** are the only evaluated generation paths with reproducible proof, so they remain comparison/fallback lanes.
3. Parser/OCR upgrades (e.g., Unlimited-OCR, RT-DocLayout, PaddleOCR-VL, etc.) are high-value for ingestion quality but remain research/future candidate lanes until on-device execution artifacts and phone telemetry exist.

## 6) Immediate next gates (to move from “catalog” to “real” on-device)

For any candidate moving from Catalog-only/Scaffold to EVAL:

- Signed Android/iOS mobile artifact present (`.task` / `.gguf` / `.onnx` / `.tflite` + manifest + hash + tokenizer/quantization metadata)
- Android + iOS install/ready run observed
- load + ask execution observed
- policy-stage output schema/citation checks observed
- telemetry: latency p50/p95, memory/RSS, timeout/cancel/retry, unsupported-device behavior

## 7) Canonical files for traceability

- `docs/review/mobile_model_gatebook_2026-07-26.md`
- `docs/review/mobile_model_execution_readiness_matrix_2026-07-26.md`
- `docs/review/mobile_model_evaluated_vs_not_authority_2026-07-26.md`
- `docs/review/mobile_model_full_evaluation_compendium_2026-07-26.md`
- `docs/review/mobile_model_frontier_2026_plus_truth_matrix_2026-07-26.md`
- `docs/review/mobile_model_frontier_2024_plus_inventory_2026-07-25.md`
- `docs/review/mobile_model_key_surface_inventory_2026-07-25.md`

