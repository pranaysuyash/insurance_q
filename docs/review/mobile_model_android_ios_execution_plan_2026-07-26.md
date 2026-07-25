# Mobile Android/iOS execution plan (2026-07-26)

This is the concrete plan to close the gap between:
- what is currently **EVAL / Scaffold / Catalog-only**, and
- what must become **mobile-executed** in this repo.

## 1) Evidence truth used this pass

- **EVAL:** reproducible output exists for that exact stage/runtime in this repo.
- **SCaffold:** code/tests/config exist, but no Android/iOS `.task` install/load/ask telemetry.
- **Catalog-only:** in strategy/frontier or provider comparison lists only, no mobile execution evidence.
- **No-path:** not part of the Flutter-native mobile inference route in this repo.

## 2) Android/iOS model/runtime shortlist by priority

### P0 — unblock current mobile lane first

| Priority | Candidate | Type | Android status | iOS status | Current status | Why this order |
|---|---|---|---|---|---|---|
| P0-1 | `flutter_gemma` integration contract | framework seam | `ON_DEVICE_INFERENCE` flags + service exists | same | **SCaffold** | Required control-plane prerequisite for any mobile-local run |
| P0-2 | `Gemma 3n` E2B/E4B `.task` | on-device generation | **No artifact** | **No artifact** | **Catalog-only** | Direct alignment with existing seam + smallest coherent shared first step |

### P1 — compare one compact alternative only after P0

| Priority | Candidate | Type | Android status | iOS status | Current status | Why |
|---|---|---|---|---|---|---|
| P1-1 | `Gemma 3` 270M / 1B | on-device generation (compact) | **No artifact** | **No artifact** | **Catalog-only** | fallback if Gemma 3n fails objective gates |
| P1-2 | `Qwen3` 1.7B | on-device generation | **No artifact** | **No artifact** | **Catalog-only** | useful comparator once artifact export + telemetry are real |

### P2 — managed/runtime fallback probes

| Priority | Candidate | Type | Android status | iOS status | Current status | Why |
|---|---|---|---|---|---|---|
| P2-1 | `Gemini Nano` / `AICore` | platform-managed managed fallback | **No-path / no probe** | n/a | **No-path** | Should be probed only after shared on-device path has a contract |
| P2-2 | `Apple Foundation Models` | platform-managed managed fallback | n/a | **No-path / no probe** | **No-path** | Requires managed probe matrix with unsupported-device behavior |

### P3 — non-mobile or out-of-band lanes

| Priority | Candidate | Type | Android status | iOS status | Current status | Why |
|---|---|---|---|---|---|---|
| P3-1 | `Transformers.js`, `WebGPU/ONNX-Web` | web/mobile-web experiment | **No-path for Flutter-native** | **No-path for Flutter-native** | **No-path** | not a Flutter-native Android/iOS on-device execution path |
| P3-2 | `Ollama` / `DeepSeek OCR` local desktop checks | desktop/local server | **No-path** | **No-path** | **Not relevant to app runtime** | desktop infrastructure only |

## 3) Hosted paid lanes (used for comparison/fallback only)

These lanes are useful for benchmark comparison and fallback policy, but are **not** mobile-offline claims in CoverWise today.

| Lane | Evidence | Status | Why kept |
|---|---|---|---|
| OpenAI `gpt-5-nano` | `docs/review/evidence/provider-smoke/realitycheck-openai-2026-07-26.json` | **EVAL** | strongest cloud baseline for policy QA |
| OpenRouter `gemini-2.5-flash-lite` | `docs/review/evidence/provider-smoke/realitycheck-openrouter-2026-07-26.json` | **EVAL (partial)** | useful comparator, not local |
| OpenRouter `google/gemma-3-4b-it` | `docs/review/evidence/provider-smoke/openrouter-gemma3-4b-synthetic-2026-07-24.json` | **EVAL (limited)** | useful comparator, not local |
| HF Pro `Qwen/Qwen3-4B-Instruct-2507` | `docs/review/evidence/provider-smoke/realitycheck-hf-2026-07-26.json` | **EVAL (limited)** | useful comparator, not local |
| Modal Labs (`comfy` token set) | `comfy/.env` key scan + docs context | **Context-only** | private benchmark infra only |

## 4) Evidence gates to promote any mobile candidate to **EVAL**

For a mobile candidate to move from **Catalog-only** or **Scaffold** into **EVAL**, each must satisfy all gates:

1. **Artifact contract present:** versioned, signed mobile artifact manifest (`.task`, `.tflite`, `.gguf`, etc. per target runtime) with model family/version/tokenizer/quantization.
2. **Cross-platform install proof:** Android and iOS run trace includes model install or ready-state for the candidate.
3. **Load + ask proof:** model load success and at least one successful `ask` call with schema-valid output.
4. **Telemetry proof:** latency p50/p95, memory/RSS, thermal trend, timeout/cancel/retry, and failure class logging.
5. **Policy-stage proof:** unsupported-field/fallback behavior, refusal handling, and citation/schema integrity are captured in corpus-aligned checks.

Until all 5 gates are present, candidate status remains **Catalog-only**.

## 5) Mobile execution truth snapshot (as of this update)

- **`mobile/lib/services/on_device_inference_service.dart`** + **`mobile/lib/config/app_config.dart`** define an offline route, but this is still **Scaffold**.
- `docs/review/evidence/local-model-eval/mobile-ondevice-harness-2026-07-26.json` proves control-path tests only (feature flag behavior and reachability), not real install/load/ask with model artifact.
- The `recent_models_2024_plus_inventory_2026-07-25.json` frontier remains **77 Catalog-only entries** for this lane until an artifact/run path lands.

## 6) Cross-links

- [mobile_model_execution_readiness_matrix_2026-07-26.md](mobile_model_execution_readiness_matrix_2026-07-26.md)
- [mobile_model_selection_board_2026-07-26.md](mobile_model_selection_board_2026-07-26.md)
- [mobile_model_shortlist_truth_and_gaps_2026-07-26.md](mobile_model_shortlist_truth_and_gaps_2026-07-26.md)
- [mobile_model_evaluated_vs_not_authority_2026-07-26.md](mobile_model_evaluated_vs_not_authority_2026-07-26.md)

