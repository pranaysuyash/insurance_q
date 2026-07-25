# Mobile model execution decision sheet (2026-07-26)

Scope: Android/iOS mobile-lane decision for CoverWise, with direct answers to:

- which models/lists were explored,
- which were evaluated,
- what is scaffold-only,
- what is catalog-only,
- and why.

This sheet keeps the 77-model frontier in scope via `document_parsers_extractors_catalog_2026_v2.xlsx` and separates that from what has real repo evidence.

## 0) Evidence truth rule

- **EVAL**: reproducible evidence exists for the exact runtime stage used in CoverWise.
- **SCaffold**: integration/hooks/tests exist, but no real Android/iOS artifact install/load/ask telemetry.
- **Catalog-only**: in frontier/research list only, no mobile execution proof.
- **No-path**: not integrated into the CoverWise mobile route in this pass.

## 1) What was actually explored and run in this pass

### 1.1 Explored and EVAL lanes (hosted and harness)

| Lane | Target | Status | Evidence | Why this matters |
|---|---|---|---|---|
| OpenAI `gpt-5-nano` (`gpt-5-nano-2025-08-07`) | Hosted generation (cloud) | **EVAL (3/3)** | `docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json`, `docs/review/evidence/provider-smoke/continuation-combined-2026-07-26c.json`, `docs/review/evidence/local-model-eval/policy-corpus-ragas-2026-07-24.json` | Stable hosted comparator for policy QA; not Android/iOS offline proof |
| OpenRouter `google/gemini-2.5-flash-lite` | Hosted generation (cloud) | **EVAL (2/3)** | `docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json`, `docs/review/evidence/provider-smoke/continuation-combined-2026-07-26c.json` | Hosted fallback candidate with partial run-pass; no mobile artifact |
| OpenRouter `google/gemma-3-4b-it` | Hosted generation (cloud) | **EVAL (limited, 1/3)** | `docs/review/evidence/provider-smoke/continuation-combined-gemma3-2026-07-26c.json` | Hosted comparison only |
| HF Pro (`Qwen/Qwen3-4B-Instruct-2507`) | Hosted generation (cloud, HF credits) | **EVAL (2/3)** | `docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json`, `docs/review/evidence/provider-smoke/continuation-combined-2026-07-26c.json` | Hosted comparator only, no on-device mobile artifact |
| On-device service seam (`flutter_gemma` + `flutter_gemma_mediapipe`) | Android/iOS control path | **SCaffold** | `mobile/lib/services/on_device_inference_service.dart`, `mobile/lib/config/app_config.dart`, `mobile/test/on_device_inference_service_test.dart`, `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26b.json` | Real install/load/ask path is not proven yet; guard-path tests only |

### 1.2 Why this is the “shortlist” now

- **Hosted paid lanes** are useful for quality/comparison and reliability but are **not mobile-offline**.
- **Flutter mobile seam** is the only native app-lane entry with concrete code-level proof, so it is the only non-catalog candidate in-scope for local-offline execution.
- Every other model family currently remains frontier-only until an Android/iOS manifest + telemetry proves real execution.

## 2) 77-model frontier status (2024+, from workbook)

- Source inventory: `document_parsers_extractors_catalog_2026_v2.xlsx`
- Parsed source JSON: `docs/review/evidence/local-model-eval/recent_models_2024_plus_inventory_2026-07-25.json`
- Stage matrix + status: `docs/review/mobile_model_frontier_2026_plus_truth_matrix_2026-07-26.md`
- Full generated per-model status register: `docs/review/mobile_model_shortlist_generated_2026-07-26.md`
- Full compact compendium with same statuses: `docs/review/mobile_model_full_evaluation_compendium_2026-07-26.md`

Status across all 77 entries (mobile-relevant):

- **77 total frontier models** (2024=4, 2025=30, 2026=43)
- **0/77 EVAL for Android/iOS install/load/ask**
- **0/77 with current on-device artifact telemetry**
- **77/77 Catalog-only** for frontier models

Example families specifically requested and their current status:

- **Baidu / Unlimited-OCR family**: `Catalog-only`
- **RT-DocLayout**: `Catalog-only`
- **PaddleOCR-VL / PaddleOCR-VL variants**: `Catalog-only`
- **MinerU / MinerU* / Docling-adjacent**: `Catalog-only`
- **Dolphin / AgenticOCR / Logics-Parsing**: `Catalog-only`
- **Visual-stage parser candidates (Qwen3-VL, LLaVA, etc.)**: `Catalog-only`

## 3) Requested lane check-in

### 3.1 Transformers.js / web GPU lane

- Current status: **No-path for Flutter native Android/iOS**.
- Why: this repo’s active mobile route is Flutter native; Transformers.js is not wired as the model bridge there.

### 3.2 HF Pro, Modal Labs, OpenRouter, OpenAI keys and paid access

- Key presence was checked across project env files, but presence != execution wiring.
- Current in-repo routing posture:
  - **OpenAI / OpenRouter / HF Pro**: evaluated as hosted lanes only (useful comparators/fallbacks).
  - **Modal Labs**: context confirmed in separate project key surfaces; **not** integrated into CoverWise mobile in this pass.
  - **No-key or any key** does not make a model Android/iOS-executable unless a mobile artifact and telemetry are present.

## 4) Why your “Ollama/MLX/desktop-only” question is correct

- `Ollama` and desktop `MLX` checks are local/server benchmarks.
- They are not Android/iOS app runtime paths and therefore are treated as **Desktop-only / Catalog-stage evidence only**.

## 5) Fine-tune / adapter lane posture

- **LoRA / QLoRA / PEFT / merged adapters:** `Not-wired` for CoverWise mobile route.
- They currently lack the required mobile artifact stack (`base + tokenizer + merge + quantization + `.task`/runtime manifest` + Android+iOS install/load/ask telemetry).

## 6) Practical shortlist (what to do next)

Ranked for this release decision:

1. **Promote on-device execution readiness before new model breadth**: complete `Gemma`/mobile `.task` install + load + ask path on Android and iOS with failure-class logging.
2. If passed, run compact comparator on one second candidate (`Gemma 3 1B/270M` or `Qwen3 1.7B`) with full telemetry.
3. Then run managed runtime probes (`Gemini Nano/AICore`, `Apple Foundation Models`).
4. Only after above, move OCR/layout parser candidates into active model-execution matrix.



## 7) Decision summary (short)

- **Selected/evaluated now:** hosted comparator lanes + on-device seam scaffold.
- **Not selected for mobile-offline:** all 77 frontier model families until real mobile artifact telemetry exists.
- **Reason:** no current Android/iOS `.task`/artifact install/load/ask evidence, no cross-device latency/failure telemetry, and no managed-runtime probe matrix in-repo.
## 8) Selected / excluded / deferred shortlist

### 8.1 Selected in this release decision window

| Model family / lane | Decision | Why it is selected now |
|---|---|---|
| OpenAI `gpt-5-nano` hosted lane | **SELECTED (comparison lane)** | Stable eval evidence exists for policy-QA smoke and corpus checks; useful as hosted fallback baseline. |
| OpenRouter `google/gemini-2.5-flash-lite` hosted lane | **SELECTED (comparison lane, limited)** | Repeatable runs show partial pass; useful for provider fallback and latency/cost comparison. |
| OpenRouter `google/gemma-3-4b-it` hosted lane | **SELECTED (limited comparison only)** | Has real run evidence though limited; not a mobile-offline candidate. |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` hosted lane | **SELECTED (comparison lane, limited)** | Has real run evidence with HF Pro tokened lane; not mobile-offline. |
| `flutter_gemma` on-device service seam | **SELECTED (scaffold, pre-promotion)** | This is the only native Android/iOS route with code/test hooks in-repo; next gate is real `.task` install/load/ask. |

### 8.2 Excluded from mobile-offline promotion

| Model family / lane | Decision | Why excluded now |
|---|---|---|
| 77-model parser/frontier set (e.g., `Unlimited-OCR`, `RT-DocLayout`, `PaddleOCR-VL`, `MinerU`, `Dolphin`, `Logics-Parsing`, `AgenticOCR`, `Baidu*` families, etc.) | **EXCLUDED** | No on-device artifact manifest (`.task`/equivalent), no Android/iOS install/load/ask telemetry, and no policy-answer validation on-device. |
| Fine-tune / LoRA / PEFT adapter products | **EXCLUDED** | No merged artifact package + tokenizer + quantization + mobile runtime contract + Android+iOS execution evidence for this repo path. |
| Transformers.js / WebGPU mobile-web lane | **EXCLUDED (not Flutter-native Android/iOS)** | Not wired into native mobile inference route in this repo (different runtime path). |
| Ollama / MLX desktop lanes | **EXCLUDED (desktop-only)** | Desktop/server runtimes only; not Android/iOS product runtime. |
| Android managed (`Gemini Nano` / `AICore`) and iOS managed (`Foundation Models`) | **DEFERRED** | Capability probes and fallback matrix not yet implemented in-repo. |

### 8.3 Deferred execution candidates for next phase

| Candidate | Next required gate before promotion |
|---|---|
| `Gemma 3n` E2B / E4B `task` candidates | Signed artifact + Android/iOS install/load/ask + latency/memory/failure telemetry |
| Compact local alternatives (`Gemma` 1B/270M, `Qwen3` 1.7B) | Same as above, then comparative quality/latency check on both platforms |
| Modal/Lake managed model routing | In-app bridge + policy contract + secure key/routing telemetry in CoverWise |

