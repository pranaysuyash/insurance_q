# Mobile model selection board (2026-07-26)

Purpose: keep one short, unambiguous shortlist for decision meetings.

## A) Decision rule (this pass)

A model is marked **Ready-to-promote** only if it has all of the following in-repo:
1) versioned mobile artifact in supported format,
2) Android+iOS install/load/ask execution evidence,
3) policy-stage telemetry (latency/memory/failure/fallback/schema-grounding).

Otherwise it remains **Evidence Gap**.

## B) What is evaluated vs not (shortlist)

| Item | Target / lane | Status | Evidence | Why |
|---|---|---:|---|---|
| OpenAI `gpt-5-nano` (`gpt-5-nano-2025-08-07`) | Hosted fallback/comparison | EVIDENCED | `docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json`, `continuation-smoke-2026-07-25.json`, `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | Reliable hosted lane for now; not offline/mobile |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted comparison only | EVIDENCED (limited) | `docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json` | `2/3`; grounded-answer task fails some runs; no mobile artifact |
| OpenRouter `google/gemma-3-4b-it` | Hosted comparison only | EVIDENCED (limited) | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | `1/3`; hosted only |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | Hosted comparison only | EVIDENCED (limited) | `docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json` | `2/3`; hosted only |
| Modal (`MODAL_TOKEN_*`) | Private benchmark infra | CONTEXT-ONLY | `comfy/.env` key surface (plus scripts) | Comfy tokens confirm infra, but no CoverWise Android/iOS mobile runtime wiring yet |
| Ollama / MLX desktop checks (`gemma3:4b`, `gemma3:12b`, `qwen2.5vl:7b`, `deepseek-ocr`) | Desktop/local server lane | DESKTOP-ONLY | `docs/review/evidence/local-model-eval/*.json` | Real execution is daemon/server-level only; not Android/iOS user app runtime |
| Mobile bridge seam (`flutter_gemma` + `ON_DEVICE_*`) | Flutter Android/iOS offline path | SCAFFOLD | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`, `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26.json` | Control-path tests only; no `.task` install/load/ask run |
| Gemma 3n E2B / E4B (`.task`) | Flutter native offline | EVIDENCE GAP | n/a | No `.task` artifact/hash + no install/load/ask evidence |
| Gemma 3 270M / 1B | Flutter native offline | EVIDENCE GAP | n/a | No exported mobile artifact/run |
| Qwen3 (0.6B / 1.7B / 4B) | Flutter native offline | EVIDENCE GAP | n/a | No exported mobile artifact/run |
| Phi-4-mini / SmolLM3 / Ministral 3B | Flutter native offline | EVIDENCE GAP | n/a | No exported mobile artifact/run |
| Qwen3-VL / Qwen2-VL / PaddleOCR-VL / LLaVA | Visual recovery (fallback) | EVIDENCE GAP | n/a | No mobile visual-stage run |
| Transformers.js / WebGPU / ONNX-web | Mobile-web experiment | NOT-IN-LANE | n/a | No Flutter-native mobile inference route in this repo |
| Android managed `Gemini Nano` / AICore | Platform-managed | NOT-IN-LANE | n/a | No in-app probe matrix for supported/unsupported devices |
| iOS managed `Foundation Models` | Platform-managed | NOT-IN-LANE | n/a | No in-app probe matrix by OS/model and fallback |
| Fine-tune / LoRA / PEFT adapters | Mobile production route | NOT-WIRED | n/a | Missing base+tokenizer+merge+quantization+artifact manifest for mobile |
| Parser frontier (`Docling`, `Marker`, `MinerU*`, `RT-DocLayout`, `Unlimited-OCR`, `Dolphin`, `AgenticOCR`, `Logics-Parsing`, etc.) | Frontend parse stage | CATALOG-ONLY | `docs/review/evidence/local-model-eval/recent_models_2024_plus_inventory_2026-07-25.json`, `docs/review/mobile_model_frontier_appendix_2026_07_25.md` | 77-item frontier inventory only; no mobile-on-device implementation run |

## C) 2024–2026 model shortlist coverage (post-2024 frontier)

- Total entries in catalog ingestion: **77** (`workbook_2024plus_inventory.json` lineage)
- Status today for all entries relative to CoverWise mobile execution: **Catalog-only**, except the mobile bridge seam (`flutter_gemma`) which is Scaffold.

## D) Next execution sequence (ranked)

1. `Gemma 3n` shared lane first: `.task` artifact + signed hash + Android + iOS install/load/ask proof.
2. Re-run manifest with strict telemetry (latency/memory/thermal/timeout/cancel/fallback/schemavalidation).
3. Then compare one compact alternative (`Gemma 3 1B/270M` or `Qwen3 1.7B`) only if step 2 is accepted.
4. Only after that, evaluate managed-device lanes and visual OCR/VLM fallbacks on failure sets.
